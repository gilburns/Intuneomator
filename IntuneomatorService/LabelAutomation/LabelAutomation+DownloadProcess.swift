//
//  LabelAutomation+DownloadProcess.swift
//  Intuneomator
//
//  Created by Gil Burns on 5/27/25.
//

import Foundation

extension LabelAutomation {
    
    /// Main dispatcher function for processing downloaded files based on their type
    ///
    /// This function serves as the primary entry point for processing downloaded software packages.
    /// It analyzes the download type and routes the processing to the appropriate specialized function:
    /// - PKG-related types are routed to `processPkgFile()` for installer processing
    /// - App-related types are routed to `processAppFile()` for application bundle processing
    ///
    /// **Supported Download Types:**
    /// - **PKG Types**: "pkg", "pkginzip", "pkgindmg", "pkgindmginzip"
    /// - **App Types**: "zip", "tbz", "dmg", "appindmginzip"
    ///
    /// **Processing Flow:**
    /// 1. Determines the appropriate processing method based on download type
    /// 2. Calls the specialized processing function with provided parameters
    /// 3. Validates and normalizes the returned results
    /// 4. Returns standardized output for further processing
    ///
    /// - Parameters:
    ///   - downloadURL: URL to the downloaded file to process
    ///   - folderName: Target folder name (format: "labelname_GUID") for organizing output
    ///   - downloadType: Type of download archive determining processing method
    ///   - fileUploadName: Final filename for the processed package
    ///   - expectedTeamID: Apple Developer Team ID for signature validation
    ///   - expectedBundleID: Expected bundle/package identifier
    ///   - expectedVersion: Expected version string for validation
    ///
    /// - Returns: Tuple containing:
    ///   - url: URL to the processed package ready for upload
    ///   - bundleID: Bundle/package identifier extracted from the software
    ///   - version: Version string extracted from the software
    ///
    /// - Throws:
    ///   - `ProcessingError` with code 128 for unsupported download types
    ///   - Any errors propagated from specialized processing functions
    ///
    /// **Error Codes:**
    /// - 128: Unsupported file type
    // MARK: - Process Downloaded File
    static func processDownloadedFile(downloadURL: URL, folderName: String, downloadType: String, fileUploadName: String, expectedTeamID: String, expectedBundleID: String, expectedVersion: String) async throws -> (url: URL?, bundleID: String, version: String) {
        
        Logger.log("Processing downloaded file...", logType: logType)
        Logger.log("  Download URL: \(downloadURL.absoluteString)", logType: logType)
        Logger.log("  Folder name: \(folderName)", logType: logType)
        Logger.log("  Download type: \(downloadType)", logType: logType)
        
        // Extract label name from folder name (format: "labelname_GUID")
        guard let labelName = folderName.components(separatedBy: "_").first else {
            return (nil, "", "")
        }
        
        // Variables to track processing results
        var outputURL: URL? = nil
        var outputAppBundleID: String = ""
        var outputAppVersion: String = ""
        
        Logger.log("  Processing file: \(downloadURL.lastPathComponent)", logType: logType)
        Logger.log("  File type: \(downloadType)", logType: logType)
        
        
        // Route processing based on download type
        switch downloadType.lowercased() {
        case "pkg", "pkginzip", "pkgindmg", "pkgindmginzip":
            Logger.log("Routing to PKG processing pipeline", logType: logType)
            let (url, bundleID, version) = try await processPkgFile(downloadURL: downloadURL, folderName: folderName, downloadType: downloadType, fileUploadName: fileUploadName, expectedTeamID: expectedTeamID, expectedBundleID: expectedBundleID, expectedVersion: expectedVersion)
            
            // Validate PKG processing results
            guard let processedURL = url else {
                Logger.log("PKG processing failed - no output URL", logType: logType)
                return (nil, "", "")
            }
            
            outputURL = processedURL
            outputAppBundleID = bundleID.isEmpty ? expectedBundleID : bundleID
            outputAppVersion = version.isEmpty ? expectedVersion : version
            
        case "zip", "tbz", "dmg", "appindmginzip":
            Logger.log("Routing to App processing pipeline (DMG deployment)", logType: logType)
            let (url, appName, bundleID, version) = try await processAppFile(downloadURL: downloadURL, folderName: folderName, downloadType: downloadType, deploymentType: 0, fileUploadName: fileUploadName, expectedTeamID: expectedTeamID, expectedBundleID: expectedBundleID, expectedVersion: expectedVersion)
            
            // Validate App processing results
            guard let processedURL = url else {
                Logger.log("App processing failed - no output URL", logType: logType)
                return (nil, "", "")
            }
            
            outputURL = processedURL
            outputAppBundleID = bundleID.isEmpty ? expectedBundleID : bundleID
            outputAppVersion = version.isEmpty ? expectedVersion : version
            
        default:
            Logger.log("Unsupported download type: \(downloadType)", logType: logType)
            throw NSError(domain: "ProcessingError", code: 128, userInfo: [NSLocalizedDescriptionKey: "Unsupported file type: \(downloadType)"])
        }
        
        
        // Return validated results
        Logger.log("Processing completed successfully", logType: logType)
        Logger.log("  Output URL: \(outputURL?.path ?? "nil")", logType: logType)
        Logger.log("  Bundle ID: \(outputAppBundleID)", logType: logType)
        Logger.log("  Version: \(outputAppVersion)", logType: logType)
        
        return (outputURL, outputAppBundleID, outputAppVersion)
    }
    
}
