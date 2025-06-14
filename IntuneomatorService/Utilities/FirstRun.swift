//
//  FirstRun.swift
//  Intuneomator
//
//  Created by Gil Burns on 3/19/25.
//

import Foundation

/// Handles first-time setup and initialization for the Intuneomator service
/// Creates required directory structure, downloads Installomator labels, and configures Launch Daemons
class FirstRun {
    

    /// Performs first-run initialization if not already completed
    /// Sets up folder structure, downloads labels, and configures scheduled tasks
    static func checkFirstRun() -> Void {
        
        if ConfigManager.readPlistValue(key: "FirstRunServiceCompleted") ?? false {
//            Logger.info("Intuneomator first run has already run. Exiting...", category: .core)
            return
        }
        
        // Create folder structure
        setupSupportFolders()
        
        // Check if Installomator labels exist
        // Installs labels at first launch
        downloadInstallomatorLabels()
        
        // Create additional LaunchDaemon's if not present
        setupOtherLaunchDaemons()
        
        let setFirstRun = ConfigManager.writePlistValue(key: "FirstRunServiceCompleted", value: true)
        
        if !setFirstRun {
            Logger.error("Failed to set FirstRun to true in config.plist", category: .core)
        } else {
            Logger.info(">>> First run complete! <<<", category: .core)
        }
    }
    
    // MARK: - Setup Folders
    
    /// Creates the required directory structure for Intuneomator operations
    /// Ensures all necessary folders exist with proper permissions
    static func setupSupportFolders() {
        Logger.info("Checking for and creating application support folders...", category: .core)
        let folders = [
            AppConstants.intuneomatorFolderURL.path,
            AppConstants.intuneomatorCacheFolderURL.path,
            AppConstants.installomatorFolderURL.path,
            AppConstants.installomatorLabelsFolderURL.path,
            AppConstants.installomatorCustomLabelsFolderURL.path,
            AppConstants.intuneomatorManagedTitlesFolderURL.path,
            AppConstants.intuneomatorOndemandTriggerURL.path,
        ]
        
        // Create required folders if they don't exist
        for folder in folders {
            if !FileManager.default.fileExists(atPath: folder) {
                _ = FileFolderManagerUtil.createFolder(at: folder)
                Logger.info("Created folder: \(folder)", category: .core)
            }
        }
        
        // Check if Installomator labels exist
        // Installs labels at first launch
        Logger.info("Checking for Installomator labels...", category: .core)
        if !FileManager.default.fileExists(atPath: AppConstants.installomatorLabelsFolderURL.path) {
            Logger.info("Installomator labels not found. Downloading...", category: .core)
            downloadInstallomatorLabels()
        }
    }
    
    // MARK: - Setup Installomator Labels
    
    /// Downloads and installs Installomator labels from the official repository
    /// Sets appropriate file permissions after successful download
    static func downloadInstallomatorLabels() {
        InstallomatorLabels.installInstallomatorLabels { success, message in
            DispatchQueue.main.async {
                if success {
                    Logger.info("Installomator labels downloaded successfully.", category: .core)

                    if FileFolderManagerUtil.changePermissionsRecursively(
                        at: AppConstants.installomatorLabelsFolderURL.path,
                        to: 0o644,
                        excludeHiddenFiles: true,
                        skipDirectories: true
                    ) {
                        Logger.info("Permissions changed for files recursively!", category: .core)
                    }
                    if FileFolderManagerUtil.changePermissionsRecursively(
                        at: AppConstants.installomatorLabelsFolderURL.path,
                        to: 0o755,
                        excludeHiddenFiles: true,
                        skipDirectories: false
                    ) {
                        Logger.info("Permissions changed for directories recursively!", category: .core)
                    }
                } else {
                    Logger.error("Failed to download Installomator labels: \(message)", category: .core)
                }
            }
        }
    }
    
    
    /// Creates additional Launch Daemons for scheduled automation tasks
    /// Configures daemons for automation, cache cleanup, label updates, and update checks
    static func setupOtherLaunchDaemons() {
        
        let scheduledDaemons: [(label: String, argument: String, weekday: Weekday?, hour: Int)] = [
            ("com.gilburns.intuneomator.automation", "intune-automation", nil, 5),      // Daily
            ("com.gilburns.intuneomator.cachecleaner", "cache-cleanup", .monday, 6),   // Monday
            ("com.gilburns.intuneomator.labelupdater", "label-update", .friday, 6),    // Friday
            ("com.gilburns.intuneomator.updatecheck", "update-check", .saturday, 6)    // Saturday
        ]

        for daemon in scheduledDaemons {
            let plistPath = "/Library/LaunchDaemons/\(daemon.label).plist"
            
            if !FileManager.default.fileExists(atPath: plistPath) {
                ScheduledTaskManager.configureScheduledTask(
                    label: daemon.label,
                    argument: daemon.argument,
                    schedules: [
                        (weekday: daemon.weekday, hour: daemon.hour, minute: 0)
                    ],
                    completion: { success, message in
                        Logger.info(success ? "✅ Created \(daemon.label)" : "❌ Failed to create \(daemon.label): \(message ?? "unknown error")", category: .core)
                    }
                )
            } else {
                Logger.info("ℹ️ \(daemon.label) already exists, skipping creation.", category: .core)
            }
        }
    }
    
}
