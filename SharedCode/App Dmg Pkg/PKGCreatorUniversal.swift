//
//  PKGCreatorUniversal.swift
//  Intuneomator
//
//  Created by Gil Burns on 4/15/25.
//

import Foundation

/// Creates universal macOS installer packages that intelligently install the correct architecture
/// Combines separate ARM64 and x86_64 application bundles into a single installer package
/// Uses JavaScript logic to detect system architecture and install the appropriate version
class PKGCreatorUniversal {
    
    /// Log type identifier for logging operations
    private let logType  = "PKGCreatorUniversal"

    /// Creates a universal installer package from separate ARM64 and x86_64 application bundles
    /// The resulting package automatically detects system architecture and installs the correct version
    /// - Parameters:
    ///   - inputPathArm64: Path to the ARM64 (Apple Silicon) .app bundle
    ///   - inputPathx86_64: Path to the x86_64 (Intel) .app bundle
    ///   - outputDir: Directory where the universal package will be created
    /// - Returns: Tuple containing package path, app name, bundle ID, and version, or nil on failure
    func createUniversalPackage(inputPathArm64: String, inputPathx86_64: String, outputDir: String) -> (packagePath: String, appName: String, appID: String, appVersion: String)? {

        Logger.log("createUniversalPackage", logType: logType)
        let fileManager = FileManager.default
        let tempDir = "\(NSTemporaryDirectory())/universal-temp-\(UUID().uuidString)"
        let rootArm = "\(tempDir)/root_arm"
        let appsArm = "\(rootArm)/Applications"
        let rootX86 = "\(tempDir)/root_x86"
        let appsX86 = "\(rootX86)/Applications"
        let componentPlistArm = "\(tempDir)/component_arm.plist"
        let componentPlistX86 = "\(tempDir)/component_x86.plist"
        let outputComponentArm = "\(tempDir)/component-arm.pkg"
        let outputComponentX86 = "\(tempDir)/component-x86.pkg"
        let distributionXML = "\(tempDir)/distribution.xml"
        let finalPackagePath: String
        
        Logger.log("Temp dir created: \(tempDir)", logType: logType)
        Logger.log("Output dir created: \(outputDir)", logType: logType)
        Logger.log("Input arm64: \(inputPathArm64)", logType: logType)
        Logger.log("Input x86_64: \(inputPathx86_64)", logType: logType)

        do {
            try fileManager.createDirectory(atPath: appsArm, withIntermediateDirectories: true)
            try fileManager.createDirectory(atPath: appsX86, withIntermediateDirectories: true)
        } catch {
            Logger.log("Error: Failed to create temp root directories - \(error)", logType: logType)
            return nil
        }

        let armAppName = (inputPathArm64 as NSString).lastPathComponent
        let x86AppName = (inputPathx86_64 as NSString).lastPathComponent
        let destArm = "\(appsArm)/\(armAppName)"
        let destX86 = "\(appsX86)/\(x86AppName)"

        do {
            try fileManager.copyItem(atPath: inputPathArm64, toPath: destArm)
            try fileManager.copyItem(atPath: inputPathx86_64, toPath: destX86)
        } catch {
            Logger.log("Error copying app bundles - \(error)", logType: logType)
            return nil
        }

        guard let appInfo = extractAppInfo(from: destArm) else {
            Logger.log("Error reading Info.plist from ARM app", logType: logType)
            return nil
        }

        // Analyze both component packages
        let _ = runProcess(["/usr/bin/pkgbuild", "--analyze", "--root", rootArm, componentPlistArm])
        let _ = runProcess(["/usr/bin/pkgbuild", "--analyze", "--root", rootX86, componentPlistX86])

        // Modify both component packages
        let _ = modifyComponentPlist(at: componentPlistArm)
        let _ = modifyComponentPlist(at: componentPlistX86)

        // Build both component packages
        let _ = runProcess(["/usr/bin/pkgbuild",
                            "--root", rootArm,
                            "--identifier", "\(appInfo.appID)",
                            "--version", appInfo.appVersion,
                            "--component-plist", componentPlistArm,
                            outputComponentArm])

        let _ = runProcess(["/usr/bin/pkgbuild",
                            "--root", rootX86,
                            "--identifier", "\(appInfo.appID)",
                            "--version", appInfo.appVersion,
                            "--component-plist", componentPlistX86,
                            outputComponentX86])

        // Write custom distribution.xml with architecture detection logic
        let xml = """
        <?xml version=\"1.0\" encoding=\"utf-8\"?>
        <installer-gui-script minSpecVersion=\"1\">
            <title>\(appInfo.appName)-\(appInfo.appVersion)</title>
            <pkg-ref id=\"\(appInfo.appID)-arm\"/>
            <pkg-ref id=\"\(appInfo.appID)-x86\"/>
            <options customize=\"allow\" require-scripts=\"false\" rootVolumeOnly=\"true\" hostArchitectures=\"x86_64,arm64\"/>
            <script>
            <![CDATA[
            function is_arm() {
              if(system.sysctl(\"machdep.cpu.brand_string\").includes(\"Apple\")) {
                return true;
              }
              return false;
            }
            ]]>
            </script>
            <choices-outline>
                <line choice=\"default\">
                    <line choice=\"\(appInfo.appID)-arm\"/>
                    <line choice=\"\(appInfo.appID)-x86\"/>
                </line>
            </choices-outline>
            <choice id=\"default\" title=\"\(appInfo.appName)-\(appInfo.appVersion)\"/>
            <choice id=\"\(appInfo.appID)-arm\" title=\"\(appInfo.appName) ARM\" visible=\"true\" enabled=\"is_arm()\" selected=\"is_arm()\">
                <pkg-ref id=\"\(appInfo.appID)-arm\"/>
            </choice>
            <pkg-ref id=\"\(appInfo.appID)-arm\" version=\"\(appInfo.appVersion)\" onConclusion=\"none\">component-arm.pkg</pkg-ref>
            <choice id=\"\(appInfo.appID)-x86\" title=\"\(appInfo.appName) x86\" visible=\"true\" enabled=\"! is_arm()\" selected=\"! is_arm()\">
                <pkg-ref id=\"\(appInfo.appID)-x86\"/>
            </choice>
            <pkg-ref id=\"\(appInfo.appID)-x86\" version=\"\(appInfo.appVersion)\" onConclusion=\"none\">component-x86.pkg</pkg-ref>
        </installer-gui-script>
        """

        do {
            try xml.write(toFile: distributionXML, atomically: true, encoding: .utf8)
        } catch {
            Logger.log("Failed to write distribution.xml - \(error)", logType: logType)
            return nil
        }

        finalPackagePath = "\(outputDir)/\(appInfo.appName)-\(appInfo.appVersion)-universal.pkg"

        let _ = runProcess(["/usr/bin/productbuild",
                            "--distribution", distributionXML,
                            "--package-path", tempDir,
                            finalPackagePath])

        if fileManager.fileExists(atPath: finalPackagePath) {
            return (finalPackagePath, appInfo.appName, appInfo.appID, appInfo.appVersion)
        } else {
            Logger.log("Universal package creation failed.", logType: logType)
            return nil
        }
    }

    /// Modifies the component plist to set BundleIsRelocatable to false
    /// Ensures the app installs to /Applications and cannot be relocated
    /// - Parameter path: Path to the component plist file
    /// - Returns: True if modification was successful, false otherwise
    private func modifyComponentPlist(at path: String) -> Bool {
        guard let plistData = NSMutableArray(contentsOfFile: path) else {
            Logger.log("Error: Unable to read component plist.", logType: logType)
            return false
        }
        
        for case let bundle as NSMutableDictionary in plistData {
            bundle["BundleIsRelocatable"] = false
        }
        
        return plistData.write(toFile: path, atomically: true)
    }

    
    /// Extracts essential metadata from an application's Info.plist file
    /// - Parameter appPath: Path to the .app bundle
    /// - Returns: Tuple with app name, bundle ID, and version, or nil on failure
    private func extractAppInfo(from appPath: String) -> (appName: String, appID: String, appVersion: String)? {
        let infoPlistPath = "\(appPath)/Contents/Info.plist"
        guard let plistData = NSDictionary(contentsOfFile: infoPlistPath),
              let appID = plistData["CFBundleIdentifier"] as? String,
              let appVersion = plistData["CFBundleShortVersionString"] as? String,
              let appName = plistData["CFBundleName"] as? String else {
            return nil
        }
        return (appName, appID, appVersion)
    }

    /// Executes a command-line process with arguments and logs output
    /// - Parameter args: Array where first element is the command path and rest are arguments
    /// - Returns: True if process completed successfully (exit code 0), false otherwise
    private func runProcess(_ args: [String]) -> Bool {
        let process = Process()
        process.launchPath = args[0]
        process.arguments = Array(args.dropFirst())
        
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe
        
        process.launch()
        process.waitUntilExit()
        
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outputData, encoding: .utf8) ?? ""
        
        Logger.log("Command output: \(output)", logType: logType)

        return process.terminationStatus == 0
    }
}



// MARK: - Usage Examples

// Example usage
/*
 
 let creator = PKGCreatorUniversal()
 if let result = creator.createUniversalPackage(inputPathArm64: pathToArmApp, inputPathx86_64: pathToX86App, outputDir: outputPath) {
     print("✅ Created: \(result.packagePath)")
     print("📦 App: \(result.appName), ID: \(result.appID), Version: \(result.appVersion)")
 } else {
     print("❌ Universal package creation failed.")
 }
 
 
result is a tuple:
 •    result.packagePath: full path to the .pkg file
 •    result.appName: from CFBundleName
 •    result.appID: from CFBundleIdentifier
 •    result.appVersion: from CFBundleShortVersionString

 
 
 •    You can destructure the tuple too if you prefer:
 if let (pkgPath, name, id, version) = pkgCreator.createPackage(inputPath: ..., outputDir: ...) {
     // use pkgPath, name, id, version directly
 }
 
 */
