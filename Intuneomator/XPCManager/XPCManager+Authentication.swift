//
//  XPCManager+Authentication.swift
//  Intuneomator
//
//  Created by Gil Burns on 5/4/25.
//

import Foundation

/// XPCManager extension for authentication credential management
/// Provides secure communication with the service for certificate and secret operations
/// All operations are executed asynchronously with proper error handling
extension XPCManager {
    
    // MARK: - Certificate Management
    /// Imports a P12 certificate file into the system keychain for authentication
    /// Delegates to the privileged service for secure keychain operations
    /// - Parameters:
    ///   - p12Data: Binary data of the P12 certificate file
    ///   - passphrase: Passphrase required to decrypt the P12 file
    ///   - completion: Callback with import success status or nil on XPC failure
    func importP12Certificate(p12Data: Data, passphrase: String, completion: @escaping (Bool?) -> Void) {
        sendRequest({ $0.importP12Certificate(p12Data: p12Data, passphrase: passphrase, reply: $1) }, completion: completion)
    }
    
    /// Checks if a private key exists in the keychain for certificate authentication
    /// Verifies availability of cryptographic material for Microsoft Graph API access
    /// - Parameter completion: Callback with key existence status or nil on XPC failure
    func privateKeyExists(completion: @escaping (Bool?) -> Void) {
        sendRequest({ $0.privateKeyExists(reply: $1) }, completion: completion)
    }
    
    /// Checks if an Entra ID client secret is stored in the keychain
    /// Verifies availability of secret-based authentication credentials
    /// - Parameter completion: Callback with secret existence status or nil on XPC failure
    func entraIDSecretKeyExists(completion: @escaping (Bool?) -> Void) {
        sendRequest({ $0.entraIDSecretKeyExists(reply: $1) }, completion: completion)
    }
    
    /// Securely stores an Entra ID client secret in the system keychain
    /// Delegates to the privileged service for secure credential storage
    /// - Parameters:
    ///   - secretKey: Client secret string from Azure AD app registration
    ///   - completion: Callback with storage success status or nil on XPC failure
    func importEntraIDSecretKey(secretKey: String, completion: @escaping (Bool?) -> Void) {
        sendRequest({ $0.importEntraIDSecretKey(secretKey: secretKey, reply: $1) }, completion: completion)
    }
    
    /// Validates stored authentication credentials against Microsoft Graph API
    /// Tests both credential validity and required permissions for Intune management
    /// - Parameter completion: Callback with validation success status or nil on XPC failure
    func validateCredentials(completion: @escaping (Bool?) -> Void) {
        sendRequest({ $0.validateCredentials(reply: $1) }, completion: completion)
    }
    
}

// MARK: - Usage Examples

/*
 
 XPCManager.shared.privateKeyExists { exists in
     Logger.logApp("Private key exists: \(exists ?? false)")
 }

 XPCManager.shared.entraIDSecretKeyExists { exists in
     Logger.logApp("Entra ID secret key exists: \(exists ?? false)")
 }

 */
