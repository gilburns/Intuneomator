//
//  Constants+DetectedApp.swift
//  Intuneomator
//
//  Created by Gil Burns on 3/14/25.
//

import Foundation

// MARK: - Detected Application Data Structures

/// Model representing an application detected in Microsoft Intune
/// Used for discovering apps installed across managed devices and mapping them to Installomator labels
struct DetectedApp: Codable {
    /// Display name of the detected application
    let displayName: String?
    
    /// Unique identifier for the detected app in Intune
    let id: String?
    
    /// Platform where app is installed (e.g., "macOS", "Windows")
    let platform: String?
    
    /// Version string of the detected application
    let version: String?
    
    /// Publisher/vendor of the application
    let publisher: String?
    
    /// Number of devices where this app is installed
    let deviceCount: Int?
    
    /// Manually assigned Installomator label for automation
    /// Not part of Microsoft Graph API response - assigned during processing
    var installomatorLabel: String
    
    /// Coding keys for JSON serialization (excludes installomatorLabel)
    enum CodingKeys: String, CodingKey {
        case displayName, id, platform, version, publisher, deviceCount
    }
    
    /// Custom decoder for Microsoft Graph API JSON response
    /// Initializes installomatorLabel with default value since it's not in API response
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
        self.id = try container.decodeIfPresent(String.self, forKey: .id)
        self.platform = try container.decodeIfPresent(String.self, forKey: .platform)
        self.version = try container.decodeIfPresent(String.self, forKey: .version)
        self.publisher = try container.decodeIfPresent(String.self, forKey: .publisher)
        self.deviceCount = try container.decodeIfPresent(Int.self, forKey: .deviceCount)
        self.installomatorLabel = "No match detected"
    }
    
    /// Manual initializer for programmatic creation
    /// Used when creating DetectedApp instances with all properties including label
    init(displayName: String?, id: String?, platform: String?, version: String?, publisher: String?, deviceCount: Int?, installomatorLabel: String) {
        self.displayName = displayName
        self.id = id
        self.platform = platform
        self.version = version
        self.publisher = publisher
        self.deviceCount = deviceCount
        self.installomatorLabel = installomatorLabel
    }
    
    /// Creates a copy of the DetectedApp with a new Installomator label
    /// Used for generating multiple app entries with different label mappings
    /// - Parameter label: New Installomator label to assign
    /// - Returns: New DetectedApp instance with updated label
    func withLabel(_ label: String) -> DetectedApp {
        return DetectedApp(
            displayName: self.displayName,
            id: self.id,
            platform: self.platform,
            version: self.version,
            publisher: self.publisher,
            deviceCount: self.deviceCount,
            installomatorLabel: label
        )
    }
}

/// Device information structure for Intune managed devices
/// Used when querying device details associated with detected applications
struct DeviceInfo: Codable {
    /// Human-readable device name
    let deviceName: String
    
    /// Unique device identifier in Intune
    let id: String
    
    /// Primary user email address associated with the device
    let emailAddress: String
}

/// Microsoft Graph API response wrapper for detected applications
/// Handles paginated responses from the Graph API endpoints
struct GraphResponseDetectedApp: Decodable {
    /// Array of detected applications from current page
    let value: [DetectedApp]
    
    /// URL for next page of results (if pagination is needed)
    let nextLink: String?
    
    /// Maps OData response format to Swift property names
    enum CodingKeys: String, CodingKey {
        case value
        case nextLink = "@odata.nextLink"
    }
}


