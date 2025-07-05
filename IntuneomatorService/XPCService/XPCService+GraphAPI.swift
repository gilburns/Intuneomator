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
        
    /// Fetches security-enabled groups from Microsoft Entra ID (Azure AD)
    /// Groups are used for application assignment targeting and access control
    /// - Parameter reply: Callback with array of group dictionaries or nil on failure
    func fetchEntraGroups(reply: @escaping ([[String : Any]]?) -> Void) {
        Task {
            do {
                let entraAuthenticator = EntraAuthenticator.shared
                let authToken = try await entraAuthenticator.getEntraIDToken()
                let categories = try await EntraGraphRequests.fetchEntraGroups(authToken: authToken)
                reply(categories)
            } catch {
                Logger.error("Failed to fetch security enabled groups: \(error.localizedDescription)", category: .core)
                reply(nil)
            }
        }
    }
    
    /// Searches for security-enabled groups by name using startswith filtering
    /// More efficient than loading all groups for large environments with 1000+ groups
    /// - Parameters:
    ///   - searchQuery: Text to search for in group display names
    ///   - maxResults: Maximum number of results to return
    ///   - reply: Callback with array of matching group dictionaries or nil on failure
    func searchEntraGroups(searchQuery: String, maxResults: Int, reply: @escaping ([[String : Any]]?) -> Void) {
        Task {
            do {
                let entraAuthenticator = EntraAuthenticator.shared
                let authToken = try await entraAuthenticator.getEntraIDToken()
                let groups = try await EntraGraphRequests.searchEntraGroups(authToken: authToken, searchQuery: searchQuery, maxResults: maxResults)
                reply(groups)
            } catch {
                Logger.error("Failed to search Entra groups (startswith): \(error.localizedDescription)", category: .core)
                reply(nil)
            }
        }
    }
    
    /// Searches for security-enabled groups by name using contains filtering for broader matching
    /// Alternative search method when startswith doesn't return enough results
    /// - Parameters:
    ///   - searchQuery: Text to search for anywhere in group display names
    ///   - maxResults: Maximum number of results to return
    ///   - reply: Callback with array of matching group dictionaries or nil on failure
    func searchEntraGroupsContains(searchQuery: String, maxResults: Int, reply: @escaping ([[String : Any]]?) -> Void) {
        Task {
            do {
                let entraAuthenticator = EntraAuthenticator.shared
                let authToken = try await entraAuthenticator.getEntraIDToken()
                let groups = try await EntraGraphRequests.searchEntraGroupsContains(authToken: authToken, searchQuery: searchQuery, maxResults: maxResults)
                reply(groups)
            } catch {
                Logger.error("Failed to search Entra groups (contains): \(error.localizedDescription)", category: .core)
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
                let entraAuthenticator = EntraAuthenticator.shared
                let authToken = try await entraAuthenticator.getEntraIDToken()
                let filters = try await EntraGraphRequests.fetchMacAssignmentFiltersAsDictionaries(authToken: authToken)
                reply(filters)
            } catch {
                Logger.error("Failed to fetch assignment filters: \(error.localizedDescription)", category: .core)
                reply(nil)
            }
        }
    }    
}

