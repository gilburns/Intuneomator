//
//  Constants.swift
//  Intuneomator
//
//  Created by Gil Burns on 3/14/25.
//

import Foundation

enum DeploymentArchTag: Int, Codable {
    case arm64 = 0
    case x86_64 = 1
    case universal = 2
}

enum DeploymentTypeTag: Int, Codable {
    case dmg = 0
    case pkg = 1
    case lob = 2
}

struct ProcessedFileResult {
  let url: URL
  let name: String
  let bundleID: String
  let version: String
}

struct Category: Codable, Equatable {
    var displayName: String
    var id: String
}


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

// Struct to store downloaded file info
struct DownloadedFile {
    let filePath: String
    let fileName: String
    let fileSize: Int64
}

// MARK: - Intune Device Filters
struct AssignmentFilter: Decodable {
    let id: String
    let displayName: String
    let description: String?
}


// MARK: - Intune App Check
struct FilteredIntuneAppInfo: Codable {
    let id: String
    let displayName: String
    let isAssigned: Bool
    let primaryBundleId: String
    let primaryBundleVersion: String
}


// MARK: - Struct for Label Data
struct LabelInfo: Codable {
    let label: String
    let labelContents: String
    let labelFileURL: String
    let labelSource: String
}


struct LabelPlistInfo: Decodable {
    let appID: String
    let description: String
    let documentation: String
    let publisher: String
    let privacy: String
    
    enum CodingKeys: String, CodingKey {
        case appID = "AppID"
        case description = "Description"
        case documentation = "Documentation"
        case publisher = "Publisher"
        case privacy = "Privacy"
    }
}




// Define a struct to store extracted plist data
struct PlistData {
    let appNewVersion: String?
    let downloadURL: String
    let expectedTeamID: String
    let name: String
    let type: String
}

// MARK: - Error Types
enum IntuneServiceError: Int, Error, Codable {
    case invalidURL = 1000
    case networkError = 1001
    case authenticationError = 1002
    case permissionDenied = 1003
    case decodingError = 1004
    case tokenError = 1005
    case serverError = 1006
    
    var localizedDescription: String {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .networkError: return "Network connection error"
        case .authenticationError: return "Authentication failed"
        case .permissionDenied: return "Missing permissions in Enterprise App settings"
        case .decodingError: return "Failed to decode server response"
        case .tokenError: return "Failed to obtain valid token"
        case .serverError: return "Server returned an error"
        }
    }
}



