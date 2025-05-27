//
//  LabelAutomation+ProcessHelpers.swift
//  Intuneomator
//
//  Created by Gil Burns on 5/22/25.
//

import Foundation

extension LabelAutomation {

    // MARK: - Downloaded file cached
    // Check if the version already exists in cache
    static func isVersionCached(forProcessedResult results: ProcessedAppResults) -> URL {
        
        let versionCheckPath = AppConstants.intuneomatorCacheFolderURL
            .appendingPathComponent(results.appLabelName)
            .appendingPathComponent(results.appVersionExpected)
                
        let fileName: String
        
        let fileSuffix: String
        if results.appDeploymentType == 0 {
            fileSuffix = "dmg"
        } else {
            fileSuffix = "pkg"
        }
        
        let fileArch: String
        if results.appDeploymentArch == 0 {
            fileArch = "arm64"
        } else if results.appDeploymentArch == 1 {
            fileArch = "x86_64"
        } else {
            fileArch = "universal"
        }
        
        if results.appDeploymentType == 2 {
            fileName = "\(results.appDisplayName)-\(results.appVersionExpected).\(fileSuffix)"
        } else  {
            let dualArch = titleIsDualArch(forLabel: results.appLabelName, guid: results.appTrackingID)
            if dualArch {
                fileName = "\(results.appDisplayName)-\(results.appVersionExpected)-\(fileArch).\(fileSuffix)"
            } else {
                fileName = "\(results.appDisplayName)-\(results.appVersionExpected).\(fileSuffix)"
            }
        }
        
        let fullPath = versionCheckPath
            .appendingPathComponent(fileName)
        
        if FileManager.default.fileExists(atPath: fullPath.path) {
            return fullPath
        } else {
            return URL(fileURLWithPath: "/")
        }
    }
    
    
    // Async version of the function
    static func isVersionUploadedToIntuneAsync(appInfo: [FilteredIntuneAppInfo], version: String) -> Bool {
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

        do {

            while currentAttempt < maxPollAttempts && !uploadSucceeded {
                appInfo = try await EntraGraphRequests.findAppsByTrackingID(authToken: authToken, trackingID: appTrackingID)
                uploadSucceeded = isVersionUploadedToIntuneAsync(appInfo: appInfo, version: processedAppResults.appVersionActual)
                
                if uploadSucceeded {
                    Logger.log("Version \(processedAppResults.appVersionActual) was uploaded to Intune", logType: logType)
                    break
                } else {
                    Logger.log("Waiting for version \(processedAppResults.appVersionActual) to appear in Intune (attempt \(currentAttempt + 1))", logType: logType)
                    try await Task.sleep(nanoseconds: pollInterval)
                    currentAttempt += 1
                }
            }

            if !uploadSucceeded {
                Logger.log("Version \(processedAppResults.appVersionActual) was NOT uploaded to Intune after polling", logType: logType)
                return (true, appInfo)
            }

        } catch {
            Logger.log("Failed to check for successful upload to Intune: \(error.localizedDescription)", logType: logType)
        }
        
        return (false, [])
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

