//
//  FolderScanner.swift
//  Intuneomator
//
//  Created by Gil Burns on 3/28/25.
//

import Foundation

/// Scans the Intuneomator managed titles folder and validates each subfolder.
struct FolderScanner {
    private static let logType = "Automation"

    /// Scans and validates all managed titles directories.
    /// - Returns: An array of folder names ready for automation.
    static func scanAndValidateFolders() -> [String] {
        Logger.log("🔄 Starting Intune automation run...", logType: logType)
        Logger.log("--------------------------------------------------------", logType: logType)

        var validFolders: [String] = []
        let basePath = AppConstants.intuneomatorManagedTitlesFolderURL.path

        do {
            var folderContents = try FileManager.default.contentsOfDirectory(atPath: basePath)
            folderContents.sort()

            for folderName in folderContents {
                let folderPath = (basePath as NSString).appendingPathComponent(folderName)
                if AutomationCheck.validateFolder(at: folderPath) {
                    Logger.log("✅ Ready for automation: \(folderName)", logType: logType)
                    validFolders.append(folderName)
                } else {
                    Logger.log("⚠️ Not ready for automation: \(folderName)", logType: logType)
                }
            }
        } catch {
            Logger.log("❌ Error reading managed titles folder: \(error.localizedDescription)", logType: logType)
        }
        Logger.log("--------------------------------------------------------", logType: logType)

//        Logger.log("📋 Valid software titles for automation: \(validFolders.joined(separator: ", "))", logType: logType)
        Logger.log("🏁 Scan complete. \(validFolders.count) folders ready for automation.", logType: logType)

        return validFolders
    }
}
