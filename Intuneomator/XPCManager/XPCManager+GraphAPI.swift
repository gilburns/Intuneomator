//
//  XPCManager+GraphAPI.swift
//  Intuneomator
//
//  Created by Gil Burns on 5/4/25.
//

import Foundation

/// XPCManager extension for Microsoft Graph API data retrieval
/// Provides GUI access to Microsoft Intune and Entra ID resources through the privileged service
/// All operations require valid authentication credentials and appropriate permissions
extension XPCManager {
    
    // MARK: - Microsoft Graph API Operations

    /// Fetches security-enabled groups from Microsoft Entra ID (Azure AD)
    /// Groups are used for application assignment targeting and access control policies
    /// - Parameter completion: Callback with array of group dictionaries or nil on failure
    func fetchEntraGroups(completion: @escaping ([[String: Any]]?) -> Void) {
        sendRequest({ $0.fetchEntraGroups(reply: $1) }, completion: completion)
    }
    
    /// Searches for security-enabled groups by name using startswith filtering
    /// More efficient than loading all groups for large environments with 1000+ groups
    /// - Parameters:
    ///   - searchQuery: Text to search for in group display names
    ///   - maxResults: Maximum number of results to return
    ///   - completion: Callback with array of matching group dictionaries or nil on failure
    func searchEntraGroups(searchQuery: String, maxResults: Int = 50, completion: @escaping ([[String: Any]]?) -> Void) {
        sendRequest({ $0.searchEntraGroups(searchQuery: searchQuery, maxResults: maxResults, reply: $1) }, completion: completion)
    }
    
    /// Searches for security-enabled groups by name using contains filtering for broader matching
    /// Alternative search method when startswith doesn't return enough results
    /// - Parameters:
    ///   - searchQuery: Text to search for anywhere in group display names
    ///   - maxResults: Maximum number of results to return
    ///   - completion: Callback with array of matching group dictionaries or nil on failure
    func searchEntraGroupsContains(searchQuery: String, maxResults: Int = 50, completion: @escaping ([[String: Any]]?) -> Void) {
        sendRequest({ $0.searchEntraGroupsContains(searchQuery: searchQuery, maxResults: maxResults, reply: $1) }, completion: completion)
    }
    
    /// Retrieves macOS-specific assignment filters from Microsoft Intune
    /// Filters enable conditional assignment based on device properties and attributes
    /// - Parameter completion: Callback with array of filter dictionaries or nil on failure
    func fetchAssignmentFiltersForMac(completion: @escaping ([[String: Any]]?) -> Void) {
        sendRequest({ $0.fetchAssignmentFiltersForMac(reply: $1) }, completion: completion)
    }
    
    
    /// Retrieves discovered macOS applications from Microsoft Intune device inventory
    /// Provides insight into applications detected across managed devices for analysis
    /// - Parameter completion: Callback with array of DetectedApp objects or nil on failure
    func fetchDiscoveredMacApps(completion: @escaping ([DetectedApp]?) -> Void) {
        sendRequest({ service, reply in
            service.fetchDiscoveredMacApps(reply: reply)
        }) { (data: Data?) in
            guard let data = data else {
                completion(nil)
                return
            }
            do {
                let apps = try JSONDecoder().decode([DetectedApp].self, from: data)
                completion(apps)
            } catch {
                Logger.error("Failed to decode DetectedApp array: \(error)", category: .core)
                completion(nil)
            }
        }
    }
    
    
    /// Fetches device information for a specific discovered application
    /// Retrieves details about devices where the specified application is installed
    /// - Parameters:
    ///   - appID: Application identifier to search for
    ///   - completion: Callback with array of DeviceInfo objects or nil on failure
    func fetchDevices(forAppID appID: String, completion: @escaping ([DeviceInfo]?) -> Void) {
        sendRequest({ service, reply in
            service.fetchDevices(forAppID: appID, reply: reply)
        }) { (data: Data?) in
            guard let data = data else {
                completion(nil)
                return
            }
            do {
                let devices = try JSONDecoder().decode([DeviceInfo].self, from: data)
                completion(devices)
            } catch {
                Logger.error("Failed to decode devices: \(error)", category: .core, toUserDirectory: true)
                completion(nil)
            }
        }
    }

}

