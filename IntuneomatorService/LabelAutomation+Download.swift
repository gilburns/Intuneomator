//
//  LabelAutomation+Download.swift
//  Intuneomator
//
//  Created by Gil Burns on 5/22/25.
//

import Foundation

extension LabelAutomation {
    
    // MARK: - Downloaded file cached
    // Check if the version already exists in cache
    static func isVersionCached(forLabel labelName: String, displayName: String, version: String, deploymentType: Int, deploymentArch: Int) throws -> URL {
        let versionCheckPath = AppConstants.intuneomatorCacheFolderURL
            .appendingPathComponent("\(labelName)/\(version)/")
        
        Logger.log("LabelAutomation: Checking cache for version: \(versionCheckPath)", logType: logType)
        Logger.log("Label: \(labelName)", logType: logType)
        Logger.log("Display name: \(displayName)", logType: logType)
        Logger.log("Version: \(version)", logType: logType)
        Logger.log("Deployment type: \(deploymentType)", logType: logType)
        Logger.log("Deployment arch: \(deploymentArch)", logType: logType)
        
        let fileName: String
        
        let fileSuffix: String
        if deploymentType == 0 {
            fileSuffix = "dmg"
        } else {
            fileSuffix = "pkg"
        }
        
        let fileArch: String
        if deploymentArch == 0 {
            fileArch = "arm64"
        } else if deploymentArch == 1 {
            fileArch = "x86_64"
        } else {
            fileArch = "universal"
        }
        
        if deploymentType == 2 {
            fileName = "\(displayName)-\(version).\(fileSuffix)"
        } else  {
            fileName = "\(displayName)-\(version)-\(fileArch).\(fileSuffix)"
        }
        
        
        let fullPath = versionCheckPath.appendingPathComponent(fileName)
        
        if FileManager.default.fileExists(atPath: fullPath.path) {
            Logger.log("LabelAutomation: File exists: \(fullPath.path))", logType: logType)
            return fullPath
        } else {
            Logger.log("LabelAutomation: File does not exists: \(fullPath.path)", logType: logType)
        }
        
        throw NSError(domain: "InvalidURL", code: 100, userInfo: [NSLocalizedDescriptionKey: "Cached file not found: \(fileName)"])
    }
    
    
    // Async version of the function (alternative approach)
    static func isVersionUploadedToIntuneAsync(appInfo: [FilteredIntuneAppInfo], version: String) async -> Bool {
        // Simple direct check
        return appInfo.contains { app in
            return app.primaryBundleVersion == version
        }
    }
    
    
    // MARK: - Download File
    static func downloadFile(for folderName: String, processedAppResults: ProcessedAppResults, downloadArch: String = "Arm") async throws -> URL {
        
        var url: URL
        
        if downloadArch == "Arm" {
            guard let urlForArch = URL(string: processedAppResults.appDownloadURL) else {
                throw NSError(domain: "InvalidURL", code: 100, userInfo: [NSLocalizedDescriptionKey: "Invalid download URL provided"])
            }
            url = urlForArch
        } else {
            guard let urlForArch = URL(string: processedAppResults.appDownloadURLx86) else {
                throw NSError(domain: "InvalidURL", code: 100, userInfo: [NSLocalizedDescriptionKey: "Invalid download URL provided"])
            }
            url = urlForArch
        }
                
        Logger.log("  Starting download from \(String(describing: url))", logType: logType)
        
        let labelName = folderName.components(separatedBy: "_").first ?? folderName
        
        let downloadFolder = AppConstants.intuneomatorCacheFolderURL
            .appendingPathComponent(labelName)
            .appendingPathComponent("tmp")
        
        
        // Create a temporary directory for the download
        let downloadsDir = downloadFolder.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: downloadsDir, withIntermediateDirectories: true)
        
        // Download the file
        let (tempLocation, response) = try await URLSession.shared.download(from: url)
        
        // Validate the response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "NetworkError", code: 101, userInfo: [NSLocalizedDescriptionKey: "Invalid response from server"])
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw NSError(domain: "NetworkError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server returned status code \(httpResponse.statusCode)"])
        }
        
        // Try to extract filename from Content-Disposition header
        var finalFilename: String
        let finalURL = response.url ?? url
        if let lastComponent = finalURL.lastPathComponent.removingPercentEncoding,
           !lastComponent.isEmpty {
            finalFilename = lastComponent
        } else if let contentDisposition = httpResponse.value(forHTTPHeaderField: "Content-Disposition"),
                  let filename = extractFilename(from: contentDisposition) {
            finalFilename = filename
        } else {
            // Fallback if both URL and Content-Disposition failed
            let ext = finalURL.pathExtension.isEmpty ? "dmg" : finalURL.pathExtension
            finalFilename = "\(processedAppResults.appDisplayName)_\(processedAppResults.appVersionExpected).\(ext)"
        }
        
        let destinationURL = downloadsDir
            .appendingPathComponent(finalFilename)
        
        // Remove existing file if present
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
            Logger.log("🗑️ Removed existing file: \(destinationURL.path)", logType: logType)
        }
        
        // Move the file to temp destination
        try FileManager.default.moveItem(at: tempLocation, to: destinationURL)
        
        // Get file size for logging
        let fileAttributes = try FileManager.default.attributesOfItem(atPath: destinationURL.path)
        let fileSizeBytes = fileAttributes[.size] as? Int64 ?? 0
        let fileSizeMB = Double(fileSizeBytes) / 1_048_576
        
        Logger.log("  Download complete: \(finalFilename) (\(String(format: "%.2f", fileSizeMB)) MB)", logType: logType)
        Logger.log("  Downloaded to: \(destinationURL.path)", logType: logType)
        
        Logger.logNoDateStamp("\(labelName)\t\(finalFilename)\t\(String(format: "%.2f", fileSizeMB)) MB\t\(finalURL)", logType: logType)

        
        return destinationURL
    }
    
    // file name from the Content Disposition
    private static func extractFilename(from contentDisposition: String) -> String? {
        // Look for format: attachment; filename="example.pkg"
        let pattern = #"filename="?([^"]+)"?"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: []),
           let match = regex.firstMatch(in: contentDisposition, options: [], range: NSRange(contentDisposition.startIndex..., in: contentDisposition)),
           let range = Range(match.range(at: 1), in: contentDisposition) {
            return String(contentDisposition[range])
        }
        return nil
    }
    
    
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
    
    // MARK: - Helper Functions for download processing
    
    private static func copyToFinalDestination(sourceURL: URL, destinationFolder: URL, keepOriginalName: Bool) throws -> URL {
        
        let fileName = keepOriginalName ? sourceURL.lastPathComponent : UUID().uuidString + "." + sourceURL.pathExtension
        let destinationURL = destinationFolder.appendingPathComponent(fileName)
        
        // Remove existing file if present
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        
        // Copy the file
        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
        
        Logger.log("📁 Copied file to: \(destinationURL.path)", logType: logType)
        return destinationURL
    }
    
    private static func extractZipFile(zipURL: URL) async throws -> URL {
        Logger.log("Extracting ZIP file: \(zipURL.lastPathComponent)", logType: logType)
        
        let extractFolder = zipURL.deletingLastPathComponent()
        
        try FileManager.default.createDirectory(at: extractFolder, withIntermediateDirectories: true)
        
        Logger.log("📦 Extracting ZIP file: \(zipURL.lastPathComponent)", logType: logType)
        
        // Use Process to run unzip command
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-q", zipURL.path, "-d", extractFolder.path]
        
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        
        try process.run()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            throw NSError(domain: "ExtractionError", code: 201, userInfo: [NSLocalizedDescriptionKey: "Failed to extract ZIP file"])
        }
        
        Logger.log("✅ ZIP extraction complete", logType: logType)
        Logger.log("Extracted folder: \(extractFolder.path)", logType: logType)
        return extractFolder
    }
    
    private static func extractZipFileWithDitto(zipURL: URL) async throws -> URL {
        Logger.log("Extracting ZIP file: \(zipURL.lastPathComponent)", logType: logType)
        
        let extractFolder = zipURL.deletingLastPathComponent()
        
        try FileManager.default.createDirectory(at: extractFolder, withIntermediateDirectories: true)
        
        Logger.log("📦 Extracting ZIP file: \(zipURL.lastPathComponent)", logType: logType)
        
        // Use Process to run unzip command
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-x", "-k", zipURL.path, extractFolder.path]
        
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        
        try process.run()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            throw NSError(domain: "ExtractionError", code: 201, userInfo: [NSLocalizedDescriptionKey: "Failed to extract ZIP file"])
        }
        
        Logger.log("✅ ZIP extraction complete", logType: logType)
        Logger.log("Extracted folder: \(extractFolder.path)", logType: logType)
        return extractFolder
    }
    
    
    private static func extractTBZFile(tbzURL: URL) async throws -> URL {
        Logger.log("Extracting TBZ file: \(tbzURL.lastPathComponent)", logType: logType)
        
        let extractFolder = tbzURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: extractFolder, withIntermediateDirectories: true)
        
        // Use Process to run tar command
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        process.arguments = ["-xf", tbzURL.path, "-C", extractFolder.path]
        
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        
        try process.run()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            throw NSError(domain: "ExtractionError", code: 202, userInfo: [NSLocalizedDescriptionKey: "Failed to extract TBZ file"])
        }
        
        Logger.log("✅ TBZ extraction complete", logType: logType)
        return extractFolder
    }
    
    private static func mountDMGFile(dmgURL: URL) async throws -> String {
        Logger.log("  Mounting DMG file: \(dmgURL.lastPathComponent)", logType: logType)
        
        let tempDir = dmgURL.deletingLastPathComponent()

        
        do {
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: nil)
            
            // Convert the DMG first if it has a Software License Agreement
            if dmgHasSLA(at: dmgURL.path) {
                let success = await convertDmgWithSLA(at: dmgURL.path)
                if success {
                Logger.logUser("Successfully converted dmg with SLA", logType: logType)
                } else {
                    Logger.logUser("Failed to convert dmg with SLA", logType: logType)
                    throw NSError(domain: "EditViewController", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert dmg containing pkg"])
                }
            }
        }

        sleep(UInt32(0.5))

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        process.arguments = ["attach", dmgURL.path, "-nobrowse", "-plist"]
                
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        let errorPipe = Pipe()
        process.standardError = errorPipe
            
        try process.run()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            let errorOutput = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "Unknown error"
            Logger.log("Error: Failed to mount .dmg file. \(errorOutput)", logType: logType)
            throw NSError(domain: "MountError", code: 301, userInfo: [NSLocalizedDescriptionKey: "Failed to mount DMG file: \(errorOutput)"])
        }
        
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        
        guard let plist = try PropertyListSerialization.propertyList(from: outputData, options: [], format: nil) as? [String: Any],
              let entities = plist["system-entities"] as? [[String: Any]] else {
            throw NSError(domain: "MountError", code: 302, userInfo: [NSLocalizedDescriptionKey: "Failed to parse mount output"])
        }
        
        for entity in entities {
            if let mountPoint = entity["mount-point"] as? String {
                Logger.log("  DMG mounted at: \(mountPoint)", logType: logType)
                return mountPoint
            }
        }
        
        throw NSError(domain: "MountError", code: 303, userInfo: [NSLocalizedDescriptionKey: "No mount point found in DMG output"])
    }
    
    private static func dmgHasSLA(at path: String) -> Bool {
        let process = Process()
        process.launchPath = "/usr/bin/hdiutil"
        process.arguments = ["imageinfo", path, "-plist"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.launch()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            Logger.log("Error: Failed to check for SLA in DMG.", logType: logType)
            return false
        }
        
        let outputData = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let plist = try? PropertyListSerialization.propertyList(from: outputData, options: [], format: nil) as? [String: Any],
              let properties = plist["Properties"] as? [String: Any],
              let hasSLA = properties["Software License Agreement"] as? Bool else {
            return false
        }
        
        return hasSLA
    }
    
    
    private static func convertDmgWithSLA(at path: String) async -> Bool {
        let fileName = URL(fileURLWithPath: path).lastPathComponent
        let tempDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory())
        let tempFileURL = tempDirectoryURL.appendingPathComponent(fileName)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        process.arguments = ["convert", "-format", "UDRW", "-o", tempFileURL.path, path]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
        } catch {
            Logger.logUser("Error: Could not launch hdiutil: \(error)", logType: logType)
            return false
        }

        // Wait asynchronously for the process to finish
        await withCheckedContinuation { continuation in
            process.terminationHandler = { _ in
                continuation.resume()
            }
        }

        guard process.terminationStatus == 0 else {
            Logger.logUser("Error: hdiutil failed to convert DMG with SLA.", logType: logType)
            return false
        }

        guard FileManager.default.fileExists(atPath: tempFileURL.path) else {
            Logger.logUser("Error: Converted file not found at expected location.", logType: logType)
            return false
        }

        do {
            try FileManager.default.removeItem(atPath: path)
            try FileManager.default.moveItem(atPath: tempFileURL.path, toPath: path)
        } catch {
            Logger.logUser("Failed to finalize converted DMG: \(error)", logType: logType)
            return false
        }

        return true
    }

    
    private static func unmountDMG(mountPoint: String) throws {
        Logger.log("  Unmounting DMG: \(mountPoint)", logType: logType)
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        process.arguments = ["detach", mountPoint, "-force"]
        
        // Redirect stdout to /dev/null but capture stderr
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus == 0 {
            Logger.log("  DMG unmounted successfully", logType: logType)
        } else {
            // Capture error output for logging
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            Logger.log("  Failed to unmount DMG: \(errorMessage)", logType: logType)
        }
    }
    
    
    private static func findFiles(inFolder folderURL: URL, withExtension ext: String) throws -> [URL] {
        let fileManager = FileManager.default
        let enumerator = fileManager.enumerator(at: folderURL, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
        
        var foundFiles = [URL]()
        
        while let fileURL = enumerator?.nextObject() as? URL {
            // Special case for .app bundles which are directories
            if ext.lowercased() == "app" {
                let resourceValues = try fileURL.resourceValues(forKeys: [.isDirectoryKey])
                if resourceValues.isDirectory == true && fileURL.pathExtension.lowercased() == "app" {
                    foundFiles.append(fileURL)
                }
            } else {
                // Normal files
                let resourceValues = try fileURL.resourceValues(forKeys: [.isDirectoryKey])
                if resourceValues.isDirectory == false && fileURL.pathExtension.lowercased() == ext.lowercased() {
                    foundFiles.append(fileURL)
                }
            }
        }
        
        Logger.log("  Found \(foundFiles.count) files with extension .\(ext) in \(folderURL.path)", logType: logType)
        for file in foundFiles {
            Logger.log("   - \(file.lastPathComponent)", logType: logType)
        }
        
        // Sort by shortest full path length
        foundFiles.sort { $0.path.count < $1.path.count }

        return foundFiles
    }

}
