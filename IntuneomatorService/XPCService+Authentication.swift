//
//  XPCService+Certificates.swift
//  Intuneomator
//
//  Created by Gil Burns on 5/4/25.
//

import Foundation

extension XPCService {
    
    // MARK: - Certificate Methods
    func importP12Certificate(p12Data: Data, passphrase: String, reply: @escaping (Bool) -> Void) {
        let success = KeychainManager.importP12CertificateToKeychain(p12Data: p12Data, passphrase: passphrase)
        reply(success)
    }
    
    func privateKeyExists(reply: @escaping (Bool) -> Void) {
        let exists = KeychainManager.privateKeyExists()
        reply(exists)
    }
    
    
    func importEntraIDSecretKey(secretKey: String, reply: @escaping (Bool) -> Void) {
        let success = KeychainManager.storeEntraIDSecretKeyInKeychain(secretKey: secretKey)
        reply(success)
    }
    
    func entraIDSecretKeyExists(reply: @escaping (Bool) -> Void) {
        let exists = KeychainManager.entraIDSecretKeyExists()
        reply(exists)
    }
    
    func validateCredentials(reply: @escaping (Bool) -> Void) {
        Task {
            do {
                let authenticator = EntraAuthenticator()
                let result = try await authenticator.ValidateCredentials()
                reply(result)
            } catch {
                Logger.log("Credential validation failed: \(error.localizedDescription)", logType: "XPCService")
                reply(false)
            }
        }
    }
    
    func getCertificate(reply: @escaping (Data?) -> Void) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassCertificate,
            kSecAttrLabel as String: "intuneomator.auth.cert",
            kSecReturnData as String: true,
            kSecUseKeychain as String: "/Library/Keychains/System.keychain"
        ]
        
        var certRef: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &certRef)
        
        if status == errSecSuccess, let certData = certRef as? Data {
            reply(certData)
        } else {
            reply(nil)
        }
    }
    
    func getAuthMethod(reply: @escaping (String) -> Void) {
        let authMethod: String = ConfigManager.readPlistValue(key: "AuthMethod") ?? "certificate"
        reply(authMethod)
    }
    
}
