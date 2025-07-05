//
//  XPCService+ShellScripts.swift
//  Intuneomator
//
//  Created by Gil Burns on 6/22/25.
//

import Foundation

/// XPCService extension for Microsoft Intune Shell Script management operations
/// Handles secure communication with Microsoft Graph API endpoints for shell script operations
/// All operations use authenticated tokens and provide comprehensive error handling through async callbacks
extension XPCService {
    
    // MARK: - Intune Shell Script Management
    
    /// Fetches all Intune Shell Scripts from Microsoft Graph with pagination support
    /// Retrieves complete list of macOS shell scripts configured in Intune with automatic pagination
    /// - Parameter reply: Callback with array of shell script dictionaries or nil on failure
    func fetchIntuneShellScripts(reply: @escaping ([[String : Any]]?) -> Void) {
        Task {
            do {
                let entraAuthenticator = EntraAuthenticator.shared
                let authToken = try await entraAuthenticator.getEntraIDToken()
                let shellScripts = try await EntraGraphRequests.fetchIntuneShellScripts(authToken: authToken)
                reply(shellScripts)
            } catch {
                Logger.error("Failed to fetch Intune shell scripts: \(error.localizedDescription)", category: .core)
                reply(nil)
            }
        }
    }
    
    /// Uploads a shell script file to Microsoft Intune with comprehensive configuration options
    /// Reads local file, encodes as Base64, and creates managed device shell script in Intune
    /// - Parameters:
    ///   - scriptPath: Absolute file path to the shell script file to upload
    ///   - scriptName: Display name for the script in Intune console
    ///   - runAsAccount: Execution context ("system" for root privileges or "user" for user context)
    ///   - retryCount: Number of retry attempts if script execution fails (1-5)
    ///   - blockExecutionNotifications: Whether to suppress execution notifications to end users
    ///   - reply: Callback indicating if upload was successful
    func uploadShellScript(scriptPath: String, scriptName: String, runAsAccount: String, retryCount: Int, blockExecutionNotifications: Bool, reply: @escaping (Bool) -> Void) {
        Task {
            do {
                let entraAuthenticator = EntraAuthenticator.shared
                let authToken = try await entraAuthenticator.getEntraIDToken()
                let success = try await EntraGraphRequests.uploadScript(
                    authToken: authToken,
                    scriptPath: scriptPath,
                    scriptName: scriptName,
                    runAsAccount: runAsAccount,
                    retryCount: retryCount,
                    blockExecutionNotifications: blockExecutionNotifications
                )
                reply(success)
            } catch {
                Logger.error("Failed to upload shell script '\(scriptName)': \(error.localizedDescription)", category: .core)
                reply(false)
            }
        }
    }
    
    /// Creates a new shell script in Microsoft Intune with custom configuration data
    /// Lower-level function providing full control over script creation parameters
    /// - Parameters:
    ///   - scriptData: Dictionary containing complete script configuration following Microsoft Graph deviceShellScript schema
    ///   - reply: Callback with the unique script ID or nil on failure
    func createNewShellScript(scriptData: [String: Any], reply: @escaping (String?) -> Void) {
        Task {
            do {
                let entraAuthenticator = EntraAuthenticator.shared
                let authToken = try await entraAuthenticator.getEntraIDToken()
                let scriptId = try await EntraGraphRequests.createNewScript(authToken: authToken, scriptData: scriptData)
                reply(scriptId)
            } catch {
                Logger.error("Failed to create new shell script: \(error.localizedDescription)", category: .core)
                reply(nil)
            }
        }
    }
    
    /// Retrieves comprehensive details about a specific shell script from Microsoft Intune
    /// Fetches complete metadata and automatically decodes Base64 script content for easy viewing
    /// - Parameters:
    ///   - scriptId: Unique identifier (GUID) of the script to retrieve
    ///   - reply: Callback with complete script details dictionary or nil on failure
    func getShellScriptDetails(scriptId: String, reply: @escaping ([String: Any]?) -> Void) {
        Task {
            do {
                let entraAuthenticator = EntraAuthenticator.shared
                let authToken = try await entraAuthenticator.getEntraIDToken()
                let scriptDetails = try await EntraGraphRequests.getScriptDetails(authToken: authToken, byId: scriptId)
                reply(scriptDetails)
            } catch {
                Logger.error("Failed to get shell script details for ID '\(scriptId)': \(error.localizedDescription)", category: .core)
                reply(nil)
            }
        }
    }
    
    /// Permanently deletes a shell script from Microsoft Intune
    /// ⚠️ Warning: This operation is irreversible and removes all associated assignments
    /// - Parameters:
    ///   - scriptId: Unique identifier (GUID) of the script to delete permanently
    ///   - reply: Callback indicating if deletion was successful
    func deleteShellScript(scriptId: String, reply: @escaping (Bool) -> Void) {
        Task {
            do {
                let entraAuthenticator = EntraAuthenticator.shared
                let authToken = try await entraAuthenticator.getEntraIDToken()
                let success = try await EntraGraphRequests.deleteScript(authToken: authToken, byId: scriptId)
                reply(success)
            } catch {
                Logger.error("Failed to delete shell script with ID '\(scriptId)': \(error.localizedDescription)", category: .core)
                reply(false)
            }
        }
    }
    
    /// Updates an existing shell script in Microsoft Intune with new configuration or content
    /// Supports partial updates - only specified properties are modified, others remain unchanged
    /// - Parameters:
    ///   - scriptId: Unique identifier (GUID) of the script to update
    ///   - updatedData: Dictionary containing only the properties to update (partial update supported)
    ///   - reply: Callback indicating if update was successful
    func updateShellScript(scriptId: String, updatedData: [String: Any], reply: @escaping (Bool) -> Void) {
        Task {
            do {
                let entraAuthenticator = EntraAuthenticator.shared
                let authToken = try await entraAuthenticator.getEntraIDToken()
                let success = try await EntraGraphRequests.updateDeviceShellScript(authToken: authToken, byId: scriptId, updatedData: updatedData)
                reply(success)
            } catch {
                Logger.error("Failed to update shell script with ID '\(scriptId)': \(error.localizedDescription)", category: .core)
                reply(false)
            }
        }
    }
    
    // MARK: - Shell Script Group Assignment Management
    
    /// Assigns Entra ID groups to a shell script in Microsoft Intune via XPC
    /// Creates group assignments allowing the script to execute on devices in specified groups
    /// - Parameters:
    ///   - scriptId: Unique identifier (GUID) of the shell script to assign groups to
    ///   - groupAssignments: Array of assignment dictionaries containing group IDs and configuration
    ///   - reply: Callback indicating if assignment was successful
    func assignGroupsToShellScript(scriptId: String, groupAssignments: [[String: Any]], reply: @escaping (Bool) -> Void) {
        Task {
            do {
                let entraAuthenticator = EntraAuthenticator.shared
                let authToken = try await entraAuthenticator.getEntraIDToken()
                let success = try await EntraGraphRequests.assignGroupsToShellScript(authToken: authToken, scriptId: scriptId, groupAssignments: groupAssignments)
                reply(success)
            } catch {
                Logger.error("Failed to assign groups to shell script '\(scriptId)': \(error.localizedDescription)", category: .core)
                reply(false)
            }
        }
    }
    
    /// Retrieves current group assignments for a shell script from Microsoft Intune via XPC
    /// Fetches all group assignments currently configured for the specified shell script
    /// - Parameters:
    ///   - scriptId: Unique identifier (GUID) of the shell script to retrieve assignments for
    ///   - reply: Callback with array of assignment dictionaries or nil on failure
    func getShellScriptAssignments(scriptId: String, reply: @escaping ([[String: Any]]?) -> Void) {
        Task {
            do {
                let entraAuthenticator = EntraAuthenticator.shared
                let authToken = try await entraAuthenticator.getEntraIDToken()
                let assignments = try await EntraGraphRequests.getShellScriptAssignments(authToken: authToken, scriptId: scriptId)
                reply(assignments)
            } catch {
                Logger.error("Failed to get assignments for shell script '\(scriptId)': \(error.localizedDescription)", category: .core)
                reply(nil)
            }
        }
    }
    
    /// Removes all group assignments from a shell script in Microsoft Intune via XPC
    /// ⚠️ Warning: This removes ALL assignments - the script will no longer execute on any devices
    /// - Parameters:
    ///   - scriptId: Unique identifier (GUID) of the shell script to remove all assignments from
    ///   - reply: Callback indicating if removal was successful
    func removeAllShellScriptAssignments(scriptId: String, reply: @escaping (Bool) -> Void) {
        Task {
            do {
                let entraAuthenticator = EntraAuthenticator.shared
                let authToken = try await entraAuthenticator.getEntraIDToken()
                let success = try await EntraGraphRequests.removeAllShellScriptAssignments(authToken: authToken, scriptId: scriptId)
                reply(success)
            } catch {
                Logger.error("Failed to remove all assignments for shell script '\(scriptId)': \(error.localizedDescription)", category: .core)
                reply(false)
            }
        }
    }
    
    /// Removes a specific group assignment from a shell script in Microsoft Intune via XPC
    /// Removes the script from a specific group assignment while preserving other assignments
    /// - Parameters:
    ///   - scriptId: Unique identifier (GUID) of the shell script
    ///   - assignmentId: Unique identifier (GUID) of the specific assignment to remove
    ///   - reply: Callback indicating if removal was successful
    func removeShellScriptAssignment(scriptId: String, assignmentId: String, reply: @escaping (Bool) -> Void) {
        Task {
            do {
                let entraAuthenticator = EntraAuthenticator.shared
                let authToken = try await entraAuthenticator.getEntraIDToken()
                let success = try await EntraGraphRequests.removeShellScriptAssignment(authToken: authToken, scriptId: scriptId, assignmentId: assignmentId)
                reply(success)
            } catch {
                Logger.error("Failed to remove assignment '\(assignmentId)' for shell script '\(scriptId)': \(error.localizedDescription)", category: .core)
                reply(false)
            }
        }
    }
}