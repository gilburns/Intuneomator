//
//  AzureStorageConfig.swift
//  IntuneomatorService
//
//  Created by Gil Burns on 7/22/25.
//

import Foundation

/// Configuration manager for Azure Storage settings
/// Handles storage of credentials and configuration in a secure manner
class AzureStorageConfig {
    
    // MARK: - Singleton
    static let shared = AzureStorageConfig()
    private init() {}
    
    // MARK: - Keychain Keys
    private enum KeychainKeys {
        static let storageAccountName = "azure_storage_account_name"
        static let storageAccountKey = "azure_storage_account_key"
        static let sasToken = "azure_storage_sas_token"
        static let containerName = "azure_storage_container_name"
        static let tenantId = "azure_storage_tenant_id"
        static let clientId = "azure_storage_client_id"
        static let clientSecret = "azure_storage_client_secret"
    }
    
    // MARK: - Configuration Properties
    
    /// Storage account name (service-side only - GUI uses XPC calls)
    var accountName: String? {
        get { KeychainManager.shared.getValue(for: KeychainKeys.storageAccountName) }
        set { 
            if let value = newValue {
                KeychainManager.shared.setValue(value, for: KeychainKeys.storageAccountName)
            } else {
                KeychainManager.shared.removeValue(for: KeychainKeys.storageAccountName)
            }
        }
    }
    
    /// Storage account key (service-side only - GUI uses XPC calls)
    var accountKey: String? {
        get { KeychainManager.shared.getValue(for: KeychainKeys.storageAccountKey) }
        set { 
            if let value = newValue {
                KeychainManager.shared.setValue(value, for: KeychainKeys.storageAccountKey)
            } else {
                KeychainManager.shared.removeValue(for: KeychainKeys.storageAccountKey)
            }
        }
    }
    
    /// SAS token (service-side only - GUI uses XPC calls)
    var sasToken: String? {
        get { KeychainManager.shared.getValue(for: KeychainKeys.sasToken) }
        set { 
            if let value = newValue {
                KeychainManager.shared.setValue(value, for: KeychainKeys.sasToken)
            } else {
                KeychainManager.shared.removeValue(for: KeychainKeys.sasToken)
            }
        }
    }
    
    /// Container name (service-side only - GUI uses XPC calls)
    var containerName: String? {
        get { KeychainManager.shared.getValue(for: KeychainKeys.containerName) }
        set { 
            if let value = newValue {
                KeychainManager.shared.setValue(value, for: KeychainKeys.containerName)
            } else {
                KeychainManager.shared.removeValue(for: KeychainKeys.containerName)
            }
        }
    }
    
    /// Azure AD Tenant ID (for Azure AD authentication)
    var tenantId: String? {
        get { KeychainManager.shared.getValue(for: KeychainKeys.tenantId) }
        set { 
            if let value = newValue {
                KeychainManager.shared.setValue(value, for: KeychainKeys.tenantId)
            } else {
                KeychainManager.shared.removeValue(for: KeychainKeys.tenantId)
            }
        }
    }
    
    /// Azure AD Client ID (for Azure AD authentication)
    var clientId: String? {
        get { KeychainManager.shared.getValue(for: KeychainKeys.clientId) }
        set { 
            if let value = newValue {
                KeychainManager.shared.setValue(value, for: KeychainKeys.clientId)
            } else {
                KeychainManager.shared.removeValue(for: KeychainKeys.clientId)
            }
        }
    }
    
    /// Azure AD Client Secret (for Azure AD authentication)
    var clientSecret: String? {
        get { KeychainManager.shared.getValue(for: KeychainKeys.clientSecret) }
        set { 
            if let value = newValue {
                KeychainManager.shared.setValue(value, for: KeychainKeys.clientSecret)
            } else {
                KeychainManager.shared.removeValue(for: KeychainKeys.clientSecret)
            }
        }
    }
    
    // MARK: - Configuration Validation
    
    /// Checks if Azure Storage is properly configured
    var isConfigured: Bool {
        guard let accountName = accountName, !accountName.isEmpty,
              let containerName = containerName, !containerName.isEmpty else {
            return false
        }
        
        // Must have at least one authentication method configured
        return hasSharedKeyAuth || hasSASAuth || hasAzureADAuth
    }
    
    /// Checks if shared key authentication is configured
    var hasSharedKeyAuth: Bool {
        guard let key = accountKey, !key.isEmpty else { return false }
        return true
    }
    
    /// Checks if SAS token authentication is configured
    var hasSASAuth: Bool {
        guard let token = sasToken, !token.isEmpty else { return false }
        return true
    }
    
    /// Checks if Azure AD authentication is configured
    var hasAzureADAuth: Bool {
        guard let tenantId = tenantId, !tenantId.isEmpty,
              let clientId = clientId, !clientId.isEmpty,
              let clientSecret = clientSecret, !clientSecret.isEmpty else {
            return false
        }
        return true
    }
    
    // MARK: - Configuration Factory
    
    /// Creates a storage configuration based on current settings
    /// - Returns: AzureStorageManager.StorageConfig or throws error if not properly configured
    /// - Throws: ConfigurationError if settings are invalid or incomplete
    func createStorageConfig() throws -> AzureStorageManager.StorageConfig {
        guard let accountName = accountName, !accountName.isEmpty else {
            throw ConfigurationError.missingAccountName
        }
        
        guard let containerName = containerName, !containerName.isEmpty else {
            throw ConfigurationError.missingContainerName
        }
        
        // Determine authentication method (priority: SAS > Shared Key > Azure AD)
        let authMethod: AzureStorageManager.StorageConfig.AuthenticationMethod
        
        if hasSASAuth, let sasToken = sasToken {
            authMethod = .sasToken(sasToken)
            Logger.info("Using SAS token authentication for Azure Storage", category: .reports)
        } else if hasSharedKeyAuth, let accountKey = accountKey {
            authMethod = .storageKey(accountKey)
            Logger.info("Using shared key authentication for Azure Storage", category: .reports)
        } else if hasAzureADAuth, let tenantId = tenantId, let clientId = clientId, let clientSecret = clientSecret {
            authMethod = .azureAD(tenantId: tenantId, clientId: clientId, clientSecret: clientSecret)
            Logger.info("Using Azure AD authentication for Azure Storage", category: .reports)
        } else {
            throw ConfigurationError.noValidAuthMethod
        }
        
        return AzureStorageManager.StorageConfig(
            accountName: accountName,
            containerName: containerName,
            authMethod: authMethod
        )
    }
    
    // MARK: - Configuration Management
    
    /// Clears all Azure Storage configuration
    func clearConfiguration() {
        accountName = nil
        accountKey = nil
        sasToken = nil
        containerName = nil
        tenantId = nil
        clientId = nil
        clientSecret = nil
        
        Logger.info("Cleared Azure Storage configuration", category: .reports)
    }
    
    /// Validates connection to Azure Storage
    /// - Returns: Success or failure with error details
    func validateConnection() async -> (success: Bool, error: String?) {
        do {
            let config = try createStorageConfig()
            let manager = AzureStorageManager(config: config)
            
            // Try to list blobs to validate connection and permissions
            let _ = try await manager.testConnection()
            
            Logger.info("Azure Storage connection validation successful", category: .reports)
            return (true, nil)
        } catch {
            let errorMessage = "Azure Storage connection validation failed: \(error.localizedDescription)"
            Logger.error(errorMessage, category: .reports)
            return (false, errorMessage)
        }
    }
    
    // MARK: - Default Configuration
    
    /// Sets up default configuration for testing/development
    func setupDefaultConfiguration(accountName: String, accountKey: String, containerName: String = "intuneomator-reports") {
        self.accountName = accountName
        self.accountKey = accountKey
        self.containerName = containerName
        
        Logger.info("Set up default Azure Storage configuration for account: \(accountName)", category: .reports)
    }
    
    // MARK: - Multiple Named Configurations
    
    /// Represents a complete storage configuration that can be stored and retrieved by name
    struct NamedStorageConfiguration: Codable {
        let name: String
        let accountName: String
        let containerName: String
        let authMethod: StorageAuthMethod
        let description: String?
        let created: Date
        let modified: Date
        
        // MARK: - Cleanup Rule Configuration
        /// Whether automatic cleanup is enabled for this storage location
        let cleanupEnabled: Bool
        
        /// Maximum file age in days before files are eligible for cleanup (nil = no age limit)
        let maxFileAgeInDays: Int?
        
        /// Additional cleanup rules for future expansion
        let cleanupRules: CleanupRules?
        
        /// Cleanup configuration rules
        struct CleanupRules: Codable {
            /// Whether to only cleanup files in the "reports/" prefix
            let reportsOnlyCleanup: Bool
            
            /// Custom prefix pattern for cleanup (if different from default "reports/")
            let customCleanupPrefix: String?
            
            /// Whether to preserve files newer than the age threshold regardless of other rules
            let preserveRecentFiles: Bool
            
            /// Additional file size limits (in bytes) - files larger than this are not cleaned up
            let maxFileSizeForCleanup: Int64?
            
            init(reportsOnlyCleanup: Bool = true, 
                 customCleanupPrefix: String? = nil, 
                 preserveRecentFiles: Bool = true, 
                 maxFileSizeForCleanup: Int64? = nil) {
                self.reportsOnlyCleanup = reportsOnlyCleanup
                self.customCleanupPrefix = customCleanupPrefix
                self.preserveRecentFiles = preserveRecentFiles
                self.maxFileSizeForCleanup = maxFileSizeForCleanup
            }
        }
        
        enum StorageAuthMethod: Codable {
            case storageKey(String)
            case sasToken(String)
            
            var description: String {
                switch self {
                case .storageKey:
                    return "Storage Account Key"
                case .sasToken:
                    return "SAS Token"
                }
            }
        }
        
        /// Converts to AzureStorageManager.StorageConfig
        func toManagerConfig() -> AzureStorageManager.StorageConfig {
            let managerAuthMethod: AzureStorageManager.StorageConfig.AuthenticationMethod
            switch authMethod {
            case .storageKey(let key):
                managerAuthMethod = .storageKey(key)
            case .sasToken(let token):
                managerAuthMethod = .sasToken(token)
            }
            
            return AzureStorageManager.StorageConfig(
                accountName: accountName,
                containerName: containerName,
                authMethod: managerAuthMethod
            )
        }
    }
    
    /// Reserved configuration names that cannot be used
    private static let reservedNames = ["default", "system", "temp", "cache"]
    
    /// Maximum number of named configurations allowed
    private static let maxConfigurations = 20
    
    /// Gets all available named configuration names
    var availableConfigurationNames: [String] {
        let configListKey = "azure_storage_config_list"
        guard let listJson = KeychainManager.shared.getValue(for: configListKey),
              let listData = listJson.data(using: .utf8),
              let names = try? JSONDecoder().decode([String].self, from: listData) else {
            return []
        }
        return names.sorted()
    }
    
    /// Gets a named storage configuration
    /// - Parameter name: The configuration name
    /// - Returns: The configuration if it exists, nil otherwise
    func getConfiguration(named name: String) -> NamedStorageConfiguration? {
        guard !name.isEmpty else { return nil }
        
        let configKey = "azure_storage_config_\(name.lowercased())"
        guard let configJson = KeychainManager.shared.getValue(for: configKey),
              let configData = configJson.data(using: .utf8),
              let config = try? JSONDecoder().decode(NamedStorageConfiguration.self, from: configData) else {
            return nil
        }
        
        return config
    }
    
    /// Sets a named storage configuration
    /// - Parameters:
    ///   - name: The configuration name (must be unique)
    ///   - configuration: The storage configuration to save
    /// - Returns: True if successful, false if failed
    func setConfiguration(named name: String, configuration: NamedStorageConfiguration) -> Bool {
        guard !name.isEmpty,
              !Self.reservedNames.contains(name.lowercased()),
              name.count <= 50,
              name.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" || $0 == " " }) else {
            Logger.error("Invalid configuration name: \(name). Names must be 1-50 characters, alphanumeric with dashes, underscores, and spaces only", category: .reports)
            return false
        }
        
        // Check if we're at the limit (unless updating existing)
        let existingNames = availableConfigurationNames
        if !existingNames.contains(name) && existingNames.count >= Self.maxConfigurations {
            Logger.error("Cannot add configuration '\(name)': maximum of \(Self.maxConfigurations) configurations allowed", category: .reports)
            return false
        }
        
        // Encode configuration
        guard let configData = try? JSONEncoder().encode(configuration),
              let configJson = String(data: configData, encoding: .utf8) else {
            Logger.error("Failed to encode configuration '\(name)'", category: .reports)
            return false
        }
        
        // Store configuration
        let configKey = "azure_storage_config_\(name.lowercased())"
        guard KeychainManager.shared.setValue(configJson, for: configKey) else {
            Logger.error("Failed to store configuration '\(name)' in keychain", category: .reports)
            return false
        }
        
        // Update configuration list
        var updatedNames = Set(existingNames)
        updatedNames.insert(name)
        
        let configListKey = "azure_storage_config_list"
        if let listData = try? JSONEncoder().encode(Array(updatedNames)),
           let listJson = String(data: listData, encoding: .utf8) {
            KeychainManager.shared.setValue(listJson, for: configListKey)
        }
        
        Logger.info("Saved Azure Storage configuration '\(name)' for account: \(configuration.accountName)", category: .reports)
        return true
    }
    
    /// Removes a named storage configuration
    /// - Parameter name: The configuration name to remove
    /// - Returns: True if successful or didn't exist, false if failed
    func removeConfiguration(named name: String) -> Bool {
        guard !name.isEmpty else { return true }
        
        let configKey = "azure_storage_config_\(name.lowercased())"
        let removed = KeychainManager.shared.removeValue(for: configKey)
        
        // Update configuration list
        let existingNames = availableConfigurationNames
        let updatedNames = existingNames.filter { $0 != name }
        
        let configListKey = "azure_storage_config_list"
        if let listData = try? JSONEncoder().encode(updatedNames),
           let listJson = String(data: listData, encoding: .utf8) {
            KeychainManager.shared.setValue(listJson, for: configListKey)
        } else {
            // If we can't update the list, remove it entirely to stay consistent
            KeychainManager.shared.removeValue(for: configListKey)
        }
        
        Logger.info("Removed Azure Storage configuration '\(name)'", category: .reports)
        return removed
    }
    
    /// Validates a named configuration without loading credentials
    /// - Parameter name: The configuration name to validate
    /// - Returns: True if configuration exists and appears valid
    func validateConfiguration(named name: String) -> Bool {
        guard let config = getConfiguration(named: name) else { return false }
        
        // Basic validation
        guard !config.accountName.isEmpty,
              !config.containerName.isEmpty else {
            return false
        }
        
        // Validate auth method has required fields
        switch config.authMethod {
        case .storageKey(let key):
            return !key.isEmpty
        case .sasToken(let token):
            return !token.isEmpty
        }
    }
    
    /// Creates an AzureStorageManager for a named configuration
    /// - Parameter name: The configuration name
    /// - Returns: AzureStorageManager instance or throws error if configuration invalid
    /// - Throws: ConfigurationError if configuration doesn't exist or is invalid
    func createManager(for configurationName: String) throws -> AzureStorageManager {
        guard let namedConfig = getConfiguration(named: configurationName) else {
            throw ConfigurationError.invalidConfiguration("Configuration '\(configurationName)' not found")
        }
        
        let managerConfig = namedConfig.toManagerConfig()
        return AzureStorageManager(config: managerConfig)
    }
    
    /// Clears all named configurations (keeps default configuration intact)
    func clearAllNamedConfigurations() {
        let names = availableConfigurationNames
        for name in names {
            _ = removeConfiguration(named: name)
        }
        
        // Clear the list
        KeychainManager.shared.removeValue(for: "azure_storage_config_list")
        
        Logger.info("Cleared all named Azure Storage configurations (\(names.count) removed)", category: .reports)
    }
    
    /// Gets summary information about all configurations
    func getConfigurationSummaries() -> [ConfigurationSummary] {
        return availableConfigurationNames.compactMap { name in
            guard let config = getConfiguration(named: name) else { return nil }
            
            return ConfigurationSummary(
                name: name,
                accountName: config.accountName,
                containerName: config.containerName,
                authMethod: config.authMethod.description,
                description: config.description,
                created: config.created,
                modified: config.modified,
                isValid: validateConfiguration(named: name),
                cleanupEnabled: config.cleanupEnabled,
                maxFileAgeInDays: config.maxFileAgeInDays
            )
        }
    }
    
    /// Summary information for a storage configuration
    struct ConfigurationSummary {
        let name: String
        let accountName: String
        let containerName: String
        let authMethod: String
        let description: String?
        let created: Date
        let modified: Date
        let isValid: Bool
        let cleanupEnabled: Bool
        let maxFileAgeInDays: Int?
        
        /// Human-readable cleanup summary
        var cleanupSummary: String {
            guard cleanupEnabled else { return "Disabled" }
            if let maxAge = maxFileAgeInDays {
                return "\(maxAge) Day\(maxAge == 1 ? "" : "s")"
            } else {
                return "Enabled"
            }
        }
    }
}

// MARK: - Configuration Errors

enum ConfigurationError: LocalizedError {
    case missingAccountName
    case missingContainerName
    case noValidAuthMethod
    case invalidConfiguration(String)
    
    var errorDescription: String? {
        switch self {
        case .missingAccountName:
            return "Storage account name is required"
        case .missingContainerName:
            return "Container name is required"
        case .noValidAuthMethod:
            return "No valid authentication method configured (requires Storage key or SAS token)"
        case .invalidConfiguration(let details):
            return "Invalid configuration: \(details)"
        }
    }
}
