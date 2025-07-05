//
//  XPCManager+AppCategories.swift
//  Intuneomator
//
//  Created by Gil Burns on 7/1/25.
//

import Foundation

/// XPCManager extension for Microsoft Intune App Category management
/// Provides GUI access to app category operations through the privileged XPC service
/// All operations require valid authentication credentials and appropriate Microsoft Graph permissions
extension XPCManager {
    
    // MARK: - Intune App Category Management Operations
    
    /// Retrieves all available mobile application categories from Microsoft Intune with comprehensive metadata
    /// 
    /// This function fetches all mobile app categories configured in Microsoft Intune, providing
    /// complete category information sorted alphabetically by display name. Categories are used
    /// to organize and classify applications within the Intune console for better management.
    /// 
    /// **Key Features:**
    /// - Retrieves complete category metadata
    /// - Automatic alphabetical sorting by display name
    /// - Comprehensive error handling
    /// - Optimized for large category lists
    /// 
    /// **Returned Data Structure:**
    /// Each category dictionary contains:
    /// - `id`: Unique category identifier (GUID)
    /// - `displayName`: User-friendly category name
    /// - Additional Microsoft Graph category properties
    /// 
    /// **Usage Example:**
    /// ```swift
    /// XPCManager.shared.fetchMobileAppCategories { categories in
    ///     if let categories = categories {
    ///         print("Found \(categories.count) app categories")
    ///         for category in categories {
    ///             let name = category["displayName"] as? String ?? "Unknown"
    ///             let id = category["id"] as? String ?? "Unknown"
    ///             print("- \(name) (ID: \(id))")
    ///         }
    ///     } else {
    ///         print("Failed to fetch app categories")
    ///     }
    /// }
    /// ```
    /// 
    /// **Common Use Cases:**
    /// - Populating category selection UI components
    /// - Building category assignment interfaces
    /// - Auditing existing category structure
    /// - Category management and organization workflows
    /// 
    /// **Required Permissions:**
    /// - DeviceManagementApps.Read.All (Application or Delegated)
    /// 
    /// - Parameter completion: Callback with array of category dictionaries (sorted by display name) or nil on failure
    func fetchMobileAppCategories(completion: @escaping ([[String: Any]]?) -> Void) {
        sendRequest({ $0.fetchMobileAppCategories(reply: $1) }, completion: completion)
    }
    
    /// Creates a new mobile app category in Microsoft Intune with comprehensive validation and error handling
    /// 
    /// This function creates a new application category in Microsoft Intune, enabling better organization
    /// and classification of mobile applications. Categories help administrators manage large app portfolios
    /// by grouping related applications together.
    /// 
    /// **Key Features:**
    /// - Comprehensive input validation
    /// - Automatic duplicate name checking by Microsoft Graph
    /// - Immediate availability for app assignment
    /// - Complete error handling with detailed feedback
    /// 
    /// **Category Data Structure:**
    /// Required fields:
    /// ```swift
    /// let categoryData: [String: Any] = [
    ///     "displayName": "Business Applications"    // Required: User-friendly category name
    /// ]
    /// ```
    /// 
    /// Optional fields:
    /// ```swift
    /// let enhancedCategoryData: [String: Any] = [
    ///     "displayName": "Development Tools",
    ///     "description": "Applications used by software development teams"
    /// ]
    /// ```
    /// 
    /// **Usage Examples:**
    /// ```swift
    /// // Basic category creation
    /// let categoryData = ["displayName": "Security Tools"]
    /// XPCManager.shared.createMobileAppCategory(categoryData: categoryData) { categoryId in
    ///     if let categoryId = categoryId {
    ///         print("Category created successfully with ID: \(categoryId)")
    ///         // Now you can assign applications to this category
    ///     } else {
    ///         print("Failed to create category")
    ///     }
    /// }
    /// 
    /// // Category creation with description
    /// let detailedCategory = [
    ///     "displayName": "Engineering Software",
    ///     "description": "CAD, simulation, and engineering analysis tools"
    /// ]
    /// XPCManager.shared.createMobileAppCategory(categoryData: detailedCategory) { categoryId in
    ///     if let categoryId = categoryId {
    ///         print("Detailed category created: \(categoryId)")
    ///     }
    /// }
    /// ```
    /// 
    /// **Best Practices:**
    /// 1. Use clear, descriptive category names
    /// 2. Follow consistent naming conventions
    /// 3. Consider hierarchical naming for sub-categories (e.g., "Development - Frontend")
    /// 4. Verify category doesn't already exist before creation
    /// 5. Plan category structure before mass creation
    /// 
    /// **Category Naming Guidelines:**
    /// - Use descriptive, business-relevant names
    /// - Avoid technical jargon when possible
    /// - Consider your organization's terminology
    /// - Keep names concise but meaningful
    /// - Use title case for consistency
    /// 
    /// **Required Permissions:**
    /// - DeviceManagementApps.ReadWrite.All (Application or Delegated)
    /// 
    /// - Parameters:
    ///   - categoryData: Dictionary containing category information (displayName is required, description optional)
    ///   - completion: Callback with the unique category ID (GUID) or nil on failure
    func createMobileAppCategory(categoryData: [String: Any], completion: @escaping (String?) -> Void) {
        sendRequest({ $0.createMobileAppCategory(categoryData: categoryData, reply: $1) }, completion: completion)
    }
    
    /// Updates an existing mobile app category in Microsoft Intune with comprehensive change management
    /// 
    /// This function modifies an existing app category's properties in Microsoft Intune. Supports
    /// partial updates where only specified properties are changed, leaving all other properties
    /// unchanged. Updates take effect immediately for future app assignments.
    /// 
    /// **Key Features:**
    /// - Partial update support (only changed properties required)
    /// - Maintains existing app assignments to the category
    /// - Immediate effect on category metadata
    /// - Comprehensive error handling and validation
    /// - Preserves category associations
    /// 
    /// **Updatable Properties:**
    /// - `displayName`: Change the category's display name
    /// - `description`: Update or add a description
    /// - Additional properties as supported by Microsoft Graph
    /// 
    /// **Usage Examples:**
    /// ```swift
    /// // Update category display name only
    /// let nameUpdate: [String: Any] = [
    ///     "displayName": "Updated Business Applications"
    /// ]
    /// XPCManager.shared.updateMobileAppCategory(
    ///     categoryId: "12345-abcde-67890",
    ///     updatedData: nameUpdate
    /// ) { success in
    ///     if success == true {
    ///         print("Category name updated successfully")
    ///     } else if success == false {
    ///         print("Failed to update category name")
    ///     } else {
    ///         print("XPC communication failed")
    ///     }
    /// }
    /// 
    /// // Update both name and description
    /// let fullUpdate: [String: Any] = [
    ///     "displayName": "Enhanced Development Tools",
    ///     "description": "Comprehensive suite of development and debugging applications"
    /// ]
    /// XPCManager.shared.updateMobileAppCategory(
    ///     categoryId: categoryId,
    ///     updatedData: fullUpdate
    /// ) { success in
    ///     print("Full update: \(success == true ? "Success" : "Failed")")
    /// }
    /// 
    /// // Add description to existing category
    /// let descriptionUpdate: [String: Any] = [
    ///     "description": "Applications for data analysis and business intelligence"
    /// ]
    /// XPCManager.shared.updateMobileAppCategory(
    ///     categoryId: analyticsCategory,
    ///     updatedData: descriptionUpdate
    /// ) { success in
    ///     print("Description added: \(success == true ? "Success" : "Failed")")
    /// }
    /// ```
    /// 
    /// **Impact on Applications:**
    /// - Applications assigned to this category remain assigned
    /// - Category changes are immediately reflected in Intune console
    /// - App assignment configurations are preserved
    /// - No reassignment of applications required
    /// - Category filters and searches update automatically
    /// 
    /// **Common Use Cases:**
    /// - Correcting category naming mistakes
    /// - Updating category descriptions for clarity
    /// - Renaming categories to match organizational changes
    /// - Adding descriptions to existing categories
    /// - Standardizing category naming conventions
    /// 
    /// **Best Practices:**
    /// 1. Plan category name changes carefully (affects user experience)
    /// 2. Consider the impact on existing app organization
    /// 3. Update descriptions to maintain clarity
    /// 4. Use consistent naming conventions across updates
    /// 5. Communicate category changes to relevant stakeholders
    /// 
    /// **Required Permissions:**
    /// - DeviceManagementApps.ReadWrite.All (Application or Delegated)
    /// 
    /// - Parameters:
    ///   - categoryId: Unique identifier (GUID) of the category to update
    ///   - updatedData: Dictionary containing only the properties to update (partial update supported)
    ///   - completion: Callback indicating if update was successful (nil on XPC failure)
    func updateMobileAppCategory(categoryId: String, updatedData: [String: Any], completion: @escaping (Bool?) -> Void) {
        sendRequest({ $0.updateMobileAppCategory(categoryId: categoryId, updatedData: updatedData, reply: $1) }, completion: completion)
    }
    
    /// Permanently deletes a mobile app category from Microsoft Intune
    /// 
    /// **⚠️ CRITICAL WARNING: IRREVERSIBLE OPERATION WITH POTENTIAL APP IMPACT**
    /// 
    /// This function permanently removes an app category from Microsoft Intune. This operation
    /// has significant implications for app organization and should be used with extreme caution.
    /// 
    /// **Critical Impact:**
    /// - Category is permanently deleted and cannot be recovered
    /// - Applications currently assigned to this category may lose their categorization
    /// - Category-based filters and searches will no longer include this category
    /// - Reporting and analytics based on this category will be affected
    /// - All references to this category ID become invalid
    /// 
    /// **Key Features:**
    /// - Comprehensive pre-deletion validation
    /// - Automatic handling of app reassignments (per Microsoft policy)
    /// - Complete error handling and feedback
    /// - Irreversible operation with proper warnings
    /// 
    /// **Prerequisites and Recommendations:**
    /// 1. **Audit Applications**: First check which apps are assigned to this category
    /// 2. **Reassign Apps**: Move important apps to other categories before deletion
    /// 3. **Export Data**: Backup category information and app assignments if needed
    /// 4. **Stakeholder Approval**: Ensure organizational approval for category removal
    /// 5. **Impact Assessment**: Understand reporting and organizational impact
    /// 
    /// **Usage Example with Safety Checks:**
    /// ```swift
    /// // Step 1: Recommended safety check (implement app-to-category lookup first)
    /// func safeDeleteCategory(categoryId: String, categoryName: String) {
    ///     // Always confirm before deletion
    ///     let alert = NSAlert()
    ///     alert.messageText = "Delete Category '\(categoryName)'"
    ///     alert.informativeText = """
    ///         WARNING: This will permanently delete the category and may affect app organization.
    ///         
    ///         This action cannot be undone. Continue?
    ///         """
    ///     alert.addButton(withTitle: "Delete Category")
    ///     alert.addButton(withTitle: "Cancel")
    ///     alert.alertStyle = .critical
    ///     
    ///     if alert.runModal() == .alertFirstButtonReturn {
    ///         XPCManager.shared.deleteMobileAppCategory(categoryId: categoryId) { success in
    ///             DispatchQueue.main.async {
    ///                 if success == true {
    ///                     print("Category '\(categoryName)' deleted successfully")
    ///                     // Refresh category lists and update UI
    ///                     self.refreshCategoryData()
    ///                 } else if success == false {
    ///                     print("Failed to delete category '\(categoryName)'")
    ///                     // Show error to user
    ///                 } else {
    ///                     print("XPC communication failed during category deletion")
    ///                 }
    ///             }
    ///         }
    ///     }
    /// }
    /// 
    /// // Step 2: Call with proper safety measures
    /// safeDeleteCategory(categoryId: "category-guid", categoryName: "Old Category")
    /// ```
    /// 
    /// **Alternative Approaches:**
    /// Instead of deletion, consider:
    /// - **Renaming**: Update the category name to indicate deprecation
    /// - **Description Update**: Mark as deprecated in the description
    /// - **App Migration**: Move all apps to other categories first
    /// - **Archive Approach**: Rename to "Archived - [Original Name]"
    /// 
    /// **Recovery Considerations:**
    /// - **No Recovery**: Deleted categories cannot be restored
    /// - **Recreation**: You can create a new category with the same name, but it will have a different ID
    /// - **App Reassignment**: Apps will need to be manually reassigned to the recreated category
    /// - **Historical Data**: Some historical reporting data may be lost
    /// 
    /// **Common Use Cases:**
    /// - Cleaning up unused or obsolete categories
    /// - Consolidating similar categories
    /// - Removing test categories after deployment
    /// - Organizational restructuring of app categories
    /// 
    /// **Required Permissions:**
    /// - DeviceManagementApps.ReadWrite.All (Application or Delegated)
    /// 
    /// - Parameters:
    ///   - categoryId: Unique identifier (GUID) of the category to delete permanently
    ///   - completion: Callback indicating if deletion was successful (nil on XPC failure)
    func deleteMobileAppCategory(categoryId: String, completion: @escaping (Bool?) -> Void) {
        sendRequest({ $0.deleteMobileAppCategory(categoryId: categoryId, reply: $1) }, completion: completion)
    }

}
