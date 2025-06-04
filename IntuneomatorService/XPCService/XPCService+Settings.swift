//
//  XPCService+Settings.swift
//  Intuneomator
//
//  Created by Gil Burns on 5/4/25.
//

import Foundation

/// XPCService extension for configuration and settings management
/// Provides secure access to application settings, authentication configuration, and system preferences
/// All configuration data is managed through ConfigManager for consistent plist operations
extension XPCService {
    
    // MARK: - Configuration Retrieval Methods
    /// Retrieves the first-run setup completion status
    /// - Parameter reply: Callback with boolean indicating if initial setup has been completed
    func getFirstRunStatus(reply: @escaping (Bool) -> Void) {
        let completed = ConfigManager.readPlistValue(key: "FirstRunGUICompleted") ?? false
        reply(completed)
    }
    
    /// Gets the configured number of application versions to retain in cache
    /// - Parameter reply: Callback with integer count of versions to keep (default: 2)
    func getAppsToKeep(reply: @escaping (Int) -> Void) {
        let appsToKeep = ConfigManager.readPlistValue(key: "AppsVersionsToKeep") ?? 2
        reply(appsToKeep)
    }

    /// Retrieves the Microsoft Entra ID (Azure AD) tenant identifier
    /// - Parameter reply: Callback with tenant ID string or empty string if not configured
    func getTenantID(reply: @escaping (String) -> Void) {
        let tenantID = ConfigManager.readPlistValue(key: "TenantID") ?? ""
        reply(tenantID)
    }
    
    /// Gets the Microsoft Entra ID application (client) identifier
    /// - Parameter reply: Callback with application ID string or empty string if not configured
    func getApplicationID(reply: @escaping (String) -> Void) {
        let applicationID = ConfigManager.readPlistValue(key: "ApplicationID") ?? ""
        reply(applicationID)
    }
    
    
    /// Checks if Microsoft Teams webhook notifications are globally enabled
    /// - Parameter reply: Callback with boolean indicating notification status
    func getTeamsNotificationsEnabled(reply: @escaping (Bool) -> Void) {
        let enabled = ConfigManager.readPlistValue(key: "TeamsNotificationsEnabled") ?? false
        reply(enabled)
    }
    
    /// Retrieves the configured Microsoft Teams webhook URL for notifications
    /// - Parameter reply: Callback with webhook URL string or empty string if not configured
    func getTeamsWebhookURL(reply: @escaping (String) -> Void) {
        let url = ConfigManager.readPlistValue(key: "TeamsWebhookURL") ?? ""
        reply(url)
    }
    
    /// Checks if Teams notifications are enabled for cache cleanup operations
    /// - Parameter reply: Callback with boolean indicating cleanup notification preference
    func getTeamsNotificationsForCleanup(reply: @escaping (Bool) -> Void) {
        let enabled = ConfigManager.readPlistValue(key: "TeamsNotificationsForCleanup") ?? false
        reply(enabled)
    }

    /// Checks if Teams notifications are enabled for CVE security alerts
    /// - Parameter reply: Callback with boolean indicating CVE notification preference
    func getTeamsNotificationsForCVEs(reply: @escaping (Bool) -> Void) {
        let enabled = ConfigManager.readPlistValue(key: "TeamsNotificationsForCVEs") ?? false
        reply(enabled)
    }

    /// Checks if Teams notifications include group assignment information
    /// - Parameter reply: Callback with boolean indicating group notification preference
    func getTeamsNotificationsForGroups(reply: @escaping (Bool) -> Void) {
        let enabled = ConfigManager.readPlistValue(key: "TeamsNotificationsForGroups") ?? false
        reply(enabled)
    }

    /// Checks if Teams notifications are enabled for Installomator label updates
    /// - Parameter reply: Callback with boolean indicating label update notification preference
    func getTeamsNotificationsForLabelUpdates(reply: @escaping (Bool) -> Void) {
        let enabled = ConfigManager.readPlistValue(key: "TeamsNotificationsForLabelUpdates") ?? false
        reply(enabled)
    }

    /// Checks if Teams notifications are enabled for application updates
    /// - Parameter reply: Callback with boolean indicating update notification preference
    func getTeamsNotificationsForUpdates(reply: @escaping (Bool) -> Void) {
        let enabled = ConfigManager.readPlistValue(key: "TeamsNotificationsForUpdates") ?? false
        reply(enabled)
    }

    /// Gets the configured Teams notification style/format preference
    /// - Parameter reply: Callback with integer representing notification style (0: basic, 1: detailed)
    func getTeamsNotificationsStyle(reply: @escaping (Int) -> Void) {
        let style = ConfigManager.readPlistValue(key: "TeamsNotificationsStyle") ?? 0
        reply(style)
    }

    /// Retrieves the SHA-1 thumbprint of the stored authentication certificate
    /// - Parameter reply: Callback with certificate thumbprint string or nil if not available
    func getCertThumbprint(reply: @escaping (String?) -> Void) {
        let certDetails = ConfigManager.readPlistValue(key: "CertificateDetails") ?? [:]
        let certThumbprint = certDetails["Thumbprint"] as? String
        reply(certThumbprint)
    }

    /// Gets the expiration date of the stored authentication certificate
    /// - Parameter reply: Callback with certificate expiration date or nil if not available
    func getCertExpiration(reply: @escaping (Date?) -> Void) {
        let certDetails = ConfigManager.readPlistValue(key: "CertificateDetails") ?? [:]
        let expirationDate = certDetails["ExpirationDate"] as? Date
        reply(expirationDate)
    }

    /// Retrieves the expiration date of the stored client secret
    /// - Parameter reply: Callback with secret expiration date or nil if not configured
    func getSecretExpirationDate(reply: @escaping (Date?) -> Void) {
        let expirationDate = ConfigManager.readPlistValue(key: "SecretExpirationDate") as Date?
        reply(expirationDate)
    }

    /// Securely retrieves the stored Entra ID client secret from keychain
    /// - Parameter reply: Callback with client secret string or nil if not found
    func getClientSecret(reply: @escaping (String?) -> Void) {
        let clientSecret = KeychainManager.retrieveEntraIDSecretKey()
        reply(clientSecret)
    }

        
    /// Gets the maximum log retention period in days
    /// - Parameter reply: Callback with integer days for log retention (0 = no limit)
    func getLogAgeMax(reply: @escaping (Int) -> Void) {
        let logAgeMax = ConfigManager.readPlistValue(key: "LogRetentionDays") ?? 0
        reply(logAgeMax)
    }
    
    /// Gets the maximum log file size limit in megabytes
    /// - Parameter reply: Callback with integer MB limit for log files (0 = no limit)
    func getLogSizeMax(reply: @escaping (Int) -> Void) {
        let logSizeMax = ConfigManager.readPlistValue(key: "LogMaxSizeMB") ?? 0
        reply(logSizeMax)
    }
    
    /// Gets the configured Intuneomator application update mode
    /// - Parameter reply: Callback with integer representing update preference (0: manual, 1: automatic)
    func getIntuneomatorUpdateMode(reply: @escaping (Int) -> Void) {
        let updateMode = ConfigManager.readPlistValue(key: "UpdateMode") ?? 0
        reply(updateMode)
    }


    /// Calculates the total size of the log directory in bytes
    /// - Parameter completion: Callback with total log folder size in bytes
    func getLogFolderSize(completion: @escaping (Int64) -> Void) {
        let size = LogManagerUtil.logFolderSizeInBytes()
        completion(size)
    }

    /// Calculates the total size of the cache directory in bytes
    /// - Parameter completion: Callback with total cache folder size in bytes
    func getCacheFolderSize(completion: @escaping (Int64) -> Void) {
        let size = CacheManagerUtil.cacheFolderSizeInBytes()
        completion(size)
    }
    
    // MARK: - Configuration Update Methods
    /// Updates the first-run setup completion status
    /// - Parameters:
    ///   - completed: Boolean indicating if setup has been completed
    ///   - reply: Callback with success status of the update operation
    func setFirstRunStatus(_ completed: Bool, reply: @escaping (Bool) -> Void) {
        let success = ConfigManager.writePlistValue(key: "FirstRunGUICompleted", value: completed)
        reply(success)
    }
    
    
    /// Sets the expiration date for the stored client secret
    /// - Parameters:
    ///   - expirationDate: Date when the client secret will expire
    ///   - reply: Callback with success status of the update operation
    func setSecretExpirationDate(_ expirationDate: Date, reply: @escaping (Bool) -> Void) {
        let success = ConfigManager.writePlistValue(key: "SecretExpirationDate", value: expirationDate)
        reply(success)
    }

    /// Configures the number of application versions to retain in cache
    /// - Parameters:
    ///   - appCount: Integer count of versions to keep for each application
    ///   - reply: Callback with success status of the update operation
    func setAppsToKeep(_ appCount: Int, reply: @escaping (Bool) -> Void) {
        let success = ConfigManager.writePlistValue(key: "AppsVersionsToKeep", value: appCount)
        reply(success)
    }

    /// Sets the authentication method for Microsoft Graph API access
    /// - Parameters:
    ///   - method: Authentication method ("certificate" or "secret")
    ///   - reply: Callback with success status (false if invalid method provided)
    func setAuthMethod(_ method: String, reply: @escaping (Bool) -> Void) {
        let validMethods = ["certificate", "secret"]
        guard validMethods.contains(method) else {
            reply(false)
            return
        }
        let success = ConfigManager.writePlistValue(key: "AuthMethod", value: method)
        reply(success)
    }
    
    /// Configures the Microsoft Entra ID (Azure AD) tenant identifier
    /// - Parameters:
    ///   - tenantID: Tenant ID string from Azure AD
    ///   - reply: Callback with success status of the update operation
    func setTenantID(_ tenantID: String, reply: @escaping (Bool) -> Void) {
        let success = ConfigManager.writePlistValue(key: "TenantID", value: tenantID)
        reply(success)
    }
    
    /// Sets the Microsoft Entra ID application (client) identifier
    /// - Parameters:
    ///   - applicationID: Application ID string from Azure AD app registration
    ///   - reply: Callback with success status of the update operation
    func setApplicationID(_ applicationID: String, reply: @escaping (Bool) -> Void) {
        let success = ConfigManager.writePlistValue(key: "ApplicationID", value: applicationID)
        reply(success)
    }
    
    /// Enables or disables Microsoft Teams webhook notifications globally
    /// - Parameters:
    ///   - enabled: Boolean to enable/disable Teams notifications
    ///   - reply: Callback with success status of the update operation
    func setTeamsNotificationsEnabled(_ enabled: Bool, reply: @escaping (Bool) -> Void) {
        let success = ConfigManager.writePlistValue(key: "TeamsNotificationsEnabled", value: enabled)
        reply(success)
    }
    
    /// Configures the Microsoft Teams webhook URL for notifications
    /// - Parameters:
    ///   - url: Teams webhook URL string
    ///   - reply: Callback with success status of the update operation
    func setTeamsWebhookURL(_ url: String, reply: @escaping (Bool) -> Void) {
        let success = ConfigManager.writePlistValue(key: "TeamsWebhookURL", value: url)
        reply(success)
    }

    /// Configures Teams notifications for cache cleanup operations
    /// - Parameters:
    ///   - enabled: Boolean to enable/disable cleanup notifications
    ///   - reply: Callback with success status of the update operation
    func setTeamsNotificationsForCleanup(_ enabled: Bool, reply: @escaping (Bool) -> Void) {
        let success = ConfigManager.writePlistValue(key: "TeamsNotificationsForCleanup", value: enabled)
        reply(success)
    }

    /// Configures Teams notifications for CVE security alerts
    /// - Parameters:
    ///   - enabled: Boolean to enable/disable CVE notifications
    ///   - reply: Callback with success status of the update operation
    func setTeamsNotificationsForCVEs(_ enabled: Bool, reply: @escaping (Bool) -> Void) {
        let success = ConfigManager.writePlistValue(key: "TeamsNotificationsForCVEs", value: enabled)
        reply(success)
    }

    /// Configures inclusion of group assignment information in Teams notifications
    /// - Parameters:
    ///   - enabled: Boolean to include/exclude group information
    ///   - reply: Callback with success status of the update operation
    func setTeamsNotificationsForGroups(_ enabled: Bool, reply: @escaping (Bool) -> Void) {
        let success = ConfigManager.writePlistValue(key: "TeamsNotificationsForGroups", value: enabled)
        reply(success)
    }

    /// Configures Teams notifications for Installomator label updates
    /// - Parameters:
    ///   - enabled: Boolean to enable/disable label update notifications
    ///   - reply: Callback with success status of the update operation
    func setTeamsNotificationsForLabelUpdates(_ enabled: Bool, reply: @escaping (Bool) -> Void) {
        let success = ConfigManager.writePlistValue(key: "TeamsNotificationsForLabelUpdates", value: enabled)
        reply(success)
    }

    /// Configures Teams notifications for application updates
    /// - Parameters:
    ///   - enabled: Boolean to enable/disable update notifications
    ///   - reply: Callback with success status of the update operation
    func setTeamsNotificationsForUpdates(_ enabled: Bool, reply: @escaping (Bool) -> Void) {
        let success = ConfigManager.writePlistValue(key: "TeamsNotificationsForUpdates", value: enabled)
        reply(success)
    }

    /// Sets the Teams notification style/format preference
    /// - Parameters:
    ///   - enabled: Integer representing notification style (0: basic, 1: detailed)
    ///   - reply: Callback with success status of the update operation
    func setTeamsNotificationsStyle(_ enabled: Int, reply: @escaping (Bool) -> Void) {
        let success = ConfigManager.writePlistValue(key: "TeamsNotificationsStyle", value: enabled)
        reply(success)
    }

    /// Configures the maximum log retention period in days
    /// - Parameters:
    ///   - logAgeMax: Integer days for log retention (0 = no limit)
    ///   - reply: Callback with success status of the update operation
    func setLogAgeMax(_ logAgeMax: Int, reply: @escaping (Bool) -> Void) {
        let success = ConfigManager.writePlistValue(key: "LogRetentionDays", value: logAgeMax)
        reply(success)
    }
    
    /// Sets the maximum log file size limit in megabytes
    /// - Parameters:
    ///   - logSizeMax: Integer MB limit for log files (0 = no limit)
    ///   - reply: Callback with success status of the update operation
    func setLogSizeMax(_ logSizeMax: Int, reply: @escaping (Bool) -> Void) {
        let success = ConfigManager.writePlistValue(key: "LogMaxSizeMB", value: logSizeMax)
        reply(success)
    }

    /// Configures the Intuneomator application update mode
    /// - Parameters:
    ///   - updateMode: Integer representing update preference (0: manual, 1: automatic)
    ///   - reply: Callback with success status of the update operation
    func setIntuneomatorUpdateMode(_ updateMode: Int, reply: @escaping (Bool) -> Void) {
        let success = ConfigManager.writePlistValue(key: "UpdateMode", value: updateMode)
        reply(success)
    }

}

