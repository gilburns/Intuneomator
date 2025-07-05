//
//  XPCService+AppCategories.swift
//  Intuneomator
//
//  Created by Gil Burns on 7/1/25.
//

import Foundation

/// XPCService extension for Microsoft Intune App Category management operations
/// Handles secure communication with Microsoft Graph API endpoints for app category operations
/// All operations use authenticated tokens and provide comprehensive error handling through async callbacks
extension XPCService {
    
    // MARK: - Intune App Category Management
 
    /// Retrieves available mobile app categories from Microsoft Intune
    /// Categories are used to organize and classify applications within the Intune console
    /// - Parameter reply: Callback with array of category dictionaries or nil on failure
    func fetchMobileAppCategories(reply: @escaping ([[String : Any]]?) -> Void) {
        Task {
            do {
                let entraAuthenticator = EntraAuthenticator.shared
                let authToken = try await entraAuthenticator.getEntraIDToken()
                let categories = try await EntraGraphRequests.fetchMobileAppCategories(authToken: authToken)
                reply(categories)
            } catch {
                Logger.error("Failed to fetch mobile app categories: \(error.localizedDescription)", category: .core)
                reply(nil)
            }
        }
    }
    
    /// Creates a new mobile app category in Microsoft Intune
    /// Categories are used to organize and classify applications within the Intune console
    /// - Parameters:
    ///   - categoryData: Dictionary containing category information (displayName is required)
    ///   - reply: Callback with created category ID or nil on failure
    func createMobileAppCategory(categoryData: [String: Any], reply: @escaping (String?) -> Void) {
        Task {
            do {
                let entraAuthenticator = EntraAuthenticator.shared
                let authToken = try await entraAuthenticator.getEntraIDToken()
                let categoryId = try await EntraGraphRequests.createMobileAppCategory(authToken: authToken, categoryData: categoryData)
                reply(categoryId)
            } catch {
                Logger.error("Failed to create mobile app category: \(error.localizedDescription)", category: .core)
                reply(nil)
            }
        }
    }
    
    /// Updates an existing mobile app category in Microsoft Intune
    /// Allows modification of category properties such as display name
    /// - Parameters:
    ///   - categoryId: Unique identifier (GUID) of the category to update
    ///   - updatedData: Dictionary containing updated category information
    ///   - reply: Callback indicating success (true) or failure (false)
    func updateMobileAppCategory(categoryId: String, updatedData: [String: Any], reply: @escaping (Bool) -> Void) {
        Task {
            do {
                let entraAuthenticator = EntraAuthenticator.shared
                let authToken = try await entraAuthenticator.getEntraIDToken()
                let success = try await EntraGraphRequests.updateMobileAppCategory(authToken: authToken, categoryId: categoryId, updatedData: updatedData)
                reply(success)
            } catch {
                Logger.error("Failed to update mobile app category \(categoryId): \(error.localizedDescription)", category: .core)
                reply(false)
            }
        }
    }
    
    /// Deletes a mobile app category from Microsoft Intune
    /// WARNING: This will remove the category permanently and may affect apps assigned to this category
    /// - Parameters:
    ///   - categoryId: Unique identifier (GUID) of the category to delete
    ///   - reply: Callback indicating success (true) or failure (false)
    func deleteMobileAppCategory(categoryId: String, reply: @escaping (Bool) -> Void) {
        Task {
            do {
                let entraAuthenticator = EntraAuthenticator.shared
                let authToken = try await entraAuthenticator.getEntraIDToken()
                let success = try await EntraGraphRequests.deleteMobileAppCategory(authToken: authToken, categoryId: categoryId)
                reply(success)
            } catch {
                Logger.error("Failed to delete mobile app category \(categoryId): \(error.localizedDescription)", category: .core)
                reply(false)
            }
        }
    }
}
