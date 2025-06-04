//
//  LabelAutomation+DownloadProcessUniv.swift
//  Intuneomator
//
//  Created by Gil Burns on 5/27/25.
//

import Foundation

extension LabelAutomation {
    
    static func processDualAppFiles(downloadURL: URL, downloadURLx86_64: URL, folderName: String, downloadType: String, fileUploadName: String, expectedTeamID: String, expectedBundleID: String) async throws -> (url: URL?, appName: String, appBundleID: String, appVersion: String)  {
        
        // PKG - Universal - Dual Arch DMGs
        //        if processedAppResults.appDeploymentType == 1 && processedAppResults.appDeploymentArch == 2 && processedAppResults.appIsDualArchCapable == true {
        
        
        Logger.log("Building Universal Dual Arch Package", logType: logType)
        Logger.log("Arch 1: \(downloadURL)", logType: logType)
        Logger.log("Arch 2: \(downloadURLx86_64)", logType: logType)
        
        var appFiles: [URL]!
        var appFilesFound: [URL]! = []
        var finalDestinationFolder: URL!
        var downloadedVersions: [String] = []
        
        var outputURL: URL? = nil
        var outputAppName: String
        var outputAppBundleID: String
        var outputAppVersion: String

        guard let labelName = folderName.components(separatedBy: "_").first else {
            return (nil, "", "", "")
        }
        
        let downloadFolder = AppConstants.intuneomatorCacheFolderURL
            .appendingPathComponent(labelName)

        
        let downloadArray = [downloadURL, downloadURLx86_64]
        for downloadURL in downloadArray {
            
            Logger.log("Processing URL: \(downloadURL)", logType: logType)
            
            switch downloadType.lowercased() {
            case "zip":
                Logger.log("Handle type zip specifics", logType: logType)
                // Extract ZIP, find and copy .app
                let extractedFolder = try await extractZipFileWithDitto(zipURL: downloadURL)
                appFiles = try findFiles(inFolder: extractedFolder, withExtension: "app")
                
                guard let appFile = appFiles.first else {
                    throw NSError(domain: "ProcessingError", code: 106, userInfo: [NSLocalizedDescriptionKey: "No .app file found in ZIP archive"])
                    
                }
                appFilesFound += [appFile]
                
            case "tbz":
                Logger.log("Handle type tbz specifics", logType: logType)
                // Extract TBZ, find and copy .app
                let extractedFolder = try await extractTBZFile(tbzURL: downloadURL)
                let appFiles = try findFiles(inFolder: extractedFolder, withExtension: "app")
                
                guard let appFile = appFiles.first else {
                    throw NSError(domain: "ProcessingError", code: 107, userInfo: [NSLocalizedDescriptionKey: "No .app file found in TBZ archive"])
                }
                appFilesFound += [appFile]
                
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
                    
                    appFilesFound += [destinationURL]
                    
                    Logger.log("App to process: \(String(describing: appFilesFound))", logType: logType)
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
                    
                    appFilesFound += [destinationURL]
                    
                    Logger.log("App to process: \(String(describing: appFilesFound))", logType: logType)
                } else {
                    throw NSError(domain: "ProcessingError", code: 106, userInfo: [NSLocalizedDescriptionKey: "Invalid copy directory"])
                }
                
            default:
                break
            }
            
            
        }
        
        // Validate and get info for apps
        
        for (index, appFile) in appFilesFound.enumerated() {
            Logger.log("Checking app \(index): \(appFile)", logType: logType)
            
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
                            Logger.log("  Package ID '\(expectedBundleID)' not found in the .pkg", logType: logType)
                            continuation.resume(returning: "None")
                        }
                    case .failure(let error):
                        Logger.log("Error inspecting .pkg: \(error.localizedDescription)", logType: logType)
                        continuation.resume(returning: "None")
                    }
                }
            }
            
            downloadedVersions.append(downloadedVersion)
            
        }
        
        if downloadedVersions[0] != downloadedVersions[1] {
            Logger.log("🛑 Versions do not match!", logType: logType)
        } else {
            Logger.log("✅ Versions match!", logType: logType)
        }
        
        
        // Check that the dual arhitecture matches expecations
        let expectedArchitectures: [AppArchitecture] = [.arm64, .x86_64]
        do {
            try validateAppArchitectures(urls: appFilesFound, expected: expectedArchitectures)
            // all good — proceed with your next steps
            Logger.log("✅ Architectures match expected!", logType: logType)
        } catch {
            // mismatch — handle or surface the error
            Logger.log("❌ \(error)", logType: logType)
        }
        
        
        // Create the final destination folder
        finalDestinationFolder = downloadFolder
            .appendingPathComponent(downloadedVersions[0])
        
        try FileManager.default.createDirectory(at: finalDestinationFolder, withIntermediateDirectories: true)
        
        Logger.log("Universal pkg creation", logType: logType)
        let pkgCreator = PKGCreatorUniversal()
        if let (outputURLResult, outputAppNameResult, outputAppBundleIDResult, outputAppVersionResult) = pkgCreator.createUniversalPackage(inputPathArm64: appFilesFound[0].path, inputPathx86_64: appFilesFound[1].path, outputDir: finalDestinationFolder.path) {
            Logger.log("  Package creation succeeded.", logType: logType)
            
            outputURL = URL(string: outputURLResult)
            outputAppName = outputAppNameResult
            outputAppBundleID = outputAppBundleIDResult
            outputAppVersion = outputAppVersionResult
        } else {
            outputURL = nil
            outputAppName = ""
            outputAppBundleID = ""
            outputAppVersion = ""
        }
        
        return (outputURL, outputAppName, outputAppBundleID, outputAppVersion)
        
    }
    //    }
    
    
}
