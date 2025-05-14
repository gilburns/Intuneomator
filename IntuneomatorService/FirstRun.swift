//
//  FirstRun.swift
//  Intuneomator
//
//  Created by Gil Burns on 3/19/25.
//

import Foundation

class FirstRun {

    static func checkFirstRun() -> Void {
        if ConfigManager.readPlistValue(key: "FirstRunServiceCompleted") ?? false {
//            Logger.log("Intuneomator first run has already run. Exiting...", logType: "FirstRun")
            return
        }
        
        // Create folder structure
        setupSupportFolders()
        
        // Check if Installomator labels exist
        // Installs labels at first launch
        downloadInstallomatorLabels()
        
        let setFirstRun = ConfigManager.writePlistValue(key: "FirstRunServiceCompleted", value: true)
        if !setFirstRun {
            Logger.log("Failed to set FirstRun to true in config.plist", logType: "FirstRun")
        } else {
            Logger.log(">>> First run complete! <<<", logType: "FirstRun")
        }
    }
    
// MARK: - Setup Folders
    static func setupSupportFolders() {
        Logger.log("Checking for and creating application support folders...", logType: "FirstRun")
        let folders = [
            AppConstants.intuneomatorFolderURL.path,
            AppConstants.intuneomatorCacheFolderURL.path,
            AppConstants.intuneomatorConfigFolderURL.path,
            AppConstants.installomatorFolderURL.path,
            AppConstants.installomatorLabelsFolderURL.path,
            AppConstants.intuneomatorManagedTitlesFolderURL.path,
        ]
        
        // Create required folders if they don't exist
        for folder in folders {
            if !FileManager.default.fileExists(atPath: folder) {
                do {
                    try FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true, attributes: nil)
                    Logger.log("Created folder: \(folder)", logType: "FirstRun")
                } catch {
                    Logger.log("Failed to create folder: \(folder), error: \(error)", logType: "FirstRun")
                }
            }
        }
        
        // Check if Installomator labels exist
        // Installs labels at first launch
        Logger.log("Checking for Installomator labels...", logType: "FirstRun")
        if !FileManager.default.fileExists(atPath: AppConstants.installomatorLabelsFolderURL.path) {
            Logger.log("Installomator labels not found. Downloading...", logType: "FirstRun")
            downloadInstallomatorLabels()
        }
    }
    
// MARK: - Setup Installomator Labels
    static func downloadInstallomatorLabels() {
        InstallomatorLabels.installInstallomatorLabels { success, message in
            DispatchQueue.main.async {
                if success {
                    Logger.log("Installomator labels downloaded successfully.", logType: "FirstRun")
                } else {
                    Logger.log("Failed to download Installomator labels: \(message)", logType: "FirstRun")
                }
            }
        }
        
        if FileFolderManagerUtil.changePermissionsRecursively(
            at: AppConstants.installomatorLabelsFolderURL.path,
            to: 0o644,
            excludeHiddenFiles: true,
            skipDirectories: true
        ) {
            Logger.log("Permissions changed for files recursively!", logType: "FirstRun")
        }

        if FileFolderManagerUtil.changePermissionsRecursively(
            at: AppConstants.installomatorLabelsFolderURL.path,
            to: 0o755,
            excludeHiddenFiles: true,
            skipDirectories: false
        ) {
            Logger.log("Permissions changed for directories recursively!", logType: "FirstRun")
        }
    }
}
