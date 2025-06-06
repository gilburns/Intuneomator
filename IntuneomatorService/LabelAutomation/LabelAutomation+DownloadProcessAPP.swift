//
//  LabelAutomation+DownloadProcessAPP.swift
//  Intuneomator
//
//  Created by Gil Burns on 5/27/25.
//

import Foundation

extension LabelAutomation {
    
    static func processAppFile(downloadURL: URL, folderName: String, downloadType: String, deploymentType: Int, fileUploadName: String, expectedTeamID: String, expectedBundleID: String) async throws -> (url: URL?, appName: String, appBundleID: String, appVersion: String) {
        
        Logger.log("Processing App Download URL type: \(downloadType) - \(downloadURL)", logType: logType)
        
        var outputURL: URL? = nil
        var outputAppName: String
        var outputAppBundleID: String
        var outputAppVersion: String
        
        Logger.log("  Processing downloaded file: \(downloadURL.lastPathComponent)", logType: logType)
        Logger.log("  File type: \(downloadType)", logType: logType)

        guard let labelName = folderName.components(separatedBy: "_").first else {
            return (nil, "", "", "")
        }
        
        let downloadFolder = AppConstants.intuneomatorCacheFolderURL
            .appendingPathComponent(labelName)

        
        var appFiles: [URL]!
        var appFileFound: URL!
        var finalDestinationFolder: URL!
        
        switch downloadType.lowercased() {
        case "zip":
            Logger.log("Handle type zip specifics", logType: logType)
            // Extract ZIP, find and copy .app
            let extractedFolder = try await extractZipFileWithDitto(zipURL: downloadURL)
            appFiles = try findFiles(inFolder: extractedFolder, withExtension: "app")
            
            guard let appFile = appFiles.first else {
                throw NSError(domain: "ProcessingError", code: 106, userInfo: [NSLocalizedDescriptionKey: "No .app file found in ZIP archive"])
                
            }
            appFileFound = appFile
            
        case "tbz":
            Logger.log("Handle type tbz specifics", logType: logType)
            // Extract TBZ, find and copy .app
            let extractedFolder = try await extractTBZFile(tbzURL: downloadURL)
            let appFiles = try findFiles(inFolder: extractedFolder, withExtension: "app")
            
            guard let appFile = appFiles.first else {
                throw NSError(domain: "ProcessingError", code: 107, userInfo: [NSLocalizedDescriptionKey: "No .app file found in TBZ archive"])
            }
            appFileFound = appFile
            
        case "dmg":
            Logger.log("Handle type dmg specifics", logType: logType)
            // Mount DMG, find and copy .app
            let mountPoint = try await mountDMGFile(dmgURL: downloadURL)
            defer { _ = try? unmountDMG(mountPoint: mountPoint) }
            
            let appFiles = try findFiles(inFolder: URL(fileURLWithPath: mountPoint), withExtension: "app")
            
            guard let appFile = appFiles.first else {
                throw NSError(domain: "ProcessingError", code: 108, userInfo: [NSLocalizedDescriptionKey: "No .app file found in mounted DMG"])
            }
            
            Logger.log("appFile: \(appFile.path)", logType: logType)
            let appName = appFile.lastPathComponent
            Logger.log("App name: \(appName)", logType: logType)
            
            if let copyDir = downloadURL.deletingLastPathComponent().path.removingPercentEncoding {
                let destinationURL = URL(fileURLWithPath: copyDir).appendingPathComponent(appName)
                // Remove existing file if present
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }
                try FileManager.default.copyItem(atPath: appFile.path, toPath: destinationURL.path)
                appFileFound = destinationURL
                Logger.log("App to process: \(appFileFound.absoluteString)", logType: logType)
            } else {
                throw NSError(domain: "ProcessingError", code: 106, userInfo: [NSLocalizedDescriptionKey: "Invalid copy directory"])
            }
            
        case "appindmginzip":
            Logger.log("Handle type appindmginzip specifics", logType: logType)
            // Extract ZIP, mount DMG, find and copy .app
            let extractedFolder = try await extractZipFile(zipURL: downloadURL)
            let dmgFiles = try findFiles(inFolder: extractedFolder, withExtension: "dmg")
            
            guard let dmgFile = dmgFiles.first else {
                throw NSError(domain: "ProcessingError", code: 109, userInfo: [NSLocalizedDescriptionKey: "No DMG file found in ZIP archive"])
            }
            
            let mountPoint = try await mountDMGFile(dmgURL: dmgFile)
            defer { _ = try? unmountDMG(mountPoint: mountPoint) }
            let appFiles = try findFiles(inFolder: URL(fileURLWithPath: mountPoint), withExtension: "app")
            
            guard let appFile = appFiles.first else {
                throw NSError(domain: "ProcessingError", code: 110, userInfo: [NSLocalizedDescriptionKey: "No .app file found in mounted DMG (from ZIP)"])
            }
            
            Logger.log("appFile: \(appFile.path)", logType: logType)
            let appName = appFile.lastPathComponent
            Logger.log("App name: \(appName)", logType: logType)
            
            if let copyDir = downloadURL.deletingLastPathComponent().path.removingPercentEncoding {
                let destinationURL = URL(fileURLWithPath: copyDir).appendingPathComponent(appName)
                // Remove existing file if present
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }
                try FileManager.default.copyItem(atPath: appFile.path, toPath: destinationURL.path)
                appFileFound = destinationURL
                Logger.log("App to process: \(appFileFound.absoluteString)", logType: logType)
            } else {
                throw NSError(domain: "ProcessingError", code: 106, userInfo: [NSLocalizedDescriptionKey: "Invalid copy directory"])
            }
            
        default:
            return (nil, "", "", "")
        }
        
        let appFile = appFileFound!
        
        // Check Signature
        let signatureResult = inspectSignatureOfDownloadedSoftware(for: appFile, expectedTeamID: expectedTeamID, inspectionType: "app")
        
        Logger.log("  Inspect result: \(signatureResult)", logType: logType)
        
        if signatureResult == true {
            Logger.log("  Signature is valid.", logType: logType)
        } else {
            Logger.log("  Signature is invalid.", logType: logType)
            throw NSError(domain: "ProcessingError", code: 101, userInfo: [NSLocalizedDescriptionKey : "Signature is invalid."])
        }
        
        // Get Version from download
        let expectedBundleID = expectedBundleID
        
        let inspector = AppInspector()
        let downloadedVersion = await withCheckedContinuation { continuation in
            inspector.getVersion(forBundleID: expectedBundleID, inAppAt: appFile) { result in
                switch result {
                case .success(let version):
                    if let version = version {
                        Logger.log("  Version for package ID '\(expectedBundleID)': \(version)", logType: logType)
                        continuation.resume(returning: version)
                    } else {
                        Logger.log("  Package ID '\(expectedBundleID)' not found in the .app", logType: logType)
                        continuation.resume(returning: "None")
                    }
                case .failure(let error):
                    Logger.log("Error inspecting .pkg: \(error.localizedDescription)", logType: logType)
                    continuation.resume(returning: "None")
                }
            }
        }
        
        // Create the final destination folder
        finalDestinationFolder = downloadFolder
            .appendingPathComponent(downloadedVersion)
        
        try FileManager.default.createDirectory(at: finalDestinationFolder, withIntermediateDirectories: true)
        
        // Create DMG for same app for Intune use
        if deploymentType == 0 {
            let dmgCreator = DMGCreator()
            do {
                let (outputURLResult, outputAppNameResult, outputAppBundleIDResult, outputAppVersionResult) = try dmgCreator.processToDMG(inputPath: appFile.path, outputDirectory: finalDestinationFolder.path)
                Logger.log("Created DMG at \(String(describing: outputURLResult)) for \(outputAppNameResult) (\(outputAppBundleIDResult)) version \(outputAppVersionResult)", logType: logType)
                
                outputURL = URL(string: outputURLResult)
                outputAppName = outputAppNameResult
                outputAppBundleID = outputAppBundleIDResult
                outputAppVersion = outputAppVersionResult
            } catch {
                Logger.log("Failed to process DMG: \(error.localizedDescription)", logType: logType)
                // Handle the error appropriately
                return (nil, "" ,"", "")
            }
            
        // Create PKG for same app for Intune use
        } else {
            Logger.log("Standard single arch pkg creation", logType: logType)
            let pkgCreator = PKGCreator()
            if let (outputURLResult, outputAppNameResult, outputAppBundleIDResult, outputAppVersionResult) = await pkgCreator.createPackage(inputPath: appFile.path, outputDir: finalDestinationFolder.path) {
                Logger.log("  Package creation succeeded.", logType: logType)
                outputURL = URL(string: outputURLResult)
                outputAppName = outputAppNameResult
                outputAppBundleID = outputAppBundleIDResult
                outputAppVersion = outputAppVersionResult
            } else {
                Logger.log("Package creation failed.", logType: logType)
                return (nil, "" ,"", "")
            }
        }
        
        Logger.log("  Output URL: \(outputURL!)", logType: logType)
        Logger.log("  Output App Name: \(outputAppName)", logType: logType)
        Logger.log("  Output App Bundle ID: \(outputAppBundleID)", logType: logType)
        Logger.log("  Output App Version: \(outputAppVersion)", logType: logType)
        
        return (outputURL, outputAppName, outputAppBundleID, outputAppVersion)
        
    }

}
