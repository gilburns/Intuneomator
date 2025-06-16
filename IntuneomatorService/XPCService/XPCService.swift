//
//  XPCService.swift
//  Intuneomator
//
//  Created by Gil Burns on 3/17/25.
//

import Foundation

/// Main XPC service implementation providing secure inter-process communication
/// Implements XPCServiceProtocol to handle requests from the Intuneomator GUI application
/// Manages transaction tracking and delegates operations to specialized service modules
/// 
/// The service implementation is modularized across multiple extension files:
/// - XPCService+Authentication: Certificate and secret management
/// - XPCService+GraphAPI: Microsoft Graph API operations
/// - XPCService+Settings: Configuration management
/// - XPCService+TaskScheduling: Launch Daemon scheduling
/// - XPCService+ViewCalls: Main application operations
class XPCService: NSObject, XPCServiceProtocol {
    
    /// Dictionary tracking active operations to prevent concurrent access issues
    private var transactionObjects: [String: NSObject] = [:]
    
    
    /// Begins a tracked operation to prevent concurrent access to shared resources
    /// - Parameters:
    ///   - identifier: Unique identifier for the operation
    ///   - timeout: Maximum duration before automatic cleanup (default 300 seconds)
    ///   - completion: Callback indicating if operation started successfully
    func beginOperation(identifier: String, timeout: TimeInterval = 300, completion: @escaping (Bool) -> Void) {
        if self.transactionObjects[identifier] != nil {
            completion(false)
            return
        }
        
        self.transactionObjects[identifier] = NSObject()
        Logger.info("Transaction begun for: \(identifier)", category: .core)
        
        // Add automatic timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { [weak self] in
            if self?.transactionObjects[identifier] != nil {
                Logger.info("Transaction \(identifier) timed out after \(timeout) seconds", category: .core)
                self?.transactionObjects.removeValue(forKey: identifier)
            }
        }
        
        completion(true)
    }
    
    /// Ends a tracked operation and releases associated resources
    /// - Parameters:
    ///   - identifier: Unique identifier of the operation to end
    ///   - completion: Callback indicating operation ended successfully
    func endOperation(identifier: String, completion: @escaping (Bool) -> Void) {
        // Remove the transaction object
        if self.transactionObjects[identifier] != nil {
            self.transactionObjects.removeValue(forKey: identifier)
            Logger.info("Transaction ended for: \(identifier)", category: .core)
        }
        completion(true)
    }
    
    /// Simple connectivity test for XPC service health checking
    /// - Parameter completion: Callback with service availability status
    func ping(completion: @escaping (Bool) -> Void) {
        completion(true)
    }
    
    // MARK: - Status Management
    
    /// Cleans up stale operation status entries
    /// - Parameter completion: Callback with number of operations removed
    func cleanupStaleOperations(completion: @escaping (Int) -> Void) {
        let statusManager = StatusNotificationManager.shared
        let initialCount = statusManager.getAllOperations().count
        
        statusManager.cleanupStaleOperations()
        
        // Wait a moment for the cleanup to complete, then return the difference
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let finalCount = statusManager.getAllOperations().count
            let removedCount = initialCount - finalCount
            Logger.info("XPC cleanupStaleOperations: removed \(removedCount) operations", category: .automation)
            completion(removedCount)
        }
    }
    
    /// Clears all error operation status entries
    /// - Parameter completion: Callback with number of operations removed
    func clearAllErrorOperations(completion: @escaping (Int) -> Void) {
        let statusManager = StatusNotificationManager.shared
        let errorCount = statusManager.getAllOperations().values.filter { $0.status == .error }.count
        
        statusManager.clearAllErrorOperations()
        
        Logger.info("XPC clearAllErrorOperations: cleared \(errorCount) error operations", category: .automation)
        completion(errorCount)
    }
    
    /// Gets the daemon service version string
    /// - Parameter completion: Callback with version string (e.g., "1.0.0.163")
    func getDaemonVersion(completion: @escaping (String) -> Void) {
        let version = VersionInfo.getVersionString()
        Logger.info("XPC getDaemonVersion: returning \(version)", category: .core)
        completion(version)
    }
    
    /// Gets the updater tool version string
    /// - Parameter completion: Callback with version string (e.g., "1.0.0.162") or "Unknown" if unavailable
    func getUpdaterVersion(completion: @escaping (String) -> Void) {
        let updaterPath = "/Library/Application Support/Intuneomator/IntuneomatorUpdater"
        
        // Check if updater exists
        guard FileManager.default.fileExists(atPath: updaterPath) else {
            Logger.info("XPC getUpdaterVersion: updater not found at \(updaterPath)", category: .core)
            completion("Not Installed")
            return
        }
        
        // Execute updater with --version parameter
        let process = Process()
        process.executableURL = URL(fileURLWithPath: updaterPath)
        process.arguments = ["--version"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe() // Suppress error output
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            
            // Parse version from output like "IntuneomatorUpdater v1.0.0.162"
            if let versionRange = output.range(of: "v"), 
               versionRange.upperBound < output.endIndex {
                let versionString = String(output[versionRange.upperBound...])
                Logger.info("XPC getUpdaterVersion: returning \(versionString)", category: .core)
                completion(versionString)
            } else {
                Logger.info("XPC getUpdaterVersion: could not parse version from output: \(output)", category: .core)
                completion("Unknown")
            }
            
        } catch {
            Logger.error("XPC getUpdaterVersion: failed to execute updater: \(error)", category: .core)
            completion("Unknown")
        }
    }
    
}

