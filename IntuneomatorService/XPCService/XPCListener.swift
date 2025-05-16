//
//  XPCListener.swift
//  Intuneomator
//
//  Created by Gil Burns on 3/17/25.
//

import Foundation

// MARK: - XPCListener
class XPCListener: NSObject, NSXPCListenerDelegate {
    let listener: NSXPCListener
    
    override init() {
        listener = NSXPCListener(machServiceName: "com.gilburns.intuneomator.service")
        super.init()
        listener.delegate = self
    }
    
    func start() {
        FirstRun.checkFirstRun()
        listener.resume()
    }
    
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        newConnection.exportedInterface = NSXPCInterface(with: XPCServiceProtocol.self)
        newConnection.exportedObject = XPCService()
        newConnection.resume()
        return true
    }
    
}

