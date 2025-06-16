//
//  LabelAutomation+UpdateIntune.swift
//  Intuneomator
//
//  Created by Gil Burns on 5/23/25.
//

import Foundation

// MARK: - Intune Application Update Extension

/// Extension for handling selective updates of automated applications in Microsoft Intune
/// Provides granular update functionality for metadata, scripts, and assignments without full re-upload
extension LabelAutomation {
  
    // MARK: - Metadata Update Operations
    
    /// Updates only the metadata for existing Intune applications matching an Installomator label
    /// Refreshes application information, descriptions, icons, categories, and system requirements
    /// - Parameter folderName: The Installomator label folder name to process for metadata updates
    static func processFolderMetadata(named folderName: String) async {
        // Variables to track label processing results
        var wrappedProcessedAppResults: ProcessedAppResults?
        var appInfo: [FilteredIntuneAppInfo]

        Logger.info("--------------------------------------------------------", category: .automation)
        Logger.info("🚀 Start metadata update of \(folderName)", category: .automation)

        // Step 1: Process Installomator label to extract current application metadata
        let folderResults = InstallomatorLabelProcessor.runProcessLabelScript(for: folderName)
        
        if !folderResults {
            Logger.error("  Failed to run Installomator script for \(folderName)", category: .automation)
            return
        }
                
        // Step 2: Extract processed application data for metadata updates
        wrappedProcessedAppResults = extractDataForProcessedAppResults(from: folderName)
        
        guard var processedAppResults = wrappedProcessedAppResults else {
            Logger.error("  Failed to extract ProcessedAppResults data for \(folderName)", category: .automation)
            return
        }
        
        Logger.info("  Extracted ProcessedAppResults data for \(processedAppResults.appDisplayName)", category: .automation)
        Logger.info("  Label: \(processedAppResults.appLabelName)", category: .automation)
        Logger.info("  Tracking ID: \(processedAppResults.appTrackingID)", category: .automation)
        Logger.info("  Version to check: \(processedAppResults.appVersionExpected)", category: .automation)
        
        let trackingID = processedAppResults.appTrackingID
        let appLabelName = processedAppResults.appLabelName
        let appDisplayName = processedAppResults.appDisplayName
        
        let operationId = "\(folderName)_metadata"
        let statusManager = StatusNotificationManager.shared
        
        // Start tracking metadata update operation
        statusManager.startOperation(
            operationId: operationId,
            labelName: appLabelName,
            appName: appDisplayName
        )
        
        // Step 3: Search Intune for applications with matching tracking ID
        Logger.info("  " + folderName + ": Fetching app info from Intune...", category: .automation)
        statusManager.updateProcessingStatus(operationId, "Fetching apps from Intune")
        
        do {
            let entraAuthenticator = EntraAuthenticator.shared
            let authToken = try await entraAuthenticator.getEntraIDToken()
            
            // Find all applications in Intune that match this tracking ID
            appInfo = try await EntraGraphRequests.findAppsByTrackingID(authToken: authToken, trackingID: trackingID)
            
            Logger.info("    Found \(appInfo.count) apps matching tracking ID \(trackingID)", category: .automation)
            
            if appInfo.isEmpty {
                statusManager.failOperation(operationId: operationId, errorMessage: "No applications found in Intune with tracking ID \(trackingID)")
                return
            }
            
            // Step 4: Update metadata for each matching application
            statusManager.updateProcessingStatus(operationId, "Updating metadata for \(appInfo.count) app(s)")
            for (index, app) in appInfo.enumerated() {
                Logger.info("    ---", category: .automation)
                Logger.info("    App: \(app.displayName)", category: .automation)
                Logger.info("    Ver: \(app.primaryBundleVersion)", category: .automation)
                Logger.info("     ID: \(app.id)", category: .automation)
                
                // Update progress
                let progress = Double(index + 1) / Double(appInfo.count)
                statusManager.updateProcessingStatus(operationId, "Updating \(app.displayName)", progress: progress)
                
                // Update application metadata and category assignments
                do {
                    let entraAuthenticator = EntraAuthenticator.shared
                    let authToken = try await entraAuthenticator.getEntraIDToken()
                    
                    // Update comprehensive application metadata (descriptions, icons, etc.)
                    try await EntraGraphRequests.updateAppIntuneMetadata(authToken: authToken, app: processedAppResults, appId: app.id)
                    
                    // Clear existing category assignments before reassigning
                    try await EntraGraphRequests.removeAllCategoriesFromIntuneApp(authToken: authToken, appID: app.id)
                    
                    // Apply updated category assignments for Company Portal organization
                    try await EntraGraphRequests.assignCategoriesToIntuneApp(
                        authToken: authToken,
                        appID: app.id,
                        categories: processedAppResults.appCategories
                    )
                    
                    Logger.info("✅ Successfully updated metadata for \(app.displayName)", category: .automation)
                    
                } catch {
                    Logger.error("Error updating \(processedAppResults.appDisplayName) with AppID \(app.id) metadata in Intune: \(error.localizedDescription)", category: .automation)
                    statusManager.failOperation(operationId: operationId, errorMessage: "Failed to update metadata for \(app.displayName): \(error.localizedDescription)")
                    return
                }
            }
            
            // Complete the operation successfully
            statusManager.completeOperation(operationId: operationId)
            Logger.info("✅ Metadata update completed successfully for \(folderName)", category: .automation)
            
        } catch {
            Logger.error("Failed to fetch app info from Intune: \(error.localizedDescription)", category: .automation)
            statusManager.failOperation(operationId: operationId, errorMessage: "Failed to fetch app info from Intune: \(error.localizedDescription)")
            return
        }
    }

    // MARK: - Scripts Update Operations
    
    /// Updates only the pre/post-install scripts for existing Intune PKG applications matching an Installomator label
    /// Refreshes script content for PKG applications without affecting other metadata or file content
    /// - Parameter folderName: The Installomator label folder name to process for script updates
    static func processFolderScripts(named folderName: String) async {
        // Variables to track label processing results  
        var wrappedProcessedAppResults: ProcessedAppResults?
        var appInfo: [FilteredIntuneAppInfo]

        Logger.info("--------------------------------------------------------", category: .automation)
        Logger.info("🚀 Start scripts update of \(folderName)", category: .automation)

        // Step 1: Process Installomator label to extract current script content
        let folderResults = InstallomatorLabelProcessor.runProcessLabelScript(for: folderName)
        
        if !folderResults {
            Logger.error("  Failed to run Installomator script for \(folderName)", category: .automation)
            return
        }
                
        // Step 2: Extract processed application data for script updates
        wrappedProcessedAppResults = extractDataForProcessedAppResults(from: folderName)
        
        guard var processedAppResults = wrappedProcessedAppResults else {
            Logger.error("  Failed to extract ProcessedAppResults data for \(folderName)", category: .automation)
            return
        }
        
        Logger.info("  Extracted ProcessedAppResults data for \(processedAppResults.appDisplayName)", category: .automation)
        Logger.info("  Label: \(String(describing: processedAppResults.appLabelName))", category: .automation)
        
        let trackingID = processedAppResults.appTrackingID
        let appLabelName = processedAppResults.appLabelName
        let appDisplayName = processedAppResults.appDisplayName
        Logger.info("  Tracking ID: \(trackingID)", category: .automation)
        
        let operationId = "\(folderName)_scripts"
        let statusManager = StatusNotificationManager.shared
        
        // Start tracking scripts update operation
        statusManager.startOperation(
            operationId: operationId,
            labelName: appLabelName,
            appName: appDisplayName
        )

        // Step 3: Search Intune for PKG applications with matching tracking ID
        Logger.info("  " + folderName + ": Fetching app info from Intune...", category: .automation)
        statusManager.updateProcessingStatus(operationId, "Fetching PKG apps from Intune")
        
        do {
            let entraAuthenticator = EntraAuthenticator.shared
            let authToken = try await entraAuthenticator.getEntraIDToken()
            
            // Find all applications in Intune that match this tracking ID
            appInfo = try await EntraGraphRequests.findAppsByTrackingID(authToken: authToken, trackingID: trackingID)
            
            Logger.info("    Found \(appInfo.count) apps matching tracking ID \(trackingID)", category: .automation)
            
            if appInfo.isEmpty {
                statusManager.failOperation(operationId: operationId, errorMessage: "No PKG applications found in Intune with tracking ID \(trackingID)")
                return
            }
            
            // Step 4: Update scripts for each matching PKG application
            statusManager.updateProcessingStatus(operationId, "Updating scripts for \(appInfo.count) PKG app(s)")
            for (index, app) in appInfo.enumerated() {
                Logger.info("    ---", category: .automation)
                Logger.info("    App: \(app.displayName)", category: .automation)
                Logger.info("    Ver: \(app.primaryBundleVersion)", category: .automation)
                Logger.info("     ID: \(app.id)", category: .automation)
                
                // Update progress
                let progress = Double(index + 1) / Double(appInfo.count)
                statusManager.updateProcessingStatus(operationId, "Updating scripts for \(app.displayName)", progress: progress)
                
                // Update pre/post-install scripts for PKG applications
                do {
                    let entraAuthenticator = EntraAuthenticator.shared
                    let authToken = try await entraAuthenticator.getEntraIDToken()
                    
                    // Update script content (Base64 encoded for secure transmission)
                    try await EntraGraphRequests.updateAppIntuneScripts(authToken: authToken, app: processedAppResults, appId: app.id)
                    
                    Logger.info("✅ Successfully updated scripts for \(app.displayName)", category: .automation)
                    
                } catch {
                    Logger.error("Error updating \(processedAppResults.appDisplayName) with AppID \(app.id) scripts in Intune: \(error.localizedDescription)", category: .automation)
                    statusManager.failOperation(operationId: operationId, errorMessage: "Failed to update scripts for \(app.displayName): \(error.localizedDescription)")
                    return
                }
            }
            
            // Complete the operation successfully
            statusManager.completeOperation(operationId: operationId)
            Logger.info("✅ Scripts update completed successfully for \(folderName)", category: .automation)
            
        } catch {
            Logger.error("Failed to fetch app info from Intune: \(error.localizedDescription)", category: .automation)
            statusManager.failOperation(operationId: operationId, errorMessage: "Failed to fetch app info from Intune: \(error.localizedDescription)")
            return
        }
    }

    
    // MARK: - Assignment Update Operations
    
    /// Updates only the group assignments for existing Intune applications matching an Installomator label
    /// Refreshes deployment targeting and category assignments without affecting application content or metadata
    /// - Parameter folderName: The Installomator label folder name to process for assignment updates
    static func processFolderAssignments(named folderName: String) async {
        // Variables to track label processing results
        var wrapedProcessedAppResults: ProcessedAppResults?
        var appInfo: [FilteredIntuneAppInfo]

        Logger.info("--------------------------------------------------------", category: .automation)
        Logger.info("🚀 Start assignment update of \(folderName)", category: .automation)

        // Step 1: Process Installomator label to extract current assignment configuration
        let folderResults = InstallomatorLabelProcessor.runProcessLabelScript(for: folderName)
        
        if !folderResults {
            Logger.error("  Failed to run Installomator script for \(folderName)", category: .automation)
            return
        }
                
        // Step 2: Extract processed application data for assignment updates
        wrapedProcessedAppResults = extractDataForProcessedAppResults(from: folderName)
        
        guard var processedAppResults = wrapedProcessedAppResults else {
            Logger.error("  Failed to extract ProcessedAppResults data for \(folderName)", category: .automation)
            return
        }
        
        Logger.info("  Extracted ProcessedAppResults data for \(processedAppResults.appDisplayName)", category: .automation)
        Logger.info("  Label: \(String(describing: processedAppResults.appLabelName))", category: .automation)
        
        let trackingID = processedAppResults.appTrackingID
        let appLabelName = processedAppResults.appLabelName
        let appDisplayName = processedAppResults.appDisplayName
        Logger.info("  Tracking ID: \(trackingID)", category: .automation)
        
        let operationId = "\(folderName)_assignments"
        let statusManager = StatusNotificationManager.shared
        
        // Start tracking assignments update operation
        statusManager.startOperation(
            operationId: operationId,
            labelName: appLabelName,
            appName: appDisplayName
        )

        // Step 3: Search Intune for applications with matching tracking ID
        Logger.info("  " + folderName + ": Fetching app info from Intune...", category: .automation)
        statusManager.updateProcessingStatus(operationId, "Fetching apps from Intune")
        
        do {
            let entraAuthenticator = EntraAuthenticator.shared
            let authToken = try await entraAuthenticator.getEntraIDToken()
            
            // Find all applications in Intune that match this tracking ID
            appInfo = try await EntraGraphRequests.findAppsByTrackingID(authToken: authToken, trackingID: trackingID)
            
            Logger.info("    Found \(appInfo.count) apps matching tracking ID \(trackingID)", category: .automation)
            
            if appInfo.isEmpty {
                statusManager.failOperation(operationId: operationId, errorMessage: "No applications found in Intune with tracking ID \(trackingID)")
                return
            }
            
            // Step 4: Update assignments for each matching application
            statusManager.updateProcessingStatus(operationId, "Updating assignments for \(appInfo.count) app(s)")
            for (index, app) in appInfo.enumerated() {
                Logger.info("    ---", category: .automation)
                Logger.info("    App: \(app.displayName)", category: .automation)
                Logger.info("    Ver: \(app.primaryBundleVersion)", category: .automation)
                Logger.info("     ID: \(app.id)", category: .automation)
                
                // Update progress
                let progress = Double(index + 1) / Double(appInfo.count)
                statusManager.updateProcessingStatus(operationId, "Updating assignments for \(app.displayName)", progress: progress)
                
                // Update group assignments only for applications that currently have assignments
                if app.isAssigned {
                    do {
                        // Clear all existing group assignments before reassigning
                        try await EntraGraphRequests.removeAllAppAssignments(authToken: authToken, appId: app.id)
                        
                        // Determine the appropriate Intune application type for assignment API
                        let intuneAppType: String
                        switch processedAppResults.appDeploymentType {
                            case 0:
                            intuneAppType = "macOSDmgApp"
                        case 1:
                            intuneAppType = "macOSPkgApp"
                        case 2:
                            intuneAppType = "macOSLobApp"
                        default:
                            intuneAppType = "macOSLobApp"
                        }
                        
                        // Apply updated group assignments for deployment targeting
                        try await EntraGraphRequests.assignGroupsToApp(
                            authToken: authToken, 
                            appId: app.id, 
                            appAssignments: processedAppResults.appAssignments, 
                            appType: intuneAppType, 
                            installAsManaged: false
                        )

                        // Apply updated category assignments for Company Portal organization
                        try await EntraGraphRequests.assignCategoriesToIntuneApp(
                            authToken: authToken,
                            appID: app.id,
                            categories: processedAppResults.appCategories
                        )
                        
                        Logger.info("✅ Successfully updated assignments for \(app.displayName)", category: .automation)
                        
                    } catch {
                        Logger.error("Error updating \(processedAppResults.appDisplayName) with AppID \(app.id) assignment in Intune: \(error.localizedDescription)", category: .automation)
                        statusManager.failOperation(operationId: operationId, errorMessage: "Failed to update assignments for \(app.displayName): \(error.localizedDescription)")
                        return
                    }
                } else {
                    Logger.info("⏭️ Skipping \(app.displayName) - not currently assigned", category: .automation)
                }
            }
            
            // Complete the operation successfully
            statusManager.completeOperation(operationId: operationId)
            Logger.info("✅ Assignment update completed successfully for \(folderName)", category: .automation)
            
        } catch {
            Logger.error("Failed to fetch app info from Intune: \(error.localizedDescription)", category: .automation)
            statusManager.failOperation(operationId: operationId, errorMessage: "Failed to fetch app info from Intune: \(error.localizedDescription)")
            return
        }
    }

}
