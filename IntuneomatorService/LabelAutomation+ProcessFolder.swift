//
//  LabelAutomation+ProcessFolder.swift
//  Intuneomator
//
//  Created by Gil Burns on 5/22/25.
//

import Foundation

extension LabelAutomation {

    // MARK: - FULLY PROCESS FOLDER
    static func processFolder(named folderName: String) async {
        
        // Variables to track label processing
        var processedAppResults: ProcessedAppResults?
        var checkedIntune: Bool = false
        
        // For check version in Intune
        var appInfo: [FilteredIntuneAppInfo]
        
        Logger.log("--------------------------------------------------------", logType: logType)
        Logger.log("🚀 Start processing of \(folderName)", logType: logType)
        Logger.log("Start processing: \(folderName)", logType: logType)

        let folderResults = InstallomatorLabelProcessor.runProcessLabelScript(for: folderName)
        
        if !folderResults {
            Logger.log("  Failed to run Installomator script for \(folderName)", logType: logType)
            return
        }
                
        // Get the Processed App Results starter for this folder
        processedAppResults = extractDataForProcessedAppResults(from: folderName)
        
        Logger.log("  Extracted ProcessedAppResults data for \(processedAppResults?.appDisplayName ?? "Unknown")", logType: logType)
        
        Logger.log("  Label: \(String(describing: processedAppResults?.appLabelName))", logType: logType)
        Logger.log("  Tracking ID: \(String(describing: processedAppResults?.appTrackingID))", logType: logType)
        Logger.log("  Version to check: \(String(describing: processedAppResults?.appVersionExpected))", logType: logType)
        
        guard let trackingID = processedAppResults?.appTrackingID else {
            Logger.log("Tracking ID is missing", logType: logType)
            return
        }
                
        // MARK: - Check Intune with expected version
        
        // appNewVersion has a known value.
        if processedAppResults?.appVersionExpected != "" {
            
            // Check Intune for an existing version
            Logger.log("  " + folderName + ": Fetching app info from Intune...", logType: logType)
            
            do {
                let entraAuthenticator = EntraAuthenticator()
                let authToken = try await entraAuthenticator.getEntraIDToken()
                
                appInfo = try await EntraGraphRequests.findAppsByTrackingID(authToken: authToken, trackingID: trackingID)
                
                Logger.log("    Found \(appInfo.count) apps matching tracking ID \(trackingID)", logType: logType)
                
                for app in appInfo {
                    Logger.log("    ---", logType: logType)
                    Logger.log("    App: \(app.displayName)", logType: logType)
                    Logger.log("    Ver: \(app.primaryBundleVersion)", logType: logType)
                    Logger.log("     ID: \(app.id)", logType: logType)
                }
                
                // Check if current version is already uploaded to Intune
                let versionExistsInIntune = await isVersionUploadedToIntuneAsync(appInfo: appInfo, version: processedAppResults!.appVersionExpected)
                
                // Version is already in Intune. No need to continue
                if versionExistsInIntune {
                    Logger.log("    ---", logType: logType)
                    Logger.log("    Version \(processedAppResults!.appVersionExpected) is already uploaded to Intune", logType: logType)
                    return
                }
                
                checkedIntune = true
                
                Logger.log("  Version \(processedAppResults!.appVersionExpected) is not yet uploaded to Intune", logType: logType)
                
            } catch {
                Logger.log("Failed to fetch app info from Intune: \(error.localizedDescription)", logType: logType)
                return
            }
        }
        
        // MARK: - Check cache for pre-existing download
        
        var cacheCheckURL: URL = URL(fileURLWithPath: "/")
        
        do{
            let results = processedAppResults ?? .empty
            
            cacheCheckURL = try isVersionCached(
                forProcessedResult: results
            )

            Logger.log("cacheCheck: \(cacheCheckURL)", logType: logType)

        } catch {
            Logger.log("No cache data found", logType: logType)
        }
        
        
        
        // MARK: - Download the file
        
        if cacheCheckURL != URL(fileURLWithPath: "/") {
            Logger.log("Cache hit. No need to download", logType: logType)
            
            processedAppResults?.appLocalURL = cacheCheckURL.path

            let actualBundleID = processedAppResults?.appBundleIdExpected
            let actualVersion = processedAppResults?.appVersionExpected
            
            processedAppResults?.appBundleIdActual = actualBundleID ?? "None"
            processedAppResults?.appVersionActual = actualVersion ?? "None"
            
            Logger.log("  Processed file ready at: \(String(describing: processedAppResults?.appLocalURL))", logType: logType)
            Logger.log("  Version: \(String(describing: processedAppResults?.appVersionActual))", logType: logType)
            
        } else {
            Logger.log("Cache miss. Downloading...", logType: logType)
            
            // Proceed with the download
            do {
                // Version needs to be downloaded and then uploaded to intune
                let downloadURL = processedAppResults?.appDownloadURL
                
                Logger.log("  Download URL: \(String(describing: downloadURL))", logType: logType)
                guard ((downloadURL?.isEmpty) != nil) else {
                    Logger.log("  No download URL available for \(processedAppResults!.appDisplayName)", logType: logType)
                    return
                }
                
                var downloadedFileURLx86 = URL(string: "ftp://")!

                // First, download the file
                let downloadedFileURL = try await downloadFile(
                    for: folderName,
                    processedAppResults: processedAppResults!
                )
                
                // check for universal pkg
                if processedAppResults?.appDeploymentArch == 2 && MetadataLoader.titleIsDualArch(forFolder: folderName) {
                    Logger.log("Downloading x86 version of the app", logType: logType)
                    Logger.log("Deployment arch is \(processedAppResults?.appDeploymentArch ?? 5), and \(folderName) is dual arch", logType: logType)
                    let downloadedFileURL = try await downloadFile(
                        for: folderName,
                        processedAppResults: processedAppResults!,
                        downloadArch: "x86"
                    )
                    downloadedFileURLx86 = downloadedFileURL
                }
                
                Logger.log("  Downloaded file path: \(downloadedFileURL.path)", logType: logType)
                
                Logger.log ("  Processing file for: \(downloadURL ?? "None")", logType: logType)
                Logger.log("  Processing folder: \(folderName)", logType: logType)
                
                // MARK: - Process the downloaded file
                
                Logger.log("Downloaded file URL 1: \(downloadedFileURL)", logType: logType)
                Logger.log("Downloaded file URL 2: \(downloadedFileURLx86)", logType: logType)

                // Process the downloaded file based on its type
                let processedFileResult = try await processDownloadedFile(
                    displayName: processedAppResults!.appDisplayName,
                    downloadURL: downloadedFileURL,
                    downloadURLx86: downloadedFileURLx86,
                    folderName: folderName,
                    processedAppResults: processedAppResults!
                )
                Logger.log ("  Processed file result: \(processedFileResult)", logType: logType)
                
                Logger.log ("  URL: \(processedFileResult.url)", logType: logType)
                Logger.log ("  name: \(processedFileResult.name)", logType: logType)
                Logger.log ("  bundleID: \(processedFileResult.bundleID)", logType: logType)
                Logger.log ("  version: \(processedFileResult.version)", logType: logType)
                
                
                processedAppResults?.appLocalURL = processedFileResult.url.path
                if processedFileResult.name != "" {
                    processedAppResults?.appDisplayName = processedFileResult.name
                }
                if processedFileResult.bundleID != "" {
                    processedAppResults?.appBundleIdActual = processedFileResult.bundleID
                }
                if processedFileResult.version != "" {
                    processedAppResults?.appVersionActual = processedFileResult.version
                }
                
                
                Logger.log("  Processed file ready at: \(String(describing: processedAppResults?.appLocalURL))", logType: logType)
                Logger.log("  Version: \(String(describing: processedAppResults?.appVersionActual))", logType: logType)
                
                
                
                // MARK: - Check Intune with download version
                if processedAppResults?.appVersionActual != processedAppResults?.appVersionExpected || checkedIntune == false {
                    Logger.log("  Version mismatch or Intune check not performed previously.", logType: logType)
                    
                    // Check Intune for an existing version
                    Logger.log("  " + folderName + ": Fetching app info from Intune...", logType: logType)
                    
                    do {
                        let entraAuthenticator = EntraAuthenticator()
                        let authToken = try await entraAuthenticator.getEntraIDToken()
                        
                        appInfo = try await EntraGraphRequests.findAppsByTrackingID(authToken: authToken, trackingID: trackingID)
                        
                        Logger.log("  Found \(appInfo.count) apps matching tracking ID \(trackingID)", logType: logType)
                        
                        for app in appInfo {
                            Logger.log("    ---", logType: logType)
                            Logger.log("    App: \(app.displayName)", logType: logType)
                            Logger.log("    Ver: \(app.primaryBundleVersion)", logType: logType)
                            Logger.log("     ID: \(app.id)", logType: logType)
                        }
                        
                        // Check if current version is already uploaded to Intune
                        let versionExistsInIntune = await isVersionUploadedToIntuneAsync(appInfo: appInfo, version: processedAppResults!.appVersionActual)
                        
                        // Version is already in Intune. No need to continue
                        if versionExistsInIntune {
                            Logger.log("    ---", logType: logType)
                            Logger.log("    Version \(processedAppResults!.appVersionActual) is already uploaded to Intune", logType: logType)
                                         
                            
                            // Clean up the download before we bail
                            let downloadFolder = AppConstants.intuneomatorCacheFolderURL
                                .appendingPathComponent(processedAppResults!.appLabelName)
                                .appendingPathComponent("tmp")
                            
                            if FileManager.default.fileExists(atPath: downloadFolder.path) {
                                // Delete the tmp directory
                                do{
                                    try FileManager.default.removeItem(at: downloadFolder)
                                } catch {
                                    Logger.log("❌ Failed to delete tmp folder: \(error.localizedDescription)", logType: logType)
                                }
                            }
                            return
                        }
                        
                        checkedIntune = true
                        
                        Logger.log("  Version \(processedAppResults!.appVersionActual) is not yet uploaded to Intune", logType: logType)
                        
                    } catch {
                        let messageResult = TeamsNotifier.processNotification(for: processedAppResults ?? .empty, success: false, errorMessage: "Failed to fetch app info from Intune \(processedAppResults?.appDisplayName ?? "unknown"): \(error.localizedDescription)")
                        Logger.log("Failed to fetch app info from Intune \(processedAppResults?.appDisplayName ?? "unknown"): \(error.localizedDescription). Teams notification sent: \(messageResult)", logType: logType)
                        return
                    }
                }

            } catch {
                Logger.log("❌ Processing failed: \(error.localizedDescription)", logType: logType)
            }

        }
        
        Logger.log("\(processedAppResults!)", logType: logType)
        
        
        // MARK: - Upload to Intune
        do {
            
            let entraAuthenticator = EntraAuthenticator()
            let authToken = try await entraAuthenticator.getEntraIDToken()
            
            guard let localFilePath = processedAppResults?.appLocalURL else {
                Logger.log("No file to upload to Intune", logType: logType)
                return
            }
            
            guard FileManager.default.fileExists(atPath: localFilePath) else {
                let messageResult = TeamsNotifier.processNotification(for: processedAppResults ?? .empty, success: false, errorMessage: "Upload file does not exist at path. Please check the logs for file path and try again.")
                Logger.log("File does not exist. Teams notification sent: \(messageResult)", logType: logType)
                return
            }
            
            // Call the upload function
            try await EntraGraphRequests.uploadAppToIntune(authToken: authToken, app: processedAppResults!)
            
        } catch {
            let messageResult = TeamsNotifier.processNotification(for: processedAppResults ?? .empty, success: false, errorMessage: "Error uploading \(processedAppResults?.appLocalURL ?? "unknown") to Intune: \(error.localizedDescription)")
            Logger.log("Error uploading \(processedAppResults?.appLocalURL ?? "unknown") to Intune: \(error.localizedDescription). Teams notification sent: \(messageResult)", logType: logType)
        }
        
        
        // Get file size for logging
        do {
            let labelDisplayName = processedAppResults!.appDisplayName
            let labelName = processedAppResults!.appLabelName
            let finalFilename = URL(string: processedAppResults!.appLocalURL)?.lastPathComponent
            // file size
            let fileIdentifier = processedAppResults!.appBundleIdActual
            let fileVersionActual = processedAppResults!.appVersionActual
            let fileVersionExpected = processedAppResults!.appVersionExpected
            let labelTrackingID = processedAppResults!.appTrackingID
            let finalURL = processedAppResults!.appLocalURL

            let fileAttributes = try FileManager.default.attributesOfItem(atPath: finalURL)
            let fileSizeBytes = fileAttributes[.size] as? Int64 ?? 0
            let fileSizeMB = Double(fileSizeBytes) / 1_048_576
                    
            Logger.logNoDateStamp("\(labelDisplayName)\t\(labelName)\t\(finalFilename ?? "Unknown")\t\(String(format: "%.2f", fileSizeMB)) MB\t\(fileIdentifier)\t\(fileVersionActual)\t\(fileVersionExpected)\t\(labelTrackingID)\t\(finalURL)", logType: logType)
            
        } catch {
            Logger.log("Unable to get file size: \(error.localizedDescription)", logType: logType)
        }

        
        // MARK: - Check Intune for the new version and unassign or remove old versions.
        
        // Check Intune for the new version
        Logger.log("  " + folderName + ": Confirming app upload to Intune...", logType: logType)
        
        var uploadSucceeded: Bool = false
        
        do {
            try await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds

            let entraAuthenticator = EntraAuthenticator()
            let authToken = try await entraAuthenticator.getEntraIDToken()
            
            appInfo = try await EntraGraphRequests.findAppsByTrackingID(authToken: authToken, trackingID: trackingID)
            
            Logger.log("  Found \(appInfo.count) apps matching tracking ID \(trackingID)", logType: logType)
            
            // Check if current version is already uploaded to Intune
            uploadSucceeded = await isVersionUploadedToIntuneAsync(appInfo: appInfo, version: processedAppResults!.appVersionActual)
            
            // Version is in Intune. Success!
            if uploadSucceeded {
                Logger.log("Version \(processedAppResults!.appVersionActual) was uploaded to Intune", logType: logType)
            } else {
                Logger.log("Version \(processedAppResults!.appVersionActual) was NOT uploaded to Intune", logType: logType)
                return
            }

            
            // Unassign old versions
            for app in appInfo {
                Logger.log("App: \(app.displayName)", logType: logType)
                Logger.log("Version: \(app.primaryBundleVersion)", logType: logType)
                Logger.log("Tracking ID: \(app.id)", logType: logType)
                
                if app.primaryBundleVersion != processedAppResults!.appVersionActual {
                    if app.isAssigned == true {
                        Logger.log("Older assigned version found in Intune!", logType: logType)
                        Logger.log("Unassigning older version for app \(app.displayName)", logType: logType)
                        Logger.log("Unassigning older version for app \(app.primaryBundleVersion)", logType: logType)
                        Logger.log("Unassigning older version for app \(app.id)", logType: logType)

                        try await EntraGraphRequests.removeAllAppAssignments(authToken: authToken, appId: app.id)
                    }
                }
            }
            
            // Clean up extra older versions of the app
            let appVersionsToKeep = ConfigManager.readPlistValue(key: "AppVersionsToKeep") ?? 2
            let totalVersions = appInfo.count
            let versionsToDeleteCount = max(0, totalVersions - appVersionsToKeep)
            if versionsToDeleteCount > 0 {
                // Since appInfo is sorted oldest to newest, delete the earliest ones
                let appsToDelete = appInfo.prefix(versionsToDeleteCount)
                for app in appsToDelete {
                    guard !app.isAssigned else { continue }
                    Logger.log("Deleting older app \(app.displayName)", logType: logType)
                    Logger.log("Deleting older app \(app.primaryBundleVersion)", logType: logType)
                    Logger.log("Deleting older app \(app.id)", logType: logType)
                    try await EntraGraphRequests.deleteIntuneApp(authToken: authToken, appId: app.id)
                }
            }
            
        } catch {
            Logger.log("Failed to check for successful upload to Intune: \(error.localizedDescription)", logType: logType)
            return
        }
    
        
        // Write the .uploaded file count
        let appVersionsToKeep = ConfigManager.readPlistValue(key: "AppVersionsToKeep") ?? 2
        let totalVersions = appInfo.count
        let versionsToDeleteCount = max(0, totalVersions - appVersionsToKeep)

        let remainingCount = appInfo.count - versionsToDeleteCount
        
        do {

            let uploadedFileURL = AppConstants.intuneomatorManagedTitlesFolderURL
                .appendingPathComponent(folderName)
                .appendingPathComponent(".uploaded")

            if remainingCount > 0 {

                // Write app count to the file
                let appCountString = "\(remainingCount)"
                try appCountString.write(to: uploadedFileURL, atomically: true, encoding: .utf8)
            } else {

                if FileManager.default.fileExists(atPath: uploadedFileURL.path) {
                    try FileManager.default.removeItem(atPath: uploadedFileURL.path)
                }
            }

        } catch {
            Logger.log("❌ Error: \(error)", logType: logType)
        }

        
        // MARK: - Send Teams Notification
                
        let didSend = TeamsNotifier.processNotification(
            for: processedAppResults,
            success: uploadSucceeded
        )
        if didSend {
            Logger.log("Message sent to Teams channel")
        }
        
        
        // MARK: - Clean up
        // Clean up
        let downloadFolder = AppConstants.intuneomatorCacheFolderURL
            .appendingPathComponent(processedAppResults!.appLabelName)
            .appendingPathComponent("tmp")
        
        if FileManager.default.fileExists(atPath: downloadFolder.path) {
            // Delete the tmp directory
            do{
                try FileManager.default.removeItem(at: downloadFolder)
            } catch {
                Logger.log("❌ Failed to delete tmp folder: \(error.localizedDescription)", logType: logType)
            }
        }
    }
    
}
