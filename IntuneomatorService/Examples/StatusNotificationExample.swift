//
//  StatusNotificationExample.swift
//  IntuneomatorService
//
//  Example integration of StatusNotificationManager with LabelAutomation
//

import Foundation

// MARK: - Example Integration with LabelAutomation

extension LabelAutomation {
    
    /// Example: Process a label with status notifications
    /// This shows how to integrate StatusNotificationManager into existing automation workflows
    static func processLabelWithStatusNotifications(
        labelName: String,
        guid: String,
        appDisplayName: String,
        downloadType: String,
        downloadURL: String,
        expectedTeamID: String,
        expectedBundleID: String,
        expectedVersion: String
    ) async {
        
        let operationId = "\(labelName)_\(guid)"
        let statusManager = StatusNotificationManager.shared
        
        // Start tracking the operation
        statusManager.startOperation(
            operationId: operationId,
            labelName: labelName,
            appName: appDisplayName
        )
        
        do {
            // Phase 1: Download
            statusManager.updateOperation(
                operationId: operationId,
                status: .downloading,
                phaseName: "Downloading",
                phaseDetail: "Initiating download from \(URL(string: downloadURL)?.host ?? "server")",
                overallProgress: 0.0
            )
            
            let downloadURL = try await downloadFileWithProgress(
                url: downloadURL,
                operationId: operationId,
                statusManager: statusManager
            )
            
            // Phase 2: Processing
            statusManager.updateProcessingStatus(
                operationId,
                "Extracting and validating files",
                progress: 0.0
            )
            
            let processedResult = try await processDownloadedFileWithProgress(
                downloadURL: downloadURL,
                folderName: operationId,
                downloadType: downloadType,
                fileUploadName: "\(labelName).pkg", // or .dmg
                expectedTeamID: expectedTeamID,
                expectedBundleID: expectedBundleID,
                expectedVersion: expectedVersion,
                operationId: operationId,
                statusManager: statusManager
            )
            
            // Phase 3: Upload to Intune
            statusManager.updateUploadStatus(
                operationId,
                "Preparing upload to Microsoft Intune",
                progress: 0.0
            )
            
            try await uploadToIntuneWithProgress(
                fileURL: processedResult.url,
                bundleID: processedResult.bundleID,
                version: processedResult.version,
                operationId: operationId,
                statusManager: statusManager
            )
            
            // Complete successfully
            statusManager.completeOperation(operationId: operationId)
            
        } catch {
            // Handle any errors
            statusManager.failOperation(
                operationId: operationId,
                errorMessage: error.localizedDescription
            )
            Logger.error("Label automation failed for \(labelName): \(error)", category: .automation)
        }
    }
    
    // MARK: - Helper Methods with Progress Tracking
    
    /// Downloads a file with progress updates
    private static func downloadFileWithProgress(
        url: String,
        operationId: String,
        statusManager: StatusNotificationManager
    ) async throws -> URL {
        
        guard let downloadURL = URL(string: url) else {
            throw NSError(domain: "InvalidURL", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid download URL"])
        }
        
        // Create download destination
        let tempDir = AppConstants.intuneomatorCacheFolderURL
            .appendingPathComponent(operationId)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        let destinationURL = tempDir.appendingPathComponent(downloadURL.lastPathComponent)
        
        // Configure URLSession with progress tracking
        let configuration = URLSessionConfiguration.default
        let session = URLSession(configuration: configuration)
        
        // Create download task
        return try await withCheckedThrowingContinuation { continuation in
            let task = session.downloadTask(with: downloadURL) { tempURL, response, error in
                if let error = error {
                    statusManager.failOperation(operationId: operationId, errorMessage: "Download failed: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let tempURL = tempURL else {
                    let error = NSError(domain: "DownloadError", code: 2, userInfo: [NSLocalizedDescriptionKey: "No download data received"])
                    statusManager.failOperation(operationId: operationId, errorMessage: error.localizedDescription)
                    continuation.resume(throwing: error)
                    return
                }
                
                do {
                    // Move downloaded file to final destination
                    if FileManager.default.fileExists(atPath: destinationURL.path) {
                        try FileManager.default.removeItem(at: destinationURL)
                    }
                    try FileManager.default.moveItem(at: tempURL, to: destinationURL)
                    
                    // Update progress to 100% for download phase
                    statusManager.updateDownloadStatus(operationId, "Download completed", progress: 1.0)
                    
                    continuation.resume(returning: destinationURL)
                } catch {
                    statusManager.failOperation(operationId: operationId, errorMessage: "Failed to save download: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                }
            }
            
            // Monitor download progress
            let observation = task.progress.observe(\.fractionCompleted) { progress, _ in
                let percentage = progress.fractionCompleted
                let downloadedBytes = Int64(progress.completedUnitCount)
                let totalBytes = Int64(progress.totalUnitCount)
                
                statusManager.updateDownloadProgress(
                    operationId: operationId,
                    downloadedBytes: downloadedBytes,
                    totalBytes: totalBytes,
                    downloadURL: url
                )
            }
            
            task.resume()
            
            // Clean up observation when task completes
            task.completionBlock = {
                observation.invalidate()
            }
        }
    }
    
    /// Processes downloaded file with progress updates
    private static func processDownloadedFileWithProgress(
        downloadURL: URL,
        folderName: String,
        downloadType: String,
        fileUploadName: String,
        expectedTeamID: String,
        expectedBundleID: String,
        expectedVersion: String,
        operationId: String,
        statusManager: StatusNotificationManager
    ) async throws -> (url: URL?, bundleID: String, version: String) {
        
        // Use existing processing methods but add progress updates
        switch downloadType.lowercased() {
        case "pkg":
            statusManager.updateProcessingStatus(operationId, "Validating PKG installer", progress: 0.2)
            return try await processPkgFile(
                downloadURL: downloadURL,
                folderName: folderName,
                downloadType: downloadType,
                fileUploadName: fileUploadName,
                expectedTeamID: expectedTeamID,
                expectedBundleID: expectedBundleID,
                expectedVersion: expectedVersion
            )
            
        case "pkginzip":
            statusManager.updateProcessingStatus(operationId, "Extracting ZIP archive", progress: 0.1)
            let extractedFolder = try await extractZipFile(zipURL: downloadURL)
            
            statusManager.updateProcessingStatus(operationId, "Locating PKG file", progress: 0.3)
            let pkgFiles = try findFiles(inFolder: extractedFolder, withExtension: "pkg")
            guard let pkgFile = pkgFiles.first else {
                throw NSError(domain: "ProcessingError", code: 102, userInfo: [NSLocalizedDescriptionKey: "No PKG file found in ZIP archive"])
            }
            
            statusManager.updateProcessingStatus(operationId, "Validating PKG installer", progress: 0.6)
            return try await processPkgFile(
                downloadURL: pkgFile,
                folderName: folderName,
                downloadType: "pkg",
                fileUploadName: fileUploadName,
                expectedTeamID: expectedTeamID,
                expectedBundleID: expectedBundleID,
                expectedVersion: expectedVersion
            )
            
        case "dmg", "appindmg":
            statusManager.updateProcessingStatus(operationId, "Mounting DMG file", progress: 0.2)
            let mountPoint = try await mountDMGFile(dmgURL: downloadURL)
            defer { _ = try? unmountDMG(mountPoint: mountPoint) }
            
            statusManager.updateProcessingStatus(operationId, "Finding application", progress: 0.5)
            let apps = try findFiles(inFolder: URL(fileURLWithPath: mountPoint), withExtension: "app")
            guard let appFile = apps.first else {
                throw NSError(domain: "ProcessingError", code: 103, userInfo: [NSLocalizedDescriptionKey: "No app found in DMG"])
            }
            
            statusManager.updateProcessingStatus(operationId, "Copying application", progress: 0.8)
            // Continue with app processing...
            return (nil, expectedBundleID, expectedVersion) // Placeholder
            
        default:
            throw NSError(domain: "ProcessingError", code: 124, userInfo: [NSLocalizedDescriptionKey: "Unsupported download type: \(downloadType)"])
        }
    }
    
    /// Uploads to Intune with progress updates
    private static func uploadToIntuneWithProgress(
        fileURL: URL?,
        bundleID: String,
        version: String,
        operationId: String,
        statusManager: StatusNotificationManager
    ) async throws {
        
        guard let fileURL = fileURL else {
            throw NSError(domain: "UploadError", code: 1, userInfo: [NSLocalizedDescriptionKey: "No file to upload"])
        }
        
        statusManager.updateUploadStatus(operationId, "Authenticating with Microsoft Graph", progress: 0.1)
        
        // Simulate authentication delay
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        statusManager.updateUploadStatus(operationId, "Creating app entry in Intune", progress: 0.3)
        
        // Simulate app creation
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        statusManager.updateUploadStatus(operationId, "Uploading file content", progress: 0.5)
        
        // Here you would integrate with your existing Graph API upload methods
        // and update progress based on actual upload progress
        
        // Simulate upload progress
        for i in 1...10 {
            let progress = 0.5 + (Double(i) / 10.0 * 0.4) // 50% to 90%
            statusManager.updateUploadProgress(
                operationId: operationId,
                uploadedBytes: Int64(i * 1024 * 1024), // Simulate MB uploaded
                totalBytes: Int64(10 * 1024 * 1024) // 10MB total
            )
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        }
        
        statusManager.updateUploadStatus(operationId, "Finalizing upload", progress: 0.95)
        
        // Simulate finalization
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        statusManager.updateUploadStatus(operationId, "Upload completed successfully", progress: 1.0)
    }
}

// MARK: - Usage Examples

/*
 
 // Example 1: Basic label processing with notifications
 Task {
     await LabelAutomation.processLabelWithStatusNotifications(
         labelName: "firefox",
         guid: "12345-67890-ABCDEF",
         appDisplayName: "Mozilla Firefox",
         downloadType: "dmg",
         downloadURL: "https://download.mozilla.org/firefox.dmg",
         expectedTeamID: "43AQ936H96",
         expectedBundleID: "org.mozilla.firefox",
         expectedVersion: "132.0.1"
     )
 }
 
 // Example 2: Monitor progress from another thread
 let operationId = "firefox_12345-67890-ABCDEF"
 Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
     if let progress = StatusNotificationManager.shared.getOperationProgress(operationId: operationId) {
         print("Operation: \(progress.appName)")
         print("Status: \(progress.status.description)")
         print("Phase: \(progress.currentPhase.name)")
         print("Progress: \(Int(progress.overallProgress * 100))%")
         
         if !progress.status.isActive {
             timer.invalidate()
         }
     }
 }
 
 // Example 3: Get all active operations
 let activeOps = StatusNotificationManager.shared.getAllOperations()
     .filter { $0.value.status.isActive }
 print("Currently running \(activeOps.count) operations")
 
 */