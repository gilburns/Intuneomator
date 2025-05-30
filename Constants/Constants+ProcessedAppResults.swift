//
//  Constants+ProcessedAppResults.swift
//  Intuneomator
//
//  Created by Gil Burns on 3/14/25.
//

import Foundation

struct ProcessedAppResults {
    var appAssignments: [[String : Any]]
    var appBundleIdActual: String
    var appBundleIdExpected: String
    var appCategories: [Category]
    var appDeploymentArch: Int
    var appDeploymentType: Int
    var appDescription: String
    var appDeveloper: String
    var appDisplayName: String
    var appDownloadURL: String
    var appDownloadURLx86: String
    var appIconURL: String
    var appIgnoreVersion: Bool
    var appInfoURL: String
    var appIsDualArchCapable: Bool
    var appIsFeatured: Bool
    var appIsManaged: Bool
    var appLabelName: String
    var appLabelType: String
    var appLocalURL: String
    var appLocalURLx86: String
    var appMinimumOS: String
    var appNotes: String
    var appOwner: String
    var appPrivacyPolicyURL: String
    var appPublisherName: String
    var appScriptPreInstall: String
    var appScriptPostInstall: String
    var appTeamID: String
    var appTrackingID: String
    var appVersionActual: String
    var appVersionExpected: String
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
