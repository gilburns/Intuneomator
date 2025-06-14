//
//  EntraGraphRequests+UploadLOB.swift
//  Intuneomator
//
//  Created by Gil Burns on 5/22/25.
//

import Foundation

// MARK: - LOB Upload Extension

/// Extension for handling macOS Line of Business (LOB) application uploads to Microsoft Intune
/// Provides complete workflow for uploading LOB apps with metadata, encryption, and group assignments
extension EntraGraphRequests {
    
    // MARK: - LOB Application Upload
    // Microsoft Graph API Reference: https://learn.microsoft.com/en-us/graph/api/intune-apps-macoslobapp-create?view=graph-rest-beta
    
    /// Uploads a macOS Line of Business (LOB) application to Microsoft Intune with complete configuration
    /// Handles PKG files packaged as LOB apps with full metadata, child app definitions, and deployment settings
    /// - Parameters:
    ///   - authToken: OAuth bearer token for Microsoft Graph authentication
    ///   - app: ProcessedAppResults containing all application data and configuration
    ///   - operationId: Optional operation ID for upload progress tracking
    /// - Returns: The unique identifier of the uploaded LOB application in Intune
    /// - Throws: Upload errors, encryption errors, network errors, or API errors
    static func uploadLOBPkg(authToken: String, app: ProcessedAppResults, operationId: String? = nil) async throws -> String {
        
        // Step 1: Create LOB application metadata in Intune
        let metadataURL = URL(string: "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps")!
        var request = URLRequest(url: metadataURL)
        request.httpMethod = "POST"
        request.addValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Build comprehensive notes field with Intuneomator tracking ID
        let fullNotes: String
        if app.appNotes.isEmpty {
            fullNotes = "Intuneomator ID: \(app.appTrackingID)"
        } else {
            fullNotes = "\(app.appNotes)\n\nIntuneomator ID: \(app.appTrackingID)"
        }

        // Generate display name with architecture information for multi-arch support
        let fileName = URL(fileURLWithPath: app.appLocalURL).lastPathComponent
        let arch = ["arm64", "x86_64"].first { fileName.contains($0) }
        let displayName = "\(app.appDisplayName) \(app.appVersionActual)\(arch.map { " \($0)" } ?? "")"
        
        // Construct comprehensive LOB application metadata
        var metadata: [String: Any] = [
            "@odata.type": "#microsoft.graph.macOSLobApp",
            "displayName": displayName,
            "description": app.appDescription,
            "developer": app.appDeveloper,
            "publisher": app.appPublisherName,
            "owner": app.appOwner,
            "notes": fullNotes,
            "fileName": "\(URL(fileURLWithPath: app.appLocalURL).lastPathComponent)",
            "privacyInformationUrl": app.appPrivacyPolicyURL,
            "informationUrl": app.appInfoURL,
            "primaryBundleId": app.appBundleIdActual,
            "primaryBundleVersion": app.appVersionActual,
            "ignoreVersionDetection": app.appIgnoreVersion,
            "installAsManaged": app.appIsManaged,
            "isFeatured": app.appIsFeatured,
            "bundleId": app.appBundleIdActual,
            "buildNumber": app.appVersionActual,
            "minimumSupportedOperatingSystem": [
                "@odata.type": "#microsoft.graph.macOSMinimumOperatingSystem",
                "v10_13": app.appMinimumOS.contains("v10_13"),
                "v10_14": app.appMinimumOS.contains("v10_14"),
                "v10_15": app.appMinimumOS.contains("v10_15"),
                "v11_0": app.appMinimumOS.contains("v11_0"),
                "v12_0": app.appMinimumOS.contains("v12_0"),
                "v13_0": app.appMinimumOS.contains("v13_0"),
                "v14_0": app.appMinimumOS.contains("v14_0"),
                "v15_0": app.appMinimumOS.contains("v15_0")
            ],
            "childApps": [[
                "@odata.type": "#microsoft.graph.macOSLobChildApp",
                "bundleId": app.appBundleIdActual,
                "buildNumber": app.appVersionActual,
                "versionNumber": "0.0"
            ]]
        ]
        
        // Include application icon if available
        if FileManager.default.fileExists(atPath: app.appIconURL),
           let iconData = try? Data(contentsOf: URL(fileURLWithPath: app.appIconURL)) {
            let base64Icon = iconData.base64EncodedString()
            metadata["largeIcon"] = [
                "@odata.type": "#microsoft.graph.mimeContent",
                "type": "image/png",
                "value": base64Icon
            ]
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: metadata, options: [])
        
        // Create LOB application in Intune
        let (metadataData, metadataResponse) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = metadataResponse as? HTTPURLResponse {
            Logger.info("Metadata response status code: \(httpResponse.statusCode)", category: .core)
            if !(200...299).contains(httpResponse.statusCode) {
                let responseBody = String(data: metadataData, encoding: .utf8) ?? "<non-UTF8 data>"
                Logger.error("Error response body: \(responseBody)", category: .core)
                throw NSError(domain: "UploadLOBPkg", code: httpResponse.statusCode, userInfo: [
                    NSLocalizedDescriptionKey: "Failed to create LOB app metadata. Status: \(httpResponse.statusCode)"
                ])
            }
        }
        
        guard
            let metadataJson = try JSONSerialization.jsonObject(with: metadataData) as? [String: Any]
        else {
            throw NSError(domain: "UploadLOBPkg", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON returned from metadata request."])
        }
        
        guard let appId = metadataJson["id"] as? String else {
            throw NSError(domain: "UploadLOBPkg", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Failed to parse app ID from response: \(metadataJson)"
            ])
        }
        
        Logger.info("  ⬆️ Uploaded \(displayName) metadata. App ID: \(appId)", category: .core)
        Logger.info("  ⬆️ Uploaded \(displayName) metadata. App ID: \(appId)", category: .core)

        // Step 2: Begin file upload workflow
        do {
            // Create content version for the LOB file
            let contentURL = URL(string: "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/\(appId)/microsoft.graph.macOSLobApp/contentVersions")!
            var versionRequest = URLRequest(url: contentURL)
            versionRequest.httpMethod = "POST"
            versionRequest.addValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
            versionRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
            versionRequest.httpBody = "{}".data(using: .utf8)
            
            let (versionData, versionResponse) = try await URLSession.shared.data(for: versionRequest)
            if let httpResponse = versionResponse as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                let responseBody = String(data: versionData, encoding: .utf8) ?? "<non-UTF8 data>"
                Logger.info("Failed to create content version. Status: \(httpResponse.statusCode), Response: \(responseBody)", category: .core)
                throw NSError(domain: "UploadLOBPkg", code: httpResponse.statusCode, userInfo: [
                    NSLocalizedDescriptionKey: "Failed to create content version. Status: \(httpResponse.statusCode)",
                    "responseBody": responseBody
                ])
            }
            
            let versionJson = try JSONSerialization.jsonObject(with: versionData) as? [String: Any]
//            Logger.info("Version JSON: \(versionJson as Any)", category: .core)
            guard let versionId = versionJson?["id"] as? String else {
                throw NSError(domain: "UploadLOBPkg", code: 10, userInfo: [NSLocalizedDescriptionKey: "Failed to get version ID"])
            }
            
            // Step 3: Encrypt LOB file for secure upload
            let (encryptedData, encryptionInfo, plaintextSize) = try encryptApp(fileURL: URL(fileURLWithPath: app.appLocalURL))
            
            // Save encrypted data to temporary file for chunked upload
            let tempDir = FileManager.default.temporaryDirectory
            let encryptedFileURL = tempDir.appendingPathComponent(UUID().uuidString + ".bin")
            try encryptedData.write(to: encryptedFileURL)
            
            // Step 4: Register file with Intune (both plaintext and encrypted sizes)
            let encryptedFileSize = encryptedData.count
            let fileName = "\(URL(fileURLWithPath: app.appLocalURL).lastPathComponent)"
            let registerURL = URL(string: "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/\(appId)/microsoft.graph.macOSLobApp/contentVersions/\(versionId)/files")!
            var fileRequest = URLRequest(url: registerURL)
            fileRequest.httpMethod = "POST"
            fileRequest.addValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
            fileRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
            let contentFile: [String: Any] = [
                "name": fileName,
                "@odata.type": "#microsoft.graph.mobileAppContentFile",
                "size": Int(plaintextSize),
                "sizeEncrypted": Int(encryptedFileSize)
            ]
            fileRequest.httpBody = try JSONSerialization.data(withJSONObject: contentFile)
            
            let (fileData, fileResponse) = try await URLSession.shared.data(for: fileRequest)
            if let httpResponse = fileResponse as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                let responseBody = String(data: fileData, encoding: .utf8) ?? "<non-UTF8 data>"
                Logger.info("File registration failed. Status: \(httpResponse.statusCode), Response: \(responseBody)", category: .core)
                throw NSError(domain: "UploadLOBPkg", code: httpResponse.statusCode, userInfo: [
                    NSLocalizedDescriptionKey: "File registration failed. Status: \(httpResponse.statusCode)"
                ])
            }
            
            
            let fileJson = try JSONSerialization.jsonObject(with: fileData) as? [String: Any]
            
            guard let fileId = fileJson?["id"] as? String else {
                throw NSError(domain: "UploadLOBPkg", code: 11, userInfo: [NSLocalizedDescriptionKey: "Failed to get file ID from registration"])
            }
            
            // Step 5: Poll for Azure Storage URI (required for file upload)
            var azureStorageUri: String? = nil
            let maxRetries = 10
            var retryCount = 0
            
            while azureStorageUri == nil && retryCount < maxRetries {
                try await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                
                let fileStatusURL = URL(string: "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/\(appId)/microsoft.graph.macOSLobApp/contentVersions/\(versionId)/files/\(fileId)")!
                var statusRequest = URLRequest(url: fileStatusURL)
                statusRequest.httpMethod = "GET"
                statusRequest.addValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
                
                let (statusData, _) = try await URLSession.shared.data(for: statusRequest)
                let statusJson = try JSONSerialization.jsonObject(with: statusData) as? [String: Any]
                
                if let uri = statusJson?["azureStorageUri"] as? String, !uri.isEmpty {
                    azureStorageUri = uri
                    break
                }
                
                retryCount += 1
            }
            
            guard let uploadUrl = azureStorageUri else {
                throw NSError(domain: "UploadLOBPkg", code: 12, userInfo: [NSLocalizedDescriptionKey: "Failed to get azureStorageUri after multiple attempts"])
            }
            
            // Step 6: Upload encrypted file using chunked upload
            try await uploadFileInChunks(fileURL: encryptedFileURL, to: uploadUrl, operationId: operationId)
            
            // Clean up temporary encrypted file
            try FileManager.default.removeItem(at: encryptedFileURL)
            
            // Step 7: Commit the uploaded file with encryption information
            try await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds wait before commit
            
            Logger.info("Committing appId: \(appId)", category: .core)
            Logger.info("Committing versionId: \(versionId)", category: .core)
            Logger.info("Committing fileId: \(fileId)", category: .core)
            
            let fileCommitURL = URL(string: "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/\(appId)/microsoft.graph.macOSLobApp/contentVersions/\(versionId)/files/\(fileId)/commit")!
            
            var fileCommitRequest = URLRequest(url: fileCommitURL)
            fileCommitRequest.httpMethod = "POST"
            fileCommitRequest.addValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
            fileCommitRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let commitBody = ["fileEncryptionInfo": encryptionInfo]
            let commitData = try JSONSerialization.data(withJSONObject: commitBody)
            fileCommitRequest.httpBody = commitData
            
            let (fileCommitResponseData, fileCommitResponse) = try await URLSession.shared.data(for: fileCommitRequest)
            
            if let httpResponse = fileCommitResponse as? HTTPURLResponse, httpResponse.statusCode != 200 {
                let responseBody = String(data: fileCommitResponseData, encoding: .utf8) ?? "<non-UTF8 data>"
                Logger.info("File commit status \(httpResponse.statusCode): \(responseBody)", category: .core)
            }
            
            // Step 8: Wait for file processing completion
            try await waitForFileUpload(appId: appId, versionId: versionId, fileId: fileId, appType: "microsoft.graph.macOSLobApp", authToken: authToken)
            
            // Step 9: Update application to use the committed content version
            let updateURL = URL(string: "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/\(appId)")!
            var updateRequest = URLRequest(url: updateURL)
            updateRequest.httpMethod = "PATCH"
            updateRequest.addValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
            updateRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let patchData = try JSONSerialization.data(withJSONObject: [
                "@odata.type": "#microsoft.graph.macOSLobApp",
                "committedContentVersion": versionId
            ])
            updateRequest.httpBody = patchData
            
            let (updateResponseData, updateResponse) = try await URLSession.shared.data(for: updateRequest)
            if let httpResponse = updateResponse as? HTTPURLResponse, httpResponse.statusCode != 204 {
                let responseBody = String(data: updateResponseData, encoding: .utf8) ?? "<non-UTF8 data>"
                Logger.error("App update failed with status \(httpResponse.statusCode): \(responseBody)", category: .core)
                throw NSError(domain: "UploadLOBPkg", code: 7, userInfo: [
                    NSLocalizedDescriptionKey: "Failed to update app with committed content version. Status: \(httpResponse.statusCode)"
                ])
            }
            
            Logger.info("LOB package uploaded and committed successfully ✅", category: .core)
        }
        
        // Step 10: Assign categories for organization in Company Portal
        Logger.info("Assigning categories to Intune app...", category: .core)
        
        do {
            let entraAuthenticator = EntraAuthenticator()
            let authToken = try await entraAuthenticator.getEntraIDToken()
            
            try await assignCategoriesToIntuneApp(
                authToken: authToken,
                appID: appId,
                categories: app.appCategories
            )
        } catch {
            Logger.error("Error assigning categories: \(error.localizedDescription)", category: .core)
        }
        
        // Step 11: Assign groups for deployment targeting
        do {
            let entraAuthenticator = EntraAuthenticator()
            let authToken = try await entraAuthenticator.getEntraIDToken()
            
            try await EntraGraphRequests.assignGroupsToApp(
                authToken: authToken, 
                appId: appId, 
                appAssignments: app.appAssignments, 
                appType: "macOSLobApp", 
                installAsManaged: app.appIsManaged
            )
            
        } catch {
            throw NSError(domain: "AssignLOBPkg", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Failed to assign groups to app."
            ])
        }
        
        return appId
    }
    
}
