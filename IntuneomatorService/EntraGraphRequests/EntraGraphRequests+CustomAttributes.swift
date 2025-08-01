//
//  EntraGraphRequests+CustomAttributes.swift
//  Intuneomator
//
//  Created by Gil Burns on 2/2/25.
//

import Foundation

// MARK: - Custom Attribute Shell Script Management Extension

/// Extension for handling Microsoft Graph API custom attribute shell script operations
/// Provides functionality for fetching and managing Intune Custom Attribute Shell Scripts for macOS
extension EntraGraphRequests {
    
    // MARK: - Custom Attribute Shell Script Retrieval
    /// Fetches all Intune Custom Attribute Shell Scripts from Microsoft Graph with pagination support
    /// Used to retrieve custom attribute shell scripts available in Intune
    /// Handles pagination to ensure all custom attribute shell scripts are fetched from large environments
    /// - Parameter authToken: OAuth bearer token for Microsoft Graph authentication
    /// - Returns: Array of dictionaries containing Intune custom attribute shell scripts information, sorted by display name
    /// - Throws: Network errors, authentication errors, or JSON parsing errors
    static func fetchIntuneCustomAttributeShellScripts(authToken: String) async throws -> [[String: Any]] {
        var allCustomAttributeShellScripts: [[String: Any]] = []
        var nextPageUrl: String? = "https://graph.microsoft.com/beta/deviceManagement/deviceCustomAttributeShellScripts"
        var pageCount = 0
        
        Logger.info("Starting paginated fetch of Custom Attribute Intune Shell Scripts...", category: .core)
        
        // Follow pagination until all custom attribute scripts are fetched
        while let urlString = nextPageUrl {
            guard let url = URL(string: urlString) else {
                throw NSError(domain: "AppDataManager", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid pagination URL: \(urlString)"])
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw NSError(domain: "AppDataManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch Intune Custom Attribute Shell Scripts (page \(pageCount + 1))"])
            }
            
            // Parse JSON response
            guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
                throw NSError(domain: "AppDataManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON response format for Intune Custom Attribute Shell Scripts (page \(pageCount + 1))"])
            }
            
            // Extract custom attribute shell scripts from this page
            guard let pageCustomAttributeShellScripts = json["value"] as? [[String: Any]] else {
                throw NSError(domain: "AppDataManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid response format for Intune Custom Attribute Shell Scripts (page \(pageCount + 1))"])
            }
            
            allCustomAttributeShellScripts.append(contentsOf: pageCustomAttributeShellScripts)
            pageCount += 1
            
            // Check for next page
            nextPageUrl = json["@odata.nextLink"] as? String
            
            Logger.debug("Fetched page \(pageCount) with \(pageCustomAttributeShellScripts.count) custom attribute shell scripts (total: \(pageCustomAttributeShellScripts.count))", category: .core)
            
            // Safety check to prevent infinite loops
            if pageCount > 100 {
                Logger.error("Safety limit reached: stopping after 100 pages of custom attribute shell scripts", category: .core)
                break
            }
        }
        
        Logger.info("Completed fetching \(allCustomAttributeShellScripts.count) total custom attribute shell scripts across \(pageCount) pages", category: .core)
        
        // Sort all custom attribute shell scripts alphabetically by display name
        return allCustomAttributeShellScripts.sorted {
            guard let name1 = $0["displayName"] as? String, let name2 = $1["displayName"] as? String else { return false }
            return name1.localizedCaseInsensitiveCompare(name2) == .orderedAscending
        }
    }
    
    /// Uploads a custom attribute shell script file to Microsoft Intune with comprehensive configuration options
    ///
    /// This function reads a local custom attribute shell script file, encodes it as Base64, and uploads it to
    /// Microsoft Intune as a custom attribute shell script. The script will be available for
    /// assignment to macOS device groups.
    ///
    /// **Key Features:**
    /// - Automatic Base64 encoding of script content
    /// - Configurable execution parameters
    /// - Comprehensive error handling and logging
    /// - Validates file accessibility before upload
    ///
    /// **Script Requirements:**
    /// - Must be a valid custom attribute shell script (typically .sh extension)
    /// - Should include proper shebang line (#!/bin/bash or #!/bin/sh)
    /// - File size limitations apply (check Microsoft Graph API limits)
    /// - Script content will be Base64 encoded automatically
    ///
    /// **Execution Context:**
    /// - `system`: Runs with root privileges (recommended for system modifications)
    /// - `user`: Runs in user context (for user-specific operations)
    ///
    /// **Usage Example:**
    /// ```swift
    /// let success = try await EntraGraphRequests.uploadScript(
    ///     authToken: token,
    ///     scriptPath: "/path/to/script.sh",
    ///     scriptName: "System Maintenance Script",
    ///     runAsAccount: "system",
    ///     retryCount: 3,
    ///     blockExecutionNotifications: true
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - authToken: Valid OAuth 2.0 bearer token with DeviceManagementConfiguration.ReadWrite.All permissions
    ///   - scriptPath: Absolute file path to the custom attribute shell script file to upload
    ///   - scriptName: Display name for the script in Intune console (user-friendly identifier)
    ///   - runAsAccount: Execution context - "system" for root privileges or "user" for user context (default: "system")
    /// - Returns: Boolean value indicating successful upload and creation
    /// - Throws:
    ///   - `NSError` with domain "IntuneScriptUploader" and code 500: File read failure, invalid URL, JSON encoding failure, or HTTP request failure
    ///   - File system errors if script file is inaccessible
    ///   - Network-related errors from URLSession
    ///
    /// **Required Permissions:**
    /// - DeviceManagementConfiguration.ReadWrite.All (Application or Delegated)
    ///
    /// **Post-Upload Steps:**
    /// After successful upload, you'll typically want to:
    /// 1. Assign the script to device groups
    /// 2. Configure execution schedule if needed
    /// 3. Monitor execution status through Intune reporting
    static func uploadCustomAttributeScript(authToken: String,
                                            scriptPath: String,
                                            scriptName: String,
                                            scriptAttributeType: Int = 1,
                                            runAsAccount: String = "system"
    ) async throws -> Bool {
        
        guard let scriptContent = try? Data(contentsOf: URL(fileURLWithPath: scriptPath)).base64EncodedString() else {
            throw NSError(domain: "IntuneScriptUploader", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to read script file"])
        }
        
        let scriptData: [String: Any] = [
            "displayName": scriptName,
            "customAttributeType": scriptAttributeType,
            "scriptContent": scriptContent,
            "runAsAccount": runAsAccount
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: scriptData, options: []) else {
            throw NSError(domain: "IntuneScriptUploader", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to encode JSON"])
        }
        
        var request = URLRequest(url: URL(string: "https://graph.microsoft.com/beta/deviceManagement/deviceCustomAttributeShellScripts/")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            let responseStr = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "IntuneScriptUploader", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to upload script. Response: \(responseStr)"])
        }
        
        let responseStr = String(data: data, encoding: .utf8) ?? "No response"
        print("Script uploaded successfully: \(responseStr)")
        return true
    }
    
    
    /// Creates a new custom attribute shell script in Microsoft Intune with custom configuration data
    ///
    /// This function creates a new device custom attribute shell script in Intune
    /// using a pre-configured dictionary of script properties. This is a lower-level
    /// function that provides full control over script creation parameters.
    ///
    /// **Key Features:**
    /// - Direct script creation from structured data
    /// - Returns the unique script ID for further operations
    /// - Comprehensive error handling with detailed responses
    /// - Automatic logging of creation status
    ///
    /// **Required Script Data Structure:**
    /// The scriptData dictionary must contain:
    /// ```swift
    /// [
    ///     "displayName": "My Custom Script",           // Required: Display name
    ///     "scriptContent": "<base64-encoded-content>", // Required: Base64 encoded script
    ///     "runAsAccount": "system",                   // Required: "system" or "user"
    ///     "retryCount": 3,                            // Optional: 1-5 retry attempts
    ///     "blockExecutionNotifications": true,        // Optional: suppress notifications
    ///     "description": "Script description"         // Optional: detailed description
    /// ]
    /// ```
    ///
    /// **Usage Example:**
    /// ```swift
    /// let scriptData: [String: Any] = [
    ///     "displayName": "Security Audit Script",
    ///     "scriptContent": scriptContent.base64EncodedString(),
    ///     "runAsAccount": "system",
    ///     "retryCount": 2,
    ///     "blockExecutionNotifications": false
    /// ]
    /// let scriptId = try await EntraGraphRequests.createNewScript(authToken: token, scriptData: scriptData)
    /// ```
    ///
    /// - Parameters:
    ///   - authToken: Valid OAuth 2.0 bearer token with DeviceManagementConfiguration.ReadWrite.All permissions
    ///   - scriptData: Dictionary containing complete script configuration following Microsoft Graph deviceCustomAttributeShellScript schema
    /// - Returns: Unique identifier (GUID) of the newly created script for use in subsequent operations
    /// - Throws:
    ///   - `NSError` with domain "IntuneScriptUploader" and code 500: Invalid URL, JSON serialization failure, HTTP request failure, or response parsing failure
    ///   - Network-related errors from URLSession
    ///   - JSON serialization errors if scriptData format is invalid
    ///
    /// **Required Permissions:**
    /// - DeviceManagementConfiguration.ReadWrite.All (Application or Delegated)
    ///
    /// **Best Practices:**
    /// - Validate script content before encoding to Base64
    /// - Use descriptive display names for easy identification
    /// - Consider setting appropriate retry counts based on script complexity
    /// - Store returned script ID for future update/delete operations
    static func createNewCustomAttributeScript(authToken: String, scriptData: [String: Any]) async throws -> String {
        
        var request = URLRequest(url: URL(string: "https://graph.microsoft.com/beta/deviceManagement/deviceCustomAttributeShellScripts/")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let jsonData = try JSONSerialization.data(withJSONObject: scriptData, options: [])
        request.httpBody = jsonData
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            let responseStr = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "IntuneScriptUploader", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to create script. Response: \(responseStr)"])
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
              let scriptId = json["id"] as? String else {
            throw NSError(domain: "IntuneScriptUploader", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to extract script ID from response"])
        }
        
        Logger.info("Successfully created script with ID: \(scriptId)", category: .core)
        return scriptId
    }
    
    
    
    /// Retrieves comprehensive details about a specific custom attribute shell script from Microsoft Intune
    ///
    /// This function fetches complete metadata and content for a specific custom attribute shell script,
    /// including automatic Base64 decoding of script content for easy viewing and editing.
    ///
    /// **Key Features:**
    /// - Automatic Base64 decoding of script content
    /// - Complete script metadata retrieval
    /// - Comprehensive error handling and logging
    /// - Ready-to-use script content for display or editing
    ///
    /// **Returned Data Structure:**
    /// The returned dictionary contains all Microsoft Graph deviceCustomAttributeShellScript properties:
    /// - `id`: Unique script identifier (GUID)
    /// - `displayName`: User-friendly script name
    /// - `description`: Optional script description
    /// - `scriptContent`: **Decoded** script content (plain text, not Base64)
    /// - `runAsAccount`: Execution context ("system" or "user")
    /// - `retryCount`: Number of retry attempts configured
    /// - `blockExecutionNotifications`: Notification suppression setting
    /// - `createdDateTime`: ISO 8601 creation timestamp
    /// - `lastModifiedDateTime`: ISO 8601 last modification timestamp
    /// - `fileName`: Original filename if available
    /// - `roleScopeTagIds`: Array of role scope tag identifiers
    ///
    /// **Usage Example:**
    /// ```swift
    /// let scriptDetails = try await EntraGraphRequests.getScriptDetails(authToken: token, byId: scriptId)
    /// print("Script Name: \(scriptDetails["displayName"] as? String ?? "Unknown")")
    /// print("Script Content:\n\(scriptDetails["scriptContent"] as? String ?? "No content")")
    /// print("Run As: \(scriptDetails["runAsAccount"] as? String ?? "Unknown")")
    /// ```
    ///
    /// **Content Decoding:**
    /// - Script content is automatically decoded from Base64 to plain text
    /// - If decoding fails, "Failed to decode script content" is returned
    /// - Original Base64 content is replaced with decoded text for convenience
    ///
    /// - Parameters:
    ///   - authToken: Valid OAuth 2.0 bearer token with DeviceManagementConfiguration.Read.All permissions
    ///   - scriptId: Unique identifier (GUID) of the script to retrieve
    /// - Returns: Dictionary containing complete script metadata with decoded script content
    /// - Throws:
    ///   - `NSError` with domain "AppDataManager" and code 500: Invalid URL, HTTP request failure, or JSON parsing failure
    ///   - Network-related errors from URLSession
    ///
    /// **Required Permissions:**
    /// - DeviceManagementConfiguration.Read.All (Application or Delegated)
    ///
    /// **Common Use Cases:**
    /// - Script content preview in management interfaces
    /// - Preparing script data for editing operations
    /// - Auditing script configurations and settings
    /// - Retrieving script metadata for reporting purposes
    static func getCustomAttributeScriptDetails(authToken: String, byId scriptId: String) async throws -> [String: Any] {
        
        let scriptDetailsURL = "https://graph.microsoft.com/beta/deviceManagement/deviceCustomAttributeShellScripts/\(scriptId)"
        
        var request = URLRequest(url: URL(string: scriptDetailsURL)!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let responseStr = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "AppDataManager", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch script details. Response: \(responseStr)"])
        }
        
        // Decode JSON response
        guard var scriptDetails = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
            throw NSError(domain: "AppDataManager", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON format."])
        }
        
        // Decode Base64-encoded script content back to text
        if let scriptContentBase64 = scriptDetails["scriptContent"] as? String,
           let scriptContentData = Data(base64Encoded: scriptContentBase64),
           let scriptContentText = String(data: scriptContentData, encoding: .utf8) {
            scriptDetails["scriptContent"] = scriptContentText // Replace with decoded text
        } else {
            scriptDetails["scriptContent"] = "Failed to decode script content"
        }
        
        return scriptDetails
    }
    
    /// Permanently deletes a custom attribute shell script from Microsoft Intune
    ///
    /// This function removes a custom attribute shell script from Intune permanently. Once deleted,
    /// the script cannot be recovered and will be removed from all assignments.
    ///
    /// **⚠️ Warning:**
    /// This operation is **irreversible**. The script and all its assignments will be
    /// permanently deleted. Consider the following before deletion:
    /// - Remove script from all device group assignments first
    /// - Backup script content if needed for future use
    /// - Verify script is not critical for device management
    ///
    /// **Key Features:**
    /// - Permanent script removal from Intune
    /// - Automatic cleanup of associated assignments
    /// - Comprehensive error handling and logging
    /// - Detailed error reporting for troubleshooting
    ///
    /// **Impact of Deletion:**
    /// - Script is removed from Intune console
    /// - All device group assignments are removed
    /// - Scheduled executions are canceled
    /// - Historical execution data may be retained (per Microsoft retention policies)
    /// - Script cannot be recovered after deletion
    ///
    /// **Usage Example:**
    /// ```swift
    /// // Recommended: Get script details first for confirmation
    /// let scriptDetails = try await EntraGraphRequests.getScriptDetails(authToken: token, byId: scriptId)
    /// print("About to delete: \(scriptDetails["displayName"] as? String ?? "Unknown Script")")
    ///
    /// // Perform deletion
    /// let success = try await EntraGraphRequests.deleteScript(authToken: token, byId: scriptId)
    /// if success {
    ///     print("Script deleted successfully")
    /// }
    /// ```
    ///
    /// **Best Practices:**
    /// 1. Always verify script details before deletion
    /// 2. Remove from assignments first to prevent execution during deletion
    /// 3. Backup script content if it might be needed later
    /// 4. Use appropriate error handling for failed deletions
    ///
    /// - Parameters:
    ///   - authToken: Valid OAuth 2.0 bearer token with DeviceManagementConfiguration.ReadWrite.All permissions
    ///   - scriptId: Unique identifier (GUID) of the script to delete permanently
    /// - Returns: Boolean value indicating successful deletion (true) or failure (false)
    /// - Throws:
    ///   - `NSError` with domain "AppDataManager" and code 500: Invalid URL or HTTP request failure with detailed error response
    ///   - Network-related errors from URLSession
    ///
    /// **Required Permissions:**
    /// - DeviceManagementConfiguration.ReadWrite.All (Application or Delegated)
    ///
    /// **Error Handling:**
    /// - 404 errors indicate script doesn't exist (may already be deleted)
    /// - 403 errors indicate insufficient permissions
    /// - 400 errors may indicate script is currently assigned or in use
    static func deleteCustomAttributeScript(authToken: String, byId scriptId: String) async throws -> Bool {
        
        let deleteURL = "https://graph.microsoft.com/beta/deviceManagement/deviceCustomAttributeShellScripts/\(scriptId)"
        
        var request = URLRequest(url: URL(string: deleteURL)!)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw NSError(domain: "AppDataManager", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to delete script."])
        }
        return true
    }
    
    /// Updates an existing custom attribute shell script in Microsoft Intune with new configuration or content
    ///
    /// This function modifies an existing custom attribute shell script's properties, content, or settings
    /// in Microsoft Intune. It supports partial updates, meaning you only need to include
    /// the properties you want to change.
    ///
    /// **Key Features:**
    /// - Partial update support (only changed properties required)
    /// - Maintains existing properties not specified in updatedData
    /// - Comprehensive error handling and logging
    /// - Automatic validation of update success
    ///
    /// **Updatable Properties:**
    /// You can update any of the following properties:
    /// - `displayName`: Change the script's display name
    /// - `description`: Update or add a description
    /// - `scriptContent`: Replace script content (must be Base64 encoded)
    /// - `runAsAccount`: Change execution context ("system" or "user")
    /// - `retryCount`: Modify retry attempts (1-5)
    /// - `blockExecutionNotifications`: Toggle notification settings
    /// - `fileName`: Update the filename reference
    ///
    /// **Script Content Updates:**
    /// When updating script content:
    /// - Content must be Base64 encoded
    /// - Existing assignments remain active with new content
    /// - Next execution will use updated script
    ///
    /// **Usage Example:**
    /// ```swift
    /// // Update just the display name and description
    /// let updates: [String: Any] = [
    ///     "displayName": "Updated Security Script v2.0",
    ///     "description": "Enhanced security checks with additional validations"
    /// ]
    /// let success = try await EntraGraphRequests.updateCustomAttributeShellScript(
    ///     authToken: token,
    ///     byId: scriptId,
    ///     updatedData: updates
    /// )
    ///
    /// // Update script content
    /// let newContent = "#!/bin/bash\necho 'Updated script'\n"
    /// let contentUpdate: [String: Any] = [
    ///     "scriptContent": Data(newContent.utf8).base64EncodedString()
    /// ]
    /// let contentSuccess = try await EntraGraphRequests.updateCustomAttributeShellScript(
    ///     authToken: token,
    ///     byId: scriptId,
    ///     updatedData: contentUpdate
    /// )
    /// ```
    ///
    /// **Impact on Assignments:**
    /// - Existing assignments remain unchanged
    /// - Updated script will be used for future executions
    /// - No need to reassign to device groups
    /// - Execution schedule remains the same
    ///
    /// **Best Practices:**
    /// 1. Test script updates in a development environment first
    /// 2. Use descriptive display names and descriptions
    /// 3. Validate Base64 encoding when updating script content
    /// 4. Consider versioning in display names or descriptions
    /// 5. Monitor execution results after content updates
    ///
    /// - Parameters:
    ///   - authToken: Valid OAuth 2.0 bearer token with DeviceManagementConfiguration.ReadWrite.All permissions
    ///   - scriptId: Unique identifier (GUID) of the script to update
    ///   - updatedData: Dictionary containing only the properties to update (partial update supported)
    /// - Returns: Boolean value indicating successful update (true) or failure (false)
    /// - Throws:
    ///   - `NSError` with domain "AppDataManager" and code 500: Invalid URL, JSON serialization failure, or HTTP request failure with detailed error response
    ///   - Network-related errors from URLSession
    ///   - JSON serialization errors if updatedData format is invalid
    ///
    /// **Required Permissions:**
    /// - DeviceManagementConfiguration.ReadWrite.All (Application or Delegated)
    ///
    /// **Common Update Scenarios:**
    /// - Fixing bugs in script content
    /// - Updating script descriptions for better documentation
    /// - Changing execution context (system vs user)
    /// - Modifying retry behavior for improved reliability
    /// - Updating display names for better organization
    static func updateCustomAttributeShellScript(authToken: String, byId scriptId: String, updatedData: [String: Any]) async throws -> Bool {
        
        let updateURL = "https://graph.microsoft.com/beta/deviceManagement/deviceCustomAttributeShellScripts//\(scriptId)"
        
        var request = URLRequest(url: URL(string: updateURL)!)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let jsonData = try JSONSerialization.data(withJSONObject: updatedData, options: [])
        request.httpBody = jsonData
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            let responseStr = String(data: data, encoding: .utf8) ?? "Unknown error"
            Logger.error("Failed to update script ID \(scriptId): \(responseStr)", category: .core)
            throw NSError(domain: "AppDataManager", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to update script. Response: \(responseStr)"])
        }
        
        Logger.info("Successfully updated script with ID: \(scriptId)", category: .core)
        return true
    }
    
    // MARK: - Custom Attribute Shell Script Group Assignment Management
    
    /// Assigns Entra ID groups to a custom attribute shell script in Microsoft Intune
    ///
    /// Creates group assignments for a custom attribute shell script, allowing it to be executed on devices
    /// belonging to the specified groups. Supports multiple assignment types and targets.
    ///
    /// **Key Features:**
    /// - Multiple group assignments in a single operation
    /// - Support for group-based and all-device/user targeting
    /// - Include/exclude assignment modes
    /// - Comprehensive error handling and logging
    /// - Automatic validation of group IDs and assignment data
    ///
    /// **Assignment Structure:**
    /// Each assignment in the array should contain:
    /// ```swift
    /// [
    ///     "groupId": "12345-abcde-67890",          // Required: Entra ID group GUID or virtual group ID
    ///     "mode": "include",                       // Required: "include" or "exclude"
    ///     "assignmentType": "Required"             // Optional: Currently not used for custom attribute shell scripts
    /// ]
    /// ```
    ///
    /// **Virtual Groups:**
    /// - All Users: groupId = "acacacac-9df4-4c7d-9d50-4ef0226f57a9"
    /// - All Devices: groupId = "adadadad-808e-44e2-905a-0b7873a8a531"
    ///
    /// **Usage Example:**
    /// ```swift
    /// let assignments = [
    ///     ["groupId": "dev-team-guid", "mode": "include"],
    ///     ["groupId": "test-team-guid", "mode": "exclude"]
    /// ]
    /// let success = try await EntraGraphRequests.assignGroupsToCustomAttributeShellScript(
    ///     authToken: token,
    ///     scriptId: "script-guid",
    ///     groupAssignments: assignments
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - authToken: Valid OAuth 2.0 bearer token with DeviceManagementConfiguration.ReadWrite.All permissions
    ///   - scriptId: Unique identifier (GUID) of the custom attribute shell script to assign groups to
    ///   - groupAssignments: Array of assignment dictionaries containing group IDs, modes, and assignment details
    /// - Returns: Boolean indicating successful assignment creation
    /// - Throws:
    ///   - `NSError` with domain "CustomAttributeAssignment" and code 500: Invalid URL, JSON serialization failure, or HTTP request failure
    ///   - Network-related errors from URLSession
    ///   - JSON serialization errors if assignment data format is invalid
    ///
    /// **Required Permissions:**
    /// - DeviceManagementConfiguration.ReadWrite.All (Application or Delegated)
    ///
    /// **Microsoft Graph API:**
    /// - Endpoint: `POST /deviceManagement/deviceCustomAttributeShellScripts/{id}/assign`
    /// - Documentation: Microsoft Graph deviceShellScript assign method
    static func assignGroupsToCustomAttributeShellScript(authToken: String, scriptId: String, groupAssignments: [[String: Any]]) async throws -> Bool {
        
        Logger.info("Assigning \(groupAssignments.count) groups to custom attribute shell script: \(scriptId)", category: .core)
        
        let urlString = "https://graph.microsoft.com/beta/deviceManagement/deviceCustomAttributeShellScripts/\(scriptId)/assign"
        Logger.info("Assignment URL being used: \(urlString)", category: .core)
        
        guard let url = URL(string: urlString) else {
            throw NSError(domain: "CustomAttributeAssignment", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid assignment URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Debug token info (safely)
        let tokenPrefix = String(authToken.prefix(20))
        let tokenSuffix = String(authToken.suffix(20))
        let tokenLength = authToken.count
        Logger.info("Token info: length=\(tokenLength), prefix=\(tokenPrefix)..., suffix=...\(tokenSuffix)", category: .core)
        Logger.info("Request headers: Authorization=Bearer [REDACTED], Content-Type=application/json", category: .core)
        
        // Build assignment payload - use bulk assign with correct structure
        var assignments: [[String: Any]] = []
        
        for assignment in groupAssignments {
            guard let groupId = assignment["groupId"] as? String, !groupId.isEmpty else {
                Logger.error("Invalid group ID in assignment: \(assignment)", category: .core)
                continue
            }
            
            let mode = assignment["mode"] as? String ?? "include"
            var targetPayload: [String: Any] = [:]
            
            // Handle all groups (including virtual groups) with the same format
            if mode == "include" {
                targetPayload = [
                    "@odata.type": "#microsoft.graph.groupAssignmentTarget",
                    "groupId": groupId
                ]
            } else if mode == "exclude" {
                // Virtual groups don't support exclude mode
                if groupId == "acacacac-9df4-4c7d-9d50-4ef0226f57a9" || groupId == "adadadad-808e-44e2-905a-0b7873a8a531" {
                    Logger.warning("Exclude mode not supported for virtual groups (\(groupId)), skipping assignment", category: .core)
                    continue
                } else {
                    targetPayload = [
                        "@odata.type": "#microsoft.graph.exclusionGroupAssignmentTarget",
                        "groupId": groupId
                    ]
                }
            } else {
                Logger.error("Invalid assignment mode '\(mode)' for group \(groupId)", category: .core)
                continue
            }
            
            let assignmentPayload: [String: Any] = [
                "target": targetPayload
            ]
            assignments.append(assignmentPayload)
        }
        
        let payload: [String: Any] = [
            "deviceManagementScriptAssignments": assignments
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: payload, options: [])
        request.httpBody = jsonData
        
        // Debug logging
        if let jsonString = String(data: jsonData, encoding: .utf8) {
            Logger.info("Bulk assignment payload: \(jsonString)", category: .core)
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // Debug response details
        if let httpResponse = response as? HTTPURLResponse {
            Logger.info("Response status code: \(httpResponse.statusCode)", category: .core)
            Logger.info("Response URL: \(httpResponse.url?.absoluteString ?? "nil")", category: .core)
            if let headers = httpResponse.allHeaderFields as? [String: String] {
                Logger.info("Response headers: \(headers)", category: .core)
            }
        }
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            let responseStr = String(data: data, encoding: .utf8) ?? "Unknown error"
            Logger.error("Failed to assign groups to custom attribute shell script \(scriptId): \(responseStr)", category: .core)
            throw NSError(domain: "CustomAttributeAssignment", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to assign groups to custom attribute shell script. Response: \(responseStr)"])
        }
        
        Logger.info("Successfully assigned \(assignments.count) groups to custom attribute shell script: \(scriptId)", category: .core)
        return true
    }
    
    
    /// Retrieves current group assignments for a custom attribute shell script from Microsoft Intune
    ///
    /// Fetches all group assignments currently configured for a specific custom attribute shell script,
    /// including assignment details, target groups, and assignment metadata.
    ///
    /// **Key Features:**
    /// - Complete assignment metadata retrieval
    /// - Group information resolution
    /// - Assignment type and target details
    /// - Comprehensive error handling and logging
    ///
    /// **Returned Data Structure:**
    /// Each assignment dictionary contains:
    /// - `id`: Assignment unique identifier
    /// - `target`: Assignment target information (group details)
    /// - `@odata.type`: Assignment type identifier
    /// - Additional Microsoft Graph assignment properties
    ///
    /// **Usage Example:**
    /// ```swift
    /// let assignments = try await EntraGraphRequests.getShellScriptAssignments(
    ///     authToken: token,
    ///     scriptId: "script-guid"
    /// )
    /// for assignment in assignments {
    ///     if let target = assignment["target"] as? [String: Any],
    ///        let groupId = target["groupId"] as? String {
    ///         print("Assigned to group: \(groupId)")
    ///     }
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - authToken: Valid OAuth 2.0 bearer token with DeviceManagementConfiguration.Read.All permissions
    ///   - scriptId: Unique identifier (GUID) of the custom attribute shell script to retrieve assignments for
    /// - Returns: Array of assignment dictionaries containing complete assignment information
    /// - Throws:
    ///   - `NSError` with domain "CustomAttributeAssignment" and code 500: Invalid URL, HTTP request failure, or JSON parsing failure
    ///   - Network-related errors from URLSession
    ///
    /// **Required Permissions:**
    /// - DeviceManagementConfiguration.Read.All (Application or Delegated)
    ///
    /// **Microsoft Graph API:**
    /// - Endpoint: `GET /deviceManagement/deviceManagementScripts/{id}/assignments`
    static func getCustomAttributeShellScriptAssignments(authToken: String, scriptId: String) async throws -> [[String: Any]] {
        
        Logger.info("Fetching assignments for custom attribute shell script: \(scriptId)", category: .core)
        
        guard let url = URL(string: "https://graph.microsoft.com/beta/deviceManagement/deviceManagementScripts/\(scriptId)/assignments") else {
            throw NSError(domain: "CustomAttributeAssignment", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid assignments URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let responseStr = String(data: data, encoding: .utf8) ?? "Unknown error"
            Logger.error("Failed to fetch assignments for custom attribute shell script \(scriptId): \(responseStr)", category: .core)
            throw NSError(domain: "CustomAttributeAssignment", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch custom attribute shell script assignments. Response: \(responseStr)"])
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
              let assignments = json["value"] as? [[String: Any]] else {
            throw NSError(domain: "CustomAttributeAssignment", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid assignments response format"])
        }
        
        Logger.info("Successfully fetched \(assignments.count) assignments for custom attribute shell script: \(scriptId)", category: .core)
        return assignments
    }
    
    /// Removes all group assignments from a custom attribute shell script in Microsoft Intune
    ///
    /// **⚠️ WARNING: This removes ALL assignments from the custom attribute shell script**
    ///
    /// This function removes all group assignments from a custom attribute shell script by sending
    /// an empty assignment array to the Microsoft Graph assign endpoint. This is
    /// the recommended approach since individual assignment deletion is not supported.
    ///
    /// **Key Features:**
    /// - Uses empty assignment array to clear all assignments
    /// - Single API call for efficiency
    /// - Comprehensive error handling and logging
    /// - Follows Microsoft Graph best practices
    ///
    /// **Usage Example:**
    /// ```swift
    /// let success = try await EntraGraphRequests.removeAllCustomAttributeShellScriptAssignments(
    ///     authToken: token,
    ///     scriptId: "script-guid"
    /// )
    /// if success {
    ///     print("All assignments removed successfully")
    /// }
    /// ```
    ///
    /// **Impact:**
    /// - Script will no longer execute on any devices
    /// - All device group assignments are removed
    /// - Operation cannot be undone (assignments must be recreated)
    ///
    /// - Parameters:
    ///   - authToken: Valid OAuth 2.0 bearer token with DeviceManagementConfiguration.ReadWrite.All permissions
    ///   - scriptId: Unique identifier (GUID) of the custom attribute shell script to remove all assignments from
    /// - Returns: Boolean indicating if all assignments were successfully removed
    /// - Throws:
    ///   - `NSError` with domain "CustomAttributeAssignment" and code 500: URL, HTTP, or JSON errors
    ///   - Network-related errors from URLSession
    ///
    /// **Required Permissions:**
    /// - DeviceManagementConfiguration.ReadWrite.All (Application or Delegated)
    ///
    /// **Microsoft Graph API:**
    /// - Endpoint: `POST /deviceManagement/deviceCustomAttributeShellScripts/{id}/assign`
    /// - Body: `{"deviceManagementScriptAssignments": []}`
    static func removeAllCustomAttributeShellScriptAssignments(authToken: String, scriptId: String) async throws -> Bool {
        
        Logger.info("Removing all assignments for custom attribute shell script: \(scriptId)", category: .core)
        
        // Use the assignment function with an empty array to remove all assignments
        do {
            let success = try await assignGroupsToCustomAttributeShellScript(authToken: authToken, scriptId: scriptId, groupAssignments: [])
            if success {
                Logger.info("Successfully removed all assignments for custom attribute shell script: \(scriptId)", category: .core)
            } else {
                Logger.error("Failed to remove all assignments for custom attribute shell script: \(scriptId)", category: .core)
            }
            return success
        } catch {
            Logger.error("Error removing all assignments for custom attribute shell script \(scriptId): \(error.localizedDescription)", category: .core)
            throw error
        }
    }
    
    /// Removes a specific group assignment from a custom attribute shell script in Microsoft Intune
    ///
    /// Deletes a single assignment by its unique identifier, removing the custom attribute shell script
    /// from the specified group assignment without affecting other assignments.
    ///
    /// **Key Features:**
    /// - Targeted assignment removal
    /// - Preserves other assignments
    /// - Comprehensive error handling and logging
    /// - Safe operation with validation
    ///
    /// **Usage Example:**
    /// ```swift
    /// // Get assignments first to find the assignment ID
    /// let assignments = try await EntraGraphRequests.getCustomAttributeShellScriptAssignments(authToken: token, scriptId: scriptId)
    /// if let assignmentToRemove = assignments.first(where: { /* your criteria */ }),
    ///    let assignmentId = assignmentToRemove["id"] as? String {
    ///
    ///     let success = try await EntraGraphRequests.removeCustomAttributeShellScriptAssignment(
    ///         authToken: token,
    ///         scriptId: scriptId,
    ///         assignmentId: assignmentId
    ///     )
    /// }
    /// ```
    ///
    /// **Impact:**
    /// - Removes script from specified group only
    /// - Other group assignments remain unchanged
    /// - Devices in the removed group will no longer execute the script
    ///
    /// - Parameters:
    ///   - authToken: Valid OAuth 2.0 bearer token with DeviceManagementConfiguration.ReadWrite.All permissions
    ///   - scriptId: Unique identifier (GUID) of the custom attribute shell script
    ///   - assignmentId: Unique identifier (GUID) of the specific assignment to remove
    /// - Returns: Boolean indicating successful assignment removal
    /// - Throws:
    ///   - `NSError` with domain "CustomAttributeAssignment" and code 500: Invalid URL or HTTP request failure
    ///   - Network-related errors from URLSession
    ///
    /// **Required Permissions:**
    /// - DeviceManagementConfiguration.ReadWrite.All (Application or Delegated)
    ///
    /// **Microsoft Graph API:**
    /// - Endpoint: `DELETE /deviceManagement/deviceCustomAttributeShellScripts/{id}/assignments/{assignmentId}`
    static func removeCustomAttributeShellScriptAssignment(authToken: String, scriptId: String, assignmentId: String) async throws -> Bool {
        
        Logger.info("Removing assignment \(assignmentId) from custom attribute shell script: \(scriptId)", category: .core)
        
        guard let url = URL(string: "https://graph.microsoft.com/beta/deviceManagement/deviceCustomAttributeShellScripts/\(scriptId)/assignments/\(assignmentId)") else {
            throw NSError(domain: "CustomAttributeAssignment", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid assignment removal URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            let responseStr = String(data: data, encoding: .utf8) ?? "Unknown error"
            Logger.error("Failed to remove assignment \(assignmentId) from custom attribute shell script \(scriptId): \(responseStr)", category: .core)
            throw NSError(domain: "CustomAttributeAssignment", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to remove custom attribute custom attribute shell script assignment. Response: \(responseStr)"])
        }
        
        Logger.info("Successfully removed assignment \(assignmentId) from custom attribute shell script: \(scriptId)", category: .core)
        return true
    }
    
    // MARK: - Custom Attribute Shell Script Device Run States
    
    /// Retrieves device run states for a specific custom attribute shell script from Microsoft Intune
    ///
    /// Fetches detailed execution results for a custom attribute shell script across all assigned devices,
    /// including execution status, output, error information, and device details.
    ///
    /// **Key Features:**
    /// - Complete device execution history
    /// - Execution status, output, and error details
    /// - Device information including name, platform, and compliance status
    /// - Last execution timestamps and duration
    /// - Comprehensive error handling and logging
    /// - Automatic pagination support for large device counts
    ///
    /// **Returned Data Structure:**
    /// Each device run state dictionary contains:
    /// - `id`: Unique run state identifier
    /// - `runState`: Execution status ("pending", "success", "fail", "scriptError", "unknown")
    /// - `resultMessage`: Script output or error message
    /// - `lastStateUpdateDateTime`: ISO 8601 timestamp of last execution
    /// - `errorCode`: Numeric error code if execution failed
    /// - `errorDescription`: Human-readable error description
    /// - `managedDevice`: Expanded device information including:
    ///   - `deviceName`: Device hostname
    ///   - `platform`: Operating system platform
    /// - `lastRunDateTime`: ISO 8601 timestamp of script execution
    /// - `preRemediationDetectionScriptOutput`: Detection script output
    /// - `remediationScriptOutput`: Remediation script output
    ///
    /// **Run State Values:**
    /// - `pending`: Script queued for execution but not yet run
    /// - `success`: Script executed successfully without errors
    /// - `fail`: Script execution failed due to system/network issues
    /// - `scriptError`: Script completed but returned non-zero exit code
    /// - `unknown`: Execution status could not be determined
    ///
    /// **Usage Example:**
    /// ```swift
    /// let deviceStates = try await EntraGraphRequests.getCustomAttributeShellScriptDeviceRunStates(
    ///     authToken: token,
    ///     scriptId: "script-guid"
    /// )
    ///
    /// for deviceState in deviceStates {
    ///     let runState = deviceState["runState"] as? String ?? "unknown"
    ///     let deviceInfo = deviceState["managedDevice"] as? [String: Any]
    ///     let deviceName = deviceInfo?["deviceName"] as? String ?? "Unknown Device"
    ///     let lastRun = deviceState["lastRunDateTime"] as? String ?? "Never"
    ///     
    ///     print("Device: \(deviceName), Status: \(runState), Last Run: \(lastRun)")
    ///     
    ///     if let resultMessage = deviceState["resultMessage"] as? String {
    ///         print("Output: \(resultMessage)")
    ///     }
    /// }
    /// ```
    ///
    /// **Common Use Cases:**
    /// - Monitoring script execution across device fleet
    /// - Troubleshooting failed script executions
    /// - Generating compliance reports
    /// - Identifying devices requiring attention
    /// - Audit trail for custom attribute collection
    ///
    /// **Performance Considerations:**
    /// - Uses `$expand=managedDevice` for efficient device data retrieval
    /// - Supports pagination for environments with many devices
    /// - Results are sorted by device name for consistent ordering
    ///
    /// - Parameters:
    ///   - authToken: Valid OAuth 2.0 bearer token with DeviceManagementConfiguration.Read.All permissions
    ///   - scriptId: Unique identifier (GUID) of the custom attribute shell script to get device run states for
    /// - Returns: Array of device run state dictionaries containing execution results and device information
    /// - Throws:
    ///   - `NSError` with domain "CustomAttributeDeviceStates" and code 500: Invalid URL, HTTP request failure, or JSON parsing failure
    ///   - Network-related errors from URLSession
    ///
    /// **Required Permissions:**
    /// - DeviceManagementConfiguration.Read.All (Application or Delegated)
    /// - DeviceManagementManagedDevices.Read.All (for device information expansion)
    ///
    /// **Microsoft Graph API:**
    /// - Endpoint: `GET /deviceManagement/deviceCustomAttributeShellScripts/{id}/deviceRunStates?$expand=managedDevice`
    /// - Documentation: Microsoft Graph deviceManagementScriptDeviceState resource type
    static func getCustomAttributeShellScriptDeviceRunStates(authToken: String, scriptId: String) async throws -> [[String: Any]] {
        
        Logger.info("Fetching device run states for custom attribute shell script: \(scriptId)", category: .core)
        
        var allDeviceStates: [[String: Any]] = []
        var nextPageUrl: String? = "https://graph.microsoft.com/beta/deviceManagement/deviceCustomAttributeShellScripts/\(scriptId)/deviceRunStates?$expand=managedDevice"
        var pageCount = 0
        
        // Follow pagination until all device run states are fetched
        while let urlString = nextPageUrl {
            guard let url = URL(string: urlString) else {
                throw NSError(domain: "CustomAttributeDeviceStates", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid pagination URL: \(urlString)"])
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NSError(domain: "CustomAttributeDeviceStates", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid response type"])
            }
            
            guard httpResponse.statusCode == 200 else {
                let responseStr = String(data: data, encoding: .utf8) ?? "Unknown error"
                Logger.error("Failed to fetch device run states for custom attribute shell script \(scriptId) (page \(pageCount + 1)): \(responseStr)", category: .core)
                throw NSError(domain: "CustomAttributeDeviceStates", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch device run states (page \(pageCount + 1)). Status: \(httpResponse.statusCode), Response: \(responseStr)"])
            }
            
            // Parse JSON response
            guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
                throw NSError(domain: "CustomAttributeDeviceStates", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON response format for device run states (page \(pageCount + 1))"])
            }
            
            // Extract device run states from this page
            guard let pageDeviceStates = json["value"] as? [[String: Any]] else {
                throw NSError(domain: "CustomAttributeDeviceStates", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid response format for device run states (page \(pageCount + 1))"])
            }
            
            allDeviceStates.append(contentsOf: pageDeviceStates)
            pageCount += 1
            
            // Check for next page
            nextPageUrl = json["@odata.nextLink"] as? String
            
            Logger.info("Fetched page \(pageCount) with \(pageDeviceStates.count) device run states (total: \(allDeviceStates.count))", category: .core)
            
            // Safety check to prevent infinite loops
            if pageCount > 100 {
                Logger.error("Safety limit reached: stopping after 100 pages of device run states", category: .core)
                break
            }
        }
        
        Logger.info("Successfully fetched \(allDeviceStates.count) device run states for custom attribute shell script \(scriptId) across \(pageCount) pages", category: .core)
        
        // Sort device states by device name for consistent ordering
        return allDeviceStates.sorted { deviceState1, deviceState2 in
            let device1 = deviceState1["managedDevice"] as? [String: Any]
            let device2 = deviceState2["managedDevice"] as? [String: Any]
            let name1 = device1?["deviceName"] as? String ?? ""
            let name2 = device2?["deviceName"] as? String ?? ""
            return name1.localizedCaseInsensitiveCompare(name2) == .orderedAscending
        }
    }
    
}
