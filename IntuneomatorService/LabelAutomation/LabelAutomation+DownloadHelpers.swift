//
//  LabelAutomation+DownloadHelpers.swift
//  Intuneomator
//
//  Created by Gil Burns on 5/27/25.
//

import Foundation

extension LabelAutomation {
 
    static func logDownloadFileInfo(forLabel labelName: String, destinationURL: URL, finalFilename: String, finalURL: URL) {
        
        do {
            // Get file size for logging
            let fileAttributes = try FileManager.default.attributesOfItem(atPath: destinationURL.path)
            let fileSizeBytes = fileAttributes[.size] as? Int64 ?? 0
            let fileSizeMB = Double(fileSizeBytes) / 1_048_576
                        
            Logger.logNoDateStamp("\(labelName)\t\(finalFilename)\t\(String(format: "%.2f", fileSizeMB)) MB\t\(finalURL.path)", logType: "Download")
        } catch {
            
        }
                
    }
    
    // MARK: - Helper Functions for download processing
    
    static func copyToFinalDestination(sourceURL: URL, destinationFolder: URL, keepOriginalName: Bool) throws -> URL {
        
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
    
    static func extractZipFile(zipURL: URL) async throws -> URL {
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
    
    static func extractZipFileWithDitto(zipURL: URL) async throws -> URL {
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
    
    
    static func extractTBZFile(tbzURL: URL) async throws -> URL {
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
    
    static func mountDMGFile(dmgURL: URL) async throws -> String {
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
    
    static func dmgHasSLA(at path: String) -> Bool {
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
    
    
    static func convertDmgWithSLA(at path: String) async -> Bool {
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

    
    static func unmountDMG(mountPoint: String) throws {
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
    
    
    static func findFiles(inFolder folderURL: URL, withExtension ext: String) throws -> [URL] {
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
