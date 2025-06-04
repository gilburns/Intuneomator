//
//  Constants+ProcessedAppResults.swift
//  Intuneomator
//
//  Created by Gil Burns on 3/14/25.
//

import Foundation

struct ProcessedAppResults {
    let appAssignments: [[String : Any]]
    var appBundleIdActual: String
    let appBundleIdExpected: String
    let appCategories: [Category]
    let appDeploymentArch: Int
    let appDeploymentType: Int
    let appDescription: String
    let appDeveloper: String
    var appDisplayName: String
    var appDownloadURL: String
    var appDownloadURLx86: String
    let appIconURL: String
    let appIgnoreVersion: Bool
    let appInfoURL: String
    let appIsDualArchCapable: Bool
    let appIsFeatured: Bool
    let appIsManaged: Bool
    let appLabelName: String
    let appLabelType: String
    var appLocalURL: String
    var appLocalURLx86: String
    let appMinimumOS: String
    let appNotes: String
    let appOwner: String
    let appPrivacyPolicyURL: String
    let appPublisherName: String
    let appScriptPreInstall: String
    let appScriptPostInstall: String
    let appTeamID: String
    let appTrackingID: String
    var appVersionActual: String
    let appVersionExpected: String
    var appUploadFilename: String
}

extension ProcessedAppResults {
  static let empty = ProcessedAppResults(
    appAssignments: [],
    appBundleIdActual: "",
    appBundleIdExpected: "",
    appCategories: [],
    appDeploymentArch: 3,
    appDeploymentType: 3,
    appDescription: "",
    appDeveloper: "",
    appDisplayName: "",
    appDownloadURL: "",
    appDownloadURLx86: "",
    appIconURL: "",
    appIgnoreVersion: false,
    appInfoURL: "",
    appIsDualArchCapable: false,
    appIsFeatured: false,
    appIsManaged: false,
    appLabelName: "",
    appLabelType: "",
    appLocalURL: "",
    appLocalURLx86: "",
    appMinimumOS: "",
    appNotes: "",
    appOwner: "",
    appPrivacyPolicyURL: "",
    appPublisherName: "",
    appScriptPreInstall: "",
    appScriptPostInstall: "",
    appTeamID: "",
    appTrackingID: "",
    appVersionActual: "",
    appVersionExpected: "",
    appUploadFilename: ""
  )
}

extension ProcessedAppResults {
    
    /// Emoji + label for architecture
    var architectureEmoji: String {
        switch appDeploymentArch {
        case 0: return "🌍 Arm64"
        case 1: return "🌍 x86_64"
        case 2: return "🌍 Universal"
        default: return "❓ Unknown"
        }
    }

    /// Emoji + label for deployment type (DMG, PKG, LOB)
    var deploymentTypeEmoji: String {
        switch appDeploymentType {
        case 0: return "💾 DMG"
        case 1: return "📦 PKG"
        case 2: return "🏢 LOB"
        default: return "❓ Unknown"
        }
    }
}
