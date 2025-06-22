//
//  XPCManager+ShellScripts.swift
//  Intuneomator
//
//  Created by Gil Burns on 6/22/25.
//

import Foundation

/// XPCManager extension for Microsoft Intune Shell Script management
/// Provides GUI access to shell script operations through the privileged XPC service
/// All operations require valid authentication credentials and appropriate Microsoft Graph permissions
extension XPCManager {
    
    // MARK: - Intune Shell Script Management Operations
    
    /// Retrieves all Intune Shell Scripts from Microsoft Graph with comprehensive pagination support
    /// 
    /// This function fetches all macOS shell scripts configured in Microsoft Intune by following
    /// pagination links until complete data retrieval. Designed for large environments with
    /// hundreds of scripts.
    /// 
    /// **Usage Example:**
    /// ```swift
    /// XPCManager.shared.fetchIntuneShellScripts { scripts in
    ///     if let scripts = scripts {
    ///         print("Found \(scripts.count) shell scripts")
    ///         for script in scripts {
    ///             print("- \(script["displayName"] as? String ?? "Unknown")")
    ///         }
    ///     } else {
    ///         print("Failed to fetch shell scripts")
    ///     }
    /// }
    /// ```
    /// 
    /// **Required Permissions:**
    /// - DeviceManagementConfiguration.Read.All (Application or Delegated)
    /// 
    /// - Parameter completion: Callback with array of shell script dictionaries (sorted by display name) or nil on failure
    func fetchIntuneShellScripts(completion: @escaping ([[String: Any]]?) -> Void) {
        sendRequest({ $0.fetchIntuneShellScripts(reply: $1) }, completion: completion)
    }
    
    /// Uploads a shell script file to Microsoft Intune with comprehensive configuration options
    /// 
    /// This function reads a local shell script file, validates it, encodes as Base64, and creates
    /// a managed device shell script in Microsoft Intune. The script becomes available for
    /// assignment to macOS device groups.
    /// 
    /// **Key Features:**
    /// - Automatic file validation and Base64 encoding
    /// - Configurable execution parameters
    /// - Comprehensive error handling
    /// - Support for both system and user execution contexts
    /// 
    /// **Usage Example:**
    /// ```swift
    /// XPCManager.shared.uploadShellScript(
    ///     scriptPath: "/path/to/maintenance.sh",
    ///     scriptName: "System Maintenance Script",
    ///     runAsAccount: "system",
    ///     retryCount: 3,
    ///     blockExecutionNotifications: true
    /// ) { success in
    ///     if success {
    ///         print("Script uploaded successfully")
    ///     } else {
    ///         print("Failed to upload script")
    ///     }
    /// }
    /// ```
    /// 
    /// **Required Permissions:**
    /// - DeviceManagementConfiguration.ReadWrite.All (Application or Delegated)
    /// 
    /// - Parameters:
    ///   - scriptPath: Absolute file path to the shell script file to upload
    ///   - scriptName: Display name for the script in Intune console (user-friendly identifier)
    ///   - runAsAccount: Execution context - "system" for root privileges or "user" for user context
    ///   - retryCount: Number of retry attempts if script execution fails (1-5)
    ///   - blockExecutionNotifications: Whether to suppress execution notifications to end users
    ///   - completion: Callback indicating if upload was successful
    func uploadShellScript(scriptPath: String, scriptName: String, runAsAccount: String, retryCount: Int, blockExecutionNotifications: Bool, completion: @escaping (Bool) -> Void) {
        sendRequest({ service, reply in
            service.uploadShellScript(
                scriptPath: scriptPath,
                scriptName: scriptName,
                runAsAccount: runAsAccount,
                retryCount: retryCount,
                blockExecutionNotifications: blockExecutionNotifications,
                reply: reply
            )
        }, completion: completion)
    }
    
    /// Creates a new shell script in Microsoft Intune with custom configuration data
    /// 
    /// This function provides direct script creation using a pre-configured dictionary
    /// of script properties. Offers full control over script creation parameters for
    /// advanced use cases.
    /// 
    /// **Script Data Structure:**
    /// ```swift
    /// let scriptData: [String: Any] = [
    ///     "displayName": "Custom Security Script",
    ///     "scriptContent": Data(scriptContent.utf8).base64EncodedString(),
    ///     "runAsAccount": "system",
    ///     "retryCount": 2,
    ///     "blockExecutionNotifications": false,
    ///     "description": "Performs security auditing and compliance checks"
    /// ]
    /// ```
    /// 
    /// **Usage Example:**
    /// ```swift
    /// XPCManager.shared.createNewShellScript(scriptData: scriptData) { scriptId in
    ///     if let scriptId = scriptId {
    ///         print("Script created with ID: \(scriptId)")
    ///         // Now you can assign to device groups using the scriptId
    ///     } else {
    ///         print("Failed to create script")
    ///     }
    /// }
    /// ```
    /// 
    /// **Required Permissions:**
    /// - DeviceManagementConfiguration.ReadWrite.All (Application or Delegated)
    /// 
    /// - Parameters:
    ///   - scriptData: Dictionary containing complete script configuration following Microsoft Graph deviceShellScript schema
    ///   - completion: Callback with the unique script ID (GUID) or nil on failure
    func createNewShellScript(scriptData: [String: Any], completion: @escaping (String?) -> Void) {
        sendRequest({ service, reply in
            service.createNewShellScript(scriptData: scriptData, reply: reply)
        }, completion: completion)
    }
    
    /// Retrieves comprehensive details about a specific shell script from Microsoft Intune
    /// 
    /// This function fetches complete metadata and content for a specific shell script,
    /// including automatic Base64 decoding of script content for easy viewing and editing.
    /// Perfect for script management interfaces and editing workflows.
    /// 
    /// **Returned Data:**
    /// - Complete Microsoft Graph deviceShellScript properties
    /// - Automatically decoded script content (plain text, not Base64)
    /// - Creation and modification timestamps
    /// - Execution configuration settings
    /// 
    /// **Usage Example:**
    /// ```swift
    /// XPCManager.shared.getShellScriptDetails(scriptId: "12345-abcde-67890") { details in
    ///     if let details = details {
    ///         print("Script: \(details["displayName"] as? String ?? "Unknown")")
    ///         print("Content:\n\(details["scriptContent"] as? String ?? "No content")")
    ///         print("Run as: \(details["runAsAccount"] as? String ?? "Unknown")")
    ///     } else {
    ///         print("Failed to fetch script details")
    ///     }
    /// }
    /// ```
    /// 
    /// **Required Permissions:**
    /// - DeviceManagementConfiguration.Read.All (Application or Delegated)
    /// 
    /// - Parameters:
    ///   - scriptId: Unique identifier (GUID) of the script to retrieve
    ///   - completion: Callback with complete script details dictionary or nil on failure
    func getShellScriptDetails(scriptId: String, completion: @escaping ([String: Any]?) -> Void) {
        sendRequest({ service, reply in
            service.getShellScriptDetails(scriptId: scriptId, reply: reply)
        }, completion: completion)
    }
    
    /// Permanently deletes a shell script from Microsoft Intune
    /// 
    /// **⚠️ WARNING: IRREVERSIBLE OPERATION**
    /// 
    /// This function permanently removes a shell script from Intune. Once deleted:
    /// - Script cannot be recovered
    /// - All device group assignments are removed
    /// - Scheduled executions are canceled
    /// - Historical execution data may be retained per Microsoft policies
    /// 
    /// **Best Practices:**
    /// 1. Always fetch script details first for confirmation
    /// 2. Remove from assignments before deletion to prevent mid-execution issues
    /// 3. Backup script content if needed for future use
    /// 4. Verify script is not critical for device management
    /// 
    /// **Usage Example:**
    /// ```swift
    /// // Recommended: Confirm before deletion
    /// XPCManager.shared.getShellScriptDetails(scriptId: scriptId) { details in
    ///     if let details = details {
    ///         let scriptName = details["displayName"] as? String ?? "Unknown Script"
    ///         print("About to delete: \(scriptName)")
    ///         
    ///         XPCManager.shared.deleteShellScript(scriptId: scriptId) { success in
    ///             if success {
    ///                 print("Script '\(scriptName)' deleted successfully")
    ///             } else {
    ///                 print("Failed to delete script")
    ///             }
    ///         }
    ///     }
    /// }
    /// ```
    /// 
    /// **Required Permissions:**
    /// - DeviceManagementConfiguration.ReadWrite.All (Application or Delegated)
    /// 
    /// - Parameters:
    ///   - scriptId: Unique identifier (GUID) of the script to delete permanently
    ///   - completion: Callback indicating if deletion was successful
    func deleteShellScript(scriptId: String, completion: @escaping (Bool) -> Void) {
        sendRequest({ service, reply in
            service.deleteShellScript(scriptId: scriptId, reply: reply)
        }, completion: completion)
    }
    
    /// Updates an existing shell script in Microsoft Intune with new configuration or content
    /// 
    /// This function modifies an existing shell script's properties, content, or settings.
    /// Supports partial updates - only properties included in updatedData are modified,
    /// all other properties remain unchanged.
    /// 
    /// **Key Features:**
    /// - Partial update support (only changed properties required)
    /// - Maintains existing assignments and schedules
    /// - Comprehensive error handling
    /// - Immediate effect on future script executions
    /// 
    /// **Updatable Properties:**
    /// - `displayName`: Change the script's display name
    /// - `description`: Update or add a description
    /// - `scriptContent`: Replace script content (must be Base64 encoded)
    /// - `runAsAccount`: Change execution context ("system" or "user")
    /// - `retryCount`: Modify retry attempts (1-5)
    /// - `blockExecutionNotifications`: Toggle notification settings
    /// 
    /// **Usage Examples:**
    /// ```swift
    /// // Update display name and description only
    /// let nameUpdate: [String: Any] = [
    ///     "displayName": "Enhanced Security Script v2.0",
    ///     "description": "Updated with additional security checks"
    /// ]
    /// XPCManager.shared.updateShellScript(scriptId: scriptId, updatedData: nameUpdate) { success in
    ///     print("Name update: \(success ? "Success" : "Failed")")
    /// }
    /// 
    /// // Update script content
    /// let newContent = "#!/bin/bash\necho 'Updated script content'\n"
    /// let contentUpdate: [String: Any] = [
    ///     "scriptContent": Data(newContent.utf8).base64EncodedString()
    /// ]
    /// XPCManager.shared.updateShellScript(scriptId: scriptId, updatedData: contentUpdate) { success in
    ///     print("Content update: \(success ? "Success" : "Failed")")
    /// }
    /// ```
    /// 
    /// **Impact on Assignments:**
    /// - Existing device group assignments remain unchanged
    /// - Updated script will be used for future executions
    /// - No need to reassign to device groups
    /// - Execution schedule remains the same
    /// 
    /// **Required Permissions:**
    /// - DeviceManagementConfiguration.ReadWrite.All (Application or Delegated)
    /// 
    /// - Parameters:
    ///   - scriptId: Unique identifier (GUID) of the script to update
    ///   - updatedData: Dictionary containing only the properties to update (partial update supported)
    ///   - completion: Callback indicating if update was successful
    func updateShellScript(scriptId: String, updatedData: [String: Any], completion: @escaping (Bool) -> Void) {
        sendRequest({ service, reply in
            service.updateShellScript(scriptId: scriptId, updatedData: updatedData, reply: reply)
        }, completion: completion)
    }
}