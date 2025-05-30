//
//  LabelAutomation+DownloadProcess.swift
//  Intuneomator
//
//  Created by Gil Burns on 5/27/25.
//

import Foundation

extension LabelAutomation {
 
    
    // MARK: - Process Downloaded File
    static func processDownloadedFile(displayName: String, downloadURL: URL, downloadURLx86: URL, folderName: String, processedAppResults: ProcessedAppResults) async throws -> (url: URL, name: String, bundleID: String, version: String) {
        
        Logger.log("Processing downloaded file...", logType: logType)
        Logger.log("  Display Name: \(displayName)", logType: logType)
        Logger.log("  Download URL: \(downloadURL.absoluteString)", logType: logType)
        Logger.log("  Download URL x86: \(downloadURLx86.absoluteString)", logType: logType)
        Logger.log("  Folder name: \(folderName)", logType: logType)
        
        let downloadType = processedAppResults.appLabelType
        let labelName = folderName.components(separatedBy: "_").first ?? folderName
        
        var outputFileName: String? = nil
        var outputURL: URL? = nil
        var outputAppName: String? = nil
        var outputAppBundleID: String? = nil
        var outputAppVersion: String? = nil
        
        _ = processedAppResults.appVersionExpected
        
        Logger.log("  Processing downloaded file: \(downloadURL.lastPathComponent)", logType: logType)
        Logger.log("  File type: \(downloadType)", logType: logType)
        
        
        let downloadFolder = AppConstants.intuneomatorCacheFolderURL
            .appendingPathComponent(labelName)
        
        // New Processing
        switch downloadType.lowercased() {
        case "pkg", "pkginzip", "pkgindmg", "pkgindmginzip":
            
            var pkgToProcessURL: URL!
            
            switch downloadType.lowercased() {
            case "pkg":
                Logger.log("Handle type pkg specifics", logType: logType)
                // Handle PKG file
                // Nothing needed here for pkg type
                pkgToProcessURL = downloadURL
            case "pkginzip":
                Logger.log("Handle type pkginzip specifics", logType: logType)
                // Extract ZIP, find PKG file
                let extractedFolder = try await extractZipFile(zipURL: downloadURL)
                let pkgFiles = try findFiles(inFolder: extractedFolder, withExtension: "pkg")
                
                guard let pkgFile = pkgFiles.first else {
                    throw NSError(domain: "ProcessingError", code: 102, userInfo: [NSLocalizedDescriptionKey: "No PKG file found in ZIP archive"])
                }
                pkgToProcessURL = pkgFile
                Logger.log("Pkg to process: \(pkgToProcessURL.absoluteString)", logType: logType)
                
            case "pkgindmg":
                Logger.log("Handle type pkgindmg specifics", logType: logType)
                // Mount DMG, find PKG file
                let mountPoint = try await mountDMGFile(dmgURL: downloadURL)
                defer { _ = try? unmountDMG(mountPoint: mountPoint) }
                
                let pkgFiles = try findFiles(inFolder: URL(fileURLWithPath: mountPoint), withExtension: "pkg")
                
                guard let pkgFile = pkgFiles.first else {
                    throw NSError(domain: "ProcessingError", code: 103, userInfo: [NSLocalizedDescriptionKey: "No PKG file found in mounted DMG"])
                }
                
                Logger.log("pkgFile: \(pkgFile.path)", logType: logType)
                let pkgName = pkgFile.lastPathComponent
                Logger.log("Pkg name: \(pkgName)", logType: logType)
                
                if let copyDir = downloadURL.deletingLastPathComponent().path.removingPercentEncoding {
                    let destinationURL = URL(fileURLWithPath: copyDir).appendingPathComponent(pkgName)
                    // Remove existing file if present
                    if FileManager.default.fileExists(atPath: destinationURL.path) {
                        try FileManager.default.removeItem(at: destinationURL)
                    }
                    try FileManager.default.copyItem(atPath: pkgFile.path, toPath: destinationURL.path)
                    pkgToProcessURL = destinationURL
                    Logger.log("Pkg to process: \(pkgToProcessURL.absoluteString)", logType: logType)
                } else {
                    throw NSError(domain: "ProcessingError", code: 106, userInfo: [NSLocalizedDescriptionKey: "Invalid copy directory"])
                }
                
            case "pkgindmginzip":
                Logger.log("Handle type pkgindmginzip specifics", logType: logType)
                // Extract ZIP, mount DMG, find PKG file
                let extractedFolder = try await extractZipFile(zipURL: downloadURL)
                let dmgFiles = try findFiles(inFolder: extractedFolder, withExtension: "dmg")
                
                guard let dmgFile = dmgFiles.first else {
                    throw NSError(domain: "ProcessingError", code: 104, userInfo: [NSLocalizedDescriptionKey: "No DMG file found in ZIP archive"])
                }
                
                let mountPoint = try await mountDMGFile(dmgURL: dmgFile)
                //                defer { _ = try? unmountDMG(mountPoint: mountPoint) }
                
                let pkgFiles = try findFiles(inFolder: URL(fileURLWithPath: mountPoint), withExtension: "pkg")
                
                guard let pkgFile = pkgFiles.first else {
                    throw NSError(domain: "ProcessingError", code: 105, userInfo: [NSLocalizedDescriptionKey: "No PKG file found in mounted DMG (from ZIP)"])
                }
                
                Logger.log("pkgFile: \(pkgFile.path)", logType: logType)
                let pkgName = pkgFile.lastPathComponent
                Logger.log("Pkg name: \(pkgName)", logType: logType)
                
                if let copyDir = downloadURL.deletingLastPathComponent().path.removingPercentEncoding {
                    let destinationURL = URL(fileURLWithPath: copyDir).appendingPathComponent(pkgName)
                    // Remove existing file if present
                    if FileManager.default.fileExists(atPath: destinationURL.path) {
                        try FileManager.default.removeItem(at: destinationURL)
                    }
                    try FileManager.default.copyItem(atPath: pkgFile.path, toPath: destinationURL.path)
                    pkgToProcessURL = destinationURL
                    Logger.log("Pkg to process: \(pkgToProcessURL.absoluteString)", logType: logType)
                } else {
                    throw NSError(domain: "ProcessingError", code: 106, userInfo: [NSLocalizedDescriptionKey: "Invalid copy directory"])
                }
                
            default:
                break
            }
            
            // Check Signature
            let signatureResult = inspectSignatureOfDownloadedSoftware(for: processedAppResults, downloadURL: pkgToProcessURL, inspectionType: "pkg")
            
            Logger.log("  Inspect result: \(signatureResult)", logType: logType)
            
            if signatureResult == true {
                Logger.log("  Signature is valid.", logType: logType)
            } else {
                Logger.log("  Signature is invalid.", logType: logType)
                throw NSError(domain: "ProcessingError", code: 101, userInfo: [NSLocalizedDescriptionKey : "Signature is invalid."])
            }
            
            // Get Version from download
            let pkgInspector = PkgInspector()
            let pkgURL = pkgToProcessURL
            let packageID = processedAppResults.appBundleIdExpected
            
            let downloadedVersion = await withCheckedContinuation { continuation in
                pkgInspector.getVersion(forPackageID: packageID, inPkgAt: pkgURL!) { result in
                    switch result {
                    case .success(let version):
                        if let version = version {
                            Logger.log("  Version for package ID '\(packageID)': \(version)", logType: logType)
                            continuation.resume(returning: version)
                        } else {
                            Logger.log("  Package ID '\(packageID)' not found in the .pkg", logType: logType)
                            continuation.resume(returning: "None")
                        }
                    case .failure(let error):
                        Logger.log("Error inspecting .pkg: \(error.localizedDescription)", logType: logType)
                        continuation.resume(returning: "None")
                    }
                }
            }
            
            // Create the final destination folder
            let finalDestinationFolder = downloadFolder
                .appendingPathComponent(downloadedVersion)
            
            try FileManager.default.createDirectory(at: finalDestinationFolder, withIntermediateDirectories: true)
            
            // set output filename
            outputFileName = "\(displayName)-\(downloadedVersion).pkg"
            
            //set output full path
            let destinationURL = finalDestinationFolder
                .appendingPathComponent(outputFileName ?? "Unknown.pkg")
            
            // Remove existing file if present
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            
            // Copy the file
            try FileManager.default.copyItem(at: pkgToProcessURL, to: destinationURL)
            
            Logger.log("📁 Copied file to: \(destinationURL.path)", logType: logType)
            
            
            Logger.log("Output URL: \(destinationURL)", logType: logType)
            Logger.log("Output App Name: \(processedAppResults.appDisplayName)", logType: logType)
            Logger.log("Output App Bundle ID: \(packageID)", logType: logType)
            Logger.log("Output App Version: \(String(describing: outputAppVersion))", logType: logType)
            
            let outputURL: URL? = destinationURL
            
            return (url: outputURL!, name: processedAppResults.appDisplayName, bundleID: packageID, version: downloadedVersion)
            
            
        case "zip", "tbz", "dmg", "appindmginzip":
            
            Logger.log("Processing App Download URL type: \(downloadType) - \(downloadURL)", logType: logType)
            
            // PKG - Universal - Dual Arch DMGs
            if processedAppResults.appDeploymentType == 1 && processedAppResults.appDeploymentArch == 2 && processedAppResults.appIsDualArchCapable == true {
                
                
                Logger.log("Building Universal Dual Arch Package", logType: logType)
                Logger.log("Arch 1: \(downloadURL)", logType: logType)
                Logger.log("Arch 2: \(downloadURLx86)", logType: logType)
                
                var appFiles: [URL]!
                var appFilesFound: [URL]! = []
                var finalDestinationFolder: URL!
                var downloadedVersions: [String] = []
                
                
                let downloadArray = [downloadURL, downloadURLx86]
                for downloadURL in downloadArray {
                    
                    Logger.log("Processing App Download URL: \(downloadURL)", logType: logType)
                    
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
                    let signatureResult = inspectSignatureOfDownloadedSoftware(for: processedAppResults, downloadURL: appFile, inspectionType: "app")
                    
                    Logger.log("  Inspect result: \(signatureResult)", logType: logType)
                    
                    if signatureResult == true {
                        Logger.log("  Signature is valid.", logType: logType)
                    } else {
                        Logger.log("  Signature is invalid.", logType: logType)
                        throw NSError(domain: "ProcessingError", code: 101, userInfo: [NSLocalizedDescriptionKey : "Signature is invalid."])
                    }
                    
                    // Get Version from download
                    let expectedBundleID = processedAppResults.appBundleIdExpected
                    
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
                finalDestinationFolder = AppConstants.intuneomatorCacheFolderURL
                    .appendingPathComponent(processedAppResults.appLabelName)
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
                }
                
                return (url: outputURL!, name: outputAppName!, bundleID: outputAppBundleID!, version: outputAppVersion!)
                
                
            } else {
                
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
                    break
                }
                
                let appFile = appFileFound!
                
                // Check Signature
                let signatureResult = inspectSignatureOfDownloadedSoftware(for: processedAppResults, downloadURL: appFile, inspectionType: "app")
                
                Logger.log("  Inspect result: \(signatureResult)", logType: logType)
                
                if signatureResult == true {
                    Logger.log("  Signature is valid.", logType: logType)
                } else {
                    Logger.log("  Signature is invalid.", logType: logType)
                    throw NSError(domain: "ProcessingError", code: 101, userInfo: [NSLocalizedDescriptionKey : "Signature is invalid."])
                }
                
                // Get Version from download
                let expectedBundleID = processedAppResults.appBundleIdExpected
                
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
                
                // Create the final destination folder
                finalDestinationFolder = downloadFolder
                    .appendingPathComponent(downloadedVersion)
                
                try FileManager.default.createDirectory(at: finalDestinationFolder, withIntermediateDirectories: true)
                
                if processedAppResults.appDeploymentType == 0 {
                    // Create DMG for same app for Intune use
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
                    }
                    
                } else {
                    Logger.log("Standard single arch pkg creation", logType: logType)
                    let pkgCreator = PKGCreator()
                    if let (outputURLResult, outputAppNameResult, outputAppBundleIDResult, outputAppVersionResult) = pkgCreator.createPackage(inputPath: appFile.path, outputDir: finalDestinationFolder.path) {
                        Logger.log("  Package creation succeeded.", logType: logType)
                        outputURL = URL(string: outputURLResult)
                        outputAppName = outputAppNameResult
                        outputAppBundleID = outputAppBundleIDResult
                        outputAppVersion = outputAppVersionResult
                    } else {
                        Logger.log("Package creation failed.", logType: logType)
                    }
                }
                
                Logger.log("  Output URL: \(outputURL!)", logType: logType)
                Logger.log("  Output App Name: \(outputAppName!)", logType: logType)
                Logger.log("  Output App Bundle ID: \(outputAppBundleID!)", logType: logType)
                Logger.log("  Output App Version: \(outputAppVersion!)", logType: logType)
                
                
            }
            
            return (url: outputURL!, name: outputAppName!, bundleID: outputAppBundleID!, version: outputAppVersion!)
            
            
            
        default:
            Logger.log("Unhandled download type: \(downloadType)", logType: logType)
            throw NSError(domain: "ProcessingError", code: 101, userInfo: [NSLocalizedDescriptionKey: "Unsupported file type: \(downloadType)"])
        }
        
    }

    
}
