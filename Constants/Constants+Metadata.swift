//
//  Constants+Metadata.swift
//  Intuneomator
//
//  Created by Gil Burns on 3/14/25.
//

import Foundation

// MARK: - Application Metadata Configuration

/// Complete metadata structure for Intune application management
/// Stores all configuration and deployment settings for managed applications
struct Metadata: Codable, Equatable {
    // MARK: - Application Classification
    
    /// Application categories for organization in Intune portal
    var categories: [Category]
    
    /// Detailed description of the application's purpose and functionality
    var description: String
    
    /// Publisher/vendor name of the application
    var publisher: String
    
    /// Application bundle identifier (e.g., com.company.appname)
    var CFBundleIdentifier: String
    
    // MARK: - Deployment Configuration
    
    /// Architecture deployment flag (0 = ARM or Universal, 1 = Intel only, 2 = Universal PKG)
    var deployAsArchTag: Int = 0
    
    /// Deployment type flag (0 = DMG, 1 = PKG, 2 = LOB)
    var deploymentTypeTag: Int = 0
    
    /// Whether this app should be featured in Company Portal
    var isFeatured: Bool
    
    /// Whether the app is managed (has configuration policies applies to LOB type only)
    var isManaged: Bool
    
    // MARK: - System Requirements
    
    /// Minimum macOS version required (e.g., "14.0")
    var minimumOS: String
    
    /// Human-readable minimum OS version for display
    var minimumOSDisplay: String
    
    /// Skip automatic version detection during updates
    var ignoreVersionDetection: Bool
    
    // MARK: - Optional Information
    
    /// Developer/company name (may differ from publisher)
    var developer: String?
    
    /// URL to application information or homepage
    var informationUrl: String?
    
    /// Administrative notes for internal use. The Intuneomator tracking ID is also stores at the end of the notes field
    var notes: String?
    
    /// Application owner or contact person
    var owner: String?
    
    /// URL to privacy policy or data handling information
    var privacyInformationUrl: String?
}

/// Partial metadata structure for selective updates
/// Used when only updating specific metadata fields without affecting core configuration
struct MetadataPartial: Codable, Equatable {
    /// Developer/company name
    var developer: String?
    
    /// URL to application information
    var informationUrl: String?
    
    /// Administrative notes
    var notes: String?
    
    /// Application owner
    var owner: String?
    
    /// Privacy policy URL
    var privacyInformationUrl: String?
    
    /// Initializer for creating partial metadata updates
    /// - Parameters:
    ///   - developer: Developer name
    ///   - informationUrl: Application information URL
    ///   - notes: Administrative notes
    ///   - owner: Application owner
    ///   - privacyInformationUrl: Privacy policy URL
    init(developer: String?,
         informationUrl: String?,
         notes: String?,
         owner: String?,
         privacyInformationUrl: String?) {
        self.developer = developer
        self.informationUrl = informationUrl
        self.notes = notes
        self.owner = owner
        self.privacyInformationUrl = privacyInformationUrl
    }
}
