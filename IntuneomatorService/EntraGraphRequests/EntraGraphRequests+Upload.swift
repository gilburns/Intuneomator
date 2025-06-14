//
//  EntraGraphRequests+UploadMethods.swift
//  Intuneomator
//
//  Created by Gil Burns on 5/22/25.
//

import Foundation
import CommonCrypto

// MARK: - Upload Operations Extension

/// Extension for handling Microsoft Graph API upload operations
/// Provides functionality for uploading applications to Intune with encryption and chunked transfer
extension EntraGraphRequests {
        
    // MARK: - Main Upload Orchestration
    
    /// Uploads an application to Intune based on deployment type
    /// Routes to appropriate upload method based on app configuration (DMG, PKG, or LOB)
    /// - Parameters:
    ///   - authToken: OAuth bearer token for Microsoft Graph authentication
    ///   - app: ProcessedAppResults containing application data and configuration
    ///   - operationId: Optional operation ID for upload progress tracking
    /// - Returns: The unique identifier of the uploaded application in Intune
    /// - Throws: Upload errors, authentication errors, or unsupported file type errors
    static func uploadAppToIntune(authToken: String, app: ProcessedAppResults, operationId: String? = nil) async throws -> String {
        Logger.info("🖥️  Uploading app to Intune...", category: .core)
        let uploadedAppID: String
        
        // Route to appropriate upload method based on deployment type
        if app.appDeploymentType == 2 {
            Logger.info("Deploying LOB app...", category: .core)
            uploadedAppID = try await uploadLOBPkg(authToken: authToken, app: app, operationId: operationId)
        } else if app.appDeploymentType == 1 {
            Logger.info("Deploying PKG app...", category: .core)
            uploadedAppID = try await uploadPKGWithScripts(authToken: authToken, app: app, operationId: operationId)
        } else if app.appDeploymentType == 0 {
            Logger.info("Deploying DMG app...", category: .core)
            uploadedAppID = try await uploadDMGApp(authToken: authToken, app: app, operationId: operationId)
        } else {
            throw NSError(domain: "UnsupportedFileType", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unsupported file type for upload."])
        }
        return uploadedAppID
    }
    
    // MARK: - Chunked File Upload System
    
    /// Uploads large files to Azure Blob Storage using chunked upload with retry logic
    /// Used by all upload methods (LOB, PKG, DMG) for reliable large file transfers
    /// - Parameters:
    ///   - fileURL: Local file URL to upload
    ///   - uploadURL: Azure Blob Storage upload URL with SAS token
    ///   - chunkSize: Size of each chunk in bytes (default: 6MB)
    ///   - operationId: Optional operation ID for upload progress tracking
    /// - Throws: File I/O errors, network errors, or upload failures
    static func uploadFileInChunks(fileURL: URL, to uploadURL: String, chunkSize: Int = 6 * 1024 * 1024, operationId: String? = nil) async throws {
        // Get file size for progress tracking and chunk calculation
        let fileSize = try FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? Int ?? 0
        
        let uploadURL = URL(string: uploadURL)!
        let baseUploadURLString = uploadURL.absoluteString
        let fileHandle = try FileHandle(forReadingFrom: fileURL)
        defer {
            try? fileHandle.close()
        }
        
        var blockIds: [String] = []
        var blockIndex = 0
        var offset = 0
        
        // Initialize status manager for progress tracking
        let statusManager = StatusNotificationManager.shared
        
        // Upload file in chunks using Azure Block Blob protocol
        while offset < fileSize {
            // Read the next chunk from file
            try fileHandle.seek(toOffset: UInt64(offset))
            let chunkData = fileHandle.readData(ofLength: min(chunkSize, fileSize - offset))

            if chunkData.isEmpty {
                break
            }

            // Generate unique block ID for Azure Blob Storage
            let blockIdString = String(format: "block-%04d", blockIndex)
            let blockId = Data(blockIdString.utf8).base64EncodedString()
            blockIds.append(blockId)

            // Create URL for this specific block
            let blockURL = URL(string: "\(baseUploadURLString)&comp=block&blockid=\(blockId)")!

            // Create request for block upload
            var blockRequest = URLRequest(url: blockURL)
            blockRequest.httpMethod = "PUT"
            blockRequest.addValue("BlockBlob", forHTTPHeaderField: "x-ms-blob-type")
            blockRequest.httpBody = chunkData

            // Upload block with exponential backoff retry logic
            var lastError: Error?
            for attempt in 1...3 {
                do {
                    let (_, response) = try await URLSession.shared.data(for: blockRequest)
                    guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                        throw NSError(domain: "UploadError", code: (response as? HTTPURLResponse)?.statusCode ?? -1, userInfo: nil)
                    }
                    lastError = nil
                    break
                } catch {
                    lastError = error
                    if attempt < 3 {
                        // Exponential backoff for throughput throttling
                        Logger.info("Throughput throttled, retrying block upload in \(0.5 * Double(attempt)) seconds...", category: .core)
                        try await Task.sleep(nanoseconds: UInt64(0.5 * Double(attempt) * 1_000_000_000))
                        continue
                    }
                }
            }
            if let error = lastError {
                throw NSError(domain: "IntuneUploadError", code: -1, userInfo: [NSLocalizedDescriptionKey : error.localizedDescription])
            }
            
            Logger.info("Uploaded block \(blockIndex): \(chunkData.count / 1024) KB", category: .core)
            
            blockIndex += 1
            offset += chunkData.count
            
            // Update upload progress if operation ID is provided
            if let operationId = operationId {
                statusManager.updateUploadProgress(
                    operationId: operationId,
                    uploadedBytes: Int64(offset),
                    totalBytes: Int64(fileSize)
                )
            }
        }
        
        // Create block list XML to commit all uploaded blocks
        var blockListXML = "<BlockList>"
        for id in blockIds {
            blockListXML += "<Latest>\(id)</Latest>"
        }
        blockListXML += "</BlockList>"
        
        let blockListData = blockListXML.data(using: .utf8)!
        
        // Create URL for committing the block list
        let blockListURL = URL(string: "\(baseUploadURLString)&comp=blocklist")!
        
        // Create request for block list commit
        var blockListRequest = URLRequest(url: blockListURL)
        blockListRequest.httpMethod = "PUT"
        blockListRequest.addValue("application/xml", forHTTPHeaderField: "Content-Type")
        blockListRequest.httpBody = blockListData
        
        Logger.info("Block list upload started...", category: .core)

        // Commit all blocks as a single blob
        let (blockListResponseData, blockListResponse) = try await URLSession.shared.data(for: blockListRequest)
        
        guard let blockListHTTPResponse = blockListResponse as? HTTPURLResponse, blockListHTTPResponse.statusCode == 201 else {
            let responseString = String(data: blockListResponseData, encoding: .utf8) ?? "<non-UTF8 data>"
            Logger.error("Block list upload failed: \(responseString)", category: .core)
            throw NSError(domain: "UploadLOBPkg", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "Failed to upload block list XML"
            ])
        }
        Logger.info("Block list upload complete ✅", category: .core)
        Logger.info("File upload complete ✅", category: .core)
    }
    
    // MARK: - Upload Status Monitoring
    
    /// Polls Microsoft Graph API for file upload completion status
    /// Monitors the processing of uploaded files until success or failure
    /// - Parameters:
    ///   - appId: Intune application identifier
    ///   - versionId: Content version identifier
    ///   - fileId: File identifier within the content version
    ///   - appType: Application type for URL construction (e.g., "macOSLobApp")
    ///   - authToken: OAuth bearer token for Microsoft Graph authentication
    /// - Throws: Timeout errors, processing failures, or network errors
    static func waitForFileUpload(appId: String, versionId: String, fileId: String, appType: String, authToken: String) async throws {
        let maxAttempts = 20
        var attempt = 1
        
        while attempt <= maxAttempts {
            // Query current upload status from Microsoft Graph
            let fileStatusURL = URL(string: "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/\(appId)/\(appType)/contentVersions/\(versionId)/files/\(fileId)")!
            var statusRequest = URLRequest(url: fileStatusURL)
            statusRequest.httpMethod = "GET"
            statusRequest.addValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
            
            let (statusData, _) = try await URLSession.shared.data(for: statusRequest)
            
            if let statusJson = try JSONSerialization.jsonObject(with: statusData) as? [String: Any] {
                if let uploadState = statusJson["uploadState"] as? String {
                    Logger.info("File upload state: \(uploadState)", category: .core)
                    
                    // Check for successful completion
                    if uploadState == "commitFileSuccess" {
                        Logger.info("File upload successfully committed ✅", category: .core)
                        return
                    }
                    
                    // Check for failure and extract error details
                    if uploadState == "commitFileFailed" {
                        if let errorCode = statusJson["errorCode"] as? String {
                            Logger.error("Error code: \(errorCode)", category: .core)
                        }
                        if let errorDescription = statusJson["errorDescription"] as? String {
                            Logger.error("Error description: \(errorDescription)", category: .core)
                        }
                        
                        throw NSError(domain: "UploadApp", code: 6, userInfo: [
                            NSLocalizedDescriptionKey: "Failed to commit file. Upload state: commitFileFailed"
                        ])
                    }
                }
            }
            
            // Wait between polling attempts
            try await Task.sleep(nanoseconds: 5_000_000_000)
            attempt += 1
        }
        
        // Timeout after maximum attempts
        throw NSError(domain: "UploadApp", code: 7, userInfo: [
            NSLocalizedDescriptionKey: "Timed out waiting for file upload to complete after \(maxAttempts) attempts"
        ])
    }

    // MARK: - File Encryption System
    
    /// Encrypts application files using AES-256-CBC with HMAC-SHA256 for Intune security requirements
    /// Creates encrypted package with all necessary cryptographic information for Intune processing
    /// - Parameter fileURL: Local file URL to encrypt
    /// - Returns: Tuple containing encrypted data, encryption info dictionary, and original file size
    /// - Throws: File I/O errors, encryption errors, or cryptographic failures
    static func encryptApp(fileURL: URL) throws -> (encryptedData: Data, encryptionInfo: [String: Any], plaintextSize: Int) {
        // Read original file data
        let fileData = try Data(contentsOf: fileURL)
        let plaintextSize = fileData.count
        
        // Generate cryptographically secure random keys and initialization vector
        var encryptionKey = Data(count: 32)  // AES-256 key (256 bits)
        var hmacKey = Data(count: 32)        // HMAC-SHA256 key (256 bits)
        var initializationVector = Data(count: 16)  // AES block size (128 bits)
        
        _ = encryptionKey.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 32, $0.baseAddress!) }
        _ = hmacKey.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 32, $0.baseAddress!) }
        _ = initializationVector.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 16, $0.baseAddress!) }
        
        // Encrypt file data using AES-256-CBC with PKCS7 padding
        let encryptedData = try encryptAES256(data: fileData, key: encryptionKey, iv: initializationVector)
        
        // Construct encrypted package following Intune security protocol
        // Step 1: Combine IV and encrypted data
        let ivData = initializationVector + encryptedData
        
        // Step 2: Generate HMAC-SHA256 signature for integrity verification
        let signature = hmacSHA256(data: ivData, key: hmacKey)
        
        // Step 3: Create final encrypted package (signature + IV + encrypted data)
        let encryptedPackage = signature + ivData
        
        // Step 4: Generate SHA-256 digest of original file for validation
        let fileDigest = fileData.sha256() ?? Data()
        
        // Step 5: Create encryption info dictionary for Microsoft Graph API
        let fileEncryptionInfo: [String: Any] = [
            "@odata.type": "#microsoft.graph.fileEncryptionInfo",
            "encryptionKey": encryptionKey.base64EncodedString(),
            "macKey": hmacKey.base64EncodedString(),
            "initializationVector": initializationVector.base64EncodedString(),
            "profileIdentifier": "ProfileVersion1",
            "fileDigestAlgorithm": "SHA256",
            "fileDigest": fileDigest.base64EncodedString(),
            "mac": signature.base64EncodedString()
        ]
        
        return (encryptedPackage, fileEncryptionInfo, plaintextSize)
    }
    
    /// Performs AES-256-CBC encryption with PKCS7 padding using CommonCrypto
    /// - Parameters:
    ///   - data: Data to encrypt
    ///   - key: 256-bit encryption key
    ///   - iv: 128-bit initialization vector
    /// - Returns: Encrypted data
    /// - Throws: Encryption errors from CommonCrypto
    private static func encryptAES256(data: Data, key: Data, iv: Data) throws -> Data {
        // Allocate buffer with extra space for PKCS7 padding
        let bufferSize = data.count + kCCBlockSizeAES128
        var encryptedBytes = [UInt8](repeating: 0, count: bufferSize)
        var numBytesEncrypted = 0
        
        // Perform AES-256-CBC encryption with PKCS7 padding
        let cryptStatus = key.withUnsafeBytes { keyBytes in
            iv.withUnsafeBytes { ivBytes in
                data.withUnsafeBytes { dataBytes in
                    CCCrypt(
                        CCOperation(kCCEncrypt),
                        CCAlgorithm(kCCAlgorithmAES),
                        CCOptions(kCCOptionPKCS7Padding),
                        keyBytes.baseAddress, key.count,
                        ivBytes.baseAddress,
                        dataBytes.baseAddress, data.count,
                        &encryptedBytes, bufferSize,
                        &numBytesEncrypted
                    )
                }
            }
        }
        
        guard cryptStatus == kCCSuccess else {
            throw NSError(domain: "EncryptionError", code: Int(cryptStatus),
                          userInfo: [NSLocalizedDescriptionKey: "Encryption failed with status: \(cryptStatus)"])
        }
        
        // Return only the actual encrypted bytes
        return Data(encryptedBytes.prefix(numBytesEncrypted))
    }
    
    /// Generates HMAC-SHA256 signature for data integrity verification
    /// - Parameters:
    ///   - data: Data to sign
    ///   - key: HMAC key for signing
    /// - Returns: HMAC-SHA256 signature
    private static func hmacSHA256(data: Data, key: Data) -> Data {
        var macOut = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        
        data.withUnsafeBytes { dataBytes in
            key.withUnsafeBytes { keyBytes in
                CCHmac(
                    CCHmacAlgorithm(kCCHmacAlgSHA256),
                    keyBytes.baseAddress!, key.count,
                    dataBytes.baseAddress!, data.count,
                    &macOut
                )
            }
        }
        
        return Data(macOut)
    }
}
