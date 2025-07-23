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
    
    // MARK: - New Settings Management Methods
    
    /// Retrieves all settings as a dictionary
    /// Consolidates all configuration values into a single dictionary for the tabbed settings interface
    /// - Parameter reply: Callback with settings dictionary or nil on failure
    func getSettings(reply: @escaping ([String: Any]?) -> Void) {
        Logger.debug("XPC Service: getSettings method called", category: .core)
        
        var settings: [String: Any] = [:]
        
        Logger.debug("Getting settings from ConfigManager", category: .core)
        
        // Application settings
        let appsToKeep = ConfigManager.readPlistValue(key: "AppsVersionsToKeep") ?? 2
        let logsMaxAge = ConfigManager.readPlistValue(key: "LogRetentionDays") ?? 30
        let logsMaxSize = ConfigManager.readPlistValue(key: "LogMaxSizeMB") ?? 100
        
        Logger.debug("ConfigManager values - appsToKeep: \(appsToKeep), logsMaxAge: \(logsMaxAge), logsMaxSize: \(logsMaxSize)", category: .core)
        
        settings["appsToKeep"] = appsToKeep
        settings["logsMaxAge"] = logsMaxAge
        settings["logsMaxSize"] = logsMaxSize
        
        // Keep updateMode as Int for popup index selection
        let updateModeInt = ConfigManager.readPlistValue(key: "UpdateMode") ?? 0
        // Map stored values to popup indices: 0=auto-update (index 0), 1=notify-only (index 1) 
        settings["updateMode"] = updateModeInt
        
        // Notification settings
        settings["sendTeamsNotifications"] = ConfigManager.readPlistValue(key: "TeamsNotificationsEnabled") ?? false
        settings["teamsWebhookURL"] = ConfigManager.readPlistValue(key: "TeamsWebhookURL") ?? ""
        settings["sendNotificationsForCleanup"] = ConfigManager.readPlistValue(key: "TeamsNotificationsForCleanup") ?? false
        settings["sendNotificationsForCVEs"] = ConfigManager.readPlistValue(key: "TeamsNotificationsForCVEs") ?? false
        settings["sendNotificationsForGroups"] = ConfigManager.readPlistValue(key: "TeamsNotificationsForGroups") ?? false
        settings["sendNotificationsForLabelUpdates"] = ConfigManager.readPlistValue(key: "TeamsNotificationsForLabelUpdates") ?? false
        settings["sendNotificationsForUpdates"] = ConfigManager.readPlistValue(key: "TeamsNotificationsForUpdates") ?? false
        
        // Convert notification style from Int to String for UI compatibility
        let notificationStyleInt = ConfigManager.readPlistValue(key: "TeamsNotificationsStyle") ?? 0
        settings["notificationStyle"] = notificationStyleInt == 1 ? "Send a notification each automation run" : "Send a notification for each software title update"
        
        // Entra ID settings
        settings["tenantID"] = ConfigManager.readPlistValue(key: "TenantID") ?? ""
        settings["clientID"] = ConfigManager.readPlistValue(key: "ApplicationID") ?? ""
        settings["authenticationMethod"] = ConfigManager.readPlistValue(key: "AuthMethod") ?? ""
        
        // Get sensitive data from keychain
        settings["clientSecret"] = KeychainManager.retrieveEntraIDSecretKey()

        
        let certDetails = ConfigManager.readPlistValue(key: "CertificateDetails") ?? [:]
        settings["certificateThumbprint"] = certDetails["Thumbprint"] ?? ""
        
        // Get expiration dates (convert Date objects to strings for UI compatibility)
        if let certExpDate = certDetails["ExpirationDate"] as? Date {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            settings["certificateExpiration"] = formatter.string(from: certExpDate)
        } else {
            settings["certificateExpiration"] = ""
        }
        
        if let secretExpDate: Date = ConfigManager.readPlistValue(key: "SecretExpirationDate") {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            settings["secretExpiration"] = formatter.string(from: secretExpDate)
        } else {
            settings["secretExpiration"] = ""
        }
        
        Logger.debug("Returning settings dictionary with \(settings.count) keys: \(settings.keys.joined(separator: ", "))", category: .core)
        
        // Ensure we're not returning an empty dictionary unexpectedly
        if settings.isEmpty {
            Logger.error("XPC Service: Settings dictionary is empty - this should not happen with default values", category: .core)
        }
        
        reply(settings)
    }
    
    /// Saves settings from dictionary format
    /// Takes consolidated settings data and distributes it to appropriate storage locations
    /// - Parameters:
    ///   - settingsData: Dictionary containing all settings data
    ///   - reply: Callback indicating if save was successful
    func saveSettingsFromDictionary(_ settingsData: [String: Any], reply: @escaping (Bool) -> Void) {
        var allSucceeded = true
        
        // Save application settings
        if let appsToKeep = settingsData["appsToKeep"] as? Int {
            allSucceeded = allSucceeded && ConfigManager.writePlistValue(key: "AppsVersionsToKeep", value: appsToKeep)
        }
        
        if let logsMaxAge = settingsData["logsMaxAge"] as? Int {
            allSucceeded = allSucceeded && ConfigManager.writePlistValue(key: "LogRetentionDays", value: logsMaxAge)
        }
        
        if let logsMaxSize = settingsData["logsMaxSize"] as? Int {
            allSucceeded = allSucceeded && ConfigManager.writePlistValue(key: "LogMaxSizeMB", value: logsMaxSize)
        }
        
        if let updateMode = settingsData["updateMode"] as? Int {
            // updateMode is now the popup index: 0=auto-update, 1=notify-only
            allSucceeded = allSucceeded && ConfigManager.writePlistValue(key: "UpdateMode", value: updateMode)
        }
        
        // Save notification settings
        if let sendNotifications = settingsData["sendTeamsNotifications"] as? Bool {
            allSucceeded = allSucceeded && ConfigManager.writePlistValue(key: "TeamsNotificationsEnabled", value: sendNotifications)
        }
        
        if let webhookURL = settingsData["teamsWebhookURL"] as? String {
            allSucceeded = allSucceeded && ConfigManager.writePlistValue(key: "TeamsWebhookURL", value: webhookURL)
        }
        
        if let cleanup = settingsData["sendNotificationsForCleanup"] as? Bool {
            allSucceeded = allSucceeded && ConfigManager.writePlistValue(key: "TeamsNotificationsForCleanup", value: cleanup)
        }
        
        if let cves = settingsData["sendNotificationsForCVEs"] as? Bool {
            allSucceeded = allSucceeded && ConfigManager.writePlistValue(key: "TeamsNotificationsForCVEs", value: cves)
        }
        
        if let groups = settingsData["sendNotificationsForGroups"] as? Bool {
            allSucceeded = allSucceeded && ConfigManager.writePlistValue(key: "TeamsNotificationsForGroups", value: groups)
        }
        
        if let labelUpdates = settingsData["sendNotificationsForLabelUpdates"] as? Bool {
            allSucceeded = allSucceeded && ConfigManager.writePlistValue(key: "TeamsNotificationsForLabelUpdates", value: labelUpdates)
        }
        
        if let updates = settingsData["sendNotificationsForUpdates"] as? Bool {
            allSucceeded = allSucceeded && ConfigManager.writePlistValue(key: "TeamsNotificationsForUpdates", value: updates)
        }
        
        if let style = settingsData["notificationStyle"] as? String {
            let styleValue = style == "Standard" ? 0 : (style == "Detailed" ? 1 : 2)
            allSucceeded = allSucceeded && ConfigManager.writePlistValue(key: "TeamsNotificationsStyle", value: styleValue)
        }
        
        // Save Entra ID settings
        if let tenantID = settingsData["tenantID"] as? String {
            allSucceeded = allSucceeded && ConfigManager.writePlistValue(key: "TenantID", value: tenantID)
        }
        
        if let clientID = settingsData["clientID"] as? String {
            allSucceeded = allSucceeded && ConfigManager.writePlistValue(key: "ApplicationID", value: clientID)
        }
        
        if let authMethod = settingsData["authenticationMethod"] as? String {
            let useSecret = authMethod == "secret"
            allSucceeded = allSucceeded && ConfigManager.writePlistValue(key: "UseClientSecret", value: useSecret)
        }
        
        // Save sensitive data to keychain
        if let clientSecret = settingsData["clientSecret"] as? String, !clientSecret.isEmpty {
            allSucceeded = allSucceeded && KeychainManager.shared.setValue(clientSecret, for: "ClientSecret")
        }
        
        if let thumbprint = settingsData["certificateThumbprint"] as? String, !thumbprint.isEmpty {
            allSucceeded = allSucceeded && KeychainManager.shared.setValue(thumbprint, for: "CertificateThumbprint")
        }
        
        // Save expiration dates
        if let certExpiration = settingsData["certificateExpiration"] as? String {
            allSucceeded = allSucceeded && ConfigManager.writePlistValue(key: "CertificateExpiration", value: certExpiration)
        }
        
        if let secretExpiration = settingsData["secretExpiration"] as? String {
            allSucceeded = allSucceeded && ConfigManager.writePlistValue(key: "SecretExpiration", value: secretExpiration)
        }
        
        reply(allSucceeded)
    }
    
    /// Tests Entra ID connection with provided settings
    /// Validates authentication credentials without saving them permanently
    /// - Parameters:
    ///   - testData: Dictionary containing authentication settings to test
    ///   - reply: Callback indicating if connection was successful
    func testEntraIDConnection(_ testData: [String: Any], reply: @escaping (Bool) -> Void) {
        // Extract test parameters
        guard let tenantID = testData["tenantID"] as? String,
              let clientID = testData["clientID"] as? String,
              let authMethod = testData["authenticationMethod"] as? String else {
            reply(false)
            return
        }
        
        // Test connection asynchronously using the new test method
        Task {
            let authenticator = EntraAuthenticator.shared
            let clientSecret = testData["clientSecret"] as? String
            
            let success = await authenticator.testAuthentication(
                tenantId: tenantID,
                clientId: clientID,
                authMethod: authMethod,
                clientSecret: clientSecret
            )
            
            reply(success)
        }
    }
    
    // MARK: - Azure Storage Configuration Methods
    
    /// Creates a new Azure Storage configuration
    /// - Parameters:
    ///   - configuration: Dictionary containing the configuration data
    ///   - reply: Callback indicating if creation was successful
    func createAzureStorageConfiguration(_ configuration: [String: Any], reply: @escaping (Bool) -> Void) {
        guard let name = configuration["name"] as? String else {
            reply(false)
            return
        }
        
        let success = AzureStorageConfig.shared.setConfiguration(named: name, configuration: convertToNamedConfig(configuration))
        reply(success)
    }
    
    /// Updates an existing Azure Storage configuration
    /// - Parameters:
    ///   - configuration: Dictionary containing the updated configuration data
    ///   - reply: Callback indicating if update was successful
    func updateAzureStorageConfiguration(_ configuration: [String: Any], reply: @escaping (Bool) -> Void) {
        guard let name = configuration["name"] as? String else {
            reply(false)
            return
        }
        
        let success = AzureStorageConfig.shared.setConfiguration(named: name, configuration: convertToNamedConfig(configuration))
        reply(success)
    }
    
    /// Removes an Azure Storage configuration by name
    /// - Parameters:
    ///   - name: Name of the configuration to remove
    ///   - reply: Callback indicating if removal was successful
    func removeAzureStorageConfiguration(_ name: String, reply: @escaping (Bool) -> Void) {
        let success = AzureStorageConfig.shared.removeConfiguration(named: name)
        reply(success)
    }
    
    /// Tests an Azure Storage configuration by name
    /// - Parameters:
    ///   - name: Name of the configuration to test
    ///   - reply: Callback indicating if connection test was successful
    func testAzureStorageConfiguration(_ name: String, reply: @escaping (Bool) -> Void) {
        Task {
            let isValid = await AzureStorageManager.validateConnection(withConfig: name)
            reply(isValid)
        }
    }
    
    /// Tests an Azure Storage configuration directly without saving
    /// - Parameters:
    ///   - configuration: Dictionary containing the configuration data to test
    ///   - reply: Callback indicating if connection test was successful
    func testAzureStorageConfigurationDirect(_ configuration: [String: Any], reply: @escaping (Bool) -> Void) {
        Logger.error("Azure Storage test - XPC method called", category: .core)
        Logger.error("Azure Storage test - received configuration keys: \(configuration.keys.sorted())", category: .core)
        Logger.error("Azure Storage test - authMethod value: \(configuration["authMethod"] ?? "nil")", category: .core)
        
        Logger.error("Azure Storage test - About to call convertToNamedConfig", category: .core)
        let namedConfig = convertToNamedConfig(configuration)
        Logger.error("Azure Storage test - converted to named config: name=\(namedConfig.name), accountName=\(namedConfig.accountName), container=\(namedConfig.containerName)", category: .core)
        Logger.error("Azure Storage test - named config auth method: \(namedConfig.authMethod)", category: .core)
        
        Task {
            do {
                Logger.error("Azure Storage test - About to call toManagerConfig", category: .core)
                let storageConfig = namedConfig.toManagerConfig()
                Logger.error("Azure Storage test - created manager config successfully", category: .core)
                Logger.error("Azure Storage test - manager config auth method: \(storageConfig.authMethod)", category: .core)
                
                let manager = AzureStorageManager(config: storageConfig)
                try await manager.testConnection()
                Logger.info("Azure Storage connection test succeeded", category: .core)
                reply(true)
            } catch {
                Logger.error("Azure Storage connection test failed: \(error.localizedDescription)", category: .core)
                reply(false)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// Converts dictionary to NamedStorageConfiguration
    private func convertToNamedConfig(_ dict: [String: Any]) -> AzureStorageConfig.NamedStorageConfiguration {
        let name = dict["name"] as? String ?? ""
        let accountName = dict["accountName"] as? String ?? ""
        let containerName = dict["containerName"] as? String ?? ""
        let description = dict["description"] as? String ?? ""
        
        let authMethod: AzureStorageConfig.NamedStorageConfiguration.StorageAuthMethod
        if let method = dict["authMethod"] as? String {
            Logger.debug("Azure Storage Config - Auth method string: '\(method)'", category: .core)
            switch method {
            case "storageKey":
                let key = dict["accountKey"] as? String ?? ""
                Logger.debug("Azure Storage Config - Using storage key auth, key length: \(key.count)", category: .core)
                authMethod = .storageKey(key)
            case "sasToken":
                let token = dict["sasToken"] as? String ?? ""
                Logger.debug("Azure Storage Config - Using SAS token auth, token length: \(token.count)", category: .core)
                authMethod = .sasToken(token)
            case "azureAD":
                let tenantId = dict["tenantId"] as? String ?? ""
                let clientId = dict["clientId"] as? String ?? ""
                let clientSecret = dict["clientSecret"] as? String ?? ""
                Logger.debug("Azure Storage Config - Using Azure AD auth", category: .core)
                authMethod = .azureAD(tenantId: tenantId, clientId: clientId, clientSecret: clientSecret)
            default:
                Logger.warning("Azure Storage Config - Unknown auth method '\(method)', defaulting to storage key", category: .core)
                authMethod = .storageKey("")
            }
        } else {
            Logger.warning("Azure Storage Config - No auth method specified, defaulting to storage key", category: .core)
            authMethod = .storageKey("")
        }
        
        return AzureStorageConfig.NamedStorageConfiguration(
            name: name,
            accountName: accountName,
            containerName: containerName,
            authMethod: authMethod,
            description: description,
            created: Date(),
            modified: Date()
        )
    }
    
    // MARK: - Azure Storage Testing Methods
    
    /// Uploads a file to Azure Storage using a named configuration
    func uploadFileToAzureStorage(fileName: String, fileData: Data, configurationName: String, reply: @escaping (Bool) -> Void) {
        Task {
            do {
                Logger.info("Starting Azure Storage upload for file '\(fileName)' using configuration '\(configurationName)'", category: .core)
                let manager = try AzureStorageManager.withNamedConfiguration(configurationName)
                
                // Create a temporary file to upload
                let tempDir = FileManager.default.temporaryDirectory
                let tempFileURL = tempDir.appendingPathComponent(fileName)
                
                Logger.info("Writing temporary file to: \(tempFileURL.path)", category: .core)
                try fileData.write(to: tempFileURL)
                defer {
                    try? FileManager.default.removeItem(at: tempFileURL)
                }
                
                Logger.info("Calling manager.uploadReport for file: \(fileName)", category: .core)
                try await manager.uploadReport(fileURL: tempFileURL)
                Logger.info("Successfully uploaded file '\(fileName)' to Azure Storage configuration '\(configurationName)'", category: .core)
                reply(true)
            } catch let error as AzureStorageError {
                Logger.error("Azure Storage Error uploading '\(fileName)': \(error.errorDescription ?? error.localizedDescription)", category: .core)
                reply(false)
            } catch {
                Logger.error("Failed to upload file '\(fileName)' to Azure Storage: \(error.localizedDescription)", category: .core)
                reply(false)
            }
        }
    }
    
    /// Generates a download link for a file in Azure Storage using a named configuration
    func generateAzureStorageDownloadLink(fileName: String, configurationName: String, expiresInDays: Int, reply: @escaping (URL?) -> Void) {
        Task {
            do {
                let manager = try AzureStorageManager.withNamedConfiguration(configurationName)
                let downloadURL = try await manager.generateDownloadLink(for: fileName, expiresIn: expiresInDays)
                Logger.info("Generated download link for '\(fileName)' in configuration '\(configurationName)', expires in \(expiresInDays) days", category: .core)
                reply(downloadURL)
            } catch {
                Logger.error("Failed to generate download link for '\(fileName)': \(error.localizedDescription)", category: .core)
                reply(nil)
            }
        }
    }
    
    /// Sends a Teams notification message
    func sendTeamsNotification(message: String, reply: @escaping (Bool) -> Void) {
        Task {
            do {
                let webhookURL = ConfigManager.readPlistValue(key: "TeamsWebhookURL") ?? ""
                guard !webhookURL.isEmpty else {
                    Logger.error("Teams webhook URL not configured", category: .core)
                    reply(false)
                    return
                }
                
                let teamsNotifier = TeamsNotifier(webhookURL: webhookURL)
                let success = await teamsNotifier.sendCustomMessage(message)
                
                if success {
                    Logger.info("Successfully sent Teams notification", category: .core)
                } else {
                    Logger.error("Failed to send Teams notification", category: .core)
                }
                
                reply(success)
            }
        }
    }

}

