//
//  EntraGraphRequests+Metadata.swift
//  Intuneomator
//
//  Created by Gil Burns on 5/22/25.
//

import Foundation

// MARK: - Metadata Management Extension

/// Extension for handling Microsoft Graph API metadata operations
/// Provides functionality for managing application categories and updating app metadata in Intune
extension EntraGraphRequests {
    
    // MARK: - Category Assignment Operations
    
    /// Assigns categories to an Intune application using Microsoft Graph API
    /// Used to organize applications in the Company Portal for easier discovery
    /// - Parameters:
    ///   - authToken: OAuth bearer token for Microsoft Graph authentication
    ///   - appID: Unique identifier of the Intune application
    ///   - categories: Array of Category objects to assign to the application
    /// - Throws: Network errors, authentication errors, or API errors
    static func assignCategoriesToIntuneApp(authToken: String, appID: String, categories: [Category]) async throws {
        Logger.log("Assigning categories to Intune app \(appID)", logType: logType)
        Logger.log("Categories: \(categories)", logType: logType)
        
        // Use beta endpoint for category assignment operations
        guard let baseUrl = URL(string: "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/\(appID)/categories/$ref") else {
            throw NSError(domain: "IntuneAPIError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL formation"])
        }
        
        // Assign each category individually with proper OData reference format
        for category in categories {
            let body = [
                "@odata.id": "https://graph.microsoft.com/beta/deviceAppManagement/mobileAppCategories/\(category.id)"
            ]
            Logger.log("Request Body for category \(category.displayName): \(body)", logType: logType)
            
            guard let jsonData = try? JSONSerialization.data(withJSONObject: body, options: []) else {
                throw NSError(domain: "IntuneAPIError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to serialize request body"])
            }
            
            var request = URLRequest(url: baseUrl)
            request.httpMethod = "POST"
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = jsonData
            
            // ConsistencyLevel header required for Graph API reference operations
            request.setValue("eventual", forHTTPHeaderField: "ConsistencyLevel")
            
            let maxRetries = 3
            var attempt = 0
            var success = false
            
            while attempt < maxRetries && !success {
                attempt += 1
                do {
                    let (data, response) = try await URLSession.shared.data(for: request)
                    
                    guard let httpResponse = response as? HTTPURLResponse else {
                        throw NSError(domain: "IntuneAPIError", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
                    }
                    
                    if httpResponse.statusCode == 204 || httpResponse.statusCode == 200 {
                        Logger.log("Successfully assigned category \(category.displayName) to app \(appID)", logType: logType)
                        success = true
                    } else {
                        let errorInfo = String(data: data, encoding: .utf8) ?? "No error details available"
                        Logger.log("Error assigning category \(category.displayName): Status \(httpResponse.statusCode), Response: \(errorInfo)", logType: logType)
                        
                        if httpResponse.statusCode == 429 || httpResponse.statusCode >= 500 {
                            Logger.log("Retrying after delay due to rate limit/server error (attempt \(attempt))", logType: logType)
                            try await Task.sleep(nanoseconds: 2_000_000_000)
                            continue
                        }
                        
                        throw NSError(domain: "IntuneAPIError", code: httpResponse.statusCode,
                                      userInfo: [NSLocalizedDescriptionKey: "Failed to assign category \(category.displayName) to app \(appID). Status code: \(httpResponse.statusCode). Error: \(errorInfo)"])
                    }
                } catch {
                    Logger.log("Exception while assigning category \(category.displayName) (attempt \(attempt)): \(error)", logType: logType)
                    if attempt == maxRetries {
                        throw error
                    } else {
                        try await Task.sleep(nanoseconds: 2_000_000_000)
                    }
                }
            }
            
            try await Task.sleep(nanoseconds: 500_000_000) // Rate limiting between categories        }
            
            Logger.log("Completed assigning all categories to app \(appID)", logType: logType)
        }
    }
    
    /// Removes all category assignments from an Intune application
    /// Used to clear existing categories before reassigning or when removing categorization
    /// - Parameters:
    ///   - authToken: OAuth bearer token for Microsoft Graph authentication
    ///   - appID: Unique identifier of the Intune application
    /// - Throws: Network errors, authentication errors, or API errors
    static func removeAllCategoriesFromIntuneApp(authToken: String, appID: String) async throws {
        Logger.log("Removing all category assignments from Intune app \(appID)", logType: logType)
        
        // First, retrieve current category assignments
        guard let categoriesUrl = URL(string: "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/\(appID)/categories") else {
            throw NSError(domain: "IntuneAPIError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL formation"])
        }
        
        var getRequest = URLRequest(url: categoriesUrl)
        getRequest.httpMethod = "GET"
        getRequest.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        getRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Fetch current category assignments
        let (data, response) = try await URLSession.shared.data(for: getRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "IntuneAPIError", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        
        if httpResponse.statusCode != 200 {
            let errorInfo = String(data: data, encoding: .utf8) ?? "No error details available"
            throw NSError(domain: "IntuneAPIError", code: httpResponse.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: "Failed to get current categories for app \(appID). Status code: \(httpResponse.statusCode). Error: \(errorInfo)"])
        }
        
        // Parse the response to extract current categories
        guard let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let value = jsonObject["value"] as? [[String: Any]] else {
            throw NSError(domain: "IntuneAPIError", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to parse categories response"])
        }
        
        // Early return if no categories are assigned
        if value.isEmpty {
            Logger.log("No categories assigned to app \(appID)", logType: logType)
            return
        }
        
        Logger.log("Found \(value.count) categories assigned to app \(appID)", logType: logType)
        
        // Remove each category assignment individually
        for categoryInfo in value {
            guard let categoryId = categoryInfo["id"] as? String else {
                Logger.log("Could not extract category ID from: \(categoryInfo)", logType: logType)
                continue
            }
            
            // Build deletion URL for category reference
            guard let deleteUrl = URL(string: "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/\(appID)/categories/\(categoryId)/$ref") else {
                Logger.log("Invalid URL formation for category \(categoryId)", logType: logType)
                continue
            }
            
            var deleteRequest = URLRequest(url: deleteUrl)
            deleteRequest.httpMethod = "DELETE"
            deleteRequest.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
            deleteRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            deleteRequest.setValue("eventual", forHTTPHeaderField: "ConsistencyLevel")
            
            let maxRetries = 3
            var attempt = 0
            var success = false
            
            while attempt < maxRetries && !success {
                attempt += 1
                do {
                    let (deleteData, deleteResponse) = try await URLSession.shared.data(for: deleteRequest)
                    
                    guard let deleteHttpResponse = deleteResponse as? HTTPURLResponse else {
                        throw NSError(domain: "IntuneAPIError", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
                    }
                    
                    if deleteHttpResponse.statusCode == 204 || deleteHttpResponse.statusCode == 200 {
                        Logger.log("Successfully removed category \(categoryId) from app \(appID)", logType: logType)
                        success = true
                    } else {
                        let errorInfo = String(data: deleteData, encoding: .utf8) ?? "No error details available"
                        Logger.log("Error removing category \(categoryId): Status \(deleteHttpResponse.statusCode), Response: \(errorInfo)", logType: logType)
                        
                        if deleteHttpResponse.statusCode == 429 || deleteHttpResponse.statusCode >= 500 {
                            Logger.log("Retrying after delay due to rate limit/server error (attempt \(attempt))", logType: logType)
                            try await Task.sleep(nanoseconds: 2_000_000_000)
                            continue
                        }
                        
                        throw NSError(domain: "IntuneAPIError", code: deleteHttpResponse.statusCode,
                                      userInfo: [NSLocalizedDescriptionKey: "Failed to remove category \(categoryId) from app \(appID). Status code: \(deleteHttpResponse.statusCode). Error: \(errorInfo)"])
                    }
                } catch {
                    Logger.log("Exception while removing category \(categoryId) (attempt \(attempt)): \(error)", logType: logType)
                    if attempt == maxRetries {
                        throw error
                    } else {
                        try await Task.sleep(nanoseconds: 2_000_000_000)
                    }
                }
            }
            
            try await Task.sleep(nanoseconds: 500_000_000) // 500ms delay between category removals
        }
        
        Logger.log("Successfully removed all categories from app \(appID)", logType: logType)
    }
    
    // MARK: - Application Metadata Updates
    
    /// Updates comprehensive metadata for an existing Intune application
    /// Used to refresh application information, descriptions, icons, and system requirements
    /// - Parameters:
    ///   - authToken: OAuth bearer token for Microsoft Graph authentication
    ///   - app: ProcessedAppResults containing all application metadata
    ///   - appId: Unique identifier of the Intune application to update
    /// - Throws: Network errors, authentication errors, or JSON serialization errors
    static func updateAppIntuneMetadata(authToken: String, app: ProcessedAppResults!, appId: String) async throws {
        
        // Retrieve current application information to preserve display name and data type
        let getURL = URL(string: "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/\(appId)?$select=displayName")!
        var getReq = URLRequest(url: getURL)
        getReq.httpMethod = "GET"
        getReq.addValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        
        let (getData, _) = try await URLSession.shared.data(for: getReq)
        let currentName = (try JSONSerialization.jsonObject(with: getData) as? [String:Any])?["displayName"] as? String
        ?? app.appDisplayName
        let currentDataType = (try JSONSerialization.jsonObject(with: getData, options: []) as? [String:Any])?["@odata.type"] as? String ?? "#microsoft.graph.macOSLobApp"
        
        // Prepare PATCH request for metadata update
        let updateURL = URL(string: "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/\(appId)")!
        var request = URLRequest(url: updateURL)
        request.httpMethod = "PATCH"
        request.addValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Build comprehensive notes field with Intuneomator tracking ID
        let fullNotes: String
        if app.appNotes.isEmpty {
            fullNotes = "Intuneomator ID: \(app.appTrackingID)"
        } else {
            fullNotes = "\(app.appNotes)\n\nIntuneomator ID: \(app.appTrackingID)"
        }
        
        // Construct comprehensive metadata payload
        var metadataPayload: [String: Any] = [
            "@odata.type": currentDataType,
            "displayName": currentName,
            "description": app.appDescription,
            "developer": app.appDeveloper,
            "publisher": app.appPublisherName,
            "owner": app.appOwner,
            "notes": fullNotes,
            "privacyInformationUrl": app.appPrivacyPolicyURL,
            "informationUrl": app.appInfoURL,
            "ignoreVersionDetection": app.appIgnoreVersion,
            "isFeatured": app.appIsFeatured,
            "minimumSupportedOperatingSystem": [
                "@odata.type": "#microsoft.graph.macOSMinimumOperatingSystem",
                "v10_13": app.appMinimumOS.contains("v10_13"),
                "v10_14": app.appMinimumOS.contains("v10_14"),
                "v10_15": app.appMinimumOS.contains("v10_15"),
                "v11_0": app.appMinimumOS.contains("v11_0"),
                "v12_0": app.appMinimumOS.contains("v12_0"),
                "v13_0": app.appMinimumOS.contains("v13_0"),
                "v14_0": app.appMinimumOS.contains("v14_0"),
                "v15_0": app.appMinimumOS.contains("v15_0")
            ]
        ]
        
        // Include application icon if available
        if FileManager.default.fileExists(atPath: app.appIconURL),
           let iconData = try? Data(contentsOf: URL(fileURLWithPath: app.appIconURL)) {
            metadataPayload["largeIcon"] = [
                "@odata.type": "#microsoft.graph.mimeContent",
                "type": "image/png",
                "value": iconData.base64EncodedString()
            ]
        }
        
        // Serialize and attach the JSON payload
        request.httpBody = try JSONSerialization.data(withJSONObject: metadataPayload, options: [])
        
        // Execute the PATCH request
        let (_, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
            throw GraphAPIError.apiError("Failed to update metadata. Status code: \(httpResponse.statusCode)")
        }
        
        Logger.log("Successfully updated metadata for app ID \(appId)", logType: logType)
        Logger.log("Successfully updated \(app.appDisplayName) metadata for app ID \(appId)", logType: "Automation")
    }
}
