//
//  XPCService+Certificates.swift
//  Intuneomator
//
//  Created by Gil Burns on 5/4/25.
//

import Foundation

/// XPCService extension for authentication-related operations
/// Handles certificate and secret management for Microsoft Entra ID authentication
extension XPCService {
    
    // MARK: - Certificate Management
    
    /// Imports a P12 certificate file into the system keychain for certificate-based authentication
    /// - Parameters:
    ///   - p12Data: The P12 certificate file data
    ///   - passphrase: Passphrase to decrypt the P12 file
    ///   - reply: Callback with import success status
    func importP12Certificate(p12Data: Data, passphrase: String, reply: @escaping (Bool) -> Void) {
        let success = KeychainManager.importP12CertificateToKeychain(p12Data: p12Data, passphrase: passphrase)
        reply(success)
    }
    
    /// Checks if a private key exists in the keychain for certificate authentication
    /// - Parameter reply: Callback indicating if a matching private key is available
    func privateKeyExists(reply: @escaping (Bool) -> Void) {
        let exists = KeychainManager.privateKeyExists()
        reply(exists)
    }
    
    
    // MARK: - Secret Management
    
    /// Imports an Entra ID client secret into the keychain for secret-based authentication
    /// - Parameters:
    ///   - secretKey: The client secret string from Azure AD app registration
    ///   - reply: Callback with import success status
    func importEntraIDSecretKey(secretKey: String, reply: @escaping (Bool) -> Void) {
        let success = KeychainManager.storeEntraIDSecretKeyInKeychain(secretKey: secretKey)
        reply(success)
    }
    
    /// Checks if an Entra ID secret key exists in the keychain
    /// - Parameter reply: Callback indicating if a secret key is stored
    func entraIDSecretKeyExists(reply: @escaping (Bool) -> Void) {
        let exists = KeychainManager.entraIDSecretKeyExists()
        reply(exists)
    }
    
    // MARK: - Authentication Validation
    
    /// Validates stored authentication credentials against Microsoft Graph API
    /// Tests both credential validity and required permissions (DeviceManagementApps.ReadWrite.All)
    /// - Parameter reply: Callback indicating if credentials are valid and have required permissions
    func validateCredentials(reply: @escaping (Bool) -> Void) {
        Task {
            do {
                let authenticator = EntraAuthenticator.shared
                let result = try await authenticator.ValidateCredentials()
                reply(result)
            } catch {
                Logger.error("Credential validation failed: \(error.localizedDescription)", category: .core)
                reply(false)
            }
        }
    }
    
    // MARK: - Certificate Retrieval
    
    /// Retrieves the stored authentication certificate data from the system keychain
    /// - Parameter reply: Callback with certificate data or nil if not found
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
    
    /// Retrieves the configured authentication method from settings
    /// - Parameter reply: Callback with authentication method ("certificate" or "secret")
    func getAuthMethod(reply: @escaping (String) -> Void) {
        let authMethod: String = ConfigManager.readPlistValue(key: "AuthMethod") ?? "certificate"
        reply(authMethod)
    }
    
}
