//
//  FolderScanner.swift
//  Intuneomator
//
//  Created by Gil Burns on 3/28/25.
//

import Foundation

/// Scans the Intuneomator managed titles folder and validates each subfolder.
struct FolderScanner {

    /// Scans and validates all managed titles directories.
    /// - Returns: An array of folder names ready for automation.
    static func scanAndValidateFolders() -> [String] {
        Logger.info("🔄 Starting Intune automation run...", category: .core)
        Logger.info("--------------------------------------------------------", category: .core)

        var validFolders: [String] = []
        let basePath = AppConstants.intuneomatorManagedTitlesFolderURL.path

        do {
            var folderContents = try FileManager.default.contentsOfDirectory(atPath: basePath)
            folderContents.sort()

            for folderName in folderContents {
                let folderPath = (basePath as NSString).appendingPathComponent(folderName)
                let pauseUpdatesPath = (folderPath as NSString).appendingPathComponent(".pauseUpdates")

                if FileManager.default.fileExists(atPath: pauseUpdatesPath) {
                    Logger.info("⏸️ Automation paused: \(folderName)", category: .core)
                } else if AutomationCheck.validateFolder(at: folderPath) {
                    Logger.info("✅ Ready for automation: \(folderName)", category: .core)
                    validFolders.append(folderName)
                } else {
                    Logger.info("⚠️ Not ready for automation: \(folderName)", category: .core)
                }
            }
        } catch {
            Logger.error("❌ Error reading managed titles folder: \(error.localizedDescription)", category: .core)
        }
        Logger.info("--------------------------------------------------------", category: .core)

//        Logger.info("📋 Valid software titles for automation: \(validFolders.joined(separator: ", ", category: .core))", logType: logType)
        Logger.info("🏁 Scan complete. \(validFolders.count) folders ready for automation.", category: .core)

        return validFolders
    }
}
