//
//  PKGCreator.swift
//  Intuneomator
//
//  Created by Gil Burns on 2/15/25.
//

import Foundation

class PKGCreator {

    // MARK: - Main Logic
    
    func createPackage(inputPath: String, outputDir: String?) -> (packagePath: String, appName: String, appID: String, appVersion: String)? {
        
        Logger.log("Input path: \(inputPath)", logType: "PKGCreator")
        Logger.log("Output directory: \(String(describing: outputDir))", logType: "PKGCreator")
        
        
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
            let unzippedPath = "\(NSTemporaryDirectory())/unzipped"
            if fileManager.fileExists(atPath: unzippedPath) {
                try? fileManager.removeItem(atPath: unzippedPath)
            }
            let extractedPath = "\(NSTemporaryDirectory())/extracted"
            if fileManager.fileExists(atPath: extractedPath) {
                try? fileManager.removeItem(atPath: extractedPath)
            }
        }

        if inputPath.hasSuffix(".dmg") {
            guard let mountedPoint = mountDMG(at: inputPath) else {
                Logger.log("Error: Failed to mount .dmg file.", logType: "PKGCreator")
                return nil
            }
            mountPoint = mountedPoint

            guard let foundApp = findApp(in: mountedPoint) else {
                Logger.log("Error: Unable to locate .app in .dmg.", logType: "PKGCreator")
                return nil
            }
            appPath = foundApp
        } else if inputPath.hasSuffix(".zip") {
            guard let unzippedPath = extractZip(at: inputPath, to: NSTemporaryDirectory()) else {
                Logger.log("Error: Unable to extract .zip.", logType: "PKGCreator")
                return nil
            }
            if let foundDMG = findDMG(in: unzippedPath) {
                guard let mountedPoint = mountDMG(at: foundDMG) else {
                    Logger.log("Error: Failed to mount .dmg found in .zip.", logType: "PKGCreator")
                    return nil
                }
                mountPoint = mountedPoint

                guard let foundApp = findApp(in: mountedPoint) else {
                    Logger.log("Error: Unable to locate .app in .dmg found in .zip.", logType: "PKGCreator")
                    return nil
                }
                appPath = foundApp
            } else if let foundApp = findApp(in: unzippedPath) {
                appPath = foundApp
            } else {
                Logger.log("Error: No .app or .dmg found in .zip.", logType: "PKGCreator")
                return nil
            }
        } else if inputPath.hasSuffix(".tbz") {
            guard let extractedPath = extractTBZ(at: inputPath, to: NSTemporaryDirectory()),
                  let foundApp = findApp(in: extractedPath) else {
                Logger.log("Error: Unable to locate .app in .tbz.", logType: "PKGCreator")
                return nil
            }
            appPath = foundApp
        } else if inputPath.hasSuffix(".app") {
            appPath = inputPath
        } else {
            Logger.log("Error: Input file must be a .app, .dmg, .zip, or .tbz.", logType: "PKGCreator")
            return nil
        }

        guard let appPath = appPath,
              let appInfo = extractAppInfo(from: appPath) else {
            Logger.log("Error: Failed to process app.", logType: "PKGCreator")
            return nil
        }

        do {
            tempDir = "\(NSTemporaryDirectory())/temp-\(UUID().uuidString)"
            try fileManager.createDirectory(atPath: tempDir!, withIntermediateDirectories: true)
        } catch {
            Logger.log("Error: Failed to create temporary directory - \(error)", logType: "PKGCreator")
            return nil
        }

        guard let packageRoot = preparePackageRoot(appPath: appPath, tempDir: tempDir!),
              let componentPlistPath = analyzeComponentPlist(for: packageRoot, tempDir: tempDir!),
              modifyComponentPlist(at: componentPlistPath),
              let componentPackage = createComponentPackage(from: packageRoot, tempDir: tempDir!, appName: appInfo.appName, appID: appInfo.appID, appVersion: appInfo.appVersion, componentPlistPath: componentPlistPath),
              let distributionXML = synthesizeDistributionXML(for: componentPackage, tempDir: tempDir!, appName: appInfo.appName, appVersion: appInfo.appVersion) else {
            return nil
        }

        let finalPackagePath = createDistributionPackage(with: distributionXML, tempDir: tempDir!, appName: appInfo.appName, appVersion: appInfo.appVersion, appArch: appInfo.appArch, outputDir: outputDirectory)

        guard !finalPackagePath.isEmpty else {
            return nil
        }

        outputPackagePath = finalPackagePath
        appName = appInfo.appName
        appID = appInfo.appID
        appVersion = appInfo.appVersion

        return (outputPackagePath, appName, appID, appVersion)
    }


    // MARK: - Helper Functions
    
    func getAppArchitecture(appPath: String) -> String? {
        let infoPlistPath = appPath + "/Contents/Info.plist"
        let macOSPath = appPath + "/Contents/MacOS"
        
        // Load the Info.plist
        guard let plistData = FileManager.default.contents(atPath: infoPlistPath),
              let plist = try? PropertyListSerialization.propertyList(from: plistData, options: [], format: nil),
              let plistDict = plist as? [String: Any],
              let executableName = plistDict["CFBundleExecutable"] as? String else {
            print("Unable to read Info.plist or CFBundleExecutable key.")
            return nil
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
            print("Failed to run file command: \(error)")
            return nil
        }
        
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        if output.contains("arm64") && output.contains("x86_64") {
            return "universal"
        } else if output.contains("arm64") {
            return "arm64"
        } else if output.contains("x86_64") {
            return "x86_64"
        } else {
            return nil
        }
    }

    
    private func dmgHasSLA(at path: String) -> Bool {
        let process = Process()
        process.launchPath = "/usr/bin/hdiutil"
        process.arguments = ["imageinfo", path, "-plist"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.launch()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            Logger.log("Error: Failed to check for SLA in DMG.", logType: "PKGCreator")
            return false
        }

        let outputData = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let plist = try? PropertyListSerialization.propertyList(from: outputData, options: [], format: nil) as? [String: Any],
              let properties = plist["Properties"] as? [String: Any],
              let hasSLA = properties["Software License Agreement"] as? Bool else {
            return false
        }

        return hasSLA
    }

    
    private func mountDMG(at path: String) -> String? {
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
            Logger.log("Error: Failed to launch hdiutil: \(error)", logType: "PKGCreator")
            return nil
        }

        // If SLA, agree and quit pager, else just close input
        if dmgHasSLA(at: path) {
            let handle = inputPipe.fileHandleForWriting
            DispatchQueue.global().async {
                // Agree to license
                handle.write(Data("Y\n".utf8))
                // Short pause to allow paging
                Thread.sleep(forTimeInterval: 0.1)
                // Quit the license viewer
                handle.write(Data("q\n".utf8))
                handle.closeFile()
            }
        } else {
            inputPipe.fileHandleForWriting.closeFile()
        }

        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let errorOutput = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "Unknown error"
            Logger.log("Error: Failed to mount .dmg file. \(errorOutput)", logType: "PKGCreator")
            return nil
        }

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        guard let plist = try? PropertyListSerialization.propertyList(from: outputData, options: [], format: nil) as? [String: Any],
              let systemEntities = plist["system-entities"] as? [[String: Any]] else {
            Logger.log("Error: Failed to parse hdiutil output.", logType: "PKGCreator")
            return nil
        }

        for entity in systemEntities {
            if let mountPoint = entity["mount-point"] as? String {
                return mountPoint
            }
        }

        Logger.log("Error: No mount point found.", logType: "PKGCreator")
        return nil
    }

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

            Logger.log("unmountDMG Command output: \(output)", logType: "PKGCreator")
        }
    }

    private func extractZip(at path: String, to tempDir: String) -> String? {
        let fileManager = FileManager.default
        let destinationPath = "\(tempDir)/unzipped"
        do {
            // Clean up existing unzipped directory if it exists
            if fileManager.fileExists(atPath: destinationPath) {
                try fileManager.removeItem(atPath: destinationPath)
            }
            try fileManager.createDirectory(atPath: destinationPath, withIntermediateDirectories: true)
            let process = Process()
//            process.launchPath = "/usr/bin/unzip"
            process.launchPath = "/usr/bin/ditto"
//            process.arguments = [path, "-d", destinationPath]
            process.arguments = ["-x", "-k", path, destinationPath]

            let outputPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = outputPipe

            do {
                process.launch()
                process.waitUntilExit()
                
                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: outputData, encoding: .utf8) ?? ""

                Logger.log("extractZip Command output: \(output)", logType: "PKGCreator")
            }
            
            guard process.terminationStatus == 0 else {
                Logger.log("Error: Failed to extract .zip file.", logType: "PKGCreator")
                return nil
            }
        } catch {
            Logger.log("Error: Failed to prepare extraction directory - \(error)", logType: "PKGCreator")
            return nil
        }
        return destinationPath
    }

    private func extractTBZ(at path: String, to tempDir: String) -> String? {
        let fileManager = FileManager.default
        let destinationPath = "\(tempDir)/extracted"
        do {
            // Clean up existing extracted directory if it exists
            if fileManager.fileExists(atPath: destinationPath) {
                try fileManager.removeItem(atPath: destinationPath)
            }
            try fileManager.createDirectory(atPath: destinationPath, withIntermediateDirectories: true)
            let process = Process()
            process.launchPath = "/usr/bin/tar"
            process.arguments = ["-xf", path, "-C", destinationPath]

            let outputPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = outputPipe

            do {
                process.launch()
                process.waitUntilExit()
                
                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: outputData, encoding: .utf8) ?? ""

                Logger.log("extractTBZ Command output: \(output)", logType: "PKGCreator")
            }

            guard process.terminationStatus == 0 else {
                Logger.log("Error: Failed to extract .tbz file.", logType: "PKGCreator")
                return nil
            }
        } catch {
            Logger.log("Error: Failed to prepare extraction directory - \(error)", logType: "PKGCreator")
            return nil
        }
        return destinationPath
    }

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

    private func extractAppInfo(from appPath: String) -> (appName: String, appID: String, appVersion: String, appArch: String)? {
        let infoPlistPath = "\(appPath)/Contents/Info.plist"
        guard let plistData = NSDictionary(contentsOfFile: infoPlistPath),
              let appID = plistData["CFBundleIdentifier"] as? String,
              let appVersion = plistData["CFBundleShortVersionString"] as? String,
              let appName = plistData["CFBundleName"] as? String else {
            Logger.log("Error: Unable to read Info.plist from \(appPath).", logType: "PKGCreator")
            return nil
        }
        
        
        let appArch: String = getAppArchitecture(appPath: appPath) ?? "unknown"

        Logger.log("appName \(appName)", logType: "PKGCreator")
        Logger.log("appID \(appID)", logType: "PKGCreator")
        Logger.log("appVersion \(appVersion)", logType: "PKGCreator")
        Logger.log("appArch \(appArch)", logType: "PKGCreator")

        
        return (appName, appID, appVersion, appArch)
    }

    private func preparePackageRoot(appPath: String, tempDir: String) -> String? {
        let packageRoot = "\(tempDir)/root"
        let applicationsPath = "\(packageRoot)/Applications"
        let fileManager = FileManager.default
        do {
            try fileManager.createDirectory(atPath: applicationsPath, withIntermediateDirectories: true)
            let destinationPath = "\(applicationsPath)/\((appPath as NSString).lastPathComponent)"
            try fileManager.copyItem(atPath: appPath, toPath: destinationPath)
        } catch {
            Logger.log("Error: Failed to prepare package root - \(error)", logType: "PKGCreator")
            return nil
        }
        return packageRoot
    }

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

            Logger.log("analyzeComponentPlist Command output: \(output)", logType: "PKGCreator")
        }
        
        guard process.terminationStatus == 0 else {
            Logger.log("Error: Failed to analyze component plist.", logType: "PKGCreator")
            return nil
        }
        return componentPlistPath
    }

    private func modifyComponentPlist(at path: String) -> Bool {
        guard let plistData = NSMutableArray(contentsOfFile: path) else {
            Logger.log("Error: Unable to read component plist.", logType: "PKGCreator")
            return false
        }
        
        for case let bundle as NSMutableDictionary in plistData {
            bundle["BundleIsRelocatable"] = false
        }
        
        return plistData.write(toFile: path, atomically: true)
    }

    private func createComponentPackage(from packageRoot: String, tempDir: String, appName: String, appID: String, appVersion: String, componentPlistPath: String) -> String? {
        let packagePath = "\(tempDir)/\(appName)-\(appVersion)-component.pkg"
        let process = Process()
        process.launchPath = "/usr/bin/pkgbuild"
        process.arguments = [
            "--root", packageRoot,
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

            Logger.log("createComponentPackage Command output: \(output)", logType: "PKGCreator")
        }
        
        guard process.terminationStatus == 0 else {
            Logger.log("Error: Failed to create component package.", logType: "PKGCreator")
            return nil
        }
        return packagePath
    }

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

            Logger.log("synthesizeDistributionXML Command output: \(output)", logType: "PKGCreator")
        }

        guard process.terminationStatus == 0 else {
            Logger.log("Error: Failed to synthesize distribution.xml.", logType: "PKGCreator")
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
            Logger.log("Error: Failed to modify distribution.xml - \(error)", logType: "PKGCreator")
            return nil
        }

        return distributionXMLPath
    }

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

            Logger.log("createDistributionPackage Command output: \(output)", logType: "PKGCreator")
        }
        
        if process.terminationStatus == 0 {
            Logger.log("Distribution package created successfully at \(outputPackagePath)", logType: "PKGCreator")
            return outputPackagePath
        } else {
            Logger.log("Error: Failed to create distribution package.", logType: "PKGCreator")
            return ""
        }
    }
}



// MARK: - Usage Examples

// Example usage
/*
 
 let pkgCreator = PKGCreator()
 if let result = pkgCreator.createPackage(inputPath: "/path/to/source.dmg", outputDir: "/path/to/output") {
     print("Package created successfully at: \(result.packagePath)")
     print("App Name: \(result.appName)")
     print("App ID: \(result.appID)")
     print("App Version: \(result.appVersion)")
 } else {
     print("Package creation failed.")
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
