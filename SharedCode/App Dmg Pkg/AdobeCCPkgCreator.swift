//
//  AdobeCCPkgCreator.swift
//  Intuneomator
//
//  Created by Gil Burns on 7/5/25.
//

import Foundation

/// Creates macOS installer packages (.pkg) from for Adobe CC application source
/// Supports processing Adobe Installer app bundles and associated resources
/// Generates distribution packages with proper installer configuration for system installation
class AdobeCCPkgCreator {
    
    // MARK: - Main Logic
    
    /// Creates a macOS installer package from an application source
    /// - Parameters:
    ///   - inputPath: Path to the source dmg
    ///   - outputDir: Optional output directory (defaults to input file's directory)
    /// - Returns: Tuple containing package path, app name, bundle ID, and version, or nil on failure
    func createPackage(inputPath: String, outputDir: String?) async -> (packagePath: String, appName: String, appID: String, appVersion: String)? {
        
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
              let scriptRoot = prepareScriptRoot(tempDir: tempDir!),
              let adobeInfo = extractAdobeApplicationInfo(from: packageRoot),
              let componentPlistPath = analyzeComponentPlist(for: packageRoot, tempDir: tempDir!),
              modifyComponentPlist(at: componentPlistPath),
              let componentPackage = createComponentPackage(from: packageRoot, scriptRoot: scriptRoot, tempDir: tempDir!, appName: adobeInfo.name, appID: "com.adobe.acc.AdobeCreativeCloud", appVersion: adobeInfo.version, componentPlistPath: componentPlistPath),
              let distributionXML = synthesizeDistributionXML(for: componentPackage, tempDir: tempDir!, appName: adobeInfo.name, appVersion: adobeInfo.version) else {
            return nil
        }

        let finalPackagePath = createDistributionPackage(with: distributionXML, tempDir: tempDir!, appName: adobeInfo.name, appVersion: adobeInfo.version, appArch: adobeInfo.architecture, outputDir: outputDirectory)

        guard !finalPackagePath.isEmpty else {
            return nil
        }

        outputPackagePath = finalPackagePath
        appName = adobeInfo.name
        appID = "com.adobe.acc.AdobeCreativeCloud"
        appVersion = adobeInfo.version

        return (outputPackagePath, appName, appID, appVersion)
    }


    // MARK: - Helper Functions
    
    /// Logs messages to console
    /// Provides consistent logging format for update operations
    /// - Parameter message: Message to log
    func log(_ message: String) {
        print("[AdobePkgCreator] \(message)")
        Logger.info("\(message)", category: .automation)
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

    /// Extracts Adobe product name, architecture and version from ApplicationInfo.xml file
    /// Parses the XML file located in the packages directory to get Adobe-specific metadata
    /// - Parameter packageRoot: Path to the package root directory containing the copied Adobe files
    /// - Returns: Tuple with Adobe product name and version, or nil if file not found or parsing fails
    private func extractAdobeApplicationInfo(from packageRoot: String) -> (name: String, architecture: String, version: String)? {
        let applicationInfoPath = "\(packageRoot)/private/tmp/AdobeInstall/packages/ApplicationInfo.xml"
        
        // Check if the ApplicationInfo.xml file exists
        guard FileManager.default.fileExists(atPath: applicationInfoPath) else {
            log("Error: ApplicationInfo.xml not found at \(applicationInfoPath)")
            return nil
        }
        
        do {
            // Read the XML file content
            let xmlContent = try String(contentsOfFile: applicationInfoPath, encoding: .utf8)
            
            // Parse XML using XMLDocument
            let xmlDocument = try XMLDocument(xmlString: xmlContent, options: [])
            
            // Extract name element
            let nameNodes = try xmlDocument.nodes(forXPath: "//application/name")
            guard let nameNode = nameNodes.first,
                  let name = nameNode.stringValue else {
                log("Error: Unable to extract name from ApplicationInfo.xml")
                return nil
            }

            // Extract architecture element
            let archNodes = try xmlDocument.nodes(forXPath: "//application/platform")
            guard let archNodes = archNodes.first,
                  let arch = archNodes.stringValue else {
                log("Error: Unable to extract platform from ApplicationInfo.xml")
                return nil
            }
            
            let architecture: String
            switch arch {
            case "macarm64":
                architecture = "arm64"
            case "osx10":
                architecture = "x86_64"
            default:
                log("Error: Unknown architecture \(arch) from ApplicationInfo.xml")
                return nil
            }

            // Extract version element
            let versionNodes = try xmlDocument.nodes(forXPath: "//application/version")
            guard let versionNode = versionNodes.first,
                  let version = versionNode.stringValue else {
                log("Error: Unable to extract version from ApplicationInfo.xml")
                return nil
            }
            
            log("Successfully extracted Adobe application info - Name: \(name), Version: \(version)")
            return (name: name.trimmingCharacters(in: .whitespacesAndNewlines), architecture: architecture.trimmingCharacters(in: .whitespacesAndNewlines),
                   version: version.trimmingCharacters(in: .whitespacesAndNewlines))
            
        } catch {
            log("Error: Failed to parse ApplicationInfo.xml - \(error)")
            return nil
        }
    }

    /// Prepares the package root directory structure for installer creation
    /// Creates /Applications structure and copies the app bundle and all other files/folders from the same directory
    /// - Parameters:
    ///   - appPath: Path to the source .app bundle
    ///   - tempDir: Temporary directory for package preparation
    /// - Returns: Path to package root directory or nil on failure
    private func preparePackageRoot(appPath: String, tempDir: String) -> String? {
        let packageRoot = "\(tempDir)/root"
        let applicationsPath = "\(packageRoot)/private/tmp/AdobeInstall"
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
    private func prepareScriptRoot(tempDir: String) -> String? {
        let scriptsPath = "\(tempDir)/Scripts"
        let fileManager = FileManager.default
        
        do {
            try fileManager.createDirectory(atPath: scriptsPath, withIntermediateDirectories: true)
            
            // Create the postinstall script content
            let postinstallScript = """
#!/bin/zsh

# Temp Directory
tempDir="/private/tmp/AdobeInstall"

# Install the Adobe software
"${tempDir}/Install.app/Contents/MacOS/Install" --mode=silent

# Get the exit code
exitCode=$?

# Clean up the Adobe Install app
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
