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

    // MARK: - Intune Configuration Profile Management Operations
    
    /// Retrieves all available Intune configuration profiles from Microsoft Intune with comprehensive metadata and assignment status
    ///
    /// This function fetches all configuration profiles configured in Microsoft Intune across all platforms (Windows, macOS, iOS, Android),
    /// providing complete information sorted alphabetically by display name with assignment status information.
    ///
    /// **Key Features:**
    /// - Retrieves configuration profiles for all platforms (Windows, macOS, iOS, Android)
    /// - Complete profile metadata including creation and modification dates
    /// - Assignment status checking (isAssigned field)
    /// - Automatic alphabetical sorting by display name
    /// - Comprehensive error handling
    /// - Optimized for large profile lists
    /// - Support for pagination through Microsoft Graph API
    ///
    /// **Returned Data Structure:**
    /// Each Intune configuration profile dictionary contains:
    /// - `id`: Unique profile identifier (GUID)
    /// - `displayName`: User-friendly profile name
    /// - `@odata.type`: Profile type indicating platform and configuration type
    /// - `description`: Profile description
    /// - `version`: Profile version number
    /// - `createdDateTime`: ISO 8601 timestamp when profile was created
    /// - `lastModifiedDateTime`: ISO 8601 timestamp when profile was last modified
    /// - `isAssigned`: Boolean indicating whether profile is assigned to any groups
    /// - `assignments`: Array of assignment objects (groups, filters, etc.)
    ///
    /// **Profile Types Included:**
    /// - **Windows**: Device restrictions, endpoint protection, custom policies, Wi-Fi, VPN
    /// - **macOS**: Device features, extensions, custom profiles, system preferences
    /// - **iOS/iPadOS**: Device restrictions, app configuration, VPN profiles, Wi-Fi settings
    /// - **Android**: Device administrator, work profile, app configuration, compliance policies
    ///
    /// **Usage Example:**
    /// ```swift
    /// XPCManager.shared.fetchIntuneConfigurationProfiles { configProfiles in
    ///     if let configProfiles = configProfiles {
    ///         print("Found \(configProfiles.count) configuration profiles")
    ///         
    ///         // Filter by assignment status
    ///         let assignedProfiles = configProfiles.filter { ($0["isAssigned"] as? Bool) == true }
    ///         let unassignedProfiles = configProfiles.filter { ($0["isAssigned"] as? Bool) == false }
    ///         
    ///         print("Assigned: \(assignedProfiles.count), Unassigned: \(unassignedProfiles.count)")
    ///         
    ///         // Display profile information
    ///         for profile in configProfiles {
    ///             let name = profile["displayName"] as? String ?? "Unknown"
    ///             let type = profile["@odata.type"] as? String ?? "Unknown"
    ///             let id = profile["id"] as? String ?? "Unknown"
    ///             let isAssigned = (profile["isAssigned"] as? Bool) == true ? "✅" : "☑️"
    ///             let created = (profile["createdDateTime"] as? String ?? "").formatIntuneDate()
    ///             
    ///             print("- \(name) \(isAssigned)")
    ///             print("  Type: \(type)")
    ///             print("  Created: \(created)")
    ///             print("  ID: \(id)")
    ///         }
    ///     } else {
    ///         print("Failed to fetch configuration profiles")
    ///     }
    /// }
    /// ```
    ///
    /// **Advanced Usage - Profile Analysis:**
    /// ```swift
    /// XPCManager.shared.fetchIntuneConfigurationProfiles { configProfiles in
    ///     guard let configProfiles = configProfiles else { return }
    ///     
    ///     // Analyze profiles by platform
    ///     let platformStats = configProfiles.reduce(into: [String: Int]()) { stats, profile in
    ///         if let odataType = profile["@odata.type"] as? String {
    ///             let platform = extractPlatform(from: odataType)
    ///             stats[platform, default: 0] += 1
    ///         }
    ///     }
    ///     
    ///     print("Configuration Profiles by Platform:")
    ///     for (platform, count) in platformStats.sorted(by: { $0.key < $1.key }) {
    ///         print("  \(platform): \(count) profiles")
    ///     }
    ///     
    ///     // Find recently modified profiles (last 30 days)
    ///     let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
    ///     let recentProfiles = configProfiles.filter { profile in
    ///         guard let lastModifiedString = profile["lastModifiedDateTime"] as? String,
    ///               let lastModified = ISO8601DateFormatter().date(from: lastModifiedString) else {
    ///             return false
    ///         }
    ///         return lastModified > thirtyDaysAgo
    ///     }
    ///     
    ///     print("\\nRecently Modified Profiles (last 30 days): \(recentProfiles.count)")
    ///     for profile in recentProfiles.sorted(by: { 
    ///         let date1 = ($0["lastModifiedDateTime"] as? String) ?? ""
    ///         let date2 = ($1["lastModifiedDateTime"] as? String) ?? ""
    ///         return date1 > date2
    ///     }) {
    ///         let name = profile["displayName"] as? String ?? "Unknown"
    ///         let lastModified = (profile["lastModifiedDateTime"] as? String ?? "").formatIntuneDate()
    ///         print("  - \(name) (modified: \(lastModified))")
    ///     }
    /// }
    /// ```
    ///
    /// **Common Use Cases:**
    /// - Populating configuration profile selection UI components
    /// - Building profile management and assignment interfaces
    /// - Auditing existing configuration profile deployment
    /// - Profile deployment and organization workflows
    /// - Creating profile assignment reporting and analytics
    /// - Identifying unassigned or unused configuration profiles
    /// - Platform-specific configuration management
    ///
    /// **Performance Considerations:**
    /// - Results are automatically paginated for large profile environments
    /// - Assignment information is efficiently retrieved in single API call using $expand
    /// - Results are pre-sorted by display name for UI consistency
    /// - Consider caching results for frequently accessed profile data
    ///
    /// **Required Permissions:**
    /// - DeviceManagementConfiguration.Read.All (Application or Delegated)
    /// - DeviceManagementManagedDevices.Read.All (for assignment information)
    ///
    /// - Parameter completion: Callback with array of Intune configuration profile dictionaries (sorted by display name) or nil on failure
    func fetchIntuneConfigurationProfiles(completion: @escaping ([[String: Any]]?) -> Void) {
        sendRequest({ $0.fetchIntuneConfigurationProfiles(reply: $1) }, completion: completion)
    }

    // MARK: - Intune Configuration Profile Deployment Status Reports
    
    /// Retrieves device configuration profile deployment status report for a specific profile from Microsoft Graph reports endpoint
    ///
    /// This function fetches detailed deployment status information for a specific Intune configuration profile across all assigned devices,
    /// providing comprehensive insights into profile deployment effectiveness, configuration compliance, and device policy status.
    /// Essential for monitoring configuration profile rollout success and troubleshooting deployment issues.
    ///
    /// **Key Features:**
    /// - Complete device deployment history and current compliance status
    /// - Detailed error information for failed deployments
    /// - Device information with names and user details
    /// - Deployment timestamps for performance analysis
    /// - Automatic pagination support for large device fleets
    /// - Sorted results by device name for consistent presentation
    ///
    /// **Returned Data Structure:**
    /// Each device deployment record dictionary contains comprehensive deployment information:
    /// - `DeviceId`: Unique device identifier (GUID) 
    /// - `DeviceName`: Device hostname for identification
    /// - `UserId`: User identifier associated with the device
    /// - `UserPrincipalName`: User's email/UPN for the device assignment
    /// - `UserName`: User's display name
    /// - `PolicyId`: Configuration profile identifier (GUID)
    /// - `PolicyName`: Configuration profile display name
    /// - `ComplianceStatus`: Deployment status ("Compliant", "NonCompliant", "InGracePeriod", "NotApplicable", "Error", "Unknown")
    /// - `LastReportedDateTime`: ISO 8601 timestamp of last status update (format with .formatIntuneDate())
    /// - `ErrorCode`: Numeric error code for failed deployments (0 for success)
    /// - `ErrorDescription`: Human-readable error description for failed deployments
    ///
    /// **Compliance Status Interpretation:**
    /// - `Compliant`: Configuration profile successfully applied and device is compliant
    /// - `NonCompliant`: Device does not meet the configuration profile requirements
    /// - `InGracePeriod`: Device is non-compliant but within grace period for remediation
    /// - `NotApplicable`: Configuration profile is not applicable to this device
    /// - `Error`: Deployment failed due to system/network/permission issues
    /// - `Unknown`: Deployment status could not be determined
    ///
    /// **Usage Example:**
    /// ```swift
    /// XPCManager.shared.getDeviceConfigProfileDeploymentStatusReport(profileId: "profile-guid-here") { deploymentStatus in
    ///     if let deploymentStatus = deploymentStatus {
    ///         print("Deployment status for \\(deploymentStatus.count) devices:")
    ///         
    ///         // Analyze deployment outcomes
    ///         let compliantCount = deploymentStatus.filter { ($0["ComplianceStatus"] as? String) == "Compliant" }.count
    ///         let nonCompliantCount = deploymentStatus.filter { ($0["ComplianceStatus"] as? String) == "NonCompliant" }.count
    ///         let errorCount = deploymentStatus.filter { ($0["ComplianceStatus"] as? String) == "Error" }.count
    ///         
    ///         print("Compliant: \\(compliantCount), Non-Compliant: \\(nonCompliantCount), Errors: \\(errorCount)")
    ///         
    ///         // Display detailed results
    ///         for deviceStatus in deploymentStatus {
    ///             let complianceStatus = deviceStatus["ComplianceStatus"] as? String ?? "unknown"
    ///             let deviceName = deviceStatus["DeviceName"] as? String ?? "Unknown Device"
    ///             let policyName = deviceStatus["PolicyName"] as? String ?? "Unknown Policy"
    ///             let lastReported = (deviceStatus["LastReportedDateTime"] as? String ?? "Never").formatIntuneDate()
    ///             
    ///             print("\\(deviceName): \\(complianceStatus) (\\(policyName)) - Last reported: \\(lastReported)")
    ///             
    ///             // Show error details for failed deployments
    ///             if complianceStatus == "Error" || complianceStatus == "NonCompliant",
    ///                let errorCode = deviceStatus["ErrorCode"] as? Int, errorCode != 0 {
    ///                 print("  Error Code: \\(errorCode)")
    ///                 if let errorDescription = deviceStatus["ErrorDescription"] as? String {
    ///                     print("  Details: \\(errorDescription)")
    ///                 }
    ///             }
    ///         }
    ///     } else {
    ///         print("Failed to retrieve configuration profile deployment status")
    ///     }
    /// }
    /// ```
    ///
    /// **Advanced Usage - Compliance Dashboard:**
    /// ```swift
    /// XPCManager.shared.getDeviceConfigProfileDeploymentStatusReport(profileId: profileId) { deploymentStatus in
    ///     guard let deploymentStatus = deploymentStatus else { return }
    ///     
    ///     // Generate compliance dashboard data
    ///     let dashboardData = deploymentStatus.compactMap { deviceStatus -> [String: Any]? in
    ///         guard let deviceName = deviceStatus["DeviceName"] as? String else { return nil }
    ///         
    ///         let complianceStatus = deviceStatus["ComplianceStatus"] as? String ?? "unknown"
    ///         let policyName = deviceStatus["PolicyName"] as? String ?? "Unknown Policy"
    ///         let lastReported = deviceStatus["LastReportedDateTime"] as? String ?? ""
    ///         let isCompliant = complianceStatus == "Compliant"
    ///         
    ///         return [
    ///             "deviceName": deviceName,
    ///             "compliant": isCompliant,
    ///             "complianceStatus": complianceStatus,
    ///             "policyName": policyName,
    ///             "lastUpdate": lastReported.formatIntuneDate()
    ///         ]
    ///     }
    ///     
    ///     // Export or display compliance dashboard
    ///     exportConfigurationComplianceDashboard(dashboardData)
    /// }
    /// ```
    ///
    /// **Common Use Cases:**
    /// - Monitoring configuration profile deployment success across device fleet
    /// - Troubleshooting policy deployment failures on specific devices
    /// - Generating compliance reports for management and auditing
    /// - Identifying devices requiring attention or manual remediation
    /// - Performance analysis of policy deployment timing and success rates
    /// - Audit trail for configuration management activities
    ///
    /// **Performance Considerations:**
    /// - Results are automatically paginated for large device environments
    /// - Device and user information is efficiently retrieved in single API call
    /// - Results are pre-sorted by device name for UI consistency
    /// - Consider caching results for frequently accessed deployment data
    ///
    /// **Required Permissions:**
    /// - DeviceManagementConfiguration.Read.All (Application or Delegated)
    /// - DeviceManagementManagedDevices.Read.All (for device information)
    /// - DeviceManagementConfiguration.Read.All (for reports access)
    ///
    /// - Parameters:
    ///   - profileId: Unique identifier (GUID) of the configuration profile to get deployment status for
    ///   - completion: Callback with array of device deployment status dictionaries or nil on failure (including XPC failure)
    func getDeviceConfigProfileDeploymentStatusReport(profileId: String, completion: @escaping ([[String: Any]]?) -> Void) {
        sendRequest({ service, reply in
            service.getDeviceConfigProfileDeploymentStatusReport(profileId: profileId, reply: reply)
        }, completion: completion)
    }
    
    // MARK: - Microsoft Graph Export Jobs API
    
    /// Creates a new export job for a specific report type from Microsoft Graph reports endpoint
    ///
    /// This function creates an export job for various Microsoft Intune reports that can be processed asynchronously
    /// and downloaded when complete. Export jobs are useful for large datasets that exceed the limits of standard API calls.
    ///
    /// **Key Features:**
    /// - Support for multiple report types (DeviceInstallStatusByApp, CompliancePolicyDevicesReport, etc.)
    /// - Flexible filtering using OData query syntax
    /// - Column selection for optimized data export
    /// - Multiple export formats (CSV, JSON)
    /// - Asynchronous processing for large datasets
    ///
    /// **Common Report Types:**
    /// - `DeviceInstallStatusByApp`: App installation status across all devices
    /// - `CompliancePolicyDevicesReport`: Device compliance status for policies
    /// - `DeviceConfigurationDevicesReport`: Configuration profile deployment status
    /// - `DeviceInventoryReport`: Device hardware and software inventory
    ///
    /// **Usage Example:**
    /// ```swift
    /// XPCManager.shared.createExportJob(
    ///     reportName: "DeviceInstallStatusByApp",
    ///     filter: "ApplicationName eq 'Microsoft Office'",
    ///     select: ["DeviceName", "InstallState", "UserName", "LastModifiedDateTime"],
    ///     format: "csv"
    /// ) { jobId in
    ///     if let jobId = jobId {
    ///         print("Export job created with ID: \\(jobId)")
    ///         // Poll for completion using getExportJobStatus
    ///     } else {
    ///         print("Failed to create export job")
    ///     }
    /// }
    /// ```
    ///
    /// **Required Permissions:**
    /// - DeviceManagementConfiguration.Read.All (for configuration reports)
    /// - DeviceManagementApps.Read.All (for app-related reports)
    /// - DeviceManagementManagedDevices.Read.All (for device reports)
    ///
    /// - Parameters:
    ///   - reportName: Name of the report to export (e.g., "DeviceInstallStatusByApp")
    ///   - filter: Optional OData filter string to limit results
    ///   - select: Optional array of column names to include in export
    ///   - format: Export format ("csv" or "json", defaults to "csv")
    ///   - completion: Callback with export job ID or nil on failure
    func createExportJob(reportName: String, filter: String?, select: [String]?, format: String, completion: @escaping (String?) -> Void) {
        sendRequest({ service, reply in
            service.createExportJob(reportName: reportName, filter: filter, select: select, format: format, reply: reply)
        }, completion: completion)
    }
    
    /// Checks the status of an export job and returns job details
    ///
    /// This function polls an export job to check its current status and retrieve metadata about the job.
    /// Export jobs typically go through states: "notStarted" → "inProgress" → "completed" (or "failed").
    ///
    /// **Job Status Values:**
    /// - `notStarted`: Job has been created but processing hasn't begun
    /// - `inProgress`: Job is currently being processed
    /// - `completed`: Job finished successfully, download URL available
    /// - `failed`: Job failed due to an error
    ///
    /// **Returned Data Structure:**
    /// - `id`: Export job identifier
    /// - `status`: Current job status
    /// - `url`: Download URL (only available when status is "completed")
    /// - `createdDateTime`: When the job was created
    /// - `requestDateTime`: When the job was requested
    /// - `errorMessage`: Error details (only present if status is "failed")
    ///
    /// **Usage Example:**
    /// ```swift
    /// XPCManager.shared.getExportJobStatus(jobId: "job-id-here") { jobStatus in
    ///     if let jobStatus = jobStatus,
    ///        let status = jobStatus["status"] as? String {
    ///         switch status {
    ///         case "completed":
    ///             if let downloadUrl = jobStatus["url"] as? String {
    ///                 print("Job completed, download URL: \\(downloadUrl)")
    ///                 // Download the data using downloadExportJobData
    ///             }
    ///         case "failed":
    ///             let error = jobStatus["errorMessage"] as? String ?? "Unknown error"
    ///             print("Job failed: \\(error)")
    ///         case "inProgress":
    ///             print("Job still processing...")
    ///         default:
    ///             print("Job status: \\(status)")
    ///         }
    ///     } else {
    ///         print("Failed to get job status")
    ///     }
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - jobId: Export job ID to check
    ///   - completion: Callback with job status dictionary or nil on failure
    func getExportJobStatus(jobId: String, completion: @escaping ([String: Any]?) -> Void) {
        sendRequest({ service, reply in
            service.getExportJobStatus(jobId: jobId, reply: reply)
        }, completion: completion)
    }
    
    /// Downloads completed export job data from Microsoft Graph
    ///
    /// This function downloads the actual export data once an export job has completed successfully.
    /// The download URL is obtained from the job status when the status becomes "completed".
    ///
    /// **Data Format:**
    /// - CSV format: Returns comma-separated values with headers in the first row
    /// - JSON format: Returns structured JSON data with array of objects
    ///
    /// **Usage Example:**
    /// ```swift
    /// // First check job status to get download URL
    /// XPCManager.shared.getExportJobStatus(jobId: jobId) { jobStatus in
    ///     if let jobStatus = jobStatus,
    ///        jobStatus["status"] as? String == "completed",
    ///        let downloadUrl = jobStatus["url"] as? String {
    ///         
    ///         // Download the actual data
    ///         XPCManager.shared.downloadExportJobData(downloadUrl: downloadUrl) { data in
    ///             if let data = data {
    ///                 // Process the downloaded data
    ///                 let csvString = String(data: data, encoding: .utf8) ?? ""
    ///                 print("Downloaded \\(data.count) bytes of data")
    ///                 
    ///                 // Save to file or process in memory
    ///                 saveExportData(data, filename: "export-\\(Date().timeIntervalSince1970).csv")
    ///             } else {
    ///                 print("Failed to download export data")
    ///             }
    ///         }
    ///     }
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - downloadUrl: Download URL from completed export job
    ///   - completion: Callback with downloaded data or nil on failure
    func downloadExportJobData(downloadUrl: String, completion: @escaping (Data?) -> Void) {
        sendRequest({ service, reply in
            service.downloadExportJobData(downloadUrl: downloadUrl, reply: reply)
        }, completion: completion)
    }
    
    /// Polls an export job until completion and automatically downloads the result
    ///
    /// This function combines job status polling with automatic download, providing a complete workflow
    /// for export job processing. It will continuously check the job status at regular intervals until
    /// the job completes or times out, then automatically download the result data.
    ///
    /// **Polling Behavior:**
    /// - Checks job status every `pollIntervalSeconds` (default: 5 seconds)
    /// - Continues polling for up to `maxWaitTimeSeconds` (default: 300 seconds / 5 minutes)
    /// - Automatically downloads data when job status becomes "completed"
    /// - Returns error immediately if job status becomes "failed"
    /// - Times out if job doesn't complete within the maximum wait time
    ///
    /// **Usage Example:**
    /// ```swift
    /// // Create and wait for export job completion
    /// XPCManager.shared.createDeviceInstallStatusByAppExportJob(
    ///     applicationId: "app-guid",
    ///     deviceName: nil,
    ///     userName: nil,
    ///     includeColumns: nil
    /// ) { jobId in
    ///     guard let jobId = jobId else {
    ///         print("Failed to create export job")
    ///         return
    ///     }
    ///
    ///     // Poll until completion and download
    ///     XPCManager.shared.pollAndDownloadExportJob(
    ///         jobId: jobId,
    ///         maxWaitTimeSeconds: 600,  // Wait up to 10 minutes
    ///         pollIntervalSeconds: 10   // Check every 10 seconds
    ///     ) { data in
    ///         if let data = data {
    ///             print("Export completed and downloaded: \\(data.count) bytes")
    ///
    ///             // Process the CSV data
    ///             let csvString = String(data: data, encoding: .utf8) ?? ""
    ///             let lines = csvString.components(separatedBy: .newlines)
    ///             print("Downloaded \\(lines.count) rows of data")
    ///
    ///             // Save or process the data as needed
    ///             saveToFile(data, filename: "device-install-status.csv")
    ///         } else {
    ///             print("Export job failed or timed out")
    ///         }
    ///     }
    /// }
    /// ```
    ///
    /// **Performance Considerations:**
    /// - Large exports may take several minutes to complete
    /// - Consider using longer poll intervals for very large datasets
    /// - Monitor network usage for large downloads
    /// - Implement proper error handling for timeout scenarios
    ///
    /// - Parameters:
    ///   - jobId: Export job ID to poll
    ///   - maxWaitTimeSeconds: Maximum time to wait for completion (default: 300)
    ///   - pollIntervalSeconds: Interval between status checks (default: 5)
    ///   - completion: Callback with downloaded data or nil on failure/timeout
    func pollAndDownloadExportJob(jobId: String, maxWaitTimeSeconds: Int = 300, pollIntervalSeconds: Int = 5, completion: @escaping (Data?) -> Void) {
        sendRequest({ service, reply in
            service.pollAndDownloadExportJob(jobId: jobId, maxWaitTimeSeconds: maxWaitTimeSeconds, pollIntervalSeconds: pollIntervalSeconds, reply: reply)
        }, completion: completion)
    }
     
    // MARK: - Scheduled Reports Management
    
    /// Gets the current scheduler status and execution statistics
    ///
    /// This function retrieves comprehensive information about the scheduled reports scheduler,
    /// including operational status, timing information, and execution statistics.
    ///
    /// **Returned Data Structure:**
    /// - `schedulerEnabled`: Boolean indicating if scheduler plist exists and is active
    /// - `schedulerInterval`: Interval in seconds between scheduler runs (typically 600 = 10 minutes)
    /// - `totalReports`: Total number of scheduled reports configured
    /// - `enabledReports`: Number of enabled scheduled reports
    /// - `lastSchedulerRun`: Date of last scheduler execution (if available from logs)
    /// - `nextReportDue`: Date when the next report is scheduled to run
    /// - `overdueReports`: Number of reports that are currently overdue
    /// - `averageExecutionTime`: Average execution time for recent reports (if available)
    ///
    /// **Usage Example:**
    /// ```swift
    /// XPCManager.shared.getSchedulerStatus { statusInfo in
    ///     if let statusInfo = statusInfo {
    ///         let enabled = statusInfo["schedulerEnabled"] as? Bool ?? false
    ///         let interval = statusInfo["schedulerInterval"] as? Int ?? 0
    ///         let totalReports = statusInfo["totalReports"] as? Int ?? 0
    ///         let enabledReports = statusInfo["enabledReports"] as? Int ?? 0
    ///         
    ///         print("Scheduler: \(enabled ? "Enabled" : "Disabled")")
    ///         print("Interval: \(interval / 60) minutes")
    ///         print("Reports: \(enabledReports)/\(totalReports) enabled")
    ///         
    ///         if let lastRun = statusInfo["lastSchedulerRun"] as? Date {
    ///             print("Last run: \(lastRun)")
    ///         }
    ///         
    ///         if let nextDue = statusInfo["nextReportDue"] as? Date {
    ///             print("Next report due: \(nextDue)")
    ///         }
    ///         
    ///         let overdue = statusInfo["overdueReports"] as? Int ?? 0
    ///         if overdue > 0 {
    ///             print("⚠️ \(overdue) reports are overdue")
    ///         }
    ///     } else {
    ///         print("Failed to get scheduler status")
    ///     }
    /// }
    /// ```
    ///
    /// - Parameter completion: Callback with scheduler status dictionary or nil on failure
    func getSchedulerStatus(completion: @escaping ([String: Any]?) -> Void) {
        sendRequest({ service, reply in
            service.getSchedulerStatus(reply: reply)
        }, completion: completion)
    }

 
}
