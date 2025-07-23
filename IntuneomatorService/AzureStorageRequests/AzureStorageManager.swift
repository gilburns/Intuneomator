//
//  AzureStorageManager.swift
//  IntuneomatorService
//
//  Created by Gil Burns on 7/22/25.
//

import Foundation

/// Azure Storage REST API Manager for report management
/// Handles authentication, file operations, and blob management for Azure Storage
class AzureStorageManager {
    
    // MARK: - Configuration
    
    /// Storage account configuration
    struct StorageConfig {
        let accountName: String
        let containerName: String
        let authMethod: AuthenticationMethod
        
        enum AuthenticationMethod {
            case storageKey(String)
            case sasToken(String)
            case azureAD(tenantId: String, clientId: String, clientSecret: String)
        }
    }
    
    // MARK: - Properties
    
    private let config: StorageConfig
    private let session: URLSession
    
    // MARK: - Initialization
    
    init(config: StorageConfig) {
        self.config = config
        
        // Configure URL session with reasonable timeouts for large file uploads
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 300  // 5 minutes
        configuration.timeoutIntervalForResource = 1800 // 30 minutes
        self.session = URLSession(configuration: configuration)
        
        Logger.info("Initialized AzureStorageManager for account: \(config.accountName)", category: .core)
    }
    
    // MARK: - Public API
    
    /// Uploads a report file to Azure Storage
    /// - Parameter fileURL: Local file URL to upload
    /// - Throws: AzureStorageError for various failure scenarios
    func uploadReport(fileURL: URL) async throws {
        let fileName = fileURL.lastPathComponent
        let blobName = "reports/\(fileName)"
        
        Logger.info("Starting upload of report: \(fileName) to blob: \(blobName)", category: .core)
        
        // Read file data
        let fileData: Data
        do {
            fileData = try Data(contentsOf: fileURL)
        } catch {
            throw AzureStorageError.fileReadError("Failed to read file at \(fileURL.path): \(error.localizedDescription)")
        }
        
        // Upload to blob storage
        try await uploadBlob(name: blobName, data: fileData, contentType: detectContentType(for: fileName))
        
        Logger.info("Successfully uploaded report: \(fileName) (\(ByteCountFormatter.string(fromByteCount: Int64(fileData.count), countStyle: .file)))", category: .core)
    }
    
    /// Deletes old reports based on age
    /// - Parameter days: Delete reports older than this many days
    /// - Throws: AzureStorageError for various failure scenarios
    func deleteOldReports(olderThan days: Int) async throws {
        Logger.info("Starting deletion of reports older than \(days) days", category: .core)
        
        // List all blobs in the reports folder
        let reportBlobs = try await listBlobs(prefix: "reports/")
        
        // Calculate cutoff date
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        
        var deletedCount = 0
        var totalSize: Int64 = 0
        
        for blob in reportBlobs {
            // Check if blob is older than cutoff date
            if let lastModified = blob.lastModified, lastModified < cutoffDate {
                do {
                    try await deleteBlob(name: blob.name)
                    deletedCount += 1
                    totalSize += blob.size ?? 0
                    Logger.info("Deleted old report: \(blob.name) (modified: \(lastModified))", category: .core)
                } catch {
                    Logger.error("Failed to delete blob \(blob.name): \(error.localizedDescription)", category: .core)
                }
            }
        }
        
        let sizeFormatted = ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
        Logger.info("Cleanup completed: deleted \(deletedCount) old reports, freed \(sizeFormatted)", category: .core)
    }
    
    /// Generates a download link for a specific report
    /// - Parameters:
    ///   - reportName: Name of the report file
    ///   - days: Number of days the link should remain valid
    /// - Returns: Download URL with SAS token
    /// - Throws: AzureStorageError for various failure scenarios
    func generateDownloadLink(for reportName: String, expiresIn days: Int) async throws -> URL {
        let blobName = "reports/\(reportName)"
        
        Logger.info("Generating download link for report: \(reportName), expires in \(days) days", category: .core)
        
        // First verify the blob exists
        let exists = try await blobExists(name: blobName)
        guard exists else {
            throw AzureStorageError.blobNotFound("Report not found: \(reportName)")
        }
        
        // Generate SAS URL
        let sasUrl = try generateSASUrl(for: blobName, expiresIn: days)
        
        Logger.info("Generated download link for \(reportName): expires \(DateFormatter.localizedString(from: Date().addingTimeInterval(TimeInterval(days * 24 * 60 * 60)), dateStyle: .medium, timeStyle: .short))", category: .core)
        
        return sasUrl
    }
    
    // MARK: - Core Storage Operations
    
    /// Uploads data to a specific blob
    private func uploadBlob(name: String, data: Data, contentType: String) async throws {
        let url = URL(string: "https://\(config.accountName).blob.core.windows.net/\(config.containerName)/\(name)")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.httpBody = data
        
        // Set headers
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue("\(data.count)", forHTTPHeaderField: "Content-Length")
        request.setValue("BlockBlob", forHTTPHeaderField: "x-ms-blob-type")
        request.setValue("2023-11-03", forHTTPHeaderField: "x-ms-version")
        
        // Add authentication
        try await addAuthentication(to: &request, method: "PUT", resource: "/\(config.accountName)/\(config.containerName)/\(name)")
        
        let (responseData, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AzureStorageError.invalidResponse("Invalid response type")
        }
        
        guard httpResponse.statusCode == 201 else {
            let responseBody = String(data: responseData, encoding: .utf8) ?? "No response body"
            Logger.error("Azure Storage upload failed with status \(httpResponse.statusCode), response: \(responseBody)", category: .core)
            throw AzureStorageError.uploadFailed("Upload failed with status \(httpResponse.statusCode): \(responseBody)")
        }
    }
    
    /// Lists blobs with optional prefix filtering
    func listBlobs(prefix: String? = nil) async throws -> [BlobInfo] {
        var urlComponents = URLComponents(string: "https://\(config.accountName).blob.core.windows.net/\(config.containerName)")!
        urlComponents.queryItems = [
            URLQueryItem(name: "restype", value: "container"),
            URLQueryItem(name: "comp", value: "list")
        ]
        
        if let prefix = prefix {
            urlComponents.queryItems?.append(URLQueryItem(name: "prefix", value: prefix))
        }
        
        guard let url = urlComponents.url else {
            throw AzureStorageError.invalidURL("Failed to construct list URL")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("2023-11-03", forHTTPHeaderField: "x-ms-version")
        
        Logger.debug("Azure Storage List Request - URL: \(url.absoluteString)", category: .core)
        Logger.debug("Azure Storage List Request - Container: \(config.containerName)", category: .core)
        
        // Add authentication
        let resource = "/\(config.accountName)/\(config.containerName)\ncomp:list\nrestype:container"
        Logger.debug("Azure Storage List Request - Resource string: \(resource)", category: .core)
        try await addAuthentication(to: &request, method: "GET", resource: resource)
        
        Logger.debug("Azure Storage List Request - Final URL: \(request.url?.absoluteString ?? "nil")", category: .core)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AzureStorageError.invalidResponse("Invalid response type")
        }
        
        Logger.debug("Azure Storage List Response - Status: \(httpResponse.statusCode)", category: .core)
        if httpResponse.statusCode != 200 {
            if let responseData = String(data: data, encoding: .utf8) {
                Logger.error("Azure Storage List Response - Error body: \(responseData)", category: .core)
            }
        }
        
        guard httpResponse.statusCode == 200 else {
            throw AzureStorageError.listFailed("List operation failed with status \(httpResponse.statusCode)")
        }
        
        return try parseBlobListResponse(data)
    }
    
    /// Deletes a specific blob
    private func deleteBlob(name: String) async throws {
        let url = URL(string: "https://\(config.accountName).blob.core.windows.net/\(config.containerName)/\(name)")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("2023-11-03", forHTTPHeaderField: "x-ms-version")
        
        // Add authentication
        try await addAuthentication(to: &request, method: "DELETE", resource: "/\(config.accountName)/\(config.containerName)/\(name)")
        
        let (_, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AzureStorageError.invalidResponse("Invalid response type")
        }
        
        guard httpResponse.statusCode == 202 else {
            throw AzureStorageError.deleteFailed("Delete operation failed with status \(httpResponse.statusCode)")
        }
    }
    
    /// Checks if a blob exists
    private func blobExists(name: String) async throws -> Bool {
        let url = URL(string: "https://\(config.accountName).blob.core.windows.net/\(config.containerName)/\(name)")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.setValue("2023-11-03", forHTTPHeaderField: "x-ms-version")
        
        // Add authentication
        try await addAuthentication(to: &request, method: "HEAD", resource: "/\(config.accountName)/\(config.containerName)/\(name)")
        
        let (_, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AzureStorageError.invalidResponse("Invalid response type")
        }
        
        return httpResponse.statusCode == 200
    }
    
    // MARK: - Authentication
    
    /// Adds authentication headers to the request
    private func addAuthentication(to request: inout URLRequest, method: String, resource: String) async throws {
        Logger.error("Azure Storage Auth - Using auth method: \(config.authMethod)", category: .core)
        
        switch config.authMethod {
        case .storageKey(let key):
            Logger.error("Azure Storage Auth - Using Shared Key authentication", category: .core)
            try addSharedKeyAuthentication(to: &request, method: method, resource: resource, key: key)
        case .sasToken(let token):
            Logger.error("Azure Storage Auth - Using SAS Token authentication", category: .core)
            addSASAuthentication(to: &request, token: token)
        case .azureAD(let tenantId, let clientId, let clientSecret):
            Logger.error("Azure Storage Auth - Using Azure AD authentication", category: .core)
            try await addAzureADAuthentication(to: &request, tenantId: tenantId, clientId: clientId, clientSecret: clientSecret)
        }
    }
    
    /// Adds shared key authentication (storage account key)
    private func addSharedKeyAuthentication(to request: inout URLRequest, method: String, resource: String, key: String) throws {
        let dateString = DateFormatter.httpDate.string(from: Date())
        request.setValue(dateString, forHTTPHeaderField: "x-ms-date")
        
        Logger.debug("Azure Storage Shared Key Auth - Account: \(config.accountName), Method: \(method), Resource: \(resource)", category: .core)
        Logger.debug("Azure Storage Shared Key Auth - Date: \(dateString)", category: .core)
        
        // Construct string to sign (after setting x-ms-date header)
        let stringToSign = buildStringToSign(method: method, request: request, resource: resource, date: dateString)
        Logger.debug("Azure Storage Shared Key Auth - String to sign: \(stringToSign)", category: .core)
        
        // Sign with storage key
        guard let keyData = Data(base64Encoded: key) else {
            Logger.error("Azure Storage Shared Key Auth - Invalid key format: key length \(key.count)", category: .core)
            throw AzureStorageError.authenticationError("Invalid storage key format")
        }
        
        let signature = try signString(stringToSign, with: keyData)
        let authHeader = "SharedKey \(config.accountName):\(signature)"
        Logger.debug("Azure Storage Shared Key Auth - Authorization header: \(authHeader)", category: .core)
        request.setValue(authHeader, forHTTPHeaderField: "Authorization")
    }
    
    /// Adds SAS token authentication
    private func addSASAuthentication(to request: inout URLRequest, token: String) {
        Logger.error("Azure Storage SAS Auth - Starting SAS authentication", category: .core)
        Logger.error("Azure Storage SAS Auth - Original URL: \(request.url?.absoluteString ?? "nil")", category: .core)
        
        // Don't parse and re-encode the SAS token - just append it directly to avoid double encoding
        guard let currentURL = request.url?.absoluteString else {
            Logger.error("Azure Storage SAS Auth - Invalid URL", category: .core)
            return
        }
        
        // Append SAS token parameters directly to the URL
        let separator = currentURL.contains("?") ? "&" : "?"
        let finalURL = "\(currentURL)\(separator)\(token)"
        
        Logger.error("Azure Storage SAS Auth - Final URL: \(finalURL)", category: .core)
        
        request.url = URL(string: finalURL)
        Logger.error("Azure Storage SAS Auth - Request headers: \(request.allHTTPHeaderFields ?? [:])", category: .core)
    }
    
    /// Adds Azure AD authentication (requires separate app registration)
    private func addAzureADAuthentication(to request: inout URLRequest, tenantId: String, clientId: String, clientSecret: String) async throws {
        // This would implement OAuth2 client credentials flow for Azure AD
        // For now, throw an error indicating this needs to be implemented
        throw AzureStorageError.authenticationError("Azure AD authentication not yet implemented - use storage key or SAS token")
    }
    
    // MARK: - SAS URL Generation
    
    /// Generates a SAS URL for blob access
    private func generateSASUrl(for blobName: String, expiresIn days: Int) throws -> URL {
        switch config.authMethod {
        case .storageKey(let key):
            return try generateSASUrlWithStorageKey(for: blobName, expiresIn: days, key: key)
        case .sasToken(let token):
            // For SAS token configurations, we can only return the blob URL with the existing token
            // Note: The expiration cannot be modified as we don't have the storage key
            Logger.warning("SAS token authentication: Cannot modify expiration time, using existing token expiration", category: .core)
            let baseUrl = "https://\(config.accountName).blob.core.windows.net/\(config.containerName)/\(blobName)"
            let urlWithSAS = "\(baseUrl)?\(token)"
            guard let url = URL(string: urlWithSAS) else {
                throw AzureStorageError.sasGenerationError("Failed to construct SAS URL with existing token")
            }
            return url
        case .azureAD:
            throw AzureStorageError.sasGenerationError("SAS URL generation with Azure AD authentication not implemented")
        }
    }
    
    /// Generates SAS URL using storage account key
    private func generateSASUrlWithStorageKey(for blobName: String, expiresIn days: Int, key: String) throws -> URL {
        let expiryDate = Date().addingTimeInterval(TimeInterval(days * 24 * 60 * 60))
        let expiryString = DateFormatter.sasDate.string(from: expiryDate)
        
        // Let's use the standard Service SAS format without protocol restrictions
        // Standard format: signedpermissions + "\n" + signedstart + "\n" + signedexpiry + "\n" + canonicalizedresource + "\n" + signedidentifier + "\n" + signedIP + "\n" + signedProtocol + "\n" + signedversion + "\n" + rscc + "\n" + rscd + "\n" + rsce + "\n" + rscl + "\n" + rsct
        let canonicalizedResource = "/blob/\(config.accountName)/\(config.containerName)/\(blobName)"
        let stringToSign = [
            "r",                    // signedpermissions
            "",                     // signedstart (empty)
            expiryString,          // signedexpiry  
            canonicalizedResource, // canonicalizedresource
            "",                     // signedidentifier (empty)
            "",                     // signedIP (empty)
            "",                     // signedProtocol (empty - remove https restriction)
            "2023-11-03",          // signedversion
            "",                     // rscc (empty)
            "",                     // rscd (empty)
            "",                     // rsce (empty)
            "",                     // rscl (empty)
            ""                      // rsct (empty)
        ].joined(separator: "\n")
        
        // SAS parameters - simpler set without protocol restriction
        let sasParams = [
            "sv": "2023-11-03",    // API version
            "sr": "b",             // Resource type (blob) 
            "sp": "r",             // Permissions (read)
            "se": expiryString     // Expiry time (no protocol restriction)
        ]
        
        Logger.debug("SAS String to sign: \(stringToSign.replacingOccurrences(of: "\n", with: "\\n"))", category: .core)
        
        // Sign the string
        guard let keyData = Data(base64Encoded: key) else {
            throw AzureStorageError.authenticationError("Invalid storage key format")
        }
        
        let signature = try signString(stringToSign, with: keyData)
        
        // Construct final URL with parameters in correct order
        var urlComponents = URLComponents(string: "https://\(config.accountName).blob.core.windows.net/\(config.containerName)/\(blobName)")!
        
        // Add parameters in the order: sv, sr, sp, se, sig (no protocol restriction)
        urlComponents.queryItems = [
            URLQueryItem(name: "sv", value: "2023-11-03"),
            URLQueryItem(name: "sr", value: "b"), 
            URLQueryItem(name: "sp", value: "r"),
            URLQueryItem(name: "se", value: expiryString),
            URLQueryItem(name: "sig", value: signature)
        ]
        
        guard let finalUrl = urlComponents.url else {
            throw AzureStorageError.sasGenerationError("Failed to construct SAS URL")
        }
        
        Logger.debug("Generated SAS URL: \(finalUrl.absoluteString)", category: .core)
        return finalUrl
    }
    
    // MARK: - Helper Methods
    
    /// Builds the string to sign for shared key authentication
    private func buildStringToSign(method: String, request: URLRequest, resource: String, date: String) -> String {
        let contentLength = request.value(forHTTPHeaderField: "Content-Length") ?? ""
        let contentType = request.value(forHTTPHeaderField: "Content-Type") ?? ""
        
        // Build canonicalized headers (x-ms-* headers sorted alphabetically)
        var canonicalizedHeaders: [String] = []
        
        if let headers = request.allHTTPHeaderFields {
            let xmsHeaders = headers
                .filter { $0.key.lowercased().hasPrefix("x-ms-") }
                .sorted { $0.key.lowercased() < $1.key.lowercased() }
            
            for (key, value) in xmsHeaders {
                canonicalizedHeaders.append("\(key.lowercased()):\(value)")
            }
        }
        
        let canonicalizedHeadersString = canonicalizedHeaders.joined(separator: "\n")
        
        return [
            method,
            "",                // Content-Encoding
            "",                // Content-Language
            contentLength == "0" ? "" : contentLength,  // Content-Length
            "",                // Content-MD5
            contentType,       // Content-Type
            "",                // Date
            "",                // If-Modified-Since
            "",                // If-Match
            "",                // If-None-Match
            "",                // If-Unmodified-Since
            "",                // Range
            canonicalizedHeadersString,  // Canonicalized x-ms headers
            resource           // Canonicalized resource
        ].joined(separator: "\n")
    }
    
    /// Signs a string with HMAC-SHA256
    private func signString(_ string: String, with key: Data) throws -> String {
        guard let stringData = string.data(using: .utf8) else {
            throw AzureStorageError.authenticationError("Failed to encode string for signing")
        }
        
        let signature = try HMAC.sha256(data: stringData, key: key)
        return signature.base64EncodedString()
    }
    
    /// Detects content type based on file extension
    private func detectContentType(for fileName: String) -> String {
        let ext = URL(fileURLWithPath: fileName).pathExtension.lowercased()
        
        switch ext {
        case "csv": return "text/csv"
        case "json": return "application/json"
        case "xml": return "application/xml"
        case "zip": return "application/zip"
        case "pdf": return "application/pdf"
        default: return "application/octet-stream"
        }
    }
    
    /// Parses blob list XML response
    private func parseBlobListResponse(_ data: Data) throws -> [BlobInfo] {
        // For now, return empty array - would need to implement XML parsing
        // This is a simplified implementation
        Logger.warning("Blob list parsing not fully implemented", category: .core)
        return []
    }
}

// MARK: - Named Configuration Convenience Methods

extension AzureStorageManager {
    
    /// Creates an AzureStorageManager instance using a named configuration
    /// - Parameter configName: The name of the configuration to use
    /// - Returns: AzureStorageManager instance or nil if configuration not found
    /// - Throws: ConfigurationError if configuration is invalid
    static func withNamedConfiguration(_ configName: String) throws -> AzureStorageManager {
        return try AzureStorageConfig.shared.createManager(for: configName)
    }
    
    /// Creates an AzureStorageManager instance using the default configuration
    /// - Returns: AzureStorageManager instance or throws error if not configured
    /// - Throws: ConfigurationError if default configuration is invalid
    static func withDefaultConfiguration() throws -> AzureStorageManager {
        let config = try AzureStorageConfig.shared.createStorageConfig()
        return AzureStorageManager(config: config)
    }
    
    /// Uploads a report using a named configuration
    /// - Parameters:
    ///   - configName: Named configuration to use
    ///   - fileURL: Local file URL to upload
    /// - Throws: AzureStorageError or ConfigurationError
    static func uploadReport(withConfig configName: String, fileURL: URL) async throws {
        let manager = try withNamedConfiguration(configName)
        try await manager.uploadReport(fileURL: fileURL)
    }
    
    /// Deletes old reports using a named configuration
    /// - Parameters:
    ///   - configName: Named configuration to use
    ///   - days: Delete reports older than this many days
    /// - Throws: AzureStorageError or ConfigurationError
    static func deleteOldReports(withConfig configName: String, olderThan days: Int) async throws {
        let manager = try withNamedConfiguration(configName)
        try await manager.deleteOldReports(olderThan: days)
    }
    
    /// Generates a download link using a named configuration
    /// - Parameters:
    ///   - configName: Named configuration to use
    ///   - reportName: Name of the report file
    ///   - days: Number of days the link should remain valid
    /// - Returns: Download URL
    /// - Throws: AzureStorageError or ConfigurationError
    static func generateDownloadLink(withConfig configName: String, for reportName: String, expiresIn days: Int) async throws -> URL {
        let manager = try withNamedConfiguration(configName)
        return try await manager.generateDownloadLink(for: reportName, expiresIn: days)
    }
    
    /// Lists blobs using a named configuration
    /// - Parameters:
    ///   - configName: Named configuration to use
    ///   - prefix: Optional prefix filter for blob names
    /// - Returns: Array of blob information
    /// - Throws: AzureStorageError or ConfigurationError
    static func listBlobs(withConfig configName: String, prefix: String? = nil) async throws -> [BlobInfo] {
        let manager = try withNamedConfiguration(configName)
        return try await manager.listBlobs(prefix: prefix)
    }
    
    /// Validates that a named configuration can successfully connect to Azure Storage
    /// - Parameter configName: Named configuration to test
    /// - Returns: True if connection is successful, false otherwise
    static func validateConnection(withConfig configName: String) async -> Bool {
        do {
            let manager = try withNamedConfiguration(configName)
            try await manager.testConnection()
            return true
        } catch {
            Logger.error("Named configuration '\(configName)' validation failed: \(error.localizedDescription)", category: .core)
            return false
        }
    }
    
    /// Uploads a report with automatic fallback between configurations
    /// - Parameters:
    ///   - fileURL: Local file URL to upload
    ///   - primaryConfig: Primary configuration to try first
    ///   - fallbackConfig: Fallback configuration name (optional)
    /// - Returns: Name of the configuration that successfully uploaded
    /// - Throws: AzureStorageError if all configurations fail
    static func uploadReportWithFallback(
        fileURL: URL,
        primaryConfig: String,
        fallbackConfig: String? = nil
    ) async throws -> String {
        // Try primary configuration
        do {
            try await uploadReport(withConfig: primaryConfig, fileURL: fileURL)
            Logger.info("Successfully uploaded report using primary config: \(primaryConfig)", category: .core)
            return primaryConfig
        } catch {
            Logger.warning("Primary config '\(primaryConfig)' failed, error: \(error.localizedDescription)", category: .core)
            
            // Try fallback configuration if provided
            if let fallbackConfig = fallbackConfig {
                do {
                    try await uploadReport(withConfig: fallbackConfig, fileURL: fileURL)
                    Logger.info("Successfully uploaded report using fallback config: \(fallbackConfig)", category: .core)
                    return fallbackConfig
                } catch {
                    Logger.error("Fallback config '\(fallbackConfig)' also failed: \(error.localizedDescription)", category: .core)
                    throw error
                }
            } else {
                // Try default configuration as final fallback
                do {
                    let manager = try withDefaultConfiguration()
                    try await manager.uploadReport(fileURL: fileURL)
                    Logger.info("Successfully uploaded report using default configuration", category: .core)
                    return "default"
                } catch {
                    Logger.error("Default configuration also failed: \(error.localizedDescription)", category: .core)
                    throw error
                }
            }
        }
    }
    
    /// Performs batch uploads to multiple named configurations
    /// - Parameters:
    ///   - fileURL: Local file URL to upload
    ///   - configNames: Array of configuration names to upload to
    /// - Returns: Dictionary mapping configuration names to results
    static func uploadReportToMultipleConfigs(
        fileURL: URL,
        configNames: [String]
    ) async -> [String: Result<Void, Error>] {
        var results: [String: Result<Void, Error>] = [:]
        
        await withTaskGroup(of: (String, Result<Void, Error>).self) { group in
            for configName in configNames {
                group.addTask {
                    do {
                        try await uploadReport(withConfig: configName, fileURL: fileURL)
                        return (configName, .success(()))
                    } catch {
                        return (configName, .failure(error))
                    }
                }
            }
            
            for await (configName, result) in group {
                results[configName] = result
            }
        }
        
        return results
    }
    
    /// Gets available named configuration names
    /// - Returns: Array of configuration names
    static func availableConfigurationNames() -> [String] {
        return AzureStorageConfig.shared.availableConfigurationNames
    }
    
    /// Checks if a named configuration exists and is valid
    /// - Parameter configName: Configuration name to check
    /// - Returns: True if configuration exists and is valid
    static func isConfigurationValid(_ configName: String) -> Bool {
        return AzureStorageConfig.shared.validateConfiguration(named: configName)
    }
}

// MARK: - Supporting Types

/// Information about a blob in storage
struct BlobInfo {
    let name: String
    let size: Int64?
    let lastModified: Date?
    let contentType: String?
}

/// Azure Storage specific errors
enum AzureStorageError: LocalizedError {
    case authenticationError(String)
    case fileReadError(String)
    case invalidURL(String)
    case invalidResponse(String)
    case uploadFailed(String)
    case downloadFailed(String)
    case listFailed(String)
    case deleteFailed(String)
    case blobNotFound(String)
    case sasGenerationError(String)
    
    var errorDescription: String? {
        switch self {
        case .authenticationError(let message):
            return "Authentication error: \(message)"
        case .fileReadError(let message):
            return "File read error: \(message)"
        case .invalidURL(let message):
            return "Invalid URL: \(message)"
        case .invalidResponse(let message):
            return "Invalid response: \(message)"
        case .uploadFailed(let message):
            return "Upload failed: \(message)"
        case .downloadFailed(let message):
            return "Download failed: \(message)"
        case .listFailed(let message):
            return "List operation failed: \(message)"
        case .deleteFailed(let message):
            return "Delete operation failed: \(message)"
        case .blobNotFound(let message):
            return "Blob not found: \(message)"
        case .sasGenerationError(let message):
            return "SAS generation error: \(message)"
        }
    }
}

// MARK: - Extensions

extension DateFormatter {
    static let httpDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss 'GMT'"
        formatter.timeZone = TimeZone(abbreviation: "GMT")
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
    
    static let sasDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
}

// MARK: - HMAC Helper

private struct HMAC {
    static func sha256(data: Data, key: Data) throws -> Data {
        let keyBytes = key.withUnsafeBytes { $0.bindMemory(to: UInt8.self) }
        let dataBytes = data.withUnsafeBytes { $0.bindMemory(to: UInt8.self) }
        
        var result = Data(count: Int(CC_SHA256_DIGEST_LENGTH))
        
        result.withUnsafeMutableBytes { resultBytes in
            CCHmac(CCHmacAlgorithm(kCCHmacAlgSHA256),
                   keyBytes.baseAddress, key.count,
                   dataBytes.baseAddress, data.count,
                   resultBytes.baseAddress)
        }
        
        return result
    }
}

import CommonCrypto
