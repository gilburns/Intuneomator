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
    
    /// Fetches all security-enabled groups from Microsoft Graph with pagination support
    /// Used to retrieve groups available for Intune application assignments
    /// Handles pagination to ensure all groups are fetched from large environments (1000+ groups)
    /// - Parameter authToken: OAuth bearer token for Microsoft Graph authentication
    /// - Returns: Array of dictionaries containing security group information, sorted by display name
    /// - Throws: Network errors, authentication errors, or JSON parsing errors
    static func fetchEntraGroups(authToken: String) async throws -> [[String: Any]] {
        var allGroups: [[String: Any]] = []
        var nextPageUrl: String? = "https://graph.microsoft.com/v1.0/groups?$filter=securityEnabled eq true&$select=id,description,displayName,securityEnabled"
        var pageCount = 0
        
        Logger.info("Starting paginated fetch of Entra groups...", category: .core)
        
        // Follow pagination until all groups are fetched
        while let urlString = nextPageUrl {
            guard let url = URL(string: urlString) else {
                throw NSError(domain: "AppDataManager", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid pagination URL: \(urlString)"])
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw NSError(domain: "AppDataManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch Entra groups (page \(pageCount + 1))"])
            }
            
            // Parse JSON response
            guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
                throw NSError(domain: "AppDataManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON response format for Entra groups (page \(pageCount + 1))"])
            }
            
            // Extract groups from this page
            guard let pageGroups = json["value"] as? [[String: Any]] else {
                throw NSError(domain: "AppDataManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid response format for Entra groups (page \(pageCount + 1))"])
            }
            
            allGroups.append(contentsOf: pageGroups)
            pageCount += 1
            
            // Check for next page
            nextPageUrl = json["@odata.nextLink"] as? String
            
            Logger.info("Fetched page \(pageCount) with \(pageGroups.count) groups (total: \(allGroups.count))", category: .core)
            
            // Safety check to prevent infinite loops
            if pageCount > 100 {
                Logger.error("Safety limit reached: stopping after 100 pages of groups", category: .core)
                break
            }
        }
        
        Logger.info("Completed fetching \(allGroups.count) total groups across \(pageCount) pages", category: .core)
        
        // Sort all groups alphabetically by display name
        return allGroups.sorted {
            guard let name1 = $0["displayName"] as? String, let name2 = $1["displayName"] as? String else { return false }
            return name1.localizedCaseInsensitiveCompare(name2) == .orderedAscending
        }
    }

    // MARK: - Alternative: Just-in-Time Group Search (Recommended for Large Environments)
    
    /// Searches for security-enabled groups by name with real-time filtering
    /// More efficient than loading all groups for large environments (1000+ groups)
    /// - Parameters:
    ///   - authToken: OAuth bearer token for Microsoft Graph authentication
    ///   - searchQuery: Text to search for in group display names (case-insensitive)
    ///   - maxResults: Maximum number of results to return (default: 50)
    /// - Returns: Array of matching groups, sorted by display name
    /// - Throws: Network errors, authentication errors, or JSON parsing errors
    static func searchEntraGroups(authToken: String, searchQuery: String, maxResults: Int = 50) async throws -> [[String: Any]] {
        // URL encode the search query
        let encodedQuery = searchQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        // Use startswith for better performance than contains
        let filterQuery = "securityEnabled eq true and startswith(displayName,'\(encodedQuery)')"
        let encodedFilter = filterQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        let urlString = "https://graph.microsoft.com/v1.0/groups?$filter=\(encodedFilter)&$select=id,description,displayName,securityEnabled&$top=\(maxResults)&$orderby=displayName"
        
        guard let url = URL(string: urlString) else {
            throw NSError(domain: "AppDataManager", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid search URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "AppDataManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to search Entra groups"])
        }
        
        // Parse JSON response
        if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
           let values = json["value"] as? [[String: Any]] {
            Logger.info("Group search for '\(searchQuery)' returned \(values.count) results", category: .core)
            return values
        }
        
        throw NSError(domain: "AppDataManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid response format for group search"])
    }
    
    /// Searches for security-enabled groups with "contains" logic for broader matching
    /// Alternative search method when startswith doesn't return enough results
    /// - Parameters:
    ///   - authToken: OAuth bearer token for Microsoft Graph authentication
    ///   - searchQuery: Text to search for anywhere in group display names
    ///   - maxResults: Maximum number of results to return (default: 50)
    /// - Returns: Array of matching groups, sorted by display name
    /// - Throws: Network errors, authentication errors, or JSON parsing errors
    static func searchEntraGroupsContains(authToken: String, searchQuery: String, maxResults: Int = 50) async throws -> [[String: Any]] {
        let encodedQuery = searchQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        // Use contains for broader matching (less performant but more comprehensive)
        let filterQuery = "securityEnabled eq true and contains(displayName,'\(encodedQuery)')"
        let encodedFilter = filterQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        let urlString = "https://graph.microsoft.com/v1.0/groups?$filter=\(encodedFilter)&$select=id,description,displayName,securityEnabled&$top=\(maxResults)&$orderby=displayName"
        
        guard let url = URL(string: urlString) else {
            throw NSError(domain: "AppDataManager", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid search URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "AppDataManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to search Entra groups"])
        }
        
        if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
           let values = json["value"] as? [[String: Any]] {
            Logger.info("Group search (contains) for '\(searchQuery)' returned \(values.count) results", category: .core)
            return values
        }
        
        throw NSError(domain: "AppDataManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid response format for group search"])
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
