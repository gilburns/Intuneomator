//
//  XPCService+AzureStorage.swift
//  IntuneomatorService
//
//  Created by Gil Burns on 7/22/25.
//

import Foundation

/// XPC service extension for Azure Storage management
extension XPCService {
    
    // MARK: - Azure Storage Configuration
    
    /// Configures Azure Storage settings for report management
    func configureAzureStorage(accountName: String, containerName: String, accountKey: String?, sasToken: String?, reply: @escaping (Bool) -> Void) {
        Logger.info("Configuring Azure Storage for account: \(accountName), container: \(containerName)", category: .core)
        
        // Validate inputs
        guard !accountName.isEmpty, !containerName.isEmpty else {
            Logger.error("Azure Storage configuration failed: account name and container name are required", category: .core)
            reply(false)
            return
        }
        
        // Must have at least one authentication method
        guard (accountKey != nil && !accountKey!.isEmpty) || (sasToken != nil && !sasToken!.isEmpty) else {
            Logger.error("Azure Storage configuration failed: either account key or SAS token is required", category: .core)
            reply(false)
            return
        }
        
        // Store configuration
        let config = AzureStorageConfig.shared
        config.accountName = accountName
        config.containerName = containerName
        
        if let key = accountKey, !key.isEmpty {
            config.accountKey = key
            config.sasToken = nil  // Clear SAS token if using account key
        } else if let token = sasToken, !token.isEmpty {
            config.sasToken = token
            config.accountKey = nil  // Clear account key if using SAS token
        }
        
        Logger.info("Azure Storage configuration completed successfully", category: .core)
        reply(true)
    }
    
    /// Uploads a report file to Azure Storage
    func uploadReportToAzureStorage(fileURL: URL, reply: @escaping (Bool) -> Void) {
        Logger.info("Starting Azure Storage upload for file: \(fileURL.lastPathComponent)", category: .core)
        
        Task {
            do {
                // Verify configuration
                guard AzureStorageConfig.shared.isConfigured else {
                    Logger.error("Azure Storage upload failed: not properly configured", category: .core)
                    DispatchQueue.main.async { reply(false) }
                    return
                }
                
                // Create storage manager
                let config = try AzureStorageConfig.shared.createStorageConfig()
                let manager = AzureStorageManager(config: config)
                
                // Upload file
                try await manager.uploadReport(fileURL: fileURL)
                
                Logger.info("Azure Storage upload completed successfully for: \(fileURL.lastPathComponent)", category: .core)
                DispatchQueue.main.async { reply(true) }
                
            } catch {
                Logger.error("Azure Storage upload failed: \(error.localizedDescription)", category: .core)
                DispatchQueue.main.async { reply(false) }
            }
        }
    }
    
    /// Deletes old reports from Azure Storage based on age
    func deleteOldReportsFromAzureStorage(olderThan days: Int, reply: @escaping (Int, Int64) -> Void) {
        Logger.info("Starting Azure Storage cleanup for reports older than \(days) days", category: .core)
        
        Task {
            do {
                // Verify configuration
                guard AzureStorageConfig.shared.isConfigured else {
                    Logger.error("Azure Storage cleanup failed: not properly configured", category: .core)
                    DispatchQueue.main.async { reply(0, 0) }
                    return
                }
                
                // Create storage manager
                let config = try AzureStorageConfig.shared.createStorageConfig()
                let manager = AzureStorageManager(config: config)
                
                // Delete old reports
                try await manager.deleteOldReports(olderThan: days)
                
                // For now, return placeholder values since the manager doesn't return counts yet
                // TODO: Modify deleteOldReports to return deletion statistics
                Logger.info("Azure Storage cleanup completed successfully", category: .core)
                DispatchQueue.main.async { reply(0, 0) }
                
            } catch {
                Logger.error("Azure Storage cleanup failed: \(error.localizedDescription)", category: .core)
                DispatchQueue.main.async { reply(0, 0) }
            }
        }
    }
    
    /// Generates a download link for a specific report
    func generateAzureStorageDownloadLink(for reportName: String, expiresIn days: Int, reply: @escaping (URL?) -> Void) {
        Logger.info("Generating Azure Storage download link for: \(reportName), expires in \(days) days", category: .core)
        
        Task {
            do {
                // Verify configuration
                guard AzureStorageConfig.shared.isConfigured else {
                    Logger.error("Azure Storage download link generation failed: not properly configured", category: .core)
                    DispatchQueue.main.async { reply(nil) }
                    return
                }
                
                // Create storage manager
                let config = try AzureStorageConfig.shared.createStorageConfig()
                let manager = AzureStorageManager(config: config)
                
                // Generate download link
                let downloadUrl = try await manager.generateDownloadLink(for: reportName, expiresIn: days)
                
                Logger.info("Azure Storage download link generated successfully for: \(reportName)", category: .core)
                DispatchQueue.main.async { reply(downloadUrl) }
                
            } catch {
                Logger.error("Azure Storage download link generation failed: \(error.localizedDescription)", category: .core)
                DispatchQueue.main.async { reply(nil) }
            }
        }
    }
    
    /// Validates Azure Storage connection and permissions
    func validateAzureStorageConnection(reply: @escaping (Bool, String?) -> Void) {
        Logger.info("Validating Azure Storage connection", category: .core)
        
        Task {
            let result = await AzureStorageConfig.shared.validateConnection()
            DispatchQueue.main.async { 
                reply(result.success, result.error)
            }
        }
    }
    
    /// Gets current Azure Storage configuration status
    func getAzureStorageConfigurationStatus(reply: @escaping (Bool) -> Void) {
        let isConfigured = AzureStorageConfig.shared.isConfigured
        Logger.info("Azure Storage configuration status: \(isConfigured ? "configured" : "not configured")", category: .core)
        reply(isConfigured)
    }
    
    /// Clears all Azure Storage configuration
    func clearAzureStorageConfiguration(reply: @escaping (Bool) -> Void) {
        Logger.info("Clearing Azure Storage configuration", category: .core)
        AzureStorageConfig.shared.clearConfiguration()
        reply(true)
    }
    
    // MARK: - Azure Storage Configuration Management
    
    /// Sets the Azure Storage account name
    func setAzureStorageAccountName(_ accountName: String, reply: @escaping (Bool) -> Void) {
        Logger.info("Setting Azure Storage account name: \(accountName)", category: .core)
        AzureStorageConfig.shared.accountName = accountName
        reply(true)
    }
    
    /// Gets the Azure Storage account name
    func getAzureStorageAccountName(reply: @escaping (String) -> Void) {
        let accountName = AzureStorageConfig.shared.accountName ?? ""
        reply(accountName)
    }
    
    /// Sets the Azure Storage container name
    func setAzureStorageContainerName(_ containerName: String, reply: @escaping (Bool) -> Void) {
        Logger.info("Setting Azure Storage container name: \(containerName)", category: .core)
        AzureStorageConfig.shared.containerName = containerName
        reply(true)
    }
    
    /// Gets the Azure Storage container name
    func getAzureStorageContainerName(reply: @escaping (String) -> Void) {
        let containerName = AzureStorageConfig.shared.containerName ?? ""
        reply(containerName)
    }
    
    /// Sets the Azure Storage account key
    func setAzureStorageAccountKey(_ accountKey: String, reply: @escaping (Bool) -> Void) {
        Logger.info("Setting Azure Storage account key", category: .core)
        AzureStorageConfig.shared.accountKey = accountKey
        reply(true)
    }
    
    /// Gets the Azure Storage account key
    func getAzureStorageAccountKey(reply: @escaping (String?) -> Void) {
        let accountKey = AzureStorageConfig.shared.accountKey
        reply(accountKey)
    }
    
    /// Sets the Azure Storage SAS token
    func setAzureStorageSASToken(_ sasToken: String, reply: @escaping (Bool) -> Void) {
        Logger.info("Setting Azure Storage SAS token", category: .core)
        AzureStorageConfig.shared.sasToken = sasToken
        reply(true)
    }
    
    /// Gets the Azure Storage SAS token
    func getAzureStorageSASToken(reply: @escaping (String?) -> Void) {
        let sasToken = AzureStorageConfig.shared.sasToken
        reply(sasToken)
    }
    
    /// Removes the Azure Storage account key from keychain
    func removeAzureStorageAccountKey(reply: @escaping (Bool) -> Void) {
        Logger.info("Removing Azure Storage account key", category: .core)
        AzureStorageConfig.shared.accountKey = nil
        reply(true)
    }
    
    /// Removes the Azure Storage SAS token from keychain
    func removeAzureStorageSASToken(reply: @escaping (Bool) -> Void) {
        Logger.info("Removing Azure Storage SAS token", category: .core)
        AzureStorageConfig.shared.sasToken = nil
        reply(true)
    }
    
    // MARK: - Named Azure Storage Configurations
    
    /// Gets all available named Azure Storage configuration names
    func getAzureStorageConfigurationNames(reply: @escaping ([String]) -> Void) {
        let names = AzureStorageConfig.shared.availableConfigurationNames
        Logger.info("Retrieved \(names.count) Azure Storage configuration names", category: .core)
        reply(names)
    }
    
    /// Gets a specific named Azure Storage configuration
    func getNamedAzureStorageConfiguration(name: String, reply: @escaping ([String: Any]?) -> Void) {
        Logger.info("Retrieving Azure Storage configuration: \(name)", category: .core)
        
        guard let config = AzureStorageConfig.shared.getConfiguration(named: name) else {
            Logger.warning("Azure Storage configuration '\(name)' not found", category: .core)
            reply(nil)
            return
        }
        
        // Convert to dictionary (excluding sensitive credentials)
        let configDict: [String: Any] = [
            "name": config.name,
            "accountName": config.accountName,
            "containerName": config.containerName,
            "authMethod": config.authMethod.description,
            "description": config.description ?? "",
            "created": config.created.timeIntervalSince1970,
            "modified": config.modified.timeIntervalSince1970
        ]
        
        reply(configDict)
    }
    
    /// Sets a named Azure Storage configuration
    func setNamedAzureStorageConfiguration(name: String, configData: [String: Any], reply: @escaping (Bool) -> Void) {
        Logger.info("Setting Azure Storage configuration: \(name)", category: .core)
        
        // Extract required fields
        guard let accountName = configData["accountName"] as? String,
              let containerName = configData["containerName"] as? String,
              let authMethodType = configData["authMethodType"] as? String else {
            Logger.error("Missing required fields for Azure Storage configuration '\(name)'", category: .core)
            reply(false)
            return
        }
        
        // Parse authentication method
        let authMethod: AzureStorageConfig.NamedStorageConfiguration.StorageAuthMethod
        switch authMethodType {
        case "storageKey":
            guard let accountKey = configData["accountKey"] as? String else {
                Logger.error("Missing account key for storage key authentication", category: .core)
                reply(false)
                return
            }
            authMethod = .storageKey(accountKey)
            
        case "sasToken":
            guard let sasToken = configData["sasToken"] as? String else {
                Logger.error("Missing SAS token for SAS token authentication", category: .core)
                reply(false)
                return
            }
            authMethod = .sasToken(sasToken)
            
        case "azureAD":
            guard let tenantId = configData["tenantId"] as? String,
                  let clientId = configData["clientId"] as? String,
                  let clientSecret = configData["clientSecret"] as? String else {
                Logger.error("Missing Azure AD credentials for OAuth authentication", category: .core)
                reply(false)
                return
            }
            authMethod = .azureAD(tenantId: tenantId, clientId: clientId, clientSecret: clientSecret)
            
        default:
            Logger.error("Invalid authentication method type: \(authMethodType)", category: .core)
            reply(false)
            return
        }
        
        // Create configuration
        let now = Date()
        let configuration = AzureStorageConfig.NamedStorageConfiguration(
            name: name,
            accountName: accountName,
            containerName: containerName,
            authMethod: authMethod,
            description: configData["description"] as? String,
            created: configData["created"] as? Date ?? now,
            modified: now
        )
        
        // Store configuration
        let success = AzureStorageConfig.shared.setConfiguration(named: name, configuration: configuration)
        reply(success)
    }
    
    /// Removes a named Azure Storage configuration
    func removeNamedAzureStorageConfiguration(name: String, reply: @escaping (Bool) -> Void) {
        Logger.info("Removing Azure Storage configuration: \(name)", category: .core)
        let success = AzureStorageConfig.shared.removeConfiguration(named: name)
        reply(success)
    }
    
    /// Validates a named Azure Storage configuration
    func validateNamedAzureStorageConfiguration(name: String, reply: @escaping (Bool) -> Void) {
        Logger.info("Validating Azure Storage configuration: \(name)", category: .core)
        let isValid = AzureStorageConfig.shared.validateConfiguration(named: name)
        reply(isValid)
    }
    
    /// Gets summary information for all Azure Storage configurations
    func getAzureStorageConfigurationSummaries(reply: @escaping ([[String: Any]]) -> Void) {
        Logger.info("Retrieving Azure Storage configuration summaries", category: .core)
        
        let summaries = AzureStorageConfig.shared.getConfigurationSummaries()
        let summaryDicts = summaries.map { summary in
            [
                "name": summary.name,
                "accountName": summary.accountName,
                "containerName": summary.containerName,
                "authMethod": summary.authMethod,
                "description": summary.description ?? "",
                "created": summary.created.timeIntervalSince1970,
                "modified": summary.modified.timeIntervalSince1970,
                "isValid": summary.isValid
            ] as [String: Any]
        }
        
        reply(summaryDicts)
    }
    
    /// Uploads a report to a specific named Azure Storage configuration
    func uploadReportToNamedAzureStorage(fileURL: URL, configurationName: String, reply: @escaping (Bool) -> Void) {
        Logger.info("Uploading report to named Azure Storage '\(configurationName)': \(fileURL.lastPathComponent)", category: .core)
        
        Task {
            do {
                // Get the named configuration and create manager
                let manager = try AzureStorageConfig.shared.createManager(for: configurationName)
                
                // Upload the report
                try await manager.uploadReport(fileURL: fileURL)
                
                Logger.info("Successfully uploaded report to '\(configurationName)': \(fileURL.lastPathComponent)", category: .core)
                DispatchQueue.main.async { reply(true) }
                
            } catch {
                Logger.error("Failed to upload report to '\(configurationName)': \(error.localizedDescription)", category: .core)
                DispatchQueue.main.async { reply(false) }
            }
        }
    }
    
    /// Deletes old reports from a specific named Azure Storage configuration
    func deleteOldReportsFromNamedAzureStorage(olderThan days: Int, configurationName: String, reply: @escaping (Int, Int64) -> Void) {
        Logger.info("Cleaning up reports older than \(days) days from '\(configurationName)'", category: .core)
        
        Task {
            do {
                // Get the named configuration and create manager
                let manager = try AzureStorageConfig.shared.createManager(for: configurationName)
                
                // Delete old reports
                try await manager.deleteOldReports(olderThan: days)
                
                // TODO: Return actual counts when implemented in AzureStorageManager
                Logger.info("Successfully cleaned up old reports from '\(configurationName)'", category: .core)
                DispatchQueue.main.async { reply(0, 0) }
                
            } catch {
                Logger.error("Failed to clean up reports from '\(configurationName)': \(error.localizedDescription)", category: .core)
                DispatchQueue.main.async { reply(0, 0) }
            }
        }
    }
    
    /// Generates a download link for a report in a specific named Azure Storage configuration
    func generateDownloadLinkFromNamedAzureStorage(for reportName: String, expiresIn days: Int, configurationName: String, reply: @escaping (URL?) -> Void) {
        Logger.info("Generating download link for '\(reportName)' from '\(configurationName)', expires in \(days) days", category: .core)
        
        Task {
            do {
                // Get the named configuration and create manager
                let manager = try AzureStorageConfig.shared.createManager(for: configurationName)
                
                // Generate download link
                let downloadUrl = try await manager.generateDownloadLink(for: reportName, expiresIn: days)
                
                Logger.info("Successfully generated download link for '\(reportName)' from '\(configurationName)'", category: .core)
                DispatchQueue.main.async { reply(downloadUrl) }
                
            } catch {
                Logger.error("Failed to generate download link for '\(reportName)' from '\(configurationName)': \(error.localizedDescription)", category: .core)
                DispatchQueue.main.async { reply(nil) }
            }
        }
    }
    
    /// Clears all named Azure Storage configurations (keeps default intact)
    func clearAllNamedAzureStorageConfigurations(reply: @escaping (Bool) -> Void) {
        Logger.info("Clearing all named Azure Storage configurations", category: .core)
        AzureStorageConfig.shared.clearAllNamedConfigurations()
        reply(true)
    }
}
