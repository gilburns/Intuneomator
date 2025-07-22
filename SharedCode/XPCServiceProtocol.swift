//
//  XPCServiceProtocol.swift
//  Intuneomator
//
//  Created by Gil Burns on 3/12/25.
//

import Foundation

/// XPC service protocol defining the interface between the GUI app and the privileged daemon service
/// Provides secure inter-process communication for authentication, automation, and configuration management
@objc protocol XPCServiceProtocol {
    
    // MARK: - Operation Management
    
    /// Begins a tracked operation with timeout handling
    /// - Parameters:
    ///   - identifier: Unique identifier for the operation
    ///   - timeout: Maximum time allowed for the operation
    ///   - completion: Callback indicating if operation started successfully
    func beginOperation(identifier: String, timeout: TimeInterval, completion: @escaping (Bool) -> Void)
    
    /// Ends a tracked operation
    /// - Parameters:
    ///   - identifier: Unique identifier of the operation to end
    ///   - completion: Callback indicating if operation ended successfully
    func endOperation(identifier: String, completion: @escaping (Bool) -> Void)
    
    /// Tests connectivity to the XPC service
    /// - Parameter completion: Callback indicating if service is responsive
    func ping(completion: @escaping (Bool) -> Void)
        
    // MARK: - Entra Authentication Settings
    
    /// Retrieves the current certificate data
    /// - Parameter reply: Callback with certificate data or nil if not found
    func getCertificate(reply: @escaping (Data?) -> Void)

    /// Imports a P12 certificate file into the system keychain for certificate-based authentication
    /// - Parameters:
    ///   - p12Data: The P12 certificate file data
    ///   - passphrase: Passphrase to decrypt the P12 file
    ///   - reply: Callback indicating if import was successful
    func importP12Certificate(p12Data: Data, passphrase: String, reply: @escaping (Bool) -> Void)
    
    /// Checks if a private key exists in the keychain for certificate authentication
    /// - Parameter reply: Callback indicating if private key exists
    func privateKeyExists(reply: @escaping (Bool) -> Void)
    
    /// Imports an Entra ID client secret into the keychain for secret-based authentication
    /// - Parameters:
    ///   - secretKey: The client secret string
    ///   - reply: Callback indicating if import was successful
    func importEntraIDSecretKey(secretKey: String, reply: @escaping (Bool) -> Void)
    
    /// Checks if an Entra ID secret key exists in the keychain
    /// - Parameter reply: Callback indicating if secret key exists
    func entraIDSecretKeyExists(reply: @escaping (Bool) -> Void)
    
    /// Validates the configured authentication credentials against Microsoft Graph API
    /// - Parameter reply: Callback indicating if credentials are valid
    func validateCredentials(reply: @escaping (Bool) -> Void)
    
    // MARK: - Main Automation Operations
    
    /// Scans all managed label folders and processes automation tasks
    /// - Parameter reply: Callback indicating if scan completed successfully
    func scanAllManagedLabels(reply: @escaping (Bool) -> Void)
    
    /// Updates app metadata in Intune for a specific label
    /// - Parameters:
    ///   - labelFolderName: Name of the label folder to process
    ///   - displayName: Display name of the app
    ///   - reply: Callback with operation result message or nil on failure
    func updateAppMetadata(_ labelFolderName: String, _ displayName: String, reply: @escaping (String?) -> Void)

    /// Updates app installation scripts in Intune for a specific label
    /// - Parameters:
    ///   - labelFolderName: Name of the label folder to process
    ///   - displayName: Display name of the app
    ///   - reply: Callback with operation result message or nil on failure
    func updateAppScripts(_ labelFolderName: String, _ displayName: String, reply: @escaping (String?) -> Void)

    /// Updates app group assignments in Intune for a specific label
    /// - Parameters:
    ///   - labelFolderName: Name of the label folder to process
    ///   - displayName: Display name of the app
    ///   - reply: Callback with operation result message or nil on failure
    func updateAppAssignments(_ labelFolderName: String, _ displayName: String, reply: @escaping (String?) -> Void)

    /// Deletes all automation data from Intune for a specific label
    /// - Parameters:
    ///   - labelFolderName: Name of the label folder to process
    ///   - displayName: Display name of the app
    ///   - reply: Callback with operation result message or nil on failure
    func deleteAutomationsFromIntune(_ labelFolderName: String, _ displayName: String, reply: @escaping (String?) -> Void)

    /// Triggers on-demand automation for a specific label
    /// - Parameters:
    ///   - labelFolderName: Name of the label folder to process
    ///   - displayName: Display name of the app
    ///   - reply: Callback with operation result message or nil on failure
    func onDemandLabelAutomation(_ labelFolderName: String, _ displayName: String, reply: @escaping (String?) -> Void)

    /// Checks Intune for existing automation data
    /// - Parameter reply: Callback indicating if automation data exists
    func checkIntuneForAutomation(reply: @escaping (Bool) -> Void)

    // MARK: - Installomator Label Management
    
    /// Adds new label content from a source (GitHub or custom)
    /// - Parameters:
    ///   - labelName: Name of the new label
    ///   - source: Source location or content for the label
    ///   - reply: Callback with operation result message or nil on failure
    func addNewLabelContent(_ labelName: String, _ source: String, reply: @escaping (String?) -> Void)
    
    /// Removes label content and associated files
    /// - Parameters:
    ///   - labelDirectory: Directory path of the label to remove
    ///   - reply: Callback indicating if removal was successful
    func removeLabelContent(_ labelDirectory: String, reply: @escaping (Bool) -> Void)

    /// Updates all Installomator labels from the official GitHub repository
    /// - Parameter reply: Callback indicating if update was successful
    func updateLabelsFromGitHub(reply: @escaping (Bool) -> Void)

    
    // MARK: - Label Configuration
    
    /// Saves label configuration content to the managed folder
    /// - Parameters:
    ///   - labelFolder: Target label folder name
    ///   - content: Configuration data as NSDictionary
    ///   - reply: Callback indicating if save was successful
    func saveLabelContent(_ labelFolder: String, _ content: NSDictionary, reply: @escaping (Bool) -> Void)

    /// Toggles custom label status for a managed folder
    /// - Parameters:
    ///   - labelFolder: Target label folder name
    ///   - toggle: Whether to enable custom label mode
    ///   - reply: Callback indicating if toggle was successful
    func toggleCustomLabel(_ labelFolder: String, _ toggle: Bool, reply: @escaping (Bool) -> Void)

    // MARK: - Label Editing Operations
    
    /// Imports a custom icon file to a label folder
    /// - Parameters:
    ///   - iconPath: File path to the icon image
    ///   - labelFolder: Target label folder name
    ///   - reply: Callback indicating if import was successful
    func importIconToLabel(_ iconPath: String, _ labelFolder: String, reply: @escaping (Bool) -> Void)
    
    /// Imports a generic default icon to a label folder
    /// - Parameters:
    ///   - labelFolder: Target label folder name
    ///   - reply: Callback indicating if import was successful
    func importGenericIconToLabel(_ labelFolder: String, reply: @escaping (Bool) -> Void)
    
    /// Saves metadata configuration for a label
    /// - Parameters:
    ///   - labelMetadata: JSON string containing metadata
    ///   - labelFolder: Target label folder name
    ///   - reply: Callback indicating if save was successful
    func saveMetadataForLabel(_ labelMetadata: String, _ labelFolder: String, reply: @escaping (Bool) -> Void)
    
    // MARK: - Script Management
    
    /// Saves a pre-installation script for a label
    /// - Parameters:
    ///   - script: Script content as string
    ///   - labelFolder: Target label folder name
    ///   - reply: Callback indicating if save was successful
    func savePreInstallScriptForLabel(_ script: String, _ labelFolder: String, reply: @escaping (Bool) -> Void)

    /// Saves a post-installation script for a label
    /// - Parameters:
    ///   - script: Script content as string
    ///   - labelFolder: Target label folder name
    ///   - reply: Callback indicating if save was successful
    func savePostInstallScriptForLabel(_ script: String, _ labelFolder: String, reply: @escaping (Bool) -> Void)

    // MARK: - Script Library Management
    
    /// Updates all Intuneomator Script Library from the official GitHub repository
    /// - Parameter reply: Callback indicating if update was successful
    func updateScriptLibraryFromGitHub(reply: @escaping (Bool) -> Void)

    // MARK: - Intune App Category Management
    
    /// Fetches mobile app categories from Microsoft Graph
    /// - Parameter reply: Callback with array of category dictionaries or nil on error
    func fetchMobileAppCategories(reply: @escaping ([[String: Any]]?) -> Void)
    
    /// Creates a new mobile app category in Microsoft Intune
    /// - Parameters:
    ///   - categoryData: Dictionary containing category information (displayName is required)
    ///   - reply: Callback with created category ID or nil on error
    func createMobileAppCategory(categoryData: [String: Any], reply: @escaping (String?) -> Void)
    
    /// Updates an existing mobile app category in Microsoft Intune
    /// - Parameters:
    ///   - categoryId: Unique identifier (GUID) of the category to update
    ///   - updatedData: Dictionary containing updated category information
    ///   - reply: Callback indicating success (true) or failure (false)
    func updateMobileAppCategory(categoryId: String, updatedData: [String: Any], reply: @escaping (Bool) -> Void)
    
    /// Deletes a mobile app category from Microsoft Intune
    /// - Parameters:
    ///   - categoryId: Unique identifier (GUID) of the category to delete
    ///   - reply: Callback indicating success (true) or failure (false)
    func deleteMobileAppCategory(categoryId: String, reply: @escaping (Bool) -> Void)

    // MARK: - Intune Mac App Reporting
    
    /// Fetches all macOS Mac Apps from Microsoft Intune
    /// - Parameter reply: Callback with array of web clip dictionaries or nil on failure
    func fetchIntuneApps(reply: @escaping ([[String: Any]]?) -> Void)
    
    /// Retrieves device app installation status report for a specific app from Microsoft Graph reports endpoint
    /// - Parameters:
    ///   - appId: Unique identifier (GUID) of the app to get installation status for
    ///   - reply: Callback with array of device installation status dictionaries or nil on failure
    func getDeviceAppInstallationStatusReport(appId: String, reply: @escaping ([[String: Any]]?) -> Void)
    
    /// Fetches all configuration profiles from Microsoft Intune across all platforms with assignment status
    /// - Parameter reply: Callback with array of configuration profile dictionaries or nil on failure
    func fetchIntuneConfigurationProfiles(reply: @escaping ([[String: Any]]?) -> Void)
    
    /// Retrieves device configuration profile deployment status report for a specific profile
    /// - Parameters:
    ///   - profileId: Unique identifier (GUID) of the configuration profile to get deployment status for
    ///   - reply: Callback with array of device deployment status dictionaries or nil on failure
    func getDeviceConfigProfileDeploymentStatusReport(profileId: String, reply: @escaping ([[String: Any]]?) -> Void)
    
    // MARK: - Microsoft Graph Export Jobs API
    
    /// Creates a new export job for a specific report type
    /// - Parameters:
    ///   - reportName: Name of the report to export (e.g., "DeviceInstallStatusByApp")
    ///   - filter: Optional OData filter string
    ///   - select: Optional array of column names to include
    ///   - format: Export format ("csv" or "json", defaults to "csv")
    ///   - reply: Callback with export job ID or nil on failure
    func createExportJob(reportName: String, filter: String?, select: [String]?, format: String, reply: @escaping (String?) -> Void)
    
    /// Checks the status of an export job
    /// - Parameters:
    ///   - jobId: Export job ID to check
    ///   - reply: Callback with job status dictionary or nil on failure
    func getExportJobStatus(jobId: String, reply: @escaping ([String: Any]?) -> Void)
    
    /// Downloads completed export job data
    /// - Parameters:
    ///   - downloadUrl: Download URL from completed export job
    ///   - reply: Callback with downloaded data or nil on failure
    func downloadExportJobData(downloadUrl: String, reply: @escaping (Data?) -> Void)
    
    /// Polls an export job until completion and downloads the result
    /// - Parameters:
    ///   - jobId: Export job ID to poll
    ///   - maxWaitTimeSeconds: Maximum time to wait for completion (default: 300)
    ///   - pollIntervalSeconds: Interval between status checks (default: 5)
    ///   - reply: Callback with downloaded data or nil on failure
    func pollAndDownloadExportJob(jobId: String, maxWaitTimeSeconds: Int, pollIntervalSeconds: Int, reply: @escaping (Data?) -> Void)

    // MARK: - Microsoft Graph Export Job Reports
    /// Creates a DeviceInstallStatusByApp export job with filtering options
    /// - Parameters:
    ///   - applicationId: Optional filter by specific application ID
    ///   - deviceName: Optional filter by device name
    ///   - userName: Optional filter by user name
    ///   - includeColumns: Optional array of specific columns to include
    ///   - format: Export format ("csv" or "json", defaults to "csv")
    ///   - reply: Callback with export job ID or nil on failure
    func createDeviceInstallStatusByAppExportJob(applicationId: String?, deviceName: String?, userName: String?, includeColumns: [String]?, format: String, reply: @escaping (String?) -> Void)

    /// Creates a UserInstallStatusAggregateByApp export job with filtering options
    /// - Parameters:
    ///   - applicationId: Optional filter by specific application ID
    ///   - deviceName: Optional filter by device name
    ///   - userName: Optional filter by user name
    ///   - includeColumns: Optional array of specific columns to include
    ///   - reply: Callback with export job ID or nil on failure
    func createUserInstallStatusAggregateByAppExportJob(applicationId: String?, deviceName: String?, userName: String?, includeColumns: [String]?, format: String, reply: @escaping (String?) -> Void)

    /// Creates a AppInvByDevice export job with filtering options
    /// - Parameters:
    ///   - deviceId: Optional filter by specific device ID
    ///   - includeColumns: Optional array of specific columns to include
    ///   - format: Export format ("csv" or "json", defaults to "csv")
    ///   - reply: Callback with export job ID or nil on failure
    func createAppInvByDeviceExportJob(deviceId: String, includeColumns: [String]?, format: String, reply: @escaping (String?) -> Void)

    /// Creates an AllAppsList export job
    /// - Parameters:
    ///   - includeColumns: Optional array of specific columns to include
    ///   - format: Export format ("csv" or "json")
    ///   - reply: Callback with export job ID or nil on failure
    func createAllAppsListExportJob(includeColumns: [String]?, format: String, reply: @escaping (String?) -> Void)
    
    /// Creates an AppInstallStatusAggregate export job
    /// - Parameters:
    ///   - platform: Optional filter by platform
    ///   - failedDevicePercentage: Optional filter by failed device percentage
    ///   - includeColumns: Optional array of specific columns to include
    ///   - format: Export format ("csv" or "json")
    ///   - reply: Callback with export job ID or nil on failure
    func createAppInstallStatusAggregateExportJob(platform: String?, failedDevicePercentage: String?, includeColumns: [String]?, format: String, reply: @escaping (String?) -> Void)
    
    /// Creates an AppInvAggregate export job
    /// - Parameters:
    ///   - includeColumns: Optional array of specific columns to include
    ///   - format: Export format ("csv" or "json")
    ///   - reply: Callback with export job ID or nil on failure
    func createAppInvAggregateExportJob(includeColumns: [String]?, format: String, reply: @escaping (String?) -> Void)

    /// Creates an AppInvRawData export job with filtering options
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
    ///   - format: Export format ("csv" or "json")
    ///   - reply: Callback with export job ID or nil on failure
    func createAppInvRawDataExportJob(applicationName: String?, applicationPublisher: String?, applicationShortVersion: String?, applicationVersion: String?, deviceId: String?, deviceName: String?, osDescription: String?, osVersion: String?, platform: String?, userId: String?, emailAddress: String?, userName: String?, includeColumns: [String]?, format: String, reply: @escaping (String?) -> Void)

    /// Creates a DeviceCompliance export job with filtering options
    /// - Parameters:
    ///   - complianceState: Optional filter by compliance state
    ///   - os: Optional filter by OS
    ///   - ownerType: Optional filter by owner type
    ///   - deviceType: Optional filter by device type
    ///   - includeColumns: Optional array of specific columns to include
    ///   - format: Export format ("csv" or "json")
    ///   - reply: Callback with export job ID or nil on failure
    func createDeviceComplianceExportJob(complianceState: String?, os: String?, ownerType: String?, deviceType: String?, includeColumns: [String]?, format: String, reply: @escaping (String?) -> Void)

    /// Creates a DeviceNonCompliance export job with filtering options
    /// - Parameters:
    ///   - complianceState: Optional filter by compliance state
    ///   - os: Optional filter by OS
    ///   - ownerType: Optional filter by owner type
    ///   - deviceType: Optional filter by device type
    ///   - userId: Optional filter by user ID
    ///   - includeColumns: Optional array of specific columns to include
    ///   - format: Export format ("csv" or "json")
    ///   - reply: Callback with export job ID or nil on failure
    func createDeviceNonComplianceExportJob(complianceState: String?, os: String?, ownerType: String?, deviceType: String?, userId: String?, includeColumns: [String]?, format: String, reply: @escaping (String?) -> Void)

    /// Creates a Devices export job with filtering options
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
    ///   - format: Export format ("csv" or "json")
    ///   - reply: Callback with export job ID or nil on failure
    func createDevicesExportJob(ownerType: String?, deviceType: String?, managementAgents: String?, categoryName: String?, managementState: String?, compliantState: String?, jailBroken: String?, enrollmentType: String?, includeColumns: [String]?, format: String, reply: @escaping (String?) -> Void)
    
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
    func createDevicesWithInventoryExportJob(createdDate: String?, lastContact: String?, categoryName: String?, compliantState: String?, managementAgents: String?, ownerType: String?, managementState: String?, deviceType: String?, jailBroken: String?, enrollmentType: String?, includeColumns: [String]?, format: String, reply: @escaping (String?) -> Void)

    /// Creates a DefenderAgents export job with filtering options
    /// - Parameters:
    ///   - deviceState: Optional filter by device state
    ///   - signatureUpdateOverdue: Optional filter by signature update overdue
    ///   - malwareProtectionEnabled: Optional filter by malware protection enabled
    ///   - realTimeProtectionEnabled: Optional filter by real-time protection enabled
    ///   - networkInspectionSystemEnabled: Optional filter by network inspection system enabled
    ///   - includeColumns: Optional array of specific columns to include
    ///   - format: Export format ("csv" or "json")
    ///   - reportType: Report type ("DefenderAgents" or "UnhealthyDefenderAgents")
    ///   - reply: Callback with export job ID or nil on failure
    func createDefenderAgentsExportJob(deviceState: String?, signatureUpdateOverdue: String?, malwareProtectionEnabled: String?, realTimeProtectionEnabled: String?, networkInspectionSystemEnabled: String?, includeColumns: [String]?, format: String, reportType: String, reply: @escaping (String?) -> Void)

    /// Creates a FirewallStatus export job with filtering options
    /// - Parameters:
    ///   - firewallStatus: Optional filter by firewall status
    ///   - includeColumns: Optional array of specific columns to include
    ///   - format: Export format ("csv" or "json")
    ///   - reply: Callback with export job ID or nil on failure
    func createFirewallStatusExportJob(firewallStatus: String?, includeColumns: [String]?, format: String, reply: @escaping (String?) -> Void)

    /// Creates a Malware export job with filtering options
    /// - Parameters:
    ///   - severity: Optional filter by severity
    ///   - executionState: Optional filter by execution state
    ///   - state: Optional filter by state
    ///   - includeColumns: Optional array of specific columns to include
    ///   - format: Export format ("csv" or "json")
    ///   - reportType: Report type ("Malware" or "ActiveMalware")
    ///   - reply: Callback with export job ID or nil on failure
    func createMalwareExportJob(severity: String?, executionState: String?, state: String?, includeColumns: [String]?, format: String, reportType: String, reply: @escaping (String?) -> Void)

    /// Creates a MAMAppProtectionStatus export job
    /// - Parameters:
    ///   - includeColumns: Optional array of specific columns to include
    ///   - format: Export format ("csv" or "json")
    ///   - reply: Callback with export job ID or nil on failure
    func createMAMAppProtectionStatusExportJob(includeColumns: [String]?, format: String, reply: @escaping (String?) -> Void)

    /// Creates a MAMAppConfigurationStatus export job
    /// - Parameters:
    ///   - includeColumns: Optional array of specific columns to include
    ///   - format: Export format ("csv" or "json")
    ///   - reply: Callback with export job ID or nil on failure
    func createMAMAppConfigurationStatusExportJob(includeColumns: [String]?, format: String, reply: @escaping (String?) -> Void)

    /// Creates a FeatureUpdatePolicyFailuresAggregate export job
    /// - Parameters:
    ///   - includeColumns: Optional array of specific columns to include
    ///   - format: Export format ("csv" or "json")
    ///   - reply: Callback with export job ID or nil on failure
    func createFeatureUpdatePolicyFailuresAggregateExportJob(includeColumns: [String]?, format: String, reply: @escaping (String?) -> Void)

    /// Creates a QualityUpdateDeviceStatusByPolicy export job with filtering options
    /// - Parameters:
    ///   - policyID: Required filter by policy ID
    ///   - aggregateState: Optional filter by aggregate state
    ///   - ownerType: Optional filter by owner type
    ///   - includeColumns: Optional array of specific columns to include
    ///   - format: Export format ("csv" or "json")
    ///   - reply: Callback with export job ID or nil on failure
    func createQualityUpdateDeviceStatusByPolicyExportJob(policyID: String, aggregateState: String?, ownerType: String?, includeColumns: [String]?, format: String, reply: @escaping (String?) -> Void)

    // MARK: - Intune Web Clip Management
    
    /// Fetches all macOS Web Clips from Microsoft Intune
    /// - Parameter reply: Callback with array of web clip dictionaries or nil on failure
    func fetchIntuneWebClips(reply: @escaping ([[String: Any]]?) -> Void)
    
    /// Creates a new macOS Web Clip in Microsoft Intune with full assignment support
    /// Automatically handles categories and group assignments if provided in the data
    /// - Parameters:
    ///   - webClipData: Dictionary containing web clip information (displayName and appUrl are required)
    ///                  May optionally include "categories" and "assignments" for automatic assignment
    ///   - reply: Callback with created web clip ID or nil on failure
    func createIntuneWebClip(webClipData: [String: Any], reply: @escaping (String?) -> Void)
    
    /// Updates an existing macOS Web Clip in Microsoft Intune
    /// - Parameters:
    ///   - webClipId: Unique identifier (GUID) of the web clip to update
    ///   - updatedData: Dictionary containing updated web clip information
    ///   - reply: Callback indicating success (true) or failure (false)
    func updateWebClip(webClipId: String, updatedData: [String: Any], reply: @escaping (Bool) -> Void)
    
    /// Deletes a macOS Web Clip from Microsoft Intune
    /// - Parameters:
    ///   - webClipId: Unique identifier (GUID) of the web clip to delete
    ///   - reply: Callback indicating success (true) or failure (false)
    func deleteWebClip(webClipId: String, reply: @escaping (Bool) -> Void)
    
    /// Fetches complete web clip details, group assignments, and category assignments for a specific web clip
    /// Returns full web clip data including largeIcon for editing purposes
    /// - Parameters:
    ///   - webClipId: Unique identifier (GUID) of the web clip
    ///   - reply: Callback with complete web clip data including assignments and categories, or nil on failure
    func fetchWebClipAssignmentsAndCategories(webClipId: String, reply: @escaping ([String: Any]?) -> Void)
    
    /// Updates an existing web clip with categories and group assignments in a comprehensive workflow
    /// Handles the complete update sequence: PATCH web clip → update categories → update assignments
    /// - Parameters:
    ///   - webClipData: Complete web clip data including properties, categories, and assignments
    ///   - reply: Callback indicating if the complete update workflow was successful
    func updateWebClipWithAssignments(webClipData: [String: Any], reply: @escaping (Bool) -> Void)

    // MARK: - Intune Shell Script Management
    
    /// Fetches all Intune Shell Scripts from Microsoft Graph with pagination support
    /// - Parameter reply: Callback with array of shell script dictionaries or nil on failure
    func fetchIntuneShellScripts(reply: @escaping ([[String: Any]]?) -> Void)
    
    /// Uploads a shell script file to Microsoft Intune
    /// - Parameters:
    ///   - scriptPath: Absolute file path to the shell script file
    ///   - scriptName: Display name for the script in Intune
    ///   - runAsAccount: Execution context ("system" or "user")
    ///   - retryCount: Number of retry attempts (1-5)
    ///   - blockExecutionNotifications: Whether to suppress execution notifications
    ///   - reply: Callback indicating if upload was successful
    func uploadShellScript(scriptPath: String, scriptName: String, runAsAccount: String, retryCount: Int, blockExecutionNotifications: Bool, reply: @escaping (Bool) -> Void)
    
    /// Creates a new shell script in Intune with custom configuration data
    /// - Parameters:
    ///   - scriptData: Dictionary containing script configuration
    ///   - reply: Callback with the script ID or nil on failure
    func createNewShellScript(scriptData: [String: Any], reply: @escaping (String?) -> Void)
    
    /// Retrieves detailed information about a specific shell script
    /// - Parameters:
    ///   - scriptId: Unique identifier of the script
    ///   - reply: Callback with script details dictionary or nil on failure
    func getShellScriptDetails(scriptId: String, reply: @escaping ([String: Any]?) -> Void)
    
    /// Permanently deletes a shell script from Intune
    /// - Parameters:
    ///   - scriptId: Unique identifier of the script to delete
    ///   - reply: Callback indicating if deletion was successful
    func deleteShellScript(scriptId: String, reply: @escaping (Bool) -> Void)
    
    /// Updates an existing shell script with new configuration or content
    /// - Parameters:
    ///   - scriptId: Unique identifier of the script to update
    ///   - updatedData: Dictionary containing properties to update
    ///   - reply: Callback indicating if update was successful
    func updateShellScript(scriptId: String, updatedData: [String: Any], reply: @escaping (Bool) -> Void)

    // MARK: - Shell Script Group Assignment Management
    
    /// Assigns Entra ID groups to a shell script in Microsoft Intune
    /// - Parameters:
    ///   - scriptId: Unique identifier of the shell script
    ///   - groupAssignments: Array of assignment dictionaries containing group IDs
    ///   - reply: Callback indicating if assignment was successful
    func assignGroupsToShellScript(scriptId: String, groupAssignments: [[String: Any]], reply: @escaping (Bool) -> Void)
    
    /// Retrieves current group assignments for a shell script
    /// - Parameters:
    ///   - scriptId: Unique identifier of the shell script
    ///   - reply: Callback with array of assignment dictionaries or nil on failure
    func getShellScriptAssignments(scriptId: String, reply: @escaping ([[String: Any]]?) -> Void)
    
    /// Removes all group assignments from a shell script
    /// - Parameters:
    ///   - scriptId: Unique identifier of the shell script
    ///   - reply: Callback indicating if removal was successful
    func removeAllShellScriptAssignments(scriptId: String, reply: @escaping (Bool) -> Void)
    
    /// Removes a specific group assignment from a shell script
    /// - Parameters:
    ///   - scriptId: Unique identifier of the shell script
    ///   - assignmentId: Unique identifier of the assignment to remove
    ///   - reply: Callback indicating if removal was successful
    func removeShellScriptAssignment(scriptId: String, assignmentId: String, reply: @escaping (Bool) -> Void)

    /// Retrieves device run states for a specific shell script
    /// - Parameters:
    ///   - scriptId: Unique identifier of the shell script
    ///   - reply: Callback with array of device run state dictionaries or nil on failure
    func getShellScriptDeviceRunStates(scriptId: String, reply: @escaping ([[String: Any]]?) -> Void)

    // MARK: - Intune Custom Attribute Shell Script Management
    
    /// Fetches all Intune Custom Attribute Shell Scripts from Microsoft Graph with pagination support
    /// - Parameter reply: Callback with array of custom attribute shell script dictionaries or nil on failure
    func fetchIntuneCustomAttributeShellScripts(reply: @escaping ([[String: Any]]?) -> Void)
    
    /// Uploads a shell script file to Microsoft Intune
    /// - Parameters:
    ///   - customAttributeName: The name of the custom attribute
    ///   - customAttributeType: The expected type of the custom attribute's value
    ///   - displayName: Display name for the custom attribute script in Intune
    ///   - description: Optional description for the device management script
    ///   - runAsAccount: Execution context ("system" or "user")
    ///   - retryCount: Number of retry attempts (1-5)
    ///   - blockExecutionNotifications: Whether to suppress execution notifications
    ///   - reply: Callback indicating if upload was successful
    func uploadCustomAttributeShellScript(scriptPath: String, scriptName: String, runAsAccount: String, retryCount: Int, blockExecutionNotifications: Bool, reply: @escaping (Bool) -> Void)
    
    /// Creates a new shell script in Intune with custom configuration data
    /// - Parameters:
    ///   - scriptData: Dictionary containing script configuration
    ///   - reply: Callback with the script ID or nil on failure
    func createNewCustomAttributeShellScript(scriptData: [String: Any], reply: @escaping (String?) -> Void)
    
    /// Retrieves detailed information about a specific custom attribute shell script
    /// - Parameters:
    ///   - scriptId: Unique identifier of the script
    ///   - reply: Callback with script details dictionary or nil on failure
    func getCustomAttributeShellScriptDetails(scriptId: String, reply: @escaping ([String: Any]?) -> Void)
    
    /// Permanently deletes a custom attribute shell script from Intune
    /// - Parameters:
    ///   - scriptId: Unique identifier of the custom attribute script to delete
    ///   - reply: Callback indicating if deletion was successful
    func deleteCustomAttributeShellScript(scriptId: String, reply: @escaping (Bool) -> Void)
    
    /// Updates an existing custom attribute shell script with new configuration or content
    /// - Parameters:
    ///   - scriptId: Unique identifier of the custom attribute script to update
    ///   - updatedData: Dictionary containing properties to update
    ///   - reply: Callback indicating if update was successful
    func updateCustomAttributeShellScript(scriptId: String, updatedData: [String: Any], reply: @escaping (Bool) -> Void)

    // MARK: - Custom Attribute Shell Script Group Assignment Management
    
    /// Assigns Entra ID groups to a shell script in Microsoft Intune
    /// - Parameters:
    ///   - scriptId: Unique identifier of the shell script
    ///   - groupAssignments: Array of assignment dictionaries containing group IDs
    ///   - reply: Callback indicating if assignment was successful
    func assignGroupsToCustomAttributeShellScript(scriptId: String, groupAssignments: [[String: Any]], reply: @escaping (Bool) -> Void)
    
    /// Retrieves current group assignments for a shell script
    /// - Parameters:
    ///   - scriptId: Unique identifier of the shell script
    ///   - reply: Callback with array of assignment dictionaries or nil on failure
    func getCustomAttributeShellScriptAssignments(scriptId: String, reply: @escaping ([[String: Any]]?) -> Void)
    
    /// Removes all group assignments from a shell script
    /// - Parameters:
    ///   - scriptId: Unique identifier of the shell script
    ///   - reply: Callback indicating if removal was successful
    func removeAllCustomAttributeShellScriptAssignments(scriptId: String, reply: @escaping (Bool) -> Void)
    
    /// Removes a specific group assignment from a shell script
    /// - Parameters:
    ///   - scriptId: Unique identifier of the shell script
    ///   - assignmentId: Unique identifier of the assignment to remove
    ///   - reply: Callback indicating if removal was successful
    func removeCustomAttributeShellScriptAssignment(scriptId: String, assignmentId: String, reply: @escaping (Bool) -> Void)
    
    /// Retrieves device run states for a specific custom attribute shell script
    /// - Parameters:
    ///   - scriptId: Unique identifier of the custom attribute shell script
    ///   - reply: Callback with array of device run state dictionaries or nil on failure
    func getCustomAttributeShellScriptDeviceRunStates(scriptId: String, reply: @escaping ([[String: Any]]?) -> Void)

    // MARK: - Group Assignment Management
    
    /// Saves Azure AD group assignments for a label
    /// - Parameters:
    ///   - groupAssignments: Array of group assignment configurations
    ///   - labelFolder: Target label folder name
    ///   - reply: Callback indicating if save was successful
    func saveGroupAssignmentsForLabel(_ groupAssignments: [[String: Any]], _ labelFolder: String, reply: @escaping (Bool) -> Void)
    
    // MARK: - Device and App Discovery
    
    /// Fetches managed devices from Intune
    /// - Parameter reply: Callback with JSON-encoded managed devices data or nil on error
    func fetchManagedDevices(reply: @escaping ([[String : Any]]?) -> Void)

    
    /// Get details of a  managed devices from Intune
    /// - Parameter reply: Callback with JSON-encoded managed device details or nil on error
    func getManagedDeviceDetails(deviceId: String, reply: @escaping ([String : Any]?) -> Void)

    /// Retrieves device compliance policy states for a specific managed device
    /// - Parameters:
    ///   - deviceId: Unique identifier (GUID) of the managed device
    ///   - reply: Callback with array of compliance policy state dictionaries or nil on failure
    func getDeviceCompliancePolicyStates(deviceId: String, reply: @escaping ([[String: Any]]?) -> Void)

    /// Retrieves device configuration states for a specific managed device
    /// - Parameters:
    ///   - deviceId: Unique identifier (GUID) of the managed device
    ///   - reply: Callback with array of configuration state dictionaries or nil on failure
    func getDeviceConfigurationStates(deviceId: String, reply: @escaping ([[String: Any]]?) -> Void)

    /// Retrieves Windows protection state for a specific managed Windows device
    /// - Parameters:
    ///   - deviceId: Unique identifier (GUID) of the managed Windows device
    ///   - reply: Callback with Windows protection state dictionary or nil on failure
    func getWindowsProtectionState(deviceId: String, reply: @escaping ([String: Any]?) -> Void)

    /// Fetches discovered macOS applications from Intune
    /// - Parameter reply: Callback with JSON-encoded app data or nil on error
    func fetchDiscoveredMacApps(reply: @escaping (Data?) -> Void)
    
    /// Fetches device information for a specific app ID from Intune
    /// - Parameters:
    ///   - appID: Intune application identifier
    ///   - reply: Callback with JSON-encoded device data or nil on error
    func fetchDevices(forAppID appID: String, reply: @escaping (Data?) -> Void)

    // MARK: - Task Scheduling
    
    /// Creates or updates a scheduled automation task using Launch Daemon
    /// - Parameters:
    ///   - label: Unique identifier for the scheduled task
    ///   - argument: Command line argument for the task
    ///   - scheduleData: Encoded schedule configuration data
    ///   - reply: Callback with success status and optional message
    func createOrUpdateScheduledTask(
        label: String,
        argument: String,
        scheduleData: Data,
        withReply reply: @escaping (Bool, String?) -> Void
    )
    
    /// Removes a scheduled automation task
    /// - Parameters:
    ///   - label: Unique identifier of the task to remove
    ///   - reply: Callback with success status and optional message
    func removeScheduledTask(
        label: String,
        withReply reply: @escaping (Bool, String?) -> Void
    )
    
    /// Checks if a scheduled task exists
    /// - Parameters:
    ///   - label: Unique identifier of the task to check
    ///   - reply: Callback indicating if task exists
    func taskExists(
        label: String,
        withReply reply: @escaping (Bool) -> Void
    )
    
    /// Toggles the enabled/disabled state of a scheduled task
    /// - Parameters:
    ///   - label: Unique identifier of the task to toggle
    ///   - enable: True to enable the task, false to disable it
    ///   - reply: Callback with success status and optional message
    func toggleScheduledTask(
        label: String,
        enable: Bool,
        withReply reply: @escaping (Bool, String?) -> Void
    )
    
    // MARK: - Microsoft Graph API
        
    /// Fetches Azure AD groups from Microsoft Graph
    /// - Parameter reply: Callback with array of group dictionaries or nil on error
    func fetchEntraGroups(reply: @escaping ([[String: Any]]?) -> Void)
    
    /// Searches Azure AD groups by name with startswith filtering
    /// - Parameters:
    ///   - searchQuery: Text to search for in group display names
    ///   - maxResults: Maximum number of results to return
    ///   - reply: Callback with array of matching group dictionaries or nil on error
    func searchEntraGroups(searchQuery: String, maxResults: Int, reply: @escaping ([[String: Any]]?) -> Void)
    
    /// Searches Azure AD groups by name with contains filtering for broader matching
    /// - Parameters:
    ///   - searchQuery: Text to search for anywhere in group display names
    ///   - maxResults: Maximum number of results to return
    ///   - reply: Callback with array of matching group dictionaries or nil on error
    func searchEntraGroupsContains(searchQuery: String, maxResults: Int, reply: @escaping ([[String: Any]]?) -> Void)
    
    /// Fetches macOS assignment filters from Microsoft Graph
    /// - Parameter reply: Callback with array of filter dictionaries or nil on error
    func fetchAssignmentFiltersForMac(reply: @escaping ([[String: Any]]?) -> Void)
    
    // MARK: - Configuration Setters
    
    /// Sets the number of apps to keep in cache management
    func setAppsToKeep(_ appCount: Int, reply: @escaping (Bool) -> Void)
    
    /// Sets the first run completion status
    func setFirstRunStatus(_ completed: Bool, reply: @escaping (Bool) -> Void)
    
    /// Sets the authentication method (certificate or secret)
    func setAuthMethod(_ method: String, reply: @escaping (Bool) -> Void)
    
    /// Sets the Azure AD tenant identifier
    func setTenantID(_ tenantID: String, reply: @escaping (Bool) -> Void)
    
    /// Sets the Azure AD application (client) identifier
    func setApplicationID(_ applicationID: String, reply: @escaping (Bool) -> Void)
    
    /// Enables or disables Teams notifications globally
    func setTeamsNotificationsEnabled(_ enabled: Bool, reply: @escaping (Bool) -> Void)
    
    /// Enables or disables Teams notifications for cache cleanup operations
    func setTeamsNotificationsForCleanup(_ enabled: Bool, reply: @escaping (Bool) -> Void)
    
    /// Enables or disables Teams notifications for CVE vulnerability alerts
    func setTeamsNotificationsForCVEs(_ enabled: Bool, reply: @escaping (Bool) -> Void)
    
    /// Enables or disables Teams notifications for group assignment information
    func setTeamsNotificationsForGroups(_ enabled: Bool, reply: @escaping (Bool) -> Void)
    
    /// Enables or disables Teams notifications for Installomator label updates
    func setTeamsNotificationsForLabelUpdates(_ enabled: Bool, reply: @escaping (Bool) -> Void)
    
    /// Enables or disables Teams notifications for application updates
    func setTeamsNotificationsForUpdates(_ enabled: Bool, reply: @escaping (Bool) -> Void)
    
    /// Sets the Teams notification style preference
    func setTeamsNotificationsStyle(_ enabled: Int, reply: @escaping (Bool) -> Void)
    
    /// Sets the Microsoft Teams webhook URL for notifications
    func setTeamsWebhookURL(_ url: String, reply: @escaping (Bool) -> Void)
    
    /// Sets the maximum age for log file retention
    func setLogAgeMax(_ logAgeMax: Int, reply: @escaping (Bool) -> Void)
    
    /// Sets the maximum size for log files
    func setLogSizeMax(_ logSizeMax: Int, reply: @escaping (Bool) -> Void)
    
    /// Sets the automatic update mode for Intuneomator
    func setIntuneomatorUpdateMode(_ updateMode: Int, reply: @escaping (Bool) -> Void)
    
    /// Sets the expiration date for the client secret
    func setSecretExpirationDate(_ expirationDate: Date, reply: @escaping (Bool) -> Void)

    
    // MARK: - Configuration Getters
    
    /// Gets the number of apps to keep in cache management
    func getAppsToKeep(reply: @escaping (Int) -> Void)
    
    /// Gets the first run completion status
    func getFirstRunStatus(reply: @escaping (Bool) -> Void)
    
    /// Gets the configured authentication method
    func getAuthMethod(reply: @escaping (String) -> Void)
    
    /// Gets the Azure AD tenant identifier
    func getTenantID(reply: @escaping (String) -> Void)
    
    /// Gets the Azure AD application (client) identifier
    func getApplicationID(reply: @escaping (String) -> Void)
    
    /// Gets the Teams notifications global enabled status
    func getTeamsNotificationsEnabled(reply: @escaping (Bool) -> Void)
    
    /// Gets the Teams notifications status for cleanup operations
    func getTeamsNotificationsForCleanup(reply: @escaping (Bool) -> Void)
    
    /// Gets the Teams notifications status for CVE alerts
    func getTeamsNotificationsForCVEs(reply: @escaping (Bool) -> Void)
    
    /// Gets the Teams notifications status for group assignments
    func getTeamsNotificationsForGroups(reply: @escaping (Bool) -> Void)
    
    /// Gets the Teams notifications status for label updates
    func getTeamsNotificationsForLabelUpdates(reply: @escaping (Bool) -> Void)
    
    /// Gets the Teams notifications status for application updates
    func getTeamsNotificationsForUpdates(reply: @escaping (Bool) -> Void)
    
    /// Gets the Teams notification style preference
    func getTeamsNotificationsStyle(reply: @escaping (Int) -> Void)
    
    /// Gets the Microsoft Teams webhook URL
    func getTeamsWebhookURL(reply: @escaping (String) -> Void)
    
    /// Gets the certificate thumbprint if available
    func getCertThumbprint(reply: @escaping (String?) -> Void)
    
    /// Gets the certificate expiration date if available
    func getCertExpiration(reply: @escaping (Date?) -> Void)
    
    /// Gets the client secret if available (for display purposes)
    func getClientSecret(reply: @escaping (String?) -> Void)
    
    /// Gets the maximum age for log file retention
    func getLogAgeMax(reply: @escaping (Int) -> Void)
    
    /// Gets the maximum size for log files
    func getLogSizeMax(reply: @escaping (Int) -> Void)
    
    /// Gets the automatic update mode setting
    func getIntuneomatorUpdateMode(reply: @escaping (Int) -> Void)

    /// Gets the client secret expiration date if available
    func getSecretExpirationDate(reply: @escaping (Date?) -> Void)
    
    // MARK: - Automation Trigger
    
    /// Triggers daemon by creating the appropriate trigger file for Launch Daemon processing
    /// - Parameters:
    ///   - triggerType: Type of trigger to create ("automation", "updatecheck", "cachecleaner", "labelupdater")
    ///   - reply: Callback with success status and optional message
    func triggerDaemon(triggerType: String, reply: @escaping (Bool, String?) -> Void)
    
    /// Checks if automation is currently running by examining the status file
    /// - Parameter reply: Callback indicating if automation is active
    func isAutomationRunning(reply: @escaping (Bool) -> Void)
    
    // MARK: - System Information
    
    /// Gets the total size of the cache folder in bytes
    /// - Parameter completion: Callback with folder size in bytes
    func getCacheFolderSize(completion: @escaping (Int64) -> Void)
    
    /// Gets the total size of the log folder in bytes
    /// - Parameter completion: Callback with folder size in bytes
    func getLogFolderSize(completion: @escaping (Int64) -> Void)
    
    // MARK: - Status Management
    
    /// Cleans up stale operation status entries
    /// - Parameter completion: Callback with number of operations removed
    func cleanupStaleOperations(completion: @escaping (Int) -> Void)
    
    /// Clears all error operation status entries
    /// - Parameter completion: Callback with number of operations removed
    func clearAllErrorOperations(completion: @escaping (Int) -> Void)
    
    /// Gets the daemon service version string
    /// - Parameter completion: Callback with version string (e.g., "1.0.0.163")
    func getDaemonVersion(completion: @escaping (String) -> Void)
    
    /// Gets the updater tool version string
    /// - Parameter completion: Callback with version string (e.g., "1.0.0.162") or "Unknown" if unavailable
    func getUpdaterVersion(completion: @escaping (String) -> Void)
}
