//
//  Logging.swift
//  Intuneomator
//
//  Created by Gil Burns on 3/12/25.
//

import Foundation

class Logger {
    static var logDirectory: URL = {
        
        let systemLogPath = AppConstants.intuneomatorLogSystemURL
        
//        URL(fileURLWithPath: "/Library/Logs/Intuneomator")

        // Ensure the directory exists
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: systemLogPath.path) {
            do {
                try fileManager.createDirectory(at: systemLogPath, withIntermediateDirectories: true, attributes: [FileAttributeKey.posixPermissions: 0o755])
            } catch {
                print("Failed to create log directory at \(systemLogPath.path): \(error.localizedDescription)")
            }
        }
        
        return systemLogPath
    }()
    
    static var logDirectoryUser: URL = {
        let userLogPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library")
            .appendingPathComponent("Logs")
            .appendingPathComponent("Intuneomator")

        // Ensure the directory exists
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: userLogPath.path) {
            do {
                try fileManager.createDirectory(at: userLogPath, withIntermediateDirectories: true, attributes: [FileAttributeKey.posixPermissions: 0o755])
            } catch {
                print("Failed to create log directory at \(userLogPath.path): \(error.localizedDescription)")
            }
        }
        
        return userLogPath
    }()
    
    /// Logs a message to a specific log file determined by the `logType`.
    static func log(_ message: String, logType: String = "General") {
        // Date for Log File
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let currentDate = dateFormatter.string(from: Date())
        
        // Date and Time for Log Entry
        let timestampFormatter = DateFormatter()
        timestampFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss:SSS"
        let timestamp = timestampFormatter.string(from: Date())
        
        let logMessage = "[\(timestamp)] \(message)\n"
        let logFilePath = logDirectory.appendingPathComponent("Intuneomator_\(logType)_\(currentDate).log")
        
        do {
            let fileManager = FileManager.default
            
            if !fileManager.fileExists(atPath: logFilePath.path) {
                fileManager.createFile(atPath: logFilePath.path, contents: nil, attributes: [FileAttributeKey.posixPermissions: 0o644])
            }
            
            let fileHandle = try FileHandle(forWritingTo: logFilePath)
            fileHandle.seekToEndOfFile()
            if let data = logMessage.data(using: .utf8) {
                fileHandle.write(data)
            }
            fileHandle.closeFile()
        } catch {
            print("Failed to write log: \(error.localizedDescription)")
        }
    }

    /// Logs a message to a specific log file determined by the `logType`.
    static func logFileTransfer(_ message: String, logType: String = "Download") {
        
        // Date and Time for Log Entry
        let timestampFormatter = DateFormatter()
        timestampFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss:SSS"
        let timestamp = timestampFormatter.string(from: Date())
        
        let logMessage = "[\(timestamp)]\t\(message)\n"
        let logFilePath = logDirectory.appendingPathComponent("Intuneomator_\(logType).txt")
        
        do {
            let fileManager = FileManager.default
            
            if !fileManager.fileExists(atPath: logFilePath.path) {
                fileManager.createFile(atPath: logFilePath.path, contents: nil, attributes: [FileAttributeKey.posixPermissions: 0o644])
            }
            
            let fileHandle = try FileHandle(forWritingTo: logFilePath)
            fileHandle.seekToEndOfFile()
            if let data = logMessage.data(using: .utf8) {
                fileHandle.write(data)
            }
            fileHandle.closeFile()
        } catch {
            print("Failed to write log: \(error.localizedDescription)")
        }
    }

    
    /// Logs a message to a specific log file determined by the `logType`.
    static func logUser(_ message: String, logType: String = "General") {
        // Date for Log File
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let currentDate = dateFormatter.string(from: Date())

        // Date and Time for Log Entry
        let timestampFormatter = DateFormatter()
        timestampFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss:SSS"
        let timestamp = timestampFormatter.string(from: Date())

        let logMessage = "[\(timestamp)] \(message)\n"
        let logFilePath = logDirectoryUser.appendingPathComponent("Intuneomator_\(logType)_\(currentDate).log")

        do {
            let fileManager = FileManager.default
            
            if !fileManager.fileExists(atPath: logFilePath.path) {
                fileManager.createFile(atPath: logFilePath.path, contents: nil, attributes: [FileAttributeKey.posixPermissions: 0o644])
            }

            let fileHandle = try FileHandle(forWritingTo: logFilePath)
            fileHandle.seekToEndOfFile()
            if let data = logMessage.data(using: .utf8) {
                fileHandle.write(data)
            }
            fileHandle.closeFile()
        } catch {
            print("Failed to write log: \(error.localizedDescription)")
        }
    }
}

// Usage Examples
/*
 
 Logger.log("Application started.")
 Logger.log("Update completed successfully.", logType: "Updates")
 Logger.log("An error occurred in the update process.", logType: "Errors")
 
*/
