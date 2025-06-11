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

        Logger.log("--------------------------------------------------------", logType: logType)
        Logger.log("🚀 Start removal of Intune automations for: \(folderName)", logType: "Automation")

        // Step 1: Process Installomator label to extract application metadata
        let folderResults = InstallomatorLabelProcessor.runProcessLabelScript(for: folderName)
        
        if !folderResults {
            Logger.log("  Failed to run Installomator script for \(folderName)", logType: logType)
            return
        }
                
        // Step 2: Extract processed application data for tracking ID lookup
        wrappedProcessedAppResults = extractDataForProcessedAppResults(from: folderName)
        
        guard let processedAppResults = wrappedProcessedAppResults else {
            Logger.log("  Failed to extract ProcessedAppResults data for \(folderName)", logType: logType)
            return
        }
        
        Logger.log("  Extracted ProcessedAppResults data for \(processedAppResults.appDisplayName)", logType: logType)
        Logger.log("  Label: \(processedAppResults.appLabelName)", logType: logType)
        Logger.log("  Tracking ID: \(processedAppResults.appTrackingID)", logType: logType)
        Logger.log("  Version to check: \(processedAppResults.appVersionExpected)", logType: logType)
        
        let trackingID = processedAppResults.appTrackingID
        
        // Step 3: Search Intune for applications with matching tracking ID
        Logger.log("  " + folderName + ": Fetching app info from Intune...", logType: logType)
        
        do {
            let entraAuthenticator = EntraAuthenticator()
            let authToken = try await entraAuthenticator.getEntraIDToken()
            
            // Find all applications in Intune that match this tracking ID
            appInfo = try await EntraGraphRequests.findAppsByTrackingID(authToken: authToken, trackingID: trackingID)
            
            Logger.log("    Found \(appInfo.count) apps matching tracking ID \(trackingID)", logType: logType)
            
            // Step 4: Remove each matching application from Intune
            for app in appInfo {
                Logger.log("    ---", logType: logType)
                Logger.log("    App: \(app.displayName)", logType: logType)
                Logger.log("    Ver: \(app.primaryBundleVersion)", logType: logType)
                Logger.log("     ID: \(app.id)", logType: logType)
                
                // Remove individual application from Intune tenant
                do {
                    let entraAuthenticator = EntraAuthenticator()
                    let authToken = try await entraAuthenticator.getEntraIDToken()
                    
                    // Execute deletion via Microsoft Graph API
                    try await EntraGraphRequests.deleteIntuneApp(authToken: authToken, appId: app.id)
                    
                } catch {
                    Logger.log("Error removing \(processedAppResults.appDisplayName) item with AppID \(app.id) from Intune: \(error.localizedDescription)", logType: logType)
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
                    Logger.log("  Removed upload tracking file for \(labelFolderName)", logType: logType)
                }
            }
            
        } catch {
            Logger.log("Failed to fetch app info from Intune: \(error.localizedDescription)", logType: logType)
            return
        }
    }

}
