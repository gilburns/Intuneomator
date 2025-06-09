//
//  Logging.swift
//  Intuneomator
//
//  Created by Gil Burns on 3/12/25.
//

import Foundation

/// Centralized logging utility for Intuneomator with support for system and user logs
/// Provides thread-safe logging with automatic directory creation and file management
class Logger {
    
    // MARK: - Private Properties
    
    /// Shared date formatter for log file naming (thread-safe singleton)
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    
    /// Shared timestamp formatter for log entries (thread-safe singleton)
    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()
    
    /// Serial queue for thread-safe logging operations
    private static let loggingQueue = DispatchQueue(label: "com.intuneomator.logging", qos: .utility)
    
    // MARK: - Log Directories
    
    /// System-wide log directory (uses AppConstants for consistency)
    static var logDirectory: URL = {
        let systemLogPath = AppConstants.intuneomatorLogSystemURL
        ensureDirectoryExists(at: systemLogPath)
        return systemLogPath
    }()
    
    /// User-specific log directory (uses FileManager API)
    static var logDirectoryUser: URL = {
        let userLogPath = AppConstants.intuneomatorLogApplicationURL
        ensureDirectoryExists(at: userLogPath)
        return userLogPath
    }()
    
    /// Intuneomator log directory for Download and Upload tracking (uses AppConstants for consistency)
    static var logDirectoryStats: URL = {
        let statsLogPath = AppConstants.intuneomatorUpDownStatsURL
        ensureDirectoryExists(at: statsLogPath)
        return statsLogPath
    }()
    
    // MARK: - Public Logging Methods
    
    /// Logs a message to the system log directory with date-based file naming
    /// - Parameters:
    ///   - message: The message to log
    ///   - logType: Category for organizing logs (default: "General")
    static func log(_ message: String, logType: String = "General") {
        writeLog(message: message, logType: logType, toUserDirectory: false, includeDateInFilename: true)
    }
    
    /// Logs a message to the system log directory without date in filename
    /// Note: Still includes timestamp in the log entry itself
    /// - Parameters:
    ///   - message: The message to log
    ///   - logType: Category for organizing logs (default: "Download")
    static func logNoDateStamp(_ message: String, logType: String = "Download") {
        writeLog(message: message, logType: logType, toUserDirectory: false, includeDateInFilename: false)
    }
    
    /// Logs a message to the user-specific log directory
    /// - Parameters:
    ///   - message: The message to log
    ///   - logType: Category for organizing logs (default: "General")
    static func logApp(_ message: String, logType: String = "General") {
        writeLog(message: message, logType: logType, toUserDirectory: true, includeDateInFilename: true)
    }
    
    // MARK: - Private Helper Methods
    
    /// Unified logging implementation to reduce code duplication
    /// - Parameters:
    ///   - message: The message to log
    ///   - logType: Category for organizing logs
    ///   - toUserDirectory: Whether to log to user directory (false = system directory)
    ///   - includeDateInFilename: Whether to include date in filename
    private static func writeLog(
        message: String,
        logType: String,
        toUserDirectory: Bool,
        includeDateInFilename: Bool
    ) {
        loggingQueue.async {
            var logDirectory: URL
            if logType == "Download" || logType == "Upload" {
                logDirectory = logDirectoryStats
            } else {
                logDirectory = toUserDirectory ? logDirectoryUser : self.logDirectory
            }
            let timestamp = timestampFormatter.string(from: Date())
            let logMessage = "[\(timestamp)] \(message)\n"
            
            let filename: String
            if includeDateInFilename {
                let currentDate = dateFormatter.string(from: Date())
                filename = "Intuneomator_\(logType)_\(currentDate).log"
            } else {
                filename = "Intuneomator_\(logType).txt"
            }
            
            let logFilePath = logDirectory.appendingPathComponent(filename)
            
            do {
                try writeToLogFile(message: logMessage, at: logFilePath)
            } catch {
                // Fallback to console if file logging fails
                print("Failed to write log to \(logFilePath.path): \(error.localizedDescription)")
                print("Log message: \(logMessage.trimmingCharacters(in: .whitespacesAndNewlines))")
            }
        }
    }
    
    /// Safely writes a message to the specified log file with proper resource management
    /// - Parameters:
    ///   - message: The formatted log message to write
    ///   - logFilePath: The URL of the log file
    /// - Throws: File system errors
    private static func writeToLogFile(message: String, at logFilePath: URL) throws {
        let fileManager = FileManager.default
        
        // Create file if it doesn't exist
        if !fileManager.fileExists(atPath: logFilePath.path) {
            fileManager.createFile(
                atPath: logFilePath.path,
                contents: nil,
                attributes: [.posixPermissions: 0o644]
            )
        }
        
        // Use proper resource management for FileHandle
        let fileHandle = try FileHandle(forWritingTo: logFilePath)
        defer { fileHandle.closeFile() }
        
        fileHandle.seekToEndOfFile()
        if let data = message.data(using: .utf8) {
            fileHandle.write(data)
        }
    }
    
    /// Ensures the specified directory exists, creating it if necessary
    /// - Parameter url: The directory URL to check/create
    private static func ensureDirectoryExists(at url: URL) {
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: url.path) {
            do {
                try fileManager.createDirectory(
                    at: url,
                    withIntermediateDirectories: true,
                    attributes: [.posixPermissions: 0o755]
                )
            } catch {
                print("Failed to create log directory at \(url.path): \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Usage Examples
/*
 
 Logger.log("Application started.")
 Logger.log("Update completed successfully.", logType: "Updates")
 Logger.log("An error occurred in the update process.", logType: "Errors")
 Logger.logApp("User-specific action performed.", logType: "UserActions")
 Logger.logNoDateStamp("Continuous log entry", logType: "Download")
 
*/
