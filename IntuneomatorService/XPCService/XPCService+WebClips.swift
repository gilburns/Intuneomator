//
//  XPCService+WebClips.swift
//  Intuneomator
//
//  Created by Gil Burns on 7/7/25.
//

import Foundation

/// XPCService extension for Microsoft Intune Web Clip management operations
/// Handles secure communication with Microsoft Graph API endpoints for macOS Web Clip operations
/// All operations use authenticated tokens and provide comprehensive error handling through async callbacks
extension XPCService {
    
    // MARK: - Intune Web Clip Management
 
    /// Retrieves all macOS Web Clips from Microsoft Intune
    /// Web Clips are bookmarks that appear as applications on macOS devices, providing quick access to web content
    /// - Parameter reply: Callback with array of web clip dictionaries or nil on failure
    func fetchIntuneWebClips(reply: @escaping ([[String : Any]]?) -> Void) {
        Task {
            do {
                let entraAuthenticator = EntraAuthenticator.shared
                let authToken = try await entraAuthenticator.getEntraIDToken()
                let webClips = try await EntraGraphRequests.fetchIntuneWebClips(authToken: authToken)
                reply(webClips)
            } catch {
                Logger.error("Failed to fetch Intune Web Clips: \(error.localizedDescription)", category: .core)
                reply(nil)
            }
        }
    }
    
    /// Creates a new macOS Web Clip in Microsoft Intune with full assignment support
    /// Web Clips allow users to access web content through app-like icons on their devices
    /// Automatically handles categories and group assignments if provided in the data
    /// - Parameters:
    ///   - webClipData: Dictionary containing web clip information (displayName and appUrl are required)
    ///   - reply: Callback with created web clip ID or nil on failure
    func createIntuneWebClip(webClipData: [String: Any], reply: @escaping (String?) -> Void) {
        Task {
            do {
                let entraAuthenticator = EntraAuthenticator.shared
                let authToken = try await entraAuthenticator.getEntraIDToken()
                
                // Check if this is a simple creation or needs assignments
                let hasCategories = !(webClipData["categories"] as? [[String: Any]] ?? []).isEmpty
                let hasAssignments = !(webClipData["assignments"] as? [[String: Any]] ?? []).isEmpty
                
                if hasCategories || hasAssignments {
                    // Use the comprehensive creation function
                    Logger.info("Creating web clip with categories and/or assignments", category: .core)
                    let results = try await EntraGraphRequests.createWebClipWithAssignments(authToken: authToken, webClipData: webClipData)
                    let webClipId = results["webClipId"] as? String
                    reply(webClipId)
                } else {
                    // Use the simple creation function
                    Logger.info("Creating web clip without assignments", category: .core)
                    let webClipId = try await EntraGraphRequests.createIntuneWebClip(authToken: authToken, webClipData: webClipData)
                    reply(webClipId)
                }
            } catch {
                Logger.error("Failed to create Intune Web Clip: \(error.localizedDescription)", category: .core)
                reply(nil)
            }
        }
    }
    
    /// Updates an existing macOS Web Clip in Microsoft Intune
    /// Allows modification of web clip properties such as display name, URL, and appearance settings
    /// - Parameters:
    ///   - webClipId: Unique identifier (GUID) of the web clip to update
    ///   - updatedData: Dictionary containing updated web clip information
    ///   - reply: Callback indicating success (true) or failure (false)
    func updateWebClip(webClipId: String, updatedData: [String: Any], reply: @escaping (Bool) -> Void) {
        Task {
            do {
                let entraAuthenticator = EntraAuthenticator.shared
                let authToken = try await entraAuthenticator.getEntraIDToken()
                let success = try await EntraGraphRequests.updateWebClip(authToken: authToken, webClipId: webClipId, updatedData: updatedData)
                reply(success)
            } catch {
                Logger.error("Failed to update Web Clip \(webClipId): \(error.localizedDescription)", category: .core)
                reply(false)
            }
        }
    }
    
    /// Deletes a macOS Web Clip from Microsoft Intune
    /// WARNING: This will remove the web clip permanently and may affect devices where it is installed
    /// - Parameters:
    ///   - webClipId: Unique identifier (GUID) of the web clip to delete
    ///   - reply: Callback indicating success (true) or failure (false)
    func deleteWebClip(webClipId: String, reply: @escaping (Bool) -> Void) {
        Task {
            do {
                let entraAuthenticator = EntraAuthenticator.shared
                let authToken = try await entraAuthenticator.getEntraIDToken()
                let success = try await EntraGraphRequests.deleteWebClip(authToken: authToken, byId: webClipId)
                reply(success)
            } catch {
                Logger.error("Failed to delete Web Clip \(webClipId): \(error.localizedDescription)", category: .core)
                reply(false)
            }
        }
    }
    
    /// Fetches both group assignments and category assignments for a specific web clip
    /// Used when editing existing web clips to populate the assignment and category UI
    /// - Parameters:
    ///   - webClipId: Unique identifier (GUID) of the web clip
    ///   - reply: Callback with assignment/category data dictionary or nil on failure
    func fetchWebClipAssignmentsAndCategories(webClipId: String, reply: @escaping ([String: Any]?) -> Void) {
        Task {
            do {
                let entraAuthenticator = EntraAuthenticator.shared
                let authToken = try await entraAuthenticator.getEntraIDToken()
                let assignmentData = try await EntraGraphRequests.fetchWebClipAssignmentsAndCategories(authToken: authToken, webClipId: webClipId)
                reply(assignmentData)
            } catch {
                Logger.error("Failed to fetch web clip assignments and categories for \(webClipId): \(error.localizedDescription)", category: .core)
                reply(nil)
            }
        }
    }
    
    /// Updates an existing web clip with categories and group assignments in a comprehensive workflow
    /// Handles the complete update sequence: PATCH web clip → update categories → update assignments
    /// - Parameters:
    ///   - webClipData: Complete web clip data including properties, categories, and assignments
    ///   - reply: Callback indicating if the complete update workflow was successful
    func updateWebClipWithAssignments(webClipData: [String: Any], reply: @escaping (Bool) -> Void) {
        Task {
            do {
                let entraAuthenticator = EntraAuthenticator.shared
                let authToken = try await entraAuthenticator.getEntraIDToken()
                let success = try await EntraGraphRequests.updateWebClipWithAssignments(authToken: authToken, webClipData: webClipData)
                reply(success)
            } catch {
                Logger.error("Failed to update web clip with assignments: \(error.localizedDescription)", category: .core)
                reply(false)
            }
        }
    }
}