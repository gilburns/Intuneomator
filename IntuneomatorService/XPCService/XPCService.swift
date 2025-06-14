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
    
}

