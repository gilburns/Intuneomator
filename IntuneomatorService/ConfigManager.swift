//
//  ConfigManager.swift
//  Intuneomator
//
//  Created by Gil Burns on 3/17/25.
//

import Foundation

import Foundation

class ConfigManager {
    static let plistPath = AppConstants.intuneomatorServiceFileURL.path

    // MARK: - Read from Plist
    static func readPlistValue<T>(key: String) -> T? {
        guard let plistDict = loadPlist() else {
            Logger.log("Failed to load plist for reading key: \(key)")
            return nil
        }
        return plistDict[key] as? T
    }
    
    // MARK: - Write to Plist
    static func writePlistValue<T>(key: String, value: T) -> Bool {
        var plistDict = loadPlist() ?? [:]
        plistDict[key] = value

        return savePlist(plistDict)
    }
    
    // MARK: - Load Entire Plist
    private static func loadPlist() -> [String: Any]? {
        guard FileManager.default.fileExists(atPath: plistPath),
              let plistData = try? Data(contentsOf: URL(fileURLWithPath: plistPath)),
              let plistDict = try? PropertyListSerialization.propertyList(from: plistData, options: [], format: nil) as? [String: Any] else {
            return nil
        }
        return plistDict
    }

    // MARK: - Save Entire Plist
    private static func savePlist(_ dict: [String: Any]) -> Bool {
        do {
            let plistData = try PropertyListSerialization.data(fromPropertyList: dict, format: .xml, options: 0)
            try plistData.write(to: URL(fileURLWithPath: plistPath))
            restrictPlistPermissions() // Ensure permissions after saving
            return true
        } catch {
            Logger.log("Failed to write plist: \(error)")
            return false
        }
    }

    // MARK: - Restrict Permissions
    static func restrictPlistPermissions() {
        executeShellCommand("/bin/chmod", arguments: ["600", plistPath])
        executeShellCommand("/bin/chmod", arguments: ["755", AppConstants.intuneomatorFolderURL.path])
        executeShellCommand("/usr/sbin/chown", arguments: ["-R", "root:wheel", AppConstants.intuneomatorFolderURL.path])
    }

    // MARK: - Helper Function for Shell Commands
    private static func executeShellCommand(_ command: String, arguments: [String]) {
        do {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: command)
            task.arguments = arguments
            try task.run()
            task.waitUntilExit()
        } catch {
            Logger.log("Error executing \(command) \(arguments.joined(separator: " ")): \(error)")
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
