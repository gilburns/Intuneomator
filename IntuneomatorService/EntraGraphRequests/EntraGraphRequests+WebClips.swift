//
//  EntraGraphRequests+WebClips.swift
//  Intuneomator
//
//  Created by Gil Burns on 7/6/25.
//

import Foundation

// MARK: - Web Clip Management Extension

/// Extension for handling Microsoft Graph API Web Clip operations
/// Provides functionality for fetching and managing Intune macOS Web Clip
extension EntraGraphRequests {
    
    // MARK: - Fetch WebClips
    // https://learn.microsoft.com/en-us/graph/api/resources/intune-apps-macoswebclip?view=graph-rest-beta
        
    static func fetchIntuneWebClips(authToken: String) async throws -> [[String: Any]] {
        var allWebClips: [[String: Any]] = []
        
        // Construct the initial URL
        // Note: $select is not used because the mobileApps endpoint only supports common fields
        // across all app types. Web clip-specific fields like appUrl are not available in $select.
        let baseURL = "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps"
        let filter = "$filter=(isof('microsoft.graph.macOSWebClip'))"
        let initialURL = "\(baseURL)?\(filter)"
        
        var nextPageUrl: String? = initialURL
        var pageCount = 0
        
        Logger.info("Starting paginated fetch of Intune Web Clips...", category: .core)
        
        // Follow pagination until all web clips are fetched
        while let urlString = nextPageUrl {
            Logger.info("Fetching web clips from URL: \(urlString)", category: .core)
            
            guard let url = URL(string: urlString) else {
                throw NSError(domain: "EntraGraphRequests.WebClips", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid pagination URL: \(urlString)"])
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                let responseString = String(data: data, encoding: .utf8) ?? "No response data"
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                Logger.error("HTTP \(statusCode) error fetching web clips (page \(pageCount + 1)): \(responseString)", category: .core)
                throw NSError(domain: "EntraGraphRequests.WebClips", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch Intune Web Clip data (page \(pageCount + 1)): HTTP \(statusCode) - \(responseString)"])
            }
            
            // Parse JSON response
            guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
                throw NSError(domain: "EntraGraphRequests.WebClips", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON response format for Intune Web Clip data (page \(pageCount + 1))"])
            }
            
            // Extract web clips from this page
            guard let pageWebClips = json["value"] as? [[String: Any]] else {
                throw NSError(domain: "EntraGraphRequests.WebClips", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid response format for Intune Web Clip data (page \(pageCount + 1))"])
            }
            
            allWebClips.append(contentsOf: pageWebClips)
            pageCount += 1
            
            // Check for next page
            nextPageUrl = json["@odata.nextLink"] as? String
            
            Logger.info("Fetched page \(pageCount) with \(pageWebClips.count) web clips (total: \(allWebClips.count))", category: .core)
            
            // Safety check to prevent infinite loops
            if pageCount > 100 {
                Logger.error("Safety limit reached: stopping after 100 pages of web clips", category: .core)
                break
            }
        }
        
        Logger.info("Completed fetching \(allWebClips.count) total web clips across \(pageCount) pages", category: .core)
        
        // Sort all web clips alphabetically by display name
        return allWebClips.sorted {
            guard let name1 = $0["displayName"] as? String, let name2 = $1["displayName"] as? String else { return false }
            return name1.localizedCaseInsensitiveCompare(name2) == .orderedAscending
        }
    }
    
    // MARK: - Fetch Full Web Clip Details
    
    /// Fetches complete web clip details including icon data for a specific web clip
    /// - Parameters:
    ///   - authToken: Valid access token for Microsoft Graph API
    ///   - webClipId: Unique identifier (GUID) of the web clip
    /// - Returns: Dictionary containing complete web clip information including largeIcon
    /// - Throws: Network errors, authentication errors, or API errors
    static func fetchWebClipDetails(authToken: String, webClipId: String) async throws -> [String: Any] {
        let detailsURL = "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/\(webClipId)"
        
        guard let url = URL(string: detailsURL) else {
            throw NSError(domain: "EntraGraphRequests.WebClips", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid web clip details URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            let responseStr = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "EntraGraphRequests.WebClips", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch web clip details. Response: \(responseStr)"])
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
            throw NSError(domain: "EntraGraphRequests.WebClips", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid response format for web clip details"])
        }
        
        Logger.info("Fetched complete details for web clip \(webClipId)", category: .core)
        return json
    }
    
    // MARK: - Create Web Clip with Assignments and Categories
    
    /// Creates a new web clip with categories and group assignments in a single operation
    /// This convenience function handles the complete workflow: create web clip → assign categories → assign groups
    /// - Parameters:
    ///   - authToken: Valid access token for Microsoft Graph API
    ///   - webClipData: Complete web clip configuration including categories and assignments
    /// - Returns: Dictionary containing the created web clip ID and operation results
    /// - Throws: Network errors, authentication errors, or API errors
    static func createWebClipWithAssignments(authToken: String, webClipData: [String: Any]) async throws -> [String: Any] {
        Logger.info("Starting complete web clip creation with assignments and categories", category: .core)
        
        // Step 1: Extract categories and assignments from the data
        let categories = webClipData["categories"] as? [[String: Any]] ?? []
        let assignments = webClipData["assignments"] as? [[String: Any]] ?? []
        
        // Step 2: Prepare clean web clip data (remove categories and assignments for initial creation)
        var cleanWebClipData = webClipData
        cleanWebClipData.removeValue(forKey: "categories")
        cleanWebClipData.removeValue(forKey: "assignments")
        
        // Step 3: Create the web clip
        let webClipId = try await createIntuneWebClip(authToken: authToken, webClipData: cleanWebClipData)
        Logger.info("Web clip created successfully with ID: \(webClipId)", category: .core)
        
        var results: [String: Any] = [
            "webClipId": webClipId,
            "created": true,
            "categoriesAssigned": false,
            "groupsAssigned": false
        ]
        
        // Step 4: Wait for web clip to be ready (polling)
        let isReady = try await waitForWebClipReady(authToken: authToken, webClipId: webClipId)
        if !isReady {
            Logger.warning("Web clip may not be fully ready, proceeding with assignments anyway", category: .core)
        }
        
        // Step 5: Assign categories if any
        if !categories.isEmpty {
            do {
                let categoryObjects = categories.compactMap { categoryDict -> Category? in
                    guard let id = categoryDict["id"] as? String,
                          let displayName = categoryDict["displayName"] as? String else {
                        return nil
                    }
                    return Category(displayName: displayName, id: id)
                }
                
                if !categoryObjects.isEmpty {
                    try await EntraGraphRequests.assignCategoriesToIntuneApp(
                        authToken: authToken,
                        appID: webClipId,
                        categories: categoryObjects
                    )
                    results["categoriesAssigned"] = true
                    Logger.info("Successfully assigned \(categoryObjects.count) categories to web clip \(webClipId)", category: .core)
                }
            } catch {
                Logger.error("Failed to assign categories to web clip \(webClipId): \(error)", category: .core)
                results["categoryError"] = error.localizedDescription
            }
        }
        
        // Step 6: Assign groups if any
        if !assignments.isEmpty {
            do {
                try await EntraGraphRequests.assignGroupsToApp(
                    authToken: authToken,
                    appId: webClipId,
                    appAssignments: assignments,
                    appType: "macOSWebClip",
                    installAsManaged: false // Web clips don't use managed installation
                )
                results["groupsAssigned"] = true
                Logger.info("Successfully assigned \(assignments.count) groups to web clip \(webClipId)", category: .core)
            } catch {
                Logger.error("Failed to assign groups to web clip \(webClipId): \(error)", category: .core)
                results["assignmentError"] = error.localizedDescription
            }
        }
        
        Logger.info("Completed web clip creation workflow for \(webClipId)", category: .core)
        return results
    }
    
    /// Waits for a newly created web clip to be ready for assignments
    /// - Parameters:
    ///   - authToken: Valid access token for Microsoft Graph API
    ///   - webClipId: ID of the web clip to check
    /// - Returns: True if web clip is ready, false if timeout reached
    private static func waitForWebClipReady(authToken: String, webClipId: String) async throws -> Bool {
        let maxAttempts = 10
        let delaySeconds: UInt64 = 2_000_000_000 // 2 seconds in nanoseconds
        
        for attempt in 1...maxAttempts {
            Logger.info("Checking web clip readiness (attempt \(attempt)/\(maxAttempts))", category: .core)
            
            do {
                // Try to fetch the web clip details
                let _ = try await fetchWebClipDetails(authToken: authToken, webClipId: webClipId)
                Logger.info("Web clip \(webClipId) is ready for assignments", category: .core)
                return true
            } catch {
                Logger.info("Web clip not ready yet (attempt \(attempt)), waiting...", category: .core)
                
                if attempt < maxAttempts {
                    try await Task.sleep(nanoseconds: delaySeconds)
                }
            }
        }
        
        Logger.warning("Web clip readiness check timed out after \(maxAttempts) attempts", category: .core)
        return false
    }

    
    // MARK: - Create Web Clip
    static func createIntuneWebClip(authToken: String, webClipData: [String: Any]) async throws -> String {
        let baseEndpoint = "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps"

        guard let url = URL(string: baseEndpoint) else {
            throw NSError(domain: "EntraGraphRequests.WebClips", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let jsonData = try JSONSerialization.data(withJSONObject: webClipData, options: [])
        request.httpBody = jsonData
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            let responseStr = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "EntraGraphRequests.WebClips", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to create web clip. Response: \(responseStr)"])
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
              let webClipId = json["id"] as? String else {
            throw NSError(domain: "EntraGraphRequests.WebClips", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to extract web clip ID from response"])
        }
        
        return webClipId
    }

    
    // MARK: - Update Web Clip
    static func updateWebClip(authToken: String, webClipId: String, updatedData: [String: Any]) async throws -> Bool {
        let updateURL = "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/\(webClipId)"
        
        guard let url = URL(string: updateURL) else {
            throw NSError(domain: "EntraGraphRequests.WebClips", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
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
            throw NSError(domain: "EntraGraphRequests.WebClips", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to update web clip. Response: \(responseStr)"])
        }
        
        return true
    }

    
    // MARK: - Delete Web Clip
    static func deleteWebClip(authToken: String, byId webClipId: String) async throws -> Bool {
        
        let deleteURL = "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/\(webClipId)"
        
        guard let url = URL(string: deleteURL) else {
            throw NSError(domain: "EntraGraphRequests.WebClips", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw NSError(domain: "EntraGraphRequests.WebClips", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to delete web clip."])
        }
        return true
    }
    
    // MARK: - Fetch Web Clip Assignments and Categories
    
    /// Fetches full web clip details, group assignments, and category assignments for a specific web clip
    /// This function retrieves comprehensive information needed for editing existing web clips including icon data
    /// - Parameters:
    ///   - authToken: Valid access token for Microsoft Graph API
    ///   - webClipId: Unique identifier (GUID) of the web clip
    /// - Returns: Dictionary containing web clip details, assignments, and categories
    /// - Throws: Network errors, authentication errors, or API errors
    static func fetchWebClipAssignmentsAndCategories(authToken: String, webClipId: String) async throws -> [String: Any] {
        Logger.info("Fetching full details, assignments and categories for web clip \(webClipId)", category: .core)
        
        // Fetch web clip details, group assignments, and categories concurrently
        async let webClipDetails = fetchWebClipDetails(authToken: authToken, webClipId: webClipId)
        async let groupAssignments = fetchWebClipGroupAssignments(authToken: authToken, webClipId: webClipId)
        async let categories = fetchWebClipCategories(authToken: authToken, webClipId: webClipId)
        
        let details = try await webClipDetails
        let assignments = try await groupAssignments
        let webClipCategories = try await categories
        
        // Merge the web clip details with assignments and categories
        var result = details
        result["assignments"] = assignments
        result["categories"] = webClipCategories
        
        Logger.info("Successfully fetched \(assignments.count) assignments and \(webClipCategories.count) categories for web clip \(webClipId)", category: .core)
        return result
    }
    
    /// Fetches group assignments for a specific web clip
    /// - Parameters:
    ///   - authToken: Valid access token for Microsoft Graph API
    ///   - webClipId: Unique identifier (GUID) of the web clip
    /// - Returns: Array of assignment dictionaries with group information
    /// - Throws: Network errors, authentication errors, or API errors
    private static func fetchWebClipGroupAssignments(authToken: String, webClipId: String) async throws -> [[String: Any]] {
        let assignmentsURL = "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/\(webClipId)/assignments"
        
        guard let url = URL(string: assignmentsURL) else {
            throw NSError(domain: "EntraGraphRequests.WebClips", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid assignments URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            let responseStr = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "EntraGraphRequests.WebClips", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch web clip assignments. Response: \(responseStr)"])
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
              let assignments = json["value"] as? [[String: Any]] else {
            throw NSError(domain: "EntraGraphRequests.WebClips", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid response format for web clip assignments"])
        }
        
        Logger.info("Fetched \(assignments.count) assignments for web clip \(webClipId)", category: .core)
        return assignments
    }
    
    /// Fetches category assignments for a specific web clip
    /// - Parameters:
    ///   - authToken: Valid access token for Microsoft Graph API
    ///   - webClipId: Unique identifier (GUID) of the web clip
    /// - Returns: Array of category dictionaries with category information
    /// - Throws: Network errors, authentication errors, or API errors
    private static func fetchWebClipCategories(authToken: String, webClipId: String) async throws -> [[String: Any]] {
        let categoriesURL = "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/\(webClipId)/categories"
        
        guard let url = URL(string: categoriesURL) else {
            throw NSError(domain: "EntraGraphRequests.WebClips", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid categories URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            let responseStr = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "EntraGraphRequests.WebClips", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch web clip categories. Response: \(responseStr)"])
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
              let categories = json["value"] as? [[String: Any]] else {
            throw NSError(domain: "EntraGraphRequests.WebClips", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid response format for web clip categories"])
        }
        
        Logger.info("Fetched \(categories.count) categories for web clip \(webClipId)", category: .core)
        return categories
    }
    
    // MARK: - Update Web Clip with Assignments and Categories
    
    /// Updates an existing web clip with categories and group assignments in a comprehensive workflow
    /// This function handles the complete update sequence: PATCH web clip → update categories → update assignments
    /// - Parameters:
    ///   - authToken: Valid access token for Microsoft Graph API
    ///   - webClipData: Complete web clip data including properties, categories, and assignments
    /// - Returns: True if the complete workflow was successful, false otherwise
    /// - Throws: Network errors, authentication errors, or API errors
    static func updateWebClipWithAssignments(authToken: String, webClipData: [String: Any]) async throws -> Bool {
        guard let webClipId = webClipData["id"] as? String else {
            throw NSError(domain: "EntraGraphRequests.WebClips", code: 400, userInfo: [NSLocalizedDescriptionKey: "Web clip ID is required for update"])
        }
        
        Logger.info("Starting comprehensive update workflow for web clip \(webClipId)", category: .core)
        
        // Step 1: Extract categories and assignments from the data
        let categories = webClipData["categories"] as? [[String: Any]] ?? []
        let groupAssignments = webClipData["groupAssignments"] as? [[String: Any]] ?? []
        
        // Step 2: Prepare clean web clip data (remove categories and assignments for PATCH)
        var cleanWebClipData = webClipData
        let fieldsToRemove = [
            "id",
            "appUrl",  // appUrl is immutable after creation
            "@odata.context",
            "createdDateTime",
            "lastModifiedDateTime",
            "uploadState",
            "supersedingAppCount",
            "dependentAppCount",
            "supersededAppCount",
            "isAssigned",
            "publishingState",
            "roleScopeTagIds",
            "assignments",  // Don't include raw assignments in PATCH
            "categories",   // Don't include raw categories in PATCH
            "groupAssignments",  // This is for internal use only
            "isNewWebClip"  // This is for internal use only
        ]
        
        for field in fieldsToRemove {
            cleanWebClipData.removeValue(forKey: field)
        }
        
        // Ensure @odata.type is included for Graph API
        cleanWebClipData["@odata.type"] = "#microsoft.graph.macOSWebClip"
        
        // Step 3: Update the web clip properties
        let updateSuccess = try await updateWebClip(authToken: authToken, webClipId: webClipId, updatedData: cleanWebClipData)
        if !updateSuccess {
            Logger.error("Failed to update web clip properties for \(webClipId)", category: .core)
            return false
        }
        Logger.info("Successfully updated web clip properties for \(webClipId)", category: .core)
        
        var allSuccess = true
        
        // Step 4: Update categories - always remove existing first, then add new ones if any
        do {
            // First, remove all existing categories to avoid conflicts
            try await EntraGraphRequests.removeAllCategoriesFromIntuneApp(
                authToken: authToken,
                appID: webClipId
            )
            Logger.info("Successfully removed all existing categories from web clip \(webClipId)", category: .core)
            
            // Then, assign new categories if any
            if !categories.isEmpty {
                let categoryObjects = categories.compactMap { categoryDict -> Category? in
                    guard let id = categoryDict["id"] as? String,
                          let displayName = categoryDict["displayName"] as? String else {
                        return nil
                    }
                    return Category(displayName: displayName, id: id)
                }
                
                if !categoryObjects.isEmpty {
                    try await EntraGraphRequests.assignCategoriesToIntuneApp(
                        authToken: authToken,
                        appID: webClipId,
                        categories: categoryObjects
                    )
                    Logger.info("Successfully assigned \(categoryObjects.count) new categories to web clip \(webClipId)", category: .core)
                }
            } else {
                Logger.info("No new categories to assign to web clip \(webClipId)", category: .core)
            }
        } catch {
            Logger.error("Failed to update categories for web clip \(webClipId): \(error)", category: .core)
            allSuccess = false  // Continue with assignments even if categories fail
        }
        
        // Step 5: Update group assignments - always remove existing first, then add new ones if any
        do {
            // First, remove all existing group assignments to avoid conflicts
            try await EntraGraphRequests.removeAllAppAssignments(
                authToken: authToken,
                appId: webClipId
            )
            Logger.info("Successfully removed all existing group assignments from web clip \(webClipId)", category: .core)
            
            // Then, assign new group assignments if any
            if !groupAssignments.isEmpty {
                // Transform groupAssignments to the format expected by assignGroupsToApp
                let transformedAssignments = transformGroupAssignmentsForAPI(groupAssignments)
                
                if !transformedAssignments.isEmpty {
                    try await EntraGraphRequests.assignGroupsToApp(
                        authToken: authToken,
                        appId: webClipId,
                        appAssignments: transformedAssignments,
                        appType: "macOSWebClip",
                        installAsManaged: false // Web clips don't use managed installation
                    )
                    Logger.info("Successfully assigned \(transformedAssignments.count) new group assignments to web clip \(webClipId)", category: .core)
                }
            } else {
                Logger.info("No new group assignments to assign to web clip \(webClipId)", category: .core)
            }
        } catch {
            Logger.error("Failed to update group assignments for web clip \(webClipId): \(error)", category: .core)
            allSuccess = false
        }
        
        Logger.info("Completed comprehensive update workflow for web clip \(webClipId) - Success: \(allSuccess)", category: .core)
        return allSuccess
    }
    
    /// Transforms UI group assignment data to the format expected by assignGroupsToApp function
    /// - Parameter groupAssignments: Array of group assignment data from the UI
    /// - Returns: Array of assignment data formatted for assignGroupsToApp function
    private static func transformGroupAssignmentsForAPI(_ groupAssignments: [[String: Any]]) -> [[String: Any]] {
        var transformedAssignments: [[String: Any]] = []
        
        for assignment in groupAssignments {
            guard let displayName = assignment["displayName"] as? String,
                  let mode = assignment["mode"] as? String,
                  let assignmentType = assignment["assignmentType"] as? String else {
                continue
            }
            
            let isVirtual = assignment["isVirtual"] as? Bool ?? false
            var transformedAssignment: [String: Any] = [:]
            
            // Add common fields that assignGroupsToApp expects
            transformedAssignment["assignmentType"] = assignmentType
            transformedAssignment["mode"] = mode
            
            if isVirtual {
                // Handle virtual groups - assignGroupsToApp expects isVirtual as Int
                transformedAssignment["isVirtual"] = 1
                transformedAssignment["displayName"] = displayName
                
                // Virtual groups don't need an "id" field since assignGroupsToApp detects them by isVirtual + displayName
            } else {
                // Handle real groups - assignGroupsToApp expects isVirtual as Int
                transformedAssignment["isVirtual"] = 0
                
                // Use the group ID from the assignment
                guard let groupId = assignment["id"] as? String else {
                    continue
                }
                transformedAssignment["id"] = groupId
            }
            
            // Add filter if present (optional)
            if let filter = assignment["filter"] as? [String: Any] {
                transformedAssignment["filter"] = filter
            }
            
            transformedAssignments.append(transformedAssignment)
        }
        
        return transformedAssignments
    }

}
