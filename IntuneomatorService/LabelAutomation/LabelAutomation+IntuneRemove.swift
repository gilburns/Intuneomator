//
//  LabelAutomation+RemoveIntune.swift
//  Intuneomator
//
//  Created by Gil Burns on 5/23/25.
//

import Foundation

// MARK: - Intune Application Removal Extension

/// Extension for handling removal of automated applications from Microsoft Intune
/// Provides functionality to clean up applications and their associated metadata from Intune tenant
extension LabelAutomation {
    
    // MARK: - Intune Application Removal Operations
    
    /// Removes all automated applications from Microsoft Intune for a specific Installomator label
    /// This function finds all applications with matching tracking IDs and removes them from Intune tenant
    /// - Parameter folderName: The Installomator label folder name to process for removal
    static func deleteAutomationsFromIntune(named folderName: String) async {
        // Variables to track label processing results
        var wrappedProcessedAppResults: ProcessedAppResults?
        var appInfo: [FilteredIntuneAppInfo]

        Logger.info("--------------------------------------------------------", category: .automation)
        Logger.info("🚀 Start removal of Intune automations for: \(folderName)", category: .automation)

        // Step 1: Process Installomator label to extract application metadata
        let folderResults = InstallomatorLabelProcessor.runProcessLabelScript(for: folderName)
        
        if !folderResults {
            Logger.error("  Failed to run Installomator script for \(folderName)", category: .automation)
            return
        }
                
        // Step 2: Extract processed application data for tracking ID lookup
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
        
        // Step 3: Search Intune for applications with matching tracking ID
        Logger.info("  " + folderName + ": Fetching app info from Intune...", category: .automation)
        
        do {
            let entraAuthenticator = EntraAuthenticator()
            let authToken = try await entraAuthenticator.getEntraIDToken()
            
            // Find all applications in Intune that match this tracking ID
            appInfo = try await EntraGraphRequests.findAppsByTrackingID(authToken: authToken, trackingID: trackingID)
            
            Logger.info("    Found \(appInfo.count) apps matching tracking ID \(trackingID)", category: .automation)
            
            // Step 4: Remove each matching application from Intune
            for app in appInfo {
                Logger.info("    ---", category: .automation)
                Logger.info("    App: \(app.displayName)", category: .automation)
                Logger.info("    Ver: \(app.primaryBundleVersion)", category: .automation)
                Logger.info("     ID: \(app.id)", category: .automation)
                
                // Remove individual application from Intune tenant
                do {
                    let entraAuthenticator = EntraAuthenticator()
                    let authToken = try await entraAuthenticator.getEntraIDToken()
                    
                    // Execute deletion via Microsoft Graph API
                    try await EntraGraphRequests.deleteIntuneApp(authToken: authToken, appId: app.id)
                    
                } catch {
                    Logger.error("Error removing \(processedAppResults.appDisplayName) item with AppID \(app.id) from Intune: \(error.localizedDescription)", category: .automation)
                }
            }
            
            // Step 5: Clean up local automation tracking files
            let labelFolderName = "\(processedAppResults.appLabelName)_\(processedAppResults.appTrackingID)"
            let labelFolderURL = AppConstants.intuneomatorManagedTitlesFolderURL.appendingPathComponent(labelFolderName)
            
            // Remove the .uploaded touch file to reset automation state
            if FileManager.default.fileExists(atPath: labelFolderURL.path) {
                let intuneUploadTouchFile = labelFolderURL.appendingPathComponent(".uploaded")
                
                if FileManager.default.fileExists(atPath: intuneUploadTouchFile.path) {
                    try FileManager.default.removeItem(at: intuneUploadTouchFile)
                    Logger.info("  Removed upload tracking file for \(labelFolderName)", category: .automation)
                }
            }
            
        } catch {
            Logger.error("Failed to fetch app info from Intune: \(error.localizedDescription)", category: .automation)
            return
        }
    }

}
