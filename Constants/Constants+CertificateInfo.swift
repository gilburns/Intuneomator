//
//  Constants+CertificateInfo.swift
//  Intuneomator
//
//  Created by Gil Burns on 3/14/25.
//

import Foundation

/// Certificate information structure for Microsoft Entra authentication
/// Used for certificate-based authentication with Microsoft Graph API
struct CertificateInfo {
    /// Subject name from the certificate (CN=, OU=, etc.)
    let subjectName: String
    
    /// Unique serial number assigned by the certificate authority
    let serialNumber: String
    
    /// Certificate authority that issued this certificate
    let issuerName: String
    
    /// SHA-1 thumbprint/fingerprint of the certificate
    let thumbprint: String
    
    /// Certificate expiration date (nil if not available)
    let expirationDate: Date?
    
    /// Key usage flags indicating certificate purpose
    let keyUsage: Int?
    
    /// DNS subject alternative names from the certificate
    let dnsNames: [String]?
    
    /// Public key algorithm (RSA, ECDSA, etc.)
    let algorithm: String?
    
    /// Public key size in bits
    let keySize: Int?
}
