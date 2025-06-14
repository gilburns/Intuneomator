//
//  ConfigManager.swift
//  Intuneomator
//
//  Created by Gil Burns on 3/17/25.
//

import Foundation

/// Manages configuration data stored in the Intuneomator service plist file
/// Provides type-safe read/write operations with automatic permission management
class ConfigManager {
    /// Path to the service configuration plist file
    static let plistPath = AppConstants.intuneomatorServiceFileURL.path

    // MARK: - Read from Plist
    
    /// Reads a value from the plist file with type safety
    /// - Parameter key: The key to read from the plist
    /// - Returns: The value cast to the specified type, or nil if not found or cast fails
    static func readPlistValue<T>(key: String) -> T? {
        guard let plistDict = loadPlist() else {
            Logger.info("Failed to load plist for reading key: \(key)", category: .core)
            return nil
        }
        return plistDict[key] as? T
    }
    
    // MARK: - Write to Plist
    
    /// Writes a value to the plist file and saves it
    /// - Parameters:
    ///   - key: The key to write to
    ///   - value: The value to store
    /// - Returns: True if the write operation was successful, false otherwise
    static func writePlistValue<T>(key: String, value: T) -> Bool {
        var plistDict = loadPlist() ?? [:]
        plistDict[key] = value

        return savePlist(plistDict)
    }
    
    // MARK: - Load Entire Plist
    
    /// Loads the entire plist file into a dictionary
    /// - Returns: Dictionary containing all plist data, or nil if loading fails
    private static func loadPlist() -> [String: Any]? {
        guard FileManager.default.fileExists(atPath: plistPath),
              let plistData = try? Data(contentsOf: URL(fileURLWithPath: plistPath)),
              let plistDict = try? PropertyListSerialization.propertyList(from: plistData, options: [], format: nil) as? [String: Any] else {
            return nil
        }
        return plistDict
    }

    // MARK: - Save Entire Plist
    
    /// Saves the dictionary to the plist file and applies security permissions
    /// - Parameter dict: The dictionary to save
    /// - Returns: True if save operation was successful, false otherwise
    private static func savePlist(_ dict: [String: Any]) -> Bool {
        do {
            let plistData = try PropertyListSerialization.data(fromPropertyList: dict, format: .xml, options: 0)
            try plistData.write(to: URL(fileURLWithPath: plistPath))
            restrictPlistPermissions() // Ensure permissions after saving
            return true
        } catch {
            Logger.info("Failed to write plist: \(error)", category: .core)
            return false
        }
    }

    // MARK: - Restrict Permissions
    
    /// Applies secure file permissions to the plist and parent directory
    /// Sets plist to 600 (rw-------), directory to 755 (rwxr-xr-x), and ownership to root:wheel
    static func restrictPlistPermissions() {
        executeShellCommand("/bin/chmod", arguments: ["600", plistPath])
        executeShellCommand("/bin/chmod", arguments: ["755", AppConstants.intuneomatorFolderURL.path])
        executeShellCommand("/usr/sbin/chown", arguments: ["-R", "root:wheel", AppConstants.intuneomatorFolderURL.path])
    }

    // MARK: - Helper Function for Shell Commands
    
    /// Executes a shell command with the given arguments
    /// - Parameters:
    ///   - command: The full path to the command to execute
    ///   - arguments: Array of arguments to pass to the command
    private static func executeShellCommand(_ command: String, arguments: [String]) {
        do {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: command)
            task.arguments = arguments
            try task.run()
            task.waitUntilExit()
        } catch {
            Logger.info("Error executing \(command) \(arguments.joined(separator: " ")): \(error)", category: .core)
        }
    }
}


// Usage Examples:

/*
 Reading a String
 let authMethod: String = ConfigManager.readPlistValue(key: "AuthMethod") ?? "certificate"
 
 Reading an Int
 let retryCount: Int = ConfigManager.readPlistValue(key: "RetryCount") ?? 0
 
 Reading a Bool
 let isEnabled: Bool = ConfigManager.readPlistValue(key: "isFeatureEnabled") ?? false
 
 
 Writing a String
 ConfigManager.writePlistValue(key: "AuthMethod", value: "certificate")
 
 Writing an Int
 ConfigManager.writePlistValue(key: "RetryCount", value: 3)
 
 Writing a Bool
 ConfigManager.writePlistValue(key: "isFeatureEnabled", value: true)
 
 */
