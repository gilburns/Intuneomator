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
            Logger.info("Invalid folder name provided", category: .automation)
            return ("Invalid folder name provided", "", "", false)
        }
        
        // Variables to track label processing
        var wrappedProcessedAppResults: ProcessedAppResults?
        var checkedIntune: Bool = false
        
        // For version checking in Intune
        var appInfo: [FilteredIntuneAppInfo] = []
        
        Logger.info("--------------------------------------------------------", category: .automation)
        Logger.info("🚀 Start processing of \(folderName)", category: .automation)

        // Update the label plist with latest info using the .sh file.
        let folderResults = InstallomatorLabelProcessor.runProcessLabelScript(for: folderName)
        
        if !folderResults {
            Logger.error("  Failed to run Installomator script for \(folderName)", category: .automation)
            return ("Failed to run Installomator script for \(folderName)", "", "", false)
        }
                
        // Get the Processed App Results starter for this folder
        wrappedProcessedAppResults = extractDataForProcessedAppResults(from: folderName)
        guard var processedAppResults = wrappedProcessedAppResults else {
            Logger.info("ProcessedAppResults unexpectedly nil", category: .automation)
            return ("\(folderName) ProcessedAppResults unexpectedly nil", "", "", false)

        }
        
        Logger.info("  Extracted ProcessedAppResults data for \(processedAppResults.appDisplayName)", category: .automation)
        
        Logger.info("  Label: \(processedAppResults.appLabelName)", category: .automation)
        Logger.info("  Tracking ID: \(processedAppResults.appTrackingID)", category: .automation)
        Logger.info("  Version to check: \(processedAppResults.appVersionExpected)", category: .automation)
        
        
        let appLabelName = processedAppResults.appLabelName
        let appTrackingID = processedAppResults.appTrackingID
        let appDisplayName = processedAppResults.appDisplayName
        
        let operationId = "\(folderName)"
        let statusManager = StatusNotificationManager.shared
        
        // Start tracking
        statusManager.startOperation(
            operationId: operationId,
            labelName: appLabelName,
            appName: appDisplayName
        )

        
        // MARK: - Authentication
        
        // Obtain Microsoft Graph API token for Intune operations
        let authToken: String
        do {
            let entraAuthenticator = EntraAuthenticator.shared
            authToken = try await entraAuthenticator.getEntraIDToken()
        } catch {
            Logger.error("Failed to get Entra ID Token: \(error.localizedDescription)", category: .automation)
            let errorMessage = "\(processedAppResults.appDisplayName) \(processedAppResults.appTrackingID) failed to get Entra ID Token"
            statusManager.failOperation(operationId: operationId, errorMessage: errorMessage)
            return (errorMessage, processedAppResults.appDisplayName, "", false)
        }
        
        // MARK: - Check Intune with expected app version
        
        // appNewVersion has a known value.
        if processedAppResults.appVersionExpected != "" {
            
            // Check Intune for an existing version
            Logger.info("  " + folderName + ": Fetching app info from Intune...", category: .automation)
            
            do {
                statusManager.updateProcessingStatus(operationId, "Checking Intune for existing…")

                appInfo = try await EntraGraphRequests.findAppsByTrackingID(authToken: authToken, trackingID: appTrackingID)
                
                Logger.info("    Found \(appInfo.count) apps matching tracking ID \(appTrackingID)", category: .automation)
                
                for app in appInfo {
                    Logger.info("    ---", category: .automation)
                    Logger.info("    App: \(app.displayName)", category: .automation)
                    Logger.info("    Ver: \(app.primaryBundleVersion)", category: .automation)
                    Logger.info("     ID: \(app.id)", category: .automation)
                }
                
                // Check if current version already exists in Intune
                let versionExistsInIntune = isVersionUploadedToIntune(appInfo: appInfo, version: processedAppResults.appVersionExpected)
                
                // Version is already in Intune. No need to continue
                if versionExistsInIntune {
                    Logger.info("    ---", category: .automation)
                    Logger.info("    Version \(processedAppResults.appVersionExpected) already exists in Intune", category: .automation)
                    statusManager.failOperation(operationId: operationId, errorMessage: "Version \(processedAppResults.appVersionExpected) already exists in Intune")
                    return ("\(processedAppResults.appDisplayName) \(processedAppResults.appVersionActual) already exists in Intune", "", "", true)

                }
                
                checkedIntune = true
                
                Logger.info("  Version \(processedAppResults.appVersionExpected) is not yet uploaded to Intune", category: .automation)
                
            } catch {
                Logger.error("Failed to fetch app info from Intune: \(error.localizedDescription)", category: .automation)
                statusManager.failOperation(operationId: operationId, errorMessage: error.localizedDescription)
                return ("\(processedAppResults.appDisplayName) \(processedAppResults.appTrackingID) failed to fetch app info from Intune.", "", "", false)

            }
        }
        
        // MARK: - Check cache or Download the file if not local
        
        let cacheURLCheck = isVersionCached(forProcessedResult: processedAppResults)
        
        if let cacheURL = cacheURLCheck {
            // No download needed, use cached version
            applyCached(cacheURL, to: &processedAppResults)
            Logger.info("  Used cached version for \(folderName)", category: .automation)
        } else {
            // Download required before proceeding to next step
            do {
                statusManager.updateDownloadStatus(operationId, "Starting download")
                let (armURL, x86URL) = try await downloadArchives(
                    for: processedAppResults,
                    folderName: folderName,
                    operationId: operationId
                )
                
                let downloadType: String = processedAppResults.appLabelType
                let expectedTeamID: String = processedAppResults.appTeamID
                let expectedBundleID: String = processedAppResults.appBundleIdExpected
                let expectedVersion: String = processedAppResults.appVersionExpected
                let deploymentType: Int = processedAppResults.appDeploymentType
                let deploymentArch: Int = processedAppResults.appDeploymentArch

                if x86URL == nil {
                    Logger.info("Only ARM available for \(folderName)", category: .automation)

                    let downloadURL: URL = armURL
                    let fileUploadName: String = processedAppResults.appUploadFilename

                    statusManager.updateProcessingStatus(operationId, "Extracting files", progress: 0.0)

                    // New Processing
                    switch downloadType.lowercased() {
                    case "pkg", "pkginzip", "pkgindmg", "pkgindmginzip":
                        statusManager.updateProcessingStatus(operationId, "Processing PKG installer", progress: 0.3)

                        let (url, bundleID, version) = try await processPkgFile(downloadURL: downloadURL, folderName: folderName, downloadType: downloadType, fileUploadName: fileUploadName, expectedTeamID: expectedTeamID, expectedBundleID: expectedBundleID, expectedVersion: expectedVersion)
                        
                        statusManager.updateProcessingStatus(operationId, "PKG processing complete", progress: 1.0)

                        guard let localURL = url else {
                            throw NSError(domain: "ProcessingError", code: 129, userInfo: [NSLocalizedDescriptionKey: "PKG processing failed - no output URL"])
                        }
                        
                        processedAppResults.appBundleIdActual = bundleID
                        processedAppResults.appLocalURL = localURL.path
                        processedAppResults.appVersionActual = version

                    case "zip", "tbz", "dmg", "appindmginzip":
                        statusManager.updateProcessingStatus(operationId, "Processing app bundle", progress: 0.3)

                        let (url, filename, bundleID, version) = try await processAppFile(downloadURL: downloadURL, folderName: folderName, downloadType: downloadType, deploymentType: deploymentType, fileUploadName: fileUploadName, expectedTeamID: expectedTeamID, expectedBundleID: expectedBundleID, expectedVersion: expectedVersion)

                        statusManager.updateProcessingStatus(operationId, "App processing complete", progress: 1.0)

                        guard let localURL = url else {
                            throw NSError(domain: "ProcessingError", code: 130, userInfo: [NSLocalizedDescriptionKey: "App processing failed - no output URL"])
                        }
                        
                        processedAppResults.appBundleIdActual = bundleID
                        processedAppResults.appDisplayName = filename
                        processedAppResults.appLocalURL = localURL.path
                        processedAppResults.appVersionActual = version

                    default:
                        Logger.info("  Unsupported download type: \(downloadType)", category: .automation)
                        throw NSError(domain: "ProcessingError", code: 131, userInfo: [NSLocalizedDescriptionKey: "Unsupported file type: \(downloadType)"])
                    }

                    
                } else {
                    statusManager.updateProcessingStatus(operationId, "Extracting files", progress: 0.0)
                    Logger.info("Both ARM and x86 available for \(folderName)", category: .automation)
                    
                    let downloadType: String = processedAppResults.appLabelType
                    let downloadURL: URL = armURL
                    guard let downloadURLx86_64 = x86URL else {
                        let errorMessage = "\(processedAppResults.appDisplayName) \(processedAppResults.appVersionActual) x86_64 binary not available"
                        Logger.info("  \(errorMessage)", category: .automation)
                        statusManager.failOperation(operationId: operationId, errorMessage: errorMessage)
                        return (errorMessage, processedAppResults.appDisplayName, "", false)
                    }
                    let fileUploadName: String = processedAppResults.appUploadFilename
                    let expectedTeamID: String = processedAppResults.appTeamID
                    let expectedBundleID: String = processedAppResults.appBundleIdExpected
                    
                    let (url, appName, bundleID, version) = try await processDualAppFiles(downloadURL: downloadURL, downloadURLx86_64: downloadURLx86_64, folderName: folderName, downloadType: downloadType, fileUploadName: fileUploadName, expectedTeamID: expectedTeamID, expectedBundleID: expectedBundleID)
                    
                    guard let localURL = url else {
                        statusManager.failOperation(operationId: operationId, errorMessage: "Dual-architecture processing failed - no output URL")
                        throw NSError(domain: "ProcessingError", code: 132, userInfo: [NSLocalizedDescriptionKey: "Dual-architecture processing failed - no output URL"])
                    }
                    
                    processedAppResults.appBundleIdActual = bundleID
                    processedAppResults.appDisplayName = appName
                    processedAppResults.appLocalURL = localURL.path
                    processedAppResults.appVersionActual = version

                }
                
            } catch {
                Logger.info("  Download/processing failed: \(error.localizedDescription)", category: .automation)
                statusManager.failOperation(operationId: operationId, errorMessage: "Download/processing failed: \(error.localizedDescription)")

                // Attempt cleanup on processing failure
                let _ = cleanUpTmpFiles(forAppLabel: appLabelName)
                let errorMessage = "\(processedAppResults.appDisplayName) \(processedAppResults.appVersionActual) download/processing failed: \(error.localizedDescription)"
                return (errorMessage, processedAppResults.appDisplayName, "", false)
            }

        }

        Logger.info("Processed \(processedAppResults)", category: .automation)
        // Process the file(s)
        
        
        
        // MARK: - Check download version against Intune versions
        if processedAppResults.appVersionActual != processedAppResults.appVersionExpected || checkedIntune == false {
            Logger.info("  Version mismatch or Intune check not performed previously.", category: .automation)
            
            let deployAsArchTag = DeploymentArchTag(rawValue: processedAppResults.appDeploymentArch) ?? .arm64
            let deploymentTypeTag = DeploymentTypeTag(rawValue: processedAppResults.appDeploymentType) ?? .dmg

            do {
                let newFileName = try MetadataLoader.finalFilename(forAppTitle: processedAppResults.appDisplayName, version: processedAppResults.appVersionActual, deploymentType: deploymentTypeTag, deploymentArch: deployAsArchTag, isDualArch: processedAppResults.appIsDualArchCapable)
                processedAppResults.appUploadFilename = newFileName
            } catch {
                Logger.error("Error constructing new filename: \(error.localizedDescription)", category: .automation)
                statusManager.failOperation(operationId: operationId, errorMessage: "Error constructing new filename: \(error.localizedDescription)")
                return ("\(processedAppResults.appDisplayName) \(processedAppResults.appVersionActual)  download failed: \(error.localizedDescription)", "\(processedAppResults.appDisplayName)", "", false)
            }
            
            // Check Intune for an existing version
            Logger.info("  " + folderName + ": Fetching app info from Intune...", category: .automation)
            
            // Check if current actual version already exists in Intune
            let versionExistsInIntune = isVersionUploadedToIntune(appInfo: appInfo, version: processedAppResults.appVersionActual)
            
            // Version is already in Intune. No need to continue
            if versionExistsInIntune {
                Logger.info("    ---", category: .automation)
                Logger.info("    Version \(processedAppResults.appVersionActual) already exists in Intune", category: .automation)
                
                // Clean up the download before we bail
                let deleteFolder = cleanUpTmpFiles(forAppLabel: appLabelName)
                Logger.info("  Folder cleanup: \(deleteFolder)", category: .automation)
                let successMessage = "\(processedAppResults.appDisplayName) \(processedAppResults.appVersionActual) already exists in Intune"
                statusManager.failOperation(operationId: operationId, errorMessage: "Version \(processedAppResults.appVersionActual) already exists in Intune")
                return (successMessage, processedAppResults.appDisplayName, "", true)
            }

            checkedIntune = true
            
            Logger.info("  Version \(processedAppResults.appVersionActual) is not yet uploaded to Intune", category: .automation)
        }

        // MARK: - Upload to Intune
        // Store the newly created app in case we need the value later
        var newAppID: String = ""
        do {
                        
           let localFilePath = processedAppResults.appLocalURL

            guard FileManager.default.fileExists(atPath: localFilePath) else {
                Logger.info("  Upload file does not exist at path: \(localFilePath)", category: .automation)
                let errorMessage = "Upload file does not exist at path. Please check the logs for file path and try again."
                let messageResult = await TeamsNotifier.processNotification(for: processedAppResults, success: false, errorMessage: errorMessage)
                Logger.info("📧 Teams notification sent: \(messageResult)", category: .automation)
                
                // Cleanup before returning
                let _ = cleanUpTmpFiles(forAppLabel: appLabelName)
                
                let returnMessage = "\(processedAppResults.appDisplayName) \(processedAppResults.appVersionActual): File not found: \(localFilePath)"
                statusManager.failOperation(operationId: operationId, errorMessage: "File not found")
                return (returnMessage, processedAppResults.appDisplayName, "", false)
            }

            // Call the upload function
            statusManager.updateUploadStatus(operationId, "Uploading to Microsoft Intune", progress: 0.0)
            newAppID = try await EntraGraphRequests.uploadAppToIntune(authToken: authToken, app: processedAppResults, operationId: operationId)
            statusManager.updateUploadStatus(operationId, "Upload completed", progress: 1.0)
            Logger.info("New app ID post upload: \(newAppID)", category: .automation)
            
            guard !newAppID.isEmpty else {
                statusManager.failOperation(operationId: operationId, errorMessage: "\(processedAppResults.appDisplayName) \(processedAppResults.appVersionActual) failed to get AppID from upload to Intune")

                return ("\(processedAppResults.appDisplayName) \(processedAppResults.appVersionActual) failed to get AppID from upload to Intune", "\(processedAppResults.appDisplayName)", "", false)
            }
            
        } catch {
            Logger.info("  Upload to Intune failed: \(error.localizedDescription)", category: .automation)
            let errorMessage = "Error uploading \(processedAppResults.appLocalURL) to Intune: \(error.localizedDescription)"
            let messageResult = await TeamsNotifier.processNotification(for: processedAppResults, success: false, errorMessage: errorMessage)
            Logger.info("📧 Teams notification sent: \(messageResult)", category: .automation)
            
            // Cleanup before returning
            let _ = cleanUpTmpFiles(forAppLabel: appLabelName)
            
            let returnMessage = "\(processedAppResults.appDisplayName) \(processedAppResults.appVersionActual) error uploading to Intune: \(error.localizedDescription)"
            statusManager.failOperation(operationId: operationId, errorMessage: "\(processedAppResults.appDisplayName) \(processedAppResults.appVersionActual) error uploading to Intune: \(error.localizedDescription)")

            return (returnMessage, processedAppResults.appDisplayName, "", false)
        }

        
        // MARK: - Write Upload log for tracking
        logUploadFileInfo(processedAppResults: processedAppResults)
        
        
        // MARK: - Check Intune for the new version and unassign or remove old versions.
        
        // Check Intune for the new version
        Logger.info("  " + folderName + ": Confirming app upload to Intune...", category: .automation)
        statusManager.updateOperation(
            operationId: operationId,
            status: .uploading,
            phaseName: "Verifying Upload",
            phaseDetail: "Confirming upload completed successfully"
        )

        var uploadSucceeded: Bool = false
        do {
            let (uploadResult, appInfoResult) = await pollForIntuneUploadStatus(withID: appTrackingID, processedAppResults: processedAppResults, authToken: authToken)
            
            uploadSucceeded = uploadResult
            appInfo = appInfoResult
            Logger.log("Upload Result: \(uploadResult)")
            Logger.log("App Info Result: \(appInfoResult)")
        }

        Logger.info("✅ App upload to Intune succeeded!", category: .automation)
        Logger.info("✅ Uploaded app ID: \(newAppID)", category: .automation)
        Logger.info("✅ Upload succeeded: \(uploadSucceeded)", category: .automation)
        Logger.info("📋 App info count: \(appInfo.count)", category: .automation)

        // Clean up Intune for failed upload
        if !uploadSucceeded {
            Logger.info("❌ \(folderName): App upload to Intune failed!", category: .automation)
            
            statusManager.updateOperation(
                operationId: operationId,
                status: .processing,
                phaseName: "Cleanup",
                phaseDetail: "Removing old versions from Intune"
            )

            // Attempt to delete the failed upload
            if !newAppID.isEmpty {
                do {
                    try await EntraGraphRequests.deleteIntuneApp(authToken: authToken, appId: newAppID)
                    Logger.info("✅ Cleaned up failed upload from Intune", category: .automation)
                } catch {
                    Logger.error("❌ Error deleting failed Intune app: \(error.localizedDescription)", category: .automation)
                }
            }
            
            // Cleanup temporary files
            let _ = cleanUpTmpFiles(forAppLabel: appLabelName)
            
            let errorMessage = "\(processedAppResults.appDisplayName) \(processedAppResults.appVersionActual) failed to upload to Intune"
            statusManager.failOperation(operationId: operationId, errorMessage: errorMessage)
            return (errorMessage, processedAppResults.appDisplayName, "", false)
        }

        // ...continue with unassigning/removing old versions
        // Unassign old versions
        do {
            
            for app in appInfo {
                Logger.info("App: \(app.displayName)", category: .automation)
                Logger.info("Version: \(app.primaryBundleVersion)", category: .automation)
                Logger.info("Tracking ID: \(app.id)", category: .automation)
                
                if app.primaryBundleVersion != processedAppResults.appVersionActual {
                    if app.isAssigned == true {
                        Logger.info("Older assigned version found in Intune!", category: .automation)
                        Logger.info("Unassigning older version for app \(app.displayName)", category: .automation)
                        Logger.info("Unassigning older version for app \(app.primaryBundleVersion)", category: .automation)
                        Logger.info("Unassigning older version for app \(app.id)", category: .automation)

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
                    Logger.info("Deleting older app \(app.displayName)", category: .automation)
                    Logger.info("Deleting older app \(app.primaryBundleVersion)", category: .automation)
                    Logger.info("Deleting older app \(app.id)", category: .automation)
                    try await EntraGraphRequests.deleteIntuneApp(authToken: authToken, appId: app.id)
                }
            }
            
        } catch {
            Logger.error("Failed to delete older apps from Intune: \(error.localizedDescription)", category: .automation)
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
        Logger.info("✅ Final cleanup completed: \(deleteFolder)", category: .automation)


        // MARK: - Return Success
        
        let successMessage = "\(processedAppResults.appDisplayName) \(processedAppResults.appVersionActual) uploaded to Intune."
        Logger.info("✅ Processing completed successfully: \(successMessage)", category: .automation)
        statusManager.completeOperation(operationId: operationId)
        return (successMessage, processedAppResults.appDisplayName, newAppID, true)

    }
    
    
}
