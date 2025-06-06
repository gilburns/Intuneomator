//
//  Constants+LabelInfo.swift
//  Intuneomator
//
//  Created by Gil Burns on 3/14/25.
//

import Foundation

// MARK: - Installomator Label Information

/// Information about an Installomator label and its associated script
/// Used for managing the 700+ supported applications in the Installomator ecosystem
struct LabelInfo: Codable {
    /// Name of the Installomator label (e.g., "googlechrome", "firefox")
    let label: String
    
    /// Complete shell script contents for this label
    let labelContents: String
    
    /// URL or file path where the label script is located
    let labelFileURL: String
    
    /// Source location where label originated
    let labelSource: String
}

/// Plist metadata information extracted from Installomator labels
/// Contains application metadata parsed from the label's plist configuration
struct LabelPlistInfo: Decodable {
    /// Application bundle identifier (e.g., "com.google.Chrome")
    let appID: String
    
    /// Human-readable description of the application
    let description: String
    
    /// URL or reference to application documentation
    let documentation: String
    
    /// Publisher/vendor name of the application
    let publisher: String
    
    /// Privacy policy URL or privacy-related information
    let privacy: String
    
    /// Maps plist keys to Swift property names
    /// Installomator uses capitalized keys in plist format
    enum CodingKeys: String, CodingKey {
        case appID = "AppID"
        case description = "Description"
        case documentation = "Documentation"
        case publisher = "Publisher"
        case privacy = "Privacy"
    }
}


