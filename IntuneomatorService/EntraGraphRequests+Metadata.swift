//
//  EntraGraphRequests+Metadata.swift
//  Intuneomator
//
//  Created by Gil Burns on 5/22/25.
//

import Foundation
import CommonCrypto

extension EntraGraphRequests {

    // MARK: - Assign Categories to App
    static func assignCategoriesToIntuneApp(authToken: String, appID: String, categories: [Category]) async throws {
        Logger.log("Assigning categories to Intune app \(appID)", logType: "AssignCategoriesToIntuneApp")
        Logger.log("Categories: \(categories)", logType: "AssignCategoriesToIntuneApp")
        
        // Try using the beta endpoint since that worked in Graph Explorer
        guard let baseUrl = URL(string: "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/\(appID)/categories/$ref") else {
            throw NSError(domain: "IntuneAPIError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL formation"])
        }
        
        for category in categories {
            // Exactly match the format you used in Graph Explorer
            let body = [
                "@odata.id": "https://graph.microsoft.com/beta/deviceAppManagement/mobileAppCategories/\(category.id)"
            ]
            Logger.log("Request Body for category \(category.displayName): \(body)", logType: "AssignCategoriesToIntuneApp")
            
            guard let jsonData = try? JSONSerialization.data(withJSONObject: body, options: []) else {
                throw NSError(domain: "IntuneAPIError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to serialize request body"])
            }
            
            var request = URLRequest(url: baseUrl)
            request.httpMethod = "POST"
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = jsonData
            
            // Add ConsistencyLevel header which is sometimes required for Graph API reference operations
            request.setValue("eventual", forHTTPHeaderField: "ConsistencyLevel")
            
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NSError(domain: "IntuneAPIError", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
                }
                
                if httpResponse.statusCode != 204 && httpResponse.statusCode != 200 {
                    let errorInfo = String(data: data, encoding: .utf8) ?? "No error details available"
                    Logger.log("Error assigning category \(category.displayName): Status \(httpResponse.statusCode), Response: \(errorInfo)", logType: "AssignCategoriesToIntuneApp")
                    
                    // If we hit rate limiting or a temporary issue, add a delay before continuing
                    if httpResponse.statusCode == 429 || httpResponse.statusCode >= 500 {
                        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 second delay
                        // You could retry here instead of throwing
                    }
                    
                    throw NSError(domain: "IntuneAPIError", code: httpResponse.statusCode,
                                  userInfo: [NSLocalizedDescriptionKey: "Failed to assign category \(category.displayName) to app \(appID). Status code: \(httpResponse.statusCode). Error: \(errorInfo)"])
                }
                
                Logger.log("Successfully assigned category \(category.displayName) to app \(appID)", logType: "AssignCategoriesToIntuneApp")
                
                // Add a small delay between requests to avoid overwhelming the API
                try await Task.sleep(nanoseconds: 500_000_000) // 500ms delay
            } catch {
                Logger.log("Exception while assigning category \(category.displayName): \(error)", logType: "AssignCategoriesToIntuneApp")
                throw error
            }
        }
        
        Logger.log("Completed assigning all categories to app \(appID)", logType: "AssignCategoriesToIntuneApp")
    }
    
    // MARK: - Remove All Category Assignments
    static func removeAllCategoriesFromIntuneApp(authToken: String, appID: String) async throws {
        Logger.log("Removing all category assignments from Intune app \(appID)", logType: "RemoveCategoriesFromIntuneApp")
        
        // First, get the current category assignments
        guard let categoriesUrl = URL(string: "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/\(appID)/categories") else {
            throw NSError(domain: "IntuneAPIError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL formation"])
        }
        
        var getRequest = URLRequest(url: categoriesUrl)
        getRequest.httpMethod = "GET"
        getRequest.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        getRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Get current category assignments
        let (data, response) = try await URLSession.shared.data(for: getRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "IntuneAPIError", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        
        if httpResponse.statusCode != 200 {
            let errorInfo = String(data: data, encoding: .utf8) ?? "No error details available"
            throw NSError(domain: "IntuneAPIError", code: httpResponse.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: "Failed to get current categories for app \(appID). Status code: \(httpResponse.statusCode). Error: \(errorInfo)"])
        }
        
        // Parse the response to get current categories
        guard let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let value = jsonObject["value"] as? [[String: Any]] else {
            throw NSError(domain: "IntuneAPIError", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to parse categories response"])
        }
        
        // If no categories are assigned, we're done
        if value.isEmpty {
            Logger.log("No categories assigned to app \(appID)", logType: "RemoveCategoriesFromIntuneApp")
            return
        }
        
        // Log found categories
        Logger.log("Found \(value.count) categories assigned to app \(appID)", logType: "RemoveCategoriesFromIntuneApp")
        
        // Remove each category
        for categoryInfo in value {
            guard let categoryId = categoryInfo["id"] as? String else {
                Logger.log("Could not extract category ID from: \(categoryInfo)", logType: "RemoveCategoriesFromIntuneApp")
                continue
            }
            
            // URL for deletion
            guard let deleteUrl = URL(string: "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/\(appID)/categories/\(categoryId)/$ref") else {
                Logger.log("Invalid URL formation for category \(categoryId)", logType: "RemoveCategoriesFromIntuneApp")
                continue
            }
            
            var deleteRequest = URLRequest(url: deleteUrl)
            deleteRequest.httpMethod = "DELETE"
            deleteRequest.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
            deleteRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            deleteRequest.setValue("eventual", forHTTPHeaderField: "ConsistencyLevel")
            
            do {
                let (deleteData, deleteResponse) = try await URLSession.shared.data(for: deleteRequest)
                
                guard let deleteHttpResponse = deleteResponse as? HTTPURLResponse else {
                    throw NSError(domain: "IntuneAPIError", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
                }
                
                if deleteHttpResponse.statusCode != 204 && deleteHttpResponse.statusCode != 200 {
                    let errorInfo = String(data: deleteData, encoding: .utf8) ?? "No error details available"
                    Logger.log("Error removing category \(categoryId): Status \(deleteHttpResponse.statusCode), Response: \(errorInfo)", logType: "RemoveCategoriesFromIntuneApp")
                    
                    // If we hit rate limiting or a temporary issue, add a delay before continuing
                    if deleteHttpResponse.statusCode == 429 || deleteHttpResponse.statusCode >= 500 {
                        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 second delay
                    }
                    
                    throw NSError(domain: "IntuneAPIError", code: deleteHttpResponse.statusCode,
                                  userInfo: [NSLocalizedDescriptionKey: "Failed to remove category \(categoryId) from app \(appID). Status code: \(deleteHttpResponse.statusCode). Error: \(errorInfo)"])
                }
                
                Logger.log("Successfully removed category \(categoryId) from app \(appID)", logType: "RemoveCategoriesFromIntuneApp")
                
                // Add a small delay between requests to avoid overwhelming the API
                try await Task.sleep(nanoseconds: 500_000_000) // 500ms delay
            } catch {
                Logger.log("Exception while removing category \(categoryId): \(error)", logType: "RemoveCategoriesFromIntuneApp")
                throw error
            }
        }
        
        Logger.log("Successfully removed all categories from app \(appID)", logType: "RemoveCategoriesFromIntuneApp")
    }
    
    
    // Usage:
    /*
     
     do {
     try await removeAllCategoriesFromIntuneApp(authToken: yourAuthToken, appID: yourAppID)
     } catch {
     print("Error removing categories: \(error.localizedDescription)")
     }
     
     */

    // MARK: - Intune Update App Metadata Function
    static func updateAppIntuneMetadata(authToken: String, app: ProcessedAppResults!, appId: String) async throws {
        
        // GET Intune info for displayName and data.type
        let getURL = URL(string: "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/\(appId)?$select=displayName")!
        var getReq = URLRequest(url: getURL)
        getReq.httpMethod = "GET"
        getReq.addValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")

        let (getData, _) = try await URLSession.shared.data(for: getReq)
        let currentName = (try JSONSerialization.jsonObject(with: getData) as? [String:Any])?["displayName"] as? String
          ?? app.appDisplayName
        let currentDataType = (try JSONSerialization.jsonObject(with: getData, options: []) as? [String:Any])?["@odata.type"] as? String ?? "#microsoft.graph.macOSLobApp"

        // Update metadata for an existing Intune app
        let updateURL = URL(string: "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/\(appId)")!
        var request = URLRequest(url: updateURL)
        request.httpMethod = "PATCH"
        request.addValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        // Build the notes field
        let fullNotes: String
        if app.appNotes.isEmpty {
            fullNotes = "Intuneomator ID: \(app.appTrackingID)"
        } else {
            fullNotes = "\(app.appNotes)\n\nIntuneomator ID: \(app.appTrackingID)"
        }
        
        // Construct the payload with only the metadata fields to update
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

        // Include largeIcon only if the file exists
        if FileManager.default.fileExists(atPath: app.appIconURL),
           let iconData = try? Data(contentsOf: URL(fileURLWithPath: app.appIconURL)) {
            metadataPayload["largeIcon"] = [
                "@odata.type": "#microsoft.graph.mimeContent",
                "type": "image/png",
                "value": iconData.base64EncodedString()
            ]
        }
        
        // Attach the JSON body
        request.httpBody = try JSONSerialization.data(withJSONObject: metadataPayload, options: [])

        // Send the PATCH request
        let (_, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
            throw GraphAPIError.apiError("Failed to update metadata. Status code: \(httpResponse.statusCode)")
        }
        
        Logger.log("Successfully updated metadata for app ID \(appId)", logType: "EntraGraphRequests")
        Logger.log("Successfully updated \(app.appDisplayName) metadata for app ID \(appId)", logType: "Automation")
    }

}
