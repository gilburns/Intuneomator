//
//  LabelAutomation+ProcessHelpers.swift
//  Intuneomator
//
//  Created by Gil Burns on 5/22/25.
//

import Foundation

extension LabelAutomation {

    // MARK: - Downloaded Dual Arch
    static func downloadArchives(
        for processed: ProcessedAppResults,
        folderName: String
    ) async throws -> (URL, URL?) {
        let primaryURL = processed.appDownloadURL
        Logger.log("  Download URL: \(primaryURL)", logType: logType)

        // always grab the universal/arm64 first
        let universalURL = try await downloadFile(
            for: folderName,
            processedAppResults: processed
        )

        // if we need x86, do it here
        let x86URL: URL?
        if processed.appDeploymentArch == 2,
           MetadataLoader.titleIsDualArch(forFolder: folderName)
        {
            Logger.log("Downloading x86 slice for dual-arch", logType: logType)
            x86URL = try await downloadFile(
                for: folderName,
                processedAppResults: processed,
                downloadArch: "x86"
            )
        } else {
            x86URL = nil
        }

        return (universalURL, x86URL)
    }

    
    static func apply(
        _ processedFile: ProcessedFileResult,
        to results: inout ProcessedAppResults
    ) {
        results.appLocalURL = processedFile.url.path
        
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
    
    static func applyDownloadedFiles(
        _ downloadedFileArm: URL,
        _ downloadedFilex86: URL?,
        to results: inout ProcessedAppResults
    ) {
        results.appLocalURL = downloadedFileArm.path
        results.appLocalURLx86 = downloadedFilex86?.path ?? ""
    }

    
    static func applyCached(
        _ cacheURL: URL,
        to results: inout ProcessedAppResults
    ) {
        Logger.log("Cached item found at \(cacheURL.path)", logType: logType)
        results.appLocalURL = cacheURL.path
        results.appBundleIdActual = results.appBundleIdExpected
        results.appVersionActual = results.appVersionExpected
    }

    static func logProcessed(_ results: ProcessedAppResults) {
        Logger.log("  Processed file ready at: \(results.appLocalURL)", logType: logType)
        Logger.log("  Version: \(results.appVersionActual)", logType: logType)
    }

    // MARK: - Downloaded file cached ???
    // Check if the version already exists in cache
    static func isVersionCached(forProcessedResult results: ProcessedAppResults) -> URL? {
        
        let labelName = results.appLabelName
        let versionExpected = results.appVersionExpected
        let fileName = results.appUploadFilename

        Logger.log("Label Name: \(labelName)", logType: logType)
        Logger.log("Version: \(versionExpected)", logType: logType)
        Logger.log("File Name: \(fileName)", logType: logType)
        
        let versionCheckPath: URL = AppConstants.intuneomatorCacheFolderURL
            .appending(path: labelName, directoryHint: .isDirectory)
            .appending(path: versionExpected, directoryHint: .isDirectory)
            .appending(path: fileName, directoryHint: .notDirectory)
                
        Logger.log("Version Check Path: \(versionCheckPath.path)")
        
        if FileManager.default.fileExists(atPath: versionCheckPath.path) {
            return versionCheckPath
        }
        return nil
    }
    
    
    // Async version of the function
    static func isVersionUploadedToIntune(appInfo: [FilteredIntuneAppInfo], version: String) -> Bool {
        // Simple direct check
        return appInfo.contains { app in
            return app.primaryBundleVersion == version
        }
    }
    
    static func titleIsDualArch(forLabel label: String, guid: String) -> Bool {
        
        let labelX86PlistPath = AppConstants.intuneomatorManagedTitlesFolderURL
            .appendingPathComponent("\(label)_\(guid)", isDirectory: true)
            .appendingPathComponent("\(label)_i386.plist", isDirectory: true)
        
        return FileManager.default.fileExists(atPath: labelX86PlistPath.path)
    }

    
    // MARK: - Poll Graph for Intune upload status
    
    static func pollForIntuneUploadStatus(withID appTrackingID: String, processedAppResults: ProcessedAppResults, authToken: String) async -> (Bool, [FilteredIntuneAppInfo]){
        
        
        // For check version in Intune
        var appInfo: [FilteredIntuneAppInfo] = []

        // Polling constants
        let maxPollAttempts = 12
        let pollInterval: UInt64 = 3_000_000_000 // 3 seconds in nanoseconds

        var uploadSucceeded = false
        var currentAttempt = 0

        Logger.log("Polling for Intune upload status...", logType: logType)
        do {

            while currentAttempt < maxPollAttempts && !uploadSucceeded {
                appInfo = try await EntraGraphRequests.findAppsByTrackingID(authToken: authToken, trackingID: appTrackingID)
                Logger.log("appInfo: \(appInfo)", logType: "debug")
                uploadSucceeded = isVersionUploadedToIntune(appInfo: appInfo, version: processedAppResults.appVersionActual)
                Logger.log("uploadSucceeded: \(uploadSucceeded)", logType: "debug")

                if uploadSucceeded {
                    Logger.log("Version \(processedAppResults.appVersionActual) was uploaded to Intune", logType: logType)
                    break
                } else {
                    Logger.log("Waiting for version \(processedAppResults.appVersionActual) to appear in Intune (attempt \(currentAttempt + 1))", logType: logType)
                    try await Task.sleep(nanoseconds: pollInterval)
                    currentAttempt += 1
                }
            }

            if uploadSucceeded {
                Logger.log("Version \(processedAppResults.appVersionActual) was uploaded to Intune after polling", logType: logType)
                return (true, appInfo)
            }

        } catch {
            Logger.log("Failed to check for successful upload to Intune: \(error.localizedDescription)", logType: logType)
        }
        
        return (false, [])
    }

    // MARK: - Log Upload File Info
    
    static func logUploadFileInfo(processedAppResults: ProcessedAppResults) {
        
        do {
            let labelDisplayName = processedAppResults.appDisplayName
            let labelName = processedAppResults.appLabelName
            let finalURL: String = processedAppResults.appLocalURL
            let finalFilename = (finalURL as NSString).lastPathComponent

            // file size
            let fileIdentifier = processedAppResults.appBundleIdActual
            let fileVersionActual = processedAppResults.appVersionActual
            let fileVersionExpected = processedAppResults.appVersionExpected
            let labelTrackingID = processedAppResults.appTrackingID

            let fileAttributes = try FileManager.default.attributesOfItem(atPath: finalURL)
            let fileSizeBytes = fileAttributes[.size] as? Int64 ?? 0
            let fileSizeMB = Double(fileSizeBytes) / 1_048_576
                    
            // Write the upload info to the Upload log file
            Logger.logNoDateStamp("\(labelDisplayName)\t\(labelName)\t\(finalFilename)\t\(String(format: "%.2f", fileSizeMB)) MB\t\(fileIdentifier)\t\(fileVersionActual)\t\(fileVersionExpected)\t\(labelTrackingID)\t\(finalURL)", logType: "Upload")
            
        } catch {
            Logger.log("Unable to get file size: \(error.localizedDescription)", logType: logType)
        }

    }
    
    // MARK: - Record upload count
    
    static func recordUploadCount(forAppFolder folderName: String, appInfo: [FilteredIntuneAppInfo]) {
        
        // Write the .uploaded file count for GUI app
        let appVersionsToKeep = ConfigManager.readPlistValue(key: "AppVersionsToKeep") ?? 2
        let totalVersions = appInfo.count
        let versionsToDeleteCount = max(0, totalVersions - appVersionsToKeep)

        let remainingCount = appInfo.count - versionsToDeleteCount
        
        do {

            let uploadedFileURL = AppConstants.intuneomatorManagedTitlesFolderURL
                .appendingPathComponent(folderName)
                .appendingPathComponent(".uploaded")

            if remainingCount > 0 {

                // Write app count to the file
                let appCountString = "\(remainingCount)"
                try appCountString.write(to: uploadedFileURL, atomically: true, encoding: .utf8)
            } else {

                if FileManager.default.fileExists(atPath: uploadedFileURL.path) {
                    try FileManager.default.removeItem(atPath: uploadedFileURL.path)
                }
            }

        } catch {
            Logger.log("❌ Error: \(error)", logType: logType)
        }

    }
    
    

    // MARK: - Tmp folder cleanup
    // Clean up automation tmp folder
    static func cleanUpTmpFiles(forAppLabel label: String) -> Bool {
        
        let downloadFolder = AppConstants.intuneomatorCacheFolderURL
            .appendingPathComponent(label)
            .appendingPathComponent("tmp")
        
        if FileManager.default.fileExists(atPath: downloadFolder.path) {
            do{
                // Delete the tmp directory
                try FileManager.default.removeItem(at: downloadFolder)
            } catch {
                Logger.log("❌ Failed to delete tmp folder: \(error.localizedDescription)", logType: LabelAutomation.logType)
                return false
            }
        }
        return true
    }
    
    
}

