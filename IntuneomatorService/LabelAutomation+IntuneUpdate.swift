//
//  LabelAutomation+UpdateIntune.swift
//  Intuneomator
//
//  Created by Gil Burns on 5/23/25.
//

import Foundation

extension LabelAutomation {
  
    // MARK: - UPDATE METADATA ONLY FOR FOLDER
    static func processFolderMetadata(named folderName: String) async {
        // Variables to track label processing
        var processedAppResults: ProcessedAppResults?

        // For check version in Intune
        var appInfo: [FilteredIntuneAppInfo]

        Logger.log("--------------------------------------------------------", logType: logType)
        Logger.log("🚀 Start metadata update of \(folderName)", logType: logType)
        Logger.log("Start metadata update of: \(folderName)", logType: logType)

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
        
        // MARK: - Check Intune for any versions
        
        // Check Intune for an existing versions
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
                
                
                // MARK: - Upload metadata to Intune
                do {
                    
                    let entraAuthenticator = EntraAuthenticator()
                    let authToken = try await entraAuthenticator.getEntraIDToken()
                    
                    // Call the update function
                    try await EntraGraphRequests.updateAppIntuneMetadata(authToken: authToken, app: processedAppResults!, appId: app.id)
                    
                    // Remove all categories
                    try await EntraGraphRequests.removeAllCategoriesFromIntuneApp(authToken: authToken, appID: app.id)
                    
                    // Assign the categories to the app
                    try await EntraGraphRequests.assignCategoriesToIntuneApp(
                        authToken: authToken,
                        appID: app.id,
                        categories: processedAppResults?.appCategories ?? []
                    )

                    
                } catch {
                    Logger.log("Error updating \(processedAppResults?.appDisplayName ?? "unknown") with AppID \(app.id) metadata in Intune: \(error.localizedDescription)", logType: logType)
                }
            }
            
        } catch {
            Logger.log("Failed to fetch app info from Intune: \(error.localizedDescription)", logType: logType)
            return
        }
    }

    // MARK: - UPDATE SCRIPTS ONLY FOR FOLDER
    static func processFolderScripts(named folderName: String) async {
        // Variables to track label processing
        var processedAppResults: ProcessedAppResults?

        // For check version in Intune
        var appInfo: [FilteredIntuneAppInfo]

        Logger.log("--------------------------------------------------------", logType: logType)
        Logger.log("🚀 Start scripts update of \(folderName)", logType: logType)
        Logger.log("Start scripts update of: \(folderName)", logType: logType)

        let folderResults = InstallomatorLabelProcessor.runProcessLabelScript(for: folderName)
        
        if !folderResults {
            Logger.log("  Failed to run Installomator script for \(folderName)", logType: logType)
            return
        }
                
        // Get the Processed App Results starter for this folder
        processedAppResults = extractDataForProcessedAppResults(from: folderName)
        
        Logger.log("  Extracted ProcessedAppResults data for \(processedAppResults?.appDisplayName ?? "Unknown")", logType: logType)
        
        Logger.log("  Label: \(String(describing: processedAppResults?.appLabelName))", logType: logType)
        
        guard let trackingID = processedAppResults?.appTrackingID else {
            Logger.log("Tracking ID is missing", logType: logType)
            return
        }
        Logger.log("  Tracking ID: \(trackingID)", logType: logType)


        // MARK: - Check Intune for any versions
        
        // Check Intune for an existing versions
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
                
                // MARK: - Upload scripts to Intune
                do {
                    
                    let entraAuthenticator = EntraAuthenticator()
                    let authToken = try await entraAuthenticator.getEntraIDToken()
                    
                    // Call the update function
                    try await EntraGraphRequests.updateAppIntuneScripts(authToken: authToken, app: processedAppResults!, appId: app.id)
                    
                } catch {
                    Logger.log("Error updating \(processedAppResults?.appDisplayName ?? "unknown") with AppID \(app.id) scripts in Intune: \(error.localizedDescription)", logType: logType)
                }
            }
            
        } catch {
            Logger.log("Failed to fetch app info from Intune: \(error.localizedDescription)", logType: logType)
            return
        }
    }

    
    // MARK: - UPDATE ASSIGNMENTS ONLY FOR FOLDER
    static func processFolderAssignments(named folderName: String) async {
        // Variables to track label processing
        var processedAppResults: ProcessedAppResults?

        // For check version in Intune
        var appInfo: [FilteredIntuneAppInfo]

        Logger.log("--------------------------------------------------------", logType: logType)
        Logger.log("🚀 Start assignment update of \(folderName)", logType: logType)
        Logger.log("Start assignment update of: \(folderName)", logType: logType)

        let folderResults = InstallomatorLabelProcessor.runProcessLabelScript(for: folderName)
        
        if !folderResults {
            Logger.log("  Failed to run Installomator script for \(folderName)", logType: logType)
            return
        }
                
        // Get the Processed App Results starter for this folder
        processedAppResults = extractDataForProcessedAppResults(from: folderName)
        
        Logger.log("  Extracted ProcessedAppResults data for \(processedAppResults?.appDisplayName ?? "Unknown")", logType: logType)
        
        Logger.log("  Label: \(String(describing: processedAppResults?.appLabelName))", logType: logType)
        
        guard let trackingID = processedAppResults?.appTrackingID else {
            Logger.log("Tracking ID is missing", logType: logType)
            return
        }
        Logger.log("  Tracking ID: \(trackingID)", logType: logType)


        // MARK: - Check Intune for any versions
        
        // Check Intune for an existing versions
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
                
                
                // MARK: - Update group assignments in Intune
                if app.isAssigned {
                    do {
                                            
                        // Remove all existing assignments
                        try await EntraGraphRequests.removeAllAppAssignments(authToken: authToken, appId: app.id)
                        
                        let intuneAppType: String
                        switch processedAppResults?.appDeploymentType {
                            case 0:
                            intuneAppType = "macOSDmgApp"
                        case 1:
                            intuneAppType = "macOSPkgApp"
                        case 2:
                            intuneAppType = "macOSLobApp"
                        default:
                            intuneAppType = "macOSLobApp"
                        }
                        
                        // Assign the groups to the app
                        try await EntraGraphRequests.assignGroupsToApp(authToken: authToken, appId: app.id, appAssignments: processedAppResults?.appAssignments ?? [], appType: intuneAppType, installAsManaged: false)

                        try await EntraGraphRequests.assignCategoriesToIntuneApp(
                            authToken: authToken,
                            appID: app.id,
                            categories: processedAppResults?.appCategories ?? []
                        )
                        
                    } catch {
                        Logger.log("Error updating \(processedAppResults?.appDisplayName ?? "unknown") with AppID \(app.id) assignment in Intune: \(error.localizedDescription)", logType: logType)
                    }
                }
            }
            
        } catch {
            Logger.log("Failed to fetch app info from Intune: \(error.localizedDescription)", logType: logType)
            return
        }
    }

}
