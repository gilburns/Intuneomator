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
    
    private static let apiVersion = "2023-11-03"
    
    // MARK: - Configuration
    
    /// Storage account configuration
    struct StorageConfig {
        let accountName: String
        let containerName: String
        let authMethod: AuthenticationMethod
        
        enum AuthenticationMethod {
            case storageKey(String)
            case sasToken(String)
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
        
    }
    
    // MARK: - Public API
    
    /// Uploads a report file to Azure Storage
    /// - Parameter fileURL: Local file URL to upload
    /// - Throws: AzureStorageError for various failure scenarios
    func uploadReport(fileURL: URL) async throws {
        let fileName = fileURL.lastPathComponent

        let blobName = fileName
        
        Logger.debug("Starting upload of report: \(fileName) to blob: \(blobName)", category: .reports)
        
        // Read file data
        let fileData: Data
        do {
            fileData = try Data(contentsOf: fileURL)
        } catch {
            throw AzureStorageError.fileReadError("Failed to read file at \(fileURL.path): \(error.localizedDescription)")
        }
        
        // Upload to blob storage
        try await uploadBlob(name: blobName, data: fileData, contentType: detectContentType(for: fileName))
        
        // Verify upload by checking if blob exists
        let exists = try await blobExists(name: blobName)
        Logger.debug("Upload verification: blob '\(blobName)' exists = \(exists)", category: .reports)
        
        Logger.debug("Successfully uploaded report: \(fileName) (\(ByteCountFormatter.string(fromByteCount: Int64(fileData.count), countStyle: .file)))", category: .reports)
    }
    
    /// Uploads a report file to Azure Storage with custom blob path
    /// - Parameters:
    ///   - fileURL: Local file URL to upload
    ///   - blobPath: Full blob path within the container
    /// - Throws: AzureStorageError for various failure scenarios
    func uploadReport(fileURL: URL, toBlobPath blobPath: String) async throws {
        let fileName = fileURL.lastPathComponent
        // Clean up blob path to avoid double "reports/" when container is already named "reports"
        let cleanBlobPath = sanitizeBlobPath(blobPath)
        
        Logger.debug("Starting upload of report: \(fileName) to blob: \(cleanBlobPath)", category: .reports)
        
        // Read file data
        let fileData: Data
        do {
            fileData = try Data(contentsOf: fileURL)
        } catch {
            throw AzureStorageError.fileReadError("Failed to read file at \(fileURL.path): \(error.localizedDescription)")
        }
        
        // Upload to blob storage
        try await uploadBlob(name: cleanBlobPath, data: fileData, contentType: detectContentType(for: fileName))
        
        Logger.info("Successfully uploaded report: \(fileName) (\(ByteCountFormatter.string(fromByteCount: Int64(fileData.count), countStyle: .file)))", category: .reports)
    }
    
    /// Sanitizes blob path to avoid double "reports/" prefix when container is named "reports"
    /// - Parameter blobPath: Original blob path
    /// - Returns: Sanitized blob path
    private func sanitizeBlobPath(_ blobPath: String) -> String {
        // If container name is "reports" and blob path starts with "reports/", remove the prefix
        if config.containerName.lowercased() == "reports" && blobPath.hasPrefix("reports/") {
            let sanitized = String(blobPath.dropFirst("reports/".count))
            return sanitized
        }
        return blobPath
    }
    
    /// Deletes old reports based on age
    /// - Parameter days: Delete reports older than this many days
    /// - Throws: AzureStorageError for various failure scenarios
    func deleteOldReports(olderThan days: Int) async throws {
        Logger.debug("Starting deletion of reports older than \(days) days", category: .reports)
        
        // List all blobs (no prefix needed if container is already "reports")
        let reportBlobs = try await listBlobs(prefix: nil)
        
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
                    Logger.info("🗑️ Deleted old report: \(blob.name) (modified: \(lastModified))", category: .reports)
                } catch {
                    Logger.error("Failed to delete blob \(blob.name): \(error.localizedDescription)", category: .reports)
                }
            }
        }
        
        let sizeFormatted = ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
        Logger.info("Cleanup completed: deleted \(deletedCount) old reports, freed \(sizeFormatted)", category: .reports)
    }
    
    /// Generates a download link for a specific report
    /// - Parameters:
    ///   - reportName: Name of the report file
    ///   - days: Number of days the link should remain valid
    ///   - forceDownloadFilename: Optional filename to force browser download (sets Content-Disposition via SAS)
    /// - Returns: Download URL with SAS token
    /// - Throws: AzureStorageError for various failure scenarios
    func generateDownloadLink(for reportName: String, expiresIn days: Int, forceDownloadFilename: String? = nil) async throws -> URL {
        let blobName = reportName
        Logger.debug("Generating download link for report: \(reportName), expires in \(days) days", category: .reports)

        // First verify the blob exists
        let exists = try await blobExists(name: blobName)
        guard exists else {
            throw AzureStorageError.blobNotFound("Report not found: \(reportName)")
        }

        // Infer content type from the filename if we end up forcing download
        // Infer content type for forced download: use binary for Safari
        let inferredContentType: String?
        if forceDownloadFilename != nil {
            let ext = URL(fileURLWithPath: reportName).pathExtension.lowercased()
            if ext == "csv" || ext == "json" {
                inferredContentType = "application/octet-stream"
            } else {
                inferredContentType = detectContentType(for: reportName)
            }
        } else {
            inferredContentType = nil
        }
        
        // Generate SAS URL
        let sasUrl = try generateSASUrl(for: blobName, expiresIn: days, forceDownloadFilename: forceDownloadFilename, responseContentType: inferredContentType)

        Logger.debug("Generated download link for \(reportName): expires \(DateFormatter.localizedString(from: Date().addingTimeInterval(TimeInterval(days * 24 * 60 * 60)), dateStyle: .medium, timeStyle: .short))", category: .reports)
        return sasUrl
    }
    
    // MARK: - Core Storage Operations
    
    /// Uploads data to a specific blob
    private func uploadBlob(name: String, data: Data, contentType: String) async throws {
        // URL encode the blob name to handle special characters and spaces
        guard let encodedName = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            throw AzureStorageError.invalidURL("Failed to URL encode blob name: \(name)")
        }
        
        let url = URL(string: "https://\(config.accountName).blob.core.windows.net/\(config.containerName)/\(encodedName)")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.httpBody = data
        
        let reqId = UUID().uuidString
        request.setValue(reqId, forHTTPHeaderField: "x-ms-client-request-id")

        // Set headers
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue("\(data.count)", forHTTPHeaderField: "Content-Length")
        request.setValue("BlockBlob", forHTTPHeaderField: "x-ms-blob-type")
        request.setValue(AzureStorageManager.apiVersion, forHTTPHeaderField: "x-ms-version")
        request.setValue("attachment; filename=\"\(name)\"", forHTTPHeaderField: "x-ms-blob-content-disposition")
                
        // Add authentication - use URL-encoded name for signature to match what Azure expects
        try await addAuthentication(to: &request, method: "PUT", resource: "/\(config.accountName)/\(config.containerName)/\(encodedName)")
        
        let (responseData, response): (Data, URLResponse) = try await withRetry { [self] in
            try await session.data(for: request)
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AzureStorageError.invalidResponse("Invalid response type")
        }
                
        guard httpResponse.statusCode == 201 else {
            let responseBody = String(data: responseData, encoding: .utf8) ?? "No response body"
            Logger.error("Azure Storage upload failed with status \(httpResponse.statusCode), response: \(responseBody)", category: .reports)
            throw AzureStorageError.uploadFailed("Upload failed with status \(httpResponse.statusCode): \(responseBody)")
        }
        
        // Log success with response headers
        if let etag = httpResponse.value(forHTTPHeaderField: "ETag") {
            Logger.debug("Upload successful - ETag: \(etag)", category: .reports)
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
        request.setValue(AzureStorageManager.apiVersion, forHTTPHeaderField: "x-ms-version")
        
        let reqId = UUID().uuidString
        request.setValue(reqId, forHTTPHeaderField: "x-ms-client-request-id")
        
        // Add authentication
        // For list blobs operation, the canonicalized resource includes query parameters
        let resourceComponents = ["/\(config.accountName)/\(config.containerName)"]
        
        // Add canonicalized query parameters in alphabetical order
        var queryParams: [String] = []
        queryParams.append("comp:list")
        if let prefix = prefix {
            queryParams.append("prefix:\(prefix)")
        }
        queryParams.append("restype:container")
        
        let resource = resourceComponents.joined() + "\n" + queryParams.joined(separator: "\n")
        try await addAuthentication(to: &request, method: "GET", resource: resource)
        
        let (data, response): (Data, URLResponse) = try await withRetry { [self] in
            try await session.data(for: request)
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AzureStorageError.invalidResponse("Invalid response type")
        }
        
        // HTTP status: \(httpResponse.statusCode)
        if httpResponse.statusCode != 200 {
            if let responseData = String(data: data, encoding: .utf8) {
                Logger.error("Azure Storage List Response - Error body: \(responseData)", category: .reports)
            }
        }
        
        guard httpResponse.statusCode == 200 else {
            throw AzureStorageError.listFailed("List operation failed with status \(httpResponse.statusCode)")
        }
        
        let blobs = try parseBlobListResponse(data)
        Logger.debug("Listed \(blobs.count) blobs: \(blobs.map { $0.name }.joined(separator: ", "))", category: .reports)
        return blobs
    }
    
    /// Deletes a specific blob
    private func deleteBlob(name: String) async throws {
        // URL encode the blob name to handle special characters and spaces
        guard let encodedName = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            throw AzureStorageError.invalidURL("Failed to URL encode blob name: \(name)")
        }
        
        let url = URL(string: "https://\(config.accountName).blob.core.windows.net/\(config.containerName)/\(encodedName)")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue(AzureStorageManager.apiVersion, forHTTPHeaderField: "x-ms-version")
        
        let reqId = UUID().uuidString
        request.setValue(reqId, forHTTPHeaderField: "x-ms-client-request-id")
        
        // Add authentication - use URL-encoded name for signature
        try await addAuthentication(to: &request, method: "DELETE", resource: "/\(config.accountName)/\(config.containerName)/\(encodedName)")
        
        let (_, response): (Data, URLResponse) = try await withRetry { [self] in
            try await session.data(for: request)
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AzureStorageError.invalidResponse("Invalid response type")
        }
        
        guard httpResponse.statusCode == 202 else {
            throw AzureStorageError.deleteFailed("Delete operation failed with status \(httpResponse.statusCode)")
        }
    }
    
    /// Checks if a blob exists
    private func blobExists(name: String) async throws -> Bool {
        // URL encode the blob name to handle special characters and spaces
        guard let encodedName = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            throw AzureStorageError.invalidURL("Failed to URL encode blob name: \(name)")
        }
        
        let url = URL(string: "https://\(config.accountName).blob.core.windows.net/\(config.containerName)/\(encodedName)")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.setValue(AzureStorageManager.apiVersion, forHTTPHeaderField: "x-ms-version")
        
        let reqId = UUID().uuidString
        request.setValue(reqId, forHTTPHeaderField: "x-ms-client-request-id")
        
        // Add authentication - use URL-encoded name for signature
        try await addAuthentication(to: &request, method: "HEAD", resource: "/\(config.accountName)/\(config.containerName)/\(encodedName)")
        
        let (_, response): (Data, URLResponse) = try await withRetry { [self] in
            try await session.data(for: request)
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AzureStorageError.invalidResponse("Invalid response type")
        }
        
        return httpResponse.statusCode == 200
    }
    
    // MARK: - Authentication
    
    /// Adds authentication headers to the request
    private func addAuthentication(to request: inout URLRequest, method: String, resource: String) async throws {
        switch config.authMethod {
        case .storageKey(let key):
            try addSharedKeyAuthentication(to: &request, method: method, resource: resource, key: key)
        case .sasToken(let token):
            addSASAuthentication(to: &request, token: token)
        }
    }
    
    /// Adds shared key authentication (storage account key)
    private func addSharedKeyAuthentication(to request: inout URLRequest, method: String, resource: String, key: String) throws {
        let dateString = DateFormatter.httpDate.string(from: Date())
        request.setValue(dateString, forHTTPHeaderField: "x-ms-date")

        // Construct string to sign (after setting x-ms-date header)
        let stringToSign = buildStringToSign(method: method, request: request, resource: resource, date: dateString)
        
        // Sign with storage key
        guard let keyData = Data(base64Encoded: key) else {
            Logger.error("Azure Storage Shared Key Auth - Invalid key format: key length \(key.count)", category: .reports)
            throw AzureStorageError.authenticationError("Invalid storage key format")
        }
        
        let signature = try signString(stringToSign, with: keyData)
        let authHeader = "SharedKey \(config.accountName):\(signature)"
        request.setValue(authHeader, forHTTPHeaderField: "Authorization")
    }
    
    /// Adds SAS token authentication
    private func addSASAuthentication(to request: inout URLRequest, token: String) {
        // Don't parse and re-encode the SAS token - just append it directly to avoid double encoding
        guard let currentURL = request.url?.absoluteString else {
            Logger.error("Azure Storage SAS Auth - Invalid URL", category: .reports)
            return
        }
        
        // Append SAS token parameters directly to the URL
        let separator = currentURL.contains("?") ? "&" : "?"
        let finalURL = "\(currentURL)\(separator)\(token)"
        
        request.url = URL(string: finalURL)
    }
    
    /// Adds Azure AD authentication (requires separate app registration)
    private func addAzureADAuthentication(to request: inout URLRequest, tenantId: String, clientId: String, clientSecret: String) async throws {
        // This would implement OAuth2 client credentials flow for Azure AD
        // For now, throw an error indicating this needs to be implemented
        throw AzureStorageError.authenticationError("Azure AD authentication not yet implemented - use storage key or SAS token")
    }
    
    // MARK: - SAS URL Generation
    
    /// Generates a SAS URL for blob access (optionally forcing download via Content-Disposition)
    private func generateSASUrl(for blobName: String, expiresIn days: Int, forceDownloadFilename: String? = nil, responseContentType: String? = nil) throws -> URL {

        switch config.authMethod {
        case .storageKey(let key):
            // Prepare optional response headers
            let rscd = forceDownloadFilename.map { filename in
                // Force download with a friendly filename
                return "attachment; filename=\"\(filename)\""
            }
            let rsct = responseContentType
            return try generateSASUrlWithStorageKey(for: blobName, expiresIn: days, key: key, rscd: rscd, rsct: rsct)
        case .sasToken(let token):
            if forceDownloadFilename != nil || responseContentType != nil {
                Logger.warning("SAS token authentication: cannot add rscd/rsct to an existing SAS token (they must be signed). Returning original SAS.", category: .reports)
            }
            guard let encodedBlobName = blobName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
                throw AzureStorageError.sasGenerationError("Failed to URL encode blob name for SAS URL")
            }
            let baseUrl = "https://\(config.accountName).blob.core.windows.net/\(config.containerName)/\(encodedBlobName)"
            let urlWithSAS = "\(baseUrl)?\(token)"
            guard let url = URL(string: urlWithSAS) else {
                throw AzureStorageError.sasGenerationError("Failed to construct SAS URL with existing token")
            }
            return url
        }
    }
    
    /// Generates SAS URL using storage account key
    private func generateSASUrlWithStorageKey(for blobName: String, expiresIn days: Int, key: String, rscd: String? = nil, rsct: String? = nil) throws -> URL {
        // Azure Storage Service SAS for Blob (service SAS) – sv >= 2020-12-06
        // StringToSign format (see docs):
        // sp\n st\n se\n canonicalizedresource\n si\n sip\n spr\n sv\n sr\n snapshot\n ses\n rscc\n rscd\n rsce\n rscl\n rsct
        // Optional fields that are not used must be included as empty strings, each followed by a newline.

        let sp = "r"                           // read
        let spr = "https"                      // only HTTPS

        // Times (UTC, ISO 8601, with small clock skew allowance)
        let now = Date()
        let st = DateFormatter.sasDate.string(from: now.addingTimeInterval(-300))
        let se = DateFormatter.sasDate.string(from: now.addingTimeInterval(TimeInterval(days * 24 * 60 * 60)))

        // Canonicalized resource MUST be URL-decoded and include service + account + container + blob
        // e.g. "/blob/<account>/<container>/<blob>"
        let canonicalizedResource = "/blob/\(config.accountName)/\(config.containerName)/\(blobName)"
        
        let sv = AzureStorageManager.apiVersion
        
        // Build StringToSign exactly per docs (sv >= 2020-12-06)
        let stringToSign = [
            sp,                 // signedPermissions
            st,                 // signedStart
            se,                 // signedExpiry
            canonicalizedResource, // canonicalizedResource
            "",                // signedIdentifier (si)
            "",                // signedIP (sip)
            spr,                // signedProtocol (spr)
            sv,                 // signedVersion (sv)
            "b",               // signedResource (sr)
            "",                // signedSnapshotTime
            "",                // signedEncryptionScope (ses)
            "",                // rscc
            rscd ?? "",        // rscd (Content-Disposition)
            "",                // rsce
            "",                // rscl
            rsct ?? ""          // rsct (Content-Type)
        ].joined(separator: "\n")

        // Decode the storage key and sign
        guard let keyData = Data(base64Encoded: key) else {
            throw AzureStorageError.authenticationError("Invalid storage key format")
        }
        let sigData = try HMAC.sha256(data: Data(stringToSign.utf8), key: keyData)
        let sig = sigData.base64EncodedString()

        // Build final URL with proper query encoding (sig MUST be percent-encoded: +,/= -> %2B,%2F,%3D)
        guard let encodedBlobName = blobName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            throw AzureStorageError.sasGenerationError("Failed to URL encode blob name")
        }
        let baseUrl = "https://\(config.accountName).blob.core.windows.net/\(config.containerName)/\(encodedBlobName)"

        func pctEncodeQuery(_ value: String) -> String {
            // RFC 3986 unreserved set
            var allowed = CharacterSet.alphanumerics
            allowed.insert(charactersIn: "-._~")
            return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
        }

        var queryItems: [String] = [
            "sp=\(pctEncodeQuery(sp))",
            "st=\(pctEncodeQuery(st))",
            "se=\(pctEncodeQuery(se))",
            "spr=\(pctEncodeQuery(spr))",
            "sv=\(pctEncodeQuery(sv))",
            "sr=b",
            "sig=\(pctEncodeQuery(sig))"
        ]
        if let rscd = rscd, !rscd.isEmpty { queryItems.append("rscd=\(pctEncodeQuery(rscd))") }
        if let rsct = rsct, !rsct.isEmpty { queryItems.append("rsct=\(pctEncodeQuery(rsct))") }
        let query = queryItems.joined(separator: "&")

        let finalUrlString = baseUrl + "?" + query
        guard let finalUrl = URL(string: finalUrlString) else {
            throw AzureStorageError.sasGenerationError("Failed to construct final SAS URL")
        }

        Logger.debug("Generated SAS URL: \(finalUrl.absoluteString)", category: .reports)
        return finalUrl
    }
    
    /// Direct HMAC-SHA256 implementation for SAS generation
    private func hmacSHA256(data: Data, key: Data) throws -> Data {
        var result = Data(count: Int(CC_SHA256_DIGEST_LENGTH))
        
        data.withUnsafeBytes { dataBytes in
            key.withUnsafeBytes { keyBytes in
                result.withUnsafeMutableBytes { resultBytes in
                    CCHmac(CCHmacAlgorithm(kCCHmacAlgSHA256),
                           keyBytes.baseAddress, key.count,
                           dataBytes.baseAddress, data.count,
                           resultBytes.baseAddress)
                }
            }
        }
        
        return result
    }
    
    /// Deletes a specific report file from Azure Storage
    /// - Parameter reportName: Name of the report file to delete
    /// - Throws: AzureStorageError for various failure scenarios
    func deleteReport(named reportName: String) async throws {
        let blobName = reportName
        
        Logger.info("Deleting report: \(reportName) (blob: \(blobName))", category: .reports)
        
        // First verify the blob exists
        let exists = try await blobExists(name: blobName)
        guard exists else {
            throw AzureStorageError.blobNotFound("Report not found: \(reportName)")
        }
        
        // Delete the blob
        try await deleteBlob(name: blobName)
        
        Logger.info("Successfully deleted report: \(reportName)", category: .reports)
    }
    
    /// Tests the connection to Azure Storage by listing blobs
    /// - Throws: AzureStorageError if connection fails
    func testConnection() async throws {
        Logger.info("Testing Azure Storage connection for account: \(config.accountName)", category: .reports)
        
        // Attempt to list blobs as a connection test
        _ = try await listBlobs(prefix: nil)
        
        Logger.info("Azure Storage connection test successful", category: .reports)
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
        case "txt": return "text/plain"
        default: return "application/octet-stream"
        }
    }
    
    /// Parses blob list XML response
    private func parseBlobListResponse(_ data: Data) throws -> [BlobInfo] {
        // Parsing blob list XML response
        
        let parser = BlobListXMLParser()
        let xmlParser = XMLParser(data: data)
        xmlParser.delegate = parser
        
        guard xmlParser.parse() else {
            if let error = xmlParser.parserError {
                Logger.error("Azure Storage - XML parsing failed: \(error.localizedDescription)", category: .reports)
                throw AzureStorageError.listFailed("Failed to parse blob list response: \(error.localizedDescription)")
            } else {
                Logger.error("Azure Storage - XML parsing failed with unknown error", category: .reports)
                throw AzureStorageError.listFailed("Failed to parse blob list response: Unknown parsing error")
            }
        }
        
        if let parseError = parser.parseError {
            Logger.error("Azure Storage - Blob list parsing error: \(parseError)", category: .reports)
            throw AzureStorageError.listFailed("Blob list parsing error: \(parseError)")
        }
        
        // Successfully parsed \(parser.blobs.count) blobs
        return parser.blobs
    }
    
    
    private func withRetry<T>(_ op: @escaping () async throws -> T) async throws -> T {
        var delay: UInt64 = 500_000_000 // 0.5s
        for attempt in 1...3 {
            do { return try await op() }
            catch {
                if attempt == 3 { throw error }
                let jitter = UInt64(Int.random(in: 0...200_000_000))
                try await Task.sleep(nanoseconds: delay + jitter)
                delay *= 2
            }
        }
        throw AzureStorageError.networkError("Retry failed")
    }

}



// MARK: - XML Parser for Blob List Responses

/// XML parser for Azure Storage blob list responses
private class BlobListXMLParser: NSObject, XMLParserDelegate {
    var blobs: [BlobInfo] = []
    var parseError: String?
    
    // Current parsing state
    private var currentBlobName: String?
    private var currentLastModified: Date?
    private var currentSize: Int64?
    private var currentContentType: String?
    private var currentElementContent: String = ""
    private var isInBlob = false
    private var isInProperties = false
    
    // Date formatter for Azure Storage date format
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss 'GMT'"
        formatter.timeZone = TimeZone(abbreviation: "GMT")
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElementContent = ""
        
        switch elementName {
        case "Blob":
            isInBlob = true
            // Reset current blob data
            currentBlobName = nil
            currentLastModified = nil
            currentSize = nil
            currentContentType = nil
        case "Properties":
            if isInBlob {
                isInProperties = true
            }
        default:
            break
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentElementContent += string
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let content = currentElementContent.trimmingCharacters(in: .whitespacesAndNewlines)
        
        switch elementName {
        case "Blob":
            // End of blob, create BlobInfo if we have valid data
            if let name = currentBlobName {
                let blobInfo = BlobInfo(
                    name: name,
                    size: currentSize,
                    lastModified: currentLastModified,
                    contentType: currentContentType
                )
                blobs.append(blobInfo)
            }
            isInBlob = false
            
        case "Properties":
            if isInBlob {
                isInProperties = false
            }
            
        case "Name":
            if isInBlob && !isInProperties {
                currentBlobName = content
            }
            
        case "Last-Modified":
            if isInBlob && isInProperties {
                currentLastModified = dateFormatter.date(from: content)
                if currentLastModified == nil {
                    Logger.warning("Azure Storage - Failed to parse date: \(content)", category: .reports)
                }
            }
            
        case "Content-Length":
            if isInBlob && isInProperties {
                currentSize = Int64(content)
                if currentSize == nil && !content.isEmpty {
                    Logger.warning("Azure Storage - Failed to parse content length: \(content)", category: .reports)
                }
            }
            
        case "Content-Type":
            if isInBlob && isInProperties {
                currentContentType = content.isEmpty ? nil : content
            }
            
        default:
            break
        }
        
        currentElementContent = ""
    }
    
    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        self.parseError = parseError.localizedDescription
        Logger.error("Azure Storage XML parsing error: \(parseError.localizedDescription)", category: .reports)
    }
    
    func parser(_ parser: XMLParser, validationErrorOccurred validationError: Error) {
        self.parseError = validationError.localizedDescription
        Logger.error("Azure Storage XML validation error: \(validationError.localizedDescription)", category: .reports)
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
        // Auto force download for CSV/JSON
        let ext = URL(fileURLWithPath: reportName).pathExtension.lowercased()
        let forceName = (ext == "csv" || ext == "json") ? reportName : nil
        return try await manager.generateDownloadLink(for: reportName, expiresIn: days, forceDownloadFilename: forceName)
    }
    
    /// Generates a download link using a named configuration with preference for read-only token
    /// This method prioritizes security by using the read-only SAS token when available for download links
    /// - Parameters:
    ///   - configName: Named configuration to use
    ///   - reportName: Name of the report file
    ///   - days: Number of days the link should remain valid (ignored for SAS token auth)
    /// - Returns: Download URL using read-only token when available
    /// - Throws: AzureStorageError or ConfigurationError
    static func generateSecureDownloadLink(withConfig configName: String, for reportName: String, expiresIn days: Int) async throws -> URL {
        // Get the full named configuration to access read-only token
        guard let namedConfig = AzureStorageConfig.shared.getConfiguration(named: configName) else {
            throw ConfigurationError.invalidConfiguration("Configuration '\(configName)' not found")
        }
        
        // For SAS token configurations with read-only token, use the read-only token
        if case .sasToken = namedConfig.authMethod, let readOnlyToken = namedConfig.readOnlySASToken, !readOnlyToken.isEmpty {
            // Create a temporary manager config using the read-only token
            let readOnlyAuthMethod = StorageConfig.AuthenticationMethod.sasToken(readOnlyToken)
            let readOnlyConfig = StorageConfig(
                accountName: namedConfig.accountName,
                containerName: namedConfig.containerName,
                authMethod: readOnlyAuthMethod
            )
            
            let readOnlyManager = AzureStorageManager(config: readOnlyConfig)
            let ext = URL(fileURLWithPath: reportName).pathExtension.lowercased()
            let forceName = (ext == "csv" || ext == "json") ? reportName : nil
            return try await readOnlyManager.generateDownloadLink(for: reportName, expiresIn: days, forceDownloadFilename: forceName)
        }
        
        // Fallback to regular method if no read-only token available
        let ext = URL(fileURLWithPath: reportName).pathExtension.lowercased()
        let forceName = (ext == "csv" || ext == "json") ? reportName : nil
        let manager = try withNamedConfiguration(configName)
        return try await manager.generateDownloadLink(for: reportName, expiresIn: days, forceDownloadFilename: forceName)
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
            Logger.error("Named configuration '\(configName)' validation failed: \(error.localizedDescription)", category: .reports)
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
            Logger.info("Successfully uploaded report using primary config: \(primaryConfig)", category: .reports)
            return primaryConfig
        } catch {
            Logger.warning("Primary config '\(primaryConfig)' failed, error: \(error.localizedDescription)", category: .reports)
            
            // Try fallback configuration if provided
            if let fallbackConfig = fallbackConfig {
                do {
                    try await uploadReport(withConfig: fallbackConfig, fileURL: fileURL)
                    Logger.info("Successfully uploaded report using fallback config: \(fallbackConfig)", category: .reports)
                    return fallbackConfig
                } catch {
                    Logger.error("Fallback config '\(fallbackConfig)' also failed: \(error.localizedDescription)", category: .reports)
                    throw error
                }
            } else {
                // Try default configuration as final fallback
                do {
                    let manager = try withDefaultConfiguration()
                    try await manager.uploadReport(fileURL: fileURL)
                    Logger.info("Successfully uploaded report using default configuration", category: .reports)
                    return "default"
                } catch {
                    Logger.error("Default configuration also failed: \(error.localizedDescription)", category: .reports)
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
    case networkError(String)
    
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
        case .networkError(let message):
            return "Network error: \(message)"
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
    
