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

