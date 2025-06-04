//
//  LabelAutomation+DownloadProcessPKG.swift
//  Intuneomator
//
//  Created by Gil Burns on 5/27/25.
//

import Foundation

extension LabelAutomation {
    
    static func processPkgFile(downloadURL: URL, folderName: String, downloadType: String, fileUploadName: String, expectedTeamID: String, expectedBundleID: String, expectedVersion: String) async throws -> (url: URL?, bundleID: String, version: String) {
        
        let pkgToProcessURL: URL
        
        var outputURL: URL? = nil
        
        guard let labelName = folderName.components(separatedBy: "_").first else {
            return (nil, "", "")
        }
        
        let downloadFolder = AppConstants.intuneomatorCacheFolderURL
            .appendingPathComponent(labelName)
        
        
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
            return (nil, "", "")
        }
        
        
        // Check Signature
        let signatureResult = inspectSignatureOfDownloadedSoftware(for: pkgToProcessURL, expectedTeamID: expectedTeamID, inspectionType: "pkg")
        
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
        let packageID = expectedBundleID
        
        let downloadedVersion = await withCheckedContinuation { continuation in
            pkgInspector.getVersion(forPackageID: packageID, inPkgAt: pkgURL) { result in
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
        
        if downloadedVersion != expectedVersion {
            
            
        }
        
        
        // Create the final destination folder
        let finalDestinationFolder = downloadFolder
            .appendingPathComponent(downloadedVersion)
        
        try FileManager.default.createDirectory(at: finalDestinationFolder, withIntermediateDirectories: true)
        
        //set output full path
        let destinationURL = finalDestinationFolder
            .appendingPathComponent(fileUploadName)
        
        // Remove existing file if present
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        
        // Copy the file
        try FileManager.default.copyItem(at: pkgToProcessURL, to: destinationURL)
        
        Logger.log("📁 Copied file to: \(destinationURL.path)", logType: logType)
        
        
        Logger.log("Output URL: \(destinationURL)", logType: logType)
        Logger.log("Output App Bundle ID: \(packageID)", logType: logType)
        Logger.log("Output App Version: \(downloadedVersion)", logType: logType)
        
        outputURL = destinationURL
        
        return (url: outputURL, bundleID: packageID, version: downloadedVersion)
        
    }
    
}
