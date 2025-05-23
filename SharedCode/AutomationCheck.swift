//
//  AutomationCheck.swift
//  Intuneomator
//
//  Created by Gil Burns on 1/13/25.
//

import Foundation

/// Performs local folder-based validation for Intuneomator metadata bundles.
/// Provides checks for required files and key/value presence in metadata, assignments, scripts, and plists.
enum AutomationCheck {
    
    private static let logType = "AutomationCheck"

    /// Required keys in metadata.json
    private static let requiredMetadataKeys = [
        "description", "publisher", "minimumOS", "CFBundleIdentifier", "ignoreVersionDetection"
    ]

    /// Required keys in the .plist file
    private static let requiredPlistKeys = [
        "downloadURL", "expectedTeamID", "label", "type"
    ]

    /// Validate a folder by checking its required files and specific keys/values
    /// - Parameter folderPath: The path to the folder to validate.
    /// - Returns: A boolean indicating whether the folder passes validation.
    static func validateFolder(at folderPath: String) -> Bool {
        let folderURL = URL(fileURLWithPath: folderPath)
        let folderName = folderURL.lastPathComponent

        let parts = folderName.split(separator: "_")
        guard parts.count == 2 else {
            Logger.log("❌ Invalid directory format for folder: \(folderName)", logType: logType)
            return false
        }
        let name = String(parts[0])

        // File: metadata.json
        let metadataURL = folderURL.appendingPathComponent("metadata.json")
        guard let metadataData = try? Data(contentsOf: metadataURL),
              let metadataJSON = try? JSONSerialization.jsonObject(with: metadataData, options: []) as? [String: Any] else {
            return false
        }

        // Check required keys in metadata.json
        for key in requiredMetadataKeys {
            if key == "ignoreVersionDetection" {
                guard metadataJSON[key] is Bool else { return false }
            } else {
                guard let value = metadataJSON[key] as? String, !value.isEmpty else { return false }
            }
        }

        // File: assignments.json
        let assignmentsURL = folderURL.appendingPathComponent("assignments.json")
        guard let assignmentsData = try? Data(contentsOf: assignmentsURL),
              let assignmentsJSON = try? JSONSerialization.jsonObject(with: assignmentsData, options: []) as? [[String: Any]],
              !assignmentsJSON.isEmpty else {
            return false
        }

        // File: filename.sh
        let shellScriptURL = folderURL.appendingPathComponent("\(name).sh")
        guard let shellScriptContent = try? String(contentsOf: shellScriptURL),
              !shellScriptContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }

        // File: filename.plist
        let plistURL = folderURL.appendingPathComponent("\(name).plist")
        guard let plistData = try? Data(contentsOf: plistURL),
              let plistContent = try? PropertyListSerialization.propertyList(from: plistData, options: [], format: nil) as? [String: Any] else {
            return false
        }

        // Check required keys in the plist
        for key in requiredPlistKeys {
            guard let value = plistContent[key] as? String, !value.isEmpty else { return false }
        }

        return true
    }
}
