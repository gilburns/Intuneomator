//
//  LogManagerUtil.swift
//  Intuneomator
//
//  Created by Gil Burns on 5/6/25.
//

import Foundation

class LogManagerUtil {
    
    static func logFolderSizeInBytes(forLogFolder logType: String = "system") -> Int64 {
        let fileManager = FileManager.default
        let folderURL: URL
        switch logType {
        case "user":
            folderURL = AppConstants.intuneomatorLogApplicationURL
        default:
            folderURL = AppConstants.intuneomatorLogSystemURL
        }
        
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

    /// Removes log files in the specified log folder that have not been modified in the last `days`.
    /// - Parameters:
    ///   - days: Files older than this (in days) will be deleted.
    ///   - logType: The log folder type ("system" or "user").
    static func removeLogFiles(olderThan days: Int, forLogFolder logType: String = "system") {
        let fileManager = FileManager.default
        let folderURL: URL
        switch logType {
        case "user":
            folderURL = AppConstants.intuneomatorLogApplicationURL
        default:
            folderURL = AppConstants.intuneomatorLogSystemURL
        }

        let expirationDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date.distantPast

        guard let enumerator = fileManager.enumerator(
            at: folderURL,
            includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey],
            options: [],
            errorHandler: nil
        ) else {
            return
        }

        for case let fileURL as URL in enumerator {
            do {
                let values = try fileURL.resourceValues(forKeys: [.isRegularFileKey, .contentModificationDateKey])
                if values.isRegularFile == true,
                   let modifiedDate = values.contentModificationDate,
                   modifiedDate < expirationDate {
                    try fileManager.removeItem(at: fileURL)
                }
            } catch {
                continue
            }
        }
    }

    /// Trims log files in the specified log folder so total size does not exceed `maxSizeMB`.
    /// Deletes oldest files first until total size is within the limit.
    /// - Parameters:
    ///   - maxSizeMB: Maximum total size in megabytes.
    ///   - logType: The log folder type ("system" or "user").
    static func trimLogFiles(toMaxSizeMB maxSizeMB: Int, forLogFolder logType: String = "system") {
        let fileManager = FileManager.default
        let folderURL: URL
        switch logType {
        case "user":
            folderURL = AppConstants.intuneomatorLogApplicationURL
        default:
            folderURL = AppConstants.intuneomatorLogSystemURL
        }

        let maxBytes = Int64(maxSizeMB) * 1024 * 1024
        var currentSize = logFolderSizeInBytes(forLogFolder: logType)
        guard currentSize > maxBytes else {
            return
        }

        var files: [(url: URL, date: Date, size: Int64)] = []
        guard let enumerator = fileManager.enumerator(
            at: folderURL,
            includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey, .fileSizeKey],
            options: [],
            errorHandler: nil
        ) else {
            return
        }

        for case let fileURL as URL in enumerator {
            do {
                let values = try fileURL.resourceValues(forKeys: [.isRegularFileKey, .contentModificationDateKey, .fileSizeKey])
                if values.isRegularFile == true,
                   let modifiedDate = values.contentModificationDate,
                   let fileSize = values.fileSize {
                    files.append((url: fileURL, date: modifiedDate, size: Int64(fileSize)))
                }
            } catch {
                continue
            }
        }

        // Sort files by oldest modification date first
        files.sort { $0.date < $1.date }

        var bytesToFree = currentSize - maxBytes

        for file in files {
            do {
                try fileManager.removeItem(at: file.url)
                bytesToFree -= file.size
                if bytesToFree <= 0 {
                    break
                }
            } catch {
                continue
            }
        }
    }

    /// Performs log cleanup based on configuration plist settings.
    /// Reads `LogRetentionDays` and `LogMaxSizeMB` keys; skips any step if the setting is missing or non-positive.
    /// - Parameter logType: The log folder type ("system" or "user").
    static func performLogCleanup(forLogFolder logType: String = "system") {
        // Remove files older than configured retention days
        if let retentionDays: Int = ConfigManager.readPlistValue(key: "LogRetentionDays"), retentionDays > 0 {
            removeLogFiles(olderThan: retentionDays, forLogFolder: logType)
        }

        // Trim logs to configured max size
        if let maxSizeMB: Int = ConfigManager.readPlistValue(key: "LogMaxSizeMB"), maxSizeMB > 0 {
            trimLogFiles(toMaxSizeMB: maxSizeMB, forLogFolder: logType)
        }
    }

}
