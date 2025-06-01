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
        var wrappedProcessedAppResults: ProcessedAppResults?
        var checkedIntune: Bool = false
        
        // For check version in Intune
        var appInfo: [FilteredIntuneAppInfo] = []
        
        Logger.log("--------------------------------------------------------", logType: logType)
        Logger.log("🚀 Start processing of \(folderName)", logType: "Automation")
        Logger.log("Start processing: \(folderName)", logType: logType)

        // Update the label plist with latest info using the .sh file.
        let folderResults = InstallomatorLabelProcessor.runProcessLabelScript(for: folderName)
        
        if !folderResults {
            Logger.log("  Failed to run Installomator script for \(folderName)", logType: logType)
            return
        }
                
        // Get the Processed App Results starter for this folder
        wrappedProcessedAppResults = extractDataForProcessedAppResults(from: folderName)
        guard var processedAppResults = wrappedProcessedAppResults else {
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
        
        // MARK: - Check Intune with expected app version
        
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
                let versionExistsInIntune = isVersionUploadedToIntune(appInfo: appInfo, version: processedAppResults.appVersionExpected)
                
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
        
        // MARK: - Check cache or Download the file if not local
        
        let cacheURLCheck = isVersionCached(forProcessedResult: processedAppResults)
        
        if cacheURLCheck != nil {
            let cacheURL: URL
            cacheURL = cacheURLCheck!
            // No download needed preocess to next step
            applyCached(cacheURL, to: &processedAppResults)
            Logger.log("  Used cache for \(folderName)", logType: logType)
        } else {
            // Download required before proceeding to next step
            do {
                let (armURL, x86URL) = try await downloadArchives(
                    for: processedAppResults,
                    folderName: folderName
                )
                
                let downloadType: String = processedAppResults.appLabelType
                let expectedTeamID: String = processedAppResults.appTeamID
                let expectedBundleID: String = processedAppResults.appBundleIdExpected

                if x86URL == nil {
                    Logger.log("Only ARM available for \(folderName)", logType: logType)

                    let downloadURL: URL = armURL
                    let fileUploadName: String = processedAppResults.appUploadFilename

                    // New Processing
                    switch downloadType.lowercased() {
                    case "pkg", "pkginzip", "pkgindmg", "pkgindmginzip":
                        
                        let (url, bundleID, version) = try await processPkgFile(downloadURL: downloadURL, folderName: folderName, downloadType: downloadType, fileUploadName: fileUploadName, expectedTeamID: expectedTeamID, expectedBundleID: expectedBundleID)
                        
                        var localURL: URL!
                        if let wrappedURL = url {
                            localURL = wrappedURL
                        }
                        processedAppResults.appBundleIdActual = bundleID
                        processedAppResults.appLocalURL = localURL.path
                        processedAppResults.appVersionActual = version

                    case "zip", "tbz", "dmg", "appindmginzip":
                        let (url, filename, bundleID, version) = try await processAppFile(downloadURL: downloadURL, folderName: folderName, downloadType: downloadType, deploymentType: 0, fileUploadName: fileUploadName, expectedTeamID: expectedTeamID, expectedBundleID: expectedBundleID)

                        var localURL: URL!
                        if let wrappedURL = url {
                            localURL = wrappedURL
                        }
                        processedAppResults.appBundleIdActual = bundleID
                        processedAppResults.appDisplayName = filename
                        processedAppResults.appLocalURL = localURL.path
                        processedAppResults.appVersionActual = version

                    default:
                        Logger.log("Unhandled download type: \(downloadType)", logType: logType)
                        throw NSError(domain: "ProcessingError", code: 101, userInfo: [NSLocalizedDescriptionKey: "Unsupported file type: \(downloadType)"])
                    }

                    
                } else {
                    Logger.log("Both ARM and x86 available for \(folderName)", logType: logType)
                    
                    let downloadType: String = processedAppResults.appLabelType
                    let downloadURL: URL = armURL
                    let downloadURLx86_64: URL!
                    if let wrappedURLx86_64: URL = x86URL {
                        downloadURLx86_64 = wrappedURLx86_64
                    } else {
                        return
                    }
                    let fileUploadName: String = processedAppResults.appUploadFilename
                    let expectedTeamID: String = processedAppResults.appTeamID
                    let expectedBundleID: String = processedAppResults.appBundleIdExpected
                    
                    let (url, appName, bundleID, version)  =  try await processDualAppFiles(downloadURL: downloadURL, downloadURLx86_64: downloadURLx86_64, folderName: folderName, downloadType: downloadType, fileUploadName: fileUploadName, expectedTeamID: expectedTeamID, expectedBundleID: expectedBundleID)
                    
                    var localURL: URL!
                    if let wrappedURL = url {
                        localURL = wrappedURL
                    }
                    
                    processedAppResults.appBundleIdActual = bundleID
                    processedAppResults.appDisplayName = appName
                    processedAppResults.appLocalURL = localURL.path
                    processedAppResults.appVersionActual = version

                }
                
            } catch {
                Logger.log("Download failed: \(error.localizedDescription)", logType: logType)
                return
            }

        }

        Logger.log("Processed \(processedAppResults)", logType: logType)
        // Process the file(s)
        
        
        
        // MARK: - Check download version against Intune versions
        if processedAppResults.appVersionActual != processedAppResults.appVersionExpected || checkedIntune == false {
            Logger.log("  Version mismatch or Intune check not performed previously.", logType: logType)
            
            // Check Intune for an existing version
            Logger.log("  " + folderName + ": Fetching app info from Intune...", logType: logType)
            
            // Check if current actual version is already uploaded to Intune
            let versionExistsInIntune = isVersionUploadedToIntune(appInfo: appInfo, version: processedAppResults.appVersionActual)
            
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
        
        
        // MARK: - Write Upload log for tracking
        logUploadFileInfo(processedAppResults: processedAppResults)
        
        
        // MARK: - Check Intune for the new version and unassign or remove old versions.
        
        // Check Intune for the new version
        Logger.log("  " + folderName + ": Confirming app upload to Intune...", logType: logType)
        
        var uploadSucceeded: Bool = false
        do {
            let (uploadResult, appInfoResult) = await pollForIntuneUploadStatus(withID: appTrackingID, processedAppResults: processedAppResults, authToken: authToken)
            
            uploadSucceeded = uploadResult
            appInfo = appInfoResult
            Logger.log("Upload Result: \(uploadResult)")
            Logger.log("App Info Result: \(appInfoResult)")
        }

        Logger.log("App upload to Intune succeeded!")
        Logger.log("uploaded app ID: \(newAppID)")
        Logger.log("Upload Succeeded: \(uploadSucceeded)")
        Logger.log("App Info: \(appInfo)")

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
    
        
        // MARK: - Write the .uploaded file count for GUI app
        recordUploadCount(forAppFolder: folderName, appInfo: appInfo)
        
        
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
