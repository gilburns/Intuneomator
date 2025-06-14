//
//  LabelAutomation.swift
//  Intuneomator
//
//  Created by Gil Burns on 3/28/25.
//

import Foundation

/// Main automation class for processing Installomator labels and managing application deployments
///
/// This class provides the core functionality for:
/// - Scanning and validating label folders
/// - Processing Installomator label scripts
/// - Extracting application metadata
/// - Analyzing application architectures
/// - Validating multi-architecture deployments
///
/// The class serves as a coordination layer between various processing components
/// and provides utilities for application analysis and validation.
class LabelAutomation {

    /// Scans the managed titles directory for valid label folders ready for processing
    ///
    /// This method delegates to `FolderScanner` to identify folders that contain
    /// valid Installomator labels ready for automation processing.
    ///
    /// - Returns: Array of folder names that passed validation checks
    // MARK: - Scan Folders to start the automation run
    static func scanAndValidateFolders() -> [String] {
        FolderScanner.scanAndValidateFolders()
    }
    
    
    /// Locates the Intuneomator.app bundle in standard installation locations
    ///
    /// Searches for the Intuneomator application bundle in common installation paths:
    /// - `/Applications/Intuneomator.app` (system-wide installation)
    /// - `~/Applications/Intuneomator.app` (user-specific installation)
    ///
    /// - Returns: Path to Intuneomator.app if found, nil otherwise
    // MARK: - Application Path Discovery
    static func getIntuneomatorAppPath() -> String? {
        let possiblePaths = [
            "/Applications/Intuneomator.app",
            "\(NSHomeDirectory())/Applications/Intuneomator.app"
        ]
        
        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                Logger.info("Found Intuneomator.app at: \(path)", category: .automation)
                return path
            }
        }
        
        Logger.warning("Could not find Intuneomator.app in expected locations", category: .automation)
        return nil
    }
    
    
    /// Checks if a script file contains architecture detection commands
    ///
    /// This method scans the contents of a file to determine if it includes
    /// architecture detection commands commonly used in Installomator scripts.
    /// These commands help determine the appropriate download URL based on
    /// the system architecture (ARM64 vs x86_64).
    ///
    /// **Detected Commands:**
    /// - `$(arch)` - Shell command substitution for architecture
    /// - `$(/usr/bin/arch)` - Full path architecture command
    ///
    /// - Parameter filePath: Absolute path to the script file to analyze
    /// - Returns: `true` if architecture commands are found, `false` otherwise
    static func containsArchCommand(filePath: String) -> Bool {
        do {
            // Validate file exists before reading
            guard FileManager.default.fileExists(atPath: filePath) else {
                Logger.error("File does not exist at path: \(filePath)", category: .automation)
                return false
            }
            
            // Read and analyze file contents
            let fileContents = try String(contentsOfFile: filePath, encoding: .utf8)
            
            // Look for architecture detection commands
            let containsArch = fileContents.contains("$(arch)") || fileContents.contains("$(/usr/bin/arch)")
            
            Logger.debug("Architecture commands \(containsArch ? "found" : "not found") in: \(filePath)", category: .automation)
            
            return containsArch
        } catch {
            Logger.error("Error reading file at \(filePath): \(error.localizedDescription)", category: .automation)
            return false
        }
    }
    
    
    
    /// Executes the Installomator label processing script for a given folder
    ///
    /// This method delegates to `InstallomatorLabelProcessor` to run the label.sh script
    /// that generates application metadata and download information.
    ///
    /// - Parameter folderName: Name of the folder containing the label to process
    /// - Returns: `true` if script execution succeeded, `false` otherwise
    static func runProcessLabelScript(for folderName: String) -> Bool {
        return InstallomatorLabelProcessor.runProcessLabelScript(for: folderName)
    }
    
    /// Extracts processed application metadata from a completed label folder
    ///
    /// This method delegates to `MetadataLoader` to parse the generated plist data
    /// containing application download URLs, versions, and deployment information.
    ///
    /// - Parameter folderName: Name of the folder containing processed label data
    /// - Returns: `ProcessedAppResults` object if parsing succeeded, nil otherwise
    // MARK: - Metadata Extraction
    static func extractDataForProcessedAppResults(from folderName: String) -> ProcessedAppResults? {
        MetadataLoader.extractDataForProcessedAppResults(from: folderName)
    }    
    
    
    /// Represents the CPU architecture of an application bundle
    ///
    /// Used for validating architecture requirements in dual-architecture deployments
    /// and ensuring compatibility with target deployment environments.
    // MARK: - Application Architecture
    enum AppArchitecture: String, CaseIterable {
        case arm64 = "arm64"        // Apple Silicon (M1, M2, etc.)
        case x86_64 = "x86_64"      // Intel processors
        case universal = "universal" // Fat binary containing both architectures
        case unknown = "unknown"    // Could not determine or unsupported architecture
    }

    /// Determines the CPU architecture of an application bundle
    ///
    /// This method analyzes the main executable of an app bundle to determine
    /// its supported CPU architectures. It reads the Info.plist to find the
    /// executable name, then uses the `file` command to inspect the binary.
    ///
    /// **Process:**
    /// 1. Reads Info.plist to get CFBundleExecutable name
    /// 2. Locates the main executable in Contents/MacOS/
    /// 3. Uses `/usr/bin/file` to analyze the binary format
    /// 4. Parses output to determine supported architectures
    ///
    /// - Parameter appURL: URL to the .app bundle to analyze
    /// - Returns: `AppArchitecture` enum value representing the detected architecture
    /// - Throws: File system errors, process execution errors, or plist parsing errors
    static func getAppArchitecture(at appURL: URL) throws -> AppArchitecture {
        // Validate app bundle structure
        guard FileManager.default.fileExists(atPath: appURL.path) else {
            Logger.info("App bundle not found at: \(appURL.path)", category: .automation)
            return .unknown
        }
        
        // Load Info.plist to get the executable name
        let infoPlistURL = appURL.appendingPathComponent("Contents/Info.plist")
        guard FileManager.default.fileExists(atPath: infoPlistURL.path) else {
            Logger.info("Info.plist not found in app bundle: \(appURL.path)", category: .automation)
            return .unknown
        }
        
        let plistData = try Data(contentsOf: infoPlistURL)
        guard
            let plist = try PropertyListSerialization.propertyList(from: plistData, options: [], format: nil) as? [String: Any],
            let execName = plist["CFBundleExecutable"] as? String,
            !execName.isEmpty
        else {
            Logger.info("Could not read CFBundleExecutable from Info.plist", category: .automation)
            return .unknown
        }

        // Point to the actual binary
        let binaryURL = appURL
            .appendingPathComponent("Contents")
            .appendingPathComponent("MacOS")
            .appendingPathComponent(execName)
        
        guard FileManager.default.fileExists(atPath: binaryURL.path) else {
            Logger.info("Executable not found: \(binaryURL.path)", category: .automation)
            return .unknown
        }

        // Verify /usr/bin/file exists
        let fileToolPath = "/usr/bin/file"
        guard FileManager.default.fileExists(atPath: fileToolPath) else {
            Logger.info("File command not found at \(fileToolPath)", category: .automation)
            return .unknown
        }

        // Call `/usr/bin/file` on that binary with proper resource management
        let process = Process()
        let pipe = Pipe()
        
        process.executableURL = URL(fileURLWithPath: fileToolPath)
        process.arguments = ["-bL", binaryURL.path] // -b for brief, -L to follow symlinks
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            // Ensure file handle is properly closed
            let fileHandle = pipe.fileHandleForReading
            let outputData = fileHandle.readDataToEndOfFile()
            try fileHandle.close()
            
            guard process.terminationStatus == 0 else {
                Logger.info("File command failed with status: \(process.terminationStatus)", category: .automation)
                return .unknown
            }
            
            guard let output = String(data: outputData, encoding: .utf8)?.lowercased() else {
                Logger.info("Could not decode file command output", category: .automation)
                return .unknown
            }

            // Inspect the output for architecture indicators
            let hasARM = output.contains("arm64")
            let hasX86 = output.contains("x86_64")

            let architecture: AppArchitecture
            switch (hasARM, hasX86) {
            case (true, true):
                architecture = .universal
            case (true, false):
                architecture = .arm64
            case (false, true):
                architecture = .x86_64
            default:
                architecture = .unknown
            }
            
            Logger.info("Detected architecture for \(appURL.lastPathComponent): \(architecture.rawValue)", category: .automation)
            return architecture
            
        } catch {
            Logger.error("Error executing file command: \(error.localizedDescription)", category: .automation)
            return .unknown
        }
    }
    
    
    
    /// Errors that can occur during architecture validation
    enum ArchitectureValidationError: Error, CustomStringConvertible {
        case mismatch(at: URL, expected: AppArchitecture, found: AppArchitecture)
        case invalidAppBundle(at: URL)
        case analysisFailure(at: URL, error: Error)
        
        var description: String {
            switch self {
            case let .mismatch(url, expected, found):
                return "Architecture mismatch for \(url.lastPathComponent): expected \(expected.rawValue), found \(found.rawValue)"
            case let .invalidAppBundle(url):
                return "Invalid app bundle structure at: \(url.lastPathComponent)"
            case let .analysisFailure(url, error):
                return "Architecture analysis failed for \(url.lastPathComponent): \(error.localizedDescription)"
            }
        }
    }

    /// Validates that a collection of app bundles match their expected architectures
    ///
    /// This method is used in dual-architecture processing to ensure that downloaded
    /// app bundles have the correct CPU architectures before creating universal packages.
    /// It performs architecture analysis on each app bundle and validates against expectations.
    ///
    /// **Common Use Cases:**
    /// - Validating ARM64 and x86_64 apps before creating universal PKG
    /// - Ensuring architecture consistency in multi-architecture deployments
    /// - Quality assurance checks before Intune upload
    ///
    /// - Parameters:
    ///   - urls: Array of URLs to app bundles to validate
    ///   - expected: Array of expected architectures (same order as urls)
    /// - Throws:
    ///   - `ArchitectureValidationError.mismatch` if architectures don't match expectations
    ///   - `ArchitectureValidationError.analysisFailure` if architecture detection fails
    ///   - File system or process execution errors from architecture analysis
    static func validateAppArchitectures(
        urls: [URL],
        expected: [AppArchitecture]
    ) throws {
        guard urls.count == expected.count else {
            Logger.info("URL count (\(urls.count)) doesn't match expected architecture count (\(expected.count))", category: .automation)
            throw NSError(domain: "ValidationError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mismatched array sizes"])
        }
        
        Logger.info("Validating architectures for \(urls.count) app bundles", category: .automation)
        
        for (url, expArch) in zip(urls, expected) {
            do {
                let actualArch = try getAppArchitecture(at: url)
                
                guard actualArch != .unknown else {
                    throw ArchitectureValidationError.invalidAppBundle(at: url)
                }
                
                guard actualArch == expArch else {
                    Logger.info("Architecture validation failed for \(url.lastPathComponent)", category: .automation)
                    throw ArchitectureValidationError.mismatch(at: url, expected: expArch, found: actualArch)
                }
                
                Logger.info("Architecture validated for \(url.lastPathComponent): \(actualArch.rawValue)", category: .automation)
                
            } catch let error as ArchitectureValidationError {
                throw error
            } catch {
                Logger.info("Architecture analysis failed for \(url.lastPathComponent): \(error.localizedDescription)", category: .automation)
                throw ArchitectureValidationError.analysisFailure(at: url, error: error)
            }
        }
        
        Logger.info("All app bundles passed architecture validation", category: .automation)
    }
    
}
