//
//  InstallomatorLabelProcessor.swift
//  Intuneomator
//
//  Created by Gil Burns on 3/23/25.
//

import Foundation

class InstallomatorLabelProcessor {
    
    static private let logType = "InstallomatorLabelProcessor"
    
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
            print("Error reading file at \(filePath): \(error)")
            return false
        }
    }

    static func runProcessLabelScript(for folderName: String) -> Bool {
        Logger.log("Running process_label.sh for \(folderName)...", logType: logType)
        
        guard let intuneomatorAppPath = getIntuneomatorAppPath() else {
            Logger.log("❌ Could not find Intuneomator.app.", logType: logType)
            return false
        }

        let processScriptPath = "\(intuneomatorAppPath)/Contents/Resources/process_label.sh"
        let folderPath = (AppConstants.intuneomatorManagedTitlesFolderURL.path as NSString).appendingPathComponent(folderName)
        
        let parts = folderName.split(separator: "_")
        guard parts.count == 2 else {
            Logger.log("❌ Invalid folder format: \(folderName)", logType: logType)
            return false
        }
        
        let updateLabel = self.updateLabelDirectory(labelDir: URL(fileURLWithPath: folderPath))
        if !updateLabel {
            Logger.log("❌ Failed to update label for \(folderName)", logType: logType)
            return false
        }
        
        let labelScriptPath = (folderPath as NSString).appendingPathComponent("\(parts[0]).sh")

        // Ensure the script and label file exist
        if !FileManager.default.fileExists(atPath: processScriptPath) {
            Logger.log("❌ process_label.sh not found at \(processScriptPath)", logType: logType)
            return false
        }
        
        if !FileManager.default.fileExists(atPath: labelScriptPath) {
            Logger.log("❌ Label script not found at \(labelScriptPath)", logType: logType)
            return false
        }

        Logger.log("▶️ Running process_label.sh for \(folderName)...", logType: logType)

        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = [processScriptPath, labelScriptPath]
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
                Logger.log("📜 process_label.sh output: \(output)", logType: logType)

                if output == "Plist created" {
                    Logger.log("✅ plist successfully updated for \(folderName)", logType: logType)
//                    return true
                } else {
                    Logger.log("❌ plist update failed for \(folderName)", logType: logType)
                    return false
                }
            }
        } catch {
            Logger.log("❌ Failed to execute process_label.sh: \(error.localizedDescription)", logType: logType)
            return false
        }
        
        let archResult = self.containsArchCommand(filePath: labelScriptPath)
        Logger.log("Arch result: \(archResult)", logType: logType)
        if archResult {
                Logger.log("❌ Label script contains arch command, running again: \(folderName)", logType: logType)
            
            let process = Process()
            let pipe = Pipe()
            
            process.executableURL = URL(fileURLWithPath: "/usr/bin/arch")
            process.arguments = ["-x86_64", "/bin/zsh", processScriptPath, labelScriptPath]
            process.standardOutput = pipe
            process.standardError = pipe
            
            do {
                try process.run()
                process.waitUntilExit()
                
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
                    Logger.log("📜 process_label.sh output: \(output)", logType: logType)
                    
                    if output == "Plist created" {
                        Logger.log("✅ plist successfully updated for \(folderName)", logType: logType)
                        return true
                    } else {
                        Logger.log("❌ plist update failed for \(folderName)", logType: logType)
                        return false
                    }
                }
            } catch {
                Logger.log("❌ Failed to execute process_label.sh: \(error.localizedDescription)", logType: logType)
                return false
            }
        } else {
            Logger.log("❌ Label script does not contain arch command: \(folderName)", logType: logType)
            return true
        }
        Logger.log("❌ Unknown error occurred when running process_label.sh", logType: logType)
        return false
    }
    
    
    static func updateLabelDirectory(labelDir: URL) -> Bool {
        // Get the name and GUID from the directory name we will process
        let directoryName = labelDir.lastPathComponent
        
        // Declare variables
        var label: String?
        var guid: String?
        
        let parts = directoryName.split(separator: "_")
        
        if parts.count == 2 {
            label = String(parts[0]) // Assign the name
            guid = String(parts[1]) // Assign the GUID
            Logger.log("Name: \(label!), GUID: \(guid!)", logType: logType)
        } else {
            Logger.log("Invalid directory format.", logType: logType)
        }
        
        // Current script file path
        let existingScriptURL = labelDir
            .appendingPathComponent("\(label!).sh")
        
        let customLabelCheck = labelDir.appendingPathComponent(".custom")
        
        // Directory containing the updated labels
        let updatedLabelsDir: String
        if !FileManager.default.fileExists(atPath: customLabelCheck.path) {
            updatedLabelsDir = AppConstants.installomatorLabelsFolderURL.path
        } else {
            updatedLabelsDir = AppConstants.installomatorCustomLabelsFolderURL.path
        }
        
        let updatedScriptPath = URL(fileURLWithPath: updatedLabelsDir)
            .appendingPathComponent("\(label!).sh")
        Logger.log("Updated script path: \(updatedScriptPath.path)", logType: logType)
        
        
        
        // Check for the script file
        if FileManager.default.fileExists(atPath: existingScriptURL.path) {
            do {
                // Check if the updated version of the script exists
                if FileManager.default.fileExists(atPath: updatedScriptPath.path) {
                    let originalContents = try String(contentsOf: existingScriptURL)
                    let updatedContents = try String(contentsOf: updatedScriptPath)
                    
                    if originalContents != updatedContents {
                        // Replace the script with the updated version
                        Logger.log("Script at \(existingScriptURL.path) is out of date.", logType: logType)
                        try updatedContents.write(to: existingScriptURL, atomically: true, encoding: .utf8)
                        Logger.log("Replaced outdated script at \(existingScriptURL.path) with updated content.", logType: logType)
                        } else {
                        Logger.log("Script at \(existingScriptURL.path) is already up to date.", logType: logType)
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
