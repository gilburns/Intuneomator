//
//  LabelAutomation+ProcessFolder.swift
//  Intuneomator
//
//  Created by Gil Burns on 5/22/25.
//

import Foundation

extension LabelAutomation {

    /// Orchestrates the complete end-to-end processing of an Installomator label folder
    ///
    /// This is the main workflow function that coordinates all aspects of processing a label:
    /// 
    /// **Processing Workflow:**
    /// 1. **Script Execution**: Runs the Installomator label script to generate metadata
    /// 2. **Metadata Extraction**: Parses the generated plist data for app information
    /// 3. **Authentication**: Obtains Microsoft Graph API token for Intune operations
    /// 4. **Version Checking**: Checks if the expected version already exists in Intune
    /// 5. **Download/Cache**: Downloads app files or uses cached versions if available
    /// 6. **Processing**: Processes downloads based on architecture and deployment type
    /// 7. **Upload**: Uploads the processed package to Microsoft Intune
    /// 8. **Validation**: Confirms successful upload and validates app metadata
    /// 9. **Cleanup**: Removes old versions and unassigns superseded apps
    /// 10. **Notification**: Sends Teams notification if configured
    /// 11. **Cleanup**: Removes temporary files and folders
    ///
    /// **Architecture Handling:**
    /// - Single architecture: Uses `processAppFile()` or `processPkgFile()`
    /// - Dual architecture: Uses `processDualAppFiles()` for universal packages
    ///
    /// **Error Recovery:**
    /// - Performs cleanup on failures
    /// - Sends Teams notifications for critical errors
    /// - Removes failed uploads from Intune
    ///
    /// - Parameter folderName: Name of the label folder to process (format: "labelname_GUID")
    /// - Returns: Tuple containing:
    ///   - status: Descriptive message of the processing result
    ///   - displayName: Application display name
    ///   - appID: Intune application ID (if successful)
    ///   - success: Boolean indicating overall success/failure
    // MARK: - FULLY PROCESS FOLDER
    static func processFolder(named folderName: String) async -> (status: String, displayName: String, appID: String, success: Bool) {
        
        // Validate input parameter
        guard !folderName.isEmpty else {
            Logger.log("❌ Invalid folder name provided", logType: logType)
            return ("Invalid folder name provided", "", "", false)
        }
        
        // Variables to track label processing
        var wrappedProcessedAppResults: ProcessedAppResults?
        var checkedIntune: Bool = false
        
        // For version checking in Intune
        var appInfo: [FilteredIntuneAppInfo] = []
        
        Logger.log("--------------------------------------------------------", logType: logType)
        Logger.log("🚀 Start processing of \(folderName)", logType: "Automation")

        // Update the label plist with latest info using the .sh file.
        let folderResults = InstallomatorLabelProcessor.runProcessLabelScript(for: folderName)
        
        if !folderResults {
            Logger.log("  Failed to run Installomator script for \(folderName)", logType: logType)
            return ("Failed to run Installomator script for \(folderName)", "", "", false)
        }
                
        // Get the Processed App Results starter for this folder
        wrappedProcessedAppResults = extractDataForProcessedAppResults(from: folderName)
        guard var processedAppResults = wrappedProcessedAppResults else {
            Logger.log("ProcessedAppResults unexpectedly nil", logType: logType)
            return ("\(folderName) ProcessedAppResults unexpectedly nil", "", "", false)

        }
        
        Logger.log("  Extracted ProcessedAppResults data for \(processedAppResults.appDisplayName)", logType: logType)
        
        Logger.log("  Label: \(processedAppResults.appLabelName)", logType: logType)
        Logger.log("  Tracking ID: \(processedAppResults.appTrackingID)", logType: logType)
        Logger.log("  Version to check: \(processedAppResults.appVersionExpected)", logType: logType)
        
        
        let appLabelName = processedAppResults.appLabelName
        let appTrackingID = processedAppResults.appTrackingID
        
        
        // MARK: - Authentication
        
        // Obtain Microsoft Graph API token for Intune operations
        let authToken: String
        do {
            let entraAuthenticator = EntraAuthenticator()
            authToken = try await entraAuthenticator.getEntraIDToken()
            Logger.log("✅ Successfully obtained Entra ID token", logType: logType)
        } catch {
            Logger.log("❌ Failed to get Entra ID Token: \(error.localizedDescription)", logType: logType)
            let errorMessage = "\(processedAppResults.appDisplayName) \(processedAppResults.appTrackingID) failed to get Entra ID Token"
            return (errorMessage, processedAppResults.appDisplayName, "", false)
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
                
                // Check if current version already exists in Intune
                let versionExistsInIntune = isVersionUploadedToIntune(appInfo: appInfo, version: processedAppResults.appVersionExpected)
                
                // Version is already in Intune. No need to continue
                if versionExistsInIntune {
                    Logger.log("    ---", logType: logType)
                    Logger.log("    Version \(processedAppResults.appVersionExpected) already exists in Intune", logType: logType)
                    return ("\(processedAppResults.appDisplayName) \(processedAppResults.appVersionActual) already exists in Intune", "", "", true)

                }
                
                checkedIntune = true
                
                Logger.log("  Version \(processedAppResults.appVersionExpected) is not yet uploaded to Intune", logType: logType)
                
            } catch {
                Logger.log("Failed to fetch app info from Intune: \(error.localizedDescription)", logType: logType)
                return ("\(processedAppResults.appDisplayName) \(processedAppResults.appTrackingID) failed to fetch app info from Intune.", "", "", false)

            }
        }
        
        // MARK: - Check cache or Download the file if not local
        
        let cacheURLCheck = isVersionCached(forProcessedResult: processedAppResults)
        
        if let cacheURL = cacheURLCheck {
            // No download needed, use cached version
            applyCached(cacheURL, to: &processedAppResults)
            Logger.log("✅ Used cached version for \(folderName)", logType: logType)
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
                let expectedVersion: String = processedAppResults.appVersionExpected
                let deploymentType: Int = processedAppResults.appDeploymentType
                let deploymentArch: Int = processedAppResults.appDeploymentArch

                if x86URL == nil {
                    Logger.log("Only ARM available for \(folderName)", logType: logType)

                    let downloadURL: URL = armURL
                    let fileUploadName: String = processedAppResults.appUploadFilename

                    // New Processing
                    switch downloadType.lowercased() {
                    case "pkg", "pkginzip", "pkgindmg", "pkgindmginzip":
                        
                        let (url, bundleID, version) = try await processPkgFile(downloadURL: downloadURL, folderName: folderName, downloadType: downloadType, fileUploadName: fileUploadName, expectedTeamID: expectedTeamID, expectedBundleID: expectedBundleID, expectedVersion: expectedVersion)
                        
                        guard let localURL = url else {
                            throw NSError(domain: "ProcessingError", code: 129, userInfo: [NSLocalizedDescriptionKey: "PKG processing failed - no output URL"])
                        }
                        
                        processedAppResults.appBundleIdActual = bundleID
                        processedAppResults.appLocalURL = localURL.path
                        processedAppResults.appVersionActual = version

                    case "zip", "tbz", "dmg", "appindmginzip":
                        let (url, filename, bundleID, version) = try await processAppFile(downloadURL: downloadURL, folderName: folderName, downloadType: downloadType, deploymentType: deploymentType, fileUploadName: fileUploadName, expectedTeamID: expectedTeamID, expectedBundleID: expectedBundleID, expectedVersion: expectedVersion)

                        guard let localURL = url else {
                            throw NSError(domain: "ProcessingError", code: 130, userInfo: [NSLocalizedDescriptionKey: "App processing failed - no output URL"])
                        }
                        
                        processedAppResults.appBundleIdActual = bundleID
                        processedAppResults.appDisplayName = filename
                        processedAppResults.appLocalURL = localURL.path
                        processedAppResults.appVersionActual = version

                    default:
                        Logger.log("❌ Unsupported download type: \(downloadType)", logType: logType)
                        throw NSError(domain: "ProcessingError", code: 131, userInfo: [NSLocalizedDescriptionKey: "Unsupported file type: \(downloadType)"])
                    }

                    
                } else {
                    Logger.log("Both ARM and x86 available for \(folderName)", logType: logType)
                    
                    let downloadType: String = processedAppResults.appLabelType
                    let downloadURL: URL = armURL
                    guard let downloadURLx86_64 = x86URL else {
                        let errorMessage = "\(processedAppResults.appDisplayName) \(processedAppResults.appVersionActual) x86_64 binary not available"
                        Logger.log("❌ \(errorMessage)", logType: logType)
                        return (errorMessage, processedAppResults.appDisplayName, "", false)
                    }
                    let fileUploadName: String = processedAppResults.appUploadFilename
                    let expectedTeamID: String = processedAppResults.appTeamID
                    let expectedBundleID: String = processedAppResults.appBundleIdExpected
                    
                    let (url, appName, bundleID, version) = try await processDualAppFiles(downloadURL: downloadURL, downloadURLx86_64: downloadURLx86_64, folderName: folderName, downloadType: downloadType, fileUploadName: fileUploadName, expectedTeamID: expectedTeamID, expectedBundleID: expectedBundleID)
                    
                    guard let localURL = url else {
                        throw NSError(domain: "ProcessingError", code: 132, userInfo: [NSLocalizedDescriptionKey: "Dual-architecture processing failed - no output URL"])
                    }
                    
                    processedAppResults.appBundleIdActual = bundleID
                    processedAppResults.appDisplayName = appName
                    processedAppResults.appLocalURL = localURL.path
                    processedAppResults.appVersionActual = version

                }
                
            } catch {
                Logger.log("❌ Download/processing failed: \(error.localizedDescription)", logType: logType)
                // Attempt cleanup on processing failure
                let _ = cleanUpTmpFiles(forAppLabel: appLabelName)
                let errorMessage = "\(processedAppResults.appDisplayName) \(processedAppResults.appVersionActual) download/processing failed: \(error.localizedDescription)"
                return (errorMessage, processedAppResults.appDisplayName, "", false)
            }

        }

        Logger.log("Processed \(processedAppResults)", logType: logType)
        // Process the file(s)
        
        
        
        // MARK: - Check download version against Intune versions
        if processedAppResults.appVersionActual != processedAppResults.appVersionExpected || checkedIntune == false {
            Logger.log("  Version mismatch or Intune check not performed previously.", logType: logType)
            
            let deployAsArchTag = DeploymentArchTag(rawValue: processedAppResults.appDeploymentArch) ?? .arm64
            let deploymentTypeTag = DeploymentTypeTag(rawValue: processedAppResults.appDeploymentType) ?? .dmg

            do {
                let newFileName = try MetadataLoader.finalFilename(forAppTitle: processedAppResults.appDisplayName, version: processedAppResults.appVersionActual, deploymentType: deploymentTypeTag, deploymentArch: deployAsArchTag, isDualArch: processedAppResults.appIsDualArchCapable)
                processedAppResults.appUploadFilename = newFileName
            } catch {
                Logger.log("Error constructing new filename: \(error.localizedDescription)", logType: logType)
                return ("\(processedAppResults.appDisplayName) \(processedAppResults.appVersionActual)  download failed: \(error.localizedDescription)", "\(processedAppResults.appDisplayName)", "", false)
            }
            
            // Check Intune for an existing version
            Logger.log("  " + folderName + ": Fetching app info from Intune...", logType: logType)
            
            // Check if current actual version already exists in Intune
            let versionExistsInIntune = isVersionUploadedToIntune(appInfo: appInfo, version: processedAppResults.appVersionActual)
            
            // Version is already in Intune. No need to continue
            if versionExistsInIntune {
                Logger.log("    ---", logType: logType)
                Logger.log("    Version \(processedAppResults.appVersionActual) already exists in Intune", logType: logType)
                
                
                // Clean up the download before we bail
                let deleteFolder = cleanUpTmpFiles(forAppLabel: appLabelName)
                Logger.log("✅ Folder cleanup: \(deleteFolder)", logType: logType)
                let successMessage = "\(processedAppResults.appDisplayName) \(processedAppResults.appVersionActual) already exists in Intune"
                return (successMessage, processedAppResults.appDisplayName, "", true)
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
                Logger.log("❌ Upload file does not exist at path: \(localFilePath)", logType: logType)
                let errorMessage = "Upload file does not exist at path. Please check the logs for file path and try again."
                let messageResult = await TeamsNotifier.processNotification(for: processedAppResults, success: false, errorMessage: errorMessage)
                Logger.log("📧 Teams notification sent: \(messageResult)", logType: logType)
                
                // Cleanup before returning
                let _ = cleanUpTmpFiles(forAppLabel: appLabelName)
                
                let returnMessage = "\(processedAppResults.appDisplayName) \(processedAppResults.appVersionActual): File not found: \(localFilePath)"
                return (returnMessage, processedAppResults.appDisplayName, "", false)
            }

            // Call the upload function
            newAppID = try await EntraGraphRequests.uploadAppToIntune(authToken: authToken, app: processedAppResults)
            
            Logger.log("New app ID post upload: \(newAppID)", logType: logType)
            
            guard !newAppID.isEmpty else {
                return ("\(processedAppResults.appDisplayName) \(processedAppResults.appVersionActual) failed to get AppID from upload to Intune", "\(processedAppResults.appDisplayName)", "", false)
            }
            
        } catch {
            Logger.log("❌ Upload to Intune failed: \(error.localizedDescription)", logType: logType)
            let errorMessage = "Error uploading \(processedAppResults.appLocalURL) to Intune: \(error.localizedDescription)"
            let messageResult = await TeamsNotifier.processNotification(for: processedAppResults, success: false, errorMessage: errorMessage)
            Logger.log("📧 Teams notification sent: \(messageResult)", logType: logType)
            
            // Cleanup before returning
            let _ = cleanUpTmpFiles(forAppLabel: appLabelName)
            
            let returnMessage = "\(processedAppResults.appDisplayName) \(processedAppResults.appVersionActual) error uploading to Intune: \(error.localizedDescription)"
            return (returnMessage, processedAppResults.appDisplayName, "", false)
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

        Logger.log("✅ App upload to Intune succeeded!", logType: logType)
        Logger.log("✅ Uploaded app ID: \(newAppID)", logType: logType)
        Logger.log("✅ Upload succeeded: \(uploadSucceeded)", logType: logType)
        Logger.log("📋 App info count: \(appInfo.count)", logType: logType)

        // Clean up Intune for failed upload
        if !uploadSucceeded {
            Logger.log("❌ \(folderName): App upload to Intune failed!", logType: logType)
            
            // Attempt to delete the failed upload
            if !newAppID.isEmpty {
                do {
                    try await EntraGraphRequests.deleteIntuneApp(authToken: authToken, appId: newAppID)
                    Logger.log("✅ Cleaned up failed upload from Intune", logType: logType)
                } catch {
                    Logger.log("❌ Error deleting failed Intune app: \(error.localizedDescription)", logType: logType)
                }
            }
            
            // Cleanup temporary files
            let _ = cleanUpTmpFiles(forAppLabel: appLabelName)
            
            let errorMessage = "\(processedAppResults.appDisplayName) \(processedAppResults.appVersionActual) failed to upload to Intune"
            return (errorMessage, processedAppResults.appDisplayName, "", false)
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
            return ("\(processedAppResults.appDisplayName) \(processedAppResults.appVersionActual) uploaded. Failed to delete older apps from Intune: \(error.localizedDescription)", "\(processedAppResults.appDisplayName)", newAppID, true)
        }

        
        // MARK: - Write the .uploaded file count for GUI app
        recordUploadCount(forAppFolder: folderName, appInfo: appInfo)
        
        
        // MARK: - Send Teams Notification
                
        let notificationStyle = ConfigManager.readPlistValue(key: "TeamsNotificationsStyle") ?? 0
        let notificationsEnabled = ConfigManager.readPlistValue(key: "TeamsNotificationsEnabled") ?? false
        if notificationStyle == 0 && notificationsEnabled {
            let didSend = await TeamsNotifier.processNotification(
                for: processedAppResults,
                success: uploadSucceeded
            )
            if didSend {
                Logger.log("Message sent to Teams channel")
            }
        }
        
        
        // MARK: - Clean up
        // MARK: - Final Cleanup
        
        let deleteFolder = cleanUpTmpFiles(forAppLabel: appLabelName)
        Logger.log("✅ Final cleanup completed: \(deleteFolder)", logType: logType)


        // MARK: - Return Success
        
        let successMessage = "\(processedAppResults.appDisplayName) \(processedAppResults.appVersionActual) uploaded to Intune."
        Logger.log("✅ Processing completed successfully: \(successMessage)", logType: logType)
        
        return (successMessage, processedAppResults.appDisplayName, newAppID, true)

    }
    
    
}
