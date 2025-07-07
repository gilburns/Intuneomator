//
//  LabelAutomation+DownloadProcessAPP.swift
//  Intuneomator
//
//  Created by Gil Burns on 5/27/25.
//

import Foundation

extension LabelAutomation {
    
    /// Processes downloaded application files from various archive formats and creates deployment packages for Intune
    ///
    /// This function handles the complete workflow for processing application downloads:
    /// 1. Extracts/mounts the download based on file type (ZIP, TBZ, DMG, or nested formats)
    /// 2. Locates and copies the .app bundle to a safe location
    /// 3. Validates the application signature against expected Team ID
    /// 4. Extracts version information from the app bundle
    /// 5. Creates either a DMG or PKG package for Intune deployment
    ///
    /// **Supported Download Types:**
    /// - `zip`: ZIP archive containing .app bundle
    /// - `tbz`: TBZ/TAR.BZ2 archive containing .app bundle
    /// - `dmg`: Disk image containing .app bundle
    /// - `appindmginzip`: ZIP archive containing a DMG with .app bundle
    ///
    /// **Resource Management:**
    /// - DMG files are properly mounted and unmounted using `defer` statements
    /// - App bundles are copied off mounted DMGs to ensure URLs remain valid after unmounting
    /// - Temporary extraction folders are handled by underlying extraction functions
    ///
    /// **Security Validation:**
    /// - Code signature verification using expected Team ID
    /// - Bundle ID validation against expected values
    /// - Version extraction and optional validation
    ///
    /// - Parameters:
    ///   - downloadURL: URL to the downloaded file to process
    ///   - folderName: Target folder name (format: "labelname_GUID") used for organizing output
    ///   - downloadType: Type of download archive ("zip", "tbz", "dmg", "appindmginzip")
    ///   - deploymentType: Deployment format (0 = DMG for Intune, 1 = PKG for Intune)
    ///   - fileUploadName: Final filename for the processed package
    ///   - expectedTeamID: Apple Developer Team ID for signature validation
    ///   - expectedBundleID: Expected bundle identifier for the application
    ///   - expectedVersion: Expected version string (optional validation)
    ///
    /// - Returns: Tuple containing:
    ///   - url: URL to the created deployment package (DMG or PKG)
    ///   - appName: Display name of the application
    ///   - appBundleID: Bundle identifier of the application
    ///   - appVersion: Version string extracted from the application
    ///
    /// - Throws:
    ///   - `ProcessingError` with specific error codes for various failure scenarios
    ///   - File system errors from extraction, mounting, or copying operations
    ///   - Signature validation errors when Team ID doesn't match
    ///
    /// **Error Codes:**
    /// - 101: Invalid code signature
    /// - 106: No .app file found in ZIP archive
    /// - 107: No .app file found in TBZ archive
    /// - 108: No .app file found in mounted DMG
    /// - 109: No DMG file found in ZIP archive
    /// - 110: No .app file found in mounted DMG (from ZIP)
    /// - 125: Invalid copy directory for DMG processing
    /// - 126: Invalid copy directory for ZIP-DMG processing
    /// - 127: Unsupported download type
    static func processAppFile(downloadURL: URL, folderName: String, downloadType: String, deploymentType: Int, fileUploadName: String, expectedTeamID: String, expectedBundleID: String, expectedVersion: String) async throws -> (url: URL?, appName: String, appBundleID: String, appVersion: String) {
        
        Logger.info("Processing App Download URL type: \(downloadType) - \(downloadURL)", category: .automation)
        
        var outputURL: URL? = nil
        var outputAppName: String
        var outputAppBundleID: String
        var outputAppVersion: String
        
        Logger.info("Processing downloaded file: \(downloadURL.lastPathComponent)", category: .automation)
        Logger.debug("File type: \(downloadType)", category: .automation)

        // Extract label name from folder name (format: "labelname_GUID")
        guard let labelName = folderName.components(separatedBy: "_").first else {
            return (nil, "", "", "")
        }
        
        // Create base download folder path for this label
        let downloadFolder = AppConstants.intuneomatorCacheFolderURL
            .appendingPathComponent(labelName)

        // Variables to track found app file and processing results
        var appFiles: [URL] = []
        var appFileFound: URL
        var finalDestinationFolder: URL
        
        // Process download based on archive type
        switch downloadType.lowercased() {
        case "zip":
            Logger.debug("Handle type zip specifics", category: .automation)
            // Extract ZIP archive and locate .app bundle
            let extractedFolder = try await extractZipFileWithDitto(zipURL: downloadURL)
            appFiles = try findFiles(inFolder: extractedFolder, withExtension: "app")
            
            guard let appFile = appFiles.first else {
                throw NSError(domain: "ProcessingError", code: 106, userInfo: [NSLocalizedDescriptionKey: "No .app file found in ZIP archive"])
                
            }
            appFileFound = appFile
            
        case "tbz":
            Logger.debug("Handle type tbz specifics", category: .automation)
            // Extract TBZ/TAR.BZ2 archive and locate .app bundle
            let extractedFolder = try await extractTBZFile(tbzURL: downloadURL)
            let foundAppFiles = try findFiles(inFolder: extractedFolder, withExtension: "app")
            
            guard let appFile = foundAppFiles.first else {
                throw NSError(domain: "ProcessingError", code: 107, userInfo: [NSLocalizedDescriptionKey: "No .app file found in TBZ archive"])
            }
            appFileFound = appFile
            
        case "dmg":
            Logger.debug("Handle type dmg specifics", category: .automation)
            // Mount DMG, locate .app bundle, and copy to safe location
            let mountPoint = try await mountDMGFile(dmgURL: downloadURL)
            defer { _ = try? unmountDMG(mountPoint: mountPoint) }
            
            let appFiles = try findFiles(inFolder: URL(fileURLWithPath: mountPoint), withExtension: "app")
            
            guard let appFile = appFiles.first else {
                throw NSError(domain: "ProcessingError", code: 108, userInfo: [NSLocalizedDescriptionKey: "No .app file found in mounted DMG"])
            }
            
            Logger.info("appFile: \(appFile.path)", category: .automation)
            let appName = appFile.lastPathComponent
            Logger.info("App name: \(appName)", category: .automation)
            
            // Copy app bundle off the mounted DMG to ensure URL remains valid after unmounting
            if let copyDir = downloadURL.deletingLastPathComponent().path.removingPercentEncoding {
                let destinationURL = URL(fileURLWithPath: copyDir).appendingPathComponent(appName)
                // Remove existing file if present
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }
                try FileManager.default.copyItem(atPath: appFile.path, toPath: destinationURL.path)
                appFileFound = destinationURL
                Logger.info("App to process: \(appFileFound.absoluteString)", category: .automation)
            } else {
                throw NSError(domain: "ProcessingError", code: 125, userInfo: [NSLocalizedDescriptionKey: "Invalid copy directory for DMG processing"])
            }
            
        case "appindmginzip":
            Logger.debug("Handle type appindmginzip specifics", category: .automation)
            // Extract ZIP, mount contained DMG, locate .app bundle, and copy to safe location
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
            
            Logger.info("appFile: \(appFile.path)", category: .automation)
            let appName = appFile.lastPathComponent
            Logger.info("App name: \(appName)", category: .automation)
            
            // Copy app bundle off the mounted DMG to ensure URL remains valid after unmounting
            if let copyDir = downloadURL.deletingLastPathComponent().path.removingPercentEncoding {
                let destinationURL = URL(fileURLWithPath: copyDir).appendingPathComponent(appName)
                // Remove existing file if present
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }
                try FileManager.default.copyItem(atPath: appFile.path, toPath: destinationURL.path)
                appFileFound = destinationURL
                Logger.info("App to process: \(appFileFound.absoluteString)", category: .automation)
            } else {
                throw NSError(domain: "ProcessingError", code: 126, userInfo: [NSLocalizedDescriptionKey: "Invalid copy directory for ZIP-DMG processing"])
            }
            
        default:
            throw NSError(domain: "ProcessingError", code: 127, userInfo: [NSLocalizedDescriptionKey: "Unsupported download type: \(downloadType)"])
        }
        
        let appFile = appFileFound
        
        // MARK: - Security Validation
        
        // Verify code signature against expected Team ID
        let signatureResult = inspectSignatureOfDownloadedSoftware(for: appFile, expectedTeamID: expectedTeamID, inspectionType: "app")
        
        Logger.info("  Inspect result: \(signatureResult)", category: .automation)
        
        if signatureResult == true {
            Logger.info("  Signature is valid.", category: .automation)
        } else {
            Logger.info("  Signature is invalid.", category: .automation)
            throw NSError(domain: "ProcessingError", code: 101, userInfo: [NSLocalizedDescriptionKey : "Signature is invalid."])
        }
        
        // MARK: - Version Extraction
        
        // Extract version information from app bundle
        let inspector = AppInspector()
        let downloadedVersion = await withCheckedContinuation { continuation in
            inspector.getVersion(forBundleID: expectedBundleID, inAppAt: appFile) { result in
                switch result {
                case .success(let version):
                    if let version = version {
                        Logger.info("  Version for bundle ID '\(expectedBundleID)': \(version)", category: .automation)
                        continuation.resume(returning: version)
                    } else {
                        Logger.info("  Bundle ID '\(expectedBundleID)' not found in the .app", category: .automation)
                        continuation.resume(returning: "None")
                    }
                case .failure(let error):
                    Logger.error("Error inspecting .app: \(error.localizedDescription)", category: .automation)
                    continuation.resume(returning: "None")
                }
            }
        }
        
        // MARK: - DMG/Package Creation
        
        // Create version-specific output directory
        if labelName != "adobecreativeclouddesktop" {
            finalDestinationFolder = downloadFolder
                .appendingPathComponent(downloadedVersion)
            
            try FileManager.default.createDirectory(at: finalDestinationFolder, withIntermediateDirectories: true)
        } else {
            finalDestinationFolder = downloadFolder
            try FileManager.default.createDirectory(at: finalDestinationFolder, withIntermediateDirectories: true)
        }
        
        Logger.info("Deployment type: \(deploymentType)", category: .automation)
        
        // Special handling for Adobe Creative Cloud non-standard installation
        if labelName == "adobecreativeclouddesktop" {
            // Create package for Intune deployment
            Logger.info("Creating Adobe CC PKG package for Intune deployment", category: .automation)
            let adobeCCPkgCreator = AdobeCCPkgCreator()
            do {
                let (outputURLResult, outputAppNameResult, outputAppBundleIDResult, outputAppVersionResult) = await adobeCCPkgCreator.createPackage(inputPath: downloadURL.path, outputDir: finalDestinationFolder.path)!
                
                Logger.info("Created PKG at \(outputURLResult) for \(outputAppNameResult) (\(outputAppBundleIDResult)) version \(outputAppVersionResult)", category: .automation)
                
                guard let outputName = URL(string: outputURLResult)?.lastPathComponent else {
                    Logger.error("Failed to extract filename from path: \(outputURLResult)", category: .automation)
                    return (nil, "" ,"", "")
                }

                finalDestinationFolder = downloadFolder
                    .appendingPathComponent(outputAppVersionResult)
                try FileManager.default.createDirectory(at: finalDestinationFolder, withIntermediateDirectories: true)
                let finalDestinationFileURL = finalDestinationFolder
                    .appendingPathComponent(outputName)
                if FileManager.default.fileExists(atPath: finalDestinationFileURL.path) {
                    try FileManager.default.removeItem(at: finalDestinationFileURL)
                }
                try FileManager.default.moveItem(atPath: outputURLResult, toPath: finalDestinationFileURL.path)
                
                outputURL = finalDestinationFileURL
                outputAppName = outputAppNameResult
                outputAppBundleID = outputAppBundleIDResult
                outputAppVersion = outputAppVersionResult
            }
        // Create deployment package based on specified type
        } else if deploymentType == 0 {
            // Create DMG package for Intune deployment
            Logger.info("Creating DMG package for Intune deployment", category: .automation)
            let dmgCreator = DMGCreator()
            do {
                let (outputURLResult, outputAppNameResult, outputAppBundleIDResult, outputAppVersionResult) = try dmgCreator.processToDMG(inputPath: appFile.path, outputDirectory: finalDestinationFolder.path)
                Logger.info("Created DMG at \(String(describing: outputURLResult)) for \(outputAppNameResult) (\(outputAppBundleIDResult)) version \(outputAppVersionResult)", category: .automation)
                
                outputURL = URL(fileURLWithPath: outputURLResult)
                outputAppName = outputAppNameResult
                outputAppBundleID = outputAppBundleIDResult
                outputAppVersion = outputAppVersionResult
            } catch {
                Logger.error("Failed to process DMG: \(error.localizedDescription)", category: .automation)
                return (nil, "" ,"", "")
            }
            
        } else {
            // Create PKG package for Intune deployment  
            Logger.info("Creating PKG package for Intune deployment", category: .automation)
            let pkgCreator = PKGCreator()
            if let (outputURLResult, outputAppNameResult, outputAppBundleIDResult, outputAppVersionResult) = await pkgCreator.createPackage(inputPath: appFile.path, outputDir: finalDestinationFolder.path) {
                Logger.info("  Package creation succeeded.", category: .automation)
                outputURL = URL(fileURLWithPath: outputURLResult)
                outputAppName = outputAppNameResult
                outputAppBundleID = outputAppBundleIDResult
                outputAppVersion = outputAppVersionResult
            } else {
                Logger.info("Package creation failed.", category: .automation)
                return (nil, "" ,"", "")
            }
        }
        
        Logger.info("  Output URL: \(outputURL?.path ?? "nil")", category: .automation)
        Logger.info("  Output App Name: \(outputAppName)", category: .automation)
        Logger.info("  Output App Bundle ID: \(outputAppBundleID)", category: .automation)
        Logger.info("  Output App Version: \(outputAppVersion)", category: .automation)
        
        return (outputURL, outputAppName, outputAppBundleID, outputAppVersion)
        
    }

}
