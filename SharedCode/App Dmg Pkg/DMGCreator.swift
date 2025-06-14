//
//  DMGCreator.swift
//  Intuneomator
//
//  Created by Gil Burns on 2/15/25.
//

import Foundation

/// Creates disk image (.dmg) files from macOS applications
/// Supports processing .app bundles, .zip archives, and .tbz archives containing applications
/// Generates compressed APFS disk images with embedded application metadata
class DMGCreator {
    
    // MARK: - Main Logic

    /// Processes an input file (.app, .zip, or .tbz) and creates a compressed DMG
    /// - Parameters:
    ///   - inputPath: Path to the application bundle or archive containing an app
    ///   - outputDirectory: Optional output directory (defaults to input file's directory)
    /// - Returns: Tuple containing DMG path, app name, bundle ID, and version
    /// - Throws: Various errors for invalid input, extraction failures, or DMG creation issues
    func processToDMG(inputPath: String, outputDirectory: String?) throws -> (dmgPath: String, appName: String, appID: String, appVersion: String) {
        
        let tempDir = NSTemporaryDirectory() + UUID().uuidString
        
        defer {
            // Cleanup in a defer block to ensure it runs regardless of success/failure
            do {
                try FileManager.default.removeItem(atPath: tempDir)
            } catch {
                log("Warning: Failed to clean up temporary directory: \(error.localizedDescription)")
            }
        }
        
        // Create a temporary directory
        try FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true, attributes: nil)

        let appPath: String

        if inputPath.hasSuffix(".zip") || inputPath.hasSuffix(".tbz") {
            appPath = try extractArchive(atPath: inputPath, to: tempDir)
        } else if inputPath.hasSuffix(".app") {
            appPath = inputPath
        } else {
            throw NSError(domain: "InvalidInputError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unsupported input type"])
        }

        // Extract app information
        let appName = (appPath as NSString).lastPathComponent.replacingOccurrences(of: ".app", with: "")
        let appVersion = try getAppVersion(fromApp: appPath)
        let infoPlistPath = appPath + "/Contents/Info.plist"
        let infoPlist = NSDictionary(contentsOfFile: infoPlistPath)
        guard let appID = infoPlist?["CFBundleIdentifier"] as? String else {
            throw NSError(domain: "AppInfoError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not retrieve app bundle identifier"])
        }

        let appArch: String = getAppArchitecture(appPath: appPath)
        
        guard appArch != "unknown" else {
            throw NSError(domain: "AppInfoError", code: 3, userInfo: [NSLocalizedDescriptionKey: "Could not determine app architecture"])
        }

        // Determine output directory
        let outputDir = outputDirectory ?? (inputPath as NSString).deletingLastPathComponent
        let dmgPath = (outputDir as NSString).appendingPathComponent("\(appName)-\(appVersion)-\(appArch).dmg")

        // Create the DMG
        do {
            try createDMG(fromApp: appPath, outputDirectory: outputDir)
        } catch {
            log("Failed to create DMG: \(error.localizedDescription)")
        }
        return (dmgPath: dmgPath, appName: appName, appID: appID, appVersion: appVersion)
    }
    
    
    // MARK: - Helper Functions

    /// Displays command-line usage information
    private func showUsage() {
        print("""
        Usage: intuneomator_dmg_tool <input path> <output directory>
        - <input path>: Path to a .app, .zip, or .tbz containing a .app
        - <output directory>: Directory where the output .dmg will be saved
        """)
        exit(1)
    }

    /// Logs messages to console
    /// Provides consistent logging format for update operations
    /// - Parameter message: Message to log
    func log(_ message: String) {
        Logger.info("\(message)", category: .automation)
        print("[DMGCreator] \(message)")
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
    
    /// Executes shell commands with error handling and logging
    /// - Parameters:
    ///   - command: Full path to the command executable
    ///   - arguments: Array of command arguments
    /// - Throws: NSError if command execution fails or returns non-zero exit status
    private func runShellCommand(_ command: String, arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = arguments

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        do {
            try process.run()
            process.waitUntilExit()
            
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: outputData, encoding: .utf8) ?? ""
            
            log("Command output: \(output)")
        } catch {
            log("Error running command: \(error)")
            throw NSError(domain: "ShellCommandError", code: Int(process.terminationStatus), userInfo: nil)
        }
        
        if process.terminationStatus != 0 {
            throw NSError(domain: "ShellCommandError", code: Int(process.terminationStatus), userInfo: nil)
        }
    }

    /// Extracts compressed archives (.zip or .tbz) and locates the contained .app bundle
    /// - Parameters:
    ///   - path: Path to the archive file
    ///   - destination: Directory to extract the archive contents
    /// - Returns: Path to the extracted .app bundle
    /// - Throws: Errors for unsupported archive types, extraction failures, or missing .app
    private func extractArchive(atPath path: String, to destination: String) throws -> String {
        let fileExtension = (path as NSString).pathExtension
        if fileExtension == "zip" {
            try runShellCommand("/usr/bin/ditto", arguments: ["-x", "-k", path, destination])
        } else if fileExtension == "tbz" {
            try runShellCommand("/usr/bin/tar", arguments: ["-xjf", path, "-C", destination])
        } else {
            throw NSError(domain: "InvalidArchiveError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unsupported archive type: \(fileExtension)"])
        }

        // Find the .app file inside the extracted folder
        let extractedContents = try FileManager.default.contentsOfDirectory(atPath: destination)
        if let appPath = extractedContents.first(where: { $0.hasSuffix(".app") }) {
            return destination + "/" + appPath
        } else {
            throw NSError(domain: "AppNotFoundError", code: 1, userInfo: [NSLocalizedDescriptionKey: ".app file not found in extracted contents"])
        }
    }

    /// Extracts the version string from an application's Info.plist file
    /// - Parameter appPath: Path to the .app bundle
    /// - Returns: Version string from CFBundleShortVersionString
    /// - Throws: Error if Info.plist cannot be read or version key is missing
    private func getAppVersion(fromApp appPath: String) throws -> String {
        let infoPlistPath = appPath + "/Contents/Info.plist"
        guard let infoPlist = NSDictionary(contentsOfFile: infoPlistPath),
              let version = infoPlist["CFBundleShortVersionString"] as? String else {
            throw NSError(domain: "AppVersionError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to read CFBundleShortVersionString from Info.plist"])
        }
        return version
    }

    /// Creates a compressed APFS disk image containing the application bundle
    /// Uses hdiutil to create a UDZO (compressed) format DMG with APFS filesystem
    /// - Parameters:
    ///   - appPath: Path to the .app bundle to include in the DMG
    ///   - outputDirectory: Directory where the DMG file will be created
    /// - Throws: Error if DMG creation fails
    private func createDMG(fromApp appPath: String, outputDirectory: String) throws {
        let appName = (appPath as NSString).lastPathComponent.replacingOccurrences(of: ".app", with: "")
        let appVersion = try getAppVersion(fromApp: appPath)
        let appArch = getAppArchitecture(appPath: appPath)
        let outputDMGPath = (outputDirectory as NSString)
            .appendingPathComponent("\(appName)-\(appVersion)-\(appArch).dmg")
        
        if FileManager.default.fileExists(atPath: outputDMGPath) {
            try FileManager.default.removeItem(atPath: outputDMGPath)
        }

        do {
            try runShellCommand("/usr/bin/hdiutil", arguments: [
                "create",
                "-fs", "APFS",
                "-srcfolder", appPath,
                "-volname", "\(appName)-\(appVersion)",
                "-format", "UDZO",
                "-nospotlight",
                "-anyowners",
                outputDMGPath
            ])
            log("DMG created successfully at \(outputDMGPath)")
        } catch {
            log("Error creating DMG: \(error)")
            return
        }
    }
}


// MARK: - Usage Examples

// Command-line interface usage:
/*
 if CommandLine.arguments.count < 2 {
     print("Usage: createDMG <input path> [output directory]")
     exit(1)
 }

 let dmgCreator = DMGCreator()
 let inputPath = "/Users/you/Downloads/MyApp.zip"
 let outputDir: String? = "/Users/you/Desktop/DMGs" // or `nil` to default to input location

 let result = dmgCreator.processToDMG(inputPath: inputPath, outputDirectory: outputDir)

 if let dmgPath = result.dmgPath {
     print("DMG created at: \(dmgPath)")
     print("App Name: \(result.appName ?? "Unknown")")
     print("App ID: \(result.appID ?? "Unknown")")
     print("App Version: \(result.appVersion ?? "Unknown")")
 } else {
     print("Failed to create DMG.")
 }
 
 
 
 Notes:
     •    You can pass nil for outputDirectory if you want the DMG to be saved in the same folder as the input file.
     •    The returned tuple gives you the .dmg path and relevant app metadata, or nil values if something failed.

 
 
 */

