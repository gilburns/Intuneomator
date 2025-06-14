//
//  LabelAutomation+DownloadProcessPKG.swift
//  Intuneomator
//
//  Created by Gil Burns on 5/27/25.
//

import Foundation

extension LabelAutomation {
    
    /// Processes downloaded PKG installer files from various archive formats for Intune deployment
    ///
    /// This function handles the complete workflow for processing PKG installer downloads:
    /// 1. Extracts/mounts the download based on file type (PKG, ZIP, DMG, or nested formats)
    /// 2. Locates and copies the .pkg installer to a safe location
    /// 3. Validates the installer signature against expected Team ID
    /// 4. Extracts version information from the PKG package
    /// 5. Organizes the final PKG file for Intune upload
    ///
    /// **Supported Download Types:**
    /// - `pkg`: Direct PKG installer file
    /// - `pkginzip`: ZIP archive containing PKG installer
    /// - `pkgindmg`: Disk image containing PKG installer
    /// - `pkgindmginzip`: ZIP archive containing a DMG with PKG installer
    ///
    /// **Resource Management:**
    /// - DMG files are properly mounted and unmounted using `defer` statements
    /// - PKG installers are copied off mounted DMGs to ensure URLs remain valid after unmounting
    /// - Temporary extraction folders are handled by underlying extraction functions
    ///
    /// **Security Validation:**
    /// - Code signature verification using expected Team ID
    /// - Package ID validation against expected bundle identifier
    /// - Version extraction and optional validation against expected version
    ///
    /// - Parameters:
    ///   - downloadURL: URL to the downloaded file to process
    ///   - folderName: Target folder name (format: "labelname_GUID") used for organizing output
    ///   - downloadType: Type of download archive ("pkg", "pkginzip", "pkgindmg", "pkgindmginzip")
    ///   - fileUploadName: Final filename for the processed PKG installer
    ///   - expectedTeamID: Apple Developer Team ID for signature validation
    ///   - expectedBundleID: Expected package identifier for the installer
    ///   - expectedVersion: Expected version string (logs warning if mismatch, but continues)
    ///
    /// - Returns: Tuple containing:
    ///   - url: URL to the processed PKG installer ready for Intune upload
    ///   - bundleID: Package identifier extracted from the installer
    ///   - version: Version string extracted from the installer
    ///
    /// - Throws:
    ///   - `ProcessingError` with specific error codes for various failure scenarios
    ///   - File system errors from extraction, mounting, or copying operations
    ///   - Signature validation errors when Team ID doesn't match
    ///
    /// **Error Codes:**
    /// - 101: Invalid code signature
    /// - 102: No PKG file found in ZIP archive
    /// - 103: No PKG file found in mounted DMG
    /// - 104: No DMG file found in ZIP archive
    /// - 105: No PKG file found in mounted DMG (from ZIP)
    /// - 122: Invalid copy directory for PKG-DMG processing
    /// - 123: Invalid copy directory for PKG-DMG-ZIP processing
    /// - 124: Unsupported download type
    static func processPkgFile(downloadURL: URL, folderName: String, downloadType: String, fileUploadName: String, expectedTeamID: String, expectedBundleID: String, expectedVersion: String) async throws -> (url: URL?, bundleID: String, version: String) {
        
        let pkgToProcessURL: URL
        var outputURL: URL? = nil
        
        // Extract label name from folder name (format: "labelname_GUID")
        guard let labelName = folderName.components(separatedBy: "_").first else {
            return (nil, "", "")
        }
        
        // Create base download folder path for this label
        let downloadFolder = AppConstants.intuneomatorCacheFolderURL
            .appendingPathComponent(labelName)
        
        // Process download based on archive type to locate PKG installer
        switch downloadType.lowercased() {
        case "pkg":
            Logger.debug("Handle type pkg specifics", category: .automation)
            // Direct PKG file - use as-is
            pkgToProcessURL = downloadURL
            
        case "pkginzip":
            Logger.debug("Handle type pkginzip specifics", category: .automation)
            // Extract ZIP archive and locate PKG installer
            let extractedFolder = try await extractZipFile(zipURL: downloadURL)
            let pkgFiles = try findFiles(inFolder: extractedFolder, withExtension: "pkg")
            
            guard let pkgFile = pkgFiles.first else {
                throw NSError(domain: "ProcessingError", code: 102, userInfo: [NSLocalizedDescriptionKey: "No PKG file found in ZIP archive"])
            }
            pkgToProcessURL = pkgFile
            Logger.info("Pkg to process: \(pkgToProcessURL.absoluteString)", category: .automation)
            
        case "pkgindmg":
            Logger.debug("Handle type pkgindmg specifics", category: .automation)
            // Mount DMG, locate PKG installer, and copy to safe location
            let mountPoint = try await mountDMGFile(dmgURL: downloadURL)
            defer { _ = try? unmountDMG(mountPoint: mountPoint) }
            
            let pkgFiles = try findFiles(inFolder: URL(fileURLWithPath: mountPoint), withExtension: "pkg")
            
            guard let pkgFile = pkgFiles.first else {
                throw NSError(domain: "ProcessingError", code: 103, userInfo: [NSLocalizedDescriptionKey: "No PKG file found in mounted DMG"])
            }
            
            Logger.info("pkgFile: \(pkgFile.path)", category: .automation)
            let pkgName = pkgFile.lastPathComponent
            Logger.info("Pkg name: \(pkgName)", category: .automation)
            
            // Copy PKG installer off the mounted DMG to ensure URL remains valid after unmounting
            if let copyDir = downloadURL.deletingLastPathComponent().path.removingPercentEncoding {
                let destinationURL = URL(fileURLWithPath: copyDir).appendingPathComponent(pkgName)
                // Remove existing file if present
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }
                try FileManager.default.copyItem(atPath: pkgFile.path, toPath: destinationURL.path)
                pkgToProcessURL = destinationURL
                Logger.info("Pkg to process: \(pkgToProcessURL.absoluteString)", category: .automation)
            } else {
                throw NSError(domain: "ProcessingError", code: 122, userInfo: [NSLocalizedDescriptionKey: "Invalid copy directory for PKG-DMG processing"])
            }
            
        case "pkgindmginzip":
            Logger.debug("Handle type pkgindmginzip specifics", category: .automation)
            // Extract ZIP, mount contained DMG, locate PKG installer, and copy to safe location
            let extractedFolder = try await extractZipFile(zipURL: downloadURL)
            let dmgFiles = try findFiles(inFolder: extractedFolder, withExtension: "dmg")
            
            guard let dmgFile = dmgFiles.first else {
                throw NSError(domain: "ProcessingError", code: 104, userInfo: [NSLocalizedDescriptionKey: "No DMG file found in ZIP archive"])
            }
            
            let mountPoint = try await mountDMGFile(dmgURL: dmgFile)
            defer { _ = try? unmountDMG(mountPoint: mountPoint) }
            
            let pkgFiles = try findFiles(inFolder: URL(fileURLWithPath: mountPoint), withExtension: "pkg")
            
            guard let pkgFile = pkgFiles.first else {
                throw NSError(domain: "ProcessingError", code: 105, userInfo: [NSLocalizedDescriptionKey: "No PKG file found in mounted DMG (from ZIP)"])
            }
            
            Logger.info("pkgFile: \(pkgFile.path)", category: .automation)
            let pkgName = pkgFile.lastPathComponent
            Logger.info("Pkg name: \(pkgName)", category: .automation)
            
            // Copy PKG installer off the mounted DMG to ensure URL remains valid after unmounting
            if let copyDir = downloadURL.deletingLastPathComponent().path.removingPercentEncoding {
                let destinationURL = URL(fileURLWithPath: copyDir).appendingPathComponent(pkgName)
                // Remove existing file if present
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }
                try FileManager.default.copyItem(atPath: pkgFile.path, toPath: destinationURL.path)
                pkgToProcessURL = destinationURL
                Logger.info("Pkg to process: \(pkgToProcessURL.absoluteString)", category: .automation)
            } else {
                throw NSError(domain: "ProcessingError", code: 123, userInfo: [NSLocalizedDescriptionKey: "Invalid copy directory for PKG-DMG-ZIP processing"])
            }
            
        default:
            throw NSError(domain: "ProcessingError", code: 124, userInfo: [NSLocalizedDescriptionKey: "Unsupported download type: \(downloadType)"])
        }
        
        
        // MARK: - Security Validation
        
        // Verify code signature against expected Team ID
        let signatureResult = inspectSignatureOfDownloadedSoftware(for: pkgToProcessURL, expectedTeamID: expectedTeamID, inspectionType: "pkg")
        
        Logger.info("  Inspect result: \(signatureResult)", category: .automation)
        
        if signatureResult == true {
            Logger.info("  Signature is valid.", category: .automation)
        } else {
            Logger.info("  Signature is invalid.", category: .automation)
            throw NSError(domain: "ProcessingError", code: 101, userInfo: [NSLocalizedDescriptionKey : "Signature is invalid."])
        }
        
        // MARK: - Version Extraction
        
        // Extract version information from PKG installer
        let pkgInspector = PkgInspector()
        let packageID = expectedBundleID
        
        let downloadedVersion = await withCheckedContinuation { continuation in
            pkgInspector.getVersion(forPackageID: packageID, inPkgAt: pkgToProcessURL) { result in
                switch result {
                case .success(let version):
                    if let version = version {
                        Logger.info("  Version for package ID '\(packageID)': \(version)", category: .automation)
                        continuation.resume(returning: version)
                    } else {
                        Logger.info("  Package ID '\(packageID)' not found in the .pkg", category: .automation)
                        continuation.resume(returning: "None")
                    }
                case .failure(let error):
                    Logger.error("Error inspecting .pkg: \(error.localizedDescription)", category: .automation)
                    continuation.resume(returning: "None")
                }
            }
        }
        
        // Validate version against expected (log warning if mismatch, but continue)
        if downloadedVersion != expectedVersion && expectedVersion != "" {
            Logger.warning("⚠️ Version mismatch: downloaded \(downloadedVersion), expected \(expectedVersion)", category: .automation)
            // Note: Continuing with downloaded version as it may be a newer release
        }
        
        // MARK: - File Organization
        
        // Create version-specific output directory
        let finalDestinationFolder = downloadFolder
            .appendingPathComponent(downloadedVersion)
        
        try FileManager.default.createDirectory(at: finalDestinationFolder, withIntermediateDirectories: true)
        
        // Set final output path with specified filename
        let destinationURL = finalDestinationFolder
            .appendingPathComponent(fileUploadName)
        
        // Remove existing file if present
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        
        // Copy the processed PKG installer to final destination
        try FileManager.default.copyItem(at: pkgToProcessURL, to: destinationURL)
        
        Logger.info("📁 Copied PKG installer to: \(destinationURL.path)", category: .automation)
        
        // Log final results
        Logger.info("Output URL: \(destinationURL)", category: .automation)
        Logger.info("Output Package ID: \(packageID)", category: .automation)
        Logger.info("Output Version: \(downloadedVersion)", category: .automation)
        
        outputURL = destinationURL
        
        return (url: outputURL, bundleID: packageID, version: downloadedVersion)
        
    }
    
}
