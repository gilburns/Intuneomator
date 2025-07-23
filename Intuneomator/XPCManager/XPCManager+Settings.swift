//
//  XPCManager+Settings.swift
//  Intuneomator
//
//  Created by Gil Burns on 5/4/25.
//

import Foundation

/// XPCManager extension for application configuration and settings management
/// Provides GUI access to read and write configuration values through the privileged service
/// All settings are persisted securely and accessible across application components
extension XPCManager {
    
    // MARK: - Configuration Update Methods
    /// Updates the first-run setup completion status
    /// Marks whether initial application configuration has been completed
    /// - Parameters:
    ///   - completed: Boolean indicating setup completion status
    ///   - completion: Callback with update success status or nil on XPC failure
    func setFirstRunCompleted(_ completed: Bool, completion: @escaping (Bool?) -> Void) {
        sendRequest({ $0.setFirstRunStatus(completed, reply: $1) }, completion: completion)
    }
    
    /// Configures the number of application versions to retain in cache
    /// Controls cache cleanup behavior for managed application downloads
    /// - Parameters:
    ///   - appCount: Integer count of versions to keep for each application
    ///   - completion: Callback with update success status or nil on XPC failure
    func setAppsToKeep(_ appCount: Int, completion: @escaping (Bool?) -> Void) {
        sendRequest({ $0.setAppsToKeep(appCount, reply: $1) }, completion: completion)
    }

    /// Sets the authentication method for Microsoft Graph API access
    /// Determines whether to use certificate-based or secret-based authentication
    /// - Parameters:
    ///   - method: Authentication method ("certificate" or "secret")
    ///   - completion: Callback with update success status or nil on XPC failure
    func setAuthMethod(_ method: String, completion: @escaping (Bool?) -> Void) {
        sendRequest({ $0.setAuthMethod(method, reply: $1) }, completion: completion)
    }

    
    /// Sets the expiration date for the stored client secret
    /// Enables proactive monitoring and renewal of authentication credentials
    /// - Parameters:
    ///   - expirationDate: Date when the client secret will expire
    ///   - completion: Callback with update success status or nil on XPC failure
    func setSecretExpirationDate(_ expirationDate: Date, completion: @escaping (Bool?) -> Void) {
        sendRequest({ $0.setSecretExpirationDate(expirationDate, reply: $1) }, completion: completion)
    }

    /// Configures the Microsoft Entra ID (Azure AD) tenant identifier
    /// Essential for establishing proper authentication context
    /// - Parameters:
    ///   - tenantID: Tenant ID string from Azure AD
    ///   - completion: Callback with update success status or nil on XPC failure
    func setTenantID(_ tenantID: String, completion: @escaping (Bool?) -> Void) {
        sendRequest({ $0.setTenantID(tenantID, reply: $1) }, completion: completion)
    }
    
    /// Sets the Microsoft Entra ID application (client) identifier
    /// Required for OAuth authentication and API authorization
    /// - Parameters:
    ///   - appID: Application ID string from Azure AD app registration
    ///   - completion: Callback with update success status or nil on XPC failure
    func setApplicationID(_ appID: String, completion: @escaping (Bool?) -> Void) {
        sendRequest({ $0.setApplicationID(appID, reply: $1) }, completion: completion)
    }
    
    /// Enables or disables Microsoft Teams webhook notifications globally
    /// Master switch for all Teams notification functionality
    /// - Parameters:
    ///   - enabled: Boolean to enable/disable Teams notifications
    ///   - completion: Callback with update success status or nil on XPC failure
    func setTeamsNotificationsEnabled(_ enabled: Bool, completion: @escaping (Bool?) -> Void) {
        sendRequest({ $0.setTeamsNotificationsEnabled(enabled, reply: $1) }, completion: completion)
    }
    
    /// Configures the Microsoft Teams webhook URL for notifications
    /// Required endpoint for posting automation updates to Teams channels
    /// - Parameters:
    ///   - url: Teams webhook URL string
    ///   - completion: Callback with update success status or nil on XPC failure
    func setTeamsWebhookURL(_ url: String, completion: @escaping (Bool?) -> Void) {
        sendRequest({ $0.setTeamsWebhookURL(url, reply: $1) }, completion: completion)
    }
    
    /// Configures Teams notifications for cache cleanup operations
    /// Controls whether cleanup activities are reported to Teams
    /// - Parameters:
    ///   - enabled: Boolean to enable/disable cleanup notifications
    ///   - completion: Callback with update success status or nil on XPC failure
    func setTeamsNotificationsForCleanup(_ enabled: Bool, completion: @escaping (Bool?) -> Void) {
        sendRequest({ $0.setTeamsNotificationsForCleanup(enabled, reply: $1) }, completion: completion)
    }

    /// Configures Teams notifications for CVE security alerts
    /// Controls whether security vulnerability notifications are sent to Teams
    /// - Parameters:
    ///   - enabled: Boolean to enable/disable CVE notifications
    ///   - completion: Callback with update success status or nil on XPC failure
    func setTeamsNotificationsForCVEs(_ enabled: Bool, completion: @escaping (Bool?) -> Void) {
        sendRequest({ $0.setTeamsNotificationsForCVEs(enabled, reply: $1) }, completion: completion)
    }

    /// Configures inclusion of group assignment information in Teams notifications
    /// Controls whether group targeting details are included in notification messages
    /// - Parameters:
    ///   - enabled: Boolean to include/exclude group information
    ///   - completion: Callback with update success status or nil on XPC failure
    func setTeamsNotificationsForGroups(_ enabled: Bool, completion: @escaping (Bool?) -> Void) {
        sendRequest({ $0.setTeamsNotificationsForGroups(enabled, reply: $1) }, completion: completion)
    }

    /// Configures Teams notifications for Installomator label updates
    /// Controls whether label refresh and update activities are reported to Teams
    /// - Parameters:
    ///   - enabled: Boolean to enable/disable label update notifications
    ///   - completion: Callback with update success status or nil on XPC failure
    func setTeamsNotificationsForLabelUpdates(_ enabled: Bool, completion: @escaping (Bool?) -> Void) {
        sendRequest({ $0.setTeamsNotificationsForLabelUpdates(enabled, reply: $1) }, completion: completion)
    }

    /// Configures Teams notifications for application updates
    /// Controls whether application deployment and update activities are reported to Teams
    /// - Parameters:
    ///   - enabled: Boolean to enable/disable update notifications
    ///   - completion: Callback with update success status or nil on XPC failure
    func setTeamsNotificationsForUpdates(_ enabled: Bool, completion: @escaping (Bool?) -> Void) {
        sendRequest({ $0.setTeamsNotificationsForUpdates(enabled, reply: $1) }, completion: completion)
    }

    /// Sets the Teams notification style/format preference
    /// Controls the verbosity and formatting of Teams notification messages
    /// - Parameters:
    ///   - enabled: Integer representing notification style (0: individual notifications, 1: single notification for all)
    ///   - completion: Callback with update success status or nil on XPC failure
    func setTeamsNotificationsStyle(_ enabled: Int, completion: @escaping (Bool?) -> Void) {
        sendRequest({ $0.setTeamsNotificationsStyle(enabled, reply: $1) }, completion: completion)
    }
    
    /// Configures the maximum log retention period in days
    /// Controls automatic log cleanup behavior for disk space management
    /// - Parameters:
    ///   - logAgeMax: Integer days for log retention (0 = no limit)
    ///   - completion: Callback with update success status or nil on XPC failure
    func setLogAgeMax(_ logAgeMax: Int, completion: @escaping (Bool?) -> Void) {
        sendRequest({ $0.setLogAgeMax(logAgeMax, reply: $1) }, completion: completion)
    }

    /// Sets the maximum log file size limit in megabytes
    /// Controls log rotation behavior to prevent excessive disk usage
    /// - Parameters:
    ///   - logSizeMax: Integer MB limit for log files (0 = no limit)
    ///   - completion: Callback with update success status or nil on XPC failure
    func setLogSizeMax(_ logSizeMax: Int, completion: @escaping (Bool?) -> Void) {
        sendRequest({ $0.setLogSizeMax(logSizeMax, reply: $1) }, completion: completion)
    }

    /// Configures the Intuneomator application update mode
    /// Controls whether application updates are handled automatically or manually
    /// - Parameters:
    ///   - updateMode: Integer representing update preference (0: automatic, 1: notify only)
    ///   - completion: Callback with update success status or nil on XPC failure
    func setIntuneomatorUpdateMode(_ updateMode: Int, completion: @escaping (Bool?) -> Void) {
        sendRequest({ $0.setIntuneomatorUpdateMode(updateMode, reply: $1) }, completion: completion)
    }

    // MARK: - Configuration Retrieval Methods
    /// Retrieves the first-run setup completion status
    /// Indicates whether initial application configuration has been completed
    /// - Parameter completion: Callback with completion status or nil on XPC failure
    func getFirstRunCompleted(completion: @escaping (Bool?) -> Void) {
        sendRequest({ $0.getFirstRunStatus(reply: $1) }, completion: completion)
    }
    
    /// Gets the configured number of application versions to retain in cache
    /// Used for cache cleanup policy enforcement
    /// - Parameter completion: Callback with version count or nil on XPC failure
    func getAppsToKeep(completion: @escaping (Int?) -> Void) {
        sendRequest({ $0.getAppsToKeep(reply: $1) }, completion: completion)
    }

    /// Retrieves the configured authentication method for Microsoft Graph API
    /// Determines the authentication strategy for API operations
    /// - Parameter completion: Callback with auth method ("certificate" or "secret") or nil on XPC failure
    func getAuthMethod(completion: @escaping (String?) -> Void) {
        sendRequest({ $0.getAuthMethod(reply: $1) }, completion: completion)
    }
    
    /// Retrieves the Microsoft Entra ID (Azure AD) tenant identifier
    /// Essential for establishing proper authentication context
    /// - Parameter completion: Callback with tenant ID string or nil on XPC failure
    func getTenantID(completion: @escaping (String?) -> Void) {
        sendRequest({ $0.getTenantID(reply: $1) }, completion: completion)
    }
    
    /// Gets the Microsoft Entra ID application (client) identifier
    /// Required for OAuth authentication and API authorization
    /// - Parameter completion: Callback with application ID string or nil on XPC failure
    func getApplicationID(completion: @escaping (String?) -> Void) {
        sendRequest({ $0.getApplicationID(reply: $1) }, completion: completion)
    }
    
    /// Checks if Microsoft Teams webhook notifications are globally enabled
    /// Master setting for all Teams notification functionality
    /// - Parameter completion: Callback with enabled status or nil on XPC failure
    func getTeamsNotificationsEnabled(completion: @escaping (Bool?) -> Void) {
        sendRequest({ $0.getTeamsNotificationsEnabled(reply: $1) }, completion: completion)
    }
    
    /// Retrieves the configured Microsoft Teams webhook URL
    /// Required endpoint for posting automation updates to Teams channels
    /// - Parameter completion: Callback with webhook URL string or nil on XPC failure
    func getTeamsWebhookURL(completion: @escaping (String?) -> Void) {
        sendRequest({ $0.getTeamsWebhookURL(reply: $1) }, completion: completion)
    }

    /// Checks if Teams notifications are enabled for cache cleanup operations
    /// Determines whether cleanup activities are reported to Teams
    /// - Parameter completion: Callback with cleanup notification status or nil on XPC failure
    func getTeamsNotificationsForCleanup(completion: @escaping (Bool?) -> Void) {
        sendRequest({ $0.getTeamsNotificationsForCleanup(reply: $1) }, completion: completion)
    }

    /// Checks if Teams notifications are enabled for CVE security alerts
    /// Determines whether security vulnerability notifications are sent to Teams
    /// - Parameter completion: Callback with CVE notification status or nil on XPC failure
    func getTeamsNotificationsForCVEs(completion: @escaping (Bool?) -> Void) {
        sendRequest({ $0.getTeamsNotificationsForCVEs(reply: $1) }, completion: completion)
    }

    /// Checks if group assignment information is included in Teams notifications
    /// Determines whether group targeting details are included in notification messages
    /// - Parameter completion: Callback with group notification status or nil on XPC failure
    func getTeamsNotificationsForGroups(completion: @escaping (Bool?) -> Void) {
        sendRequest({ $0.getTeamsNotificationsForGroups(reply: $1) }, completion: completion)
    }

    /// Checks if Teams notifications are enabled for Installomator label updates
    /// Determines whether label refresh and update activities are reported to Teams
    /// - Parameter completion: Callback with label update notification status or nil on XPC failure
    func getTeamsNotificationsForLabelUpdates(completion: @escaping (Bool?) -> Void) {
        sendRequest({ $0.getTeamsNotificationsForLabelUpdates(reply: $1) }, completion: completion)
    }

    /// Checks if Teams notifications are enabled for application updates
    /// Determines whether application deployment and update activities are reported to Teams
    /// - Parameter completion: Callback with update notification status or nil on XPC failure
    func getTeamsNotificationsForUpdates(completion: @escaping (Bool?) -> Void) {
        sendRequest({ $0.getTeamsNotificationsForUpdates(reply: $1) }, completion: completion)
    }

    /// Gets the configured Teams notification style/format preference
    /// Determines the verbosity and formatting of Teams notification messages
    /// - Parameter completion: Callback with style integer (0: individual notifications, 1: single notification for all) or nil on XPC failure
    func getTeamsNotificationsStyle(completion: @escaping (Int?) -> Void) {
        sendRequest({ $0.getTeamsNotificationsStyle(reply: $1) }, completion: completion)
    }

    /// Retrieves the SHA-1 thumbprint of the stored authentication certificate
    /// Used for certificate identification and validation
    /// - Parameter completion: Callback with certificate thumbprint string or nil on XPC failure
    func getCertThumbprint(completion: @escaping (String?) -> Void) {
        sendRequest({ $0.getCertThumbprint(reply: $1) }, completion: completion)
    }

    /// Gets the expiration date of the stored authentication certificate
    /// Enables proactive monitoring of certificate validity
    /// - Parameter completion: Callback with certificate expiration date or nil on XPC failure
    func getCertExpiration(completion: @escaping (Date?) -> Void) {
        sendRequest({ $0.getCertExpiration(reply: $1) }, completion: completion)
    }

    /// Retrieves the expiration date of the stored client secret
    /// Enables proactive monitoring and renewal of authentication credentials
    /// - Parameter completion: Callback with secret expiration date or nil on XPC failure
    func getSecretExpirationDate(completion: @escaping (Date?) -> Void) {
        sendRequest({ $0.getSecretExpirationDate(reply: $1) }, completion: completion)
    }

    
    /// Securely retrieves the stored Entra ID client secret from keychain
    /// Provides access to authentication credentials for API operations
    /// - Parameter completion: Callback with client secret string or nil on XPC failure
    func getClientSecret(completion: @escaping (String?) -> Void) {
        sendRequest({ $0.getClientSecret(reply: $1) }, completion: completion)
    }

    
    /// Calculates the total size of the log directory in bytes
    /// Used for disk usage monitoring and cleanup decision making
    /// - Parameter completion: Callback with total log folder size in bytes or nil on XPC failure
    func getLogFolderSize(completion: @escaping (Int64?) -> Void) {
        sendRequest({ $0.getLogFolderSize(completion: $1) }, completion: completion)
    }

    /// Calculates the total size of the cache directory in bytes
    /// Used for disk usage monitoring and cleanup decision making
    /// - Parameter completion: Callback with total cache folder size in bytes or nil on XPC failure
    func getCacheFolderSize(completion: @escaping (Int64?) -> Void) {
        sendRequest({ $0.getCacheFolderSize(completion: $1) }, completion: completion)
    }
    
    /// Gets the maximum log retention period in days
    /// Used for automatic log cleanup policy enforcement
    /// - Parameter completion: Callback with retention days (0 = no limit) or nil on XPC failure
    func getLogAgeMax(completion: @escaping (Int?) -> Void) {
        sendRequest({ $0.getLogAgeMax(reply: $1) }, completion: completion)
    }

    /// Gets the maximum log file size limit in megabytes
    /// Used for log rotation and space management policies
    /// - Parameter completion: Callback with size limit in MB (0 = no limit) or nil on XPC failure
    func getLogSizeMax(completion: @escaping (Int?) -> Void) {
        sendRequest({ $0.getLogSizeMax(reply: $1) }, completion: completion)
    }

    /// Gets the configured Intuneomator application update mode
    /// Determines whether application updates are handled automatically or manually
    /// - Parameter completion: Callback with update mode (0: automatic, 1: notify only) or nil on XPC failure
    func getIntuneomatorUpdateMode(completion: @escaping (Int?) -> Void) {
        sendRequest({ $0.getIntuneomatorUpdateMode(reply: $1) }, completion: completion)
    }
    
    // MARK: - New Settings Management Methods
    
    /// Retrieves all settings as a dictionary
    /// Used by the new tabbed settings interface
    /// - Parameter completion: Callback with settings dictionary or nil on XPC failure
    func getSettings(completion: @escaping ([String: Any]?) -> Void) {
        sendRequest({ $0.getSettings(reply: $1) }, completion: completion)
    }
    
    /// Saves settings from dictionary format
    /// Used by the new tabbed settings interface to persist changes
    /// - Parameters:
    ///   - settingsData: Dictionary containing all settings data
    ///   - completion: Callback with success status or nil on XPC failure
    func saveSettingsFromDictionary(_ settingsData: [String: Any], completion: @escaping (Bool?) -> Void) {
        sendRequest({ $0.saveSettingsFromDictionary(settingsData, reply: $1) }, completion: completion)
    }
    
    /// Tests Entra ID connection with provided settings
    /// Used by the Entra ID settings tab to validate configuration
    /// - Parameters:
    ///   - testData: Dictionary containing authentication settings to test
    ///   - completion: Callback with connection success status or nil on XPC failure
    func testEntraIDConnection(with testData: [String: Any], completion: @escaping (Bool?) -> Void) {
        sendRequest({ $0.testEntraIDConnection(testData, reply: $1) }, completion: completion)
    }
    
    // MARK: - Azure Storage Configuration Methods
    
    /// Creates a new Azure Storage configuration
    /// - Parameters:
    ///   - configuration: Dictionary containing the configuration data
    ///   - completion: Callback with success status or nil on XPC failure
    func createAzureStorageConfiguration(_ configuration: [String: Any], completion: @escaping (Bool?) -> Void) {
        sendRequest({ $0.createAzureStorageConfiguration(configuration, reply: $1) }, completion: completion)
    }
    
    /// Updates an existing Azure Storage configuration
    /// - Parameters:
    ///   - configuration: Dictionary containing the updated configuration data
    ///   - completion: Callback with success status or nil on XPC failure
    func updateAzureStorageConfiguration(_ configuration: [String: Any], completion: @escaping (Bool?) -> Void) {
        sendRequest({ $0.updateAzureStorageConfiguration(configuration, reply: $1) }, completion: completion)
    }
    
    /// Removes an Azure Storage configuration by name
    /// - Parameters:
    ///   - name: Name of the configuration to remove
    ///   - completion: Callback with success status or nil on XPC failure
    func removeAzureStorageConfiguration(name: String, completion: @escaping (Bool?) -> Void) {
        sendRequest({ $0.removeAzureStorageConfiguration(name, reply: $1) }, completion: completion)
    }
    
    /// Tests an Azure Storage configuration by name
    /// - Parameters:
    ///   - name: Name of the configuration to test
    ///   - completion: Callback with connection success status or nil on XPC failure
    func testAzureStorageConfiguration(name: String, completion: @escaping (Bool?) -> Void) {
        sendRequest({ $0.testAzureStorageConfiguration(name, reply: $1) }, completion: completion)
    }
    
    /// Tests an Azure Storage configuration directly without saving
    /// - Parameters:
    ///   - configuration: Dictionary containing the configuration data to test
    ///   - completion: Callback with connection success status or nil on XPC failure
    func testAzureStorageConfigurationDirect(_ configuration: [String: Any], completion: @escaping (Bool?) -> Void) {
        sendRequest({ $0.testAzureStorageConfigurationDirect(configuration, reply: $1) }, completion: completion)
    }

}

