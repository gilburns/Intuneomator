//
//  LabelAutomation.swift
//  Intuneomator
//
//  Created by Gil Burns on 3/28/25.
//

import Foundation

class LabelAutomation {
    static let logType = "LabelAutomation"

    // MARK: - Scan Folders to start the automation run
    static func scanAndValidateFolders() -> [String] {
        FolderScanner.scanAndValidateFolders()
    }
    
    
    // MARK: - Process label.sh for a given folder
    static func getIntuneomatorAppPath() -> String? {
        let possiblePaths = [
            "/Applications/Intuneomator.app",
            "\(NSHomeDirectory())/Applications/Intuneomator.app",
            "/usr/local/Intuneomator.app"
        ]
        
        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        
        Logger.log("❌ Could not find Intuneomator.app in expected locations.", logType: logType)
        return nil
    }
    
    
    static func containsArchCommand(filePath: String) -> Bool {
        do {
            // Attempt to read the contents of the file
            let fileContents = try String(contentsOfFile: filePath, encoding: .utf8)
            
            // Look for either "$(arch)" or "$(/usr/bin/arch)" in the file
            return fileContents.contains("$(arch)") || fileContents.contains("$(/usr/bin/arch)")
        } catch {
            Logger.log("Error reading file at \(filePath): \(error)", logType: logType)
            return false
        }
    }
    
    
    
    static func runProcessLabelScript(for folderName: String) -> Bool {
        return InstallomatorLabelProcessor.runProcessLabelScript(for: folderName)
    }
    
    // MARK: - Collect the plist data so we can download the file

    static func extractDataForProcessedAppResults(from folderName: String) -> ProcessedAppResults? {
        MetadataLoader.extractDataForProcessedAppResults(from: folderName)
    }    
    
    
    // MARK: Application Architecture
    enum AppArchitecture: String {
        case arm64
        case x86_64
        case universal
        case unknown
    }

    static func getAppArchitecture(at appURL: URL) throws -> AppArchitecture {
        // Load Info.plist to get the executable name
        let infoPlistURL = appURL.appendingPathComponent("Contents/Info.plist")
        let plistData = try Data(contentsOf: infoPlistURL)
        guard
            let plist = try PropertyListSerialization.propertyList(from: plistData, options: [], format: nil) as? [String: Any],
            let execName = plist["CFBundleExecutable"] as? String
        else {
            return .unknown
        }

        // Point to the actual binary
        let binaryURL = appURL
            .appendingPathComponent("Contents")
            .appendingPathComponent("MacOS")
            .appendingPathComponent(execName)

        // Call `/usr/bin/file` on that binary
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/file")
        process.arguments = ["-bL", binaryURL.path] // -b for brief, -L to follow symlinks

        let pipe = Pipe()
        process.standardOutput = pipe
        try process.run()
        process.waitUntilExit()

        let outputData = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: outputData, encoding: .utf8)?.lowercased() else {
            return .unknown
        }

        // Inspect the output
        let hasARM = output.contains("arm64")
        let hasX86 = output.contains("x86_64")

        switch (hasARM, hasX86) {
        case (true, true):
            return .universal
        case (true, false):
            return .arm64
        case (false, true):
            return .x86_64
        default:
            return .unknown
        }
    }
    
    
    
    enum ArchitectureValidationError: Error, CustomStringConvertible {
        case mismatch(at: URL, expected: AppArchitecture, found: AppArchitecture)
        
        var description: String {
            switch self {
            case let .mismatch(url, expected, found):
                return "Architecture mismatch for \(url.lastPathComponent): expected \(expected.rawValue), found \(found.rawValue)"
            }
        }
    }

    static func validateAppArchitectures(
        urls: [URL],
        expected: [AppArchitecture]
    ) throws {
        for (url, expArch) in zip(urls, expected) {
            let actualArch = try getAppArchitecture(at: url)
            guard actualArch == expArch else {
                throw ArchitectureValidationError.mismatch(at: url, expected: expArch, found: actualArch)
            }
        }
    }
    
}
