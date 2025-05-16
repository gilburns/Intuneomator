//
//  XPCManager.swift
//  Intuneomator
//
//  Created by Gil Burns on 3/18/25.
//

import Foundation

class XPCManager {
    static let shared = XPCManager()
    var connection: NSXPCConnection?
    
    private let requestQueue = DispatchQueue(label: "com.gilburns.xpcRequestQueue", attributes: .concurrent)
    
    private init() {
        setupConnection()
    }
    
    private func setupConnection() {
        
        connection = NSXPCConnection(machServiceName: "com.gilburns.intuneomator.service",
                                     options: .privileged)
        
        let interface = NSXPCInterface(with: XPCServiceProtocol.self)

        interface.setClasses(
            [ScheduledTime.self] as NSSet as? Set<AnyHashable> ?? [],
            for: #selector(XPCServiceProtocol.createOrUpdateScheduledTask(
                label:argument:scheduleData:withReply:)),
            argumentIndex: 2,
            ofReply: false
        )
        
        connection?.remoteObjectInterface = interface
//        connection?.remoteObjectInterface = NSXPCInterface(with: XPCServiceProtocol.self)
        connection?.resume()
    }
    
    func sendRequest<T>(_ request: @escaping (XPCServiceProtocol, @escaping (T?) -> Void) -> Void, completion: @escaping (T?) -> Void) {
        requestQueue.async { [weak self] in
            guard let service = self?.connection?.remoteObjectProxyWithErrorHandler({ error in
                Logger.logUser("XPCManager: XPC connection error: \(error)")
                completion(nil)
            }) as? XPCServiceProtocol else {
                completion(nil)
                return
            }
            request(service, completion)
        }
    }
    
    // Lifecycle Methods
    func beginXPCServiceTransaction(identifier: String = "mainOperation", completion: @escaping (Bool?) -> Void) {
        sendRequest({ $0.beginOperation(identifier: identifier, timeout: 300, completion: $1) }, completion: completion)
    }
    
    func endXPCServiceTransaction(identifier: String = "mainOperation", completion: @escaping (Bool?) -> Void) {
        sendRequest({ $0.endOperation(identifier: identifier, completion: $1) }, completion: completion)
    }
    
    func checkXPCServiceRunning(completion: @escaping (Bool?) -> Void) {
        sendRequest({ $0.ping(completion: $1) }, completion: completion)
    }
    
    func sendMessageToDaemon(message: String, completion: @escaping (String?) -> Void) {
        sendRequest({ $0.sendMessage(message, reply: $1) }, completion: completion)
    }
    
}


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
         Logger.logUser("Please enter a secret key.")
         return
     }
     
     Logger.logUser("Saving secret key...")
     XPCManager.shared.importEntraIDSecretKey(secretKey: secretKeyText) { success in
         if success ?? false {
             Logger.logUser("Successfully imported Entra ID secret key.")
         } else {
             Logger.logUser("Failed to import Entra ID secret key.")
         }
     }
 }
 
 @IBAction func chooseP12FileButtonClicked(_ sender: Any) {
     guard let passphrase = p12PasscodeTextField?.stringValue.trimmingCharacters(in: .whitespacesAndNewlines), !passphrase.isEmpty else {
         Logger.logUser("Passcode is required.")
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
                         Logger.logUser("Successfully imported .p12 into the daemon.")
                     } else {
                         Logger.logUser("Failed to import .p12.")
                     }
                 }
             }
         } catch {
             Logger.logUser("Failed to read .p12 file: \(error)")
         }
     }
 }
 
 @IBAction func authMethodChanged(_ sender: NSPopUpButton) {
     let selectedMethod = sender.selectedItem?.title.lowercased() ?? "certificate"
     XPCManager.shared.setAuthMethod(selectedMethod) { success in
         if success ?? false {
             Logger.logUser("Successfully updated auth method to: \(selectedMethod)")
         } else {
             Logger.logUser("Failed to update auth method.")
         }
     }
 }
 
 @IBAction func tenantIDChanged(_ sender: NSTextField) {
     guard let tenantIDString = tenantIdTextField?.stringValue.trimmingCharacters(in: .whitespacesAndNewlines), !tenantIDString.isEmpty else {
         Logger.logUser("Tenant ID is required.")
         return
     }
     Logger.logUser("Tenant ID changed to: \(tenantIDString)")
     XPCManager.shared.setTenantID(tenantIDString) { success in
         if success ?? false {
             Logger.logUser("Successfully updated tenant ID to: \(tenantIDString)")
         } else {
             Logger.logUser("Failed to update tenant ID.")
         }
     }
 }
 
 @IBAction func appIDChanged(_ sender: NSTextField) {
     guard let appIDString = appIdTextField?.stringValue.trimmingCharacters(in: .whitespacesAndNewlines), !appIDString.isEmpty else {
         Logger.logUser("App ID is required.")
         return
     }
     Logger.logUser("App ID changed to: \(appIDString)")
     XPCManager.shared.setApplicationID(appIDString) { success in
         if success ?? false {
             Logger.logUser("Successfully updated app ID to: \(appIDString)")
         } else {
             Logger.logUser("Failed to update app ID.")
         }
     }
 }

 
 */
