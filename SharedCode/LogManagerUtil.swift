//
//  LogManagerUtil.swift
//  Intuneomator
//
//  Created by Gil Burns on 5/6/25.
//

import Foundation

/// Utility class for managing log file operations including cleanup, size monitoring, and retention.
/// This class provides comprehensive log management functionality for both system and user log directories,
/// including automated cleanup based on configuration settings, size-based trimming, and age-based retention.
/// Supports different log folder types to handle various logging scenarios within the application.
class LogManagerUtil {
    
    static let logFileName = "LogManager"

    /// Calculates the total size in bytes of all files in the specified log folder.
    /// 
    /// Recursively traverses the log directory and sums the file sizes of all regular files,
    /// skipping directories and any unreadable files. Provides accurate disk usage information
    /// for log management and cleanup decisions.
    /// 
    /// - Parameter logType: The type of log folder to analyze ("user" for application logs, "system" for system logs)
    /// - Returns: Total size in bytes of all files in the log folder, or 0 if folder is inaccessible
    /// 
    /// **Behavior:**
    /// - Only counts regular files, ignoring directories and special files
    /// - Gracefully handles unreadable files by skipping them
    /// - Returns 0 if the folder enumeration fails
    /// 
    /// **Use Cases:**
    /// - Monitoring log disk usage
    /// - Determining if size-based cleanup is needed
    /// - Providing storage statistics for log management
    static func logFolderSizeInBytes(forLogFolder logType: String = "system") -> Int64 {
        let fileManager = FileManager.default
        // Determine target log directory based on log type
        let folderURL: URL
        switch logType {
        case "user":
            folderURL = AppConstants.intuneomatorLogApplicationURL
        default:
            folderURL = AppConstants.intuneomatorLogSystemURL
        }
        
        var totalSize: Int64 = 0

        // Create directory enumerator to traverse all files
        guard let enumerator = fileManager.enumerator(at: folderURL, includingPropertiesForKeys: [.fileSizeKey], options: [], errorHandler: nil) else {
            return 0
        }

        // Sum file sizes for all regular files in the directory tree
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

    /// Removes log files that exceed the specified age threshold to maintain log retention policies.
    /// 
    /// Performs age-based log cleanup by deleting files that have not been modified within the
    /// specified number of days. Uses file modification date to determine age, providing automatic
    /// log rotation and preventing unlimited log accumulation.
    /// 
    /// - Parameters:
    ///   - days: Maximum age in days - files older than this will be deleted
    ///   - logType: The log folder type ("user" for application logs, "system" for system logs)
    /// 
    /// **Process Flow:**
    /// 1. Calculates expiration date based on current date minus retention days
    /// 2. Enumerates all files in the target log directory
    /// 3. Checks modification date of each regular file
    /// 4. Deletes files older than the expiration threshold
    /// 5. Logs deletion actions for audit trail
    /// 
    /// **Safety Features:**
    /// - Only processes regular files, ignoring directories
    /// - Gracefully handles file access errors
    /// - Continues processing even if individual deletions fail
    /// 
    /// **Use Cases:**
    /// - Automated log retention based on time policies
    /// - Preventing log directories from growing indefinitely
    /// - Compliance with data retention requirements
    static func removeLogFiles(olderThan days: Int, forLogFolder logType: String = "system") {
        let fileManager = FileManager.default
        // Determine target log directory based on log type
        let folderURL: URL
        switch logType {
        case "user":
            folderURL = AppConstants.intuneomatorLogApplicationURL
        default:
            folderURL = AppConstants.intuneomatorLogSystemURL
        }

        // Calculate cutoff date for file retention
        let expirationDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date.distantPast

        // Create directory enumerator with required file metadata
        guard let enumerator = fileManager.enumerator(
            at: folderURL,
            includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey],
            options: [],
            errorHandler: nil
        ) else {
            return
        }
        
        // Process each file and delete if older than retention period
        for case let fileURL as URL in enumerator {
            do {
                let values = try fileURL.resourceValues(forKeys: [.isRegularFileKey, .contentModificationDateKey])
                if values.isRegularFile == true,
                   let modifiedDate = values.contentModificationDate,
                   modifiedDate < expirationDate {
                    try fileManager.removeItem(at: fileURL)
                    Logger.logNoDateStamp("  Deleting old log file:", logType: logFileName)
                    Logger.logNoDateStamp("  \(fileURL.path)", logType: logFileName)
                }
            } catch {
                continue // Skip files that can't be processed
            }
        }
    }

    /// Enforces size-based log retention by removing oldest files when total size exceeds limit.
    /// 
    /// Implements intelligent log trimming that maintains log directories within specified size
    /// constraints by removing the oldest files first. This prevents log directories from consuming
    /// excessive disk space while preserving the most recent log data for troubleshooting.
    /// 
    /// - Parameters:
    ///   - maxSizeMB: Maximum allowed total size for the log folder in megabytes
    ///   - logType: The log folder type ("user" for application logs, "system" for system logs)
    /// 
    /// **Algorithm:**
    /// 1. Calculates current total size of log directory
    /// 2. Returns early if already within size limit
    /// 3. Enumerates all files with size and modification date metadata
    /// 4. Sorts files by modification date (oldest first)
    /// 5. Deletes files in order until size target is achieved
    /// 
    /// **Smart Features:**
    /// - Only deletes files if size limit is exceeded
    /// - Preserves newest files for recent log analysis
    /// - Calculates exact bytes to free for efficient trimming
    /// - Logs deletion actions for audit trail
    /// 
    /// **Use Cases:**
    /// - Preventing log directories from filling disk space
    /// - Maintaining recent logs while removing old data
    /// - Automated disk space management
    static func trimLogFiles(toMaxSizeMB maxSizeMB: Int, forLogFolder logType: String = "system") {
        let fileManager = FileManager.default
        // Determine target log directory based on log type
        let folderURL: URL
        switch logType {
        case "user":
            folderURL = AppConstants.intuneomatorLogApplicationURL
        default:
            folderURL = AppConstants.intuneomatorLogSystemURL
        }

        // Convert megabytes to bytes and check if trimming is needed
        let maxBytes = Int64(maxSizeMB) * 1024 * 1024
        let currentSize = logFolderSizeInBytes(forLogFolder: logType)
        guard currentSize > maxBytes else {
            return // Already within size limit
        }

        // Collect file metadata for sorting and deletion planning
        var files: [(url: URL, date: Date, size: Int64)] = []
        guard let enumerator = fileManager.enumerator(
            at: folderURL,
            includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey, .fileSizeKey],
            options: [],
            errorHandler: nil
        ) else {
            return
        }

        // Build list of files with metadata needed for intelligent deletion
        for case let fileURL as URL in enumerator {
            do {
                let values = try fileURL.resourceValues(forKeys: [.isRegularFileKey, .contentModificationDateKey, .fileSizeKey])
                if values.isRegularFile == true,
                   let modifiedDate = values.contentModificationDate,
                   let fileSize = values.fileSize {
                    files.append((url: fileURL, date: modifiedDate, size: Int64(fileSize)))
                }
            } catch {
                continue // Skip files that can't be processed
            }
        }

        // Sort files by oldest modification date first for intelligent deletion
        files.sort { $0.date < $1.date }

        var bytesToFree = currentSize - maxBytes

        Logger.logNoDateStamp("Found \(files.count) log files, trimming to free up \(bytesToFree) bytes...", logType: logFileName)
        
        // Delete oldest files until size target is achieved
        for file in files {
            do {
                try fileManager.removeItem(at: file.url)
                Logger.logNoDateStamp("  Deleting log file to free space:", logType: logFileName)
                Logger.logNoDateStamp("  \(file.url.path)", logType: logFileName)

                bytesToFree -= file.size
                if bytesToFree <= 0 {
                    break // Size target achieved
                }
            } catch {
                continue // Skip files that can't be deleted
            }
        }
    }

    /// Executes comprehensive log cleanup based on application configuration settings.
    /// 
    /// Provides automated log management by reading cleanup policies from the application's
    /// configuration and applying both age-based and size-based retention rules. This method
    /// serves as the main entry point for scheduled log maintenance operations.
    /// 
    /// - Parameter logType: The log folder type ("user" for application logs, "system" for system logs)
    /// 
    /// **Configuration Keys:**
    /// - `LogRetentionDays`: Maximum age in days for log files (age-based cleanup)
    /// - `LogMaxSizeMB`: Maximum total size in MB for log directory (size-based cleanup)
    /// 
    /// **Process Flow:**
    /// 1. Reads age retention policy from configuration
    /// 2. Performs age-based cleanup if policy is configured and valid
    /// 3. Reads size limit policy from configuration  
    /// 4. Performs size-based cleanup if policy is configured and valid
    /// 5. Skips any step if corresponding setting is missing or invalid
    /// 
    /// **Behavior:**
    /// - Gracefully handles missing or invalid configuration values
    /// - Only positive values are considered valid for cleanup policies
    /// - Age-based cleanup runs before size-based cleanup
    /// - Each cleanup step is independent and logged separately
    /// 
    /// **Use Cases:**
    /// - Scheduled maintenance tasks
    /// - Application startup cleanup
    /// - Manual log management operations
    static func performLogCleanup(forLogFolder logType: String = "system") {
        
        // Apply age-based retention policy if configured
        if let retentionDays: Int = ConfigManager.readPlistValue(key: "LogRetentionDays"), retentionDays > 0 {
            Logger.logNoDateStamp("Cleaning up logs older than \(retentionDays) days...", logType: logFileName)
            removeLogFiles(olderThan: retentionDays, forLogFolder: logType)
        }

        // Apply size-based retention policy if configured
        if let maxSizeMB: Int = ConfigManager.readPlistValue(key: "LogMaxSizeMB"), maxSizeMB > 0 {
            Logger.logNoDateStamp("Trimming logs to maximum size of \(maxSizeMB) MB...", logType: logFileName)
            trimLogFiles(toMaxSizeMB: maxSizeMB, forLogFolder: logType)
        }
    }

}
