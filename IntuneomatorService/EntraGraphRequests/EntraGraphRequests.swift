//
//  EntraGraphRequests.swift
//  Intuneomator
//
//  Created by Gil Burns on 3/24/25.
//

import Foundation
import CommonCrypto

/// Handles Microsoft Graph API requests for Intune mobile app management
/// Provides methods for fetching app categories, assignment filters, managing app assignments, and app operations
class EntraGraphRequests {
    
    
    /// Custom error types for Microsoft Graph API operations
    enum GraphAPIError: Error {
        case invalidURL
        case requestFailed(Error)
        case invalidResponse
        case decodingError(Error)
        case encodingError
        case apiError(String)
        case resourceNotFound(String)
    }
    
    // MARK: - Fetch device filters from Graph
    //https://learn.microsoft.com/en-us/graph/api/intune-policyset-deviceandappmanagementassignmentfilter-list?view=graph-rest-beta
    
    /// Fetches macOS assignment filters from Microsoft Graph API
    /// - Parameter authToken: Valid access token for Microsoft Graph API
    /// - Returns: Array of dictionaries containing filter ID, display name, and description
    /// - Throws: GraphAPIError for decoding failures or invalid URL
    static func fetchMacAssignmentFiltersAsDictionaries(authToken: String) async throws -> [[String: Any]] {
        let urlString = "https://graph.microsoft.com/beta/deviceManagement/assignmentFilters?$filter=platform eq 'macOS'&$select=id,displayName,description"
        guard let url = URL(string: urlString) else {
            throw NSError(domain: "InvalidURL", code: -1)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, _) = try await URLSession.shared.data(for: request)
        let decoded = try JSONDecoder().decode(GraphResponse.self, from: data)
        
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
    
    
    // MARK: - Find Apps By Tracking ID
    
    /// Searches for macOS apps in Intune by tracking ID in the notes field
    /// - Parameters:
    ///   - authToken: Valid access token for Microsoft Graph API
    ///   - trackingID: Unique tracking identifier to search for in app notes
    /// - Returns: Array of filtered app information matching the tracking ID
    /// - Throws: GraphAPIError for various request and processing failures
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
    
    
    
    
    // MARK: - Assign Groups to App
    
    /// Assigns Azure AD groups to an Intune mobile app with specified settings
    /// - Parameters:
    ///   - authToken: Valid access token for Microsoft Graph API
    ///   - appId: Unique identifier of the mobile app in Intune
    ///   - appAssignments: Array of assignment configurations including groups, assignment types, and filters
    ///   - appType: Type of the mobile app (e.g., macOSLobApp, macOSPkgApp)
    ///   - installAsManaged: Whether to install the app as managed with uninstall on device removal
    /// - Throws: GraphAPIError for encoding, API, or response failures
    static func assignGroupsToApp(authToken: String, appId: String, appAssignments: [[String: Any]], appType: String, installAsManaged: Bool) async throws {
        
        // Format the URL for the assignment endpoint
        let baseURL = "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/\(appId)/microsoft.graph.assign"
        
        guard let url = URL(string: baseURL) else {
            throw GraphAPIError.invalidURL
        }
                
        // Build the assignments payload
        var assignments: [[String: Any]] = []
        
        for assignment in appAssignments {
            
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
                
        // Prepare the request payload
        let requestPayload: [String: Any] = ["mobileAppAssignments": assignments]
        
        // Convert payload to JSON Data
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestPayload) else {
            throw GraphAPIError.encodingError
        }
//        Logger.info("jsonData: \(jsonData)", category: .core)
        
        // Add more detailed logging
//        Logger.info("Final request payload: \(String(data: jsonData, encoding: .utf8, category: .core) ?? "Could not decode payload")", logType: logType)
        
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
                Logger.error("Error String: \(errorString)", category: .core)

                throw GraphAPIError.apiError("API Error: \(errorString)")
            }
            throw GraphAPIError.invalidResponse
        }
    }
    
    
    /// Checks if the specified app type supports assignment filters
    /// - Parameter appType: The mobile app type to check
    /// - Returns: True if assignment filters are supported for this app type
    private static func appTypeSupportsAssignmentFilters(_ appType: String) -> Bool {
        return assignmentFilterSupportedAppTypes.contains(appType)
    }
    
    /// Set of app types that support assignment filters in Microsoft Intune
    private static let assignmentFilterSupportedAppTypes: Set<String> = [
        "macOSLobApp", // Currently supported
        "macOSWebClip"
        // If Microsoft adds support later:
        // "macOSPkgApp",
        // "macOSDmgApp"
    ]
    
    /// Applies assignment filter to a target object if filter is available and supported
    /// - Parameters:
    ///   - target: Target assignment object to modify
    ///   - assignment: Assignment configuration containing filter information
    ///   - appType: Type of mobile app to check filter support
    private static func applyFilterIfAvailable(to target: inout [String: Any], from assignment: [String: Any], appType: String) {
        if let filter = assignment["filter"] as? [String: Any],
           let filterId = filter["id"] as? String,
           let filterMode = filter["mode"] as? String {
            
            if appTypeSupportsAssignmentFilters(appType) {
                target["deviceAndAppManagementAssignmentFilterId"] = filterId
                target["deviceAndAppManagementAssignmentFilterType"] = filterMode.lowercased()
                Logger.info("🔎 Filter applied: ID=\(filterId), Type=\(filterMode.lowercased()) to \(target))", category: .core)
            } else {
                Logger.info("⚠️ Filter was provided for unsupported appType: \(appType). Ignoring.", category: .core)
            }
        } else {
            Logger.info("ℹ️ No filter applied for this assignment target", category: .core)
        }
    }
    
    
    // MARK: - Intune Remove All Groups assignments from an app
    
    /// Removes all group assignments from an Intune mobile app
    /// - Parameters:
    ///   - authToken: Valid access token for Microsoft Graph API
    ///   - appId: Unique identifier of the mobile app in Intune
    /// - Throws: GraphAPIError for API failures or invalid responses
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
            
            Logger.info("Removed assignment: \(assignment.id)", category: .core)
        }
        
        Logger.info("All assignments removed for app: \(appId)", category: .core)
    }
    
    

    // MARK: - Intune Update App Scripts
    
    /// Updates pre-install and post-install scripts for a macOS PKG app in Intune
    /// - Parameters:
    ///   - authToken: Valid access token for Microsoft Graph API
    ///   - app: Processed app results containing script content
    ///   - appId: Unique identifier of the mobile app in Intune
    /// - Throws: GraphAPIError for API failures, NSError for unsupported deployment types
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
        
        Logger.info("Successfully updated scripts for app ID \(appId)", category: .core)
        Logger.info("Successfully updated \(app.appDisplayName) scripts for app ID \(appId)", category: .core)
    }

    // MARK: - Intune Delete App Function
    
    /// Deletes a mobile app from Intune after removing all assignments
    /// - Parameters:
    ///   - authToken: Valid access token for Microsoft Graph API
    ///   - appId: Unique identifier of the mobile app to delete
    /// - Throws: GraphAPIError for API failures or invalid responses
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
        
        Logger.info("App deleted successfully: \(appId)", category: .core)
    }
}


/// Helper extension for SHA-256 hashing operations
extension Data {
    /// Computes SHA-256 hash of the data
    /// - Returns: SHA-256 hash as Data, or nil if hashing fails
    func sha256() -> Data? {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        self.withUnsafeBytes { buffer in
            _ = CC_SHA256(buffer.baseAddress, CC_LONG(self.count), &hash)
        }
        return Data(hash)
    }
}
