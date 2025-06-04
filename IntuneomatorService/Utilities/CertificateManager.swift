//
//  CertificateManager.swift
//  Intuneomator
//
//  Created by Gil Burns on 3/17/25.
//

import Foundation
import Security
import CommonCrypto

/// Manages X.509 certificate operations including extraction, analysis, and storage
/// Provides comprehensive certificate metadata extraction and keychain integration
class CertificateManager {
    
    /// Log type identifier for logging operations
    static let logType = "CertificateManager"
    
    /// Retrieves the SHA-1 thumbprint of a certificate by its keychain label
    /// - Parameter certificateLabel: The label used to identify the certificate in keychain
    /// - Returns: Hexadecimal SHA-1 thumbprint string, or nil if certificate not found
    static func getCertificateThumbprint(certificateLabel: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassCertificate,
            kSecAttrLabel as String: certificateLabel,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnRef as String: true,
            kSecReturnData as String: true
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let certData = item as? Data else { return nil }
        
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
        certData.withUnsafeBytes { buffer in
            _ = CC_SHA1(buffer.baseAddress, CC_LONG(buffer.count), &digest)
        }
        
        return digest.map { String(format: "%02X", $0) }.joined()
    }
    
    /// Extracts comprehensive metadata from an X.509 certificate
    /// Analyzes certificate properties to extract subject, issuer, expiration, key usage, and cryptographic details
    /// - Parameter certificate: SecCertificate reference to analyze
    /// - Returns: CertificateInfo structure containing all extracted metadata
    static func extractCertificateInfo(_ certificate: SecCertificate) -> CertificateInfo {
        // Extract subject name
        let subjectName = SecCertificateCopySubjectSummary(certificate) as String? ?? ""
        
        // Extract serial number, issuer, and expiration date
        var serialNumber = ""
        var issuerName = ""
        var expirationDate: Date? = nil
        
        var keyUsage: Int? = nil
        var dnsNames: [String]? = nil
        var algorithm: String? = nil
        var keySize: Int? = nil
        
        var error: Unmanaged<CFError>?
        if let properties = SecCertificateCopyValues(certificate, nil, &error) as? [CFString: Any] {
            // Extract serial number
            if let serialDict = properties[kSecOIDX509V1SerialNumber] as? [CFString: Any],
               let serialData = serialDict[kSecPropertyKeyValue] as? Data {
                serialNumber = serialData.map { String(format: "%02X", $0) }.joined()
            }
            
            // Extract issuer
            if let issuerDict = properties[kSecOIDX509V1IssuerName] as? [CFString: Any],
               let issuerValue = issuerDict[kSecPropertyKeyValue] as? [[CFString: Any]] {
                issuerName = String(describing: issuerValue)
            }
            
            // Extract expiration date
            // Extract expiration date
            if let validityDict = properties[kSecOIDX509V1ValidityNotAfter] as? [CFString: Any],
               let expiryValue = validityDict[kSecPropertyKeyValue] as? Date {
                expirationDate = expiryValue
            } else {
                // Try to find by string key
                for (key, value) in properties {
                    let keyString = key as String
                    if keyString == "2.5.29.24" {
                        if let validityDict = value as? [CFString: Any],
                           let expiryValue = validityDict[kSecPropertyKeyValue] as? Date {
                            expirationDate = expiryValue
                            break
                        }
                    }
                }
            }
            
            // In your main certificate extraction function
            if let keyUsageValue = extractKeyUsage(from: properties) {
                keyUsage = keyUsageValue
                Logger.log(interpretKeyUsage(keyUsageValue), logType: logType)
            } else {
                Logger.log("No key usage found in certificate", logType: logType)
            }
            
            
            // Extract DNS names
            for (key, value) in properties {
                let keyString = key as String
                if keyString == "DNSNAMES" {
                    if let namesDict = value as? [CFString: Any],
                       let names = namesDict[kSecPropertyKeyValue] as? [String] {
                        dnsNames = names
                        break
                    }
                }
            }
            
            // Comprehensive approach to extract public key algorithm and size
            extractPublicKeyInfo(from: properties, algorithm: &algorithm, keySize: &keySize)
            
            // If the primary method fails, try alternative approaches
            if algorithm == nil || keySize == nil {
                Logger.log("Primary method failed to extract key info, trying alternatives...", logType: logType)
                extractPublicKeyInfoAlternative(from: properties, certificate: certificate, algorithm: &algorithm, keySize: &keySize)
            }
            
            // Debug logging for troubleshooting
            if algorithm == nil || keySize == nil {
                logAllCertificateProperties(properties)
            }
            
            logAllCertificateProperties(properties)
            
            // Debug: Log all available properties
            if let properties = SecCertificateCopyValues(certificate, nil, &error) as? [CFString: Any] {
                for (key, value) in properties {
                    Logger.log("Certificate property - Key: \(key), Type: \(type(of: value))", logType: logType)
                    
                    if let propDict = value as? [CFString: Any] {
                        if let propValue = propDict[kSecPropertyKeyValue] {
                            Logger.log("  Value type: \(type(of: propValue))", logType: logType)
                        }
                    }
                }
                
                // Try alternative property keys for expiration date
                let dateKeys = [
                    kSecOIDX509V1ValidityNotAfter,
                    kSecOIDInvalidityDate,
                    kSecOIDX509V1ValidityNotBefore  // For comparison
                ]
                
                for key in dateKeys {
                    if let validityDict = properties[key] as? [CFString: Any],
                       let value = validityDict[kSecPropertyKeyValue] {
                        Logger.log("Found date for key \(key): \(value) (type: \(type(of: value)))", logType: logType)
                        
                        // If it's a date, use it
                        if let dateValue = value as? Date {
                            expirationDate = dateValue
                            Logger.log("Successfully extracted expiration date: \(dateValue)", logType: logType)
                            break
                        }
                    }
                }
            }
        }
        
        // Calculate thumbprint (SHA-1 hash)
        let certData = SecCertificateCopyData(certificate) as Data
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
        
        certData.withUnsafeBytes { buffer in
            _ = CC_SHA1(buffer.baseAddress, CC_LONG(buffer.count), &digest)
        }
        
        let thumbprint = digest.map { String(format: "%02X", $0) }.joined()
        
        return CertificateInfo(
            subjectName: subjectName,
            serialNumber: serialNumber,
            issuerName: issuerName,
            thumbprint: thumbprint,
            expirationDate: expirationDate,
            keyUsage: keyUsage,
            dnsNames: dnsNames,
            algorithm: algorithm,
            keySize: keySize
        )
    }
    
    
    /// Logs all certificate properties recursively for debugging purposes
    /// - Parameter properties: Certificate properties dictionary from SecCertificateCopyValues
    static func logAllCertificateProperties(_ properties: [CFString: Any]) {
        Logger.log("=== Full Certificate Properties for Debugging ===", logType: logType)
        
        // Function to recursively print dictionary contents
        func logDictionary(_ dict: [CFString: Any], prefix: String = "") {
            for (key, value) in dict {
                let keyString = key as String
                Logger.log("\(prefix)Key: \(keyString)", logType: logType)
                
                if let nestedDict = value as? [CFString: Any] {
                    Logger.log("\(prefix)  [Dictionary]:", logType: logType)
                    logDictionary(nestedDict, prefix: prefix + "    ")
                } else if let array = value as? [Any] {
                    Logger.log("\(prefix)  [Array] Count: \(array.count)", logType: logType)
                    for (index, item) in array.enumerated() {
                        Logger.log("\(prefix)    [\(index)] Type: \(type(of: item))", logType: logType)
                        if let dict = item as? [CFString: Any] {
                            logDictionary(dict, prefix: prefix + "      ")
                        } else {
                            Logger.log("\(prefix)      Value: \(item)", logType: logType)
                        }
                    }
                } else {
                    Logger.log("\(prefix)  Value: \(value) (Type: \(type(of: value)))", logType: logType)
                }
            }
        }
        
        logDictionary(properties)
        Logger.log("=== End of Certificate Properties ===", logType: logType)
    }
    
    
    /// Primary method for extracting public key algorithm and size from certificate properties
    /// - Parameters:
    ///   - properties: Certificate properties dictionary
    ///   - algorithm: Inout parameter for detected algorithm (RSA, ECC, etc.)
    ///   - keySize: Inout parameter for detected key size in bits
    static func extractPublicKeyInfo(from properties: [CFString: Any], algorithm: inout String?, keySize: inout Int?) {
        // Use the string OID for subject public key info: "1.2.840.113549.1.1.1" (RSA)
        //    let oidSubjectPublicKeyInfo = "1.2.840.113549.1.1" as CFString
        
        // Look for public key info properties
        for (key, value) in properties {
            let keyString = key as String
            
            // Check if this is the public key property
            if keyString == "1.2.840.113549.1.1.1" {  // RSA
                algorithm = "RSA"
                if let algDict = value as? [CFString: Any],
                   let keyData = algDict[kSecPropertyKeyValue] as? Data {
                    determineKeySize(from: keyData, algorithm: algorithm, keySize: &keySize)
                }
            } else if keyString == "1.2.840.10045.2.1" {  // ECC
                algorithm = "ECC"
                // ECC key sizes can be determined by the curve
                // Process accordingly...
            } else if keyString.hasPrefix("1.2.840.113549.1.1") {
                // This might be another RSA variant
                algorithm = "RSA"
                // Extract key data if available...
            }
            
            // Look for the Subject Key property by various identifiers
            if keyString == "subjectPublicKeyInfo" ||
                key == kSecOIDX509V1SubjectPublicKey ||
                keyString.hasPrefix("2.5.29.14") {  // Subject Key Identifier OID
                
                if let keyInfo = value as? [CFString: Any],
                   let keyData = keyInfo[kSecPropertyKeyValue] as? Data {
                    determineKeySize(from: keyData, algorithm: algorithm, keySize: &keySize)
                }
            }
        }
    }
    
    
    /// Alternative method for extracting public key information using OID analysis
    /// - Parameters:
    ///   - properties: Certificate properties dictionary
    ///   - certificate: SecCertificate reference for raw data analysis
    ///   - algorithm: Inout parameter for detected algorithm
    ///   - keySize: Inout parameter for detected key size
    static func extractPublicKeyInfoAlternative(from properties: [CFString: Any], certificate: SecCertificate, algorithm: inout String?, keySize: inout Int?) {
        // Method 2: Check for specific algorithm OIDs
        // RSA: 1.2.840.113549.1.1.1
        // ECC: 1.2.840.10045.2.1
        // DSA: 1.2.840.10040.4.1
        
        // Known algorithm OIDs
        let algorithmOIDs = [
            "1.2.840.113549.1.1.1": "RSA",
            "1.2.840.10045.2.1": "ECC",
            "1.2.840.10040.4.1": "DSA"
        ]
        
        for (key, value) in properties {
            let keyString = key as String
            
            // Check if it's one of our known algorithm OIDs
            if let alg = algorithmOIDs[keyString] {
                algorithm = alg
                
                if let algDict = value as? [CFString: Any],
                   let keyData = algDict[kSecPropertyKeyValue] as? Data {
                    determineKeySize(from: keyData, algorithm: algorithm, keySize: &keySize)
                }
            }
            
            // Method 3: Look for the SignatureAlgorithm property
            if keyString == "1.2.840.113549.1.1.11" {
                // SHA256 with RSA
                algorithm = "RSA"
            } else if keyString == "1.2.840.10045.4.3.2" {
                // SHA256 with ECDSA
                algorithm = "ECC"
            } else if keyString == "1.2.840.10045.4.3.3" {
                // SHA384 with ECDSA
                algorithm = "ECC"
            }
            
            // Method 4: Check for known curve OIDs for ECC
            // This helps determine ECC key size
            if algorithm == "ECC" && keySize == nil {
                if keyString == "1.2.840.10045.3.1.7" {
                    // P-256 curve
                    keySize = 256
                } else if keyString == "1.3.132.0.34" {
                    // P-384 curve
                    keySize = 384
                } else if keyString == "1.3.132.0.35" {
                    // P-521 curve
                    keySize = 521
                }
            }
        }
        
        // Method 5: Direct analysis of certificate data
        if (algorithm == nil || keySize == nil) && algorithm != "ECC" {
            let certData = SecCertificateCopyData(certificate) as Data
            analyzeRawCertificateData(certData, algorithm: &algorithm, keySize: &keySize)
        }
    }
    
    /// Determines cryptographic key size based on key data and algorithm type
    /// - Parameters:
    ///   - keyData: Raw key data from certificate
    ///   - algorithm: Detected algorithm type
    ///   - keySize: Inout parameter for calculated key size
    static func determineKeySize(from keyData: Data, algorithm: String?, keySize: inout Int?) {
        guard keySize == nil else { return }
        
        switch algorithm {
        case "RSA":
            // For RSA, estimate based on key data size
            // A more accurate approach would involve ASN.1 parsing
            // This is an approximation that works for most RSA keys
            let bitSize = (keyData.count - 22) * 8
            keySize = [1024, 2048, 3072, 4096].min(by: { abs($0 - bitSize) < abs($1 - bitSize) })
            
        case "ECC", "ECDSA":
            // For ECC, key size depends on the curve
            switch keyData.count {
            case _ where keyData.count <= 65:
                keySize = 256 // P-256
            case _ where keyData.count <= 97:
                keySize = 384 // P-384
            case _ where keyData.count <= 133:
                keySize = 521 // P-521
            default:
                keySize = nil
            }
            
        default:
            // For other algorithms, leave as nil or implement specific logic
            keySize = nil
        }
    }
    
    /// Analyzes raw certificate data using simplified ASN.1 pattern matching
    /// Used as a fallback when standard property extraction fails
    /// - Parameters:
    ///   - data: Raw certificate data
    ///   - algorithm: Inout parameter for detected algorithm
    ///   - keySize: Inout parameter for estimated key size
    static func analyzeRawCertificateData(_ data: Data, algorithm: inout String?, keySize: inout Int?) {
        // Simplified ASN.1 analysis - would need a proper ASN.1 parser for production code
        // This is a simplified approach that works for common certificates
        
        // Look for RSA OID sequence (0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x01, 0x01)
        let rsaOID: [UInt8] = [0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x01, 0x01]
        var foundRSA = false
        
        // Convert Data to [UInt8] for easier analysis
        let bytes = [UInt8](data)
        
        // Simple pattern matching (not fully reliable but can help in some cases)
        for i in 0..<bytes.count-rsaOID.count {
            if bytes[i..<i+rsaOID.count].elementsEqual(rsaOID) {
                algorithm = "RSA"
                foundRSA = true
                break
            }
        }
        
        // If RSA was found, try to estimate key size
        if foundRSA && keySize == nil {
            // Look for modulus size in the ASN.1 structure
            // This is a very simplified approach
            let estimatedSize = data.count / 3
            keySize = [1024, 2048, 3072, 4096].min(by: { abs($0/8 - estimatedSize) < abs($1/8 - estimatedSize) })
        }
    }
    
    /// Extracts X.509 key usage extension from certificate properties
    /// - Parameter properties: Certificate properties dictionary
    /// - Returns: Integer bitmask representing key usage flags, or nil if not found
    static func extractKeyUsage(from properties: [CFString: Any]) -> Int? {
        // Standard OID for key usage
//        let keyUsageOID = "2.5.29.15" as CFString
        
        // Look for key usage by OID
        for (key, value) in properties {
            let keyString = key as String
            
            // Check for standard key usage OID or alternative ways it might appear
            if keyString == "2.5.29.15" ||
                key == kSecOIDKeyUsage ||
                keyString.contains("keyUsage") {
                
                if let usageDict = value as? [CFString: Any] {
                    // Try multiple approaches to extract the value
                    
                    // Approach 1: Direct value
                    if let usage = usageDict[kSecPropertyKeyValue] as? Int {
                        return usage
                    }
                    
                    // Approach 2: As Data
                    else if let usageData = usageDict[kSecPropertyKeyValue] as? Data,
                            usageData.count > 0 {
                        // Convert first byte to Int
                        return Int(usageData[0])
                    }
                    
                    // Approach 3: As String representation
                    else if let usageStr = usageDict[kSecPropertyKeyValue] as? String {
                        // Try to parse integer from string
                        if let usage = Int(usageStr) {
                            return usage
                        }
                    }
                    
                    // Approach 4: Check for array of individual usages
                    else if let usages = usageDict[kSecPropertyKeyValue] as? [String] {
                        var usageValue = 0
                        
                        for usage in usages {
                            switch usage.lowercased() {
                            case "digitalsignature":
                                usageValue |= 128
                            case "nonrepudiation":
                                usageValue |= 64
                            case "keyencipherment":
                                usageValue |= 32
                            case "dataencipherment":
                                usageValue |= 16
                            case "keyagreement":
                                usageValue |= 8
                            case "keycertsign":
                                usageValue |= 4
                            case "crlsign":
                                usageValue |= 2
                            case "encipheronly":
                                usageValue |= 1
                            default:
                                break
                            }
                        }
                        
                        return usageValue
                    }
                }
            }
        }
        
        return nil
    }
    
    
    
    /// Converts key usage bitmask to human-readable string representation
    /// - Parameter usage: Key usage bitmask value
    /// - Returns: Formatted string describing enabled key usage flags
    static func interpretKeyUsage(_ usage: Int) -> String {
        var usages: [String] = []
        
        if (usage & 128) != 0 { usages.append("digitalSignature") }
        if (usage & 64) != 0 { usages.append("nonRepudiation") }
        if (usage & 32) != 0 { usages.append("keyEncipherment") }
        if (usage & 16) != 0 { usages.append("dataEncipherment") }
        if (usage & 8) != 0 { usages.append("keyAgreement") }
        if (usage & 4) != 0 { usages.append("keyCertSign") }
        if (usage & 2) != 0 { usages.append("cRLSign") }
        if (usage & 1) != 0 { usages.append("encipherOnly") }
        if (usage & 0) != 0 { usages.append("decipherOnly") }
        
        if usages.isEmpty {
            return "No key usages set (value: 0)"
        }
        
        return "Key usages: " + usages.joined(separator: ", ") + " (value: \(usage))"
    }
    
    
    // MARK: - Certificate Storage and Retrieval
    
    /// Saves certificate information to the configuration plist file
    /// - Parameter certInfo: CertificateInfo structure to persist
    func saveCertificateInfoToPlist(_ certInfo: CertificateInfo) {
        var certDict: [String: Any] = [
            "SubjectName": certInfo.subjectName,
            "SerialNumber": certInfo.serialNumber,
            "Thumbprint": certInfo.thumbprint,
            "ImportDate": Date()
        ]

        if let expiryDate = certInfo.expirationDate {
            certDict["ExpirationDate"] = expiryDate
        }
        if let keyUsage = certInfo.keyUsage {
            certDict["KeyUsage"] = keyUsage
        }
        if let dnsNames = certInfo.dnsNames {
            certDict["DNSNames"] = dnsNames
        }
        if let algorithm = certInfo.algorithm {
            certDict["Algorithm"] = algorithm
        }
        if let keySize = certInfo.keySize {
            certDict["KeySize"] = keySize
        }

        if ConfigManager.writePlistValue(key: "CertificateDetails", value: certDict) {
            ConfigManager.restrictPlistPermissions()
            Logger.log("Saved certificate info to plist.", logType: CertificateManager.logType)
        } else {
            Logger.log("Failed to save certificate info to plist.", logType: CertificateManager.logType)
        }
    }
    
    
    /// Loads previously saved certificate information from the configuration plist
    /// - Returns: CertificateInfo structure if found and valid, nil otherwise
    func loadCertificateInfoFromPlist() -> CertificateInfo? {
    guard let plistDict: [String: Any] = ConfigManager.readPlistValue(key: "CertificateDetails") else {
        Logger.log("Certificate info plist not found or empty.", logType: CertificateManager.logType)
        return nil
    }

    guard let subjectName = plistDict["SubjectName"] as? String,
          let serialNumber = plistDict["SerialNumber"] as? String,
          let thumbprint = plistDict["Thumbprint"] as? String else {
        Logger.log("Failed to extract required certificate fields from plist.", logType: CertificateManager.logType)
        return nil
    }

    let issuerName = plistDict["CertificateIssuerName"] as? String ?? ""
    let expirationDate = plistDict["ExpirationDate"] as? Date
    let keyUsage = plistDict["KeyUsage"] as? Int
    let dnsNames = plistDict["DNSNames"] as? [String]
    let algorithm = plistDict["Algorithm"] as? String
    let keySize = plistDict["KeySize"] as? Int

    if let expiryDate = expirationDate, expiryDate < Date() {
        Logger.log("WARNING: Certificate has expired on \(expiryDate)", logType: CertificateManager.logType)
    }

    return CertificateInfo(
        subjectName: subjectName,
        serialNumber: serialNumber,
        issuerName: issuerName,
        thumbprint: thumbprint,
        expirationDate: expirationDate,
        keyUsage: keyUsage,
        dnsNames: dnsNames,
        algorithm: algorithm,
        keySize: keySize
    )
    }
    
    /// Instance method to retrieve certificate thumbprint by label
    /// - Parameter certificateLabel: The label used to identify the certificate in keychain
    /// - Returns: Hexadecimal SHA-1 thumbprint string, or nil if certificate not found
    func getCertificateThumbprint(certificateLabel: String) -> String? {
        // Set up the query to find our certificate
        let query: [String: Any] = [
            kSecClass as String: kSecClassCertificate,
            kSecAttrLabel as String: certificateLabel,  // Use the label you specified during import
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnRef as String: true,
            kSecReturnData as String: true
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        if status != errSecSuccess {
            Logger.log("Failed to find certificate: \(status)", logType: CertificateManager.logType)
            return nil
        }
        
        guard let certData = item as? Data else {
            Logger.log("Failed to get certificate data", logType: CertificateManager.logType)
            return nil
        }
        
        // Calculate SHA-1 hash (thumbprint)
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
        certData.withUnsafeBytes { buffer in
            _ = CC_SHA1(buffer.baseAddress, CC_LONG(buffer.count), &digest)
        }
        
        // Convert to hex string
        let hexString = digest.map { String(format: "%02X", $0) }.joined()
        return hexString
    }
    
}
