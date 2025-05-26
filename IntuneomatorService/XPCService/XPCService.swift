//
//  XPCService.swift
//  Intuneomator
//
//  Created by Gil Burns on 3/17/25.
//

import Foundation

// MARK: - XPCService
class XPCService: NSObject, XPCServiceProtocol {
    
    private var transactionObjects: [String: NSObject] = [:]
        
    let logType = "XPCService"
    
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
    
    func endOperation(identifier: String, completion: @escaping (Bool) -> Void) {
        // Remove the transaction object
        if self.transactionObjects[identifier] != nil {
            self.transactionObjects.removeValue(forKey: identifier)
            Logger.log("Transaction ended for: \(identifier)", logType: logType)
        }
        completion(true)
    }
    
    func ping(completion: @escaping (Bool) -> Void) {
        completion(true)
    }
    
    
    func sendMessage(_ message: String, reply: @escaping (String) -> Void) {
        Logger.log("Daemon received: \(message)", logType: logType)
        reply("Daemon Response: Received '\(message)' at \(Date())")
    }

    
}

