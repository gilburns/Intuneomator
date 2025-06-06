//
//  EntraGraphRequests+Groups.swift
//  Intuneomator
//
//  Created by Gil Burns on 5/22/25.
//

import Foundation

// MARK: - Groups Management Extension

/// Extension for handling Microsoft Graph API group operations
/// Provides functionality for fetching and managing Azure AD groups for application assignments
extension EntraGraphRequests {
    
    // MARK: - Security Groups Retrieval
    
    /// Fetches all security-enabled groups from Microsoft Graph with filtering and sorting
    /// Used to retrieve groups available for Intune application assignments
    /// - Parameter authToken: OAuth bearer token for Microsoft Graph authentication
    /// - Returns: Array of dictionaries containing security group information, sorted by display name
    /// - Throws: Network errors, authentication errors, or JSON parsing errors
    static func fetchEntraGroups(authToken: String) async throws -> [[String: Any]] {
        let url = URL(string: "https://graph.microsoft.com/v1.0/groups?$filter=securityEnabled eq true&$select=id,description,displayName,securityEnabled")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "AppDataManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch Entra groups"])
        }
        
        // Parse JSON response and sort groups alphabetically by display name
        if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
           let values = json["value"] as? [[String: Any]] {
            return values.sorted {
                guard let name1 = $0["displayName"] as? String, let name2 = $1["displayName"] as? String else { return false }
                return name1.localizedCaseInsensitiveCompare(name2) == .orderedAscending
            }
        }
        throw NSError(domain: "AppDataManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid response format for Entra groups"])
    }

    // MARK: - Group Lookup Operations
    
    /// Retrieves a group's unique identifier by its display name
    /// Used for resolving group names to IDs for application assignment operations
    /// - Parameters:
    ///   - authToken: OAuth bearer token for Microsoft Graph authentication
    ///   - displayName: The display name of the group to search for
    /// - Returns: The unique identifier (GUID) of the matching group
    /// - Throws: GraphAPIError for various failure scenarios (invalid URL, invalid response, resource not found)
    static func getGroupIdByDisplayName(authToken: String, displayName: String) async throws -> String {
        // URL encode the group name to handle special characters
        let encodedName = displayName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "https://graph.microsoft.com/beta/groups?$filter=displayName eq '\(encodedName)'"
        
        guard let url = URL(string: urlString) else {
            throw GraphAPIError.invalidURL
        }
        
        // Prepare the Graph API request
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        // Execute the API call
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // Validate HTTP response status
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw GraphAPIError.invalidResponse
        }
        
        // Local structures for parsing group search results
        struct GroupResponse: Codable {
            let value: [Group]
        }
        
        struct Group: Codable {
            let id: String
            let displayName: String
        }
        
        let groupResponse = try JSONDecoder().decode(GroupResponse.self, from: data)
        
        // Return the first matching group's ID or throw error if not found
        guard let group = groupResponse.value.first else {
            throw GraphAPIError.resourceNotFound("Group not found: \(displayName)")
        }
        
        return group.id
    }
}
