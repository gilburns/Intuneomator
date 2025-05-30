//
//  Constants+CertificateInfo.swift
//  Intuneomator
//
//  Created by Gil Burns on 3/14/25.
//

import Foundation

struct CertificateInfo {
    let subjectName: String
    let serialNumber: String
    let issuerName: String
    let thumbprint: String
    let expirationDate: Date?
    let keyUsage: Int?
    let dnsNames: [String]?
    let algorithm: String?
    let keySize: Int?
}
