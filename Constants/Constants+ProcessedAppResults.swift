//
//  Constants+ProcessedAppResults.swift
//  Intuneomator
//
//  Created by Gil Burns on 3/14/25.
//

import Foundation

// MARK: - Processed Application Results

/// Comprehensive results structure for processed applications
/// Contains all data collected during application processing workflow
struct ProcessedAppResults {
    /// Group assignments for the application in Intune
    let appAssignments: [[String : Any]]
    
    /// Actual bundle identifier discovered during processing
    var appBundleIdActual: String
    
    /// Expected bundle identifier from metadata
    let appBundleIdExpected: String
    
    /// Application categories for Intune portal organization
    let appCategories: [Category]
    
    /// Architecture deployment configuration (0=ARM64, 1=x86_64, 2=Universal)
    let appDeploymentArch: Int
    
    /// Deployment type (0=DMG, 1=PKG, 2=LOB)
    let appDeploymentType: Int
    
    /// Application description for users
    let appDescription: String
    
    /// Developer/company name
    let appDeveloper: String
    
    /// Display name for the application
    var appDisplayName: String
    
    /// Download URL for ARM64/Universal version
    var appDownloadURL: String
    
    /// Download URL for x86_64 version (if different)
    var appDownloadURLx86: String
    
    /// URL to application icon image
    let appIconURL: String
    
    /// Whether to skip version detection during updates
    let appIgnoreVersion: Bool
    
    /// Application information/homepage URL
    let appInfoURL: String
    
    /// Whether app supports both Intel and ARM architectures
    let appIsDualArchCapable: Bool
    
    /// Whether app should be featured in Company Portal
    let appIsFeatured: Bool
    
    /// Whether app has configuration policies (LOB only)
    let appIsManaged: Bool
    
    /// Installomator label name used for processing
    let appLabelName: String
    
    /// Type of Installomator label (e.g., "dmg", "pkg")
    let appLabelType: String
    
    /// Local file path for ARM64/Universal version
    var appLocalURL: String
    
    /// Local file path for x86_64 version (if different)
    var appLocalURLx86: String
    
    /// Minimum macOS version requirement
    let appMinimumOS: String
    
    /// Administrative notes (includes Intuneomator tracking ID)
    let appNotes: String
    
    /// Application owner or contact person
    let appOwner: String
    
    /// Privacy policy URL
    let appPrivacyPolicyURL: String
    
    /// Publisher/vendor name
    let appPublisherName: String
    
    /// Pre-installation script content
    let appScriptPreInstall: String
    
    /// Post-installation script content
    let appScriptPostInstall: String
    
    /// Apple Developer Team ID for code signature verification
    let appTeamID: String
    
    /// Unique tracking identifier for Intuneomator
    let appTrackingID: String
    
    /// Actual version discovered during processing
    var appVersionActual: String
    
    /// Expected version from metadata or Installomator
    let appVersionExpected: String
    
    /// Filename for upload to Intune
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
