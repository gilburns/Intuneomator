//
//  CacheManagerUtil.swift
//  Intuneomator
//
//  Created by Gil Burns on 5/4/25.
//

import Foundation

/// Manages cache cleanup operations for Intuneomator application downloads
/// Removes orphaned cache folders and maintains version limits to control disk usage
class CacheManagerUtil {
    
    /// Log type identifier for logging operations
    static private let logType = "CacheCleaner"
    
    /// Removes cache folders that no longer correspond to active managed titles
    /// Compares cache folder names against managed titles and deletes unmatched entries
    static func removeOrphanedCaches() {
        let managedTitlesURL = AppConstants.intuneomatorManagedTitlesFolderURL
        let cacheFolderURL = AppConstants.intuneomatorCacheFolderURL
        
        // Get all valid titles from the managed folder (removing GUID)
        let managedTitleList: [String] = (try? FileManager.default.contentsOfDirectory(at: managedTitlesURL, includingPropertiesForKeys: nil, options: .skipsHiddenFiles).compactMap { url in
            let folderName = url.lastPathComponent
            if let baseTitle = folderName.split(separator: "_").first {
                return String(baseTitle)
            }
            return nil
        }) ?? []

        let managedTitles = Set(managedTitleList)
        
        // Iterate over the cache folders
        if let cacheFolders = try? FileManager.default.contentsOfDirectory(at: cacheFolderURL, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) {
            for folder in cacheFolders {
                let folderName = folder.lastPathComponent
                if !managedTitles.contains(folderName) {
                    // Not a managed title, delete it
                    try? FileManager.default.removeItem(at: folder)
                    Logger.log("🗑️ Removed orphaned cache folder: \(folderName)", logType: logType)
                }
            }
        }
    }
    
    /// Removes old cached versions, keeping only the most recent N versions per title
    /// Uses numeric version comparison to determine which versions to retain
    static func trimOldVersions() {
        let cacheFolderURL = AppConstants.intuneomatorCacheFolderURL
        let versionsToKeep = ConfigManager.readPlistValue(key: "AppVersionsToKeep") ?? 2

        if let titleFolders = try? FileManager.default.contentsOfDirectory(at: cacheFolderURL, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) {
            for titleFolder in titleFolders {
                let titleFolderName = titleFolder.lastPathComponent

                // Get version subfolders
                guard let versionFolders = try? FileManager.default.contentsOfDirectory(at: titleFolder, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) else { continue }
                
                let versionNames = versionFolders.map { $0.lastPathComponent }

                // Sort version strings descending
                let sortedVersions = versionNames.sorted { $0.compare($1, options: .numeric) == .orderedDescending }

                let versionsToDelete = sortedVersions.dropFirst(versionsToKeep)

                for version in versionsToDelete {
                    let versionPath = titleFolder.appendingPathComponent(version)
                    try? FileManager.default.removeItem(at: versionPath)
                    Logger.log("🧹 Deleted old version: \(titleFolderName)/\(version)", logType: logType)
                }
            }
        }
    }
    
    /// Performs comprehensive cache cleanup including orphan removal and version trimming
    /// Executes cleanup operations in optimal order for maximum effectiveness
    static func runCleanup() {
        Logger.log("🔍 Running orphaned cache cleanup...", logType: logType)
        removeOrphanedCaches()
        
        Logger.log("🔍 Trimming old versions...", logType: logType)
        trimOldVersions()
    }
    
    
    /// Calculates the total size of the cache directory in bytes
    /// Recursively enumerates all files to compute accurate disk usage
    /// - Returns: Total size in bytes, or 0 if calculation fails
    static func cacheFolderSizeInBytes() -> Int64 {
        let fileManager = FileManager.default
        let folderURL = AppConstants.intuneomatorCacheFolderURL
        var totalSize: Int64 = 0

        guard let enumerator = fileManager.enumerator(at: folderURL, includingPropertiesForKeys: [.fileSizeKey], options: [], errorHandler: nil) else {
            return 0
        }

        for case let fileURL as URL in enumerator {
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
                if resourceValues.isRegularFile == true, let fileSize = resourceValues.fileSize {
                    totalSize += Int64(fileSize)
                }
            } catch {
                continue // Skip unreadable files
            }
        }

        return totalSize
    }

}



// Usage example:

/*
 
 Call:
 
 CacheCleaner.runCleanup()
 
 to perform both orphan cleanup and version trimming in sequence.

 */
