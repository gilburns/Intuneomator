//
//  CLIAppPkgCreator.swift
//  Intuneomator
//
//  Created by Gil Burns on 2/20/26.
//

import Foundation

/// Creates macOS installer packages (.pkg) from for an application source that installs via CLI
/// Supports processing app bundles and associated resources
/// Generates distribution packages with proper installer configuration for system installation
class CLIAppPkgCreator {
    
    // MARK: - Main Logic
    
    /// Creates a macOS installer package from an application source
    /// - Parameters:
    ///   - inputPath: Path to the source dmg
    ///   - outputDir: Optional output directory (defaults to input file's directory)
    ///   - applicationID: The bundle ID of the application
    ///   - appCLI: The Command Line Installer path
    ///   - appArgs: The arguments to pass to the command line installer tool
    /// - Returns: Tuple containing package path, app name, bundle ID, and version, or nil on failure
    func createPackage(inputPath: String, outputDir: String?, applicationID: String, appCLI: String, appArgs: String) async -> (packagePath: String, appName: String, appID: String, appVersion: String)? {
        
        let fileManager = FileManager.default
        let outputDirectory = outputDir ?? (inputPath as NSString).deletingLastPathComponent
        var tempDir: String?
        var mountPoint: String?
        var appPath: String?
        
        // Output values
        var outputPackagePath: String = ""
        var appName: String = ""
        var appID: String = ""
        var appVersion: String = ""

        defer {
            if let tempDir = tempDir {
                try? fileManager.removeItem(atPath: tempDir)
            }
            if let mountPoint = mountPoint {
                unmountDMG(at: mountPoint)
            }
        }

        if inputPath.hasSuffix(".dmg") {
            guard let mountedPoint = await mountDMG(at: inputPath) else {
                log("Error: Failed to mount .dmg file.")
                return nil
            }
            mountPoint = mountedPoint

            guard let foundApp = findApp(in: mountedPoint) else {
                log("Error: Unable to locate .app in .dmg.")
                return nil
            }
            appPath = foundApp
        } else {
            log("Error: Input file must be a .dmg.")
            return nil
        }

        guard let appPath = appPath else {
            log("Error: Failed to process app.")
            return nil
        }

        do {
            tempDir = "\(NSTemporaryDirectory())/temp-\(UUID().uuidString)"
            try fileManager.createDirectory(atPath: tempDir!, withIntermediateDirectories: true)
        } catch {
            log("Error: Failed to create temporary directory - \(error)")
            return nil
        }

        guard let packageRoot = preparePackageRoot(appPath: appPath, tempDir: tempDir!),
              let scriptRoot = prepareScriptRoot(tempDir: tempDir!, cliPath: appCLI, cliArgs: appArgs),
              let appInfo = extractAppInfo(from: appPath),
              let componentPlistPath = analyzeComponentPlist(for: packageRoot, tempDir: tempDir!),
              modifyComponentPlist(at: componentPlistPath),
              let componentPackage = createComponentPackage(from: packageRoot, scriptRoot: scriptRoot, tempDir: tempDir!, appName: appInfo.name, appID: applicationID, appVersion: appInfo.version, componentPlistPath: componentPlistPath),
              let distributionXML = synthesizeDistributionXML(for: componentPackage, tempDir: tempDir!, appName: appInfo.name, appVersion: appInfo.version) else {
            return nil
        }

        let finalPackagePath = createDistributionPackage(with: distributionXML, tempDir: tempDir!, appName: appInfo.name, appVersion: appInfo.version, appArch: appInfo.arch, outputDir: outputDirectory)

        guard !finalPackagePath.isEmpty else {
            return nil
        }

        outputPackagePath = finalPackagePath
        appName = appInfo.name
        appID = appInfo.appID
        appVersion = appInfo.version

        return (outputPackagePath, appName, appID, appVersion)
    }


    // MARK: - Helper Functions
    
    /// Logs messages to console
    /// Provides consistent logging format for update operations
    /// - Parameter message: Message to log
    func log(_ message: String) {
        print("[CLIAppPkgCreator] \(message)")
        Logger.info("\(message)", category: .automation)
    }
    
    /// Determines the architecture of a macOS application bundle
    /// - Parameter appPath: Path to the .app bundle
    /// - Returns: Architecture string ("universal", "arm64", "x86_64") or "unknown" if undetermined
    func getAppArchitecture(appPath: String) -> String {
        let infoPlistPath = appPath + "/Contents/Info.plist"
        let macOSPath = appPath + "/Contents/MacOS"
        
        // Load the Info.plist
        guard let plistData = FileManager.default.contents(atPath: infoPlistPath),
              let plist = try? PropertyListSerialization.propertyList(from: plistData, options: [], format: nil),
              let plistDict = plist as? [String: Any],
              let executableName = plistDict["CFBundleExecutable"] as? String else {
            log("Unable to read Info.plist or CFBundleExecutable key.")
            return "unknown"
        }
        
        let fullExecutablePath = "\(macOSPath)/\(executableName)"
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/file")
        process.arguments = [fullExecutablePath]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        do {
            try process.run()
        } catch {
            log("Failed to run file command: \(error)")
            return "unknown"
        }
        
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else {
            return "unknown"
        }
        
        if output.contains("arm64") && output.contains("x86_64") {
            return "universal"
        } else if output.contains("arm64") {
            return "arm64"
        } else if output.contains("x86_64") {
            return "x86_64"
        } else {
            return "unknown"
        }
    }

    /// Mounts a DMG file
    /// - Parameter path: Path to the DMG file to mount
    /// - Returns: Mount point path if successful, nil otherwise
    private func mountDMG(at path: String) async -> String? {
        let process = Process()
        process.launchPath = "/usr/bin/hdiutil"
        process.arguments = ["attach", path, "-plist", "-mountrandom", "/private/tmp", "-nobrowse"]

        // Always create inputPipe and assign to process.standardInput
        let inputPipe = Pipe()
        process.standardInput = inputPipe

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        let errorPipe = Pipe()
        process.standardError = errorPipe

        do {
            try process.run()
        } catch {
            log("Error: Failed to launch hdiutil: \(error)")
            return nil
        }

        inputPipe.fileHandleForWriting.closeFile()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let errorOutput = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "Unknown error"
            log("Error: Failed to mount .dmg file. \(errorOutput)")
            return nil
        }

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        guard let plist = try? PropertyListSerialization.propertyList(from: outputData, options: [], format: nil) as? [String: Any],
              let systemEntities = plist["system-entities"] as? [[String: Any]] else {
            log("Error: Failed to parse hdiutil output.")
            return nil
        }

        for entity in systemEntities {
            if let mountPoint = entity["mount-point"] as? String {
                return mountPoint
            }
        }

        log("Error: No mount point found.")
        return nil
    }

    /// Unmounts a previously mounted DMG file
    /// - Parameter mountPoint: The mount point path to unmount
    private func unmountDMG(at mountPoint: String) {
        let process = Process()
        process.launchPath = "/usr/bin/hdiutil"
        process.arguments = ["detach", mountPoint, "-quiet"]
        
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        do {
            process.launch()
            process.waitUntilExit()
            
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: outputData, encoding: .utf8) ?? ""

            log("unmountDMG Command output: \(output)")
        }
    }

    /// Searches for a DMG file within a directory
    /// - Parameter directory: Directory path to search
    /// - Returns: Path to first DMG file found, or nil if none found
    private func findDMG(in directory: String) -> String? {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(atPath: directory) else { return nil }

        while let item = enumerator.nextObject() as? String {
            if item.hasSuffix(".dmg") {
                return "\(directory)/\(item)"
            }
        }
        return nil
    }

    /// Searches for an application bundle within a directory
    /// - Parameter directory: Directory path to search
    /// - Returns: Path to first .app bundle found, or nil if none found
    private func findApp(in directory: String) -> String? {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(atPath: directory) else { return nil }

        while let item = enumerator.nextObject() as? String {
            if item.hasSuffix(".app") {
                return "\(directory)/\(item)"
            }
        }
        return nil
    }

    /// Extracts metadata from an application's Info.plist file
    /// - Parameter appPath: Path to the .app bundle
    /// - Returns: Tuple with app name, bundle ID, version, and architecture, or nil on failure
    private func extractAppInfo(from appPath: String) -> (name: String, appID: String, version: String, arch: String)? {
        let infoPlistPath = "\(appPath)/Contents/Info.plist"
        guard let plistData = NSDictionary(contentsOfFile: infoPlistPath),
              let appID = plistData["CFBundleIdentifier"] as? String,
              let appVersion = plistData["CFBundleShortVersionString"] as? String,
              let appName = plistData["CFBundleName"] as? String else {
            log("Error: Unable to read Info.plist from \(appPath).")
            return nil
        }
        
        let appArch: String = getAppArchitecture(appPath: appPath)
        
        return (appName, appID, appVersion, appArch)
    }

    /// Prepares the package root directory structure for installer creation
    /// Creates /Applications structure and copies the app bundle and all other files/folders from the same directory
    /// - Parameters:
    ///   - appPath: Path to the source .app bundle
    ///   - tempDir: Temporary directory for package preparation
    /// - Returns: Path to package root directory or nil on failure
    private func preparePackageRoot(appPath: String, tempDir: String) -> String? {
        let packageRoot = "\(tempDir)/root"
        let applicationsPath = "\(packageRoot)/private/tmp/com.installomator.cliInstall"
        let fileManager = FileManager.default
        
        do {
            try fileManager.createDirectory(atPath: applicationsPath, withIntermediateDirectories: true)
            
            // Get the parent directory of the app
            let appParentDirectory = (appPath as NSString).deletingLastPathComponent
            
            // Get all items in the parent directory
            let allItems = try fileManager.contentsOfDirectory(atPath: appParentDirectory)
            
            // Copy all items (including the app and any other files/folders) to the applications path
            for item in allItems {
                let sourcePath = "\(appParentDirectory)/\(item)"
                let destinationPath = "\(applicationsPath)/\(item)"
                
                // Skip if destination already exists (shouldn't happen in temp directories, but safety check)
                if fileManager.fileExists(atPath: destinationPath) {
                    try fileManager.removeItem(atPath: destinationPath)
                }
                
                try fileManager.copyItem(atPath: sourcePath, toPath: destinationPath)
                log("Copied item: \(item)")
            }
            
            log("Successfully copied \(allItems.count) items from \(appParentDirectory) to \(applicationsPath)")
            
        } catch {
            log("Error: Failed to prepare package root - \(error)")
            return nil
        }
        return packageRoot
    }

    /// Prepares the script directory structure for installer creation
    /// Creates scripts structure and postinstall script in the same directory
    /// - Parameters:
    ///   - tempDir: Temporary directory for package preparation
    /// - Returns: Path to scripts directory or nil on failure
    private func prepareScriptRoot(tempDir: String, cliPath: String, cliArgs: String) -> String? {
        let scriptsPath = "\(tempDir)/Scripts"
        let fileManager = FileManager.default
        
        do {
            try fileManager.createDirectory(atPath: scriptsPath, withIntermediateDirectories: true)
            
            // Create the postinstall script content
            let postinstallScript = """
#!/bin/zsh

# Temp Directory
tempDir="/private/tmp/com.installomator.cliInstall"

# Install the Application
"${tempDir}/\(cliPath)" \(cliArgs)

# Get the exit code
exitCode=$?

# Clean up the Install app
/bin/rm -R "${tempDir}"

# Exit with the install exit code
exit "${exitCode}"
"""
            
            // Write the postinstall script to the Scripts directory
            let postinstallPath = "\(scriptsPath)/postinstall"
            try postinstallScript.write(toFile: postinstallPath, atomically: true, encoding: .utf8)
            
            // Make the postinstall script executable
            let attributes: [FileAttributeKey: Any] = [
                .posixPermissions: 0o755
            ]
            try fileManager.setAttributes(attributes, ofItemAtPath: postinstallPath)
            
            log("Successfully created postinstall script at \(postinstallPath)")
            
        } catch {
            log("Error: Failed to prepare script root - \(error)")
            return nil
        }
        return scriptsPath
    }

    /// Analyzes the package structure and creates component plist
    /// Uses pkgbuild --analyze to generate component configuration
    /// - Parameters:
    ///   - packageRoot: Path to the package root directory
    ///   - tempDir: Temporary directory for plist creation
    /// - Returns: Path to component plist file or nil on failure
    private func analyzeComponentPlist(for packageRoot: String, tempDir: String) -> String? {
        let componentPlistPath = "\(tempDir)/component.plist"
        let process = Process()
        process.launchPath = "/usr/bin/pkgbuild"
        process.arguments = ["--analyze", "--root", packageRoot, componentPlistPath]

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        do {
            process.launch()
            process.waitUntilExit()
            
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: outputData, encoding: .utf8) ?? ""

            log("analyzeComponentPlist Command output: \(output)")
        }
        
        guard process.terminationStatus == 0 else {
            log("Error: Failed to analyze component plist.")
            return nil
        }
        return componentPlistPath
    }

    /// Modifies the component plist to set BundleIsRelocatable to false
    /// Ensures the app installs to /Applications and cannot be relocated
    /// - Parameter path: Path to the component plist file
    /// - Returns: True if modification was successful, false otherwise
    private func modifyComponentPlist(at path: String) -> Bool {
        guard let plistData = NSMutableArray(contentsOfFile: path) else {
            log("Error: Unable to read component plist.")
            return false
        }
        
        for case let bundle as NSMutableDictionary in plistData {
            bundle["BundleIsRelocatable"] = false
        }
        
        return plistData.write(toFile: path, atomically: true)
    }

    /// Creates a component package using pkgbuild
    /// - Parameters:
    ///   - packageRoot: Path to the package root directory
    ///   - tempDir: Temporary directory for package creation
    ///   - appName: Application name for package naming
    ///   - appID: Bundle identifier for package identifier
    ///   - appVersion: Version string for package versioning
    ///   - componentPlistPath: Path to the component configuration plist
    /// - Returns: Path to created component package or nil on failure
    private func createComponentPackage(from packageRoot: String, scriptRoot: String, tempDir: String, appName: String, appID: String, appVersion: String, componentPlistPath: String) -> String? {
        let packagePath = "\(tempDir)/\(appName)-\(appVersion)-component.pkg"
        let process = Process()
        process.launchPath = "/usr/bin/pkgbuild"
        process.arguments = [
            "--root", packageRoot,
            "--scripts", scriptRoot,
            "--identifier", appID,
            "--version", appVersion,
            "--component-plist", componentPlistPath,
            packagePath
        ]
        
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        do {
            process.launch()
            process.waitUntilExit()
            
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: outputData, encoding: .utf8) ?? ""

            log("createComponentPackage Command output: \(output)")
        }
        
        guard process.terminationStatus == 0 else {
            log("Error: Failed to create component package.")
            return nil
        }
        return packagePath
    }

    /// Creates and customizes distribution XML for the installer
    /// Generates XML with title, domain restrictions, and installation options
    /// - Parameters:
    ///   - componentPackage: Path to the component package
    ///   - tempDir: Temporary directory for XML creation
    ///   - appName: Application name for installer title
    ///   - appVersion: Version string for installer title
    /// - Returns: Path to distribution XML file or nil on failure
    private func synthesizeDistributionXML(for componentPackage: String, tempDir: String, appName: String, appVersion: String) -> String? {
        let distributionXMLPath = "\(tempDir)/distribution.xml"
        let process = Process()
        process.launchPath = "/usr/bin/productbuild"
        process.arguments = ["--synthesize", "--package", componentPackage, distributionXMLPath]

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        do {
            process.launch()
            process.waitUntilExit()
            
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: outputData, encoding: .utf8) ?? ""

            log("synthesizeDistributionXML Command output: \(output)")
        }

        guard process.terminationStatus == 0 else {
            log("Error: Failed to synthesize distribution.xml.")
            return nil
        }

        // Modify the distribution.xml file with additional keys
        do {
            var xmlContent = try String(contentsOfFile: distributionXMLPath, encoding: .utf8)

            // Add title element after <installer-gui-script>
            if let startIndex = xmlContent.range(of: "<installer-gui-script")?.upperBound {
                let insertIndex = xmlContent.range(of: ">", range: startIndex..<xmlContent.endIndex)?.upperBound
                if let insertIndex = insertIndex {
                    let titleElement = "\n    <title>\(appName) - \(appVersion)</title>"
                    xmlContent.insert(contentsOf: titleElement, at: insertIndex)
                }
            }

            // Add domains element on its own line
            if let optionsIndex = xmlContent.range(of: "<options")?.lowerBound {
                let domainsElement = "\n    <domains enable_anywhere=\"false\" enable_currentUserHome=\"false\" enable_localSystem=\"true\"/>\n"
                xmlContent.insert(contentsOf: domainsElement, at: optionsIndex)
            }

            // Modify options element to append rootVolumeOnly="true"
            if let optionsRange = xmlContent.range(of: "<options [^>]*/>", options: .regularExpression) {
                let optionsElement = String(xmlContent[optionsRange])
                if !optionsElement.contains("rootVolumeOnly") {
                    let updatedOptions = optionsElement.replacingOccurrences(of: "/>", with: " rootVolumeOnly=\"true\" />")
                    xmlContent.replaceSubrange(optionsRange, with: updatedOptions)
                }
            }

            // Write the modified content back to the file
            try xmlContent.write(toFile: distributionXMLPath, atomically: true, encoding: .utf8)
        } catch {
            log("Error: Failed to modify distribution.xml - \(error)")
            return nil
        }

        return distributionXMLPath
    }

    /// Creates the final distribution package using productbuild
    /// - Parameters:
    ///   - distributionXML: Path to the distribution XML file
    ///   - tempDir: Temporary directory containing component packages
    ///   - appName: Application name for package naming
    ///   - appVersion: Version string for package naming
    ///   - appArch: Architecture string for package naming
    ///   - outputDir: Output directory for the final package
    /// - Returns: Path to created distribution package, or empty string on failure
    private func createDistributionPackage(with distributionXML: String, tempDir: String, appName: String, appVersion: String, appArch: String, outputDir: String) -> String {
        let outputPackagePath = "\(outputDir)/\(appName)-\(appVersion)-\(appArch).pkg"
        
        if FileManager.default.fileExists(atPath: outputPackagePath) {
            try? FileManager.default.removeItem(atPath: outputPackagePath)
        }
        
        let process = Process()
        process.launchPath = "/usr/bin/productbuild"
        process.arguments = [
            "--distribution", distributionXML,
            "--package-path", tempDir,
            outputPackagePath
        ]
        
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        do {
            process.launch()
            process.waitUntilExit()
            
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: outputData, encoding: .utf8) ?? ""

            log("createDistributionPackage Command output: \(output)")
        }
        
        if process.terminationStatus == 0 {
            log("Distribution package created successfully at \(outputPackagePath)")
            return outputPackagePath
        } else {
            log("Error: Failed to create distribution package.")
            return ""
        }
    }

}
