//
//  LabelAutomation+DownloadHelpers.swift
//  Intuneomator
//
//  Created by Gil Burns on 5/27/25.
//

import Foundation

// MARK: - Download Helper Functions Extension

/// Extension providing utility functions for download processing and file management
/// Supports various archive formats, file system operations, and logging for automation workflows
extension LabelAutomation {
 
    // MARK: - Download Logging
    
    /// Logs download completion information including file size and destination path
    /// Creates structured log entries for tracking downloaded files during automation
    /// - Parameters:
    ///   - labelName: The Installomator label name being processed
    ///   - destinationURL: The temporary download location
    ///   - finalFilename: The final filename after processing
    ///   - finalURL: The final destination path
    static func logDownloadFileInfo(forLabel labelName: String, destinationURL: URL, finalFilename: String, finalURL: URL) {
        
        do {
            // Calculate file size in MB for readable logging format
            let fileAttributes = try FileManager.default.attributesOfItem(atPath: destinationURL.path)
            let fileSizeBytes = fileAttributes[.size] as? Int64 ?? 0
            let fileSizeMB = Double(fileSizeBytes) / 1_048_576
                        
            // Log tab-separated values for structured download tracking
            Logger.log("\(labelName)\t\(finalFilename)\t\(String(format: "%.2f", fileSizeMB)) MB\t\(finalURL.path)", level: .info, category: .download)
        } catch {
            // Silently handle file attribute errors
        }
                
    }
    
    // MARK: - File Management Operations
    
    /// Copies a file from source to destination with optional filename preservation
    /// Handles file overwrites and generates unique filenames when needed
    /// - Parameters:
    ///   - sourceURL: The source file location
    ///   - destinationFolder: The target folder for the copied file
    ///   - keepOriginalName: Whether to preserve the original filename or generate a UUID
    /// - Returns: The URL of the copied file at its final destination
    /// - Throws: File system errors if copy operation fails
    static func copyToFinalDestination(sourceURL: URL, destinationFolder: URL, keepOriginalName: Bool) throws -> URL {
        
        // Generate filename: preserve original or create unique UUID-based name
        let fileName = keepOriginalName ? sourceURL.lastPathComponent : UUID().uuidString + "." + sourceURL.pathExtension
        let destinationURL = destinationFolder.appendingPathComponent(fileName)
        
        // Remove existing file if present to avoid conflicts
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        
        // Perform the file copy operation
        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
        
        Logger.info("📁 Copied file to: \(destinationURL.path)", category: .automation)
        return destinationURL
    }
    
    // MARK: - Archive Extraction Operations
    
    /// Extracts a ZIP archive using the system unzip command
    /// Creates extraction directory and handles command execution with error checking
    /// - Parameter zipURL: The URL of the ZIP file to extract
    /// - Returns: The URL of the extraction directory containing extracted contents
    /// - Throws: ExtractionError if unzip command fails or returns non-zero exit status
    static func extractZipFile(zipURL: URL) async throws -> URL {
        Logger.info("Extracting ZIP file: \(zipURL.lastPathComponent)", category: .automation)
        
        let extractFolder = zipURL.deletingLastPathComponent()
        
        // Ensure extraction directory exists
        try FileManager.default.createDirectory(at: extractFolder, withIntermediateDirectories: true)
        
        Logger.info("📦 Extracting ZIP file: \(zipURL.lastPathComponent)", category: .automation)
        
        // Execute unzip command with quiet mode and destination directory
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-q", zipURL.path, "-d", extractFolder.path]
        
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        
        try process.run()
        process.waitUntilExit()
        
        // Verify successful extraction
        guard process.terminationStatus == 0 else {
            throw NSError(domain: "ExtractionError", code: 201, userInfo: [NSLocalizedDescriptionKey: "Failed to extract ZIP file"])
        }
        
        Logger.info("✅ ZIP extraction complete", category: .automation)
        Logger.info("Extracted folder: \(extractFolder.path)", category: .automation)
        return extractFolder
    }
    
    /// Extracts a ZIP archive using the system ditto command (alternative method)
    /// Provides additional ZIP extraction capability using macOS-specific ditto utility
    /// - Parameter zipURL: The URL of the ZIP file to extract
    /// - Returns: The URL of the extraction directory containing extracted contents
    /// - Throws: ExtractionError if ditto command fails or returns non-zero exit status
    static func extractZipFileWithDitto(zipURL: URL) async throws -> URL {
        Logger.info("Extracting ZIP file: \(zipURL.lastPathComponent)", category: .automation)
        
        let extractFolder = zipURL.deletingLastPathComponent()
        
        // Ensure extraction directory exists
        try FileManager.default.createDirectory(at: extractFolder, withIntermediateDirectories: true)
        
        Logger.info("📦 Extracting ZIP file: \(zipURL.lastPathComponent)", category: .automation)
        
        // Execute ditto command with extract and keep structure options
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-x", "-k", zipURL.path, extractFolder.path]
        
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        
        try process.run()
        process.waitUntilExit()
        
        // Verify successful extraction
        guard process.terminationStatus == 0 else {
            throw NSError(domain: "ExtractionError", code: 201, userInfo: [NSLocalizedDescriptionKey: "Failed to extract ZIP file with ditto"])
        }
        
        Logger.info("✅ ZIP extraction complete", category: .automation)
        Logger.info("Extracted folder: \(extractFolder.path)", category: .automation)
        return extractFolder
    }
    
    /// Extracts a TBZ (tar.bz2) archive using the system tar command
    /// Handles compressed tar archives commonly used for software distribution
    /// - Parameter tbzURL: The URL of the TBZ file to extract
    /// - Returns: The URL of the extraction directory containing extracted contents
    /// - Throws: ExtractionError if tar command fails or returns non-zero exit status
    static func extractTBZFile(tbzURL: URL) async throws -> URL {
        Logger.info("Extracting TBZ file: \(tbzURL.lastPathComponent)", category: .automation)
        
        let extractFolder = tbzURL.deletingLastPathComponent()
        
        // Ensure extraction directory exists
        try FileManager.default.createDirectory(at: extractFolder, withIntermediateDirectories: true)
        
        // Execute tar command with extract and change directory options
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        process.arguments = ["-xf", tbzURL.path, "-C", extractFolder.path]
        
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        
        try process.run()
        process.waitUntilExit()
        
        // Verify successful extraction
        guard process.terminationStatus == 0 else {
            throw NSError(domain: "ExtractionError", code: 202, userInfo: [NSLocalizedDescriptionKey: "Failed to extract TBZ file"])
        }
        
        Logger.info("✅ TBZ extraction complete", category: .automation)
        return extractFolder
    }
    
    // MARK: - DMG File Operations
    
    /// Mounts a DMG file and returns the mount point path
    /// Handles Software License Agreement (SLA) conversion and plist parsing of mount output
    /// - Parameter dmgURL: The URL of the DMG file to mount
    /// - Returns: The mount point path where the DMG is accessible
    /// - Throws: MountError if mounting fails, SLA conversion fails, or mount point cannot be determined
    static func mountDMGFile(dmgURL: URL) async throws -> String {
        Logger.info("  Mounting DMG file: \(dmgURL.lastPathComponent)", category: .automation)
        
        let tempDir = dmgURL.deletingLastPathComponent()

        do {
            // Ensure temporary directory exists for SLA conversion if needed
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: nil)
            
            // Handle DMGs with Software License Agreements that prevent mounting
            if dmgHasSLA(at: dmgURL.path) {
                let success = await convertDmgWithSLA(at: dmgURL.path)
                if success {
                Logger.info("Successfully converted dmg with SLA", category: .automation)
                } else {
                    Logger.error("Failed to convert dmg with SLA", category: .automation)
                    throw NSError(domain: "EditViewController", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert dmg containing pkg"])
                }
            }
        }

        // Brief pause to ensure file system stability after SLA conversion
        sleep(UInt32(0.5))

        // Execute hdiutil attach with plist output for parsing
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        process.arguments = ["attach", dmgURL.path, "-nobrowse", "-plist"]
                
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        let errorPipe = Pipe()
        process.standardError = errorPipe
            
        try process.run()
        process.waitUntilExit()
        
        // Verify successful mounting
        guard process.terminationStatus == 0 else {
            let errorOutput = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "Unknown error"
            Logger.error("Error: Failed to mount .dmg file. \(errorOutput)", category: .automation)
            throw NSError(domain: "MountError", code: 301, userInfo: [NSLocalizedDescriptionKey: "Failed to mount DMG file: \(errorOutput)"])
        }
        
        // Parse plist output to extract mount point information
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        
        guard let plist = try PropertyListSerialization.propertyList(from: outputData, options: [], format: nil) as? [String: Any],
              let entities = plist["system-entities"] as? [[String: Any]] else {
            throw NSError(domain: "MountError", code: 302, userInfo: [NSLocalizedDescriptionKey: "Failed to parse mount output"])
        }
        
        // Extract mount point from system entities
        for entity in entities {
            if let mountPoint = entity["mount-point"] as? String {
                Logger.info("  DMG mounted at: \(mountPoint)", category: .automation)
                return mountPoint
            }
        }
        
        throw NSError(domain: "MountError", code: 303, userInfo: [NSLocalizedDescriptionKey: "No mount point found in DMG output"])
    }
    
    /// Checks if a DMG file contains a Software License Agreement (SLA)
    /// SLA-protected DMGs require conversion before they can be mounted programmatically
    /// - Parameter path: The file system path to the DMG file
    /// - Returns: True if the DMG contains an SLA, false otherwise
    static func dmgHasSLA(at path: String) -> Bool {
        // Execute hdiutil imageinfo to get DMG properties in plist format
        let process = Process()
        process.launchPath = "/usr/bin/hdiutil"
        process.arguments = ["imageinfo", path, "-plist"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.launch()
        process.waitUntilExit()
        
        // Verify command executed successfully
        guard process.terminationStatus == 0 else {
            Logger.error("Error: Failed to check for SLA in DMG.", category: .automation)
            return false
        }
        
        // Parse plist output to check for SLA property
        let outputData = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let plist = try? PropertyListSerialization.propertyList(from: outputData, options: [], format: nil) as? [String: Any],
              let properties = plist["Properties"] as? [String: Any],
              let hasSLA = properties["Software License Agreement"] as? Bool else {
            return false
        }
        
        return hasSLA
    }
    
    /// Converts a DMG file with Software License Agreement to a standard format
    /// Removes SLA protection to allow programmatic mounting and processing
    /// - Parameter path: The file system path to the SLA-protected DMG file
    /// - Returns: True if conversion succeeded, false if conversion failed
    static func convertDmgWithSLA(at path: String) async -> Bool {
        let fileName = URL(fileURLWithPath: path).lastPathComponent
        let tempDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory())
        let tempFileURL = tempDirectoryURL.appendingPathComponent(fileName)

        // Execute hdiutil convert to UDRW format (removes SLA)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        process.arguments = ["convert", "-format", "UDRW", "-o", tempFileURL.path, path]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
        } catch {
            Logger.error("Error: Could not launch hdiutil: \(error)", category: .automation)
            return false
        }

        // Wait asynchronously for the conversion process to complete
        await withCheckedContinuation { continuation in
            process.terminationHandler = { _ in
                continuation.resume()
            }
        }

        // Verify conversion completed successfully
        guard process.terminationStatus == 0 else {
            Logger.error("Error: hdiutil failed to convert DMG with SLA.", category: .automation)
            return false
        }

        // Verify converted file was created
        guard FileManager.default.fileExists(atPath: tempFileURL.path) else {
            Logger.error("Error: Converted file not found at expected location.", category: .automation)
            return false
        }

        // Replace original DMG with converted version
        do {
            try FileManager.default.removeItem(atPath: path)
            try FileManager.default.moveItem(atPath: tempFileURL.path, toPath: path)
        } catch {
            Logger.error("Failed to finalize converted DMG: \(error)", category: .automation)
            return false
        }

        return true
    }

    /// Unmounts a previously mounted DMG file using its mount point
    /// Forcefully detaches the DMG volume and handles any unmounting errors
    /// - Parameter mountPoint: The file system path where the DMG is mounted
    /// - Throws: Does not throw errors but logs unmounting failures for debugging
    static func unmountDMG(mountPoint: String) throws {
        Logger.info("  Unmounting DMG: \(mountPoint)", category: .automation)
        
        // Execute hdiutil detach with force option to ensure unmounting
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        process.arguments = ["detach", mountPoint, "-force"]
        
        // Capture both stdout and stderr for error reporting
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        try process.run()
        process.waitUntilExit()
        
        // Log success or failure with detailed error information
        if process.terminationStatus == 0 {
            Logger.info("  DMG unmounted successfully", category: .automation)
        } else {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            Logger.error("  Failed to unmount DMG: \(errorMessage)", category: .automation)
        }
    }
    
    // MARK: - File Discovery Operations
    
    /// Recursively searches for files with a specific extension in a given folder
    /// Handles special cases like .app bundles and provides sorted results by path length
    /// - Parameters:
    ///   - folderURL: The directory URL to search within
    ///   - ext: The file extension to search for (without the dot)
    /// - Returns: An array of URLs for files matching the extension, sorted by shortest path first
    /// - Throws: File system errors if directory enumeration fails
    static func findFiles(inFolder folderURL: URL, withExtension ext: String) throws -> [URL] {
        let fileManager = FileManager.default
        let enumerator = fileManager.enumerator(at: folderURL, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
        
        var foundFiles = [URL]()
        
        // Enumerate all items in the directory tree
        while let fileURL = enumerator?.nextObject() as? URL {
            // Handle .app bundles as special case (they are directories but function as files)
            if ext.lowercased() == "app" {
                let resourceValues = try fileURL.resourceValues(forKeys: [.isDirectoryKey])
                if resourceValues.isDirectory == true && fileURL.pathExtension.lowercased() == "app" {
                    foundFiles.append(fileURL)
                }
            } else {
                // Handle regular files by matching extension
                let resourceValues = try fileURL.resourceValues(forKeys: [.isDirectoryKey])
                if resourceValues.isDirectory == false && fileURL.pathExtension.lowercased() == ext.lowercased() {
                    foundFiles.append(fileURL)
                }
            }
        }
        
        // Log discovery results for debugging
        Logger.info("  Found \(foundFiles.count) files with extension .\(ext) in \(folderURL.path)", category: .automation)
        for file in foundFiles {
            Logger.info("   - \(file.lastPathComponent)", category: .automation)
        }
        
        // Sort by shortest path length (typically finds files at root level first)
        foundFiles.sort { $0.path.count < $1.path.count }

        return foundFiles
    }



}
