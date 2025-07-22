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

    // MARK: - Export Jobs Report Types
    /// Creates a DeviceInstallStatusByApp export job with convenient filtering options
    ///
    /// This is a convenience function specifically for the DeviceInstallStatusByApp report, which is one of the most
    /// commonly used export reports. It provides simplified parameters for common filtering scenarios.
    ///
    /// **Default Columns Included:**
    /// - `ApplicationId`: Unique app identifier
    /// - `ApplicationName`: User-friendly app name
    /// - `DeviceId`: Unique device identifier
    /// - `DeviceName`: Device hostname
    /// - `UPN`: User principal name
    /// - `UserId`: User identifier
    /// - `UserName`: User display name
    /// - `InstallState`: Installation status
    /// - `InstallStateDetail`: Detailed installation information
    /// - `LastModifiedDateTime`: Last status update timestamp
    /// - `AppVersion`: Installed app version
    /// - `Platform`: Device platform (Windows, macOS, iOS, Android)
    ///
    /// **Usage Example:**
    /// ```swift
    /// // Export installation status for a specific app
    /// XPCManager.shared.createDeviceInstallStatusByAppExportJob(
    ///     applicationId: "app-guid-here",
    ///     deviceName: nil,
    ///     userName: nil,
    ///     includeColumns: nil  // Use default columns
    /// ) { jobId in
    ///     if let jobId = jobId {
    ///         print("DeviceInstallStatusByApp export job created: \\(jobId)")
    ///         // Poll for completion
    ///     } else {
    ///         print("Failed to create export job")
    ///     }
    /// }
    /// 
    /// // Export with custom filtering and columns
    /// XPCManager.shared.createDeviceInstallStatusByAppExportJob(
    ///     applicationId: nil,
    ///     deviceName: "DESKTOP-12345",
    ///     userName: "john.doe@company.com",
    ///     includeColumns: ["ApplicationName", "DeviceName", "InstallState", "LastModifiedDateTime"]
    /// ) { jobId in
    ///     // Handle result
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - applicationId: Optional filter by specific application ID
    ///   - deviceName: Optional filter by device name
    ///   - userName: Optional filter by user name (UPN)
    ///   - includeColumns: Optional array of specific columns to include (uses defaults if nil)
    ///   - format: Export format ("csv" or "json", defaults to "csv")
    ///   - completion: Callback with export job ID or nil on failure
    func createDeviceInstallStatusByAppExportJob(applicationId: String?, deviceName: String?, userName: String?, includeColumns: [String]?, format: String = "csv", completion: @escaping (String?) -> Void) {
        sendRequest({ service, reply in
            service.createDeviceInstallStatusByAppExportJob(applicationId: applicationId, deviceName: deviceName, userName: userName, includeColumns: includeColumns, format: format, reply: reply)
        }, completion: completion)
    }

    /// Creates a UserInstallStatusAggregateByApp export job with convenient filtering options
    ///
    /// This is a convenience function specifically for the UserInstallStatusAggregateByApp report, which is one of the most
    /// commonly used export reports. It provides simplified parameters for common filtering scenarios.
    ///
    /// **Default Columns Included:**
    /// - `UserPrincipalName`: User principal name
    /// - `UserName`: User display name
    /// - `FailedCount`: Failed count
    /// - `InstalledCount`: installed count
    /// - `PendingInstallCount`: Pending install count
    /// - `NotInstalledCount`: Not installed count
    /// - `NotApplicableCount`: Not applicable count
    ///
    /// **Usage Example:**
    /// ```swift
    /// // Export installation status for a specific app
    /// XPCManager.shared.createUserInstallStatusAggregateByAppExportJob(
    ///     applicationId: "app-guid-here",
    ///     deviceName: nil,
    ///     userName: nil,
    ///     includeColumns: nil  // Use default columns
    /// ) { jobId in
    ///     if let jobId = jobId {
    ///         print("UserInstallStatusAggregateByApp export job created: \\(jobId)")
    ///         // Poll for completion
    ///     } else {
    ///         print("Failed to create export job")
    ///     }
    /// }
    ///
    /// // Export with custom filtering and columns
    /// XPCManager.shared.createUserInstallStatusAggregateByAppExportJob(
    ///     applicationId: nil,
    ///     deviceName: "DESKTOP-12345",
    ///     userName: "john.doe@company.com",
    ///     includeColumns: ["ApplicationName", "DeviceName", "InstallState", "LastModifiedDateTime"]
    /// ) { jobId in
    ///     // Handle result
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - applicationId: Optional filter by specific application ID
    ///   - deviceName: Optional filter by device name
    ///   - userName: Optional filter by user name (UPN)
    ///   - includeColumns: Optional array of specific columns to include (uses defaults if nil)
    ///   - format: Export format ("csv" or "json", defaults to "csv")
    ///   - completion: Callback with export job ID or nil on failure
    func createUserInstallStatusAggregateByAppExportJob(applicationId: String?, deviceName: String?, userName: String?, includeColumns: [String]?, format: String = "csv", completion: @escaping (String?) -> Void) {
        sendRequest({ service, reply in
            service.createUserInstallStatusAggregateByAppExportJob(applicationId: applicationId, deviceName: deviceName, userName: userName, includeColumns: includeColumns, format: format, reply: reply)
        }, completion: completion)
    }

    /// Creates a AppInvByDevice export job with convenient filtering options
    ///
    /// This is a convenience function specifically for the AppInvByDevice report
    ///
    /// **Default Columns Included:**
    /// - `DeviceId`: Unique device identifier
    /// - `ApplicationKey`
    /// - `ApplicationName`: User-friendly app name
    /// - `ApplicationPublisher`: User-friendly app publisher
    /// - `ApplicationShortVersion`: App short version
    /// - `ApplicationVersion`: App version
    /// - `DeviceName`: Device hostname
    /// - `OSDescription`: OS Description
    /// - `OSVersion`: OS Version
    /// - `Platform`: Device platform
    /// - `UserId`: User identifier
    /// - `EmailAddress`: User email address
    /// - `UserName`: User display name
    ///
    /// **Usage Example:**
    /// ```swift
    /// // Export installation status for a specific app
    /// XPCManager.shared.createAppInvByDeviceExportJob(
    ///     deviceId: "device-guid-here",
    ///     includeColumns: nil  // Use default columns
    /// ) { jobId in
    ///     if let jobId = jobId {
    ///         print("AppInvByDevice export job created: \\(jobId)")
    ///         // Poll for completion
    ///     } else {
    ///         print("Failed to create export job")
    ///     }
    /// }
    ///
    /// // Export with custom filtering and columns
    /// XPCManager.shared.createAppInvByDeviceExportJob(
    ///     deviceId: "abded-12345-65443",
    ///     includeColumns: ["ApplicationName", "DeviceName", "Platform", "UserName"]
    /// ) { jobId in
    ///     // Handle result
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - deviceId: Non-Optional filter by specific application ID
    ///   - includeColumns: Optional array of specific columns to include (uses defaults if nil)
    ///   - format: Export format ("csv" or "json", defaults to "csv")
    ///   - completion: Callback with export job ID or nil on failure
    func createAppInvByDeviceExportJob(deviceId: String, includeColumns: [String]?, format: String = "csv", completion: @escaping (String?) -> Void) {
        sendRequest({ service, reply in
            service.createAppInvByDeviceExportJob(deviceId: deviceId, includeColumns: includeColumns, format: format, reply: reply)
        }, completion: completion)
    }

    // MARK: - Additional Export Jobs Report Types

    /// Creates an AllAppsList export job for comprehensive app inventory reporting
    ///
    /// This function creates an export job for the AllAppsList report, which provides a complete inventory
    /// of all applications discovered across managed devices in the organization. Essential for software
    /// asset management, license compliance, and application portfolio analysis.
    ///
    /// **Usage Example:**
    /// ```swift
    /// XPCManager.shared.createAllAppsListExportJob(
    ///     includeColumns: ["ApplicationName", "Publisher", "Version", "DeviceCount"],
    ///     format: "csv"
    /// ) { jobId in
    ///     if let jobId = jobId {
    ///         print("AllAppsList export job created: \(jobId)")
    ///     } else {
    ///         print("Failed to create export job")
    ///     }
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - includeColumns: Optional array of specific columns to include
    ///   - format: Export format ("csv" or "json", defaults to "csv")
    ///   - completion: Callback with export job ID or nil on failure
    func createAllAppsListExportJob(includeColumns: [String]?, format: String = "csv", completion: @escaping (String?) -> Void) {
        sendRequest({ service, reply in
            service.createAllAppsListExportJob(includeColumns: includeColumns, format: format, reply: reply)
        }, completion: completion)
    }

    /// Creates an AppInstallStatusAggregate export job for comprehensive app install status reporting
    ///
    /// This function creates an export job for the AppInstallStatusAggregate report, which provides a complete
    /// applications install status across managed devices in the organization. Essential for software
    /// asset management, license compliance, and application portfolio analysis.
    ///
    /// **Usage Example:**
    /// ```swift
    /// XPCManager.shared.createAppInstallStatusAggregateExportJob(
    ///     platform: nil,
    ///     failedDevicePercentage: nil,
    ///     includeColumns: ["ApplicationName", "Publisher", "Version", "DeviceCount"],
    ///     format: "csv"
    /// ) { jobId in
    ///     if let jobId = jobId {
    ///         print("AppInstallStatusAggregate export job created: \(jobId)")
    ///     } else {
    ///         print("Failed to create export job")
    ///     }
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - platform: Optional filter by specific platform
    ///   - failedDevicePercentage: Optional filter by device failed percentage
    ///   - includeColumns: Optional array of specific columns to include
    ///   - format: Export format ("csv" or "json", defaults to "csv")
    ///   - completion: Callback with export job ID or nil on failure
    func createAppInstallStatusAggregateExportJob(platform: String?, failedDevicePercentage: String?, includeColumns: [String]?, format: String = "csv", completion: @escaping (String?) -> Void) {
        sendRequest({ service, reply in
            service.createAppInstallStatusAggregateExportJob(platform: platform, failedDevicePercentage: failedDevicePercentage, includeColumns: includeColumns, format: format, reply: reply)
        }, completion: completion)
    }

    /// Creates an AppInvAggregate export job for application inventory aggregate reporting
    ///
    /// This function creates an export job for aggregated application inventory data, providing
    /// summarized statistics about applications across the organization. Useful for high-level
    /// reporting and trend analysis of application usage and deployment patterns.
    ///
    /// **Usage Example:**
    /// ```swift
    /// XPCManager.shared.createAppInvAggregateExportJob(
    ///     includeColumns: nil,
    ///     format: "json"
    /// ) { jobId in
    ///     // Handle result
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - includeColumns: Optional array of specific columns to include
    ///   - format: Export format ("csv" or "json", defaults to "csv")
    ///   - completion: Callback with export job ID or nil on failure
    func createAppInvAggregateExportJob(includeColumns: [String]?, format: String = "csv", completion: @escaping (String?) -> Void) {
        sendRequest({ service, reply in
            service.createAppInvAggregateExportJob(includeColumns: includeColumns, format: format, reply: reply)
        }, completion: completion)
    }

    /// Creates an AppInvRawData export job with extensive filtering options
    ///
    /// This function creates an export job for detailed raw application inventory data with comprehensive
    /// filtering capabilities. Provides granular application information across all managed devices.
    ///
    /// **Usage Example:**
    /// ```swift
    /// XPCManager.shared.createAppInvRawDataExportJob(
    ///     applicationName: "Microsoft",
    ///     applicationPublisher: nil,
    ///     applicationShortVersion: nil,
    ///     applicationVersion: nil,
    ///     deviceId: nil,
    ///     deviceName: "DESKTOP-ABC123",
    ///     osDescription: nil,
    ///     osVersion: nil,
    ///     platform: "macOS",
    ///     userId: nil,
    ///     emailAddress: nil,
    ///     userName: nil,
    ///     includeColumns: ["ApplicationName", "DeviceName", "Version"],
    ///     format: "csv"
    /// ) { jobId in
    ///     // Handle result
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - applicationName: Optional filter by application name
    ///   - applicationPublisher: Optional filter by application publisher
    ///   - applicationShortVersion: Optional filter by application short version
    ///   - applicationVersion: Optional filter by application version
    ///   - deviceId: Optional filter by device ID
    ///   - deviceName: Optional filter by device name
    ///   - osDescription: Optional filter by OS description
    ///   - osVersion: Optional filter by OS version
    ///   - platform: Optional filter by platform
    ///   - userId: Optional filter by user ID
    ///   - emailAddress: Optional filter by email address
    ///   - userName: Optional filter by user name
    ///   - includeColumns: Optional array of specific columns to include
    ///   - format: Export format ("csv" or "json", defaults to "csv")
    ///   - completion: Callback with export job ID or nil on failure
    func createAppInvRawDataExportJob(applicationName: String?, applicationPublisher: String?, applicationShortVersion: String?, applicationVersion: String?, deviceId: String?, deviceName: String?, osDescription: String?, osVersion: String?, platform: String?, userId: String?, emailAddress: String?, userName: String?, includeColumns: [String]?, format: String = "csv", completion: @escaping (String?) -> Void) {
        sendRequest({ service, reply in
            service.createAppInvRawDataExportJob(applicationName: applicationName, applicationPublisher: applicationPublisher, applicationShortVersion: applicationShortVersion, applicationVersion: applicationVersion, deviceId: deviceId, deviceName: deviceName, osDescription: osDescription, osVersion: osVersion, platform: platform, userId: userId, emailAddress: emailAddress, userName: userName, includeColumns: includeColumns, format: format, reply: reply)
        }, completion: completion)
    }

    /// Creates a DeviceCompliance export job with filtering options
    ///
    /// This function creates an export job for device compliance status reporting, providing
    /// comprehensive compliance information across all managed devices.
    ///
    /// **Usage Example:**
    /// ```swift
    /// XPCManager.shared.createDeviceComplianceExportJob(
    ///     complianceState: "compliant",
    ///     os: "macOS",
    ///     ownerType: "company",
    ///     deviceType: "desktop",
    ///     includeColumns: ["DeviceName", "ComplianceState", "LastSync"],
    ///     format: "csv"
    /// ) { jobId in
    ///     // Handle result
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - complianceState: Optional filter by compliance state
    ///   - os: Optional filter by operating system
    ///   - ownerType: Optional filter by owner type
    ///   - deviceType: Optional filter by device type
    ///   - includeColumns: Optional array of specific columns to include
    ///   - format: Export format ("csv" or "json", defaults to "csv")
    ///   - completion: Callback with export job ID or nil on failure
    func createDeviceComplianceExportJob(complianceState: String?, os: String?, ownerType: String?, deviceType: String?, includeColumns: [String]?, format: String = "csv", completion: @escaping (String?) -> Void) {
        sendRequest({ service, reply in
            service.createDeviceComplianceExportJob(complianceState: complianceState, os: os, ownerType: ownerType, deviceType: deviceType, includeColumns: includeColumns, format: format, reply: reply)
        }, completion: completion)
    }

    /// Creates a DeviceNonCompliance export job with filtering options
    ///
    /// This function creates an export job for device non-compliance reporting, focusing on
    /// devices that are not meeting compliance requirements.
    ///
    /// **Usage Example:**
    /// ```swift
    /// XPCManager.shared.createDeviceNonComplianceExportJob(
    ///     complianceState: "noncompliant",
    ///     os: nil,
    ///     ownerType: nil,
    ///     deviceType: nil,
    ///     userId: nil,
    ///     includeColumns: ["DeviceName", "NonComplianceReason", "LastSync"],
    ///     format: "csv"
    /// ) { jobId in
    ///     // Handle result
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - complianceState: Optional filter by compliance state
    ///   - os: Optional filter by operating system
    ///   - ownerType: Optional filter by owner type
    ///   - deviceType: Optional filter by device type
    ///   - userId: Optional filter by user ID
    ///   - includeColumns: Optional array of specific columns to include
    ///   - format: Export format ("csv" or "json", defaults to "csv")
    ///   - completion: Callback with export job ID or nil on failure
    func createDeviceNonComplianceExportJob(complianceState: String?, os: String?, ownerType: String?, deviceType: String?, userId: String?, includeColumns: [String]?, format: String = "csv", completion: @escaping (String?) -> Void) {
        sendRequest({ service, reply in
            service.createDeviceNonComplianceExportJob(complianceState: complianceState, os: os, ownerType: ownerType, deviceType: deviceType, userId: userId, includeColumns: includeColumns, format: format, reply: reply)
        }, completion: completion)
    }

    /// Creates a Devices export job with comprehensive filtering options
    ///
    /// This function creates an export job for general device information with extensive
    /// filtering capabilities for device management and inventory reporting.
    ///
    /// **Usage Example:**
    /// ```swift
    /// XPCManager.shared.createDevicesExportJob(
    ///     ownerType: "company",
    ///     deviceType: "desktop",
    ///     managementAgents: nil,
    ///     categoryName: nil,
    ///     managementState: "managed",
    ///     compliantState: "compliant",
    ///     jailBroken: "false",
    ///     enrollmentType: "azureADJoined",
    ///     includeColumns: ["DeviceName", "OS", "LastSync", "User"],
    ///     format: "csv"
    /// ) { jobId in
    ///     // Handle result
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - ownerType: Optional filter by owner type
    ///   - deviceType: Optional filter by device type
    ///   - managementAgents: Optional filter by management agents
    ///   - categoryName: Optional filter by category name
    ///   - managementState: Optional filter by management state
    ///   - compliantState: Optional filter by compliant state
    ///   - jailBroken: Optional filter by jail broken status
    ///   - enrollmentType: Optional filter by enrollment type
    ///   - includeColumns: Optional array of specific columns to include
    ///   - format: Export format ("csv" or "json", defaults to "csv")
    ///   - completion: Callback with export job ID or nil on failure
    func createDevicesExportJob(ownerType: String?, deviceType: String?, managementAgents: String?, categoryName: String?, managementState: String?, compliantState: String?, jailBroken: String?, enrollmentType: String?, includeColumns: [String]?, format: String = "csv", completion: @escaping (String?) -> Void) {
        sendRequest({ service, reply in
            service.createDevicesExportJob(ownerType: ownerType, deviceType: deviceType, managementAgents: managementAgents, categoryName: categoryName, managementState: managementState, compliantState: compliantState, jailBroken: jailBroken, enrollmentType: enrollmentType, includeColumns: includeColumns, format: format, reply: reply)
        }, completion: completion)
    }

    /// Creates a DevicesWithInventory export job with comprehensive filtering options
    ///
    /// This function creates an export job for general device information with extensive
    /// filtering capabilities for device management and inventory reporting.
    ///
    /// **Usage Example:**
    /// ```swift
    /// XPCManager.shared.createDevicesWithInventoryExportJob(
    ///     createdDate: nil,
    ///     lastContact: nil,
    ///     categoryName: nil,
    ///     compliantState: "compliant",
    ///     managementAgents: nil,
    ///     ownerType: "company",
    ///     managementState: "managed",
    ///     deviceType: "desktop",
    ///     jailBroken: "false",
    ///     enrollmentType: "azureADJoined",
    ///     includeColumns: ["DeviceName", "OS", "LastSync", "User"],
    ///     format: "csv"
    /// ) { jobId in
    ///     // Handle result
    /// }
    /// ```
    ///
    /// Creates a DevicesWithInventory export job with filtering options
    /// - Parameters:
    ///   - createdDate: Optional filter by created date
    ///   - lastContact: Optional filter by last contact
    ///   - categoryName: Optional filter by category name
    ///   - compliantState: Optional filter by management agents
    ///   - managementAgents: Optional filter by management agents
    ///   - ownerType: Optional filter by specific owner type
    ///   - managementState: Optional filter by management state
    ///   - deviceType: Optional filter by device type
    ///   - jailBroken: Optional filter by jail broken state
    ///   - enrollmentType: Optional filter by enrollment type
    ///   - includeColumns: Optional array of specific columns to include
    ///   - format: Export format ("csv" or "json", defaults to "csv")
    ///   - reply: Callback with export job ID or nil on failure
    func createDevicesWithInventoryExportJob(createdDate: String?, lastContact: String?, categoryName: String?, compliantState: String?, managementAgents: String?, ownerType: String?, managementState: String?, deviceType: String?, jailBroken: String?, enrollmentType: String?, includeColumns: [String]?, format: String = "csv", completion: @escaping (String?) -> Void) {
        sendRequest({ service, reply in
            service.createDevicesWithInventoryExportJob(createdDate: createdDate, lastContact: lastContact, categoryName: categoryName, compliantState: compliantState, managementAgents: managementAgents, ownerType: ownerType, managementState: managementState, deviceType: deviceType,  jailBroken: jailBroken, enrollmentType: enrollmentType, includeColumns: includeColumns, format: format, reply: reply)
        }, completion: completion)
    }

    /// Creates a DefenderAgents export job with security filtering options
    ///
    /// This function creates an export job for Microsoft Defender security agent status across
    /// managed devices, providing critical security posture information.
    ///
    /// **Usage Example:**
    /// ```swift
    /// XPCManager.shared.createDefenderAgentsExportJob(
    ///     deviceState: "active",
    ///     signatureUpdateOverdue: "false",
    ///     malwareProtectionEnabled: "true",
    ///     realTimeProtectionEnabled: "true",
    ///     networkInspectionSystemEnabled: nil,
    ///     includeColumns: ["DeviceName", "DefenderStatus", "LastUpdate"],
    ///     format: "csv",
    ///     reportType: "DefenderAgents"
    /// ) { jobId in
    ///     // Handle result
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - deviceState: Optional filter by device state
    ///   - signatureUpdateOverdue: Optional filter by signature update overdue status
    ///   - malwareProtectionEnabled: Optional filter by malware protection enabled status
    ///   - realTimeProtectionEnabled: Optional filter by real-time protection enabled status
    ///   - networkInspectionSystemEnabled: Optional filter by network inspection system enabled status
    ///   - includeColumns: Optional array of specific columns to include
    ///   - format: Export format ("csv" or "json", defaults to "csv")
    ///   - reportType: Report type identifier (defaults to "DefenderAgents")
    ///   - completion: Callback with export job ID or nil on failure
    func createDefenderAgentsExportJob(deviceState: String?, signatureUpdateOverdue: String?, malwareProtectionEnabled: String?, realTimeProtectionEnabled: String?, networkInspectionSystemEnabled: String?, includeColumns: [String]?, format: String = "csv", reportType: String = "DefenderAgents", completion: @escaping (String?) -> Void) {
        sendRequest({ service, reply in
            service.createDefenderAgentsExportJob(deviceState: deviceState, signatureUpdateOverdue: signatureUpdateOverdue, malwareProtectionEnabled: malwareProtectionEnabled, realTimeProtectionEnabled: realTimeProtectionEnabled, networkInspectionSystemEnabled: networkInspectionSystemEnabled, includeColumns: includeColumns, format: format, reportType: reportType, reply: reply)
        }, completion: completion)
    }

    /// Creates a FirewallStatus export job with filtering options
    ///
    /// This function creates an export job for firewall status reporting across managed devices,
    /// providing essential security configuration information.
    ///
    /// **Usage Example:**
    /// ```swift
    /// XPCManager.shared.createFirewallStatusExportJob(
    ///     firewallStatus: "enabled",
    ///     includeColumns: ["DeviceName", "FirewallStatus", "Profile"],
    ///     format: "csv"
    /// ) { jobId in
    ///     // Handle result
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - firewallStatus: Optional filter by firewall status
    ///   - includeColumns: Optional array of specific columns to include
    ///   - format: Export format ("csv" or "json", defaults to "csv")
    ///   - completion: Callback with export job ID or nil on failure
    func createFirewallStatusExportJob(firewallStatus: String?, includeColumns: [String]?, format: String = "csv", completion: @escaping (String?) -> Void) {
        sendRequest({ service, reply in
            service.createFirewallStatusExportJob(firewallStatus: firewallStatus, includeColumns: includeColumns, format: format, reply: reply)
        }, completion: completion)
    }

    /// Creates a Malware export job with threat filtering options
    ///
    /// This function creates an export job for malware detection and threat information across
    /// managed devices, providing critical security incident data.
    ///
    /// **Usage Example:**
    /// ```swift
    /// XPCManager.shared.createMalwareExportJob(
    ///     severity: "high",
    ///     executionState: "detected",
    ///     state: "active",
    ///     includeColumns: ["DeviceName", "ThreatName", "Severity", "DetectionTime"],
    ///     format: "csv",
    ///     reportType: "Malware"
    /// ) { jobId in
    ///     // Handle result
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - severity: Optional filter by severity
    ///   - executionState: Optional filter by execution state
    ///   - state: Optional filter by state
    ///   - includeColumns: Optional array of specific columns to include
    ///   - format: Export format ("csv" or "json", defaults to "csv")
    ///   - reportType: Report type identifier (defaults to "Malware")
    ///   - completion: Callback with export job ID or nil on failure
    func createMalwareExportJob(severity: String?, executionState: String?, state: String?, includeColumns: [String]?, format: String = "csv", reportType: String = "Malware", completion: @escaping (String?) -> Void) {
        sendRequest({ service, reply in
            service.createMalwareExportJob(severity: severity, executionState: executionState, state: state, includeColumns: includeColumns, format: format, reportType: reportType, reply: reply)
        }, completion: completion)
    }

    /// Creates a MAMAppProtectionStatus export job for mobile application management
    ///
    /// This function creates an export job for Mobile Application Management (MAM) app protection
    /// status reporting, providing insights into application protection policy compliance.
    ///
    /// **Usage Example:**
    /// ```swift
    /// XPCManager.shared.createMAMAppProtectionStatusExportJob(
    ///     includeColumns: ["AppName", "ProtectionStatus", "PolicyName", "UserEmail"],
    ///     format: "csv"
    /// ) { jobId in
    ///     // Handle result
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - includeColumns: Optional array of specific columns to include
    ///   - format: Export format ("csv" or "json", defaults to "csv")
    ///   - completion: Callback with export job ID or nil on failure
    func createMAMAppProtectionStatusExportJob(includeColumns: [String]?, format: String = "csv", completion: @escaping (String?) -> Void) {
        sendRequest({ service, reply in
            service.createMAMAppProtectionStatusExportJob(includeColumns: includeColumns, format: format, reply: reply)
        }, completion: completion)
    }

    /// Creates a MAMAppConfigurationStatus export job for mobile application management
    ///
    /// This function creates an export job for Mobile Application Management (MAM) app configuration
    /// status reporting, providing insights into application configuration policy deployment.
    ///
    /// **Usage Example:**
    /// ```swift
    /// XPCManager.shared.createMAMAppConfigurationStatusExportJob(
    ///     includeColumns: ["AppName", "ConfigurationStatus", "PolicyName", "LastUpdate"],
    ///     format: "json"
    /// ) { jobId in
    ///     // Handle result
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - includeColumns: Optional array of specific columns to include
    ///   - format: Export format ("csv" or "json", defaults to "csv")
    ///   - completion: Callback with export job ID or nil on failure
    func createMAMAppConfigurationStatusExportJob(includeColumns: [String]?, format: String = "csv", completion: @escaping (String?) -> Void) {
        sendRequest({ service, reply in
            service.createMAMAppConfigurationStatusExportJob(includeColumns: includeColumns, format: format, reply: reply)
        }, completion: completion)
    }

    /// Creates a FeatureUpdatePolicyFailuresAggregate export job for Windows update reporting
    ///
    /// This function creates an export job for aggregated feature update policy failure information,
    /// providing insights into Windows feature update deployment issues.
    ///
    /// **Usage Example:**
    /// ```swift
    /// XPCManager.shared.createFeatureUpdatePolicyFailuresAggregateExportJob(
    ///     includeColumns: ["PolicyName", "FailureCount", "ErrorCode", "AffectedDevices"],
    ///     format: "csv"
    /// ) { jobId in
    ///     // Handle result
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - includeColumns: Optional array of specific columns to include
    ///   - format: Export format ("csv" or "json", defaults to "csv")
    ///   - completion: Callback with export job ID or nil on failure
    func createFeatureUpdatePolicyFailuresAggregateExportJob(includeColumns: [String]?, format: String = "csv", completion: @escaping (String?) -> Void) {
        sendRequest({ service, reply in
            service.createFeatureUpdatePolicyFailuresAggregateExportJob(includeColumns: includeColumns, format: format, reply: reply)
        }, completion: completion)
    }

    /// Creates a QualityUpdateDeviceStatusByPolicy export job with policy-specific filtering
    ///
    /// This function creates an export job for quality update device status by policy, providing
    /// detailed information about Windows quality update deployment status per policy.
    ///
    /// **Usage Example:**
    /// ```swift
    /// XPCManager.shared.createQualityUpdateDeviceStatusByPolicyExportJob(
    ///     policyID: "12345678-1234-1234-1234-123456789012",
    ///     aggregateState: "failed",
    ///     ownerType: "company",
    ///     includeColumns: ["DeviceName", "UpdateStatus", "InstallDate", "ErrorCode"],
    ///     format: "csv"
    /// ) { jobId in
    ///     // Handle result
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - policyID: Required policy ID filter
    ///   - aggregateState: Optional filter by aggregate state
    ///   - ownerType: Optional filter by owner type
    ///   - includeColumns: Optional array of specific columns to include
    ///   - format: Export format ("csv" or "json", defaults to "csv")
    ///   - completion: Callback with export job ID or nil on failure
    func createQualityUpdateDeviceStatusByPolicyExportJob(policyID: String, aggregateState: String?, ownerType: String?, includeColumns: [String]?, format: String = "csv", completion: @escaping (String?) -> Void) {
        sendRequest({ service, reply in
            service.createQualityUpdateDeviceStatusByPolicyExportJob(policyID: policyID, aggregateState: aggregateState, ownerType: ownerType, includeColumns: includeColumns, format: format, reply: reply)
        }, completion: completion)
    }

 
}
