//
//  InstallomatorLabelProcessor.swift
//  Intuneomator
//
//  Created by Gil Burns on 3/23/25.
//

import Foundation

/// Utility class for processing and managing Installomator label scripts within Intuneomator.
/// This class handles the execution of Installomator label scripts to generate application metadata,
/// manages label updates from the Installomator repository, and handles architecture-specific
/// script execution requirements. Provides the core functionality for converting Installomator
/// labels into Intune-compatible application packages.
class InstallomatorLabelProcessor {
    
    static private let logType = "InstallomatorLabelProcessor"
    
    /// Locates the Intuneomator.app bundle in common installation locations.
    /// 
    /// Searches through standard macOS application directories to find the Intuneomator
    /// application bundle. This is necessary to locate bundled resources like the
    /// process_label.sh script used for label processing.
    /// 
    /// - Returns: The full path to Intuneomator.app if found, nil otherwise
    /// 
    /// **Search Locations:**
    /// 1. `/Applications/Intuneomator.app` (system-wide installation)
    /// 2. `~/Applications/Intuneomator.app` (user-specific installation)
    /// 3. `/usr/local/Intuneomator.app` (alternative installation location)
    /// 
    /// **Use Cases:**
    /// - Locating bundled scripts and resources
    /// - Validating application installation
    /// - Supporting multiple installation scenarios
    static func getIntuneomatorAppPath() -> String? {
        // Search common application installation locations
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

    /// Analyzes an Installomator label script to determine if it uses architecture detection commands.
    /// 
    /// Scans the script content for architecture-related commands that require special handling
    /// during execution. Scripts containing these commands need to be run under specific
    /// architecture contexts (typically x86_64) to ensure proper functionality.
    /// 
    /// - Parameter filePath: The full path to the label script file
    /// - Returns: `true` if the script contains architecture commands, `false` otherwise
    /// 
    /// **Detected Patterns:**
    /// - `$(arch)` - Shell command substitution for architecture detection
    /// - `$(/usr/bin/arch)` - Full path architecture command
    /// 
    /// **Use Cases:**
    /// - Determining execution strategy for label scripts
    /// - Handling Universal binary compatibility
    /// - Ensuring proper architecture context for downloads
    static func containsArchCommand(filePath: String) -> Bool {
        do {
            // Read and analyze script content for architecture commands
            let fileContents = try String(contentsOfFile: filePath, encoding: .utf8)
            
            // Look for either "$(arch)" or "$(/usr/bin/arch)" in the file
            return fileContents.contains("$(arch)") || fileContents.contains("$(/usr/bin/arch)")
        } catch {
            Logger.log("❌ Error reading file at \(filePath): \(error)", logType: logType)
            return false
        }
    }
    
    /// Executes a shell process and returns the trimmed output string.
    /// 
    /// - Parameters:
    ///   - executableURL: URL to the executable to run
    ///   - arguments: Array of arguments to pass to the executable
    ///   - folderName: Name of the folder being processed (for error logging)
    /// - Returns: The trimmed output string if successful, nil if failed
    /// - Throws: Process execution errors
    private static func executeProcess(executableURL: URL, arguments: [String], folderName: String) throws -> String? {
        let process = Process()
        let pipe = Pipe()
        
        process.executableURL = executableURL
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = pipe
        
        try process.run()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            Logger.log("❌ Process failed with exit code \(process.terminationStatus) for \(folderName)", logType: logType)
            return nil
        }
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Executes the process_label.sh script for a specific Installomator label to generate metadata.
    /// 
    /// Runs the bundled process_label.sh script against an Installomator label to extract
    /// application metadata and create property list files. Handles both standard execution
    /// and architecture-specific execution for scripts that require x86_64 context.
    /// 
    /// - Parameter folderName: The managed title folder name (format: "labelname_GUID")
    /// - Returns: `true` if script execution succeeded and metadata was generated, `false` otherwise
    /// 
    /// **Process Flow:**
    /// 1. Locates Intuneomator.app and validates process_label.sh script
    /// 2. Updates the label script to latest version from repository
    /// 3. Executes process_label.sh with the label script
    /// 4. Analyzes script for architecture commands
    /// 5. Re-executes under x86_64 architecture if needed
    /// 6. Validates "Plist created" output for success confirmation
    /// 
    /// **Architecture Handling:**
    /// - Standard execution: `/bin/zsh process_label.sh labelscript.sh`
    /// - Architecture-specific: `/usr/bin/arch -x86_64 /bin/zsh process_label.sh labelscript.sh`
    /// 
    /// **Error Conditions:**
    /// - Intuneomator.app not found
    /// - Invalid folder name format
    /// - Label update failure
    /// - Missing script files
    /// - Script execution failure
    static func runProcessLabelScript(for folderName: String) -> Bool {
        
        guard let intuneomatorAppPath = getIntuneomatorAppPath() else {
            Logger.log("❌ Could not find Intuneomator.app.", logType: logType)
            return false
        }

        let processScriptPath = "\(intuneomatorAppPath)/Contents/Resources/process_label.sh"
        let folderURL = AppConstants.intuneomatorManagedTitlesFolderURL.appendingPathComponent(folderName)
        let folderPath = folderURL.path
        
        // Parse folder name format (labelname_GUID)
        let parts = folderName.split(separator: "_")
        guard parts.count == 2 else {
            Logger.log("❌ Invalid folder format: \(folderName)", logType: logType)
            return false
        }
        
        // Update label script to latest version before processing
        let updateLabel = self.updateLabelDirectory(labelDir: folderURL)
        if !updateLabel {
            Logger.log("❌ Failed to update label for \(folderName)", logType: logType)
            return false
        }
        
        let labelScriptPath = folderURL.appendingPathComponent("\(parts[0]).sh").path

        // Validate required script files exist before execution
        if !FileManager.default.fileExists(atPath: processScriptPath) {
            Logger.log("❌ process_label.sh not found at \(processScriptPath)", logType: logType)
            return false
        }
        
        if !FileManager.default.fileExists(atPath: labelScriptPath) {
            Logger.log("❌ Label script not found at \(labelScriptPath)", logType: logType)
            return false
        }

        // Execute process_label.sh script with standard zsh
        do {
            if let output = try executeProcess(
                executableURL: URL(fileURLWithPath: "/bin/zsh"),
                arguments: [processScriptPath, labelScriptPath],
                folderName: folderName
            ) {
                // Check for successful plist creation output
                if output != "Plist created" {
                    Logger.log("❌ plist update failed for \(folderName): \(output)", logType: logType)
                    return false
                }
                // Success - continue to check if architecture-specific execution needed
            } else {
                Logger.log("❌ No output received from process_label.sh for \(folderName)", logType: logType)
                return false
            }
        } catch {
            Logger.log("❌ Failed to execute process_label.sh: \(error.localizedDescription)", logType: logType)
            return false
        }
        
        let archResult = self.containsArchCommand(filePath: labelScriptPath)
        if archResult {
            // Script contains architecture commands, re-execute under x86_64
            do {
                if let output = try executeProcess(
                    executableURL: URL(fileURLWithPath: "/usr/bin/arch"),
                    arguments: ["-x86_64", "/bin/zsh", processScriptPath, labelScriptPath],
                    folderName: folderName
                ) {
                    // Validate successful plist creation under x86_64 architecture
                    if output == "Plist created" {
                        return true
                    } else {
                        Logger.log("❌ plist update failed for \(folderName): \(output)", logType: logType)
                        return false
                    }
                } else {
                    Logger.log("❌ No output received from x86_64 process_label.sh for \(folderName)", logType: logType)
                    return false
                }
            } catch {
                Logger.log("❌ Failed to execute x86_64 process_label.sh: \(error.localizedDescription)", logType: logType)
                return false
            }
        } else {
            return true
        }
        Logger.log("❌ Unknown error occurred when running process_label.sh", logType: logType)
        return false
    }
    
    
    /// Updates an Installomator label script to the latest version from the repository.
    /// 
    /// Compares the current label script in a managed title directory with the latest
    /// version from the Installomator repository and updates it if changes are detected.
    /// Handles both standard Installomator labels and custom labels based on directory markers.
    /// 
    /// - Parameter labelDir: The URL of the managed title directory containing the label script
    /// - Returns: `true` if the update check/process succeeded, `false` if an error occurred
    /// 
    /// **Process Flow:**
    /// 1. Parses directory name to extract label name and GUID
    /// 2. Checks for .custom marker to determine label source
    /// 3. Compares existing script with repository version
    /// 4. Updates script content if differences are found
    /// 5. Preserves existing script if already up-to-date
    /// 
    /// **Label Sources:**
    /// - Standard labels: From main Installomator repository
    /// - Custom labels: From custom labels directory (marked with .custom file)
    /// 
    /// **Error Conditions:**
    /// - Invalid directory name format
    /// - Missing label script files
    /// - File I/O errors during comparison or update
    static func updateLabelDirectory(labelDir: URL) -> Bool {
        // Extract label name and GUID from directory name (format: labelname_GUID)
        let directoryName = labelDir.lastPathComponent
        
        // Parse directory name into label and GUID components
        let parts = directoryName.split(separator: "_")
        
        guard parts.count == 2 else {
            Logger.log("❌ Invalid directory format: \(directoryName)", logType: logType)
            return false
        }
        
        let label = String(parts[0])
        let guid = String(parts[1])
        
        // Build paths for existing script and update source
        let existingScriptURL = labelDir
            .appendingPathComponent("\(label).sh")
        
        let customLabelCheck = labelDir.appendingPathComponent(".custom")
        
        // Determine source directory based on custom label marker
        let updatedLabelsDir: String
        if !FileManager.default.fileExists(atPath: customLabelCheck.path) {
            updatedLabelsDir = AppConstants.installomatorLabelsFolderURL.path
        } else {
            updatedLabelsDir = AppConstants.installomatorCustomLabelsFolderURL.path
        }
        
        let updatedScriptPath = URL(fileURLWithPath: updatedLabelsDir)
            .appendingPathComponent("\(label).sh")
        
        // Perform script update check and replacement if needed
        if FileManager.default.fileExists(atPath: existingScriptURL.path) {
            do {
                // Compare existing script with repository version
                if FileManager.default.fileExists(atPath: updatedScriptPath.path) {
                    let originalContents = try String(contentsOf: existingScriptURL)
                    let updatedContents = try String(contentsOf: updatedScriptPath)
                    
                    if originalContents != updatedContents {
                        // Update script with newer version from repository
                        try updatedContents.write(to: existingScriptURL, atomically: true, encoding: .utf8)
                        Logger.log("Replaced outdated script at \(existingScriptURL.path) with updated content.", logType: logType)
                        } else {
                        // Script is already current, no update needed
                    }
                }
            } catch {
                Logger.log("Failed to update script: \(error)", logType: logType)
                return false
            }
        } else {
            Logger.log("Script not found at \(existingScriptURL.path)", logType: logType)
            return false
        }
        return true
    }
}
