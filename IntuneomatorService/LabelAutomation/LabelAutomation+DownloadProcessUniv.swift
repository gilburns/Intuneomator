//
//  LabelAutomation+DownloadProcessUniv.swift
//  Intuneomator
//
//  Created by Gil Burns on 5/27/25.
//

import Foundation

extension LabelAutomation {
    
    /// Processes dual-architecture application downloads to create universal PKG installers for Intune
    ///
    /// This function handles the complete workflow for processing dual-architecture (ARM64 + x86_64) application downloads:
    /// 1. Downloads and extracts/mounts both architecture-specific app bundles from various archive formats
    /// 2. Validates that both apps have matching versions and expected architectures
    /// 3. Verifies code signatures against expected Team ID for both apps
    /// 4. Creates a universal PKG installer containing both architectures for Intune deployment
    ///
    /// **Supported Download Types:**
    /// - `zip`: ZIP archives containing .app bundles
    /// - `tbz`: TBZ/TAR.BZ2 archives containing .app bundles  
    /// - `dmg`: Disk images containing .app bundles
    /// - `appindmginzip`: ZIP archives containing DMGs with .app bundles
    ///
    /// **Architecture Validation:**
    /// - Ensures exactly 2 app bundles are found (one ARM64, one x86_64)
    /// - Validates architecture requirements using `validateAppArchitectures()`
    /// - Verifies both apps have identical version numbers
    ///
    /// **Resource Management:**
    /// - DMG files are properly mounted and unmounted using `defer` statements
    /// - App bundles are copied off mounted DMGs to ensure URLs remain valid after unmounting
    /// - Temporary extraction folders are handled by underlying extraction functions
    ///
    /// **Security Validation:**
    /// - Code signature verification using expected Team ID for both app bundles
    /// - Bundle ID validation against expected values
    /// - Version consistency checking between architectures
    ///
    /// - Parameters:
    ///   - downloadURL: URL to the ARM64 architecture download
    ///   - downloadURLx86_64: URL to the x86_64 architecture download
    ///   - folderName: Target folder name (format: "labelname_GUID") used for organizing output
    ///   - downloadType: Type of download archive ("zip", "tbz", "dmg", "appindmginzip")
    ///   - fileUploadName: Final filename for the universal PKG installer
    ///   - expectedTeamID: Apple Developer Team ID for signature validation
    ///   - expectedBundleID: Expected bundle identifier for both applications
    ///
    /// - Returns: Tuple containing:
    ///   - url: URL to the created universal PKG installer
    ///   - appName: Display name of the application
    ///   - appBundleID: Bundle identifier of the application
    ///   - appVersion: Version string (verified to match across both architectures)
    ///
    /// - Throws:
    ///   - `ProcessingError` with specific error codes for various failure scenarios
    ///   - File system errors from extraction, mounting, or copying operations
    ///   - Signature validation errors when Team ID doesn't match
    ///   - Architecture validation errors when apps don't meet dual-arch requirements
    ///   - Version mismatch errors when app versions differ between architectures
    ///
    /// **Error Codes:**
    /// - 101: Invalid code signature
    /// - 106: No .app file found in ZIP archive
    /// - 107: No .app file found in TBZ archive
    /// - 108: No .app file found in mounted DMG
    /// - 109: No DMG file found in ZIP archive
    /// - 110: No .app file found in mounted DMG (from ZIP)
    /// - 111: Expected exactly 2 app versions, found different count
    /// - 112: App versions do not match between architectures
    /// - 113: Expected exactly 2 app files, found different count
    /// - 120: Invalid copy directory for DMG processing
    /// - 121: Invalid copy directory for ZIP-DMG processing
    static func processDualAppFiles(downloadURL: URL, downloadURLx86_64: URL, folderName: String, downloadType: String, fileUploadName: String, expectedTeamID: String, expectedBundleID: String) async throws -> (url: URL?, appName: String, appBundleID: String, appVersion: String)  {
        
        
        Logger.info("Building Universal Dual Arch Package", category: .automation)
        Logger.info("ARM64 URL: \(downloadURL)", category: .automation)
        Logger.info("x86_64 URL: \(downloadURLx86_64)", category: .automation)
        
        // Variables to track processing results
        var appFiles: [URL] = []
        var appFilesFound: [URL] = []
        var finalDestinationFolder: URL
        var downloadedVersions: [String] = []
        
        var outputURL: URL? = nil
        var outputAppName: String
        var outputAppBundleID: String
        var outputAppVersion: String

        // Extract label name from folder name (format: "labelname_GUID")
        guard let labelName = folderName.components(separatedBy: "_").first else {
            return (nil, "", "", "")
        }
        
        // Create base download folder path for this label
        let downloadFolder = AppConstants.intuneomatorCacheFolderURL
            .appendingPathComponent(labelName)

        // Process both architecture downloads (ARM64 first, then x86_64)
        let downloadArray = [downloadURL, downloadURLx86_64]
        for (index, downloadURL) in downloadArray.enumerated() {
            let archName = index == 0 ? "ARM64" : "x86_64"
            Logger.info("Processing \(archName) URL: \(downloadURL)", category: .automation)
            
            // Process download based on archive type
            switch downloadType.lowercased() {
            case "zip":
                Logger.debug("Handle type zip specifics for \(archName)", category: .automation)
                // Extract ZIP archive and locate .app bundle
                let extractedFolder = try await extractZipFileWithDitto(zipURL: downloadURL)
                appFiles = try findFiles(inFolder: extractedFolder, withExtension: "app")
                
                guard let appFile = appFiles.first else {
                    throw NSError(domain: "ProcessingError", code: 106, userInfo: [NSLocalizedDescriptionKey: "No .app file found in ZIP archive for \(archName)"])
                }
                appFilesFound += [appFile]
                
            case "tbz":
                Logger.debug("Handle type tbz specifics for \(archName)", category: .automation)
                // Extract TBZ/TAR.BZ2 archive and locate .app bundle
                let extractedFolder = try await extractTBZFile(tbzURL: downloadURL)
                let foundAppFiles = try findFiles(inFolder: extractedFolder, withExtension: "app")
                
                guard let appFile = foundAppFiles.first else {
                    throw NSError(domain: "ProcessingError", code: 107, userInfo: [NSLocalizedDescriptionKey: "No .app file found in TBZ archive for \(archName)"])
                }
                appFilesFound += [appFile]
                
            case "dmg":
                Logger.debug("Handle type dmg specifics for \(archName)", category: .automation)
                // Mount DMG, locate .app bundle, and copy to safe location
                let mountPoint = try await mountDMGFile(dmgURL: downloadURL)
                defer { _ = try? unmountDMG(mountPoint: mountPoint) }
                
                let appFiles = try findFiles(inFolder: URL(fileURLWithPath: mountPoint), withExtension: "app")
                
                guard let appFile = appFiles.first else {
                    throw NSError(domain: "ProcessingError", code: 108, userInfo: [NSLocalizedDescriptionKey: "No .app file found in mounted DMG for \(archName)"])
                }
                
                Logger.info("\(archName) appFile: \(appFile.path)", category: .automation)
                let appName = appFile.lastPathComponent
                Logger.info("\(archName) App name: \(appName)", category: .automation)
                
                // Copy app bundle off the mounted DMG to ensure URL remains valid after unmounting
                if let copyDir = downloadURL.deletingLastPathComponent().path.removingPercentEncoding {
                    let destinationURL = URL(fileURLWithPath: copyDir).appendingPathComponent(appName)
                    // Remove existing file if present
                    if FileManager.default.fileExists(atPath: destinationURL.path) {
                        try FileManager.default.removeItem(at: destinationURL)
                    }
                    try FileManager.default.copyItem(atPath: appFile.path, toPath: destinationURL.path)
                    
                    appFilesFound += [destinationURL]
                    
                    Logger.info("\(archName) App to process: \(destinationURL.path)", category: .automation)
                } else {
                    throw NSError(domain: "ProcessingError", code: 120, userInfo: [NSLocalizedDescriptionKey: "Invalid copy directory for DMG processing (\(archName))"])
                }
                
            case "appindmginzip":
                Logger.debug("Handle type appindmginzip specifics for \(archName)", category: .automation)
                // Extract ZIP, mount contained DMG, locate .app bundle, and copy to safe location
                let extractedFolder = try await extractZipFile(zipURL: downloadURL)
                let dmgFiles = try findFiles(inFolder: extractedFolder, withExtension: "dmg")
                
                guard let dmgFile = dmgFiles.first else {
                    throw NSError(domain: "ProcessingError", code: 109, userInfo: [NSLocalizedDescriptionKey: "No DMG file found in ZIP archive for \(archName)"])
                }
                
                let mountPoint = try await mountDMGFile(dmgURL: dmgFile)
                defer { _ = try? unmountDMG(mountPoint: mountPoint) }
                let appFiles = try findFiles(inFolder: URL(fileURLWithPath: mountPoint), withExtension: "app")
                
                guard let appFile = appFiles.first else {
                    throw NSError(domain: "ProcessingError", code: 110, userInfo: [NSLocalizedDescriptionKey: "No .app file found in mounted DMG (from ZIP) for \(archName)"])
                }
                
                Logger.info("\(archName) appFile: \(appFile.path)", category: .automation)
                let appName = appFile.lastPathComponent
                Logger.info("\(archName) App name: \(appName)", category: .automation)
                
                // Copy app bundle off the mounted DMG to ensure URL remains valid after unmounting
                if let copyDir = downloadURL.deletingLastPathComponent().path.removingPercentEncoding {
                    let destinationURL = URL(fileURLWithPath: copyDir).appendingPathComponent(appName)
                    // Remove existing file if present
                    if FileManager.default.fileExists(atPath: destinationURL.path) {
                        try FileManager.default.removeItem(at: destinationURL)
                    }
                    try FileManager.default.copyItem(atPath: appFile.path, toPath: destinationURL.path)
                    
                    appFilesFound += [destinationURL]
                    
                    Logger.info("\(archName) App to process: \(destinationURL.path)", category: .automation)
                } else {
                    throw NSError(domain: "ProcessingError", code: 121, userInfo: [NSLocalizedDescriptionKey: "Invalid copy directory for ZIP-DMG processing (\(archName))"])
                }
                
            default:
                break
            }
            
            
        }
        
        // MARK: - Security and Version Validation
        
        // Validate signatures and extract versions for both app bundles
        for (index, appFile) in appFilesFound.enumerated() {
            let archName = index == 0 ? "ARM64" : "x86_64"
            Logger.info("Validating \(archName) app: \(appFile.path)", category: .automation)
            
            // Verify code signature against expected Team ID
            let signatureResult = inspectSignatureOfDownloadedSoftware(for: appFile, expectedTeamID: expectedTeamID, inspectionType: "app")
            
            Logger.info("  \(archName) signature result: \(signatureResult)", category: .automation)
            
            if signatureResult == true {
                Logger.info("  \(archName) signature is valid.", category: .automation)
            } else {
                Logger.info("  \(archName) signature is invalid.", category: .automation)
                throw NSError(domain: "ProcessingError", code: 101, userInfo: [NSLocalizedDescriptionKey : "\(archName) signature is invalid."])
            }
            
            // Extract version information from app bundle
            let inspector = AppInspector()
            let downloadedVersion = await withCheckedContinuation { continuation in
                inspector.getVersion(forBundleID: expectedBundleID, inAppAt: appFile) { result in
                    switch result {
                    case .success(let version):
                        if let version = version {
                            Logger.info("  \(archName) version for bundle ID '\(expectedBundleID)': \(version)", category: .automation)
                            continuation.resume(returning: version)
                        } else {
                            Logger.info("  Bundle ID '\(expectedBundleID)' not found in the \(archName) .app", category: .automation)
                            continuation.resume(returning: "None")
                        }
                    case .failure(let error):
                        Logger.error("Error inspecting \(archName) .app: \(error.localizedDescription)", category: .automation)
                        continuation.resume(returning: "None")
                    }
                }
            }
            
            downloadedVersions.append(downloadedVersion)
        }
        
        // MARK: - Version and Architecture Validation
        
        // Ensure we have exactly 2 versions (one per architecture)
        guard downloadedVersions.count == 2 else {
            throw NSError(domain: "ProcessingError", code: 111, userInfo: [NSLocalizedDescriptionKey: "Expected exactly 2 app versions, found \(downloadedVersions.count)"])
        }
        
        // Verify both architectures have matching versions
        if downloadedVersions[0] != downloadedVersions[1] {
            Logger.info("🛑 Architecture versions do not match!", category: .automation)
            Logger.info("ARM64 version: \(downloadedVersions[0])", category: .automation)
            Logger.info("x86_64 version: \(downloadedVersions[1])", category: .automation)
            throw NSError(domain: "ProcessingError", code: 112, userInfo: [NSLocalizedDescriptionKey: "App versions do not match: ARM64(\(downloadedVersions[0])) vs x86_64(\(downloadedVersions[1]))"])
        } else {
            Logger.info("✅ Architecture versions match: \(downloadedVersions[0])", category: .automation)
        }
        
        // Ensure we have exactly 2 app files (one per architecture)
        guard appFilesFound.count == 2 else {
            throw NSError(domain: "ProcessingError", code: 113, userInfo: [NSLocalizedDescriptionKey: "Expected exactly 2 app files, found \(appFilesFound.count)"])
        }
        
        // Validate that the apps meet dual-architecture requirements
        let expectedArchitectures: [AppArchitecture] = [.arm64, .x86_64]
        do {
            try validateAppArchitectures(urls: appFilesFound, expected: expectedArchitectures)
            Logger.info("✅ App architectures validated: ARM64 + x86_64", category: .automation)
        } catch {
            Logger.info("❌ Architecture validation failed: \(error)", category: .automation)
            throw error
        }
        
        // MARK: - Universal Package Creation
        
        // Create version-specific output directory
        finalDestinationFolder = downloadFolder
            .appendingPathComponent(downloadedVersions[0])
        
        try FileManager.default.createDirectory(at: finalDestinationFolder, withIntermediateDirectories: true)
        
        // Create universal PKG installer containing both architectures
        Logger.info("Creating universal PKG installer", category: .automation)
        Logger.info("ARM64 input: \(appFilesFound[0].path)", category: .automation)
        Logger.info("x86_64 input: \(appFilesFound[1].path)", category: .automation)
        Logger.info("Output directory: \(finalDestinationFolder.path)", category: .automation)
        
        let pkgCreator = PKGCreatorUniversal()
        if let (outputURLResult, outputAppNameResult, outputAppBundleIDResult, outputAppVersionResult) = pkgCreator.createUniversalPackage(inputPathArm64: appFilesFound[0].path, inputPathx86_64: appFilesFound[1].path, outputDir: finalDestinationFolder.path) {
            Logger.info("✅ Universal package creation succeeded.", category: .automation)
            
            outputURL = URL(fileURLWithPath: outputURLResult)
            outputAppName = outputAppNameResult
            outputAppBundleID = outputAppBundleIDResult
            outputAppVersion = outputAppVersionResult
            
            Logger.info("Created universal PKG: \(outputURLResult)", category: .automation)
            Logger.info("App name: \(outputAppNameResult)", category: .automation)
            Logger.info("Bundle ID: \(outputAppBundleIDResult)", category: .automation)
            Logger.info("Version: \(outputAppVersionResult)", category: .automation)
        } else {
            Logger.info("❌ Universal package creation failed.", category: .automation)
            outputURL = nil
            outputAppName = ""
            outputAppBundleID = ""
            outputAppVersion = ""
        }
        
        return (outputURL, outputAppName, outputAppBundleID, outputAppVersion)
        
    }
    
}
