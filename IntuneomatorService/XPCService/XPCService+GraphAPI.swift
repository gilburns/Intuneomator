//
//  XPCService+GraphAPI.swift
//  Intuneomator
//
//  Created by Gil Burns on 5/4/25.
//

import Foundation

/// XPCService extension for Microsoft Graph API operations
/// Handles secure communication with Microsoft Graph API endpoints for Intune management
/// All operations use authenticated tokens and provide error handling through async callbacks
extension XPCService {
    
    // MARK: - Graph API Methods
    
    /// Retrieves available mobile app categories from Microsoft Intune
    /// Categories are used to organize and classify applications within the Intune console
    /// - Parameter reply: Callback with array of category dictionaries or nil on failure
    func fetchMobileAppCategories(reply: @escaping ([[String : Any]]?) -> Void) {
        Task {
            do {
                let entraAuthenticator = EntraAuthenticator()
                let authToken = try await entraAuthenticator.getEntraIDToken()
                let categories = try await EntraGraphRequests.fetchMobileAppCategories(authToken: authToken)
                reply(categories)
            } catch {
                Logger.log("Failed to fetch mobile app categories: \(error.localizedDescription)", logType: logType)
                reply(nil)
            }
        }
    }
    
    /// Fetches security-enabled groups from Microsoft Entra ID (Azure AD)
    /// Groups are used for application assignment targeting and access control
    /// - Parameter reply: Callback with array of group dictionaries or nil on failure
    func fetchEntraGroups(reply: @escaping ([[String : Any]]?) -> Void) {
        Task {
            do {
                let entraAuthenticator = EntraAuthenticator()
                let authToken = try await entraAuthenticator.getEntraIDToken()
                let categories = try await EntraGraphRequests.fetchEntraGroups(authToken: authToken)
                reply(categories)
            } catch {
                Logger.log("Failed to fetch security enabled groups: \(error.localizedDescription)", logType: logType)
                reply(nil)
            }
        }
    }
    
    /// Retrieves macOS-specific assignment filters from Microsoft Intune
    /// Filters enable conditional assignment based on device properties and attributes
    /// - Parameter reply: Callback with array of filter dictionaries or nil on failure
    func fetchAssignmentFiltersForMac(reply: @escaping ([[String: Any]]?) -> Void) {
        Task {
            do {
                let entraAuthenticator = EntraAuthenticator()
                let authToken = try await entraAuthenticator.getEntraIDToken()
                let filters = try await EntraGraphRequests.fetchMacAssignmentFiltersAsDictionaries(authToken: authToken)
                reply(filters)
            } catch {
                Logger.log("Failed to fetch assignment filters: \(error.localizedDescription)", logType: logType)
                reply(nil)
            }
        }
    }    
}

