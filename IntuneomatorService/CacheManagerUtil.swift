//
//  CacheManagerUtil.swift
//  Intuneomator
//
//  Created by Gil Burns on 5/4/25.
//

import Foundation

class CacheManagerUtil {
    
    static private let logType = "CacheCleaner"
    
    /// Removes any cache folders that do not correspond to a managed title
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
    
    /// Keeps only the latest N versions of each valid title
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
    
    /// Run full cleanup: orphaned folders first, then trim versions
    static func runCleanup() {
        Logger.log("🔍 Running orphaned cache cleanup...", logType: logType)
        removeOrphanedCaches()
        
        Logger.log("🔍 Trimming old versions...", logType: logType)
        trimOldVersions()
    }
    
    
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
