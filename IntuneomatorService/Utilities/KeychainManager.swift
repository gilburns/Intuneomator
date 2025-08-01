//
//  KeychainManager.swift
//  Intuneomator
//
//  Created by Gil Burns on 3/17/25.
//

import Foundation
import CommonCrypto

/// Manages secure storage and retrieval of certificates and secrets in the macOS keychain
/// Handles P12 certificate import, private key access, and Entra ID secret management
class KeychainManager {
    
    
    /// Stores a secret key in the keychain (legacy method)
    /// - Parameter secretKey: The secret key string to store
    /// - Returns: True if storage was successful, false otherwise
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

    /// Retrieves a secret key from the keychain (legacy method)
    /// - Returns: The secret key string if found, nil otherwise
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
    
    /// Stores an Entra ID client secret in the system keychain with import date tracking
    /// - Parameter secretKey: The Entra ID client secret to store
    /// - Returns: True if storage was successful, false otherwise
    static func storeEntraIDSecretKeyInKeychain(secretKey: String) -> Bool {
        let keyLabel = "com.intuneomator.entrasecret"
        let secretData = secretKey.data(using: .utf8)!

        // Use standard keychain storage (reverting the access control approach that caused -25291)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "EntraIDSecret",
            kSecAttrAccount as String: keyLabel,
            kSecValueData as String: secretData,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        // Remove any existing entry before adding a new one
        SecItemDelete(query as CFDictionary)

        // Store the secret key
        let status = SecItemAdd(query as CFDictionary, nil)

        if status == errSecSuccess {
            Logger.info("Successfully stored Entra ID secret key in keychain.", category: .core)
            
            // Update ACL using the security command line tool to add explicit permissions
            if !updateSecretKeyACLWithSecurityTool() {
                Logger.warning("Secret key stored but ACL update failed - may have permission issues after updates", category: .core)
            }
            
            // Save the import date for possible expiration notifications later
            let importDate = Date()
            if ConfigManager.writePlistValue(key: "SecretImportDate", value: importDate) {
                ConfigManager.restrictPlistPermissions()
                Logger.info("Saved Secret Imports Date to plist.", category: .core)
            } else {
                Logger.error("Failed to save secert import date to plist.", category: .core)
            }
            
            return true
        } else {
            // Add the error code to our error message function
            let errorMessage = keychainErrorMessage(status)
            Logger.error("Failed to store Entra ID secret key: \(status) (\(errorMessage))", category: .core)
            return false
        }
    }
    
    /// Updates the ACL for the secret key using the security command line tool
    /// - Returns: True if ACL update was successful, false otherwise
    private static func updateSecretKeyACLWithSecurityTool() -> Bool {
        let keyLabel = "com.intuneomator.entrasecret"
        let servicePath = "/Library/Application Support/Intuneomator/IntuneomatorService"
        
        // Try to set the partition list to allow access from the daemon service
        // Use correct parameters: -a account, -s service, -S partition-list
        let result = runSecurityCommand(args: [
            "set-generic-password-partition-list",
            "-a", keyLabel,
            "-s", "EntraIDSecret", 
            "-S", servicePath,
            "-k", ""  // Empty password will prompt, but we'll try without keychain access first
        ])
        
        if result.success {
            return true
        }
        
        // Try alternative approach without specifying keychain password
        let altResult = runSecurityCommand(args: [
            "set-generic-password-partition-list",
            "-a", keyLabel,
            "-s", "EntraIDSecret", 
            "-S", servicePath
        ])
        
        if altResult.success {
            return true
        }
        
        // If both approaches fail, log the error but don't fail the import
        Logger.warning("ACL update failed for secret key: \(result.output)", category: .core)
        
        // Consider it a non-critical failure since basic keychain storage succeeded
        return false
    }


    /// Retrieves the stored Entra ID client secret from the keychain
    /// - Returns: The Entra ID client secret if found, nil otherwise
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
            return secretKey
        } else {
            // Provide detailed error information for troubleshooting
            let errorMessage = keychainErrorMessage(status)
            Logger.error("Failed to retrieve Entra ID secret key: \(status) (\(errorMessage))", category: .core)
            
            // For permission errors, suggest remediation
            if status == errSecInteractionNotAllowed {
                Logger.error("Keychain access denied - this may be caused by daemon updates. Re-importing the secret key may resolve this issue.", category: .core)
            }
            
            
            return nil
        }
    }
    
    /// Converts keychain error codes to human-readable messages
    /// - Parameter status: OSStatus error code from keychain operations
    /// - Returns: Human-readable error description
    private static func keychainErrorMessage(_ status: OSStatus) -> String {
        switch status {
        case errSecSuccess:
            return "Success"
        case errSecParam:
            return "One or more parameters passed to the function were not valid"
        case errSecAllocate:
            return "Failed to allocate memory"
        case errSecNotAvailable:
            return "No keychain is available"
        case errSecDuplicateItem:
            return "The item already exists"
        case errSecItemNotFound:
            return "The item cannot be found"
        case errSecInteractionNotAllowed:
            return "Interaction with the Security Server is not allowed (permission denied)"
        case errSecDecode:
            return "Unable to decode the provided data"
        case errSecAuthFailed:
            return "Authorization/Authentication failed"
        case -25293:  // errSecUserCancel
            return "User canceled the operation"
        case -25308:  // errSecInteractionNotAllowed (explicit for clarity)
            return "Interaction not allowed (access denied)"
        case -25299:  // errSecInvalidKeychain
            return "Invalid keychain reference"
        case -25300:  // errSecInvalidValue
            return "Invalid value for parameter"
        case -25291:  // errSecInvalidData
            return "Invalid data provided"
        default:
            return "Unknown keychain error (\(status))"
        }
    }

    
    // MARK: - Check if Entra ID Secret Key Exists
    
    /// Checks if an Entra ID secret key exists in the keychain without retrieving it
    /// - Returns: True if the secret key exists, false otherwise
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
    
    /// Checks if an Entra ID secret key exists in the keychain with logging
    /// - Returns: True if the secret key exists, false otherwise
    static func entraIDSecretKeyExistsWithLogging() -> Bool {
        let exists = entraIDSecretKeyExists()
        Logger.info("Entra ID secret key exists: \(exists)", category: .core)
        return exists
    }

    
    // MARK: - Import p12 via Security
    
    /// Imports a P12 certificate file into the system keychain
    /// Extracts certificate information and stores it in the configuration plist
    /// - Parameters:
    ///   - p12Data: The P12 certificate file data
    ///   - passphrase: The passphrase to decrypt the P12 file
    /// - Returns: True if import was successful, false otherwise
    static func importP12CertificateToKeychain(p12Data: Data, passphrase: String) -> Bool {
        // First extract certificate info from the p12 before importing to keychain
        let importParams: [String: Any] = [kSecImportExportPassphrase as String: passphrase]
        var items: CFArray?
        
        let status = SecPKCS12Import(p12Data as CFData, importParams as CFDictionary, &items)
        if status != errSecSuccess {
            Logger.error("Failed to import .p12 file: \(status)", category: .core)
            return false
        }
        
        guard let itemsArray = items as? [[String: Any]],
              let firstItem = itemsArray.first else {
            Logger.info("No valid items found in the .p12 file.", category: .core)
            return false
        }
        
        // Extract identity and certificate for identification
        if firstItem[kSecImportItemIdentity as String] == nil {
            Logger.info("No identity found in .p12", category: .core)
            return false
        }
        
        let identity = firstItem[kSecImportItemIdentity as String] as! SecIdentity
        
        var certificate: SecCertificate?
        let certStatus = SecIdentityCopyCertificate(identity, &certificate)
        if certStatus != errSecSuccess || certificate == nil {
            Logger.error("Failed to extract certificate from identity", category: .core)
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
            Logger.error("Failed to create temporary directory: \(error)", category: .core)
            return false
        }
        
        // Write the p12 data to a temporary file
        let p12Path = tempDir.appendingPathComponent("identity.p12")
        do {
            try p12Data.write(to: p12Path)
        } catch {
            Logger.error("Failed to write .p12 to temp file: \(error)", category: .core)
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
            Logger.info("Info: Cleaned up temp files: \(tempDir)", category: .core)

        } catch {
            Logger.error("Warning: Failed to clean up temp files: \(error)", category: .core)
        }
        
        if !result.success {
            if result.output.contains("already exists") {
                Logger.info("Item already exists in keychain, considering this a success", category: .core)
                return true
            }
            Logger.error("Failed to import .p12 to System keychain: \(result.output)", category: .core)
            return false
        }
        
        Logger.info("Successfully imported .p12 into the system keychain.", category: .core)
        return true
    }

    // MARK: - Get Private Key Info
    
    /// Retrieves the private key from the keychain that matches the stored certificate info
    /// Uses subject name and thumbprint to identify the correct certificate
    /// - Returns: The private key if found and matching, nil otherwise
    static func getPrivateKeyFromKeychain() -> SecKey? {
        // Load saved certificate info from plist
        let certificateManager = CertificateManager()
        guard let certInfo = certificateManager.loadCertificateInfoFromPlist(),
              !certInfo.subjectName.isEmpty,
              !certInfo.thumbprint.isEmpty else {
            Logger.info("Missing certificate info in plist", category: .core)
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
            Logger.error("Failed to find identities: \(status)", category: .core)
            return nil
        }
        
        guard let identities = result as? [SecIdentity] else {
            Logger.error("Failed to cast identity results", category: .core)
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
//                            Logger.info("Found matching certificate and extracted private key", category: .core)
                            return key
                        }
                    }
                }
            }
        }
        
        Logger.info("Could not find matching certificate and private key", category: .core)
        return nil
    }

    
    // MARK: - Check if Matching Private Key Exists
    
    /// Checks if a private key exists in the keychain that matches the stored certificate info
    /// - Returns: True if a matching private key exists, false otherwise
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
    
    
    /// Checks if a private key exists in the keychain with logging
    /// - Returns: True if a matching private key exists, false otherwise
    static func privateKeyExistsWithLogging() -> Bool {
        let exists = privateKeyExists()
        Logger.info("Private key exists: \(exists)", category: .core)
        return exists
    }

    // MARK: - Singleton Instance
    
    /// Shared singleton instance for generic keychain operations
    static let shared = KeychainManager()
    
    /// Private initializer for singleton pattern
    private init() {}
    
    // MARK: - Generic Keychain Operations
    
    /// Stores a generic string value in the keychain
    /// - Parameters:
    ///   - value: The string value to store
    ///   - key: The key identifier for the value
    /// - Returns: True if storage was successful, false otherwise
    @discardableResult
    func setValue(_ value: String, for key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "Intuneomator",
            kSecAttrAccount as String: key,
            kSecValueData as String: value.data(using: .utf8)!,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        // Remove existing item first
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    /// Retrieves a generic string value from the keychain
    /// - Parameter key: The key identifier for the value
    /// - Returns: The string value if found, nil otherwise
    func getValue(for key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "Intuneomator",
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    /// Removes a generic string value from the keychain
    /// - Parameter key: The key identifier for the value to remove
    /// - Returns: True if removal was successful, false otherwise
    @discardableResult
    func removeValue(for key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "Intuneomator",
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
    
    // MARK: - Run Security Command
    
    /// Executes the macOS security command-line tool with specified arguments
    /// - Parameter args: Array of arguments to pass to the security command
    /// - Returns: Tuple containing success status and command output
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
            
            // Only log security tool output if there's an error
            if process.terminationStatus != 0 {
                Logger.warning("Security tool failed: \(output)", category: .core)
            }
            
            return (process.terminationStatus == 0, output)
        } catch {
            Logger.error("Failed to execute security tool: \(error)", category: .core)
            return (false, error.localizedDescription)
        }
    }

}
