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
    
    /// Log type identifier for logging operations
    let logType = "XPCService"
    
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
        Logger.log("Transaction begun for: \(identifier)", logType: logType)
        
        // Add automatic timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { [weak self] in
            if self?.transactionObjects[identifier] != nil {
                Logger.log("Transaction \(identifier) timed out after \(timeout) seconds", logType: self!.logType)
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
            Logger.log("Transaction ended for: \(identifier)", logType: logType)
        }
        completion(true)
    }
    
    /// Simple connectivity test for XPC service health checking
    /// - Parameter completion: Callback with service availability status
    func ping(completion: @escaping (Bool) -> Void) {
        completion(true)
    }
    
}

