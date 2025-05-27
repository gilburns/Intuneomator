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
        var appInfo: [FilteredIntuneAppInfo] = []
        
        Logger.log("--------------------------------------------------------", logType: logType)
        Logger.log("🚀 Start processing of \(folderName)", logType: "Automation")
        Logger.log("Start processing: \(folderName)", logType: logType)

        let folderResults = InstallomatorLabelProcessor.runProcessLabelScript(for: folderName)
        
        if !folderResults {
            Logger.log("  Failed to run Installomator script for \(folderName)", logType: logType)
            return
        }
                
        // Get the Processed App Results starter for this folder
        processedAppResults = extractDataForProcessedAppResults(from: folderName)
        
        guard var processedAppResults = processedAppResults else {
            Logger.log("ProcessedAppResults unexpectedly nil", logType: logType)
            return
        }
        
        Logger.log("  Extracted ProcessedAppResults data for \(processedAppResults.appDisplayName)", logType: logType)
        
        Logger.log("  Label: \(String(describing: processedAppResults.appLabelName))", logType: logType)
        Logger.log("  Tracking ID: \(String(describing: processedAppResults.appTrackingID))", logType: logType)
        Logger.log("  Version to check: \(String(describing: processedAppResults.appVersionExpected))", logType: logType)
        
        
        let appLabelName = processedAppResults.appLabelName
        let appTrackingID = processedAppResults.appTrackingID
        
        
        // Get Graph Token to use throughout the run
        var authToken: String
        do {
            let entraAuthenticator = EntraAuthenticator()
            authToken = try await entraAuthenticator.getEntraIDToken()
        } catch {
            Logger.log("Falied to get Entra ID Token: \(error)", logType: logType)
            // Teams Notification for auth failure
            return
        }
        
        // MARK: - Check Intune with expected version
        
        // appNewVersion has a known value.
        if processedAppResults.appVersionExpected != "" {
            
            // Check Intune for an existing version
            Logger.log("  " + folderName + ": Fetching app info from Intune...", logType: logType)
            
            do {
                
                appInfo = try await EntraGraphRequests.findAppsByTrackingID(authToken: authToken, trackingID: appTrackingID)
                
                Logger.log("    Found \(appInfo.count) apps matching tracking ID \(appTrackingID)", logType: logType)
                
                for app in appInfo {
                    Logger.log("    ---", logType: logType)
                    Logger.log("    App: \(app.displayName)", logType: logType)
                    Logger.log("    Ver: \(app.primaryBundleVersion)", logType: logType)
                    Logger.log("     ID: \(app.id)", logType: logType)
                }
                
                // Check if current version is already uploaded to Intune
                let versionExistsInIntune = isVersionUploadedToIntuneAsync(appInfo: appInfo, version: processedAppResults.appVersionExpected)
                
                // Version is already in Intune. No need to continue
                if versionExistsInIntune {
                    Logger.log("    ---", logType: logType)
                    Logger.log("    Version \(processedAppResults.appVersionExpected) is already uploaded to Intune", logType: logType)
                    return
                }
                
                checkedIntune = true
                
                Logger.log("  Version \(processedAppResults.appVersionExpected) is not yet uploaded to Intune", logType: logType)
                
            } catch {
                Logger.log("Failed to fetch app info from Intune: \(error.localizedDescription)", logType: logType)
                return
            }
        }
        
        // MARK: - Check cache for pre-existing download
        
        var cacheCheckURL: URL = URL(fileURLWithPath: "/")
        cacheCheckURL = isVersionCached(forProcessedResult: processedAppResults)
        Logger.log("cacheCheck: \(cacheCheckURL.path)", logType: logType)

        
        // MARK: - Download the file
        
        if cacheCheckURL != URL(fileURLWithPath: "/") {
            Logger.log("Cached item found. No need to download", logType: logType)
            
            processedAppResults.appLocalURL = cacheCheckURL.path

            let actualBundleID = processedAppResults.appBundleIdExpected
            let actualVersion = processedAppResults.appVersionExpected
            
            processedAppResults.appBundleIdActual = actualBundleID
            processedAppResults.appVersionActual = actualVersion
            
            Logger.log("  Processed file ready at: \(String(describing: processedAppResults.appLocalURL))", logType: logType)
            Logger.log("  Version: \(String(describing: processedAppResults.appVersionActual))", logType: logType)
            
        } else {
            Logger.log("Cache miss. Downloading...", logType: logType)
            
            // Proceed with the download
            do {
                // Version needs to be downloaded and then uploaded to intune
                let downloadURL = processedAppResults.appDownloadURL
                
                Logger.log("  Download URL: \(downloadURL)", logType: logType)
                                
                var downloadedFileURLx86 = URL(string: "ftp://")!

                // Download the file
                let downloadedFileURL = try await downloadFile(
                    for: folderName,
                    processedAppResults: processedAppResults
                )
                
                // check for universal pkg
                if processedAppResults.appDeploymentArch == 2 && MetadataLoader.titleIsDualArch(forFolder: folderName) {
                    Logger.log("Downloading x86 version of the app", logType: logType)
                    Logger.log("Deployment arch is \(processedAppResults.appDeploymentArch), and \(folderName) is dual arch", logType: logType)
                    let downloadedFileURL = try await downloadFile(
                        for: folderName,
                        processedAppResults: processedAppResults,
                        downloadArch: "x86"
                    )
                    downloadedFileURLx86 = downloadedFileURL
                }
                
                processedAppResults.appDownloadURL = downloadURL
                processedAppResults.appDownloadURLx86 = downloadedFileURLx86.path
                
                // MARK: - Process the downloaded file
                
                Logger.log("Downloaded file URL 1: \(downloadedFileURL)", logType: logType)
                Logger.log("Downloaded file URL 2: \(downloadedFileURLx86)", logType: logType)

                // Process the downloaded file based on its type
                let processedFileResult = try await processDownloadedFile(
                    displayName: processedAppResults.appDisplayName,
                    downloadURL: downloadedFileURL,
                    downloadURLx86: downloadedFileURLx86,
                    folderName: folderName,
                    processedAppResults: processedAppResults
                )
                Logger.log ("  Processed file result: \(processedFileResult)", logType: logType)
                
                Logger.log ("  URL: \(processedFileResult.url)", logType: logType)
                Logger.log ("  name: \(processedFileResult.name)", logType: logType)
                Logger.log ("  bundleID: \(processedFileResult.bundleID)", logType: logType)
                Logger.log ("  version: \(processedFileResult.version)", logType: logType)
                
                
                processedAppResults.appLocalURL = processedFileResult.url.path
                if processedFileResult.name != "" {
                    processedAppResults.appDisplayName = processedFileResult.name
                }
                if processedFileResult.bundleID != "" {
                    processedAppResults.appBundleIdActual = processedFileResult.bundleID
                }
                if processedFileResult.version != "" {
                    processedAppResults.appVersionActual = processedFileResult.version
                }
                
                
                Logger.log("  Processed file ready at: \(String(describing: processedAppResults.appLocalURL))", logType: logType)
                Logger.log("  Version: \(String(describing: processedAppResults.appVersionActual))", logType: logType)
                
                
                
                // MARK: - Check Intune with download version
                if processedAppResults.appVersionActual != processedAppResults.appVersionExpected || checkedIntune == false {
                    Logger.log("  Version mismatch or Intune check not performed previously.", logType: logType)
                    
                    // Check Intune for an existing version
                    Logger.log("  " + folderName + ": Fetching app info from Intune...", logType: logType)
                    
                    do {
                        
                        appInfo = try await EntraGraphRequests.findAppsByTrackingID(authToken: authToken, trackingID: appTrackingID)
                        
                        Logger.log("  Found \(appInfo.count) apps matching tracking ID \(appTrackingID)", logType: logType)
                        
                        for app in appInfo {
                            Logger.log("    ---", logType: logType)
                            Logger.log("    App: \(app.displayName)", logType: logType)
                            Logger.log("    Ver: \(app.primaryBundleVersion)", logType: logType)
                            Logger.log("     ID: \(app.id)", logType: logType)
                        }
                        
                        // Check if current version is already uploaded to Intune
                        let versionExistsInIntune = isVersionUploadedToIntuneAsync(appInfo: appInfo, version: processedAppResults.appVersionActual)
                        
                        // Version is already in Intune. No need to continue
                        if versionExistsInIntune {
                            Logger.log("    ---", logType: logType)
                            Logger.log("    Version \(processedAppResults.appVersionActual) is already uploaded to Intune", logType: logType)
                                         
                            
                            // Clean up the download before we bail
                            let deleteFolder = cleanUpTmpFiles(forAppLabel: appLabelName)
                            Logger.log("Folder cleanup : \(deleteFolder)", logType: logType)
                            return
                        }
                        
                        checkedIntune = true
                        
                        Logger.log("  Version \(processedAppResults.appVersionActual) is not yet uploaded to Intune", logType: logType)
                        
                    } catch {
                        let messageResult = TeamsNotifier.processNotification(for: processedAppResults, success: false, errorMessage: "Failed to fetch app info from Intune \(processedAppResults.appDisplayName): \(error.localizedDescription)")
                        Logger.log("Failed to fetch app info from Intune \(processedAppResults.appDisplayName): \(error.localizedDescription). Teams notification sent: \(messageResult)", logType: logType)
                        return
                    }
                }

            } catch {
                Logger.log("❌ Processing failed: \(error.localizedDescription)", logType: logType)
            }

        }
        
        // MARK: - Upload to Intune
        // Store the newly created app in case we need the value later
        var newAppID: String = ""
        do {
                        
           let localFilePath = processedAppResults.appLocalURL
            
            
            guard FileManager.default.fileExists(atPath: localFilePath) else {
                let messageResult = TeamsNotifier.processNotification(for: processedAppResults, success: false, errorMessage: "Upload file does not exist at path. Please check the logs for file path and try again.")
                Logger.log("File does not exist. Teams notification sent: \(messageResult)", logType: logType)
                return
            }
            
            // Call the upload function
            newAppID = try await EntraGraphRequests.uploadAppToIntune(authToken: authToken, app: processedAppResults)
            
        } catch {
            let messageResult = TeamsNotifier.processNotification(for: processedAppResults, success: false, errorMessage: "Error uploading \(processedAppResults.appLocalURL) to Intune: \(error.localizedDescription)")
            Logger.log("Error uploading \(processedAppResults.appLocalURL) to Intune: \(error.localizedDescription). Teams notification sent: \(messageResult)", logType: logType)
        }
        
        
        // Get file size for logging
        do {
            let labelDisplayName = processedAppResults.appDisplayName
            let labelName = processedAppResults.appLabelName
            let finalFilename = URL(string: processedAppResults.appLocalURL)?.lastPathComponent
            // file size
            let fileIdentifier = processedAppResults.appBundleIdActual
            let fileVersionActual = processedAppResults.appVersionActual
            let fileVersionExpected = processedAppResults.appVersionExpected
            let labelTrackingID = processedAppResults.appTrackingID
            let finalURL = processedAppResults.appLocalURL

            let fileAttributes = try FileManager.default.attributesOfItem(atPath: finalURL)
            let fileSizeBytes = fileAttributes[.size] as? Int64 ?? 0
            let fileSizeMB = Double(fileSizeBytes) / 1_048_576
                    
            // Write the upload info to the Upload log file
            Logger.logNoDateStamp("\(labelDisplayName)\t\(labelName)\t\(finalFilename ?? "Unknown")\t\(String(format: "%.2f", fileSizeMB)) MB\t\(fileIdentifier)\t\(fileVersionActual)\t\(fileVersionExpected)\t\(labelTrackingID)\t\(finalURL)", logType: "Upload")
            
        } catch {
            Logger.log("Unable to get file size: \(error.localizedDescription)", logType: logType)
        }

        
        // MARK: - Check Intune for the new version and unassign or remove old versions.
        
        // Check Intune for the new version
        Logger.log("  " + folderName + ": Confirming app upload to Intune...", logType: logType)
        
        var uploadSucceeded: Bool = false
        do {
            let (uploadResult, appInfo) = await pollForIntuneUploadStatus(withID: appTrackingID, processedAppResults: processedAppResults, authToken: authToken)
        }
        
        // clean up Intune for failed upload
        if uploadSucceeded == false {
            Logger.log("  " + folderName + ": App upload to Intune failed!", logType: logType)
            do {
                try await EntraGraphRequests.deleteIntuneApp(authToken: authToken, appId: newAppID)
            } catch {
                Logger.log("Error deleting Intune app: \(error.localizedDescription)", logType: logType)
                // Teams notification for failed delete?
            }
            return
        }
        
        // ...continue with unassigning/removing old versions
        // Unassign old versions
        do {
            
            for app in appInfo {
                Logger.log("App: \(app.displayName)", logType: logType)
                Logger.log("Version: \(app.primaryBundleVersion)", logType: logType)
                Logger.log("Tracking ID: \(app.id)", logType: logType)
                
                if app.primaryBundleVersion != processedAppResults.appVersionActual {
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
            Logger.log("Failed to delete older apps from Intune: \(error.localizedDescription)", logType: logType)
            return
        }
    
        
        // Write the .uploaded file count for GUI app
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
        
        let deleteFolder = cleanUpTmpFiles(forAppLabel: appLabelName)
        Logger.log("Folder cleanup : \(deleteFolder)", logType: logType)
    }
    
}
