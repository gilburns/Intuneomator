//
//  KeychainManager.swift
//  Intuneomator
//
//  Created by Gil Burns on 3/17/25.
//

import Foundation
import CommonCrypto

class KeychainManager {
    static func storeSecretKey(secretKey: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "EntraIDSecret",
            kSecAttrAccount as String: "com.intuneomator.entrasecret",
            kSecValueData as String: secretKey.data(using: .utf8)!,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    static func retrieveSecretKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "EntraIDSecret",
            kSecAttrAccount as String: "com.intuneomator.entrasecret",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    // MARK: - Store and Retrieve Entra Secret Key
    static func storeEntraIDSecretKeyInKeychain(secretKey: String) -> Bool {
        let keyLabel = "com.intuneomator.entrasecret"
        let secretData = secretKey.data(using: .utf8)!

        // Prepare the keychain query
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "EntraIDSecret",
            kSecAttrAccount as String: keyLabel,
            kSecValueData as String: secretData,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock  // Ensures access after reboot
        ]

        // Remove any existing entry before adding a new one
        SecItemDelete(query as CFDictionary)

        // Store the secret key
        let status = SecItemAdd(query as CFDictionary, nil)

        if status == errSecSuccess {
            Logger.log("Successfully stored Entra ID secret key in the system keychain.", logType: "KeychainManager")
            
            // Save the import date for possible expiration notifications later
            let importDate = Date()
            if ConfigManager.writePlistValue(key: "SecretImportDate", value: importDate) {
                ConfigManager.restrictPlistPermissions()
                Logger.log("Saved Secret Imports Date to plist.", logType: "KeychainManager")
            } else {
                Logger.log("Failed to save secert import date to plist.", logType: "KeychainManager")
            }
            
            return true
        } else {
            Logger.log("Failed to store Entra ID secret key: \(status)", logType: "KeychainManager")
            return false
        }
    }


    static func retrieveEntraIDSecretKey() -> String? {
        let keyLabel = "com.intuneomator.entrasecret"
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "EntraIDSecret",
            kSecAttrAccount as String: keyLabel,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        if status == errSecSuccess, let secretData = item as? Data, let secretKey = String(data: secretData, encoding: .utf8) {
            Logger.log("Successfully retrieved Entra ID secret key from keychain.", logType: "KeychainManager")
            return secretKey
        } else {
            Logger.log("Failed to retrieve Entra ID secret key: \(status)", logType: "KeychainManager")
            return nil
        }
    }

    
    // MARK: - Check if Entra ID Secret Key Exists
    static func entraIDSecretKeyExists() -> Bool {
        let keyLabel = "com.intuneomator.entrasecret"
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "EntraIDSecret",
            kSecAttrAccount as String: keyLabel,
            kSecReturnData as String: false, // We don't need the data
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
     static func entraIDSecretKeyExistsWithLogging() -> Bool {
         let exists = entraIDSecretKeyExists()
         Logger.log("Entra ID secret key exists: \(exists)", logType: "KeychainManager")
         return exists
     }

    
    // MARK: - Import p12 via Security

    static func importP12CertificateToKeychain(p12Data: Data, passphrase: String) -> Bool {
        // First extract certificate info from the p12 before importing to keychain
        let importParams: [String: Any] = [kSecImportExportPassphrase as String: passphrase]
        var items: CFArray?
        
        let status = SecPKCS12Import(p12Data as CFData, importParams as CFDictionary, &items)
        if status != errSecSuccess {
            Logger.log("Failed to import .p12 file: \(status)", logType: "KeychainManager")
            return false
        }
        
        guard let itemsArray = items as? [[String: Any]],
              let firstItem = itemsArray.first else {
            Logger.log("No valid items found in the .p12 file.", logType: "KeychainManager")
            return false
        }
        
        // Extract identity and certificate for identification
        if firstItem[kSecImportItemIdentity as String] == nil {
            Logger.log("No identity found in .p12", logType: "KeychainManager")
            return false
        }
        
        let identity = firstItem[kSecImportItemIdentity as String] as! SecIdentity
        
        var certificate: SecCertificate?
        let certStatus = SecIdentityCopyCertificate(identity, &certificate)
        if certStatus != errSecSuccess || certificate == nil {
            Logger.log("Failed to extract certificate from identity", logType: "KeychainManager")
            return false
        }
        
        // Extract identifiable information
        let certInfo = CertificateManager.extractCertificateInfo(certificate!)
        
        // Save this information to preferences
        let certificateManager = CertificateManager()
        certificateManager.saveCertificateInfoToPlist(certInfo)

        // Now proceed with importing to the System keychain
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        do {
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        } catch {
            Logger.log("Failed to create temporary directory: \(error)", logType: "KeychainManager")
            return false
        }
        
        // Write the p12 data to a temporary file
        let p12Path = tempDir.appendingPathComponent("identity.p12")
        do {
            try p12Data.write(to: p12Path)
        } catch {
            Logger.log("Failed to write .p12 to temp file: \(error)", logType: "KeychainManager")
            return false
        }
        
        // Import with permissions for your service
        let result = runSecurityCommand(
            args: ["import", p12Path.path,
                   "-k", "/Library/Keychains/System.keychain",
                   "-P", passphrase,
                   "-T", "/Library/Application Support/Intuneomator/IntuneomatorService"]
        )
        
        // Clean up
        do {
            try FileManager.default.removeItem(at: tempDir)
            Logger.log("Info: Cleaned up temp files: \(tempDir)", logType: "KeychainManager")

        } catch {
            Logger.log("Warning: Failed to clean up temp files: \(error)", logType: "KeychainManager")
        }
        
        if !result.success {
            if result.output.contains("already exists") {
                Logger.log("Item already exists in keychain, considering this a success", logType: "KeychainManager")
                return true
            }
            Logger.log("Failed to import .p12 to System keychain: \(result.output)", logType: "KeychainManager")
            return false
        }
        
        Logger.log("Successfully imported .p12 into the system keychain.", logType: "KeychainManager")
        return true
    }

    // MARK: - Get Private Key Info
    static func getPrivateKeyFromKeychain() -> SecKey? {
        // Load saved certificate info from plist
        let certificateManager = CertificateManager()
        guard let certInfo = certificateManager.loadCertificateInfoFromPlist(),
              !certInfo.subjectName.isEmpty,
              !certInfo.thumbprint.isEmpty else {
            Logger.log("Missing certificate info in plist", logType: "KeychainManager")
            return nil
        }
        
        // Find the identity matching our saved subject name
        let query: [String: Any] = [
            kSecClass as String: kSecClassIdentity,
            kSecReturnRef as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]
        
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status != errSecSuccess {
            Logger.log("Failed to find identities: \(status)", logType: "KeychainManager")
            return nil
        }
        
        guard let identities = result as? [SecIdentity] else {
            Logger.log("Failed to cast identity results", logType: "KeychainManager")
            return nil
        }
        
        // For each identity, check if it matches our saved info
        for identity in identities {
            var certificate: SecCertificate?
            let certStatus = SecIdentityCopyCertificate(identity, &certificate)
            
            if certStatus == errSecSuccess, let cert = certificate {
                // Check subject name first (faster check)
                let subject = SecCertificateCopySubjectSummary(cert) as String? ?? ""
                
                if subject == certInfo.subjectName {
                    // Verify with thumbprint for extra certainty
                    let certData = SecCertificateCopyData(cert) as Data
                    var digest = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
                    
                    certData.withUnsafeBytes { buffer in
                        _ = CC_SHA1(buffer.baseAddress, CC_LONG(buffer.count), &digest)
                    }
                    
                    let thumbprint = digest.map { String(format: "%02X", $0) }.joined()
                    
                    if thumbprint == certInfo.thumbprint {
                        // Found a match - extract private key
                        var privateKey: SecKey?
                        let keyStatus = SecIdentityCopyPrivateKey(identity, &privateKey)
                        
                        if keyStatus == errSecSuccess, let key = privateKey {
//                            Logger.log("Found matching certificate and extracted private key", logType: "KeychainManager")
                            return key
                        }
                    }
                }
            }
        }
        
        Logger.log("Could not find matching certificate and private key", logType: "KeychainManager")
        return nil
    }

    
    // MARK: - Check if Matching Private Key Exists
    static func privateKeyExists() -> Bool {
        let certificateManager = CertificateManager()
        guard let certInfo = certificateManager.loadCertificateInfoFromPlist(),
              !certInfo.subjectName.isEmpty,
              !certInfo.thumbprint.isEmpty else {
            return false
        }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassIdentity,
            kSecReturnRef as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]
        
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess, let identities = result as? [SecIdentity] else {
            return false
        }
        
        for identity in identities {
            var certificate: SecCertificate?
            if SecIdentityCopyCertificate(identity, &certificate) == errSecSuccess,
               let cert = certificate {
                let subject = SecCertificateCopySubjectSummary(cert) as String? ?? ""
                if subject == certInfo.subjectName {
                    let certData = SecCertificateCopyData(cert) as Data
                    var digest = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
                    certData.withUnsafeBytes {
                        _ = CC_SHA1($0.baseAddress, CC_LONG(certData.count), &digest)
                    }
                    let thumbprint = digest.map { String(format: "%02X", $0) }.joined()
                    if thumbprint == certInfo.thumbprint {
                        return true
                    }
                }
            }
        }
        
        return false
    }
    
    
    static func privateKeyExistsWithLogging() -> Bool {
        let exists = privateKeyExists()
        Logger.log("Private key exists: \(exists)", logType: "KeychainManager")
        return exists
    }

    
    
    // MARK: - Run Security Command
    static func runSecurityCommand(args: [String]) -> (success: Bool, output: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = args
        
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: outputData, encoding: .utf8) ?? ""
            
            Logger.log("Security tool output: \(output)", logType: "KeychainManager")
            
            return (process.terminationStatus == 0, output)
        } catch {
            Logger.log("Failed to execute security tool: \(error)", logType: "KeychainManager")
            return (false, error.localizedDescription)
        }
    }

}
