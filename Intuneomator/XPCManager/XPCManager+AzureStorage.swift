//
//  XPCManager+AzureStorage.swift
//  Intuneomator
//
//  Created by Gil Burns on 7/22/25.
//

import Foundation

/// XPC Manager extension for Azure Storage management
/// Provides client-side interface for Azure Storage operations through the privileged daemon service
extension XPCManager {
    
    // MARK: - Azure Storage Configuration
    
    /// Configures Azure Storage settings for report management
    /// - Parameters:
    ///   - accountName: Storage account name
    ///   - containerName: Container name for storing reports
    ///   - accountKey: Storage account key (optional, for shared key auth)
    ///   - sasToken: SAS token (optional, alternative to account key)
    ///   - completion: Callback indicating if configuration was successful
    func configureAzureStorage(
        accountName: String,
        containerName: String,
        accountKey: String? = nil,
        sasToken: String? = nil,
        completion: @escaping (Bool) -> Void
    ) {
        Logger.info("Configuring Azure Storage via XPC: \(accountName)/\(containerName)", category: .core, toUserDirectory: true)
        
        sendRequest({ proxy, reply in
            proxy.configureAzureStorage(
                accountName: accountName,
                containerName: containerName,
                accountKey: accountKey,
                sasToken: sasToken,
                reply: { success in
                    reply(success)
                }
            )
        }, completion: { result in
            completion(result ?? false)
        })
    }
    
    /// Uploads a report file to Azure Storage
    /// - Parameters:
    ///   - fileURL: Local file URL to upload
    ///   - completion: Callback indicating success (true) or failure (false)
    func uploadReportToAzureStorage(fileURL: URL, completion: @escaping (Bool) -> Void) {
        Logger.info("Uploading report to Azure Storage via XPC: \(fileURL.lastPathComponent)", category: .core, toUserDirectory: true)
        
        sendRequest({ proxy, reply in
            proxy.uploadReportToAzureStorage(fileURL: fileURL, reply: { success in
                reply(success)
            })
        }, completion: { result in
            completion(result ?? false)
        })
    }
    
    /// Deletes old reports from Azure Storage based on age
    /// - Parameters:
    ///   - days: Delete reports older than this many days
    ///   - completion: Callback with deletion count and total size freed in bytes
    func deleteOldReportsFromAzureStorage(olderThan days: Int, completion: @escaping (Int, Int64) -> Void) {
        Logger.info("Cleaning up old reports from Azure Storage via XPC: older than \(days) days", category: .core, toUserDirectory: true)
        
        sendRequest({ proxy, reply in
            proxy.deleteOldReportsFromAzureStorage(olderThan: days, reply: { count, size in
                reply((count, size))
            })
        }, completion: { result in
            if let result = result {
                completion(result.0, result.1)
            } else {
                completion(0, 0)
            }
        })
    }
    
    /// Generates a download link for a specific report
    /// - Parameters:
    ///   - reportName: Name of the report file
    ///   - expiresIn: Number of days the link should remain valid
    ///   - completion: Callback with download URL or nil on failure
    func generateAzureStorageDownloadLink(
        for reportName: String,
        expiresIn days: Int,
        completion: @escaping (URL?) -> Void
    ) {
        Logger.info("Generating Azure Storage download link via XPC: \(reportName), expires in \(days) days", category: .core, toUserDirectory: true)
        
        sendRequest({ proxy, reply in
            proxy.generateAzureStorageDownloadLink(for: reportName, expiresIn: days, reply: { url in
                reply(url)
            })
        }, completion: completion)
    }
    
    /// Validates Azure Storage connection and permissions
    /// - Parameter completion: Callback with success status and optional error message
    func validateAzureStorageConnection(completion: @escaping (Bool, String?) -> Void) {
        Logger.info("Validating Azure Storage connection via XPC", category: .core, toUserDirectory: true)
        
        sendRequest({ proxy, reply in
            proxy.validateAzureStorageConnection(reply: { success, error in
                reply((success, error))
            })
        }, completion: { result in
            completion(result?.0 ?? false, result?.1)
        })
    }
    
    /// Gets current Azure Storage configuration status
    /// - Parameter completion: Callback indicating if Azure Storage is properly configured
    func getAzureStorageConfigurationStatus(completion: @escaping (Bool) -> Void) {
        sendRequest({ proxy, reply in
            proxy.getAzureStorageConfigurationStatus(reply: { isConfigured in
                reply(isConfigured)
            })
        }, completion: { result in
            completion(result ?? false)
        })
    }
    
    /// Clears all Azure Storage configuration
    /// - Parameter completion: Callback indicating if clearing was successful
    func clearAzureStorageConfiguration(completion: @escaping (Bool) -> Void) {
        Logger.info("Clearing Azure Storage configuration via XPC", category: .core, toUserDirectory: true)
        
        sendRequest({ proxy, reply in
            proxy.clearAzureStorageConfiguration(reply: { success in
                reply(success)
            })
        }, completion: { result in
            completion(result ?? false)
        })
    }
    
    // MARK: - Individual Azure Storage Configuration Management
    
    /// Sets the Azure Storage account name via XPC
    /// - Parameters:
    ///   - accountName: Storage account name
    ///   - completion: Callback indicating if setting was successful
    func setAzureStorageAccountName(_ accountName: String, completion: @escaping (Bool) -> Void) {
        sendRequest({ proxy, reply in
            proxy.setAzureStorageAccountName(accountName, reply: { success in
                reply(success)
            })
        }, completion: { result in
            completion(result ?? false)
        })
    }
    
    /// Gets the Azure Storage account name via XPC
    /// - Parameter completion: Callback with account name
    func getAzureStorageAccountName(completion: @escaping (String) -> Void) {
        sendRequest({ proxy, reply in
            proxy.getAzureStorageAccountName(reply: { accountName in
                reply(accountName)
            })
        }, completion: { result in
            completion(result ?? "")
        })
    }
    
    /// Sets the Azure Storage container name via XPC
    /// - Parameters:
    ///   - containerName: Container name
    ///   - completion: Callback indicating if setting was successful
    func setAzureStorageContainerName(_ containerName: String, completion: @escaping (Bool) -> Void) {
        sendRequest({ proxy, reply in
            proxy.setAzureStorageContainerName(containerName, reply: { success in
                reply(success)
            })
        }, completion: { result in
            completion(result ?? false)
        })
    }
    
    /// Gets the Azure Storage container name via XPC
    /// - Parameter completion: Callback with container name
    func getAzureStorageContainerName(completion: @escaping (String) -> Void) {
        sendRequest({ proxy, reply in
            proxy.getAzureStorageContainerName(reply: { containerName in
                reply(containerName)
            })
        }, completion: { result in
            completion(result ?? "")
        })
    }
    
    /// Sets the Azure Storage account key via XPC
    /// - Parameters:
    ///   - accountKey: Storage account key
    ///   - completion: Callback indicating if setting was successful
    func setAzureStorageAccountKey(_ accountKey: String, completion: @escaping (Bool) -> Void) {
        sendRequest({ proxy, reply in
            proxy.setAzureStorageAccountKey(accountKey, reply: { success in
                reply(success)
            })
        }, completion: { result in
            completion(result ?? false)
        })
    }
    
    /// Gets the Azure Storage account key via XPC
    /// - Parameter completion: Callback with account key or nil if not set
    func getAzureStorageAccountKey(completion: @escaping (String?) -> Void) {
        sendRequest({ proxy, reply in
            proxy.getAzureStorageAccountKey(reply: { accountKey in
                reply(accountKey)
            })
        }, completion: completion)
    }
    
    /// Sets the Azure Storage SAS token via XPC
    /// - Parameters:
    ///   - sasToken: SAS token
    ///   - completion: Callback indicating if setting was successful
    func setAzureStorageSASToken(_ sasToken: String, completion: @escaping (Bool) -> Void) {
        sendRequest({ proxy, reply in
            proxy.setAzureStorageSASToken(sasToken, reply: { success in
                reply(success)
            })
        }, completion: { result in
            completion(result ?? false)
        })
    }
    
    /// Gets the Azure Storage SAS token via XPC
    /// - Parameter completion: Callback with SAS token or nil if not set
    func getAzureStorageSASToken(completion: @escaping (String?) -> Void) {
        sendRequest({ proxy, reply in
            proxy.getAzureStorageSASToken(reply: { sasToken in
                reply(sasToken)
            })
        }, completion: completion)
    }
    
    /// Removes the Azure Storage account key via XPC
    /// - Parameter completion: Callback indicating if removal was successful
    func removeAzureStorageAccountKey(completion: @escaping (Bool) -> Void) {
        sendRequest({ proxy, reply in
            proxy.removeAzureStorageAccountKey(reply: { success in
                reply(success)
            })
        }, completion: { result in
            completion(result ?? false)
        })
    }
    
    /// Removes the Azure Storage SAS token via XPC
    /// - Parameter completion: Callback indicating if removal was successful
    func removeAzureStorageSASToken(completion: @escaping (Bool) -> Void) {
        sendRequest({ proxy, reply in
            proxy.removeAzureStorageSASToken(reply: { success in
                reply(success)
            })
        }, completion: { result in
            completion(result ?? false)
        })
    }
    
    // MARK: - Named Azure Storage Configuration Management
    
    /// Gets all available named Azure Storage configuration names via XPC
    /// - Parameter completion: Callback with array of configuration names
    func getAzureStorageConfigurationNames(completion: @escaping ([String]) -> Void) {
        sendRequest({ proxy, reply in
            proxy.getAzureStorageConfigurationNames(reply: { names in
                reply(names)
            })
        }, completion: { result in
            completion(result ?? [])
        })
    }
    
    /// Gets a specific named Azure Storage configuration via XPC
    /// - Parameters:
    ///   - name: Configuration name
    ///   - completion: Callback with configuration data or nil if not found
    func getNamedAzureStorageConfiguration(name: String, completion: @escaping ([String: Any]?) -> Void) {
        sendRequest({ proxy, reply in
            proxy.getNamedAzureStorageConfiguration(name: name, reply: { configData in
                reply(configData)
            })
        }, completion: completion)
    }
    
    /// Sets a named Azure Storage configuration via XPC
    /// - Parameters:
    ///   - name: Configuration name
    ///   - configData: Configuration data dictionary
    ///   - completion: Callback indicating if operation was successful
    func setNamedAzureStorageConfiguration(name: String, configData: [String: Any], completion: @escaping (Bool) -> Void) {
        Logger.info("Setting named Azure Storage configuration via XPC: \(name)", category: .core, toUserDirectory: true)
        
        sendRequest({ proxy, reply in
            proxy.setNamedAzureStorageConfiguration(name: name, configData: configData, reply: { success in
                reply(success)
            })
        }, completion: { result in
            completion(result ?? false)
        })
    }
    
    /// Removes a named Azure Storage configuration via XPC
    /// - Parameters:
    ///   - name: Configuration name to remove
    ///   - completion: Callback indicating if operation was successful
    func removeNamedAzureStorageConfiguration(name: String, completion: @escaping (Bool) -> Void) {
        Logger.info("Removing named Azure Storage configuration via XPC: \(name)", category: .core, toUserDirectory: true)
        
        sendRequest({ proxy, reply in
            proxy.removeNamedAzureStorageConfiguration(name: name, reply: { success in
                reply(success)
            })
        }, completion: { result in
            completion(result ?? false)
        })
    }
    
    /// Validates a named Azure Storage configuration via XPC
    /// - Parameters:
    ///   - name: Configuration name to validate
    ///   - completion: Callback indicating if configuration is valid
    func validateNamedAzureStorageConfiguration(name: String, completion: @escaping (Bool) -> Void) {
        sendRequest({ proxy, reply in
            proxy.validateNamedAzureStorageConfiguration(name: name, reply: { isValid in
                reply(isValid)
            })
        }, completion: { result in
            completion(result ?? false)
        })
    }
    
    /// Gets summary information for all Azure Storage configurations via XPC
    /// - Parameter completion: Callback with array of configuration summaries
    func getAzureStorageConfigurationSummaries(completion: @escaping ([[String: Any]]) -> Void) {
        sendRequest({ proxy, reply in
            proxy.getAzureStorageConfigurationSummaries(reply: { summaries in
                reply(summaries)
            })
        }, completion: { result in
            completion(result ?? [])
        })
    }
    
    /// Uploads a report to a specific named Azure Storage configuration via XPC
    /// - Parameters:
    ///   - fileURL: Local file URL to upload
    ///   - configurationName: Named configuration to use for upload
    ///   - completion: Callback indicating if upload was successful
    func uploadReportToNamedAzureStorage(fileURL: URL, configurationName: String, completion: @escaping (Bool) -> Void) {
        Logger.info("Uploading report to named Azure Storage '\(configurationName)' via XPC: \(fileURL.lastPathComponent)", category: .core, toUserDirectory: true)
        
        sendRequest({ proxy, reply in
            proxy.uploadReportToNamedAzureStorage(fileURL: fileURL, configurationName: configurationName, reply: { success in
                reply(success)
            })
        }, completion: { result in
            completion(result ?? false)
        })
    }
    
    /// Deletes old reports from a specific named Azure Storage configuration via XPC
    /// - Parameters:
    ///   - days: Delete reports older than this many days
    ///   - configurationName: Named configuration to use
    ///   - completion: Callback with deletion count and total size freed in bytes
    func deleteOldReportsFromNamedAzureStorage(olderThan days: Int, configurationName: String, completion: @escaping (Int, Int64) -> Void) {
        Logger.info("Cleaning up old reports from named Azure Storage '\(configurationName)' via XPC: older than \(days) days", category: .core, toUserDirectory: true)
        
        sendRequest({ proxy, reply in
            proxy.deleteOldReportsFromNamedAzureStorage(olderThan: days, configurationName: configurationName, reply: { count, size in
                reply((count, size))
            })
        }, completion: { result in
            if let result = result {
                completion(result.0, result.1)
            } else {
                completion(0, 0)
            }
        })
    }
    
    /// Generates a download link for a report in a specific named Azure Storage configuration via XPC
    /// - Parameters:
    ///   - reportName: Name of the report file
    ///   - expiresIn: Number of days the link should remain valid
    ///   - configurationName: Named configuration to use
    ///   - completion: Callback with download URL or nil on failure
    func generateDownloadLinkFromNamedAzureStorage(for reportName: String, expiresIn days: Int, configurationName: String, completion: @escaping (URL?) -> Void) {
        Logger.info("Generating download link for '\(reportName)' from named Azure Storage '\(configurationName)' via XPC, expires in \(days) days", category: .core, toUserDirectory: true)
        
        sendRequest({ proxy, reply in
            proxy.generateDownloadLinkFromNamedAzureStorage(for: reportName, expiresIn: days, configurationName: configurationName, reply: { url in
                reply(url)
            })
        }, completion: completion)
    }
    
    /// Clears all named Azure Storage configurations via XPC (keeps default intact)
    /// - Parameter completion: Callback indicating if operation was successful
    func clearAllNamedAzureStorageConfigurations(completion: @escaping (Bool) -> Void) {
        Logger.info("Clearing all named Azure Storage configurations via XPC", category: .core, toUserDirectory: true)
        
        sendRequest({ proxy, reply in
            proxy.clearAllNamedAzureStorageConfigurations(reply: { success in
                reply(success)
            })
        }, completion: { result in
            completion(result ?? false)
        })
    }
    
    // MARK: - Azure Storage File Management Testing Methods
    
    /// Uploads a file to Azure Storage using a named configuration for testing
    /// - Parameters:
    ///   - fileName: Name of the file to upload
    ///   - fileData: Data content of the file
    ///   - configurationName: Name of the Azure Storage configuration to use
    ///   - completion: Callback indicating if upload was successful
    func uploadFileToAzureStorage(fileName: String, fileData: Data, configurationName: String, completion: @escaping (Bool?) -> Void) {
        sendRequest({ proxy, reply in
            proxy.uploadFileToAzureStorage(fileName: fileName, fileData: fileData, configurationName: configurationName, reply: { success in
                reply(success)
            })
        }, completion: completion)
    }
    
    /// Generates a download link for a file in Azure Storage using a named configuration for testing
    /// - Parameters:
    ///   - fileName: Name of the file to generate link for
    ///   - configurationName: Name of the Azure Storage configuration to use
    ///   - expiresInDays: Number of days the link should remain valid
    ///   - completion: Callback with download URL or nil on failure
    func generateAzureStorageDownloadLink(fileName: String, configurationName: String, expiresInDays: Int, completion: @escaping (URL?) -> Void) {
        sendRequest({ proxy, reply in
            proxy.generateAzureStorageDownloadLink(fileName: fileName, configurationName: configurationName, expiresInDays: expiresInDays, reply: { url in
                reply(url)
            })
        }, completion: completion)
    }
    
    /// Sends a Teams notification message for testing
    /// - Parameters:
    ///   - message: Message content to send
    ///   - completion: Callback indicating if notification was sent successfully
    func sendTeamsNotification(message: String, completion: @escaping (Bool?) -> Void) {
        sendRequest({ proxy, reply in
            proxy.sendTeamsNotification(message: message, reply: { success in
                reply(success)
            })
        }, completion: completion)
    }
    
    /// Lists all files in Azure Storage using a named configuration
    /// - Parameters:
    ///   - configurationName: Name of the Azure Storage configuration to use
    ///   - completion: Callback with array of file information dictionaries or nil on failure
    func listAzureStorageFiles(configurationName: String, completion: @escaping ([[String: Any]]?) -> Void) {
        sendRequest({ proxy, reply in
            proxy.listAzureStorageFiles(configurationName: configurationName, reply: { fileList in
                reply(fileList)
            })
        }, completion: completion)
    }
    
    /// Deletes a specific file from Azure Storage using a named configuration
    /// - Parameters:
    ///   - fileName: Name of the file to delete
    ///   - configurationName: Name of the Azure Storage configuration to use
    ///   - completion: Callback indicating if deletion was successful
    func deleteAzureStorageFile(fileName: String, configurationName: String, completion: @escaping (Bool?) -> Void) {
        sendRequest({ proxy, reply in
            proxy.deleteAzureStorageFile(fileName: fileName, configurationName: configurationName, reply: { success in
                reply(success)
            })
        }, completion: completion)
    }
    
    /// Deletes old files from Azure Storage based on age using a named configuration
    /// - Parameters:
    ///   - configurationName: Name of the Azure Storage configuration to use
    ///   - olderThanDays: Delete files older than this many days
    ///   - completion: Callback with deletion summary dictionary or nil on failure
    func deleteOldAzureStorageFiles(configurationName: String, olderThanDays: Int, completion: @escaping ([String: Any]?) -> Void) {
        sendRequest({ proxy, reply in
            proxy.deleteOldAzureStorageFiles(configurationName: configurationName, olderThanDays: olderThanDays, reply: { summary in
                reply(summary)
            })
        }, completion: completion)
    }
}

// MARK: - Convenience Methods

extension XPCManager {
    
    /// Configures Azure Storage with shared key authentication
    /// - Parameters:
    ///   - accountName: Storage account name
    ///   - accountKey: Storage account key
    ///   - containerName: Container name (defaults to "intuneomator-reports")
    ///   - completion: Callback indicating if configuration was successful
    func configureAzureStorageWithSharedKey(
        accountName: String,
        accountKey: String,
        containerName: String = "intuneomator-reports",
        completion: @escaping (Bool) -> Void
    ) {
        configureAzureStorage(
            accountName: accountName,
            containerName: containerName,
            accountKey: accountKey,
            sasToken: nil,
            completion: completion
        )
    }
    
    /// Configures Azure Storage with SAS token authentication
    /// - Parameters:
    ///   - accountName: Storage account name
    ///   - sasToken: SAS token
    ///   - containerName: Container name (defaults to "intuneomator-reports")
    ///   - completion: Callback indicating if configuration was successful
    func configureAzureStorageWithSASToken(
        accountName: String,
        sasToken: String,
        containerName: String = "intuneomator-reports",
        completion: @escaping (Bool) -> Void
    ) {
        configureAzureStorage(
            accountName: accountName,
            containerName: containerName,
            accountKey: nil,
            sasToken: sasToken,
            completion: completion
        )
    }
    
    /// Uploads a report and optionally generates a download link
    /// - Parameters:
    ///   - fileURL: Local file URL to upload
    ///   - generateDownloadLink: Whether to generate a download link after upload
    ///   - linkExpiresIn: Number of days the download link should remain valid
    ///   - completion: Callback with upload success and optional download URL
    func uploadReportWithOptionalLink(
        fileURL: URL,
        generateDownloadLink: Bool = false,
        linkExpiresIn days: Int = 7,
        completion: @escaping (Bool, URL?) -> Void
    ) {
        uploadReportToAzureStorage(fileURL: fileURL) { [weak self] uploadSuccess in
            guard uploadSuccess else {
                completion(false, nil)
                return
            }
            
            guard generateDownloadLink else {
                completion(true, nil)
                return
            }
            
            self?.generateAzureStorageDownloadLink(for: fileURL.lastPathComponent, expiresIn: days) { downloadUrl in
                completion(true, downloadUrl)
            }
        }
    }
    
    /// Performs a complete Azure Storage health check
    /// - Parameter completion: Callback with detailed health status
    func performAzureStorageHealthCheck(completion: @escaping (AzureStorageHealthStatus) -> Void) {
        // Check configuration status
        getAzureStorageConfigurationStatus { isConfigured in
            guard isConfigured else {
                completion(.notConfigured)
                return
            }
            
            // Validate connection
            self.validateAzureStorageConnection { isValid, error in
                if isValid {
                    completion(.healthy)
                } else {
                    completion(.connectionFailed(error ?? "Unknown connection error"))
                }
            }
        }
    }
    
    // MARK: - Named Configuration Convenience Methods
    
    /// Creates a new named Azure Storage configuration with shared key authentication
    /// - Parameters:
    ///   - name: Configuration name
    ///   - accountName: Storage account name
    ///   - accountKey: Storage account key
    ///   - containerName: Container name (defaults to "intuneomator-reports")
    ///   - description: Optional description
    ///   - completion: Callback indicating if creation was successful
    func createNamedAzureStorageConfiguration(
        name: String,
        accountName: String,
        accountKey: String,
        containerName: String = "intuneomator-reports",
        description: String? = nil,
        completion: @escaping (Bool) -> Void
    ) {
        let configData: [String: Any] = [
            "accountName": accountName,
            "containerName": containerName,
            "authMethodType": "storageKey",
            "accountKey": accountKey,
            "description": description ?? ""
        ]
        
        setNamedAzureStorageConfiguration(name: name, configData: configData, completion: completion)
    }
    
    /// Creates a new named Azure Storage configuration with SAS token authentication
    /// - Parameters:
    ///   - name: Configuration name
    ///   - accountName: Storage account name
    ///   - sasToken: SAS token
    ///   - containerName: Container name (defaults to "intuneomator-reports")
    ///   - description: Optional description
    ///   - completion: Callback indicating if creation was successful
    func createNamedAzureStorageConfigurationWithSAS(
        name: String,
        accountName: String,
        sasToken: String,
        containerName: String = "intuneomator-reports",
        description: String? = nil,
        completion: @escaping (Bool) -> Void
    ) {
        let configData: [String: Any] = [
            "accountName": accountName,
            "containerName": containerName,
            "authMethodType": "sasToken",
            "sasToken": sasToken,
            "description": description ?? ""
        ]
        
        setNamedAzureStorageConfiguration(name: name, configData: configData, completion: completion)
    }
    
    /// Creates a new named Azure Storage configuration with Azure AD authentication
    /// - Parameters:
    ///   - name: Configuration name
    ///   - accountName: Storage account name
    ///   - tenantId: Azure AD tenant ID
    ///   - clientId: Azure AD client ID
    ///   - clientSecret: Azure AD client secret
    ///   - containerName: Container name (defaults to "intuneomator-reports")
    ///   - description: Optional description
    ///   - completion: Callback indicating if creation was successful
    func createNamedAzureStorageConfigurationWithAzureAD(
        name: String,
        accountName: String,
        tenantId: String,
        clientId: String,
        clientSecret: String,
        containerName: String = "intuneomator-reports",
        description: String? = nil,
        completion: @escaping (Bool) -> Void
    ) {
        let configData: [String: Any] = [
            "accountName": accountName,
            "containerName": containerName,
            "authMethodType": "azureAD",
            "tenantId": tenantId,
            "clientId": clientId,
            "clientSecret": clientSecret,
            "description": description ?? ""
        ]
        
        setNamedAzureStorageConfiguration(name: name, configData: configData, completion: completion)
    }
    
    /// Uploads a report with automatic fallback to default configuration if named config fails
    /// - Parameters:
    ///   - fileURL: Local file URL to upload
    ///   - preferredConfigurationName: Preferred named configuration to try first
    ///   - useDefaultFallback: Whether to fallback to default configuration on failure
    ///   - completion: Callback with success status and configuration name used
    func uploadReportWithFallback(
        fileURL: URL,
        preferredConfigurationName: String,
        useDefaultFallback: Bool = true,
        completion: @escaping (Bool, String) -> Void
    ) {
        // Try preferred named configuration first
        uploadReportToNamedAzureStorage(fileURL: fileURL, configurationName: preferredConfigurationName) { success in
            if success {
                completion(true, preferredConfigurationName)
                return
            }
            
            guard useDefaultFallback else {
                completion(false, preferredConfigurationName)
                return
            }
            
            // Fallback to default configuration
            self.uploadReportToAzureStorage(fileURL: fileURL) { defaultSuccess in
                completion(defaultSuccess, defaultSuccess ? "default" : "failed")
            }
        }
    }
    
    /// Performs health check for a specific named configuration
    /// - Parameters:
    ///   - configurationName: Named configuration to check
    ///   - completion: Callback with health status
    func performNamedAzureStorageHealthCheck(configurationName: String, completion: @escaping (AzureStorageHealthStatus) -> Void) {
        validateNamedAzureStorageConfiguration(name: configurationName) { isValid in
            if isValid {
                completion(.healthy)
            } else {
                completion(.connectionFailed("Configuration '\(configurationName)' is invalid or not found"))
            }
        }
    }
    
    /// Gets configuration names suitable for populating a dropdown menu
    /// - Parameter completion: Callback with configuration names and display labels
    func getConfigurationMenuItems(completion: @escaping ([(name: String, displayLabel: String)]) -> Void) {
        getAzureStorageConfigurationSummaries { summaries in
            let menuItems = summaries.compactMap { summary -> (String, String)? in
                guard let name = summary["name"] as? String,
                      let accountName = summary["accountName"] as? String,
                      let isValid = summary["isValid"] as? Bool else {
                    return nil
                }
                
                let status = isValid ? "✅" : "❌"
                let displayLabel = "\(name) (\(accountName)) \(status)"
                return (name, displayLabel)
            }
            
            completion(menuItems)
        }
    }
}

// MARK: - Supporting Types

/// Azure Storage health status enumeration
enum AzureStorageHealthStatus {
    case notConfigured
    case healthy
    case connectionFailed(String)
    
    var description: String {
        switch self {
        case .notConfigured:
            return "Azure Storage is not configured"
        case .healthy:
            return "Azure Storage is healthy and accessible"
        case .connectionFailed(let error):
            return "Azure Storage connection failed: \(error)"
        }
    }
    
    var isHealthy: Bool {
        if case .healthy = self {
            return true
        }
        return false
    }
}
