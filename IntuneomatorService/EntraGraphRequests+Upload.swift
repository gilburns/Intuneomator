//
//  EntraGraphRequests+UploadMethods.swift
//  Intuneomator
//
//  Created by Gil Burns on 5/22/25.
//

import Foundation
import CommonCrypto

extension EntraGraphRequests {
    
    static let logType = "EntraGraphRequests"
    
    // MARK: - Intune Upload Functions
    static func uploadAppToIntune(authToken: String, app: ProcessedAppResults) async throws {
        
        Logger.log("🖥️  Uploading app to Intune...", logType: logType)
        
        if app.appDeploymentType == 2 {
            Logger.log("Deplying LOB app...", logType: logType)
            try await uploadLOBPkg(authToken: authToken, app: app)
        } else if app.appDeploymentType == 1 {
            Logger.log("Deplying PKG app...", logType: logType)
            try await uploadPKGWithScripts(authToken: authToken, app: app)
        } else if app.appDeploymentType == 0 {
            Logger.log("Deplying DMG app...", logType: logType)
            try await uploadDMGApp(authToken: authToken, app: app)
        } else {
            throw NSError(domain: "UnsupportedFileType", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unsupported file type for upload."])
        }
    }
    
    
    // MARK: - LOB
    // https://learn.microsoft.com/en-us/graph/api/intune-apps-macoslobapp-create?view=graph-rest-beta
    
    static func uploadLOBPkg(authToken: String, app: ProcessedAppResults) async throws {
        
        // Create the metadata payload
        let metadataURL = URL(string: "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps")!
        var request = URLRequest(url: metadataURL)
        request.httpMethod = "POST"
        request.addValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Build the notes field
        let fullNotes: String
        if app.appNotes.isEmpty {
            fullNotes = "Intuneomator ID: \(app.appTrackingID)"
        } else {
            fullNotes = "\(app.appNotes)\n\nIntuneomator ID: \(app.appTrackingID)"
        }

        // Determine architecture suffix for displayName
        let fileName = URL(fileURLWithPath: app.appLocalURL).lastPathComponent
        let arch = ["arm64", "x86_64"].first { fileName.contains($0) }
        let displayName = "\(app.appDisplayName) \(app.appVersionActual)\(arch.map { " \($0)" } ?? "")"
        
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
        
        // Add icon if valid
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
        
        let (metadataData, metadataResponse) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = metadataResponse as? HTTPURLResponse {
            Logger.log("Metadata response status code: \(httpResponse.statusCode)", logType: logType)
            if !(200...299).contains(httpResponse.statusCode) {
                let responseBody = String(data: metadataData, encoding: .utf8) ?? "<non-UTF8 data>"
                Logger.log("Error response body: \(responseBody)", logType: logType)
                throw NSError(domain: "UploadLOBPkg", code: httpResponse.statusCode, userInfo: [
                    NSLocalizedDescriptionKey: "Failed to create app metadata. Status: \(httpResponse.statusCode)"
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
        
        Logger.log("Uploaded \(displayName) metadata. App ID: \(appId)", logType: logType)
        Logger.log("Uploaded \(displayName) metadata. App ID: \(appId)", logType: "Automation")

        // Start upload session
        do {
            // Create content version
            let contentURL = URL(string: "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/\(appId)/microsoft.graph.macOSLobApp/contentVersions")!
            var versionRequest = URLRequest(url: contentURL)
            versionRequest.httpMethod = "POST"
            versionRequest.addValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
            versionRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
            versionRequest.httpBody = "{}".data(using: .utf8)
            
            let (versionData, versionResponse) = try await URLSession.shared.data(for: versionRequest)
            if let httpResponse = versionResponse as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                let responseBody = String(data: versionData, encoding: .utf8) ?? "<non-UTF8 data>"
                Logger.log("Failed to create content version. Status: \(httpResponse.statusCode), Response: \(responseBody)", logType: logType)
                throw NSError(domain: "UploadLOBPkg", code: httpResponse.statusCode, userInfo: [
                    NSLocalizedDescriptionKey: "Failed to create content version. Status: \(httpResponse.statusCode)",
                    "responseBody": responseBody
                ])
            }
            
            let versionJson = try JSONSerialization.jsonObject(with: versionData) as? [String: Any]
//            Logger.log("Version JSON: \(versionJson as Any)", logType: logType)
            guard let versionId = versionJson?["id"] as? String else {
                throw NSError(domain: "UploadLOBPkg", code: 10, userInfo: [NSLocalizedDescriptionKey: "Failed to get version ID"])
            }
            
            
            // Encrypt the file before registration
            let (encryptedData, encryptionInfo, plaintextSize) = try encryptApp(fileURL: URL(fileURLWithPath: app.appLocalURL))
            
            // Save the encrypted data to a temporary file
            let tempDir = FileManager.default.temporaryDirectory
            let encryptedFileURL = tempDir.appendingPathComponent(UUID().uuidString + ".bin")
            try encryptedData.write(to: encryptedFileURL)
            
            
            // Register file
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
                Logger.log("File registration failed. Status: \(httpResponse.statusCode), Response: \(responseBody)", logType: logType)
                throw NSError(domain: "UploadLOBPkg", code: httpResponse.statusCode, userInfo: [
                    NSLocalizedDescriptionKey: "File registration failed. Status: \(httpResponse.statusCode)"
                ])
            }
            
            
            let fileJson = try JSONSerialization.jsonObject(with: fileData) as? [String: Any]
//            Logger.log("File registration response: \(fileJson as Any)", logType: logType)
            
            // After file registration
            guard let fileId = fileJson?["id"] as? String else {
                throw NSError(domain: "UploadLOBPkg", code: 11, userInfo: [NSLocalizedDescriptionKey: "Failed to get file ID from registration"])
            }
            
            // Poll for azureStorageUri
            var azureStorageUri: String? = nil
            let maxRetries = 10
            var retryCount = 0
            
            while azureStorageUri == nil && retryCount < maxRetries {
                // Wait a bit before polling
                try await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                
                // Check file status
                let fileStatusURL = URL(string: "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/\(appId)/microsoft.graph.macOSLobApp/contentVersions/\(versionId)/files/\(fileId)")!
                var statusRequest = URLRequest(url: fileStatusURL)
                statusRequest.httpMethod = "GET"
                statusRequest.addValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
                
                let (statusData, _) = try await URLSession.shared.data(for: statusRequest)
                let statusJson = try JSONSerialization.jsonObject(with: statusData) as? [String: Any]
                
//                Logger.log("File status response: \(statusJson as Any)", logType: logType)
                
                // Check if azureStorageUri is available
                if let uri = statusJson?["azureStorageUri"] as? String, !uri.isEmpty {
                    azureStorageUri = uri
                    break
                }
                
                retryCount += 1
            }
            
            guard let uploadUrl = azureStorageUri else {
                throw NSError(domain: "UploadLOBPkg", code: 12, userInfo: [NSLocalizedDescriptionKey: "Failed to get azureStorageUri after multiple attempts"])
            }
            
            
            // Upload file in chunks
            // Upload the encrypted file
            try await uploadFileInChunks(fileURL: encryptedFileURL, to: uploadUrl)
            
            // Delete the temporary encrypted file
            try FileManager.default.removeItem(at: encryptedFileURL)
            
            // After uploading the file chunks
            // Wait a bit before attempting to commit (give Azure storage time to process)
            try await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds
            
            
            // Commit the file
            
            Logger.log("Committing appId: \(appId)", logType: logType)
            Logger.log("Committing versionId: \(versionId)", logType: logType)
            Logger.log("Committing fileId: \(fileId)", logType: logType)
            
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
                Logger.log("File commit status \(httpResponse.statusCode): \(responseBody)", logType: logType)
            }
            
            // After committing the file wait for commit to complete
            try await waitForFileUpload(appId: appId, versionId: versionId, fileId: fileId, appType: "microsoft.graph.macOSLobApp", authToken: authToken)
            
            
            // Update the app to use the new content version
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
                Logger.log("App update failed with status \(httpResponse.statusCode): \(responseBody)", logType: logType)
                throw NSError(domain: "UploadLOBPkg", code: 7, userInfo: [
                    NSLocalizedDescriptionKey: "Failed to update app with committed content version. Status: \(httpResponse.statusCode)"
                ])
            }
            
            Logger.log("LOB package uploaded and committed successfully ✅", logType: logType)
        }
        
        Logger.log("Assigning categories to Intune app...", logType: logType)
        
        // Assign the categories to the newly uploaded app
        do {
            let entraAuthenticator = EntraAuthenticator()
            let authToken = try await entraAuthenticator.getEntraIDToken()
            
            try await assignCategoriesToIntuneApp(
                authToken: authToken,
                appID: appId,
                categories: app.appCategories
            )
        } catch {
            Logger.log("Error assigning categories: \(error.localizedDescription)", logType: logType)
        }
        
        // Assign the groups to the newly uploaded app
        do {
            
            let entraAuthenticator = EntraAuthenticator()
            let authToken = try await entraAuthenticator.getEntraIDToken()
            
            // Call the assignment function
            try await EntraGraphRequests.assignGroupsToApp(authToken: authToken, appId: appId, appAssignments: app.appAssignments, appType: "macOSLobApp", installAsManaged: app.appIsManaged)
            
        } catch {
            throw NSError(domain: "AssignLOBPkg", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Failed to assign groups to app."
            ])
        }
        
//        print("LOB app uploaded and committed successfully ✅")
        
    }
    
    
    // MARK: - PKG
    // https://learn.microsoft.com/en-us/graph/api/intune-apps-macospkgapp-create?view=graph-rest-beta
    
    static func uploadPKGWithScripts(authToken: String, app: ProcessedAppResults) async throws {
        // Create the metadata payload with PKG-specific type
        let metadataURL = URL(string: "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps")!
        var request = URLRequest(url: metadataURL)
        request.httpMethod = "POST"
        request.addValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Build the notes field
        let fullNotes: String
        if app.appNotes.isEmpty {
            fullNotes = "Intuneomator ID: \(app.appTrackingID)"
        } else {
            fullNotes = "\(app.appNotes)\n\nIntuneomator ID: \(app.appTrackingID)"
        }

        // Determine architecture suffix for displayName
        let fileName = URL(fileURLWithPath: app.appLocalURL).lastPathComponent
        let arch = ["arm64", "x86_64"].first { fileName.contains($0) }
        let displayName = "\(app.appDisplayName) \(app.appVersionActual)\(arch.map { " \($0)" } ?? "")"

        var metadata: [String: Any] = [
            "@odata.type": "#microsoft.graph.macOSPkgApp",
            "displayName": displayName,
            "description": app.appDescription,
            "developer": app.appPublisherName,
            "publisher": app.appPublisherName,
            "owner": app.appOwner,
            "notes": fullNotes,
            "fileName": "\(URL(fileURLWithPath: app.appLocalURL).lastPathComponent)",
            "privacyInformationUrl": "",
            "informationUrl": app.appInfoURL,
            "primaryBundleId": app.appBundleIdActual,
            "primaryBundleVersion": app.appVersionActual,
            "ignoreVersionDetection": app.appIgnoreVersion,
            "isFeatured": app.appIsFeatured,
            "bundleId": app.appBundleIdActual,
            "buildNumber": app.appVersionActual,
            "includedApps": [[
                "@odata.type": "#microsoft.graph.macOSIncludedApp",
                "bundleId": app.appBundleIdActual,
                "bundleVersion": app.appVersionActual
            ]]
        ]
        
        // Add pre-install script if present
        let preInstall = app.appScriptPreInstall
        if !preInstall.isEmpty {
            metadata["preInstallScript"] = [
                "@odata.type": "#microsoft.graph.macOSAppScript",
                "scriptContent": Data(preInstall.utf8).base64EncodedString()
            ]
        }
        
        // Add post-install script if present
        let postInstall = app.appScriptPostInstall
        if !postInstall.isEmpty {
            metadata["postInstallScript"] = [
                "@odata.type": "#microsoft.graph.macOSAppScript",
                "scriptContent": Data(postInstall.utf8).base64EncodedString()
            ]
        }
        
        // Add min OS requirement
        metadata["minimumSupportedOperatingSystem"] = [
            "@odata.type": "#microsoft.graph.macOSMinimumOperatingSystem",
            "v10_13": app.appMinimumOS.contains("v10_13"),
            "v10_14": app.appMinimumOS.contains("v10_14"),
            "v10_15": app.appMinimumOS.contains("v10_15"),
            "v11_0": app.appMinimumOS.contains("v11_0"),
            "v12_0": app.appMinimumOS.contains("v12_0"),
            "v13_0": app.appMinimumOS.contains("v13_0"),
            "v14_0": app.appMinimumOS.contains("v14_0"),
            "v15_0": app.appMinimumOS.contains("v15_0")
        ]
        
        // Add icon if available
        if FileManager.default.fileExists(atPath: app.appIconURL),
           let iconData = try? Data(contentsOf: URL(fileURLWithPath: app.appIconURL)) {
            metadata["largeIcon"] = [
                "@odata.type": "#microsoft.graph.mimeContent",
                "type": "image/png",
                "value": iconData.base64EncodedString()
            ]
        }
        
        
        request.httpBody = try JSONSerialization.data(withJSONObject: metadata, options: [])
        
        let (metadataData, metadataResponse) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = metadataResponse as? HTTPURLResponse {
            Logger.log("Metadata response status code: \(httpResponse.statusCode)", logType: logType)
            if !(200...299).contains(httpResponse.statusCode) {
                let responseBody = String(data: metadataData, encoding: .utf8) ?? "<non-UTF8 data>"
                Logger.log("Error response body: \(responseBody)", logType: logType)
                throw NSError(domain: "UploadPKGWithScripts", code: httpResponse.statusCode, userInfo: [
                    NSLocalizedDescriptionKey: "Failed to create PKG app metadata. Status: \(httpResponse.statusCode)"
                ])
            }
        }
        
        guard
            let metadataJson = try JSONSerialization.jsonObject(with: metadataData) as? [String: Any]
        else {
            throw NSError(domain: "UploadPKGWithScripts", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON returned from metadata request."])
        }
        
        guard let appId = metadataJson["id"] as? String else {
            throw NSError(domain: "UploadPKGWithScripts", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Failed to parse app ID from response: \(metadataJson)"
            ])
        }
        
        Logger.log("Uploaded \(displayName) metadata. App ID: \(appId)", logType: logType)
        Logger.log("Uploaded \(displayName) metadata. App ID: \(appId)", logType: "Automation")

        // Start upload session
        do {
            // Create content version
            let contentURL = URL(string: "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/\(appId)/microsoft.graph.macOSPkgApp/contentVersions")!
            var versionRequest = URLRequest(url: contentURL)
            versionRequest.httpMethod = "POST"
            versionRequest.addValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
            versionRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
            versionRequest.httpBody = "{}".data(using: .utf8)
            
            let (versionData, versionResponse) = try await URLSession.shared.data(for: versionRequest)
            if let httpResponse = versionResponse as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                let responseBody = String(data: versionData, encoding: .utf8) ?? "<non-UTF8 data>"
                Logger.log("Failed to create content version. Status: \(httpResponse.statusCode), Response: \(responseBody)", logType: logType)
                throw NSError(domain: "UploadPKGWithScripts", code: httpResponse.statusCode, userInfo: [
                    NSLocalizedDescriptionKey: "Failed to create content version. Status: \(httpResponse.statusCode)",
                    "responseBody": responseBody
                ])
            }
            
            let versionJson = try JSONSerialization.jsonObject(with: versionData) as? [String: Any]
//            Logger.log("Version JSON: \(versionJson as Any)", logType: logType)
            guard let versionId = versionJson?["id"] as? String else {
                throw NSError(domain: "UploadPKGWithScripts", code: 10, userInfo: [NSLocalizedDescriptionKey: "Failed to get version ID"])
            }
            
            // Encrypt the file before registration
            let (encryptedData, encryptionInfo, plaintextSize) = try encryptApp(fileURL: URL(fileURLWithPath: app.appLocalURL))
            
            // Save the encrypted data to a temporary file
            let tempDir = FileManager.default.temporaryDirectory
            let encryptedFileURL = tempDir.appendingPathComponent(UUID().uuidString + ".bin")
            try encryptedData.write(to: encryptedFileURL)
            
            // Register file with encrypted file size
            let encryptedFileSize = encryptedData.count
            let fileName = "\(URL(fileURLWithPath: app.appLocalURL).lastPathComponent)"
            let registerURL = URL(string: "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/\(appId)/microsoft.graph.macOSPkgApp/contentVersions/\(versionId)/files")!
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
                Logger.log("File registration failed. Status: \(httpResponse.statusCode), Response: \(responseBody)", logType: logType)
                throw NSError(domain: "UploadPKGWithScripts", code: httpResponse.statusCode, userInfo: [
                    NSLocalizedDescriptionKey: "File registration failed. Status: \(httpResponse.statusCode)"
                ])
            }
            
            let fileJson = try JSONSerialization.jsonObject(with: fileData) as? [String: Any]
//            Logger.log("File registration response: \(fileJson as Any)", logType: logType)
            
            guard let fileId = fileJson?["id"] as? String else {
                throw NSError(domain: "UploadPKGWithScripts", code: 11, userInfo: [NSLocalizedDescriptionKey: "Failed to get file ID from registration"])
            }
            
            // Poll for azureStorageUri
            var azureStorageUri: String? = nil
            let maxRetries = 10
            var retryCount = 0
            
            while azureStorageUri == nil && retryCount < maxRetries {
                try await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                
                let fileStatusURL = URL(string: "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/\(appId)/microsoft.graph.macOSPkgApp/contentVersions/\(versionId)/files/\(fileId)")!
                var statusRequest = URLRequest(url: fileStatusURL)
                statusRequest.httpMethod = "GET"
                statusRequest.addValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
                
                let (statusData, _) = try await URLSession.shared.data(for: statusRequest)
                let statusJson = try JSONSerialization.jsonObject(with: statusData) as? [String: Any]
                
//                Logger.log("File status response: \(statusJson as Any)", logType: logType)
                
                if let uri = statusJson?["azureStorageUri"] as? String, !uri.isEmpty {
                    azureStorageUri = uri
                    break
                }
                
                retryCount += 1
            }
            
            guard let uploadUrl = azureStorageUri else {
                throw NSError(domain: "UploadPKGWithScripts", code: 12, userInfo: [NSLocalizedDescriptionKey: "Failed to get azureStorageUri after multiple attempts"])
            }
            
            // Upload file in chunks (using the new block upload method)
            try await uploadFileInChunks(fileURL: encryptedFileURL, to: uploadUrl)
            
            // Delete the temporary encrypted file
            try FileManager.default.removeItem(at: encryptedFileURL)
            
            // Wait before committing
            try await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds
            
            // Commit the file
            Logger.log("Committing appId: \(appId)", logType: logType)
            Logger.log("Committing versionId: \(versionId)", logType: logType)
            Logger.log("Committing fileId: \(fileId)", logType: logType)
            
            let fileCommitURL = URL(string: "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/\(appId)/microsoft.graph.macOSPkgApp/contentVersions/\(versionId)/files/\(fileId)/commit")!
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
                Logger.log("File commit status \(httpResponse.statusCode): \(responseBody)", logType: logType)
            }
            
            // Wait for file upload to complete
            try await waitForFileUpload(appId: appId, versionId: versionId, fileId: fileId, appType: "microsoft.graph.macOSPkgApp", authToken: authToken)
            
            // Update the app to use the new content version
            let updateURL = URL(string: "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/\(appId)")!
            var updateRequest = URLRequest(url: updateURL)
            updateRequest.httpMethod = "PATCH"
            updateRequest.addValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
            updateRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let patchData = try JSONSerialization.data(withJSONObject: [
                "@odata.type": "#microsoft.graph.macOSPkgApp",
                "committedContentVersion": versionId
            ])
            updateRequest.httpBody = patchData
            
            let (updateResponseData, updateResponse) = try await URLSession.shared.data(for: updateRequest)
            if let httpResponse = updateResponse as? HTTPURLResponse, httpResponse.statusCode != 204 {
                let responseBody = String(data: updateResponseData, encoding: .utf8) ?? "<non-UTF8 data>"
                Logger.log("App update failed with status \(httpResponse.statusCode): \(responseBody)", logType: logType)
                throw NSError(domain: "UploadPKGWithScripts", code: 7, userInfo: [
                    NSLocalizedDescriptionKey: "Failed to update app with committed content version. Status: \(httpResponse.statusCode)"
                ])
            }
            
            Logger.log("Assigning categories to Intune app...", logType: logType)
            
            // Assign the categories to the newly uploaded app
            do {
                let entraAuthenticator = EntraAuthenticator()
                let authToken = try await entraAuthenticator.getEntraIDToken()
                
                try await assignCategoriesToIntuneApp(
                    authToken: authToken,
                    appID: appId,
                    categories: app.appCategories
                )
            } catch {
                Logger.log("Error assigning categories: \(error.localizedDescription)", logType: logType)
            }
            
            // Assign the groups to the newly uploaded app
            do {
                
                let entraAuthenticator = EntraAuthenticator()
                let authToken = try await entraAuthenticator.getEntraIDToken()
                
                // Call the assignment function
                try await EntraGraphRequests.assignGroupsToApp(authToken: authToken, appId: appId, appAssignments: app.appAssignments, appType: "macOSpkgApp", installAsManaged: app.appIsManaged)
                
            } catch {
                throw NSError(domain: "AssignLOBPkg", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: "Failed to assign groups to app."
                ])
            }
            
            
//            print("PKG with scripts uploaded and committed successfully ✅")
        }
    }
    
    // MARK: - DMG
    // https://learn.microsoft.com/en-us/graph/api/intune-apps-macosdmgapp-create?view=graph-rest-beta
    
    static func uploadDMGApp(authToken: String, app: ProcessedAppResults) async throws {
        // Create the metadata payload with DMG-specific type
        let metadataURL = URL(string: "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps")!
        var request = URLRequest(url: metadataURL)
        request.httpMethod = "POST"
        request.addValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Build the notes field
        let fullNotes: String
        if app.appNotes.isEmpty {
            fullNotes = "Intuneomator ID: \(app.appTrackingID)"
        } else {
            fullNotes = "\(app.appNotes)\n\nIntuneomator ID: \(app.appTrackingID)"
        }

        // Determine architecture suffix for displayName
        let fileName = URL(fileURLWithPath: app.appLocalURL).lastPathComponent
        let arch = ["arm64", "x86_64"].first { fileName.contains($0) }
        let displayName = "\(app.appDisplayName) \(app.appVersionActual)\(arch.map { " \($0)" } ?? "")"

        var metadata: [String: Any] = [
            "@odata.type": "#microsoft.graph.macOSDmgApp",
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
            "isFeatured": app.appIsFeatured,
            "includedApps": [[
                "@odata.type": "#microsoft.graph.macOSIncludedApp",
                "bundleId": app.appBundleIdActual,
                "bundleVersion": app.appVersionActual
            ]]
        ]
        
        // Add min OS requirement
        metadata["minimumSupportedOperatingSystem"] = [
            "@odata.type": "#microsoft.graph.macOSMinimumOperatingSystem",
            "v10_13": app.appMinimumOS.contains("v10_13"),
            "v10_14": app.appMinimumOS.contains("v10_14"),
            "v10_15": app.appMinimumOS.contains("v10_15"),
            "v11_0": app.appMinimumOS.contains("v11_0"),
            "v12_0": app.appMinimumOS.contains("v12_0"),
            "v13_0": app.appMinimumOS.contains("v13_0"),
            "v14_0": app.appMinimumOS.contains("v14_0"),
            "v15_0": app.appMinimumOS.contains("v15_0")
        ]
        
        // Add icon if available
        if FileManager.default.fileExists(atPath: app.appIconURL),
           let iconData = try? Data(contentsOf: URL(fileURLWithPath: app.appIconURL)) {
            metadata["largeIcon"] = [
                "@odata.type": "#microsoft.graph.mimeContent",
                "type": "image/png",
                "value": iconData.base64EncodedString()
            ]
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: metadata, options: [])
        
        let (metadataData, metadataResponse) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = metadataResponse as? HTTPURLResponse {
            Logger.log("Metadata response status code: \(httpResponse.statusCode)", logType: logType)
            if !(200...299).contains(httpResponse.statusCode) {
                let responseBody = String(data: metadataData, encoding: .utf8) ?? "<non-UTF8 data>"
                Logger.log("Error response body: \(responseBody)", logType: logType)
                throw NSError(domain: "UploadDMGApp", code: httpResponse.statusCode, userInfo: [
                    NSLocalizedDescriptionKey: "Failed to create DMG app metadata. Status: \(httpResponse.statusCode)"
                ])
            }
        }
        
        guard
            let metadataJson = try JSONSerialization.jsonObject(with: metadataData) as? [String: Any]
        else {
            throw NSError(domain: "UploadDMGApp", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON returned from metadata request."])
        }
        
        guard let appId = metadataJson["id"] as? String else {
            throw NSError(domain: "UploadDMGApp", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Failed to parse app ID from response: \(metadataJson)"
            ])
        }
        
        Logger.log("Uploaded \(displayName) metadata. App ID: \(appId)", logType: logType)
        Logger.log("Uploaded \(displayName) metadata. App ID: \(appId)", logType: "Automation")

        // Start upload session
        do {
            // Create content version
            let contentURL = URL(string: "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/\(appId)/microsoft.graph.macOSDmgApp/contentVersions")!
            var versionRequest = URLRequest(url: contentURL)
            versionRequest.httpMethod = "POST"
            versionRequest.addValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
            versionRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
            versionRequest.httpBody = "{}".data(using: .utf8)
            
            let (versionData, versionResponse) = try await URLSession.shared.data(for: versionRequest)
            if let httpResponse = versionResponse as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                let responseBody = String(data: versionData, encoding: .utf8) ?? "<non-UTF8 data>"
                Logger.log("Failed to create content version. Status: \(httpResponse.statusCode), Response: \(responseBody)", logType: logType)
                throw NSError(domain: "UploadDMGApp", code: httpResponse.statusCode, userInfo: [
                    NSLocalizedDescriptionKey: "Failed to create content version. Status: \(httpResponse.statusCode)",
                    "responseBody": responseBody
                ])
            }
            
            let versionJson = try JSONSerialization.jsonObject(with: versionData) as? [String: Any]
//            Logger.log("Version JSON: \(versionJson as Any)", logType: logType)
            guard let versionId = versionJson?["id"] as? String else {
                throw NSError(domain: "UploadDMGApp", code: 10, userInfo: [NSLocalizedDescriptionKey: "Failed to get version ID"])
            }
            
            // Encrypt the file before registration
            let (encryptedData, encryptionInfo, plaintextSize) = try encryptApp(fileURL: URL(fileURLWithPath: app.appLocalURL))
            
            // Save the encrypted data to a temporary file
            let tempDir = FileManager.default.temporaryDirectory
            let encryptedFileURL = tempDir.appendingPathComponent(UUID().uuidString + ".bin")
            try encryptedData.write(to: encryptedFileURL)
            
            // Register file with encrypted file size
            let encryptedFileSize = encryptedData.count
            let fileName = "\(URL(fileURLWithPath: app.appLocalURL).lastPathComponent)"
            let registerURL = URL(string: "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/\(appId)/microsoft.graph.macOSDmgApp/contentVersions/\(versionId)/files")!
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
                Logger.log("File registration failed. Status: \(httpResponse.statusCode), Response: \(responseBody)", logType: logType)
                throw NSError(domain: "UploadDMGApp", code: httpResponse.statusCode, userInfo: [
                    NSLocalizedDescriptionKey: "File registration failed. Status: \(httpResponse.statusCode)"
                ])
            }
            
            let fileJson = try JSONSerialization.jsonObject(with: fileData) as? [String: Any]
//            Logger.log("File registration response: \(fileJson as Any)", logType: logType)
            
            guard let fileId = fileJson?["id"] as? String else {
                throw NSError(domain: "UploadDMGApp", code: 11, userInfo: [NSLocalizedDescriptionKey: "Failed to get file ID from registration"])
            }
            
            // Poll for azureStorageUri
            var azureStorageUri: String? = nil
            let maxRetries = 10
            var retryCount = 0
            
            while azureStorageUri == nil && retryCount < maxRetries {
                try await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                
                let fileStatusURL = URL(string: "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/\(appId)/microsoft.graph.macOSDmgApp/contentVersions/\(versionId)/files/\(fileId)")!
                var statusRequest = URLRequest(url: fileStatusURL)
                statusRequest.httpMethod = "GET"
                statusRequest.addValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
                
                let (statusData, _) = try await URLSession.shared.data(for: statusRequest)
                let statusJson = try JSONSerialization.jsonObject(with: statusData) as? [String: Any]
                
//                Logger.log("File status response: \(statusJson as Any)", logType: logType)
                
                if let uri = statusJson?["azureStorageUri"] as? String, !uri.isEmpty {
                    azureStorageUri = uri
                    break
                }
                
                retryCount += 1
            }
            
            guard let uploadUrl = azureStorageUri else {
                throw NSError(domain: "UploadDMGApp", code: 12, userInfo: [NSLocalizedDescriptionKey: "Failed to get azureStorageUri after multiple attempts"])
            }
            
            // Upload file in chunks (using the new block upload method)
            try await uploadFileInChunks(fileURL: encryptedFileURL, to: uploadUrl)
            
            // Delete the temporary encrypted file
            try FileManager.default.removeItem(at: encryptedFileURL)
            
            // Wait before committing
            try await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds
            
            // Commit the file
            Logger.log("Committing appId: \(appId)", logType: logType)
            Logger.log("Committing versionId: \(versionId)", logType: logType)
            Logger.log("Committing fileId: \(fileId)", logType: logType)
            
            let fileCommitURL = URL(string: "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/\(appId)/microsoft.graph.macOSDmgApp/contentVersions/\(versionId)/files/\(fileId)/commit")!
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
                Logger.log("File commit status \(httpResponse.statusCode): \(responseBody)", logType: logType)
            }
            
            // Wait for file upload to complete
            try await waitForFileUpload(appId: appId, versionId: versionId, fileId: fileId, appType: "microsoft.graph.macOSDmgApp", authToken: authToken)
            
            // Update the app to use the new content version
            let updateURL = URL(string: "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/\(appId)")!
            var updateRequest = URLRequest(url: updateURL)
            updateRequest.httpMethod = "PATCH"
            updateRequest.addValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
            updateRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let patchData = try JSONSerialization.data(withJSONObject: [
                "@odata.type": "#microsoft.graph.macOSDmgApp",
                "committedContentVersion": versionId
            ])
            updateRequest.httpBody = patchData
            
            let (updateResponseData, updateResponse) = try await URLSession.shared.data(for: updateRequest)
            if let httpResponse = updateResponse as? HTTPURLResponse, httpResponse.statusCode != 204 {
                let responseBody = String(data: updateResponseData, encoding: .utf8) ?? "<non-UTF8 data>"
                Logger.log("App update failed with status \(httpResponse.statusCode): \(responseBody)", logType: logType)
                throw NSError(domain: "UploadDMGApp", code: 7, userInfo: [
                    NSLocalizedDescriptionKey: "Failed to update app with committed content version. Status: \(httpResponse.statusCode)"
                ])
            }
            
            Logger.log("Assigning categories to Intune app...", logType: logType)
            
            // Assign the categories to the newly uploaded app
            do {
                let entraAuthenticator = EntraAuthenticator()
                let authToken = try await entraAuthenticator.getEntraIDToken()
                
                try await assignCategoriesToIntuneApp(
                    authToken: authToken,
                    appID: appId,
                    categories: app.appCategories
                )
            } catch {
                Logger.log("Error assigning categories: \(error.localizedDescription)", logType: logType)
            }
            
            // Assign the groups to the newly uploaded app
            do {
                
                let entraAuthenticator = EntraAuthenticator()
                let authToken = try await entraAuthenticator.getEntraIDToken()
                
                // Call the assignment function
                try await EntraGraphRequests.assignGroupsToApp(authToken: authToken, appId: appId, appAssignments: app.appAssignments, appType: "macOSDmgApp", installAsManaged: app.appIsManaged)
                
            } catch {
                throw NSError(domain: "AssignLOBPkg", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: "Failed to assign groups to app."
                ])
            }
            
//            print("DMG app uploaded and committed successfully ✅")
        }
    }
    
    
    // MARK: - File Chunk Upload
    // File Chunk Upload - used by LOB, PKG, DMG
    private static func uploadFileInChunks(fileURL: URL, to uploadURL: String, chunkSize: Int = 6 * 1024 * 1024) async throws {
        // Get file size using FileManager
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
        
        // Upload file in blocks
        while offset < fileSize {
            // Read the next chunk
            try fileHandle.seek(toOffset: UInt64(offset))
            let chunkData = fileHandle.readData(ofLength: min(chunkSize, fileSize - offset))

            if chunkData.isEmpty {
                break
            }

            // Generate block ID
            let blockIdString = String(format: "block-%04d", blockIndex)
            let blockId = Data(blockIdString.utf8).base64EncodedString()
            blockIds.append(blockId)

            // Create URL for this block
            let blockURL = URL(string: "\(baseUploadURLString)&comp=block&blockid=\(blockId)")!

            // Create request
            var blockRequest = URLRequest(url: blockURL)
            blockRequest.httpMethod = "PUT"
            blockRequest.addValue("BlockBlob", forHTTPHeaderField: "x-ms-blob-type")
            blockRequest.httpBody = chunkData

            // Upload block with retry
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
                        // Exponential backoff before retrying
                        Logger.log("Throughput throttled, retrying block upload in \(0.5 * Double(attempt)) seconds...", logType: logType)
                        try await Task.sleep(nanoseconds: UInt64(0.5 * Double(attempt) * 1_000_000_000))
                        continue
                    }
                }
            }
            if let error = lastError {
                throw NSError(domain: "IntuneUploadError", code: -1, userInfo: [NSLocalizedDescriptionKey : error.localizedDescription])
            }
            
            
            Logger.log("Uploaded block \(blockIndex): \(chunkData.count / 1024) KB", logType: logType)
            
            blockIndex += 1
            offset += chunkData.count
        }
        
        // After all blocks are uploaded, create and upload the block list XML
        var blockListXML = "<BlockList>"
        for id in blockIds {
            blockListXML += "<Latest>\(id)</Latest>"
        }
        blockListXML += "</BlockList>"
        
        let blockListData = blockListXML.data(using: .utf8)!
        
        // Create URL for the block list
        let blockListURL = URL(string: "\(baseUploadURLString)&comp=blocklist")!
        
        // Create request for block list
        var blockListRequest = URLRequest(url: blockListURL)
        blockListRequest.httpMethod = "PUT"
        blockListRequest.addValue("application/xml", forHTTPHeaderField: "Content-Type")
        blockListRequest.httpBody = blockListData
        
        Logger.log("Block list upload started...", logType: logType)

        // Upload block list
        let (blockListResponseData, blockListResponse) = try await URLSession.shared.data(for: blockListRequest)
        
        
        guard let blockListHTTPResponse = blockListResponse as? HTTPURLResponse, blockListHTTPResponse.statusCode == 201 else {
            let responseString = String(data: blockListResponseData, encoding: .utf8) ?? "<non-UTF8 data>"
            Logger.log("Block list upload failed: \(responseString)", logType: logType)
            throw NSError(domain: "UploadLOBPkg", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "Failed to upload block list XML"
            ])
        }
        Logger.log("Block list upload complete ✅", logType: logType)
        
        Logger.log("File upload complete ✅", logType: logType)
    }
    
    
    // MARK: - Wait for Upload
    // After committing the file, poll for status until completed or failed
    private static func waitForFileUpload(appId: String, versionId: String, fileId: String, appType: String, authToken: String) async throws {
        let maxAttempts = 20
        var attempt = 1
        
        while attempt <= maxAttempts {
            // Get the current status using the appropriate app type in the URL
            let fileStatusURL = URL(string: "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/\(appId)/\(appType)/contentVersions/\(versionId)/files/\(fileId)")!
            var statusRequest = URLRequest(url: fileStatusURL)
            statusRequest.httpMethod = "GET"
            statusRequest.addValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
            
            let (statusData, _) = try await URLSession.shared.data(for: statusRequest)
            
            if let statusJson = try JSONSerialization.jsonObject(with: statusData) as? [String: Any] {
//                Logger.log("Full file status response: \(statusJson)", logType: logType)
                
                if let uploadState = statusJson["uploadState"] as? String {
                    Logger.log("File upload state: \(uploadState)", logType: logType)
                    
                    // Check for success state
                    if uploadState == "commitFileSuccess" {
                        Logger.log("File upload successfully committed ✅", logType: logType)
                        return
                    }
                    
                    // Check for failure state
                    if uploadState == "commitFileFailed" {
                        // Get more error details if available
                        if let errorCode = statusJson["errorCode"] as? String {
                            Logger.log("Error code: \(errorCode)", logType: logType)
                        }
                        if let errorDescription = statusJson["errorDescription"] as? String {
                            Logger.log("Error description: \(errorDescription)", logType: logType)
                        }
                        
                        throw NSError(domain: "UploadApp", code: 6, userInfo: [
                            NSLocalizedDescriptionKey: "Failed to commit file. Upload state: commitFileFailed"
                        ])
                    }
                }
            }
            
            // Wait 5 seconds between attempts
            try await Task.sleep(nanoseconds: 5_000_000_000)
            attempt += 1
        }
        
        // If we get here, we've timed out
        throw NSError(domain: "UploadApp", code: 7, userInfo: [
            NSLocalizedDescriptionKey: "Timed out waiting for file upload to complete after \(maxAttempts) attempts"
        ])
    }

    // MARK: - Encryption Functions
    // Helper function to encrypt the app file
    private static func encryptApp(fileURL: URL) throws -> (encryptedData: Data, encryptionInfo: [String: Any], plaintextSize: Int) {
        
        // Read the file data
        let fileData = try Data(contentsOf: fileURL)
        let plaintextSize = fileData.count
        
        
        
        // Generate random keys and IV
        var encryptionKey = Data(count: 32)  // 256 bits
        var hmacKey = Data(count: 32)        // 256 bits
        var initializationVector = Data(count: 16)  // 128 bits
        
        _ = encryptionKey.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 32, $0.baseAddress!) }
        _ = hmacKey.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 32, $0.baseAddress!) }
        _ = initializationVector.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 16, $0.baseAddress!) }
        
        
        // Encrypt the file using AES-256 in CBC mode with PKCS7 padding
        let encryptedData = try encryptAES256(data: fileData, key: encryptionKey, iv: initializationVector)
        
        
        // Step 1: Combine the IV and encrypted data into a single byte string
        let ivData = initializationVector + encryptedData
        
        // Step 2: Generate a HMAC-SHA256 signature of the IV and encrypted data
        let signature = hmacSHA256(data: ivData, key: hmacKey)
        
        // Step 3: Combine the signature and IV + encrypted data into a single byte string
        let encryptedPackage = signature + ivData
        
        // Step 4: Create the file digest (SHA-256 of the original file)
        let fileDigest = fileData.sha256() ?? Data()
        
        // Step 5: Create the file encryption info dictionary
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
    
    // Helper function for AES-256 CBC encryption with PKCS7 padding
    private static func encryptAES256(data: Data, key: Data, iv: Data) throws -> Data {
        // Create a buffer large enough to hold the encrypted data
        // AES encryption in CBC mode with PKCS7 padding might increase the size up to one block
        let bufferSize = data.count + kCCBlockSizeAES128
        var encryptedBytes = [UInt8](repeating: 0, count: bufferSize)
        var numBytesEncrypted = 0
        
        // Perform encryption
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
        
        // Return only the bytes that were actually encrypted
        return Data(encryptedBytes.prefix(numBytesEncrypted))
    }
    
    
    // Helper function for HMAC-SHA256
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
