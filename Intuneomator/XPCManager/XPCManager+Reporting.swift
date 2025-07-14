//
//  XPCManager+Reporting.swift
//  Intuneomator
//
//  Created by Gil Burns on 7/11/25.
//

import Foundation

extension XPCManager {
    // MARK: - Intune App Management Operations
    
    /// Retrieves all available Intune apps from Microsoft Intune with comprehensive metadata
    ///
    /// This function fetches all apps configured in Microsoft Intune, providing
    /// complete information sorted alphabetically by display name.
    ///
    /// **Key Features:**
    /// - Retrieves complete app metadata
    /// - Automatic alphabetical sorting by display name
    /// - Comprehensive error handling
    /// - Optimized for large app lists
    /// - Support for pagination through Microsoft Graph API
    ///
    /// **Returned Data Structure:**
    /// Each Intune app dictionary contains:
    /// - `id`: Unique app identifier (GUID)
    /// - `displayName`: User-friendly app name
    /// - `@odata.type`: Indicator for the type of deployment
    /// - Additional Microsoft Graph app app properties
    ///
    /// **Usage Example:**
    /// ```swift
    /// XPCManager.shared.fetchIntuneApps { intuneApps in
    ///     if let intuneApps = intuneApps {
    ///         print("Found \(intuneApps.count) Intune apps")
    ///         for intuneApp in intuneApps {
    ///             let name = intuneApp["displayName"] as? String ?? "Unknown"
    ///             let url = intuneApp["@odata.type"] as? String ?? "Unknown"
    ///             let id = intuneApp["id"] as? String ?? "Unknown"
    ///             print("- \(name): \(url) (ID: \(id))")
    ///         }
    ///     } else {
    ///         print("Failed to fetch Intune apps")
    ///     }
    /// }
    /// ```
    ///
    /// **Common Use Cases:**
    /// - Populating app selection UI components
    /// - Building app management interfaces
    /// - Auditing existing app configuration
    /// - App deployment and organization workflows
    /// - Creating app assignment interfaces
    ///
    /// **Required Permissions:**
    /// - DeviceManagementApps.Read.All (Application or Delegated)
    ///
    /// - Parameter completion: Callback with array of Intune app dictionaries (sorted by display name) or nil on failure
    func fetchIntuneApps(completion: @escaping ([[String: Any]]?) -> Void) {
        sendRequest({ $0.fetchIntuneApps(reply: $1) }, completion: completion)
    }

    // MARK: - Intune App Installation Status Reports
    
    /// Retrieves device app installation status report for a specific app from Microsoft Graph reports endpoint
    ///
    /// This function fetches detailed installation status information for a specific Intune app across all assigned devices,
    /// providing comprehensive insights into app deployment effectiveness, installation failures, and device compliance.
    /// Essential for monitoring app rollout success and troubleshooting installation issues.
    ///
    /// **Key Features:**
    /// - Complete device installation history and current status
    /// - Detailed error information for failed installations
    /// - Device information with names and user details
    /// - Installation timestamps for performance analysis
    /// - Automatic pagination support for large device fleets
    /// - Sorted results by device name for consistent presentation
    ///
    /// **Returned Data Structure:**
    /// Each device installation record dictionary contains comprehensive installation information:
    /// - `DeviceId`: Unique device identifier (GUID) 
    /// - `DeviceName`: Device hostname for identification
    /// - `UserId`: User identifier associated with the device
    /// - `UserPrincipalName`: User's email/UPN for the device assignment
    /// - `UserName`: User's display name
    /// - `InstallState`: Installation status ("installed", "failed", "notInstalled", "uninstallFailed", "pendingInstall", "unknown")
    /// - `InstallStateDetail`: Detailed installation state information
    /// - `AppVersion`: Version of the app that was installed or attempted
    /// - `ErrorCode`: Numeric error code for failed installations (0 for success)
    /// - `LastModifiedDateTime`: ISO 8601 timestamp of last status update (format with .formatIntuneDate())
    ///
    /// **Installation State Interpretation:**
    /// - `installed`: App successfully installed and functional on device
    /// - `failed`: Installation attempt failed due to system/network/permission issues
    /// - `notInstalled`: App assigned but not yet installed on device
    /// - `uninstallFailed`: App removal attempt failed
    /// - `pendingInstall`: Installation queued but not yet attempted
    /// - `unknown`: Installation status could not be determined
    ///
    /// **Usage Example:**
    /// ```swift
    /// XPCManager.shared.getDeviceAppInstallationStatusReport(appId: "app-guid-here") { installationStatus in
    ///     if let installationStatus = installationStatus {
    ///         print("Installation status for \\(installationStatus.count) devices:")
    ///         
    ///         // Analyze installation outcomes
    ///         let installedCount = installationStatus.filter { ($0["InstallState"] as? String) == "installed" }.count
    ///         let failedCount = installationStatus.filter { ($0["InstallState"] as? String) == "failed" }.count
    ///         let pendingCount = installationStatus.filter { ($0["InstallState"] as? String) == "pendingInstall" }.count
    ///         
    ///         print("Installed: \\(installedCount), Failed: \\(failedCount), Pending: \\(pendingCount)")
    ///         
    ///         // Display detailed results
    ///         for deviceStatus in installationStatus {
    ///             let installState = deviceStatus["InstallState"] as? String ?? "unknown"
    ///             let deviceName = deviceStatus["DeviceName"] as? String ?? "Unknown Device"
    ///             let appVersion = deviceStatus["AppVersion"] as? String ?? "Unknown"
    ///             let lastModified = (deviceStatus["LastModifiedDateTime"] as? String ?? "Never").formatIntuneDate()
    ///             
    ///             print("\\(deviceName): \\(installState) (v\\(appVersion)) - Last updated: \\(lastModified)")
    ///             
    ///             // Show error details for failed installations
    ///             if installState == "failed", 
    ///                let errorCode = deviceStatus["ErrorCode"] as? Int, errorCode != 0 {
    ///                 print("  Error Code: \\(errorCode)")
    ///                 if let installStateDetail = deviceStatus["InstallStateDetail"] as? String {
    ///                     print("  Details: \\(installStateDetail)")
    ///                 }
    ///             }
    ///         }
    ///     } else {
    ///         print("Failed to retrieve app installation status")
    ///     }
    /// }
    /// ```
    ///
    /// **Advanced Usage - Installation Compliance Report:**
    /// ```swift
    /// XPCManager.shared.getDeviceAppInstallationStatusReport(appId: appId) { installationStatus in
    ///     guard let installationStatus = installationStatus else { return }
    ///     
    ///     // Generate compliance report
    ///     let complianceData = installationStatus.compactMap { deviceStatus -> [String: Any]? in
    ///         guard let deviceName = deviceStatus["DeviceName"] as? String else { return nil }
    ///         
    ///         let installState = deviceStatus["InstallState"] as? String ?? "unknown"
    ///         let appVersion = deviceStatus["AppVersion"] as? String ?? "Unknown"
    ///         let lastModified = deviceStatus["LastModifiedDateTime"] as? String ?? ""
    ///         let isCompliant = installState == "installed"
    ///         
    ///         return [
    ///             "deviceName": deviceName,
    ///             "compliant": isCompliant,
    ///             "installState": installState,
    ///             "appVersion": appVersion,
    ///             "lastUpdate": lastModified.formatIntuneDate()
    ///         ]
    ///     }
    ///     
    ///     // Export or display compliance report
    ///     exportInstallationComplianceReport(complianceData)
    /// }
    /// ```
    ///
    /// **Common Use Cases:**
    /// - Monitoring app deployment success across device fleet
    /// - Troubleshooting installation failures on specific devices
    /// - Generating installation compliance and status reports for management
    /// - Identifying devices requiring attention or manual intervention
    /// - Performance analysis of app deployment timing and success rates
    /// - Audit trail for app installation and management activities
    ///
    /// **Performance Considerations:**
    /// - Results are automatically paginated for large device environments
    /// - Device and user information is efficiently retrieved in single API call
    /// - Results are pre-sorted by device name for UI consistency
    /// - Consider caching results for frequently accessed installation data
    ///
    /// **Required Permissions:**
    /// - DeviceManagementApps.Read.All (Application or Delegated)
    /// - DeviceManagementManagedDevices.Read.All (for device information)
    /// - DeviceManagementConfiguration.Read.All (for reports access)
    ///
    /// - Parameters:
    ///   - appId: Unique identifier (GUID) of the app to get installation status for
    ///   - completion: Callback with array of device installation status dictionaries or nil on failure (including XPC failure)
    func getDeviceAppInstallationStatusReport(appId: String, completion: @escaping ([[String: Any]]?) -> Void) {
        sendRequest({ service, reply in
            service.getDeviceAppInstallationStatusReport(appId: appId, reply: reply)
        }, completion: completion)
    }
 
}
