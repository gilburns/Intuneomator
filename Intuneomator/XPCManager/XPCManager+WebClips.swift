//
//  XPCManager+WebClips.swift
//  Intuneomator
//
//  Created by Gil Burns on 7/7/25.
//

import Foundation

/// XPCManager extension for Microsoft Intune Web Clip management
/// Provides GUI access to web clip operations through the privileged XPC service
/// All operations require valid authentication credentials and appropriate Microsoft Graph permissions
extension XPCManager {
    
    // MARK: - Intune Web Clip Management Operations
    
    /// Retrieves all available macOS Web Clips from Microsoft Intune with comprehensive metadata
    /// 
    /// This function fetches all macOS Web Clips configured in Microsoft Intune, providing
    /// complete web clip information sorted alphabetically by display name. Web Clips are web
    /// bookmarks that appear as applications on macOS devices, enabling quick access to web
    /// content through app-like icons.
    /// 
    /// **Key Features:**
    /// - Retrieves complete web clip metadata
    /// - Automatic alphabetical sorting by display name
    /// - Comprehensive error handling
    /// - Optimized for large web clip lists
    /// - Support for pagination through Microsoft Graph API
    /// 
    /// **Returned Data Structure:**
    /// Each web clip dictionary contains:
    /// - `id`: Unique web clip identifier (GUID)
    /// - `displayName`: User-friendly web clip name
    /// - `appUrl`: Target URL for the web clip
    /// - `fullScreenEnabled`: Whether the web clip opens in full-screen mode
    /// - `preComposedIconEnabled`: Whether a custom icon is used
    /// - Additional Microsoft Graph web clip properties
    /// 
    /// **Usage Example:**
    /// ```swift
    /// XPCManager.shared.fetchIntuneWebClips { webClips in
    ///     if let webClips = webClips {
    ///         print("Found \(webClips.count) web clips")
    ///         for webClip in webClips {
    ///             let name = webClip["displayName"] as? String ?? "Unknown"
    ///             let url = webClip["appUrl"] as? String ?? "Unknown"
    ///             let id = webClip["id"] as? String ?? "Unknown"
    ///             print("- \(name): \(url) (ID: \(id))")
    ///         }
    ///     } else {
    ///         print("Failed to fetch web clips")
    ///     }
    /// }
    /// ```
    /// 
    /// **Common Use Cases:**
    /// - Populating web clip selection UI components
    /// - Building web clip management interfaces
    /// - Auditing existing web clip configuration
    /// - Web clip deployment and organization workflows
    /// - Creating web clip assignment interfaces
    /// 
    /// **Required Permissions:**
    /// - DeviceManagementApps.Read.All (Application or Delegated)
    /// 
    /// - Parameter completion: Callback with array of web clip dictionaries (sorted by display name) or nil on failure
    func fetchIntuneWebClips(completion: @escaping ([[String: Any]]?) -> Void) {
        sendRequest({ $0.fetchIntuneWebClips(reply: $1) }, completion: completion)
    }
    
    /// Creates a new macOS Web Clip in Microsoft Intune with comprehensive validation and error handling
    /// 
    /// This function creates a new web clip in Microsoft Intune, enabling users to access web content
    /// through app-like icons on their macOS devices. Web Clips provide a seamless way to integrate
    /// web-based tools and resources into the device's application workflow.
    /// 
    /// **Key Features:**
    /// - Comprehensive input validation
    /// - Automatic URL format checking by Microsoft Graph
    /// - Immediate availability for device assignment
    /// - Complete error handling with detailed feedback
    /// - Support for custom icons and full-screen display
    /// 
    /// **Web Clip Data Structure:**
    /// Required fields:
    /// ```swift
    /// let webClipData: [String: Any] = [
    ///     "@odata.type": "#microsoft.graph.macOSWebClip",
    ///     "displayName": "Company Portal",           // Required: User-friendly web clip name
    ///     "appUrl": "https://portal.company.com"     // Required: Target URL (must start with http:// or https://)
    /// ]
    /// ```
    /// 
    /// Optional fields:
    /// ```swift
    /// let enhancedWebClipData: [String: Any] = [
    ///     "@odata.type": "#microsoft.graph.macOSWebClip",
    ///     "displayName": "Development Dashboard",
    ///     "appUrl": "https://dev.company.com",
    ///     "fullScreenEnabled": true,                  // Open in full-screen mode
    ///     "preComposedIconEnabled": false            // Use system-generated icon
    /// ]
    /// ```
    /// 
    /// **Usage Examples:**
    /// ```swift
    /// // Basic web clip creation
    /// let webClipData: [String: Any] = [
    ///     "@odata.type": "#microsoft.graph.macOSWebClip",
    ///     "displayName": "Employee Self-Service",
    ///     "appUrl": "https://selfservice.company.com"
    /// ]
    /// XPCManager.shared.createIntuneWebClip(webClipData: webClipData) { webClipId in
    ///     if let webClipId = webClipId {
    ///         print("Web clip created successfully with ID: \(webClipId)")
    ///         // Now you can assign this web clip to device groups
    ///     } else {
    ///         print("Failed to create web clip")
    ///     }
    /// }
    /// 
    /// // Advanced web clip creation with custom settings
    /// let advancedWebClip: [String: Any] = [
    ///     "@odata.type": "#microsoft.graph.macOSWebClip",
    ///     "displayName": "Analytics Dashboard",
    ///     "appUrl": "https://analytics.company.com",
    ///     "fullScreenEnabled": true,
    ///     "preComposedIconEnabled": true
    /// ]
    /// XPCManager.shared.createIntuneWebClip(webClipData: advancedWebClip) { webClipId in
    ///     if let webClipId = webClipId {
    ///         print("Advanced web clip created: \(webClipId)")
    ///     }
    /// }
    /// ```
    /// 
    /// **Best Practices:**
    /// 1. Use clear, descriptive web clip names that indicate their purpose
    /// 2. Ensure URLs are accessible from target devices
    /// 3. Test web clips with different screen sizes and resolutions
    /// 4. Consider using HTTPS URLs for security
    /// 5. Plan web clip organization before mass creation
    /// 6. Verify web content is mobile/tablet optimized
    /// 
    /// **URL Requirements:**
    /// - Must start with `http://` or `https://`
    /// - Should be publicly accessible or accessible via VPN
    /// - Consider responsive design for various screen sizes
    /// - Test with authentication requirements if applicable
    /// 
    /// **Required Permissions:**
    /// - DeviceManagementApps.ReadWrite.All (Application or Delegated)
    /// 
    /// - Parameters:
    ///   - webClipData: Dictionary containing web clip information (displayName and appUrl are required)
    ///   - completion: Callback with the unique web clip ID (GUID) or nil on failure
    func createIntuneWebClip(webClipData: [String: Any], completion: @escaping (String?) -> Void) {
        sendRequest({ $0.createIntuneWebClip(webClipData: webClipData, reply: $1) }, completion: completion)
    }
    
    /// Updates an existing macOS Web Clip in Microsoft Intune with comprehensive change management
    /// 
    /// This function modifies an existing web clip's properties in Microsoft Intune. Supports
    /// partial updates where only specified properties are changed, leaving all other properties
    /// unchanged. Updates take effect immediately for future deployments and existing installations.
    /// 
    /// **Key Features:**
    /// - Partial update support (only changed properties required)
    /// - Maintains existing device assignments
    /// - Immediate effect on web clip metadata
    /// - Comprehensive error handling and validation
    /// - Preserves deployment configurations
    /// 
    /// **Updatable Properties:**
    /// - `displayName`: Change the web clip's display name
    /// - `appUrl`: Update the target URL
    /// - `fullScreenEnabled`: Modify full-screen behavior
    /// - `preComposedIconEnabled`: Change icon handling
    /// - Additional properties as supported by Microsoft Graph
    /// 
    /// **Usage Examples:**
    /// ```swift
    /// // Update web clip URL only
    /// let urlUpdate: [String: Any] = [
    ///     "appUrl": "https://newdomain.company.com"
    /// ]
    /// XPCManager.shared.updateWebClip(
    ///     webClipId: "12345-abcde-67890",
    ///     updatedData: urlUpdate
    /// ) { success in
    ///     if success == true {
    ///         print("Web clip URL updated successfully")
    ///     } else if success == false {
    ///         print("Failed to update web clip URL")
    ///     } else {
    ///         print("XPC communication failed")
    ///     }
    /// }
    /// 
    /// // Update display name and enable full-screen
    /// let displayUpdate: [String: Any] = [
    ///     "displayName": "Updated Company Portal",
    ///     "fullScreenEnabled": true
    /// ]
    /// XPCManager.shared.updateWebClip(
    ///     webClipId: webClipId,
    ///     updatedData: displayUpdate
    /// ) { success in
    ///     print("Display update: \(success == true ? "Success" : "Failed")")
    /// }
    /// 
    /// // Enable custom icon handling
    /// let iconUpdate: [String: Any] = [
    ///     "preComposedIconEnabled": true
    /// ]
    /// XPCManager.shared.updateWebClip(
    ///     webClipId: portalClipId,
    ///     updatedData: iconUpdate
    /// ) { success in
    ///     print("Icon setting updated: \(success == true ? "Success" : "Failed")")
    /// }
    /// ```
    /// 
    /// **Impact on Devices:**
    /// - Devices assigned to this web clip retain their assignments
    /// - Web clip changes are reflected in future installations
    /// - Existing installations may require manual refresh or reinstallation
    /// - Device assignment configurations are preserved
    /// - Web clip filters and searches update automatically
    /// 
    /// **Common Use Cases:**
    /// - Updating URLs when services migrate to new domains
    /// - Correcting web clip naming mistakes
    /// - Modifying display settings for better user experience
    /// - Updating web clips to match organizational changes
    /// - Enhancing web clip configuration with new features
    /// 
    /// **Best Practices:**
    /// 1. Test URL changes in a development environment first
    /// 2. Consider the impact on existing device deployments
    /// 3. Communicate web clip changes to affected users
    /// 4. Use consistent naming conventions across updates
    /// 5. Verify updated URLs are accessible from target devices
    /// 
    /// **Required Permissions:**
    /// - DeviceManagementApps.ReadWrite.All (Application or Delegated)
    /// 
    /// - Parameters:
    ///   - webClipId: Unique identifier (GUID) of the web clip to update
    ///   - updatedData: Dictionary containing only the properties to update (partial update supported)
    ///   - completion: Callback indicating if update was successful (nil on XPC failure)
    func updateWebClip(webClipId: String, updatedData: [String: Any], completion: @escaping (Bool?) -> Void) {
        sendRequest({ $0.updateWebClip(webClipId: webClipId, updatedData: updatedData, reply: $1) }, completion: completion)
    }
    
    /// Permanently deletes a macOS Web Clip from Microsoft Intune
    /// 
    /// **⚠️ CRITICAL WARNING: IRREVERSIBLE OPERATION WITH POTENTIAL DEVICE IMPACT**
    /// 
    /// This function permanently removes a web clip from Microsoft Intune. This operation
    /// has significant implications for device access to web resources and should be used with extreme caution.
    /// 
    /// **Critical Impact:**
    /// - Web clip is permanently deleted and cannot be recovered
    /// - Devices with this web clip installed may lose access to the web resource
    /// - Assignment configurations are permanently lost
    /// - All references to this web clip ID become invalid
    /// - Users may lose bookmarked access to important web resources
    /// 
    /// **Key Features:**
    /// - Comprehensive pre-deletion validation
    /// - Automatic handling of device uninstallations (per Microsoft policy)
    /// - Complete error handling and feedback
    /// - Irreversible operation with proper warnings
    /// 
    /// **Prerequisites and Recommendations:**
    /// 1. **Audit Assignments**: First check which device groups have this web clip assigned
    /// 2. **User Communication**: Notify users about the removal of web access
    /// 3. **Alternative Access**: Provide alternative methods to access the web resource
    /// 4. **Export Configuration**: Backup web clip settings if needed for recreation
    /// 5. **Stakeholder Approval**: Ensure organizational approval for web clip removal
    /// 
    /// **Usage Example with Safety Checks:**
    /// ```swift
    /// // Step 1: Recommended safety check
    /// func safeDeleteWebClip(webClipId: String, webClipName: String, webClipUrl: String) {
    ///     // Always confirm before deletion
    ///     let alert = NSAlert()
    ///     alert.messageText = "Delete Web Clip '\(webClipName)'"
    ///     alert.informativeText = """
    ///         WARNING: This will permanently delete the web clip and remove device access to:
    ///         \(webClipUrl)
    ///         
    ///         This action cannot be undone. Continue?
    ///         """
    ///     alert.addButton(withTitle: "Delete Web Clip")
    ///     alert.addButton(withTitle: "Cancel")
    ///     alert.alertStyle = .critical
    ///     
    ///     if alert.runModal() == .alertFirstButtonReturn {
    ///         XPCManager.shared.deleteWebClip(webClipId: webClipId) { success in
    ///             DispatchQueue.main.async {
    ///                 if success == true {
    ///                     print("Web clip '\(webClipName)' deleted successfully")
    ///                     // Refresh web clip lists and update UI
    ///                     self.refreshWebClipData()
    ///                 } else if success == false {
    ///                     print("Failed to delete web clip '\(webClipName)'")
    ///                     // Show error to user
    ///                 } else {
    ///                     print("XPC communication failed during web clip deletion")
    ///                 }
    ///             }
    ///         }
    ///     }
    /// }
    /// 
    /// // Step 2: Call with proper safety measures
    /// safeDeleteWebClip(
    ///     webClipId: "webclip-guid", 
    ///     webClipName: "Old Portal", 
    ///     webClipUrl: "https://old.company.com"
    /// )
    /// ```
    /// 
    /// **Alternative Approaches:**
    /// Instead of deletion, consider:
    /// - **URL Update**: Redirect to a new location or maintenance page
    /// - **Display Name Update**: Mark as deprecated in the name
    /// - **Assignment Removal**: Remove device assignments but keep the web clip
    /// - **Replacement Strategy**: Create new web clip before removing old one
    /// 
    /// **Recovery Considerations:**
    /// - **No Recovery**: Deleted web clips cannot be restored
    /// - **Recreation**: You can create a new web clip with the same name and URL, but it will have a different ID
    /// - **Device Reassignment**: Devices will need new assignments to the recreated web clip
    /// - **User Impact**: Users may lose convenient access to web resources
    /// 
    /// **Common Use Cases:**
    /// - Removing access to discontinued web services
    /// - Cleaning up obsolete or unused web clips
    /// - Consolidating similar web access points
    /// - Removing test web clips after deployment
    /// - Organizational restructuring of web access
    /// 
    /// **Required Permissions:**
    /// - DeviceManagementApps.ReadWrite.All (Application or Delegated)
    /// 
    /// - Parameters:
    ///   - webClipId: Unique identifier (GUID) of the web clip to delete permanently
    ///   - completion: Callback indicating if deletion was successful (nil on XPC failure)
    func deleteWebClip(webClipId: String, completion: @escaping (Bool?) -> Void) {
        sendRequest({ $0.deleteWebClip(webClipId: webClipId, reply: $1) }, completion: completion)
    }
    
    /// Fetches complete web clip details including icon, group assignments, and category assignments
    /// 
    /// This function retrieves comprehensive web clip information for editing workflows,
    /// including the complete web clip configuration, icon data, assignments, and categories.
    /// This provides all data needed to populate the editing interface with current settings.
    /// 
    /// **Key Features:**
    /// - Concurrent fetching of web clip details, assignments, and categories for optimal performance
    /// - Complete web clip metadata including icon data (largeIcon)
    /// - Assignment metadata with group information and assignment types
    /// - Category information with names and IDs for proper display
    /// - Comprehensive error handling and logging
    /// - Optimized for editing workflows
    /// 
    /// **Returned Data Structure:**
    /// The completion handler receives a dictionary containing complete web clip data:
    /// ```swift
    /// [
    ///     // Complete web clip properties
    ///     "id": "web-clip-guid",
    ///     "displayName": "Web Clip Name",
    ///     "appUrl": "https://example.com",
    ///     "description": "Web clip description",
    ///     "fullScreenEnabled": true,
    ///     "preComposedIconEnabled": false,
    ///     "largeIcon": [
    ///         "@odata.type": "#microsoft.graph.mimeContent",
    ///         "type": "image/png",
    ///         "value": "base64-encoded-image-data"
    ///     ],
    ///     // Assignment data
    ///     "assignments": [
    ///         [
    ///             "id": "assignment-guid",
    ///             "target": [
    ///                 "@odata.type": "#microsoft.graph.groupAssignmentTarget",
    ///                 "groupId": "group-guid"
    ///             ],
    ///             "intent": "required" | "available" | "uninstall"
    ///         ]
    ///     ],
    ///     // Category data
    ///     "categories": [
    ///         [
    ///             "id": "category-guid",
    ///             "displayName": "Category Name"
    ///         ]
    ///     ]
    /// ]
    /// ```
    /// 
    /// **Usage Example:**
    /// ```swift
    /// XPCManager.shared.fetchWebClipAssignmentsAndCategories(webClipId: "web-clip-guid") { fullWebClipData in
    ///     if let completeData = fullWebClipData {
    ///         // Extract web clip properties
    ///         let displayName = completeData["displayName"] as? String ?? ""
    ///         let appUrl = completeData["appUrl"] as? String ?? ""
    ///         
    ///         // Extract icon data if available
    ///         if let iconData = completeData["largeIcon"] as? [String: Any],
    ///            let base64String = iconData["value"] as? String {
    ///             // Decode and display icon
    ///         }
    ///         
    ///         // Extract assignments and categories
    ///         let assignments = completeData["assignments"] as? [[String: Any]] ?? []
    ///         let categories = completeData["categories"] as? [[String: Any]] ?? []
    ///         
    ///         print("Loaded web clip '\(displayName)' with \(assignments.count) assignments and \(categories.count) categories")
    ///         
    ///         // Pass complete data to editor
    ///         DispatchQueue.main.async {
    ///             self.openWebClipEditor(with: completeData)
    ///         }
    ///     } else {
    ///         print("Failed to fetch complete web clip data")
    ///     }
    /// }
    /// ```
    /// 
    /// **Assignment Types:**
    /// - **Required**: Must be installed on target devices
    /// - **Available**: Available for users to install from Company Portal
    /// - **Uninstall**: Remove the web clip from target devices
    /// 
    /// **Target Types:**
    /// - **Group Assignment**: Targets specific Azure AD groups
    /// - **All Users**: Targets all users in the tenant
    /// - **All Devices**: Targets all devices in the tenant
    /// 
    /// **Common Use Cases:**
    /// - Pre-populating assignment interface when editing existing web clips
    /// - Preserving existing assignments during web clip updates
    /// - Auditing current web clip deployment configuration
    /// - Building assignment management interfaces
    /// - Creating assignment comparison and diff views
    /// 
    /// **Performance Considerations:**
    /// - Assignments and categories are fetched concurrently for optimal speed
    /// - Data is cached temporarily within the editing session
    /// - Large assignment lists are handled efficiently
    /// - Network requests are optimized for minimal latency
    /// 
    /// **Error Handling:**
    /// The completion handler will receive `nil` if:
    /// - Network connectivity issues occur
    /// - Authentication tokens are invalid or expired
    /// - The web clip ID is not found in Intune
    /// - Insufficient permissions to access assignment data
    /// - API rate limits are exceeded
    /// 
    /// **Required Permissions:**
    /// - DeviceManagementApps.Read.All (Application or Delegated)
    /// 
    /// - Parameters:
    ///   - webClipId: Unique identifier (GUID) of the web clip to fetch assignment data for
    ///   - completion: Callback with assignment and category data dictionary or nil on failure
    func fetchWebClipAssignmentsAndCategories(webClipId: String, completion: @escaping ([String: Any]?) -> Void) {
        sendRequest({ $0.fetchWebClipAssignmentsAndCategories(webClipId: webClipId, reply: $1) }, completion: completion)
    }
    
    /// Updates an existing web clip with categories and group assignments in a comprehensive workflow
    /// 
    /// This function handles the complete update workflow for web clips that includes updating
    /// the web clip properties, categories, and group assignments. It follows a structured
    /// approach: PATCH web clip → update categories → update assignments.
    /// 
    /// **Key Features:**
    /// - Complete update workflow handling all web clip aspects
    /// - Automatic handling of categories and group assignment changes
    /// - Sequential operations with proper error handling
    /// - Rollback-resistant design (continues with remaining operations on partial failures)
    /// - Comprehensive logging and error reporting
    /// 
    /// **Update Sequence:**
    /// 1. **Web Clip Update**: PATCH request to update basic web clip properties
    /// 2. **Category Assignment**: Update category assignments if categories were changed
    /// 3. **Group Assignment**: Update group assignments if assignments were changed
    /// 
    /// **Required Permissions:**
    /// - DeviceManagementApps.ReadWrite.All (Application or Delegated)
    /// 
    /// - Parameters:
    ///   - webClipData: Complete web clip data including properties, categories, and assignments
    ///   - completion: Callback indicating if the complete update workflow was successful
    func updateWebClipWithAssignments(webClipData: [String: Any], completion: @escaping (Bool?) -> Void) {
        sendRequest({ $0.updateWebClipWithAssignments(webClipData: webClipData, reply: $1) }, completion: completion)
    }

}
