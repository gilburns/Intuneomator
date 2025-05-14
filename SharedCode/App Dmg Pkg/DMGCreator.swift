//
//  DMGCreator.swift
//  Intuneomator
//
//  Created by Gil Burns on 2/15/25.
//

import Foundation

class DMGCreator {

    // MARK: - Main Logic

    // Process the input path and generate the DMG
    func processToDMG(inputPath: String, outputDirectory: String?) throws -> (dmgPath: String, appName: String, appID: String, appVersion: String) {
        
        Logger.log("processing \(inputPath)", logType: "DMGCreator")
        Logger.log("Output \(String(describing: outputDirectory))", logType: "DMGCreator")

        let tempDir = NSTemporaryDirectory() + UUID().uuidString
        
        defer {
            // Cleanup in a defer block to ensure it runs regardless of success/failure
            do {
                try FileManager.default.removeItem(atPath: tempDir)
            } catch {
                Logger.log("Warning: Failed to clean up temporary directory: \(error.localizedDescription)", logType: "DMGCreator")
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

        let appArch: String = getAppArchitecture(appPath: appPath) ?? "unknown"

        Logger.log("appName \(appName)", logType: "DMGCreator")
        Logger.log("appID \(appID)", logType: "DMGCreator")
        Logger.log("appVersion \(appVersion)", logType: "DMGCreator")
        Logger.log("appArch \(appArch)", logType: "DMGCreator")

        
        // Determine output directory
        let outputDir = outputDirectory ?? (inputPath as NSString).deletingLastPathComponent
        let dmgPath = (outputDir as NSString).appendingPathComponent("\(appName)-\(appVersion)-\(appArch).dmg")

        // Create the DMG
        do {
            try createDMG(fromApp: appPath, outputDirectory: outputDir)
        } catch {
            Logger.log("Failed to create DMG: \(error.localizedDescription)", logType: "DMGCreator")
        }
        return (dmgPath: dmgPath, appName: appName, appID: appID, appVersion: appVersion)
    }
    
    
    // MARK: - Helper Functions

    private func showUsage() {
        print("""
        Usage: intuneomator_dmg_tool <input path> <output directory>
        - <input path>: Path to a .app, .zip, or .tbz containing a .app
        - <output directory>: Directory where the output .dmg will be saved
        """)
        exit(1)
    }


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
    
    // Helper function to run shell commands
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
            
            Logger.log("Command output: \(output)", logType: "DMGCreator")
        } catch {
            Logger.log("Error running command: \(error)", logType: "DMGCreator")
            throw NSError(domain: "ShellCommandError", code: Int(process.terminationStatus), userInfo: nil)
        }
        
        if process.terminationStatus != 0 {
            throw NSError(domain: "ShellCommandError", code: Int(process.terminationStatus), userInfo: nil)
        }
    }

    // Extract .zip or .tbz files
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

    // Get CFBundleShortVersionString from an .app
    private func getAppVersion(fromApp appPath: String) throws -> String {
        let infoPlistPath = appPath + "/Contents/Info.plist"
        guard let infoPlist = NSDictionary(contentsOfFile: infoPlistPath),
              let version = infoPlist["CFBundleShortVersionString"] as? String else {
            throw NSError(domain: "AppVersionError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to read CFBundleShortVersionString from Info.plist"])
        }
        return version
    }

    // Create an APFS DMG containing the app
    private func createDMG(fromApp appPath: String, outputDirectory: String) throws {
        let appName = (appPath as NSString).lastPathComponent.replacingOccurrences(of: ".app", with: "")
        let appVersion = try getAppVersion(fromApp: appPath)
        let appArch = getAppArchitecture(appPath: appPath)
        let outputDMGPath = (outputDirectory as NSString).appendingPathComponent("\(appName)-\(appVersion)-\(appArch ?? "unknown").dmg")
        
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
            Logger.log("DMG created successfully at \(outputDMGPath)", logType: "DMGCreator")
        } catch {
            Logger.log("Error creating DMG: \(error)", logType: "DMGCreator")
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

