//
//  EntraGraphRequests+AppCategories.swift
//  Intuneomator
//
//  Created by Gil Burns on 6/30/25.
//

import Foundation

// MARK: - App Category Management Extension

/// Extension for handling Microsoft Graph API application category operations
/// Provides functionality for fetching and managing Intune App Categories
extension EntraGraphRequests {
    
    // MARK: - Fetch Mobile App Categories
    // https://learn.microsoft.com/en-us/graph/api/intune-apps-mobileappcategory-list?view=graph-rest-1.0&tabs=http
    
    /// Fetches all mobile app categories from Microsoft Graph API
    /// - Parameter authToken: Valid access token for Microsoft Graph API
    /// - Returns: Array of dictionaries containing category ID and display name, sorted alphabetically
    /// - Throws: NSError for API failures or invalid response format
    static func fetchMobileAppCategories(authToken: String) async throws -> [[String: Any]] {
        let url = URL(string: "https://graph.microsoft.com/v1.0/deviceAppManagement/mobileAppCategories?$select=id,displayName")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "AppDataManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch mobile app categories"])
        }
        
        if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
           let values = json["value"] as? [[String: Any]] {
            return values.sorted {
                guard let name1 = $0["displayName"] as? String, let name2 = $1["displayName"] as? String else { return false }
                return name1.localizedCaseInsensitiveCompare(name2) == .orderedAscending
            }
        }
        throw NSError(domain: "AppDataManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid response format for mobile app categories"])
    }
    
    /// Creates a new mobile app category in Microsoft Intune
    /// - Parameters:
    ///   - authToken: Valid OAuth 2.0 bearer token with DeviceManagementApps.ReadWrite.All permissions
    ///   - categoryData: Dictionary containing category information (displayName is required)
    /// - Returns: The unique identifier (GUID) of the created category
    /// - Throws: Network errors, authentication errors, or JSON parsing errors
    static func createMobileAppCategory(authToken: String, categoryData: [String: Any]) async throws -> String {
        let baseEndpoint = "https://graph.microsoft.com/v1.0/deviceAppManagement/mobileAppCategories"

        guard let url = URL(string: baseEndpoint) else {
            throw NSError(domain: "AppCategoryCreator", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let jsonData = try JSONSerialization.data(withJSONObject: categoryData, options: [])
        request.httpBody = jsonData
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            let responseStr = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "AppCategoryCreator", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to create app category. Response: \(responseStr)"])
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
              let categoryId = json["id"] as? String else {
            throw NSError(domain: "AppCategoryCreator", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to extract category ID from response"])
        }
        
        return categoryId
    }
    
    /// Updates an existing mobile app category in Microsoft Intune
    /// - Parameters:
    ///   - authToken: Valid OAuth 2.0 bearer token with DeviceManagementApps.ReadWrite.All permissions
    ///   - categoryId: Unique identifier (GUID) of the category to update
    ///   - updatedData: Dictionary containing updated category information
    /// - Returns: Boolean indicating successful update
    /// - Throws: Network errors, authentication errors, or HTTP request failures
    static func updateMobileAppCategory(authToken: String, categoryId: String, updatedData: [String: Any]) async throws -> Bool {
        let updateURL = "https://graph.microsoft.com/v1.0/deviceAppManagement/mobileAppCategories/\(categoryId)"
        
        guard let url = URL(string: updateURL) else {
            throw NSError(domain: "AppCategoryUpdater", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let jsonData = try JSONSerialization.data(withJSONObject: updatedData, options: [])
        request.httpBody = jsonData
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            let responseStr = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "AppCategoryUpdater", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to update app category. Response: \(responseStr)"])
        }
        
        return true
    }
    
    /// Deletes a mobile app category from Microsoft Intune
    /// - Parameters:
    ///   - authToken: Valid OAuth 2.0 bearer token with DeviceManagementApps.ReadWrite.All permissions
    ///   - categoryId: Unique identifier (GUID) of the category to delete
    /// - Returns: Boolean indicating successful deletion
    /// - Throws: Network errors, authentication errors, or HTTP request failures
    static func deleteMobileAppCategory(authToken: String, categoryId: String) async throws -> Bool {
        let deleteURL = "https://graph.microsoft.com/v1.0/deviceAppManagement/mobileAppCategories/\(categoryId)"
        
        guard let url = URL(string: deleteURL) else {
            throw NSError(domain: "AppCategoryDeleter", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            let responseStr = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "AppCategoryDeleter", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to delete app category. Response: \(responseStr)"])
        }
        
        return true
    }
}
