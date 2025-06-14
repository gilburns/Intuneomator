//
//  LabelAutomation+ProcessHelpers.swift
//  Intuneomator
//
//  Created by Gil Burns on 5/22/25.
//

import Foundation

// MARK: - Process Helper Functions Extension

/// Extension providing utility functions for automation workflow processing
/// Handles file operations, caching, dual-architecture support, and Intune integration tracking
extension LabelAutomation {

    // MARK: - Multi-Architecture Download Operations
    
    /// Downloads application files for both ARM64/Universal and x86_64 architectures when required
    /// Supports dual-architecture deployments for comprehensive macOS hardware compatibility
    /// - Parameters:
    ///   - processed: ProcessedAppResults containing download URLs and architecture requirements
    ///   - folderName: The Installomator label name for the application
    ///   - operationId: Optional operation ID for status tracking
    /// - Returns: A tuple containing the primary (ARM64/Universal) URL and optional x86_64 URL
    /// - Throws: Download errors, network errors, or file system errors
    static func downloadArchives(
        for processed: ProcessedAppResults,
        folderName: String,
        operationId: String? = nil
    ) async throws -> (URL, URL?) {
        let primaryURL = processed.appDownloadURL
        Logger.info("  Download URL: \(primaryURL)", category: .automation)

        // Download primary architecture (Universal/ARM64) first
        let universalURL = try await downloadFile(
            for: folderName,
            processedAppResults: processed,
            operationId: operationId
        )

        // Download x86_64 architecture if dual-arch deployment is required
        let x86URL: URL?
        if processed.appDeploymentArch == 2,
           MetadataLoader.titleIsDualArch(forFolder: folderName)
        {
            Logger.info("Downloading x86 slice for dual-arch", category: .automation)
            x86URL = try await downloadFile(
                for: folderName,
                processedAppResults: processed,
                downloadArch: "x86",
                operationId: operationId
            )
        } else {
            x86URL = nil
        }

        return (universalURL, x86URL)
    }

    // MARK: - Result Application Operations
    
    /// Applies processed file information to the application results structure
    /// Updates metadata including display name, bundle ID, and version from processed file
    /// - Parameters:
    ///   - processedFile: The ProcessedFileResult containing extracted file information
    ///   - results: The ProcessedAppResults structure to update with file information
    static func apply(
        _ processedFile: ProcessedFileResult,
        to results: inout ProcessedAppResults
    ) {
        // Update local file path
        results.appLocalURL = processedFile.url.path
        
        // Update application metadata only if new values are provided
        if !processedFile.name.isEmpty {
            results.appDisplayName = processedFile.name
        }
        if !processedFile.bundleID.isEmpty {
            results.appBundleIdActual = processedFile.bundleID
        }
        if !processedFile.version.isEmpty {
            results.appVersionActual = processedFile.version
        }
    }
    
    /// Applies downloaded file URLs to the application results for dual-architecture support
    /// Sets both ARM64/Universal and x86_64 file paths for comprehensive deployment coverage
    /// - Parameters:
    ///   - downloadedFileArm: The URL of the primary architecture (ARM64/Universal) file
    ///   - downloadedFilex86: The optional URL of the x86_64 architecture file
    ///   - results: The ProcessedAppResults structure to update with downloaded file paths
    static func applyDownloadedFiles(
        _ downloadedFileArm: URL,
        _ downloadedFilex86: URL?,
        to results: inout ProcessedAppResults
    ) {
        results.appLocalURL = downloadedFileArm.path
        results.appLocalURLx86 = downloadedFilex86?.path ?? ""
    }

    /// Applies cached file information to the application results structure
    /// Uses cached version to avoid re-downloading and re-processing existing files
    /// - Parameters:
    ///   - cacheURL: The URL of the cached file
    ///   - results: The ProcessedAppResults structure to update with cached file information
    static func applyCached(
        _ cacheURL: URL,
        to results: inout ProcessedAppResults
    ) {
        Logger.info("Cached item found at \(cacheURL.path)", category: .automation)
        results.appLocalURL = cacheURL.path
        results.appBundleIdActual = results.appBundleIdExpected
        results.appVersionActual = results.appVersionExpected
    }

    /// Logs processed application information for debugging and tracking
    /// Provides visibility into the final processing results before upload
    /// - Parameter results: The ProcessedAppResults containing processed application information
    static func logProcessed(_ results: ProcessedAppResults) {
        Logger.info("  Processed file ready at: \(results.appLocalURL)", category: .automation)
        Logger.info("  Version: \(results.appVersionActual)", category: .automation)
    }

    // MARK: - Cache Management Operations
    
    /// Checks if a specific application version already exists in the local cache
    /// Prevents unnecessary re-downloading of previously processed application versions
    /// - Parameter results: ProcessedAppResults containing label name, version, and filename information
    /// - Returns: URL of cached file if found, nil if not cached
    static func isVersionCached(forProcessedResult results: ProcessedAppResults) -> URL? {
        let labelName = results.appLabelName
        let versionExpected = results.appVersionExpected
        let fileName = results.appUploadFilename

        if labelName == "" {
            return nil
        }

        if versionExpected == "" {
            return nil
        }

        if fileName == "" {
            return nil
        }

        Logger.info("Label Name: \(labelName)", category: .automation)
        Logger.info("Version: \(versionExpected)", category: .automation)
        Logger.info("File Name: \(fileName)", category: .automation)

        // Construct cache file path: Cache/{label}/{version}/{filename}
        let versionCheckPath: URL = AppConstants.intuneomatorCacheFolderURL
            .appending(path: labelName, directoryHint: .isDirectory)
            .appending(path: versionExpected, directoryHint: .isDirectory)
            .appending(path: fileName, directoryHint: .notDirectory)

        Logger.info("Version Check Path: \(versionCheckPath.path)", category: .automation)

        // Return URL if cached file exists, otherwise nil
        if FileManager.default.fileExists(atPath: versionCheckPath.path) {
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: versionCheckPath.path)
                if let ownerID = attributes[.ownerAccountID] as? NSNumber,
                   let groupID = attributes[.groupOwnerAccountID] as? NSNumber {
                    // Check if file is owned by root:wheel (UID 0, GID 0)
                    if ownerID.intValue == 0 && groupID.intValue == 0 {
                        return versionCheckPath
                    } else {
                        Logger.info("Ownership mismatch on cached file. Deleting: \(versionCheckPath.path)", category: .automation)
                        try FileManager.default.removeItem(at: versionCheckPath)
                        return nil
                    }
                }
            } catch {
                Logger.error("Error checking ownership of cached file: \(error.localizedDescription)", category: .automation)
                return nil
            }
        }
        return nil
    }
    
    // MARK: - Intune Version Validation
    
    /// Checks if a specific application version has already been uploaded to Microsoft Intune
    /// Prevents duplicate uploads and provides upload status validation
    /// - Parameters:
    ///   - appInfo: Array of FilteredIntuneAppInfo containing existing applications in Intune
    ///   - version: The application version string to search for
    /// - Returns: True if version exists in Intune, false if not found
    static func isVersionUploadedToIntune(appInfo: [FilteredIntuneAppInfo], version: String) -> Bool {
        // Search for matching version in existing Intune applications
        
        Logger.info("Verifying version \(version)...", category: .automation)
        Logger.info("App Info: \(appInfo)", category: .automation)
        
        return appInfo.contains { app in
            return app.primaryBundleVersion == version
        }
    }
    
    /// Determines if an Installomator label supports dual-architecture deployment
    /// Checks for existence of x86_64 specific configuration files
    /// - Parameters:
    ///   - label: The Installomator label name
    ///   - guid: The unique identifier for the application
    /// - Returns: True if dual-architecture support is available, false otherwise
    static func titleIsDualArch(forLabel label: String, guid: String) -> Bool {
        
        // Check for x86_64 specific plist file indicating dual-arch support
        let labelX86PlistPath = AppConstants.intuneomatorManagedTitlesFolderURL
            .appendingPathComponent("\(label)_\(guid)", isDirectory: true)
            .appendingPathComponent("\(label)_i386.plist", isDirectory: true)
        
        return FileManager.default.fileExists(atPath: labelX86PlistPath.path)
    }

    
    // MARK: - Intune Upload Status Monitoring
    
    /// Polls Microsoft Graph API to verify successful application upload to Intune
    /// Implements retry logic with exponential backoff to handle upload processing delays
    /// - Parameters:
    ///   - appTrackingID: The unique tracking identifier for the application
    ///   - processedAppResults: ProcessedAppResults containing version information for verification
    ///   - authToken: OAuth bearer token for Microsoft Graph authentication
    /// - Returns: A tuple containing success status and array of found applications in Intune
    static func pollForIntuneUploadStatus(withID appTrackingID: String, processedAppResults: ProcessedAppResults, authToken: String) async -> (Bool, [FilteredIntuneAppInfo]){
        
        var appInfo: [FilteredIntuneAppInfo] = []

        // Polling configuration for upload verification
        let maxPollAttempts = 12
        let pollInterval: UInt64 = 3_000_000_000 // 3 seconds in nanoseconds

        var uploadSucceeded = false
        var currentAttempt = 0

        Logger.info("Polling for Intune upload status...", category: .automation)
        do {

            // Poll until upload appears in Intune or max attempts reached
            while currentAttempt < maxPollAttempts && !uploadSucceeded {
                appInfo = try await EntraGraphRequests.findAppsByTrackingID(authToken: authToken, trackingID: appTrackingID)
                Logger.debug("appInfo: \(appInfo)", category: .automation)
                uploadSucceeded = isVersionUploadedToIntune(appInfo: appInfo, version: processedAppResults.appVersionActual)
                Logger.debug("uploadSucceeded: \(uploadSucceeded)", category: .automation)

                if uploadSucceeded {
                    Logger.info("Version \(processedAppResults.appVersionActual) was uploaded to Intune", category: .automation)
                    break
                } else {
                    Logger.info("Waiting for version \(processedAppResults.appVersionActual) to appear in Intune (attempt \(currentAttempt + 1))", category: .automation)
                    try await Task.sleep(nanoseconds: pollInterval)
                    currentAttempt += 1
                }
            }

            if uploadSucceeded {
                Logger.info("Version \(processedAppResults.appVersionActual) was uploaded to Intune after polling", category: .automation)
                return (true, appInfo)
            }

        } catch {
            Logger.error("Failed to check for successful upload to Intune: \(error.localizedDescription)", category: .automation)
        }
        
        return (false, [])
    }

    // MARK: - Upload Tracking and Logging
    
    /// Logs comprehensive upload information for tracking and audit purposes
    /// Creates structured log entries with application metadata, file size, and version information
    /// - Parameter processedAppResults: ProcessedAppResults containing all application information to log
    static func logUploadFileInfo(processedAppResults: ProcessedAppResults) {
        
        do {
            // Extract application metadata for logging
            let labelDisplayName = processedAppResults.appDisplayName
            let labelName = processedAppResults.appLabelName
            let finalURL: String = processedAppResults.appLocalURL
            let finalFilename = (finalURL as NSString).lastPathComponent

            // Extract version and identifier information
            let fileIdentifier = processedAppResults.appBundleIdActual
            let fileVersionActual = processedAppResults.appVersionActual
            let fileVersionExpected = processedAppResults.appVersionExpected
            let labelTrackingID = processedAppResults.appTrackingID

            // Calculate file size in MB for readable logging format
            let fileAttributes = try FileManager.default.attributesOfItem(atPath: finalURL)
            let fileSizeBytes = fileAttributes[.size] as? Int64 ?? 0
            let fileSizeMB = Double(fileSizeBytes) / 1_048_576
                    
            // Write tab-separated values to Upload log file for structured tracking
            Logger.log("\(labelDisplayName)\t\(labelName)\t\(finalFilename)\t\(String(format: "%.2f", fileSizeMB)) MB\t\(fileIdentifier)\t\(fileVersionActual)\t\(fileVersionExpected)\t\(labelTrackingID)\t\(finalURL)", level: .info, category: .upload)
            
        } catch {
            Logger.info("Unable to get file size: \(error.localizedDescription)", category: .automation)
        }

    }
    
    // MARK: - Version Management
    
    /// Records the current count of uploaded applications for version management
    /// Creates tracking files for GUI display and manages version retention policies
    /// - Parameters:
    ///   - folderName: The application folder name for tracking file placement
    ///   - appInfo: Array of existing applications in Intune for count calculation
    static func recordUploadCount(forAppFolder folderName: String, appInfo: [FilteredIntuneAppInfo]) {
        
        // Calculate remaining versions after applying retention policy
        let appVersionsToKeep = ConfigManager.readPlistValue(key: "AppVersionsToKeep") ?? 2
        let totalVersions = appInfo.count
        let versionsToDeleteCount = max(0, totalVersions - appVersionsToKeep)

        let remainingCount = appInfo.count - versionsToDeleteCount
        
        do {

            let uploadedFileURL = AppConstants.intuneomatorManagedTitlesFolderURL
                .appendingPathComponent(folderName)
                .appendingPathComponent(".uploaded")

            if remainingCount > 0 {

                // Write remaining app count to tracking file for GUI display
                let appCountString = "\(remainingCount)"
                try appCountString.write(to: uploadedFileURL, atomically: true, encoding: .utf8)
            } else {

                // Remove tracking file if no versions remain
                if FileManager.default.fileExists(atPath: uploadedFileURL.path) {
                    try FileManager.default.removeItem(atPath: uploadedFileURL.path)
                }
            }

        } catch {
            Logger.error("Error: \(error)", category: .automation)
        }

    }
    
    // MARK: - Temporary File Cleanup
    
    /// Cleans up temporary files and directories created during automation processing
    /// Removes temporary download and processing files to maintain disk space hygiene
    /// - Parameter label: The Installomator label name for targeted cleanup
    /// - Returns: True if cleanup succeeded or no files to clean, false if cleanup failed
    static func cleanUpTmpFiles(forAppLabel label: String) -> Bool {
        
        // Construct path to temporary download folder for this label
        let downloadFolder = AppConstants.intuneomatorCacheFolderURL
            .appendingPathComponent(label)
            .appendingPathComponent("tmp")
        
        // Remove temporary directory if it exists
        if FileManager.default.fileExists(atPath: downloadFolder.path) {
            do{
                try FileManager.default.removeItem(at: downloadFolder)
                Logger.info("Cleaned up temporary files for \(label)", category: .automation)
            } catch {
                Logger.error("Failed to delete tmp folder: \(error.localizedDescription)", category: .automation)
                return false
            }
        }
        return true
    }
    
    
}

