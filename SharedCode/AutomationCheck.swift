//
//  AutomationCheck.swift
//  Intuneomator
//
//  Created by Gil Burns on 1/13/25.
//

import Foundation

class AutomationCheck {
    
    /// Validate a folder by checking its required files and specific keys/values
    /// - Parameter folderPath: The path to the folder to validate.
    /// - Returns: A boolean indicating whether the folder passes validation.
    static func validateFolder(at folderPath: String) -> Bool {
        let folderURL = URL(fileURLWithPath: folderPath)
        let folderName = folderURL.lastPathComponent
//        print("Folder URL: \(folderURL)")
//        print("Folder Name: \(folderName)")

        var name: String?
//        var guid: String?

        let parts = folderName.split(separator: "_")

        if parts.count == 2 {
            name = String(parts[0]) // Assign the name
//            guid = String(parts[1]) // Assign the GUID
//            Logger.log("Name: \(name!), GUID: \(guid!)", logType: "Validation_\(name!)")
        } else {
            Logger.log("Invalid directory format.")
        }

        
//        Logger.log("Validating folder: \(folderName).", logType: "Validation_\(name!)")

        // 1. File 1: metadata.json
        let metadataURL = folderURL.appendingPathComponent("metadata.json")
        guard let metadataData = try? Data(contentsOf: metadataURL),
              let metadataJSON = try? JSONSerialization.jsonObject(with: metadataData, options: []) as? [String: Any] else {
//            Logger.log("Validation failed: metadata.json is missing or unreadable.", logType: "Validation_\(name!)")
            return false
        }
        
        // Check required keys in metadata.json
        let requiredMetadataKeys = ["description", "publisher", "minimumOS", "CFBundleIdentifier", "ignoreVersionDetection"]
        for key in requiredMetadataKeys {
            if key == "ignoreVersionDetection" {
                guard let _ = metadataJSON[key] as? Bool else {
//                    Logger.log("Validation failed: metadata.json is missing or invalid for key: \(key).", logType: "Validation_\(name!)")
                    return false
                }
            } else {
                guard let value = metadataJSON[key] as? String, !value.isEmpty else {
//                    Logger.log("Validation failed: metadata.json is missing or invalid for key: \(key).", logType: "Validation_\(name!)")
                    return false
                }
            }
        }
        
        // 2. File 2: description.txt
//        let descriptionURL = folderURL.appendingPathComponent("description.txt")
//        guard let descriptionContent = try? String(contentsOf: descriptionURL), !descriptionContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
//            Logger.log("Validation failed: description.txt is missing or empty.", logType: "Validation_\(name!)")
//            return false
//        }
        
        // 3. File 3: assignments.json
        let assignmentsURL = folderURL.appendingPathComponent("assignments.json")
        guard let assignmentsData = try? Data(contentsOf: assignmentsURL),
              let assignmentsJSON = try? JSONSerialization.jsonObject(with: assignmentsData, options: []) as? [[String: Any]] else {
        //    Logger.log("Validation failed: assignments.json is missing or unreadable.", logType: "Validation_\(name!)")
            return false
        }

        // Check required arrays in assignments.json
        guard assignmentsJSON.count >= 1 else {
        //    Logger.log(“Validation failed: assignments.json does not contain any valid assignments.”, logType: “Validation_(name!)”)
        return false
        }

        // 4. File 4: filename.sh
        let shellScriptURL = folderURL.appendingPathComponent("\(name!).sh")
        guard let shellScriptContent = try? String(contentsOf: shellScriptURL), !shellScriptContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
//            Logger.log("Validation failed: \(name!).sh is missing or empty.", logType: "Validation_\(name!)")
            return false
        }
        
        // 5. File 5: filename.plist
        let plistURL = folderURL.appendingPathComponent("\(name!).plist")
        guard let plistData = try? Data(contentsOf: plistURL),
              let plistContent = try? PropertyListSerialization.propertyList(from: plistData, options: [], format: nil) as? [String: Any] else {
//            Logger.log("Validation failed: \(name!).plist is missing or unreadable.", logType: "Validation_\(name!)")
            return false
        }
        
        // Check required keys in the plist
        let requiredPlistKeys = ["downloadURL", "expectedTeamID", "label", "type"]
        for key in requiredPlistKeys {
            guard let value = plistContent[key] as? String, !value.isEmpty else {
//                Logger.log("Validation failed: \(folderName).plist is missing or invalid for key: \(key).", logType: "Validation_\(name!)")
                return false
            }
        }

//        Logger.log("Validation Passed for: \(folderName)", logType: "Validation_\(name!)")

        // If all checks pass
        return true
    }
}
