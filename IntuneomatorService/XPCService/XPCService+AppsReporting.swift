//
//  XPCService+AppsReporting.swift
//  Intuneomator
//
//  Created by Gil Burns on 7/11/25.
//

import Foundation

/// XPCService extension for Microsoft Intune App management operations
/// Handles secure communication with Microsoft Graph API endpoints for Intune App operations
/// All operations use authenticated tokens and provide comprehensive error handling through async callbacks
extension XPCService {
    // MARK: - Intune App Reporting Management
 
    /// Retrieves all apps from Microsoft Intune
    /// - Parameter reply: Callback with array of Intune app dictionaries or nil on failure
    func fetchIntuneApps(reply: @escaping ([[String : Any]]?) -> Void) {
        Task {
            do {
                let entraAuthenticator = EntraAuthenticator.shared
                let authToken = try await entraAuthenticator.getEntraIDToken()
                let webClips = try await EntraGraphRequests.fetchIntuneApps(authToken: authToken)
                reply(webClips)
            } catch {
                Logger.error("Failed to fetch Intune Apps: \(error.localizedDescription)", category: .core)
                reply(nil)
            }
        }
    }
    
    func getDeviceAppInstallationStatusReport(appId: String, reply: @escaping ([[String : Any]]?) -> Void) {
        Task {
            do {
                let entraAuthenticator = EntraAuthenticator.shared
                let authToken = try await entraAuthenticator.getEntraIDToken()
                let installationStatus = try await EntraGraphRequests.getDeviceAppInstallationStatusReport(authToken: authToken, appId: appId)
                reply(installationStatus)
            } catch {
                Logger.error("Failed to fetch Intune App installation status: \(error.localizedDescription)", category: .core)
                reply(nil)
            }
        }

    }
    
}
