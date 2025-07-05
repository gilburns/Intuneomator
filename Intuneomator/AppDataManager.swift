//
//  AppDataManager.swift
//  Intuneomator
//
//  Created by Gil Burns on 1/10/25.
//

import Foundation

/// Errors that can occur during AppDataManager operations.
enum AppDataManagerError: Error, LocalizedError {
    /// The AppDataManager instance was deallocated during an async operation
    case deallocated
    /// A data fetch operation failed with the specified reason
    case fetchFailed(String)
    /// Received data failed validation with the specified reason
    case invalidData(String)
    
    var errorDescription: String? {
        switch self {
        case .deallocated:
            return "AppDataManager was deallocated during operation"
        case .fetchFailed(let message):
            return "Data fetch failed: \(message)"
        case .invalidData(let message):
            return "Invalid data received: \(message)"
        }
    }
}

/// Centralized data manager for Microsoft Intune and Entra ID application data.
/// 
/// This class provides a unified interface for fetching, caching, and managing data from Microsoft
/// services including mobile app categories, Entra groups, and assignment filters. It implements
/// intelligent caching, data validation, and thread-safe access patterns to ensure efficient
/// and reliable data management throughout the application lifecycle.
/// 
/// **Key Features:**
/// - Automatic data caching with configurable expiration (5-minute default)
/// - Data validation to ensure structural integrity
/// - Loading state tracking to prevent duplicate requests
/// - Thread-safe access via MainActor isolation
/// - Comprehensive error handling with detailed error types
/// 
/// **Usage Pattern:**
/// ```swift
/// // Fetch data with automatic caching
/// try await AppDataManager.shared.fetchMobileAppCategories()
/// 
/// // Force refresh when needed
/// try await AppDataManager.shared.fetchEntraGroups(forceRefresh: true)
/// 
/// // Access cached data synchronously
/// let categories = AppDataManager.shared.getMobileAppCategories()
/// ```
@MainActor
class AppDataManager {
    
    /// Current application type being processed (used for context tracking)
    var currentAppType: String = ""
    
    /// Current application bundle ID being processed (used for context tracking)
    var currentAppBundleID: String = ""
    
    /// Shared singleton instance providing centralized data access
    static let shared = AppDataManager()
    
    /// Cached mobile application categories from Microsoft Graph API
    private(set) var mobileAppCategories: [[String: Any]] = []
    
    /// Cached Entra ID groups for application assignment
    private(set) var entraGroups: [[String: Any]] = []
    
    /// Cached assignment filters for macOS applications
    private(set) var entraFilters: [[String: Any]] = []
    
    // MARK: - Data Freshness Tracking
    
    /// Timestamp of the last successful mobile app categories fetch
    private(set) var lastCategoriesUpdate: Date?
    
    /// Timestamp of the last successful Entra groups fetch
    private(set) var lastGroupsUpdate: Date?
    
    /// Timestamp of the last successful Entra filters fetch
    private(set) var lastFiltersUpdate: Date?
    
    // MARK: - Loading State Tracking
    
    /// Indicates whether mobile app categories are currently being fetched
    private(set) var isLoadingCategories = false
    
    /// Indicates whether Entra groups are currently being fetched
    private(set) var isLoadingGroups = false
    
    /// Indicates whether Entra filters are currently being fetched
    private(set) var isLoadingFilters = false

    private init() {
        setupNotificationObservers()
    }
    
    /// Sets up notification observers for data updates from other components
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCategoryUpdate),
            name: .categoryManagerDidUpdateCategories,
            object: nil
        )
    }
    
    /// Handles category update notifications from the AppCategoryManagerViewController
    /// This ensures the AppDataManager cache is refreshed when categories are modified
    @objc private func handleCategoryUpdate(_ notification: Notification) {
        Logger.info("Category update notification received, refreshing cached categories", category: .core, toUserDirectory: true)
        
        Task { @MainActor in
            do {
                try await self.fetchMobileAppCategories(forceRefresh: true)
                Logger.info("Categories successfully refreshed after external update", category: .core, toUserDirectory: true)
            } catch {
                Logger.error("Failed to refresh categories after update notification: \(error)", category: .core, toUserDirectory: true)
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Data Fetching Methods
    
    /// Fetches mobile application categories from Microsoft Graph API with intelligent caching.
    /// 
    /// Retrieves available mobile app categories that can be used for application classification
    /// in Microsoft Intune. Implements automatic caching to reduce API calls and improve performance.
    /// 
    /// - Parameter forceRefresh: If true, bypasses cache and forces a fresh fetch from the API
    /// - Throws: `AppDataManagerError` for various failure conditions including network errors,
    ///           invalid data, or concurrent fetch attempts
    /// 
    /// **Caching Behavior:**
    /// - Uses 5-minute cache expiration by default
    /// - Skips fetch if data is fresh and forceRefresh is false
    /// - Validates data structure before caching
    /// 
    /// **Concurrency Safety:**
    /// - Prevents duplicate concurrent requests for the same data
    /// - Updates loading state during fetch operations
    /// - Uses MainActor isolation for thread safety
    func fetchMobileAppCategories(forceRefresh: Bool = false) async throws {
        // Check if already loading
        guard !isLoadingCategories else {
            throw AppDataManagerError.fetchFailed("Already loading mobile app categories")
        }
        
        // Check if recent data exists and force refresh not requested
        if !forceRefresh, let lastUpdate = lastCategoriesUpdate,
           Date().timeIntervalSince(lastUpdate) < 300 { // 5 minutes cache
            return // Use cached data
        }
        
        isLoadingCategories = true
        defer { isLoadingCategories = false }
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            XPCManager.shared.fetchMobileAppCategories { [weak self] categories in
                guard let self = self else {
                    continuation.resume(throwing: AppDataManagerError.deallocated)
                    return
                }
                if let categories = categories {
                    // Validate data structure
                    guard self.validateCategoriesData(categories) else {
                        continuation.resume(throwing: AppDataManagerError.invalidData("Invalid mobile app categories format"))
                        return
                    }
                    self.mobileAppCategories = categories
                    self.lastCategoriesUpdate = Date()
                    continuation.resume()
                } else {
                    continuation.resume(throwing: AppDataManagerError.fetchFailed("Failed to fetch mobile app categories"))
                }
            }
        }
    }

    /// Fetches Entra ID groups for application assignment with intelligent caching.
    /// 
    /// Retrieves available Entra ID (Azure AD) groups that can be used for assigning applications
    /// to users and devices in Microsoft Intune. Groups are essential for targeted app deployment.
    /// 
    /// - Parameter forceRefresh: If true, bypasses cache and forces a fresh fetch from the API
    /// - Throws: `AppDataManagerError` for various failure conditions
    /// 
    /// **Usage Context:**
    /// - Groups are used for application assignment targeting
    /// - Essential for configuring who receives specific applications
    /// - Supports both user and device groups
    func fetchEntraGroups(forceRefresh: Bool = false) async throws {
        guard !isLoadingGroups else {
            throw AppDataManagerError.fetchFailed("Already loading Entra groups")
        }
        
        if !forceRefresh, let lastUpdate = lastGroupsUpdate,
           Date().timeIntervalSince(lastUpdate) < 300 {
            return
        }
        
        isLoadingGroups = true
        defer { isLoadingGroups = false }
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            XPCManager.shared.fetchEntraGroups { [weak self] groups in
                guard let self = self else {
                    continuation.resume(throwing: AppDataManagerError.deallocated)
                    return
                }
                if let groups = groups {
                    guard self.validateGroupsData(groups) else {
                        continuation.resume(throwing: AppDataManagerError.invalidData("Invalid Entra groups format"))
                        return
                    }
                    self.entraGroups = groups
                    self.lastGroupsUpdate = Date()
                    continuation.resume()
                } else {
                    continuation.resume(throwing: AppDataManagerError.fetchFailed("Failed to fetch Entra groups"))
                }
            }
        }
    }
    
    /// Fetches assignment filters for macOS applications with intelligent caching.
    /// 
    /// Retrieves available assignment filters that provide advanced targeting capabilities
    /// for macOS applications in Microsoft Intune. Filters enable fine-grained control
    /// over application deployment based on device properties and conditions.
    /// 
    /// - Parameter forceRefresh: If true, bypasses cache and forces a fresh fetch from the API
    /// - Throws: `AppDataManagerError` for various failure conditions
    /// 
    /// **Filter Capabilities:**
    /// - Device property-based targeting (OS version, device model, etc.)
    /// - Complex conditional logic for deployment rules
    /// - Enhanced targeting beyond simple group membership
    func fetchEntraFilters(forceRefresh: Bool = false) async throws {
        guard !isLoadingFilters else {
            throw AppDataManagerError.fetchFailed("Already loading Entra filters")
        }
        
        if !forceRefresh, let lastUpdate = lastFiltersUpdate,
           Date().timeIntervalSince(lastUpdate) < 300 {
            return
        }
        
        isLoadingFilters = true
        defer { isLoadingFilters = false }
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            XPCManager.shared.fetchAssignmentFiltersForMac { [weak self] filters in
                guard let self = self else {
                    continuation.resume(throwing: AppDataManagerError.deallocated)
                    return
                }
                if let filters = filters {
                    guard self.validateFiltersData(filters) else {
                        continuation.resume(throwing: AppDataManagerError.invalidData("Invalid Entra filters format"))
                        return
                    }
                    self.entraFilters = filters
                    self.lastFiltersUpdate = Date()
                    continuation.resume()
                } else {
                    continuation.resume(throwing: AppDataManagerError.fetchFailed("Failed to fetch Entra filters"))
                }
            }
        }
    }
    
    // MARK: - Data Accessors
    
    /// Returns the currently cached mobile application categories.
    /// 
    /// Provides synchronous access to previously fetched mobile app categories.
    /// Returns empty array if no data has been fetched yet.
    /// 
    /// - Returns: Array of category dictionaries containing id, displayName, and other properties
    func getMobileAppCategories() -> [[String: Any]] {
        return mobileAppCategories
    }

    /// Returns the currently cached Entra ID groups.
    /// 
    /// Provides synchronous access to previously fetched Entra groups for application assignment.
    /// Returns empty array if no data has been fetched yet.
    /// 
    /// - Returns: Array of group dictionaries containing id, displayName, and other properties
    func getEntraGroups() -> [[String: Any]] {
        return entraGroups
    }
    
    /// Returns the currently cached assignment filters for macOS applications.
    /// 
    /// Provides synchronous access to previously fetched assignment filters.
    /// Returns empty array if no data has been fetched yet.
    /// 
    /// - Returns: Array of filter dictionaries containing id, displayName, and other properties
    func getEntraFilters() -> [[String: Any]] {
        return entraFilters
    }
    
    // MARK: - Utility Methods
    
    /// Refreshes all cached data concurrently, forcing fresh fetches from APIs.
    /// 
    /// Performs concurrent refresh of all three data types (categories, groups, filters)
    /// to minimize total refresh time. Useful for ensuring all data is current when
    /// starting critical operations or after authentication changes.
    /// 
    /// - Throws: `AppDataManagerError` if any of the fetch operations fail
    /// 
    /// **Performance:**
    /// - Executes all three fetches concurrently for optimal speed
    /// - Typically faster than sequential refresh operations
    /// - Ideal for startup scenarios or after configuration changes
    func refreshAllData() async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { try await self.fetchMobileAppCategories(forceRefresh: true) }
            group.addTask { try await self.fetchEntraGroups(forceRefresh: true) }
            group.addTask { try await self.fetchEntraFilters(forceRefresh: true) }
            
            // Wait for all tasks to complete and propagate any errors
            try await group.waitForAll()
        }
    }
    
    /// Reinitializes the AppDataManager after authentication configuration changes.
    /// 
    /// Clears all cached data and attempts to fetch fresh data from APIs. This method
    /// is specifically designed for scenarios where authentication has been newly
    /// configured (such as after completing the setup wizard) and the data that
    /// previously failed to load should be retried.
    /// 
    /// - Throws: `AppDataManagerError` if any of the fetch operations fail
    /// 
    /// **Use Cases:**
    /// - After completing the setup wizard
    /// - After updating authentication credentials
    /// - When switching between different Intune tenants
    /// - After resolving authentication issues
    func reinitializeAfterAuthSetup() async throws {
        Logger.info("Reinitializing AppDataManager after authentication setup...", category: .core, toUserDirectory: true)
        
        // Clear any stale cached data first
        clearAllData()
        
        // Fetch fresh data with newly configured authentication
        try await refreshAllData()
        
        Logger.info("AppDataManager reinitialization completed successfully", category: .core, toUserDirectory: true)
    }
    
    /// Clears all cached data and resets freshness timestamps.
    /// 
    /// Removes all cached data and resets internal state. Useful when switching
    /// between different Intune tenants or after authentication changes that
    /// might affect data validity.
    /// 
    /// **Effects:**
    /// - Clears all cached arrays
    /// - Resets all timestamp tracking
    /// - Forces fresh fetches on next data access
    /// - Does not affect loading states (safe to call during operations)
    func clearAllData() {
        mobileAppCategories.removeAll()
        entraGroups.removeAll()
        entraFilters.removeAll()
        
        lastCategoriesUpdate = nil
        lastGroupsUpdate = nil
        lastFiltersUpdate = nil
    }
    
    /// Checks if cached data for a specific type has exceeded the maximum age threshold.
    /// 
    /// Determines whether cached data should be considered stale and needs refreshing.
    /// Useful for implementing custom cache management logic or UI indicators.
    /// 
    /// - Parameters:
    ///   - dataType: The type of data to check (categories, groups, or filters)
    ///   - maxAge: Maximum age in seconds before data is considered stale (default: 300)
    /// - Returns: `true` if data is stale or has never been fetched, `false` if still fresh
    /// 
    /// **Use Cases:**
    /// - Implementing cache expiration logic
    /// - Showing data freshness indicators in UI
    /// - Deciding whether to refresh specific data types
    func isDataStale(for dataType: DataType, maxAge: TimeInterval = 300) -> Bool {
        let lastUpdate: Date?
        switch dataType {
        case .categories:
            lastUpdate = lastCategoriesUpdate
        case .groups:
            lastUpdate = lastGroupsUpdate
        case .filters:
            lastUpdate = lastFiltersUpdate
        }
        
        guard let update = lastUpdate else { return true }
        return Date().timeIntervalSince(update) > maxAge
    }
    
    // MARK: - Data Validation
    
    /// Validates the structure and content of mobile app categories data.
    /// 
    /// Ensures that categories data contains the required fields for proper application
    /// categorization functionality. Empty arrays are considered valid.
    /// 
    /// - Parameter categories: Array of category dictionaries to validate
    /// - Returns: `true` if data structure is valid, `false` otherwise
    /// 
    /// **Required Fields:**
    /// - `id`: Unique identifier for the category
    /// - `displayName`: Human-readable name for the category
    private func validateCategoriesData(_ categories: [[String: Any]]) -> Bool {
        guard !categories.isEmpty else { return true } // Empty is valid
        
        // Basic validation - ensure each category has required fields
        return categories.allSatisfy { category in
            category["id"] != nil && category["displayName"] != nil
        }
    }
    
    /// Validates the structure and content of Entra groups data.
    /// 
    /// Ensures that groups data contains the required fields for proper application
    /// assignment functionality. Empty arrays are considered valid.
    /// 
    /// - Parameter groups: Array of group dictionaries to validate
    /// - Returns: `true` if data structure is valid, `false` otherwise
    /// 
    /// **Required Fields:**
    /// - `id`: Unique identifier for the group
    /// - `displayName`: Human-readable name for the group
    private func validateGroupsData(_ groups: [[String: Any]]) -> Bool {
        guard !groups.isEmpty else { return true }
        
        return groups.allSatisfy { group in
            group["id"] != nil && group["displayName"] != nil
        }
    }
    
    /// Validates the structure and content of assignment filters data.
    /// 
    /// Ensures that filters data contains the required fields for proper application
    /// targeting functionality. Empty arrays are considered valid.
    /// 
    /// - Parameter filters: Array of filter dictionaries to validate
    /// - Returns: `true` if data structure is valid, `false` otherwise
    /// 
    /// **Required Fields:**
    /// - `id`: Unique identifier for the filter
    /// - `displayName`: Human-readable name for the filter
    private func validateFiltersData(_ filters: [[String: Any]]) -> Bool {
        guard !filters.isEmpty else { return true }
        
        return filters.allSatisfy { filter in
            filter["id"] != nil && filter["displayName"] != nil
        }
    }
}

// MARK: - Supporting Types

extension AppDataManager {
    /// Enumeration of supported data types for cache management and validation operations.
    enum DataType {
        /// Mobile application categories for app classification
        case categories
        /// Entra ID groups for application assignment
        case groups
        /// Assignment filters for advanced targeting
        case filters
    }
}
