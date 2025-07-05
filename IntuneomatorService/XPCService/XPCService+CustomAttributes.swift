//
//  XPCService+CustomAttributes.swift
//  Intuneomator
//
//  Created by Gil Burns on 6/24/25.
//

import Foundation

/// XPCService extension for Microsoft Intune Custom Attribute management operations
/// Handles secure communication with Microsoft Graph API endpoints for custom attribute operations
/// All operations use authenticated tokens and provide comprehensive error handling through async callbacks
extension XPCService {
    
    // MARK: - Intune Shell Script Management
    
    /// Fetches all Intune Custom Attributes from Microsoft Graph with pagination support
    /// Retrieves complete list of macOS custom attributes configured in Intune with automatic pagination
    /// - Parameter reply: Callback with array of custom attribute dictionaries or nil on failure
    func fetchIntuneCustomAttributeShellScripts(reply: @escaping ([[String : Any]]?) -> Void) {
        Task {
            do {
                let entraAuthenticator = EntraAuthenticator.shared
                let authToken = try await entraAuthenticator.getEntraIDToken()
                let customAttributes = try await EntraGraphRequests.fetchIntuneCustomAttributeShellScripts(authToken: authToken)
                reply(customAttributes)
            } catch {
                Logger.error("Failed to fetch Intune custom attributes: \(error.localizedDescription)", category: .core)
                reply(nil)
            }
        }
        
    }
    
    /// Uploads a custom attribute file to Microsoft Intune with comprehensive configuration options
    /// Reads local file, encodes as Base64, and creates custom attribute shell script in Intune
    /// - Parameters:
    ///   - scriptPath: Absolute file path to the custom attribute file to upload
    ///   - scriptName: Display name for the script in Intune console
    ///   - runAsAccount: Execution context ("system" for root privileges or "user" for user context)
    ///   - retryCount: Number of retry attempts if script execution fails (1-5)
    ///   - blockExecutionNotifications: Whether to suppress execution notifications to end users
    ///   - reply: Callback indicating if upload was successful
    func uploadCustomAttributeShellScript(scriptPath: String, scriptName: String, runAsAccount: String, retryCount: Int, blockExecutionNotifications: Bool, reply: @escaping (Bool) -> Void) {
        
    }
    
    /// Creates a new custom attribute in Microsoft Intune with custom configuration data
    /// Lower-level function providing full control over custom attribute creation parameters
    /// - Parameters:
    ///   - scriptData: Dictionary containing complete custom attribute configuration following Microsoft Graph deviceShellScript schema
    ///   - reply: Callback with the unique script ID or nil on failure
    func createNewCustomAttributeShellScript(scriptData: [String : Any], reply: @escaping (String?) -> Void) {
        Task {
            do {
                let entraAuthenticator = EntraAuthenticator.shared
                let authToken = try await entraAuthenticator.getEntraIDToken()
                let scriptId = try await EntraGraphRequests.createNewCustomAttributeScript(authToken: authToken, scriptData: scriptData)
                reply(scriptId)
            } catch {
                Logger.error("Failed to create new custom attribute: \(error.localizedDescription)", category: .core)
                reply(nil)
            }
        }
    }
    
    /// Retrieves comprehensive details about a specific custom attribute from Microsoft Intune
    /// Fetches complete metadata and automatically decodes Base64 custom attribute content for easy viewing
    /// - Parameters:
    ///   - scriptId: Unique identifier (GUID) of the custom attribute to retrieve
    ///   - reply: Callback with complete custom attribute details dictionary or nil on failure
    func getCustomAttributeShellScriptDetails(scriptId: String, reply: @escaping ([String : Any]?) -> Void) {
        Task {
            do {
                let entraAuthenticator = EntraAuthenticator.shared
                let authToken = try await entraAuthenticator.getEntraIDToken()
                let scriptDetails = try await EntraGraphRequests.getCustomAttributeScriptDetails(authToken: authToken, byId: scriptId)
                reply(scriptDetails)
            } catch {
                Logger.error("Failed to get custom attribute details for ID '\(scriptId)': \(error.localizedDescription)", category: .core)
                reply(nil)
            }
        }
    }
    
    /// Permanently deletes a custom attribute from Microsoft Intune
    /// ⚠️ Warning: This operation is irreversible and removes all associated assignments
    /// - Parameters:
    ///   - scriptId: Unique identifier (GUID) of the custom attribute to delete permanently
    ///   - reply: Callback indicating if deletion was successful
    func deleteCustomAttributeShellScript(scriptId: String, reply: @escaping (Bool) -> Void) {
        Task {
            do {
                let entraAuthenticator = EntraAuthenticator.shared
                let authToken = try await entraAuthenticator.getEntraIDToken()
                let success = try await EntraGraphRequests.deleteCustomAttributeScript(authToken: authToken, byId: scriptId)
                reply(success)
            } catch {
                Logger.error("Failed to delete custom attribute with ID '\(scriptId)': \(error.localizedDescription)", category: .core)
                reply(false)
            }
        }
    }
    
    /// Updates an existing custom attribute in Microsoft Intune with new configuration or content
    /// Supports partial updates - only specified properties are modified, others remain unchanged
    /// - Parameters:
    ///   - scriptId: Unique identifier (GUID) of the custom attribute to update
    ///   - updatedData: Dictionary containing only the properties to update (partial update supported)
    ///   - reply: Callback indicating if update was successful
    func updateCustomAttributeShellScript(scriptId: String, updatedData: [String : Any], reply: @escaping (Bool) -> Void) {
        Task {
            do {
                let entraAuthenticator = EntraAuthenticator.shared
                let authToken = try await entraAuthenticator.getEntraIDToken()
                let success = try await EntraGraphRequests.updateCustomAttributeShellScript(authToken: authToken, byId: scriptId, updatedData: updatedData)
                reply(success)
            } catch {
                Logger.error("Failed to update custom attribute with ID '\(scriptId)': \(error.localizedDescription)", category: .core)
                reply(false)
            }
        }
    }
    
    // MARK: - Custom Attribute Group Assignment Management
    
    /// Assigns Entra ID groups to a custom attributes in Microsoft Intune via XPC
    /// Creates group assignments allowing the custom attribute script to execute on devices in specified groups
    /// - Parameters:
    ///   - scriptId: Unique identifier (GUID) of the custom attribute to assign groups to
    ///   - groupAssignments: Array of assignment dictionaries containing group IDs and configuration
    ///   - reply: Callback indicating if assignment was successful
    func assignGroupsToCustomAttributeShellScript(scriptId: String, groupAssignments: [[String : Any]], reply: @escaping (Bool) -> Void) {
        Task {
            do {
                let entraAuthenticator = EntraAuthenticator.shared
                let authToken = try await entraAuthenticator.getEntraIDToken()
                let success = try await EntraGraphRequests.assignGroupsToCustomAttributeShellScript(authToken: authToken, scriptId: scriptId, groupAssignments: groupAssignments)
                reply(success)
            } catch {
                Logger.error("Failed to assign groups to custom attribute '\(scriptId)': \(error.localizedDescription)", category: .core)
                reply(false)
            }
        }
        
    }
    
    /// Retrieves current group assignments for a custom attribute from Microsoft Intune via XPC
    /// Fetches all group assignments currently configured for the specified custom attribute
    /// - Parameters:
    ///   - scriptId: Unique identifier (GUID) of the custom attribute to retrieve assignments for
    ///   - reply: Callback with array of assignment dictionaries or nil on failure
    func getCustomAttributeShellScriptAssignments(scriptId: String, reply: @escaping ([[String : Any]]?) -> Void) {
        Task {
            do {
                let entraAuthenticator = EntraAuthenticator.shared
                let authToken = try await entraAuthenticator.getEntraIDToken()
                let assignments = try await EntraGraphRequests.getCustomAttributeShellScriptAssignments(authToken: authToken, scriptId: scriptId)
                reply(assignments)
            } catch {
                Logger.error("Failed to get assignments for custom attribute '\(scriptId)': \(error.localizedDescription)", category: .core)
                reply(nil)
            }
        }
        
    }
    
    /// Removes all group assignments from a custom attribute in Microsoft Intune via XPC
    /// ⚠️ Warning: This removes ALL assignments - the custom attribute will no longer execute on any devices
    /// - Parameters:
    ///   - scriptId: Unique identifier (GUID) of the custom attribute to remove all assignments from
    ///   - reply: Callback indicating if removal was successful
    func removeAllCustomAttributeShellScriptAssignments(scriptId: String, reply: @escaping (Bool) -> Void) {
        Task {
            do {
                let entraAuthenticator = EntraAuthenticator.shared
                let authToken = try await entraAuthenticator.getEntraIDToken()
                let success = try await EntraGraphRequests.removeAllCustomAttributeShellScriptAssignments(authToken: authToken, scriptId: scriptId)
                reply(success)
            } catch {
                Logger.error("Failed to remove all assignments for custom attribute '\(scriptId)': \(error.localizedDescription)", category: .core)
                reply(false)
            }
        }
        
    }
    
    /// Removes a specific group assignment from a custom attribute in Microsoft Intune via XPC
    /// Removes the custom attribute from a specific group assignment while preserving other assignments
    /// - Parameters:
    ///   - scriptId: Unique identifier (GUID) of the custom attribute
    ///   - assignmentId: Unique identifier (GUID) of the specific assignment to remove
    ///   - reply: Callback indicating if removal was successful
    func removeCustomAttributeShellScriptAssignment(scriptId: String, assignmentId: String, reply: @escaping (Bool) -> Void) {
        Task {
            do {
                let entraAuthenticator = EntraAuthenticator.shared
                let authToken = try await entraAuthenticator.getEntraIDToken()
                let success = try await EntraGraphRequests.removeCustomAttributeShellScriptAssignment(authToken: authToken, scriptId: scriptId, assignmentId: assignmentId)
                reply(success)
            } catch {
                Logger.error("Failed to remove assignment '\(assignmentId)' for custom attribute '\(scriptId)': \(error.localizedDescription)", category: .core)
                reply(false)
            }
        }
    }
}
