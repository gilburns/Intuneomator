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
    ///     if success == true {
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
    ///   - completion: Callback indicating if upload was successful (nil on XPC failure)
    func uploadShellScript(scriptPath: String, scriptName: String, runAsAccount: String, retryCount: Int, blockExecutionNotifications: Bool, completion: @escaping (Bool?) -> Void) {
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
    ///             if success == true {
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
    ///   - completion: Callback indicating if deletion was successful (nil on XPC failure)
    func deleteShellScript(scriptId: String, completion: @escaping (Bool?) -> Void) {
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
    ///     print("Name update: \(success == true ? "Success" : "Failed")")
    /// }
    /// 
    /// // Update script content
    /// let newContent = "#!/bin/bash\necho 'Updated script content'\n"
    /// let contentUpdate: [String: Any] = [
    ///     "scriptContent": Data(newContent.utf8).base64EncodedString()
    /// ]
    /// XPCManager.shared.updateShellScript(scriptId: scriptId, updatedData: contentUpdate) { success in
    ///     print("Content update: \(success == true ? "Success" : "Failed")")
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
    ///   - completion: Callback indicating if update was successful (nil on XPC failure)
    func updateShellScript(scriptId: String, updatedData: [String: Any], completion: @escaping (Bool?) -> Void) {
        sendRequest({ service, reply in
            service.updateShellScript(scriptId: scriptId, updatedData: updatedData, reply: reply)
        }, completion: completion)
    }
    
    // MARK: - Shell Script Group Assignment Operations
    
    /// Assigns Entra ID groups to a shell script in Microsoft Intune with comprehensive assignment management
    /// 
    /// This function creates group assignments for a shell script, enabling it to execute on devices
    /// belonging to the specified Entra ID groups. Supports multiple group assignments in a single operation
    /// with automatic validation and error handling.
    /// 
    /// **Key Features:**
    /// - Batch assignment of multiple groups
    /// - Automatic group ID validation
    /// - Comprehensive error handling with detailed feedback
    /// - Support for different assignment intents
    /// 
    /// **Assignment Structure:**
    /// Each assignment in the groupAssignments array should contain:
    /// ```swift
    /// [
    ///     "groupId": "12345-abcde-67890-fghij-klmno",  // Required: Entra ID group GUID
    ///     "intent": "required"                         // Optional: assignment intent
    /// ]
    /// ```
    /// 
    /// **Usage Example:**
    /// ```swift
    /// let assignments = [
    ///     ["groupId": "dev-team-group-id"],
    ///     ["groupId": "qa-team-group-id"],
    ///     ["groupId": "admin-group-id"]
    /// ]
    /// 
    /// XPCManager.shared.assignGroupsToShellScript(
    ///     scriptId: "script-guid-here",
    ///     groupAssignments: assignments
    /// ) { success in
    ///     if success == true {
    ///         print("Groups assigned successfully to shell script")
    ///     } else if success == false {
    ///         print("Failed to assign groups to shell script")
    ///     } else {
    ///         print("XPC communication failed")
    ///     }
    /// }
    /// ```
    /// 
    /// **Impact of Assignment:**
    /// - Script will execute on all devices belonging to assigned groups
    /// - Devices must be enrolled in Intune and managed
    /// - Script execution follows configured schedule and retry settings
    /// - Assignment is immediate but execution timing depends on device check-in
    /// 
    /// **Required Permissions:**
    /// - DeviceManagementConfiguration.ReadWrite.All (Application or Delegated)
    /// 
    /// - Parameters:
    ///   - scriptId: Unique identifier (GUID) of the shell script to assign groups to
    ///   - groupAssignments: Array of assignment dictionaries containing group IDs and optional configuration
    ///   - completion: Callback indicating if assignment was successful (nil on XPC failure)
    func assignGroupsToShellScript(scriptId: String, groupAssignments: [[String: Any]], completion: @escaping (Bool?) -> Void) {
        sendRequest({ service, reply in
            service.assignGroupsToShellScript(scriptId: scriptId, groupAssignments: groupAssignments, reply: reply)
        }, completion: completion)
    }
    
    /// Retrieves current group assignments for a shell script from Microsoft Intune
    /// 
    /// This function fetches all group assignments currently configured for a specific shell script,
    /// providing complete assignment metadata including target groups and assignment details.
    /// 
    /// **Key Features:**
    /// - Complete assignment metadata retrieval
    /// - Group information and assignment details
    /// - Assignment target resolution
    /// - Comprehensive error handling
    /// 
    /// **Returned Data Structure:**
    /// Each assignment dictionary in the returned array contains:
    /// - `id`: Assignment unique identifier (GUID)
    /// - `target`: Assignment target information containing group details
    /// - `@odata.type`: Microsoft Graph assignment type
    /// - Additional assignment metadata from Microsoft Graph
    /// 
    /// **Usage Example:**
    /// ```swift
    /// XPCManager.shared.getShellScriptAssignments(scriptId: "script-guid") { assignments in
    ///     if let assignments = assignments {
    ///         print("Found \\(assignments.count) assignments for shell script")
    ///         
    ///         for assignment in assignments {
    ///             if let target = assignment["target"] as? [String: Any],
    ///                let groupId = target["groupId"] as? String {
    ///                 print("Script assigned to group: \\(groupId)")
    ///             }
    ///             
    ///             if let assignmentId = assignment["id"] as? String {
    ///                 print("Assignment ID: \\(assignmentId)")
    ///             }
    ///         }
    ///     } else {
    ///         print("Failed to retrieve script assignments")
    ///     }
    /// }
    /// ```
    /// 
    /// **Common Use Cases:**
    /// - Displaying current assignments in management interfaces
    /// - Preparing assignment data for editing operations
    /// - Auditing script deployment scope
    /// - Identifying assignments for selective removal
    /// 
    /// **Required Permissions:**
    /// - DeviceManagementConfiguration.Read.All (Application or Delegated)
    /// 
    /// - Parameters:
    ///   - scriptId: Unique identifier (GUID) of the shell script to retrieve assignments for
    ///   - completion: Callback with array of assignment dictionaries or nil on failure (including XPC failure)
    func getShellScriptAssignments(scriptId: String, completion: @escaping ([[String: Any]]?) -> Void) {
        sendRequest({ service, reply in
            service.getShellScriptAssignments(scriptId: scriptId, reply: reply)
        }, completion: completion)
    }
    
    /// Removes all group assignments from a shell script in Microsoft Intune
    /// 
    /// **⚠️ CRITICAL WARNING: This operation removes ALL assignments from the shell script**
    /// 
    /// This function completely unassigns a shell script from all device groups, effectively
    /// stopping its execution on all devices. This operation is typically used when:
    /// - Decommissioning a script entirely
    /// - Preparing for complete reassignment
    /// - Emergency script disabling
    /// 
    /// **Key Features:**
    /// - Batch removal of all assignments
    /// - Individual assignment deletion for reliability
    /// - Comprehensive error handling and reporting
    /// - Graceful handling of partial failures
    /// 
    /// **Impact of Removal:**
    /// - Script will immediately stop executing on all devices
    /// - All device group assignments are permanently removed
    /// - Existing script execution history is preserved
    /// - Script remains in Intune but becomes inactive
    /// - Operation cannot be undone (assignments must be recreated)
    /// 
    /// **Usage Example:**
    /// ```swift
    /// // Recommended: Confirm before removal
    /// let alert = NSAlert()
    /// alert.messageText = "Remove All Assignments"
    /// alert.informativeText = "This will remove the script from ALL device groups. Continue?"
    /// alert.addButton(withTitle: "Remove All")
    /// alert.addButton(withTitle: "Cancel")
    /// 
    /// if alert.runModal() == .alertFirstButtonReturn {
    ///     XPCManager.shared.removeAllShellScriptAssignments(scriptId: scriptId) { success in
    ///         if success == true {
    ///             print("All assignments removed successfully")
    ///             // Refresh UI to reflect changes
    ///         } else if success == false {
    ///             print("Failed to remove some or all assignments")
    ///         } else {
    ///             print("XPC communication failed")
    ///         }
    ///     }
    /// }
    /// ```
    /// 
    /// **Best Practices:**
    /// 1. Always confirm with user before removing all assignments
    /// 2. Consider backing up assignment configuration before removal
    /// 3. Provide clear feedback about the impact to users
    /// 4. Use selective removal when possible instead of complete removal
    /// 
    /// **Required Permissions:**
    /// - DeviceManagementConfiguration.ReadWrite.All (Application or Delegated)
    /// 
    /// - Parameters:
    ///   - scriptId: Unique identifier (GUID) of the shell script to remove all assignments from
    ///   - completion: Callback indicating if all assignments were successfully removed (nil on XPC failure)
    func removeAllShellScriptAssignments(scriptId: String, completion: @escaping (Bool?) -> Void) {
        sendRequest({ service, reply in
            service.removeAllShellScriptAssignments(scriptId: scriptId, reply: reply)
        }, completion: completion)
    }
    
    /// Removes a specific group assignment from a shell script in Microsoft Intune
    /// 
    /// This function performs targeted removal of a single assignment, allowing precise control
    /// over script deployment while preserving other group assignments. This is ideal for
    /// selective unassignment without affecting the entire script deployment.
    /// 
    /// **Key Features:**
    /// - Selective assignment removal
    /// - Preserves all other assignments
    /// - Immediate effect on script execution
    /// - Safe operation with comprehensive validation
    /// 
    /// **Assignment ID Resolution:**
    /// To use this function, you first need to retrieve assignments to find the specific assignment ID:
    /// 
    /// ```swift
    /// // Step 1: Get current assignments
    /// XPCManager.shared.getShellScriptAssignments(scriptId: scriptId) { assignments in
    ///     guard let assignments = assignments else { return }
    ///     
    ///     // Step 2: Find the assignment to remove (example: by group ID)
    ///     let targetGroupId = "group-to-remove-guid"
    ///     if let assignmentToRemove = assignments.first(where: { assignment in
    ///         if let target = assignment["target"] as? [String: Any],
    ///            let groupId = target["groupId"] as? String {
    ///             return groupId == targetGroupId
    ///         }
    ///         return false
    ///     }),
    ///        let assignmentId = assignmentToRemove["id"] as? String {
    ///         
    ///         // Step 3: Remove the specific assignment
    ///         XPCManager.shared.removeShellScriptAssignment(
    ///             scriptId: scriptId,
    ///             assignmentId: assignmentId
    ///         ) { success in
    ///             if success == true {
    ///                 print("Assignment removed successfully")
    ///             } else {
    ///                 print("Failed to remove assignment")
    ///             }
    ///         }
    ///     }
    /// }
    /// ```
    /// 
    /// **Impact of Removal:**
    /// - Script stops executing on devices in the removed group only
    /// - Other group assignments remain completely unchanged
    /// - Devices in the removed group lose access to the script immediately
    /// - Script execution continues normally on other assigned groups
    /// 
    /// **Common Use Cases:**
    /// - Removing script from specific departments or teams
    /// - Adjusting script scope without complete redeployment
    /// - Emergency removal from problematic device groups
    /// - Gradual rollback of script deployment
    /// 
    /// **Required Permissions:**
    /// - DeviceManagementConfiguration.ReadWrite.All (Application or Delegated)
    /// 
    /// - Parameters:
    ///   - scriptId: Unique identifier (GUID) of the shell script
    ///   - assignmentId: Unique identifier (GUID) of the specific assignment to remove
    ///   - completion: Callback indicating if the assignment was successfully removed (nil on XPC failure)
    func removeShellScriptAssignment(scriptId: String, assignmentId: String, completion: @escaping (Bool?) -> Void) {
        sendRequest({ service, reply in
            service.removeShellScriptAssignment(scriptId: scriptId, assignmentId: assignmentId, reply: reply)
        }, completion: completion)
    }
    
    // MARK: - Shell Script Device Run States
    
    /// Retrieves device run states for a specific shell script from Microsoft Intune
    ///
    /// This function fetches detailed execution results for a shell script across all assigned devices,
    /// providing comprehensive insights into script performance, device compliance, and execution outcomes.
    /// Essential for monitoring shell script deployment effectiveness and troubleshooting execution issues.
    ///
    /// **Key Features:**
    /// - Complete device execution history and status
    /// - Detailed script output and error information
    /// - Device information with names and platform details
    /// - Execution timestamps for performance analysis
    /// - Automatic pagination support for large device fleets
    /// - Sorted results by device name for consistent presentation
    ///
    /// **Returned Data Structure:**
    /// Each device run state dictionary contains rich execution information:
    /// - `runState`: Execution status ("pending", "success", "fail", "scriptError", "unknown")
    /// - `resultMessage`: Complete script output or detailed error message
    /// - `lastRunDateTime`: ISO 8601 timestamp of script execution (formatted with .formatIntuneDate())
    /// - `lastStateUpdateDateTime`: ISO 8601 timestamp of last status update
    /// - `errorCode`: Numeric error code for failed executions
    /// - `errorDescription`: Human-readable error explanation
    /// - `managedDevice`: Expanded device information including:
    ///   - `deviceName`: Device hostname for identification
    ///   - `platform`: Operating system platform
    ///   - Additional device management properties
    ///
    /// **Run State Interpretation:**
    /// - `pending`: Script queued for execution but not yet run on device
    /// - `success`: Script executed successfully with zero exit code
    /// - `fail`: Script execution failed due to system/network/permission issues
    /// - `scriptError`: Script ran but returned non-zero exit code
    /// - `unknown`: Execution status could not be determined
    ///
    /// **Usage Example:**
    /// ```swift
    /// XPCManager.shared.getShellScriptDeviceRunStates(scriptId: "script-guid") { deviceStates in
    ///     if let deviceStates = deviceStates {
    ///         print("Execution results for \(deviceStates.count) devices:")
    ///
    ///         // Analyze execution outcomes
    ///         let successCount = deviceStates.filter { ($0["runState"] as? String) == "success" }.count
    ///         let failureCount = deviceStates.filter { ($0["runState"] as? String)?.contains("fail") == true }.count
    ///         let pendingCount = deviceStates.filter { ($0["runState"] as? String) == "pending" }.count
    ///
    ///         print("Success: \(successCount), Failures: \(failureCount), Pending: \(pendingCount)")
    ///
    ///         // Display detailed results
    ///         for deviceState in deviceStates {
    ///             let runState = deviceState["runState"] as? String ?? "unknown"
    ///             let deviceInfo = deviceState["managedDevice"] as? [String: Any]
    ///             let deviceName = deviceInfo?["deviceName"] as? String ?? "Unknown Device"
    ///             let lastRun = (deviceState["lastRunDateTime"] as? String ?? "Never").formatIntuneDate()
    ///
    ///             print("\(deviceName): \(runState) (Last run: \(lastRun))")
    ///
    ///             // Show script output for successful executions
    ///             if runState == "success", let output = deviceState["resultMessage"] as? String {
    ///                 print("  Output: \(output)")
    ///             }
    ///
    ///             // Show error details for failed executions
    ///             if runState.contains("fail"), let error = deviceState["errorDescription"] as? String {
    ///                 print("  Error: \(error)")
    ///             }
    ///         }
    ///     } else {
    ///         print("Failed to retrieve device run states")
    ///     }
    /// }
    /// ```
    ///
    /// **Advanced Usage - Compliance Reporting:**
    /// ```swift
    /// XPCManager.shared.getShellScriptDeviceRunStates(scriptId: scriptId) { deviceStates in
    ///     guard let deviceStates = deviceStates else { return }
    ///
    ///     // Generate compliance report
    ///     let complianceData = deviceStates.compactMap { deviceState -> [String: Any]? in
    ///         guard let deviceInfo = deviceState["managedDevice"] as? [String: Any],
    ///               let deviceName = deviceInfo["deviceName"] as? String else { return nil }
    ///
    ///         let runState = deviceState["runState"] as? String ?? "unknown"
    ///         let lastRun = deviceState["lastRunDateTime"] as? String ?? ""
    ///         let isCompliant = runState == "success"
    ///
    ///         return [
    ///             "deviceName": deviceName,
    ///             "compliant": isCompliant,
    ///             "status": runState,
    ///             "lastExecution": lastRun.formatIntuneDate()
    ///         ]
    ///     }
    ///
    ///     // Export or display compliance report
    ///     exportComplianceReport(complianceData)
    /// }
    /// ```
    ///
    /// **Common Use Cases:**
    /// - Monitoring shell script deployment across device fleet
    /// - Troubleshooting script execution failures on specific devices
    /// - Generating compliance and execution reports for management
    /// - Identifying devices requiring attention or intervention
    /// - Performance analysis of script execution timing
    /// - Audit trail for shell script execution activities
    ///
    /// **Performance Considerations:**
    /// - Results are automatically paginated for large device environments
    /// - Device information is efficiently expanded in single API call
    /// - Results are pre-sorted by device name for UI consistency
    /// - Consider caching results for frequently accessed data
    ///
    /// **Required Permissions:**
    /// - DeviceManagementConfiguration.Read.All (Application or Delegated)
    /// - DeviceManagementManagedDevices.Read.All (for device information expansion)
    ///
    /// - Parameters:
    ///   - scriptId: Unique identifier (GUID) of the shell script to get device run states for
    ///   - completion: Callback with array of device run state dictionaries or nil on failure (including XPC failure)
    func getShellScriptDeviceRunStates(scriptId: String, completion: @escaping ([[String: Any]]?) -> Void) {
        sendRequest({ service, reply in
            service.getShellScriptDeviceRunStates(scriptId: scriptId, reply: reply)
        }, completion: completion)
    }

}
