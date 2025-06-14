//
//  XPCManager.swift
//  Intuneomator
//
//  Created by Gil Burns on 3/18/25.
//

import Foundation

/// Core XPC communication manager for the Intuneomator GUI application
/// Provides secure inter-process communication with the privileged IntuneomatorService
/// Manages connection lifecycle, request queuing, and error handling for all XPC operations
/// 
/// The manager implementation is modularized across multiple extension files:
/// - XPCManager+Authentication: Certificate and secret management operations
/// - XPCManager+GraphAPI: Microsoft Graph API data retrieval
/// - XPCManager+Settings: Configuration and preference management
/// - XPCManager+TaskScheduling: Launch Daemon scheduling operations
/// - XPCManager+ViewCalls: Main application and view controller operations
class XPCManager {
    
    /// Shared singleton instance for application-wide XPC communication
    static let shared = XPCManager()
    
    /// Active XPC connection to the IntuneomatorService
    var connection: NSXPCConnection?
    
    /// Concurrent dispatch queue for handling XPC requests efficiently
    private let requestQueue = DispatchQueue(label: "com.gilburns.xpcRequestQueue", attributes: .concurrent)
    
    /// Private initializer enforcing singleton pattern
    /// Automatically establishes XPC connection upon instantiation
    private init() {
        setupConnection()
    }
    
    /// Establishes privileged XPC connection to the IntuneomatorService
    /// Configures remote object interface and class allowlists for secure communication
    private func setupConnection() {
        
        connection = NSXPCConnection(machServiceName: "com.gilburns.intuneomator.service",
                                     options: .privileged)
        
        let interface = NSXPCInterface(with: XPCServiceProtocol.self)

        // Configure class allowlist for scheduled task serialization
        interface.setClasses(
            [ScheduledTime.self] as NSSet as? Set<AnyHashable> ?? [],
            for: #selector(XPCServiceProtocol.createOrUpdateScheduledTask(
                label:argument:scheduleData:withReply:)),
            argumentIndex: 2,
            ofReply: false
        )
        
        connection?.remoteObjectInterface = interface
        connection?.resume()
    }
    
    /// Generic XPC request dispatcher with error handling and queue management
    /// Provides type-safe request execution with automatic error logging
    /// - Parameters:
    ///   - request: Closure defining the XPC service call with completion handler
    ///   - completion: Callback executed with request result or nil on failure
    func sendRequest<T>(_ request: @escaping (XPCServiceProtocol, @escaping (T?) -> Void) -> Void, completion: @escaping (T?) -> Void) {
        requestQueue.async { [weak self] in
            guard let service = self?.connection?.remoteObjectProxyWithErrorHandler({ error in
                Logger.info("XPCManager: XPC connection error: \(error)", category: .core, toUserDirectory: true)
                completion(nil)
            }) as? XPCServiceProtocol else {
                completion(nil)
                return
            }
            request(service, completion)
        }
    }
    
    // MARK: - Transaction Lifecycle Management
    
    /// Begins a tracked XPC service transaction to prevent concurrent operations
    /// Useful for ensuring exclusive access to shared resources during complex operations
    /// - Parameters:
    ///   - identifier: Unique identifier for the transaction (default: "mainOperation")
    ///   - completion: Callback with transaction start success status
    func beginXPCServiceTransaction(identifier: String = "mainOperation", completion: @escaping (Bool?) -> Void) {
        sendRequest({ $0.beginOperation(identifier: identifier, timeout: 300, completion: $1) }, completion: completion)
    }
    
    /// Ends a tracked XPC service transaction and releases associated resources
    /// Should be called to complete operations started with beginXPCServiceTransaction
    /// - Parameters:
    ///   - identifier: Unique identifier of the transaction to end
    ///   - completion: Callback with transaction end success status
    func endXPCServiceTransaction(identifier: String = "mainOperation", completion: @escaping (Bool?) -> Void) {
        sendRequest({ $0.endOperation(identifier: identifier, completion: $1) }, completion: completion)
    }
    
    /// Performs connectivity test to verify XPC service availability
    /// Useful for health checking and connection validation
    /// - Parameter completion: Callback with service availability status
    func checkXPCServiceRunning(completion: @escaping (Bool?) -> Void) {
        sendRequest({ $0.ping(completion: $1) }, completion: completion)
    }
        
}

// MARK: - Usage Examples

/*
  
 
 XPCManager.shared.getAuthMethod { authMethod in
     DispatchQueue.main.async {
         self.authMethodPopUpButton.selectItem(withTitle: authMethod?.capitalized ?? "Certificate")
     }
 }

 XPCManager.shared.getTenantID { tenantID in
     DispatchQueue.main.async {
         self.tenantIdTextField.stringValue = tenantID ?? ""
     }
 }

 XPCManager.shared.getApplicationID { appID in
     DispatchQueue.main.async {
         self.appIdTextField.stringValue = appID ?? ""
     }
 }

 
 
 @IBAction func saveSecretKeyButtonClicked(_ sender: Any) {
     let secretKeyText = secretKeyTextField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
     if secretKeyText.isEmpty {
         Logger.info("Please enter a secret key.", category: .core, toUserDirectory: true)
         return
     }
     
     Logger.info("Saving secret key...", category: .core, toUserDirectory: true)
     XPCManager.shared.importEntraIDSecretKey(secretKey: secretKeyText) { success in
         if success ?? false {
             Logger.info("Successfully imported Entra ID secret key.", category: .core, toUserDirectory: true)
         } else {
             Logger.info("Failed to import Entra ID secret key.", category: .core, toUserDirectory: true)
         }
     }
 }
 
 @IBAction func chooseP12FileButtonClicked(_ sender: Any) {
     guard let passphrase = p12PasscodeTextField?.stringValue.trimmingCharacters(in: .whitespacesAndNewlines), !passphrase.isEmpty else {
         Logger.info("Passcode is required.", category: .core, toUserDirectory: true)
         return
     }
     
     chooseP12File()
 }
 
 func chooseP12File() {
     let openPanel = NSOpenPanel()
     openPanel.allowedContentTypes = [.p12]
     openPanel.allowsMultipleSelection = false
     openPanel.canChooseDirectories = false
     openPanel.canChooseFiles = true
     
     if openPanel.runModal() == .OK, let url = openPanel.url {
         do {
             let p12Data = try Data(contentsOf: url)
             XPCManager.shared.importP12Certificate(p12Data: p12Data, passphrase: p12PasscodeTextField.stringValue) { success in
                 DispatchQueue.main.async {
                     if success ?? false {
                         Logger.info("Successfully imported .p12 into the daemon.", category: .core, toUserDirectory: true)
                     } else {
                         Logger.info("Failed to import .p12.", category: .core, toUserDirectory: true)
                     }
                 }
             }
         } catch {
             Logger.info("Failed to read .p12 file: \(error, category: .core, toUserDirectory: true)")
         }
     }
 }
 
 @IBAction func authMethodChanged(_ sender: NSPopUpButton) {
     let selectedMethod = sender.selectedItem?.title.lowercased() ?? "certificate"
     XPCManager.shared.setAuthMethod(selectedMethod) { success in
         if success ?? false {
             Logger.info("Successfully updated auth method to: \(selectedMethod, category: .core, toUserDirectory: true)")
         } else {
             Logger.info("Failed to update auth method.", category: .core, toUserDirectory: true)
         }
     }
 }
 
 @IBAction func tenantIDChanged(_ sender: NSTextField) {
     guard let tenantIDString = tenantIdTextField?.stringValue.trimmingCharacters(in: .whitespacesAndNewlines), !tenantIDString.isEmpty else {
         Logger.info("Tenant ID is required.", category: .core, toUserDirectory: true)
         return
     }
     Logger.info("Tenant ID changed to: \(tenantIDString, category: .core, toUserDirectory: true)")
     XPCManager.shared.setTenantID(tenantIDString) { success in
         if success ?? false {
             Logger.info("Successfully updated tenant ID to: \(tenantIDString, category: .core, toUserDirectory: true)")
         } else {
             Logger.info("Failed to update tenant ID.", category: .core, toUserDirectory: true)
         }
     }
 }
 
 @IBAction func appIDChanged(_ sender: NSTextField) {
     guard let appIDString = appIdTextField?.stringValue.trimmingCharacters(in: .whitespacesAndNewlines), !appIDString.isEmpty else {
         Logger.info("App ID is required.", category: .core, toUserDirectory: true)
         return
     }
     Logger.info("App ID changed to: \(appIDString, category: .core, toUserDirectory: true)")
     XPCManager.shared.setApplicationID(appIDString) { success in
         if success ?? false {
             Logger.info("Successfully updated app ID to: \(appIDString, category: .core, toUserDirectory: true)")
         } else {
             Logger.info("Failed to update app ID.", category: .core, toUserDirectory: true)
         }
     }
 }

 
 */
