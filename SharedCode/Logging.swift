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
    
    // MARK: - Log Categories
    
    /// Standard log categories for consistent logging across the application
    enum LogCategory: String, CaseIterable {
        case core = "Core"               // Essential app operations (daemon, XPC, auth, errors)
        case automation = "Automation"   // Label processing, Graph API, metadata operations
        case download = "Download"       // Download tracking (kept separate)
        case upload = "Upload"           // Upload tracking (kept separate)
        case debug = "Debug"             // Development debugging (can be disabled in production)
        
        /// Whether this category should include date in filename
        var includesDateInFilename: Bool {
            switch self {
            case .download, .upload:
                return false  // Continuous logging files
            default:
                return true   // Date-based rotation
            }
        }
        
        /// Whether this category uses stats directory for download/upload tracking
        var usesStatsDirectory: Bool {
            return self == .download || self == .upload
        }
    }
    
    // MARK: - Log Levels
    
    /// Log levels for filtering messages by importance
    enum LogLevel: String, CaseIterable, Comparable {
        case debug = "DEBUG"
        case info = "INFO"
        case warning = "WARNING"
        case error = "ERROR"
        case critical = "CRITICAL"
        
        static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
            let order: [LogLevel] = [.debug, .info, .warning, .error, .critical]
            guard let lhsIndex = order.firstIndex(of: lhs),
                  let rhsIndex = order.firstIndex(of: rhs) else {
                return false
            }
            return lhsIndex < rhsIndex
        }
    }
    
    /// Current minimum log level (can be adjusted for production vs development)
    static var minimumLogLevel: LogLevel = .info
    
    /// Production mode setting - when enabled, debug logging is completely disabled
    static var isProductionMode: Bool = false {
        didSet {
            minimumLogLevel = isProductionMode ? .info : .debug
        }
    }
    
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
    
    /// Enhanced logging with categories and levels
    /// - Parameters:
    ///   - message: The message to log
    ///   - level: The importance level of the message
    ///   - category: The category for organizing logs
    ///   - toUserDirectory: Whether to log to user directory (false = system directory)
    static func log(
        _ message: String,
        level: LogLevel = .info,
        category: LogCategory = .core,
        toUserDirectory: Bool = false
    ) {
        // Filter out messages below minimum log level
        guard level >= minimumLogLevel else { return }
        
        let formattedMessage = "[\(level.rawValue)] \(message)"
        writeLog(
            message: formattedMessage,
            logType: category.rawValue,
            toUserDirectory: toUserDirectory && !category.usesStatsDirectory,
            includeDateInFilename: category.includesDateInFilename
        )
    }
    
    // MARK: - Convenience Methods for Specific Levels
    
    /// Log a debug message (filtered out in production if minimumLogLevel > debug)
    static func debug(_ message: String, category: LogCategory = .debug, toUserDirectory: Bool = false) {
        log(message, level: .debug, category: category, toUserDirectory: toUserDirectory)
    }
    
    /// Log an informational message
    static func info(_ message: String, category: LogCategory = .core, toUserDirectory: Bool = false) {
        log(message, level: .info, category: category, toUserDirectory: toUserDirectory)
    }
    
    /// Log a warning message
    static func warning(_ message: String, category: LogCategory = .core, toUserDirectory: Bool = false) {
        log(message, level: .warning, category: category, toUserDirectory: toUserDirectory)
    }
    
    /// Log an error message
    static func error(_ message: String, category: LogCategory = .core, toUserDirectory: Bool = false) {
        log(message, level: .error, category: category, toUserDirectory: toUserDirectory)
    }
    
    /// Log a critical message
    static func critical(_ message: String, category: LogCategory = .core, toUserDirectory: Bool = false) {
        log(message, level: .critical, category: category, toUserDirectory: toUserDirectory)
    }
    
    // MARK: - Legacy Methods (for backward compatibility)
    
//    /// Logs a message to the system log directory with date-based file naming
//    /// - Parameters:
//    ///   - message: The message to log
//    ///   - logType: Category for organizing logs (default: "General")
//    @available(*, deprecated, message: "Use log(_:level:category:toUserDirectory:) instead")
//    static func log(_ message: String, logType: String = "General") {
//        writeLog(message: message, logType: logType, toUserDirectory: false, includeDateInFilename: true)
//    }
//    
//    /// Logs a message to the system log directory without date in filename
//    /// Note: Still includes timestamp in the log entry itself
//    /// - Parameters:
//    ///   - message: The message to log
//    ///   - logType: Category for organizing logs (default: "Download")
//    @available(*, deprecated, message: "Use log(_:level:category:toUserDirectory:) instead")
//    static func logNoDateStamp(_ message: String, logType: String = "Download") {
//        writeLog(message: message, logType: logType, toUserDirectory: false, includeDateInFilename: false)
//    }
//    
//    /// Logs a message to the user-specific log directory
//    /// - Parameters:
//    ///   - message: The message to log
//    ///   - logType: Category for organizing logs (default: "General")
//    @available(*, deprecated, message: "Use log(_:level:category:toUserDirectory:) instead")
//    static func logApp(_ message: String, logType: String = "General") {
//        writeLog(message: message, logType: logType, toUserDirectory: true, includeDateInFilename: true)
//    }
    
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
 
 // New enhanced logging (recommended)
 Logger.info("Application started", category: .core)
 Logger.error("Authentication failed", category: .core)
 Logger.info("Processing label: someLabel", category: .automation)
 Logger.debug("Debugging download process", category: .debug)
 Logger.log("Downloaded file.dmg", level: .info, category: .download)
 Logger.log("Uploaded to Intune", level: .info, category: .upload)
 
 // Legacy logging (deprecated but still supported)
 Logger.log("Application started.")
 Logger.log("Update completed successfully.", logType: "Updates")
 Logger.logApp("User-specific action performed.", logType: "UserActions")
 Logger.logNoDateStamp("Continuous log entry", logType: "Download")
 
*/
