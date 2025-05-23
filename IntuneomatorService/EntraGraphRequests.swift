//
//  EntraGraphRequests.swift
//  Intuneomator
//
//  Created by Gil Burns on 3/24/25.
//

import Foundation
import CommonCrypto

class EntraGraphRequests {
    
    enum GraphAPIError: Error {
        case invalidURL
        case requestFailed(Error)
        case invalidResponse
        case decodingError(Error)
        case encodingError
        case apiError(String)
        case resourceNotFound(String)
    }
    
    
    // MARK: - Detected Applications
    // https://learn.microsoft.com/en-us/graph/api/intune-devices-detectedapp-list?view=graph-rest-1.0&tabs=http
    
    
    /// Fetches all detected apps from Microsoft Graph, handling pagination.
    static func fetchAllDetectedApps(authToken: String) async throws -> [DetectedApp] {
        
        let graphEndpoint = "https://graph.microsoft.com/beta/deviceManagement/detectedApps"

        var allApps: [DetectedApp] = []
        var nextLink: String? = graphEndpoint


        while let url = nextLink {
            guard let requestURL = URL(string: url) else {
                throw NSError(domain: "Invalid URL", code: 0, userInfo: nil)
            }

            var request = URLRequest(url: requestURL)
            request.httpMethod = "GET"
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Accept")

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw NSError(domain: "No HTTP response", code: 0, userInfo: nil)
            }

            print("ℹ️ HTTP Status Code: \(httpResponse.statusCode)")

            if httpResponse.statusCode == 403 {
                Logger.log("Missing permissions. Please grant permissions in Enterprise App settings.")
                throw NSError(domain: "Graph API Forbidden", code: 403, userInfo: nil)
            }

            if httpResponse.statusCode != 200 {
                if let responseBody = String(data: data, encoding: .utf8) {
                    print("❌ Response Body: \(responseBody)")
                }
                throw NSError(domain: "Invalid server response", code: httpResponse.statusCode, userInfo: nil)
            }

            do {
                let decodedResponse = try JSONDecoder().decode(GraphResponseDetectedApp.self, from: data)
                allApps.append(contentsOf: decodedResponse.value)
                nextLink = decodedResponse.nextLink
            } catch {
                print("❌ JSON Decoding Error: \(error)")
                throw error
            }
        }

        print(allApps.count)
        return allApps
    }

    
    /// Fetches and filters detected apps to return only macOS applications.
    static func fetchMacOSDetectedApps(authToken: String) async throws -> [DetectedApp] {
        let allApps = try await fetchAllDetectedApps(authToken: authToken)
        
//        print("🔍 Checking platforms in detected apps:")
//        for app in allApps {
//            print(" - \(app.displayName ?? "Unknown App"): \(app.platform ?? "Unknown Platform")")
//        }

        let macApps = allApps.filter { ($0.platform?.lowercased() ?? "") == "macos" }
        
        print("✅ Found \(macApps.count) macOS apps")
        return macApps
    }

    
    // Function to fetch devices for a given detected app ID
    static func fetchDevices(authToken: String, forAppID appID: String) async throws -> [(deviceName: String, id: String, emailAddress: String)] {
        
        let graphEndpoint = "https://graph.microsoft.com/beta/deviceManagement/detectedApps"

        let urlString = "\(graphEndpoint)/\(appID)/managedDevices?$select=deviceName,id,emailAddress"
        guard let url = URL(string: urlString) else { throw NSError(domain: "Invalid URL", code: 400, userInfo: nil) }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "Invalid server response", code: (response as? HTTPURLResponse)?.statusCode ?? 500, userInfo: nil)
        }

        // Parse JSON response
        struct APIResponse: Decodable {
            let value: [Device]
        }

        struct Device: Decodable {
            let deviceName: String?
            let id: String?
            let emailAddress: String?
        }

        let decodedResponse = try JSONDecoder().decode(APIResponse.self, from: data)

        return decodedResponse.value.map { ($0.deviceName ?? "Unknown Device", $0.id ?? "Missing ID", $0.emailAddress ?? "No Email") }
    }


    // MARK: - Fetch Mobile App Categories
    // https://learn.microsoft.com/en-us/graph/api/intune-apps-mobileappcategory-list?view=graph-rest-1.0&tabs=http
    
    /// Fetches all mobile apps categories from Microsoft Graph.
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
    
    
    // MARK: - Fetch device filters from Graph
    //https://learn.microsoft.com/en-us/graph/api/intune-policyset-deviceandappmanagementassignmentfilter-list?view=graph-rest-beta
    
    /// Fetches all assignment filters from Microsoft Graph.
    static func fetchMacAssignmentFiltersAsDictionaries(authToken: String) async throws -> [[String: Any]] {
        let urlString = "https://graph.microsoft.com/beta/deviceManagement/assignmentFilters?$filter=platform eq 'macOS'&$select=id,displayName,description"
        guard let url = URL(string: urlString) else {
            throw NSError(domain: "InvalidURL", code: -1)
        }
        
        Logger.log("URL: \(urlString)", logType: "EntraGraphRequests")

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, _) = try await URLSession.shared.data(for: request)
        let decoded = try JSONDecoder().decode(GraphResponse.self, from: data)

        Logger.log("Decoded: \(decoded)", logType: "EntraGraphRequests")
        
        return decoded.value.map {
            [
                "id": $0.id,
                "displayName": $0.displayName,
                "description": $0.description ?? ""
            ]
        }
    }

    private struct GraphResponse: Decodable {
        let value: [AssignmentFilter]
    }

    private struct AssignmentFilter: Decodable {
        let id: String
        let displayName: String
        let description: String?
    }
    
    
    // Usage:
    /*
     EntraGraphRequests.fetchMacAssignmentFilters(authToken: "YOUR_ACCESS_TOKEN") { result in
         switch result {
         case .success(let filters):
             for filter in filters {
                 print("ID: \(filter.id), Name: \(filter.displayName), Description: \(filter.description ?? "None")")
             }
         case .failure(let error):
             print("Error fetching filters: \(error)")
         }
     }
     */
    
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
    
    // MARK: - Find Apps By Tracking ID
    static func findAppsByTrackingID(authToken: String, trackingID: String) async throws -> [FilteredIntuneAppInfo] {
        // Format the URL with proper encoding for the filter parameter
        let baseURL = "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps"
        let filterQuery = "(isof('microsoft.graph.macOSDmgApp') or isof('microsoft.graph.macOSPkgApp') or isof('microsoft.graph.macOSLobApp')) and endswith(notes,'\(trackingID)')"
        let encodedFilter = filterQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "\(baseURL)?$filter=\(encodedFilter)"
        
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
        
        // Process and filter the response
        do {
            // Define a structure to match the Microsoft Graph response format
            struct GraphResponse: Codable {
                let value: [AppItem]
            }
            
            // This structure matches the full app item format from Microsoft Graph
            struct AppItem: Codable {
                let id: String
                let displayName: String
                let isAssigned: Bool
                var primaryBundleId: String?
                var primaryBundleVersion: String?
                let bundleId: String?
                let buildNumber: String?
                
                enum CodingKeys: String, CodingKey {
                    case id, displayName, isAssigned, primaryBundleId, primaryBundleVersion, bundleId, buildNumber
                }
                
                init(from decoder: Decoder) throws {
                    let container = try decoder.container(keyedBy: CodingKeys.self)
                    
                    id = try container.decode(String.self, forKey: .id)
                    displayName = try container.decode(String.self, forKey: .displayName)
                    isAssigned = try container.decode(Bool.self, forKey: .isAssigned)
                    
                    // Handle optional fields
                    primaryBundleId = try container.decodeIfPresent(String.self, forKey: .primaryBundleId)
                    primaryBundleVersion = try container.decodeIfPresent(String.self, forKey: .primaryBundleVersion)
                    bundleId = try container.decodeIfPresent(String.self, forKey: .bundleId)
                    buildNumber = try container.decodeIfPresent(String.self, forKey: .buildNumber)
                }
            }
            
            // Decode the response
            let graphResponse = try JSONDecoder().decode(GraphResponse.self, from: data)
            
            // Map the response to our filtered format
            let filteredApps = graphResponse.value.map { app in
                // Use LOB app fields if primary fields are not available
                let effectiveBundleId = app.primaryBundleId ?? app.bundleId ?? ""
                let effectiveVersion = app.primaryBundleVersion ?? app.buildNumber ?? ""
                
                return FilteredIntuneAppInfo(
                    id: app.id,
                    displayName: app.displayName,
                    isAssigned: app.isAssigned,
                    primaryBundleId: effectiveBundleId,
                    primaryBundleVersion: effectiveVersion
                )
            }
            
            return filteredApps
        } catch {
            throw GraphAPIError.decodingError(error)
        }
    }
    
    // Example usage:
    /*
     Task {
     do {
     let authToken = "your_auth_token_here"
     let trackingID = "C0A9E195-F623-44DC-BB4C-99EFB538E09E"
     
     let apps = try await findAppsByTrackingID(authToken: authToken, trackingID: trackingID)
     
     for app in apps {
     print("App: \(app.displayName)")
     print("ID: \(app.id)")
     print("Bundle ID: \(app.primaryBundleId)")
     print("Version: \(app.primaryBundleVersion)")
     print("Assigned: \(app.isAssigned)")
     print("---")
     }
     } catch {
     print("Error: \(error)")
     }
     }
     */
    
    
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
    
    
    // MARK: - Assign Groups to App
    static func assignGroupsToApp(authToken: String, appId: String, appAssignments: [[String: Any]], appType: String, installAsManaged: Bool) async throws {
        
        Logger.log("assignGroupsToApp", logType: "EntraGraphRequests")
        Logger.log("appId: \(appId)", logType: "EntraGraphRequests")
        Logger.log("assignments: \(appAssignments)", logType: "EntraGraphRequests")
        Logger.log("appType: \(appType)", logType: "EntraGraphRequests")
        
        
        // Format the URL for the assignment endpoint
        let baseURL = "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/\(appId)/microsoft.graph.assign"
        
        guard let url = URL(string: baseURL) else {
            throw GraphAPIError.invalidURL
        }
        
        Logger.log("URL: \(url)", logType: "EntraGraphRequests")
        
        // Build the assignments payload
        var assignments: [[String: Any]] = []
        
        for assignment in appAssignments {
            Logger.log ("Processing Assignment: \(assignment)", logType: "EntraGraphRequests")
            
            guard let assignmentType = assignment["assignmentType"] as? String,
                  let mode = assignment["mode"] as? String else {
                continue
            }
            
            let isVirtual = assignment["isVirtual"] as? Int == 1
            
            // Create the assignment object with correct settings type for macOS
            var assignmentObject: [String: Any] = [
                "@odata.type": "#microsoft.graph.mobileAppAssignment",
                "intent": assignmentType.lowercased()
            ]

            if appType == "macOSLobApp" {
                if installAsManaged {
                    assignmentObject["settings"] = [
                        "@odata.type": "#microsoft.graph.macOsLobAppAssignmentSettings",
                        "uninstallOnDeviceRemoval": true
                    ]
                } else {
                    assignmentObject["settings"] = [
                        "@odata.type": "#microsoft.graph.macOsLobAppAssignmentSettings"
                    ]
                }
            }
            
            // Handle virtual groups (All Users or All Devices)
            if isVirtual {
                if let displayName = assignment["displayName"] as? String {
                    var targetObject: [String: Any] = [:]
                    
                    if displayName == "All Users" {
                        targetObject["@odata.type"] = "#microsoft.graph.allLicensedUsersAssignmentTarget"
                    } else if displayName == "All Devices" {
                        targetObject["@odata.type"] = "#microsoft.graph.allDevicesAssignmentTarget"
                    }
                    
                    // Add filter if available
                    if appTypeSupportsAssignmentFilters(appType) {
                        applyFilterIfAvailable(to: &targetObject, from: assignment, appType: appType)
                    }
                    
                    assignmentObject["target"] = targetObject
                }
            } else {
                if let groupId = assignment["id"] as? String {
                    var targetObject: [String: Any] = [
                        "@odata.type": (mode.lowercased() == "include")
                            ? "#microsoft.graph.groupAssignmentTarget"
                            : "#microsoft.graph.exclusionGroupAssignmentTarget",
                        "groupId": groupId
                    ]
                    
                    // Add filter if available
                    if appTypeSupportsAssignmentFilters(appType) {
                        applyFilterIfAvailable(to: &targetObject, from: assignment, appType: appType)
                    }
                    
                    assignmentObject["target"] = targetObject
                }
            }
            assignments.append(assignmentObject)
        }
        
        Logger.log("Assignments: \(assignments)", logType: "EntraGraphRequests")
        
        // Prepare the request payload
        let requestPayload: [String: Any] = ["mobileAppAssignments": assignments]
        
        // Convert payload to JSON Data
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestPayload) else {
            throw GraphAPIError.encodingError
        }
//        Logger.log("jsonData: \(jsonData)", logType: "EntraGraphRequests")
        
        // Add more detailed logging
//        Logger.log("Final request payload: \(String(data: jsonData, encoding: .utf8) ?? "Could not decode payload")", logType: "EntraGraphRequests")
        
        // Prepare the request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        // Make the API call
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // Check for valid response
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            // If there's an error, try to extract more details
            if let errorString = String(data: data, encoding: .utf8) {
                Logger.log("Error String: \(errorString)", logType: "EntraGraphRequests")

                throw GraphAPIError.apiError("API Error: \(errorString)")
            }
            throw GraphAPIError.invalidResponse
        }
//        Logger.log("Http Response: \(httpResponse)", logType: "EntraGraphRequests")
    }
    
    
    private static func appTypeSupportsAssignmentFilters(_ appType: String) -> Bool {
        return assignmentFilterSupportedAppTypes.contains(appType)
    }
    
    private static let assignmentFilterSupportedAppTypes: Set<String> = [
        "macOSLobApp" // Currently supported
        // If Microsoft adds support later:
        // "macOSPkgApp",
        // "macOSDmgApp"
    ]
    
    private static func applyFilterIfAvailable(to target: inout [String: Any], from assignment: [String: Any], appType: String) {
        if let filter = assignment["filter"] as? [String: Any],
           let filterId = filter["id"] as? String,
           let filterMode = filter["mode"] as? String {
            
            if appTypeSupportsAssignmentFilters(appType) {
                target["deviceAndAppManagementAssignmentFilterId"] = filterId
                target["deviceAndAppManagementAssignmentFilterType"] = filterMode.lowercased()
                Logger.log("🔎 Filter applied: ID=\(filterId), Type=\(filterMode.lowercased()) to \(target))", logType: "AssignGroupsToApp")
            } else {
                Logger.log("⚠️ Filter was provided for unsupported appType: \(appType). Ignoring.", logType: "AssignGroupsToApp")
            }
        } else {
            Logger.log("ℹ️ No filter applied for this assignment target", logType: "AssignGroupsToApp")
        }
    }
    
    
    // MARK: - Intune Remove All Groups assignments from an app
    static func removeAllAppAssignments(authToken: String, appId: String) async throws {
        // 1. Get current assignments
        let assignmentsURL = "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/\(appId)/assignments"
        
        var request = URLRequest(url: URL(string: assignmentsURL)!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw GraphAPIError.invalidResponse
        }
        
        // Process the assignments data
        struct AssignmentsResponse: Codable {
            let value: [Assignment]
        }
        
        struct Assignment: Codable {
            let id: String
        }
        
        let assignmentsResponse = try JSONDecoder().decode(AssignmentsResponse.self, from: data)
        
        // 2. Delete each assignment
        for assignment in assignmentsResponse.value {
            let deleteURL = "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/\(appId)/assignments/\(assignment.id)"
            
            var deleteRequest = URLRequest(url: URL(string: deleteURL)!)
            deleteRequest.httpMethod = "DELETE"
            deleteRequest.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
            
            let (_, deleteResponse) = try await URLSession.shared.data(for: deleteRequest)
            
            guard let deleteHttpResponse = deleteResponse as? HTTPURLResponse,
                  (200...299).contains(deleteHttpResponse.statusCode) else {
                throw GraphAPIError.invalidResponse
            }
            
            Logger.log("Removed assignment: \(assignment.id)", logType: "EntraGraphRequests")
        }
        
        Logger.log("All assignments removed for app: \(appId)", logType: "EntraGraphRequests")
    }
    
    
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

    // MARK: - Intune Update App Scripts
    static func updateAppIntuneScripts(authToken: String, app: ProcessedAppResults!, appId: String) async throws {
        
        // GET Intune info for displayName and data.type
        let getURL = URL(string: "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/\(appId)?$select=displayName")!
        var getReq = URLRequest(url: getURL)
        getReq.httpMethod = "GET"
        getReq.addValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")

        let (getData, _) = try await URLSession.shared.data(for: getReq)
        let currentName = (try JSONSerialization.jsonObject(with: getData) as? [String:Any])?["displayName"] as? String
          ?? app.appDisplayName
        let currentDataType = (try JSONSerialization.jsonObject(with: getData, options: []) as? [String:Any])?["@odata.type"] as? String ?? "#microsoft.graph.macOSLobApp"

        if currentDataType != "#microsoft.graph.macOSPkgApp" {
            throw NSError(domain: "UnsupportedDeploymentType", code: 1, userInfo: [NSLocalizedDescriptionKey: "Scripts can only be updated for PKG apps."])
        }
                
        // Update scripts for an existing Intune app
        let updateURL = URL(string: "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/\(appId)")!
        var request = URLRequest(url: updateURL)
        request.httpMethod = "PATCH"
        request.addValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        // Construct the payload with only the metadata fields to update
        var payload: [String: Any] = [
            "@odata.type": currentDataType,
            "displayName": currentName
        ]

        // Add pre-install script if present
        let preInstall = app.appScriptPreInstall
        if !preInstall.isEmpty {
            payload["preInstallScript"] = [
                "@odata.type": "#microsoft.graph.macOSAppScript",
                "scriptContent": Data(preInstall.utf8).base64EncodedString()
            ]
        } else {
            payload["preInstallScript"] = [
                "@odata.type": "#microsoft.graph.macOSAppScript",
                "scriptContent": ""
            ]
        }
        
        // Add post-install script if present
        let postInstall = app.appScriptPostInstall
        if !postInstall.isEmpty {
            payload["postInstallScript"] = [
                "@odata.type": "#microsoft.graph.macOSAppScript",
                "scriptContent": Data(postInstall.utf8).base64EncodedString()
            ]
        } else {
            payload["postInstallScript"] = [
                "@odata.type": "#microsoft.graph.macOSAppScript",
                "scriptContent": ""
            ]
        }
        
        // Attach the JSON body
        request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])

        // Send the PATCH request
        let (_, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
            throw GraphAPIError.apiError("Failed to update scripts. Status code: \(httpResponse.statusCode)")
        }
        
        Logger.log("Successfully updated scripts for app ID \(appId)", logType: "EntraGraphRequests")
        Logger.log("Successfully updated \(app.appDisplayName) scripts for app ID \(appId)", logType: "Automation")
    }

    // MARK: - Intune Delete App Function
    static func deleteIntuneApp(authToken: String, appId: String) async throws {
        // First, get and remove all assignments
        try await removeAllAppAssignments(authToken: authToken, appId: appId)
        
        // Format the URL for the delete endpoint
        let deleteURL = "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/\(appId)"
        
        guard let url = URL(string: deleteURL) else {
            throw GraphAPIError.invalidURL
        }
        
        // Prepare the request
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        
        // Make the API call
        let (_, response) = try await URLSession.shared.data(for: request)
        
        // Check for valid response
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw GraphAPIError.invalidResponse
        }
        
        Logger.log("App deleted successfully: \(appId)", logType: "EntraGraphRequests")
    }
    
    // MARK: - Intune Upload Functions
    static func uploadAppToIntune(authToken: String, app: ProcessedAppResults) async throws {
        
        Logger.log("🖥️  Uploading app to Intune...", logType: "EntraGraphRequests")
        
        if app.appDeploymentType == 2 {
            Logger.log("Deplying LOB app...", logType: "EntraGraphRequests")
            try await uploadLOBPkg(authToken: authToken, app: app)
        } else if app.appDeploymentType == 1 {
            Logger.log("Deplying PKG app...", logType: "EntraGraphRequests")
            try await uploadPKGWithScripts(authToken: authToken, app: app)
        } else if app.appDeploymentType == 0 {
            Logger.log("Deplying DMG app...", logType: "EntraGraphRequests")
            try await uploadDMGApp(authToken: authToken, app: app)
        } else {
            throw NSError(domain: "UnsupportedFileType", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unsupported file type for upload."])
        }
    }
    
    
    // MARK: - LOB
    // https://learn.microsoft.com/en-us/graph/api/intune-apps-macoslobapp-create?view=graph-rest-beta
    
    static func uploadLOBPkg(authToken: String, app: ProcessedAppResults) async throws {
        
        // Create the metadata payload
        let metadataURL = URL(string: "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps")!
        var request = URLRequest(url: metadataURL)
        request.httpMethod = "POST"
        request.addValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Build the notes field
        let fullNotes: String
        if app.appNotes.isEmpty {
            fullNotes = "Intuneomator ID: \(app.appTrackingID)"
        } else {
            fullNotes = "\(app.appNotes)\n\nIntuneomator ID: \(app.appTrackingID)"
        }

        // Determine architecture suffix for displayName
        let fileName = URL(fileURLWithPath: app.appLocalURL).lastPathComponent
        let arch = ["arm64", "x86_64"].first { fileName.contains($0) }
        let displayName = "\(app.appDisplayName) \(app.appVersionActual)\(arch.map { " \($0)" } ?? "")"
        
        var metadata: [String: Any] = [
            "@odata.type": "#microsoft.graph.macOSLobApp",
            "displayName": displayName,
            "description": app.appDescription,
            "developer": app.appDeveloper,
            "publisher": app.appPublisherName,
            "owner": app.appOwner,
            "notes": fullNotes,
            "fileName": "\(URL(fileURLWithPath: app.appLocalURL).lastPathComponent)",
            "privacyInformationUrl": app.appPrivacyPolicyURL,
            "informationUrl": app.appInfoURL,
            "primaryBundleId": app.appBundleIdActual,
            "primaryBundleVersion": app.appVersionActual,
            "ignoreVersionDetection": app.appIgnoreVersion,
            "installAsManaged": app.appIsManaged,
            "isFeatured": app.appIsFeatured,
            "bundleId": app.appBundleIdActual,
            "buildNumber": app.appVersionActual,
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
            ],
            "childApps": [[
                "@odata.type": "#microsoft.graph.macOSLobChildApp",
                "bundleId": app.appBundleIdActual,
                "buildNumber": app.appVersionActual,
                "versionNumber": "0.0"
            ]]
        ]
        
        // Add icon if valid
        if FileManager.default.fileExists(atPath: app.appIconURL),
           let iconData = try? Data(contentsOf: URL(fileURLWithPath: app.appIconURL)) {
            let base64Icon = iconData.base64EncodedString()
            metadata["largeIcon"] = [
                "@odata.type": "#microsoft.graph.mimeContent",
                "type": "image/png",
                "value": base64Icon
            ]
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: metadata, options: [])
        
        let (metadataData, metadataResponse) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = metadataResponse as? HTTPURLResponse {
            Logger.log("Metadata response status code: \(httpResponse.statusCode)", logType: "EntraGraphRequests")
            if !(200...299).contains(httpResponse.statusCode) {
                let responseBody = String(data: metadataData, encoding: .utf8) ?? "<non-UTF8 data>"
                Logger.log("Error response body: \(responseBody)", logType: "EntraGraphRequests")
                throw NSError(domain: "UploadLOBPkg", code: httpResponse.statusCode, userInfo: [
                    NSLocalizedDescriptionKey: "Failed to create app metadata. Status: \(httpResponse.statusCode)"
                ])
            }
        }
        
        guard
            let metadataJson = try JSONSerialization.jsonObject(with: metadataData) as? [String: Any]
        else {
            throw NSError(domain: "UploadLOBPkg", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON returned from metadata request."])
        }
        
        guard let appId = metadataJson["id"] as? String else {
            throw NSError(domain: "UploadLOBPkg", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Failed to parse app ID from response: \(metadataJson)"
            ])
        }
        
        Logger.log("Uploaded \(displayName) metadata. App ID: \(appId)", logType: "EntraGraphRequests")
        Logger.log("Uploaded \(displayName) metadata. App ID: \(appId)", logType: "Automation")

        // Start upload session
        do {
            // Create content version
            let contentURL = URL(string: "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/\(appId)/microsoft.graph.macOSLobApp/contentVersions")!
            var versionRequest = URLRequest(url: contentURL)
            versionRequest.httpMethod = "POST"
            versionRequest.addValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
            versionRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
            versionRequest.httpBody = "{}".data(using: .utf8)
            
            let (versionData, versionResponse) = try await URLSession.shared.data(for: versionRequest)
            if let httpResponse = versionResponse as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                let responseBody = String(data: versionData, encoding: .utf8) ?? "<non-UTF8 data>"
                Logger.log("Failed to create content version. Status: \(httpResponse.statusCode), Response: \(responseBody)", logType: "EntraGraphRequests")
                throw NSError(domain: "UploadLOBPkg", code: httpResponse.statusCode, userInfo: [
                    NSLocalizedDescriptionKey: "Failed to create content version. Status: \(httpResponse.statusCode)",
                    "responseBody": responseBody
                ])
            }
            
            let versionJson = try JSONSerialization.jsonObject(with: versionData) as? [String: Any]
//            Logger.log("Version JSON: \(versionJson as Any)", logType: "EntraGraphRequests")
            guard let versionId = versionJson?["id"] as? String else {
                throw NSError(domain: "UploadLOBPkg", code: 10, userInfo: [NSLocalizedDescriptionKey: "Failed to get version ID"])
            }
            
            
            // Encrypt the file before registration
            let (encryptedData, encryptionInfo, plaintextSize) = try encryptApp(fileURL: URL(fileURLWithPath: app.appLocalURL))
            
            // Save the encrypted data to a temporary file
            let tempDir = FileManager.default.temporaryDirectory
            let encryptedFileURL = tempDir.appendingPathComponent(UUID().uuidString + ".bin")
            try encryptedData.write(to: encryptedFileURL)
            
            
            // Register file
            let encryptedFileSize = encryptedData.count
            let fileName = "\(URL(fileURLWithPath: app.appLocalURL).lastPathComponent)"
            let registerURL = URL(string: "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/\(appId)/microsoft.graph.macOSLobApp/contentVersions/\(versionId)/files")!
            var fileRequest = URLRequest(url: registerURL)
            fileRequest.httpMethod = "POST"
            fileRequest.addValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
            fileRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
            let contentFile: [String: Any] = [
                "name": fileName,
                "@odata.type": "#microsoft.graph.mobileAppContentFile",
                "size": Int(plaintextSize),
                "sizeEncrypted": Int(encryptedFileSize)
            ]
            fileRequest.httpBody = try JSONSerialization.data(withJSONObject: contentFile)
            
            let (fileData, fileResponse) = try await URLSession.shared.data(for: fileRequest)
            if let httpResponse = fileResponse as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                let responseBody = String(data: fileData, encoding: .utf8) ?? "<non-UTF8 data>"
                Logger.log("File registration failed. Status: \(httpResponse.statusCode), Response: \(responseBody)", logType: "EntraGraphRequests")
                throw NSError(domain: "UploadLOBPkg", code: httpResponse.statusCode, userInfo: [
                    NSLocalizedDescriptionKey: "File registration failed. Status: \(httpResponse.statusCode)"
                ])
            }
            
            
            let fileJson = try JSONSerialization.jsonObject(with: fileData) as? [String: Any]
//            Logger.log("File registration response: \(fileJson as Any)", logType: "EntraGraphRequests")
            
            // After file registration
            guard let fileId = fileJson?["id"] as? String else {
                throw NSError(domain: "UploadLOBPkg", code: 11, userInfo: [NSLocalizedDescriptionKey: "Failed to get file ID from registration"])
            }
            
            // Poll for azureStorageUri
            var azureStorageUri: String? = nil
            let maxRetries = 10
            var retryCount = 0
            
            while azureStorageUri == nil && retryCount < maxRetries {
                // Wait a bit before polling
                try await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                
                // Check file status
                let fileStatusURL = URL(string: "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/\(appId)/microsoft.graph.macOSLobApp/contentVersions/\(versionId)/files/\(fileId)")!
                var statusRequest = URLRequest(url: fileStatusURL)
                statusRequest.httpMethod = "GET"
                statusRequest.addValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
                
                let (statusData, _) = try await URLSession.shared.data(for: statusRequest)
                let statusJson = try JSONSerialization.jsonObject(with: statusData) as? [String: Any]
                
//                Logger.log("File status response: \(statusJson as Any)", logType: "EntraGraphRequests")
                
                // Check if azureStorageUri is available
                if let uri = statusJson?["azureStorageUri"] as? String, !uri.isEmpty {
                    azureStorageUri = uri
                    break
                }
                
                retryCount += 1
            }
            
            guard let uploadUrl = azureStorageUri else {
                throw NSError(domain: "UploadLOBPkg", code: 12, userInfo: [NSLocalizedDescriptionKey: "Failed to get azureStorageUri after multiple attempts"])
            }
            
            
            // Upload file in chunks
            // Upload the encrypted file
            try await uploadFileInChunks(fileURL: encryptedFileURL, to: uploadUrl)
            
            // Delete the temporary encrypted file
            try FileManager.default.removeItem(at: encryptedFileURL)
            
            // After uploading the file chunks
            // Wait a bit before attempting to commit (give Azure storage time to process)
            try await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds
            
            
            // Commit the file
            
            Logger.log("Committing appId: \(appId)", logType: "EntraGraphRequests")
            Logger.log("Committing versionId: \(versionId)", logType: "EntraGraphRequests")
            Logger.log("Committing fileId: \(fileId)", logType: "EntraGraphRequests")
            
            let fileCommitURL = URL(string: "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/\(appId)/microsoft.graph.macOSLobApp/contentVersions/\(versionId)/files/\(fileId)/commit")!
            
            var fileCommitRequest = URLRequest(url: fileCommitURL)
            fileCommitRequest.httpMethod = "POST"
            fileCommitRequest.addValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
            fileCommitRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let commitBody = ["fileEncryptionInfo": encryptionInfo]
            
            let commitData = try JSONSerialization.data(withJSONObject: commitBody)
            fileCommitRequest.httpBody = commitData
            
            
            let (fileCommitResponseData, fileCommitResponse) = try await URLSession.shared.data(for: fileCommitRequest)
            
            if let httpResponse = fileCommitResponse as? HTTPURLResponse, httpResponse.statusCode != 200 {
                let responseBody = String(data: fileCommitResponseData, encoding: .utf8) ?? "<non-UTF8 data>"
                Logger.log("File commit status \(httpResponse.statusCode): \(responseBody)", logType: "EntraGraphRequests")
            }
            
            // After committing the file wait for commit to complete
            try await waitForFileUpload(appId: appId, versionId: versionId, fileId: fileId, appType: "microsoft.graph.macOSLobApp", authToken: authToken)
            
            
            // Update the app to use the new content version
            let updateURL = URL(string: "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/\(appId)")!
            var updateRequest = URLRequest(url: updateURL)
            updateRequest.httpMethod = "PATCH"
            updateRequest.addValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
            updateRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let patchData = try JSONSerialization.data(withJSONObject: [
                "@odata.type": "#microsoft.graph.macOSLobApp",
                "committedContentVersion": versionId
            ])
            updateRequest.httpBody = patchData
            
            let (updateResponseData, updateResponse) = try await URLSession.shared.data(for: updateRequest)
            if let httpResponse = updateResponse as? HTTPURLResponse, httpResponse.statusCode != 204 {
                let responseBody = String(data: updateResponseData, encoding: .utf8) ?? "<non-UTF8 data>"
                Logger.log("App update failed with status \(httpResponse.statusCode): \(responseBody)", logType: "EntraGraphRequests")
                throw NSError(domain: "UploadLOBPkg", code: 7, userInfo: [
                    NSLocalizedDescriptionKey: "Failed to update app with committed content version. Status: \(httpResponse.statusCode)"
                ])
            }
            
            Logger.log("LOB package uploaded and committed successfully ✅", logType: "EntraGraphRequests")
        }
        
        Logger.log("Assigning categories to Intune app...", logType: "EntraGraphRequests")
        
        // Assign the categories to the newly uploaded app
        do {
            let entraAuthenticator = EntraAuthenticator()
            let authToken = try await entraAuthenticator.getEntraIDToken()
            
            try await assignCategoriesToIntuneApp(
                authToken: authToken,
                appID: appId,
                categories: app.appCategories
            )
        } catch {
            Logger.log("Error assigning categories: \(error.localizedDescription)", logType: "EntraGraphRequests")
        }
        
        // Assign the groups to the newly uploaded app
        do {
            
            let entraAuthenticator = EntraAuthenticator()
            let authToken = try await entraAuthenticator.getEntraIDToken()
            
            // Call the assignment function
            try await EntraGraphRequests.assignGroupsToApp(authToken: authToken, appId: appId, appAssignments: app.appAssignments, appType: "macOSLobApp", installAsManaged: app.appIsManaged)
            
        } catch {
            throw NSError(domain: "AssignLOBPkg", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Failed to assign groups to app."
            ])
        }
        
//        print("LOB app uploaded and committed successfully ✅")
        
    }
    
    
    // MARK: - PKG
    // https://learn.microsoft.com/en-us/graph/api/intune-apps-macospkgapp-create?view=graph-rest-beta
    
    static func uploadPKGWithScripts(authToken: String, app: ProcessedAppResults) async throws {
        // Create the metadata payload with PKG-specific type
        let metadataURL = URL(string: "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps")!
        var request = URLRequest(url: metadataURL)
        request.httpMethod = "POST"
        request.addValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Build the notes field
        let fullNotes: String
        if app.appNotes.isEmpty {
            fullNotes = "Intuneomator ID: \(app.appTrackingID)"
        } else {
            fullNotes = "\(app.appNotes)\n\nIntuneomator ID: \(app.appTrackingID)"
        }

        // Determine architecture suffix for displayName
        let fileName = URL(fileURLWithPath: app.appLocalURL).lastPathComponent
        let arch = ["arm64", "x86_64"].first { fileName.contains($0) }
        let displayName = "\(app.appDisplayName) \(app.appVersionActual)\(arch.map { " \($0)" } ?? "")"

        var metadata: [String: Any] = [
            "@odata.type": "#microsoft.graph.macOSPkgApp",
            "displayName": displayName,
            "description": app.appDescription,
            "developer": app.appPublisherName,
            "publisher": app.appPublisherName,
            "owner": app.appOwner,
            "notes": fullNotes,
            "fileName": "\(URL(fileURLWithPath: app.appLocalURL).lastPathComponent)",
            "privacyInformationUrl": "",
            "informationUrl": app.appInfoURL,
            "primaryBundleId": app.appBundleIdActual,
            "primaryBundleVersion": app.appVersionActual,
            "ignoreVersionDetection": app.appIgnoreVersion,
            "isFeatured": app.appIsFeatured,
            "bundleId": app.appBundleIdActual,
            "buildNumber": app.appVersionActual,
            "includedApps": [[
                "@odata.type": "#microsoft.graph.macOSIncludedApp",
                "bundleId": app.appBundleIdActual,
                "bundleVersion": app.appVersionActual
            ]]
        ]
        
        // Add pre-install script if present
        let preInstall = app.appScriptPreInstall
        if !preInstall.isEmpty {
            metadata["preInstallScript"] = [
                "@odata.type": "#microsoft.graph.macOSAppScript",
                "scriptContent": Data(preInstall.utf8).base64EncodedString()
            ]
        }
        
        // Add post-install script if present
        let postInstall = app.appScriptPostInstall
        if !postInstall.isEmpty {
            metadata["postInstallScript"] = [
                "@odata.type": "#microsoft.graph.macOSAppScript",
                "scriptContent": Data(postInstall.utf8).base64EncodedString()
            ]
        }
        
        // Add min OS requirement
        metadata["minimumSupportedOperatingSystem"] = [
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
        
        // Add icon if available
        if FileManager.default.fileExists(atPath: app.appIconURL),
           let iconData = try? Data(contentsOf: URL(fileURLWithPath: app.appIconURL)) {
            metadata["largeIcon"] = [
                "@odata.type": "#microsoft.graph.mimeContent",
                "type": "image/png",
                "value": iconData.base64EncodedString()
            ]
        }
        
        
        request.httpBody = try JSONSerialization.data(withJSONObject: metadata, options: [])
        
        let (metadataData, metadataResponse) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = metadataResponse as? HTTPURLResponse {
            Logger.log("Metadata response status code: \(httpResponse.statusCode)", logType: "EntraGraphRequests")
            if !(200...299).contains(httpResponse.statusCode) {
                let responseBody = String(data: metadataData, encoding: .utf8) ?? "<non-UTF8 data>"
                Logger.log("Error response body: \(responseBody)", logType: "EntraGraphRequests")
                throw NSError(domain: "UploadPKGWithScripts", code: httpResponse.statusCode, userInfo: [
                    NSLocalizedDescriptionKey: "Failed to create PKG app metadata. Status: \(httpResponse.statusCode)"
                ])
            }
        }
        
        guard
            let metadataJson = try JSONSerialization.jsonObject(with: metadataData) as? [String: Any]
        else {
            throw NSError(domain: "UploadPKGWithScripts", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON returned from metadata request."])
        }
        
        guard let appId = metadataJson["id"] as? String else {
            throw NSError(domain: "UploadPKGWithScripts", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Failed to parse app ID from response: \(metadataJson)"
            ])
        }
        
        Logger.log("Uploaded \(displayName) metadata. App ID: \(appId)", logType: "EntraGraphRequests")
        Logger.log("Uploaded \(displayName) metadata. App ID: \(appId)", logType: "Automation")

        // Start upload session
        do {
            // Create content version
            let contentURL = URL(string: "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/\(appId)/microsoft.graph.macOSPkgApp/contentVersions")!
            var versionRequest = URLRequest(url: contentURL)
            versionRequest.httpMethod = "POST"
            versionRequest.addValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
            versionRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
            versionRequest.httpBody = "{}".data(using: .utf8)
            
            let (versionData, versionResponse) = try await URLSession.shared.data(for: versionRequest)
            if let httpResponse = versionResponse as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                let responseBody = String(data: versionData, encoding: .utf8) ?? "<non-UTF8 data>"
                Logger.log("Failed to create content version. Status: \(httpResponse.statusCode), Response: \(responseBody)", logType: "EntraGraphRequests")
                throw NSError(domain: "UploadPKGWithScripts", code: httpResponse.statusCode, userInfo: [
                    NSLocalizedDescriptionKey: "Failed to create content version. Status: \(httpResponse.statusCode)",
                    "responseBody": responseBody
                ])
            }
            
            let versionJson = try JSONSerialization.jsonObject(with: versionData) as? [String: Any]
//            Logger.log("Version JSON: \(versionJson as Any)", logType: "EntraGraphRequests")
            guard let versionId = versionJson?["id"] as? String else {
                throw NSError(domain: "UploadPKGWithScripts", code: 10, userInfo: [NSLocalizedDescriptionKey: "Failed to get version ID"])
            }
            
            // Encrypt the file before registration
            let (encryptedData, encryptionInfo, plaintextSize) = try encryptApp(fileURL: URL(fileURLWithPath: app.appLocalURL))
            
            // Save the encrypted data to a temporary file
            let tempDir = FileManager.default.temporaryDirectory
            let encryptedFileURL = tempDir.appendingPathComponent(UUID().uuidString + ".bin")
            try encryptedData.write(to: encryptedFileURL)
            
            // Register file with encrypted file size
            let encryptedFileSize = encryptedData.count
            let fileName = "\(URL(fileURLWithPath: app.appLocalURL).lastPathComponent)"
            let registerURL = URL(string: "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/\(appId)/microsoft.graph.macOSPkgApp/contentVersions/\(versionId)/files")!
            var fileRequest = URLRequest(url: registerURL)
            fileRequest.httpMethod = "POST"
            fileRequest.addValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
            fileRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
            let contentFile: [String: Any] = [
                "name": fileName,
                "@odata.type": "#microsoft.graph.mobileAppContentFile",
                "size": Int(plaintextSize),
                "sizeEncrypted": Int(encryptedFileSize)
            ]
            fileRequest.httpBody = try JSONSerialization.data(withJSONObject: contentFile)
            
            let (fileData, fileResponse) = try await URLSession.shared.data(for: fileRequest)
            if let httpResponse = fileResponse as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                let responseBody = String(data: fileData, encoding: .utf8) ?? "<non-UTF8 data>"
                Logger.log("File registration failed. Status: \(httpResponse.statusCode), Response: \(responseBody)", logType: "EntraGraphRequests")
                throw NSError(domain: "UploadPKGWithScripts", code: httpResponse.statusCode, userInfo: [
                    NSLocalizedDescriptionKey: "File registration failed. Status: \(httpResponse.statusCode)"
                ])
            }
            
            let fileJson = try JSONSerialization.jsonObject(with: fileData) as? [String: Any]
//            Logger.log("File registration response: \(fileJson as Any)", logType: "EntraGraphRequests")
            
            guard let fileId = fileJson?["id"] as? String else {
                throw NSError(domain: "UploadPKGWithScripts", code: 11, userInfo: [NSLocalizedDescriptionKey: "Failed to get file ID from registration"])
            }
            
            // Poll for azureStorageUri
            var azureStorageUri: String? = nil
            let maxRetries = 10
            var retryCount = 0
            
            while azureStorageUri == nil && retryCount < maxRetries {
                try await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                
                let fileStatusURL = URL(string: "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/\(appId)/microsoft.graph.macOSPkgApp/contentVersions/\(versionId)/files/\(fileId)")!
                var statusRequest = URLRequest(url: fileStatusURL)
                statusRequest.httpMethod = "GET"
                statusRequest.addValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
                
                let (statusData, _) = try await URLSession.shared.data(for: statusRequest)
                let statusJson = try JSONSerialization.jsonObject(with: statusData) as? [String: Any]
                
//                Logger.log("File status response: \(statusJson as Any)", logType: "EntraGraphRequests")
                
                if let uri = statusJson?["azureStorageUri"] as? String, !uri.isEmpty {
                    azureStorageUri = uri
                    break
                }
                
                retryCount += 1
            }
            
            guard let uploadUrl = azureStorageUri else {
                throw NSError(domain: "UploadPKGWithScripts", code: 12, userInfo: [NSLocalizedDescriptionKey: "Failed to get azureStorageUri after multiple attempts"])
            }
            
            // Upload file in chunks (using the new block upload method)
            try await uploadFileInChunks(fileURL: encryptedFileURL, to: uploadUrl)
            
            // Delete the temporary encrypted file
            try FileManager.default.removeItem(at: encryptedFileURL)
            
            // Wait before committing
            try await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds
            
            // Commit the file
            Logger.log("Committing appId: \(appId)", logType: "EntraGraphRequests")
            Logger.log("Committing versionId: \(versionId)", logType: "EntraGraphRequests")
            Logger.log("Committing fileId: \(fileId)", logType: "EntraGraphRequests")
            
            let fileCommitURL = URL(string: "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/\(appId)/microsoft.graph.macOSPkgApp/contentVersions/\(versionId)/files/\(fileId)/commit")!
            var fileCommitRequest = URLRequest(url: fileCommitURL)
            fileCommitRequest.httpMethod = "POST"
            fileCommitRequest.addValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
            fileCommitRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let commitBody = ["fileEncryptionInfo": encryptionInfo]
            let commitData = try JSONSerialization.data(withJSONObject: commitBody)
            fileCommitRequest.httpBody = commitData
            
            let (fileCommitResponseData, fileCommitResponse) = try await URLSession.shared.data(for: fileCommitRequest)
            
            if let httpResponse = fileCommitResponse as? HTTPURLResponse, httpResponse.statusCode != 200 {
                let responseBody = String(data: fileCommitResponseData, encoding: .utf8) ?? "<non-UTF8 data>"
                Logger.log("File commit status \(httpResponse.statusCode): \(responseBody)", logType: "EntraGraphRequests")
            }
            
            // Wait for file upload to complete
            try await waitForFileUpload(appId: appId, versionId: versionId, fileId: fileId, appType: "microsoft.graph.macOSPkgApp", authToken: authToken)
            
            // Update the app to use the new content version
            let updateURL = URL(string: "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/\(appId)")!
            var updateRequest = URLRequest(url: updateURL)
            updateRequest.httpMethod = "PATCH"
            updateRequest.addValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
            updateRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let patchData = try JSONSerialization.data(withJSONObject: [
                "@odata.type": "#microsoft.graph.macOSPkgApp",
                "committedContentVersion": versionId
            ])
            updateRequest.httpBody = patchData
            
            let (updateResponseData, updateResponse) = try await URLSession.shared.data(for: updateRequest)
            if let httpResponse = updateResponse as? HTTPURLResponse, httpResponse.statusCode != 204 {
                let responseBody = String(data: updateResponseData, encoding: .utf8) ?? "<non-UTF8 data>"
                Logger.log("App update failed with status \(httpResponse.statusCode): \(responseBody)", logType: "EntraGraphRequests")
                throw NSError(domain: "UploadPKGWithScripts", code: 7, userInfo: [
                    NSLocalizedDescriptionKey: "Failed to update app with committed content version. Status: \(httpResponse.statusCode)"
                ])
            }
            
            Logger.log("Assigning categories to Intune app...", logType: "EntraGraphRequests")
            
            // Assign the categories to the newly uploaded app
            do {
                let entraAuthenticator = EntraAuthenticator()
                let authToken = try await entraAuthenticator.getEntraIDToken()
                
                try await assignCategoriesToIntuneApp(
                    authToken: authToken,
                    appID: appId,
                    categories: app.appCategories
                )
            } catch {
                Logger.log("Error assigning categories: \(error.localizedDescription)", logType: "EntraGraphRequests")
            }
            
            // Assign the groups to the newly uploaded app
            do {
                
                let entraAuthenticator = EntraAuthenticator()
                let authToken = try await entraAuthenticator.getEntraIDToken()
                
                // Call the assignment function
                try await EntraGraphRequests.assignGroupsToApp(authToken: authToken, appId: appId, appAssignments: app.appAssignments, appType: "macOSpkgApp", installAsManaged: app.appIsManaged)
                
            } catch {
                throw NSError(domain: "AssignLOBPkg", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: "Failed to assign groups to app."
                ])
            }
            
            
//            print("PKG with scripts uploaded and committed successfully ✅")
        }
    }
    
    // MARK: - DMG
    // https://learn.microsoft.com/en-us/graph/api/intune-apps-macosdmgapp-create?view=graph-rest-beta
    
    static func uploadDMGApp(authToken: String, app: ProcessedAppResults) async throws {
        // Create the metadata payload with DMG-specific type
        let metadataURL = URL(string: "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps")!
        var request = URLRequest(url: metadataURL)
        request.httpMethod = "POST"
        request.addValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Build the notes field
        let fullNotes: String
        if app.appNotes.isEmpty {
            fullNotes = "Intuneomator ID: \(app.appTrackingID)"
        } else {
            fullNotes = "\(app.appNotes)\n\nIntuneomator ID: \(app.appTrackingID)"
        }

        // Determine architecture suffix for displayName
        let fileName = URL(fileURLWithPath: app.appLocalURL).lastPathComponent
        let arch = ["arm64", "x86_64"].first { fileName.contains($0) }
        let displayName = "\(app.appDisplayName) \(app.appVersionActual)\(arch.map { " \($0)" } ?? "")"

        var metadata: [String: Any] = [
            "@odata.type": "#microsoft.graph.macOSDmgApp",
            "displayName": displayName,
            "description": app.appDescription,
            "developer": app.appDeveloper,
            "publisher": app.appPublisherName,
            "owner": app.appOwner,
            "notes": fullNotes,
            "fileName": "\(URL(fileURLWithPath: app.appLocalURL).lastPathComponent)",
            "privacyInformationUrl": app.appPrivacyPolicyURL,
            "informationUrl": app.appInfoURL,
            "primaryBundleId": app.appBundleIdActual,
            "primaryBundleVersion": app.appVersionActual,
            "ignoreVersionDetection": app.appIgnoreVersion,
            "isFeatured": app.appIsFeatured,
            "includedApps": [[
                "@odata.type": "#microsoft.graph.macOSIncludedApp",
                "bundleId": app.appBundleIdActual,
                "bundleVersion": app.appVersionActual
            ]]
        ]
        
        // Add min OS requirement
        metadata["minimumSupportedOperatingSystem"] = [
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
        
        // Add icon if available
        if FileManager.default.fileExists(atPath: app.appIconURL),
           let iconData = try? Data(contentsOf: URL(fileURLWithPath: app.appIconURL)) {
            metadata["largeIcon"] = [
                "@odata.type": "#microsoft.graph.mimeContent",
                "type": "image/png",
                "value": iconData.base64EncodedString()
            ]
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: metadata, options: [])
        
        let (metadataData, metadataResponse) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = metadataResponse as? HTTPURLResponse {
            Logger.log("Metadata response status code: \(httpResponse.statusCode)", logType: "EntraGraphRequests")
            if !(200...299).contains(httpResponse.statusCode) {
                let responseBody = String(data: metadataData, encoding: .utf8) ?? "<non-UTF8 data>"
                Logger.log("Error response body: \(responseBody)", logType: "EntraGraphRequests")
                throw NSError(domain: "UploadDMGApp", code: httpResponse.statusCode, userInfo: [
                    NSLocalizedDescriptionKey: "Failed to create DMG app metadata. Status: \(httpResponse.statusCode)"
                ])
            }
        }
        
        guard
            let metadataJson = try JSONSerialization.jsonObject(with: metadataData) as? [String: Any]
        else {
            throw NSError(domain: "UploadDMGApp", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON returned from metadata request."])
        }
        
        guard let appId = metadataJson["id"] as? String else {
            throw NSError(domain: "UploadDMGApp", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Failed to parse app ID from response: \(metadataJson)"
            ])
        }
        
        Logger.log("Uploaded \(displayName) metadata. App ID: \(appId)", logType: "EntraGraphRequests")
        Logger.log("Uploaded \(displayName) metadata. App ID: \(appId)", logType: "Automation")

        // Start upload session
        do {
            // Create content version
            let contentURL = URL(string: "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/\(appId)/microsoft.graph.macOSDmgApp/contentVersions")!
            var versionRequest = URLRequest(url: contentURL)
            versionRequest.httpMethod = "POST"
            versionRequest.addValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
            versionRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
            versionRequest.httpBody = "{}".data(using: .utf8)
            
            let (versionData, versionResponse) = try await URLSession.shared.data(for: versionRequest)
            if let httpResponse = versionResponse as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                let responseBody = String(data: versionData, encoding: .utf8) ?? "<non-UTF8 data>"
                Logger.log("Failed to create content version. Status: \(httpResponse.statusCode), Response: \(responseBody)", logType: "EntraGraphRequests")
                throw NSError(domain: "UploadDMGApp", code: httpResponse.statusCode, userInfo: [
                    NSLocalizedDescriptionKey: "Failed to create content version. Status: \(httpResponse.statusCode)",
                    "responseBody": responseBody
                ])
            }
            
            let versionJson = try JSONSerialization.jsonObject(with: versionData) as? [String: Any]
//            Logger.log("Version JSON: \(versionJson as Any)", logType: "EntraGraphRequests")
            guard let versionId = versionJson?["id"] as? String else {
                throw NSError(domain: "UploadDMGApp", code: 10, userInfo: [NSLocalizedDescriptionKey: "Failed to get version ID"])
            }
            
            // Encrypt the file before registration
            let (encryptedData, encryptionInfo, plaintextSize) = try encryptApp(fileURL: URL(fileURLWithPath: app.appLocalURL))
            
            // Save the encrypted data to a temporary file
            let tempDir = FileManager.default.temporaryDirectory
            let encryptedFileURL = tempDir.appendingPathComponent(UUID().uuidString + ".bin")
            try encryptedData.write(to: encryptedFileURL)
            
            // Register file with encrypted file size
            let encryptedFileSize = encryptedData.count
            let fileName = "\(URL(fileURLWithPath: app.appLocalURL).lastPathComponent)"
            let registerURL = URL(string: "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/\(appId)/microsoft.graph.macOSDmgApp/contentVersions/\(versionId)/files")!
            var fileRequest = URLRequest(url: registerURL)
            fileRequest.httpMethod = "POST"
            fileRequest.addValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
            fileRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
            let contentFile: [String: Any] = [
                "name": fileName,
                "@odata.type": "#microsoft.graph.mobileAppContentFile",
                "size": Int(plaintextSize),
                "sizeEncrypted": Int(encryptedFileSize)
            ]
            fileRequest.httpBody = try JSONSerialization.data(withJSONObject: contentFile)
            
            let (fileData, fileResponse) = try await URLSession.shared.data(for: fileRequest)
            if let httpResponse = fileResponse as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                let responseBody = String(data: fileData, encoding: .utf8) ?? "<non-UTF8 data>"
                Logger.log("File registration failed. Status: \(httpResponse.statusCode), Response: \(responseBody)", logType: "EntraGraphRequests")
                throw NSError(domain: "UploadDMGApp", code: httpResponse.statusCode, userInfo: [
                    NSLocalizedDescriptionKey: "File registration failed. Status: \(httpResponse.statusCode)"
                ])
            }
            
            let fileJson = try JSONSerialization.jsonObject(with: fileData) as? [String: Any]
//            Logger.log("File registration response: \(fileJson as Any)", logType: "EntraGraphRequests")
            
            guard let fileId = fileJson?["id"] as? String else {
                throw NSError(domain: "UploadDMGApp", code: 11, userInfo: [NSLocalizedDescriptionKey: "Failed to get file ID from registration"])
            }
            
            // Poll for azureStorageUri
            var azureStorageUri: String? = nil
            let maxRetries = 10
            var retryCount = 0
            
            while azureStorageUri == nil && retryCount < maxRetries {
                try await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                
                let fileStatusURL = URL(string: "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/\(appId)/microsoft.graph.macOSDmgApp/contentVersions/\(versionId)/files/\(fileId)")!
                var statusRequest = URLRequest(url: fileStatusURL)
                statusRequest.httpMethod = "GET"
                statusRequest.addValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
                
                let (statusData, _) = try await URLSession.shared.data(for: statusRequest)
                let statusJson = try JSONSerialization.jsonObject(with: statusData) as? [String: Any]
                
//                Logger.log("File status response: \(statusJson as Any)", logType: "EntraGraphRequests")
                
                if let uri = statusJson?["azureStorageUri"] as? String, !uri.isEmpty {
                    azureStorageUri = uri
                    break
                }
                
                retryCount += 1
            }
            
            guard let uploadUrl = azureStorageUri else {
                throw NSError(domain: "UploadDMGApp", code: 12, userInfo: [NSLocalizedDescriptionKey: "Failed to get azureStorageUri after multiple attempts"])
            }
            
            // Upload file in chunks (using the new block upload method)
            try await uploadFileInChunks(fileURL: encryptedFileURL, to: uploadUrl)
            
            // Delete the temporary encrypted file
            try FileManager.default.removeItem(at: encryptedFileURL)
            
            // Wait before committing
            try await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds
            
            // Commit the file
            Logger.log("Committing appId: \(appId)", logType: "EntraGraphRequests")
            Logger.log("Committing versionId: \(versionId)", logType: "EntraGraphRequests")
            Logger.log("Committing fileId: \(fileId)", logType: "EntraGraphRequests")
            
            let fileCommitURL = URL(string: "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/\(appId)/microsoft.graph.macOSDmgApp/contentVersions/\(versionId)/files/\(fileId)/commit")!
            var fileCommitRequest = URLRequest(url: fileCommitURL)
            fileCommitRequest.httpMethod = "POST"
            fileCommitRequest.addValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
            fileCommitRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let commitBody = ["fileEncryptionInfo": encryptionInfo]
            let commitData = try JSONSerialization.data(withJSONObject: commitBody)
            fileCommitRequest.httpBody = commitData
            
            let (fileCommitResponseData, fileCommitResponse) = try await URLSession.shared.data(for: fileCommitRequest)
            
            if let httpResponse = fileCommitResponse as? HTTPURLResponse, httpResponse.statusCode != 200 {
                let responseBody = String(data: fileCommitResponseData, encoding: .utf8) ?? "<non-UTF8 data>"
                Logger.log("File commit status \(httpResponse.statusCode): \(responseBody)", logType: "EntraGraphRequests")
            }
            
            // Wait for file upload to complete
            try await waitForFileUpload(appId: appId, versionId: versionId, fileId: fileId, appType: "microsoft.graph.macOSDmgApp", authToken: authToken)
            
            // Update the app to use the new content version
            let updateURL = URL(string: "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/\(appId)")!
            var updateRequest = URLRequest(url: updateURL)
            updateRequest.httpMethod = "PATCH"
            updateRequest.addValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
            updateRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let patchData = try JSONSerialization.data(withJSONObject: [
                "@odata.type": "#microsoft.graph.macOSDmgApp",
                "committedContentVersion": versionId
            ])
            updateRequest.httpBody = patchData
            
            let (updateResponseData, updateResponse) = try await URLSession.shared.data(for: updateRequest)
            if let httpResponse = updateResponse as? HTTPURLResponse, httpResponse.statusCode != 204 {
                let responseBody = String(data: updateResponseData, encoding: .utf8) ?? "<non-UTF8 data>"
                Logger.log("App update failed with status \(httpResponse.statusCode): \(responseBody)", logType: "EntraGraphRequests")
                throw NSError(domain: "UploadDMGApp", code: 7, userInfo: [
                    NSLocalizedDescriptionKey: "Failed to update app with committed content version. Status: \(httpResponse.statusCode)"
                ])
            }
            
            Logger.log("Assigning categories to Intune app...", logType: "EntraGraphRequests")
            
            // Assign the categories to the newly uploaded app
            do {
                let entraAuthenticator = EntraAuthenticator()
                let authToken = try await entraAuthenticator.getEntraIDToken()
                
                try await assignCategoriesToIntuneApp(
                    authToken: authToken,
                    appID: appId,
                    categories: app.appCategories
                )
            } catch {
                Logger.log("Error assigning categories: \(error.localizedDescription)", logType: "EntraGraphRequests")
            }
            
            // Assign the groups to the newly uploaded app
            do {
                
                let entraAuthenticator = EntraAuthenticator()
                let authToken = try await entraAuthenticator.getEntraIDToken()
                
                // Call the assignment function
                try await EntraGraphRequests.assignGroupsToApp(authToken: authToken, appId: appId, appAssignments: app.appAssignments, appType: "macOSDmgApp", installAsManaged: app.appIsManaged)
                
            } catch {
                throw NSError(domain: "AssignLOBPkg", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: "Failed to assign groups to app."
                ])
            }
            
//            print("DMG app uploaded and committed successfully ✅")
        }
    }
    
    
    // MARK: - File Chunk Upload
    // File Chunk Upload - used by LOB, PKG, DMG
    private static func uploadFileInChunks(fileURL: URL, to uploadURL: String, chunkSize: Int = 6 * 1024 * 1024) async throws {
        // Get file size using FileManager
        let fileSize = try FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? Int ?? 0
        
        let uploadURL = URL(string: uploadURL)!
        let baseUploadURLString = uploadURL.absoluteString
        let fileHandle = try FileHandle(forReadingFrom: fileURL)
        defer {
            try? fileHandle.close()
        }
        
        var blockIds: [String] = []
        var blockIndex = 0
        var offset = 0
        
        // Upload file in blocks
        while offset < fileSize {
            // Read the next chunk
            try fileHandle.seek(toOffset: UInt64(offset))
            let chunkData = fileHandle.readData(ofLength: min(chunkSize, fileSize - offset))

            if chunkData.isEmpty {
                break
            }

            // Generate block ID
            let blockIdString = String(format: "block-%04d", blockIndex)
            let blockId = Data(blockIdString.utf8).base64EncodedString()
            blockIds.append(blockId)

            // Create URL for this block
            let blockURL = URL(string: "\(baseUploadURLString)&comp=block&blockid=\(blockId)")!

            // Create request
            var blockRequest = URLRequest(url: blockURL)
            blockRequest.httpMethod = "PUT"
            blockRequest.addValue("BlockBlob", forHTTPHeaderField: "x-ms-blob-type")
            blockRequest.httpBody = chunkData

            // Upload block with retry
            var lastError: Error?
            for attempt in 1...3 {
                do {
                    let (_, response) = try await URLSession.shared.data(for: blockRequest)
                    guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                        throw NSError(domain: "UploadError", code: (response as? HTTPURLResponse)?.statusCode ?? -1, userInfo: nil)
                    }
                    lastError = nil
                    break
                } catch {
                    lastError = error
                    if attempt < 3 {
                        // Exponential backoff before retrying
                        Logger.log("Throughput throttled, retrying block upload in \(0.5 * Double(attempt)) seconds...", logType: "EntraGraphRequests")
                        try await Task.sleep(nanoseconds: UInt64(0.5 * Double(attempt) * 1_000_000_000))
                        continue
                    }
                }
            }
            if let error = lastError {
                throw error
            }
            
            
            Logger.log("Uploaded block \(blockIndex): \(chunkData.count / 1024) KB", logType: "EntraGraphRequests")
            
            blockIndex += 1
            offset += chunkData.count
        }
        
        // After all blocks are uploaded, create and upload the block list XML
        var blockListXML = "<BlockList>"
        for id in blockIds {
            blockListXML += "<Latest>\(id)</Latest>"
        }
        blockListXML += "</BlockList>"
        
        let blockListData = blockListXML.data(using: .utf8)!
        
        // Create URL for the block list
        let blockListURL = URL(string: "\(baseUploadURLString)&comp=blocklist")!
        
        // Create request for block list
        var blockListRequest = URLRequest(url: blockListURL)
        blockListRequest.httpMethod = "PUT"
        blockListRequest.addValue("application/xml", forHTTPHeaderField: "Content-Type")
        blockListRequest.httpBody = blockListData
        
        Logger.log("Block list upload started...", logType: "EntraGraphRequests")

        // Upload block list
        let (blockListResponseData, blockListResponse) = try await URLSession.shared.data(for: blockListRequest)
        
        
        guard let blockListHTTPResponse = blockListResponse as? HTTPURLResponse, blockListHTTPResponse.statusCode == 201 else {
            let responseString = String(data: blockListResponseData, encoding: .utf8) ?? "<non-UTF8 data>"
            Logger.log("Block list upload failed: \(responseString)", logType: "EntraGraphRequests")
            throw NSError(domain: "UploadLOBPkg", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "Failed to upload block list XML"
            ])
        }
        Logger.log("Block list upload complete ✅", logType: "EntraGraphRequests")
        
        Logger.log("File upload complete ✅", logType: "EntraGraphRequests")
    }
    
    
    // MARK: - Wait for Upload
    // After committing the file, poll for status until completed or failed
    private static func waitForFileUpload(appId: String, versionId: String, fileId: String, appType: String, authToken: String) async throws {
        let maxAttempts = 20
        var attempt = 1
        
        while attempt <= maxAttempts {
            // Get the current status using the appropriate app type in the URL
            let fileStatusURL = URL(string: "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/\(appId)/\(appType)/contentVersions/\(versionId)/files/\(fileId)")!
            var statusRequest = URLRequest(url: fileStatusURL)
            statusRequest.httpMethod = "GET"
            statusRequest.addValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
            
            let (statusData, _) = try await URLSession.shared.data(for: statusRequest)
            
            if let statusJson = try JSONSerialization.jsonObject(with: statusData) as? [String: Any] {
//                Logger.log("Full file status response: \(statusJson)", logType: "EntraGraphRequests")
                
                if let uploadState = statusJson["uploadState"] as? String {
                    Logger.log("File upload state: \(uploadState)", logType: "EntraGraphRequests")
                    
                    // Check for success state
                    if uploadState == "commitFileSuccess" {
                        Logger.log("File upload successfully committed ✅", logType: "EntraGraphRequests")
                        return
                    }
                    
                    // Check for failure state
                    if uploadState == "commitFileFailed" {
                        // Get more error details if available
                        if let errorCode = statusJson["errorCode"] as? String {
                            Logger.log("Error code: \(errorCode)", logType: "EntraGraphRequests")
                        }
                        if let errorDescription = statusJson["errorDescription"] as? String {
                            Logger.log("Error description: \(errorDescription)", logType: "EntraGraphRequests")
                        }
                        
                        throw NSError(domain: "UploadApp", code: 6, userInfo: [
                            NSLocalizedDescriptionKey: "Failed to commit file. Upload state: commitFileFailed"
                        ])
                    }
                }
            }
            
            // Wait 5 seconds between attempts
            try await Task.sleep(nanoseconds: 5_000_000_000)
            attempt += 1
        }
        
        // If we get here, we've timed out
        throw NSError(domain: "UploadApp", code: 7, userInfo: [
            NSLocalizedDescriptionKey: "Timed out waiting for file upload to complete after \(maxAttempts) attempts"
        ])
    }
    
    
    // MARK: - Encryption Functions
    // Helper function to encrypt the app file
    private static func encryptApp(fileURL: URL) throws -> (encryptedData: Data, encryptionInfo: [String: Any], plaintextSize: Int) {
        
        // Read the file data
        let fileData = try Data(contentsOf: fileURL)
        let plaintextSize = fileData.count
        
        
        
        // Generate random keys and IV
        var encryptionKey = Data(count: 32)  // 256 bits
        var hmacKey = Data(count: 32)        // 256 bits
        var initializationVector = Data(count: 16)  // 128 bits
        
        _ = encryptionKey.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 32, $0.baseAddress!) }
        _ = hmacKey.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 32, $0.baseAddress!) }
        _ = initializationVector.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 16, $0.baseAddress!) }
        
        
        // Encrypt the file using AES-256 in CBC mode with PKCS7 padding
        let encryptedData = try encryptAES256(data: fileData, key: encryptionKey, iv: initializationVector)
        
        
        // Step 1: Combine the IV and encrypted data into a single byte string
        let ivData = initializationVector + encryptedData
        
        // Step 2: Generate a HMAC-SHA256 signature of the IV and encrypted data
        let signature = hmacSHA256(data: ivData, key: hmacKey)
        
        // Step 3: Combine the signature and IV + encrypted data into a single byte string
        let encryptedPackage = signature + ivData
        
        // Step 4: Create the file digest (SHA-256 of the original file)
        let fileDigest = fileData.sha256() ?? Data()
        
        // Step 5: Create the file encryption info dictionary
        let fileEncryptionInfo: [String: Any] = [
            "@odata.type": "#microsoft.graph.fileEncryptionInfo",
            "encryptionKey": encryptionKey.base64EncodedString(),
            "macKey": hmacKey.base64EncodedString(),
            "initializationVector": initializationVector.base64EncodedString(),
            "profileIdentifier": "ProfileVersion1",
            "fileDigestAlgorithm": "SHA256",
            "fileDigest": fileDigest.base64EncodedString(),
            "mac": signature.base64EncodedString()
        ]
        
        return (encryptedPackage, fileEncryptionInfo, plaintextSize)
    }
    
    // Helper function for AES-256 CBC encryption with PKCS7 padding
    private static func encryptAES256(data: Data, key: Data, iv: Data) throws -> Data {
        // Create a buffer large enough to hold the encrypted data
        // AES encryption in CBC mode with PKCS7 padding might increase the size up to one block
        let bufferSize = data.count + kCCBlockSizeAES128
        var encryptedBytes = [UInt8](repeating: 0, count: bufferSize)
        var numBytesEncrypted = 0
        
        // Perform encryption
        let cryptStatus = key.withUnsafeBytes { keyBytes in
            iv.withUnsafeBytes { ivBytes in
                data.withUnsafeBytes { dataBytes in
                    CCCrypt(
                        CCOperation(kCCEncrypt),
                        CCAlgorithm(kCCAlgorithmAES),
                        CCOptions(kCCOptionPKCS7Padding),
                        keyBytes.baseAddress, key.count,
                        ivBytes.baseAddress,
                        dataBytes.baseAddress, data.count,
                        &encryptedBytes, bufferSize,
                        &numBytesEncrypted
                    )
                }
            }
        }
        
        guard cryptStatus == kCCSuccess else {
            throw NSError(domain: "EncryptionError", code: Int(cryptStatus),
                          userInfo: [NSLocalizedDescriptionKey: "Encryption failed with status: \(cryptStatus)"])
        }
        
        // Return only the bytes that were actually encrypted
        return Data(encryptedBytes.prefix(numBytesEncrypted))
    }
    
    
    // Helper function for HMAC-SHA256
    private static func hmacSHA256(data: Data, key: Data) -> Data {
        var macOut = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        
        data.withUnsafeBytes { dataBytes in
            key.withUnsafeBytes { keyBytes in
                CCHmac(
                    CCHmacAlgorithm(kCCHmacAlgSHA256),
                    keyBytes.baseAddress!, key.count,
                    dataBytes.baseAddress!, data.count,
                    &macOut
                )
            }
        }
        
        return Data(macOut)
    }
}


// Helper extension for SHA-256 hashing
extension Data {
    func sha256() -> Data? {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        self.withUnsafeBytes { buffer in
            _ = CC_SHA256(buffer.baseAddress, CC_LONG(self.count), &hash)
        }
        return Data(hash)
    }
}
