//
//  XPCManager+Certificates.swift
//  Intuneomator
//
//  Created by Gil Burns on 5/4/25.
//

import Foundation

extension XPCManager {
    
    // Certificate Methods
    func importP12Certificate(p12Data: Data, passphrase: String, completion: @escaping (Bool?) -> Void) {
        sendRequest({ $0.importP12Certificate(p12Data: p12Data, passphrase: passphrase, reply: $1) }, completion: completion)
    }
    
    func privateKeyExists(completion: @escaping (Bool?) -> Void) {
        sendRequest({ $0.privateKeyExists(reply: $1) }, completion: completion)
    }
    
    func entraIDSecretKeyExists(completion: @escaping (Bool?) -> Void) {
        sendRequest({ $0.entraIDSecretKeyExists(reply: $1) }, completion: completion)
    }
    
    func importEntraIDSecretKey(secretKey: String, completion: @escaping (Bool?) -> Void) {
        sendRequest({ $0.importEntraIDSecretKey(secretKey: secretKey, reply: $1) }, completion: completion)
    }
    
    func validateCredentials(completion: @escaping (Bool?) -> Void) {
        sendRequest({ $0.validateCredentials(reply: $1) }, completion: completion)
    }
    
}

/*
 
 XPCManager.shared.privateKeyExists { exists in
     Logger.logUser("Private key exists: \(exists ?? false)")
 }

 XPCManager.shared.entraIDSecretKeyExists { exists in
     Logger.logUser("Entra ID secret key exists: \(exists ?? false)")
 }

 */
