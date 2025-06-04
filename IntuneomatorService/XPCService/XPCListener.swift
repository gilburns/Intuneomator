//
//  XPCListener.swift
//  Intuneomator
//
//  Created by Gil Burns on 3/17/25.
//

import Foundation

/// XPC service listener for secure inter-process communication with the Intuneomator GUI
/// Handles incoming connections and delegates service requests to XPCService implementation
class XPCListener: NSObject, NSXPCListenerDelegate {
    
    /// NSXPCListener instance configured for the Intuneomator service Mach service
    let listener: NSXPCListener
    
    /// Initializes the XPC listener with the service Mach service name
    /// Sets up the listener delegate relationship for connection handling
    override init() {
        listener = NSXPCListener(machServiceName: "com.gilburns.intuneomator.service")
        super.init()
        listener.delegate = self
    }
    
    /// Starts the XPC service listener after performing first-run initialization
    /// Resumes the listener to begin accepting incoming connections from the GUI
    func start() {
        FirstRun.checkFirstRun()
        listener.resume()
    }
    
    /// NSXPCListenerDelegate method called when a new connection is requested
    /// Configures the connection with the service protocol interface and implementation
    /// - Parameters:
    ///   - listener: The XPC listener receiving the connection
    ///   - newConnection: The incoming XPC connection to configure
    /// - Returns: Always true to accept all connections
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        newConnection.exportedInterface = NSXPCInterface(with: XPCServiceProtocol.self)
        newConnection.exportedObject = XPCService()
        newConnection.resume()
        return true
    }
    
}

