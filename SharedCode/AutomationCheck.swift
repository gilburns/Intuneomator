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

    /// Validate a folder and return a detailed, human-readable readiness report.
    ///
    /// Performs the same checks as `validateFolder(at:)`, but rather than a boolean,
    /// collects every failing check so the caller can see exactly what is missing.
    /// - Parameter folderPath: The path to the folder to validate.
    /// - Returns: `"Ready for Automation"` if all checks pass, otherwise `"Not Ready for Automation"`
    ///   followed by a bulleted list of the specific issues found.
    static func validationReport(at folderPath: String) -> String {
        var issues: [String] = []

        let folderURL = URL(fileURLWithPath: folderPath)
        let folderName = folderURL.lastPathComponent

        let parts = folderName.split(separator: "_")
        let name: String? = parts.count == 2 ? String(parts[0]) : nil
        if name == nil {
            issues.append("Folder name '\(folderName)' is not in the expected 'label_GUID' format")
        }

        // File: metadata.json
        let metadataURL = folderURL.appendingPathComponent("metadata.json")
        if let metadataData = try? Data(contentsOf: metadataURL),
           let metadataJSON = try? JSONSerialization.jsonObject(with: metadataData, options: []) as? [String: Any] {
            for key in requiredMetadataKeys {
                if key == "ignoreVersionDetection" {
                    if !(metadataJSON[key] is Bool) {
                        issues.append("metadata.json is missing a boolean value for '\(key)'")
                    }
                } else if !((metadataJSON[key] as? String).map({ !$0.isEmpty }) ?? false) {
                    issues.append("metadata.json is missing a value for '\(key)'")
                }
            }
        } else {
            issues.append("Missing or invalid metadata.json")
        }

        // File: assignments.json
        let assignmentsURL = folderURL.appendingPathComponent("assignments.json")
        if let assignmentsData = try? Data(contentsOf: assignmentsURL),
           let assignmentsJSON = try? JSONSerialization.jsonObject(with: assignmentsData, options: []) as? [[String: Any]],
           !assignmentsJSON.isEmpty {
            // Present and valid
        } else {
            issues.append("Missing, invalid, or empty assignments.json")
        }

        if let name {
            // File: filename.sh
            let shellScriptURL = folderURL.appendingPathComponent("\(name).sh")
            if let shellScriptContent = try? String(contentsOf: shellScriptURL),
               !shellScriptContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                // Present and non-empty
            } else {
                issues.append("Missing or empty \(name).sh script")
            }

            // File: filename.plist
            let plistURL = folderURL.appendingPathComponent("\(name).plist")
            if let plistData = try? Data(contentsOf: plistURL),
               let plistContent = try? PropertyListSerialization.propertyList(from: plistData, options: [], format: nil) as? [String: Any] {
                for key in requiredPlistKeys {
                    if !((plistContent[key] as? String).map({ !$0.isEmpty }) ?? false) {
                        issues.append("\(name).plist is missing a value for '\(key)'")
                    }
                }
            } else {
                issues.append("Missing or invalid \(name).plist")
            }
        } else {
            issues.append("Cannot verify shell script or plist because the folder name format is invalid")
        }

        guard !issues.isEmpty else {
            return "Ready for Automation"
        }

        let bulletedIssues = issues.map { "- \($0)" }.joined(separator: "\n")
        return "Not Ready for Automation\n\(bulletedIssues)"
    }
}
