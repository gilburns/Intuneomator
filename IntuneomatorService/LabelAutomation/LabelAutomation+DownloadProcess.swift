//
//  LabelAutomation+DownloadProcess.swift
//  Intuneomator
//
//  Created by Gil Burns on 5/27/25.
//

import Foundation

extension LabelAutomation {
    
    
    // MARK: - Process Downloaded File
    static func processDownloadedFile(downloadURL: URL, folderName: String, downloadType: String, fileUploadName: String, expectedTeamID: String, expectedBundleID: String, expectedVersion: String) async throws -> (url: URL?, bundleID: String, version: String) {
        
        Logger.log("Processing downloaded file...", logType: logType)
        Logger.log("  Download URL: \(downloadURL.absoluteString)", logType: logType)
        Logger.log("  Folder name: \(folderName)", logType: logType)
        Logger.log("  Download type: \(downloadType)", logType: logType)
        
        let downloadType = downloadType
        guard let labelName = folderName.components(separatedBy: "_").first else {
            return (nil, "", "")
        }
        
        // set output filename
        var outputFileName: String = fileUploadName
        
        var outputURL: URL? = nil
        var outputAppName: String? = nil
        var outputAppBundleID: String? = nil
        var outputAppVersion: String? = nil
        
        Logger.log("  Processing downloaded file: \(downloadURL.lastPathComponent)", logType: logType)
        Logger.log("  File type: \(downloadType)", logType: logType)
        
        
        // New Processing
        switch downloadType.lowercased() {
        case "pkg", "pkginzip", "pkgindmg", "pkgindmginzip":
            let (url, bundleID, version) = try await processPkgFile(downloadURL: downloadURL, folderName: folderName, downloadType: downloadType, fileUploadName: fileUploadName, expectedTeamID: expectedTeamID, expectedBundleID: expectedBundleID, expectedVersion: expectedVersion)
            
            outputURL = url
            outputAppBundleID = bundleID
            outputAppVersion = version
            
        case "zip", "tbz", "dmg", "appindmginzip":
            let (url, filename, bundleID, version) = try await processAppFile(downloadURL: downloadURL, folderName: folderName, downloadType: downloadType, deploymentType: 0, fileUploadName: fileUploadName, expectedTeamID: expectedTeamID, expectedBundleID: expectedBundleID, expectedVersion: expectedVersion)
            
            outputURL = url
            outputFileName = filename
            outputAppBundleID = bundleID
            outputAppVersion = version

            
        default:
            Logger.log("Unhandled download type: \(downloadType)", logType: logType)
            throw NSError(domain: "ProcessingError", code: 101, userInfo: [NSLocalizedDescriptionKey: "Unsupported file type: \(downloadType)"])
        }
        
        
        
        return (outputURL!, outputAppBundleID!, outputAppVersion!)
    }
    
}
