//
//  EntraGraphRequests+Groups.swift
//  Intuneomator
//
//  Created by Gil Burns on 5/22/25.
//

import Foundation
import CommonCrypto

extension EntraGraphRequests {
    
    // MARK: - Fetch Security Enabled Entra Groups
    
    /// Fetches all security enabled groups from Microsoft Graph.
    static func fetchEntraGroups(authToken: String) async throws -> [[String: Any]] {
        let url = URL(string: "https://graph.microsoft.com/v1.0/groups?$filter=securityEnabled eq true&$select=id,description,displayName,securityEnabled")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "AppDataManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch Entra groups"])
        }
        
        if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
           let values = json["value"] as? [[String: Any]] {
            return values.sorted {
                guard let name1 = $0["displayName"] as? String, let name2 = $1["displayName"] as? String else { return false }
                return name1.localizedCaseInsensitiveCompare(name2) == .orderedAscending
            }
        }
        throw NSError(domain: "AppDataManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid response format for Entra groups"])
    }

    
    // MARK: - Find groups ID By Display Name
    
    // Helper function to get group ID from display name
    static func getGroupIdByDisplayName(authToken: String, displayName: String) async throws -> String {
        let encodedName = displayName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "https://graph.microsoft.com/beta/groups?$filter=displayName eq '\(encodedName)'"
        
        guard let url = URL(string: urlString) else {
            throw GraphAPIError.invalidURL
        }
        
        // Prepare the request
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        // Make the API call
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // Check for valid response
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw GraphAPIError.invalidResponse
        }
        
        // Process the response
        struct GroupResponse: Codable {
            let value: [Group]
        }
        
        struct Group: Codable {
            let id: String
            let displayName: String
        }
        
        let groupResponse = try JSONDecoder().decode(GroupResponse.self, from: data)
        
        // Return the first matching group's ID
        guard let group = groupResponse.value.first else {
            throw GraphAPIError.resourceNotFound("Group not found: \(displayName)")
        }
        
        return group.id
    }

}
