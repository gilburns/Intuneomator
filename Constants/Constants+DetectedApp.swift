//
//  Constants+DetectedApp.swift
//  Intuneomator
//
//  Created by Gil Burns on 3/14/25.
//

import Foundation

/// Model for a detected app
struct DetectedApp: Codable {
    let displayName: String?
    let id: String?
    let platform: String?
    let version: String?
    let publisher: String?
    let deviceCount: Int?
    var installomatorLabel: String // This is manually assigned, not from JSON
    
    enum CodingKeys: String, CodingKey {
        case displayName, id, platform, version, publisher, deviceCount
    }
    
    // Custom decoder for JSON
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
    
    // ✅ Manual initializer to allow object duplication
    init(displayName: String?, id: String?, platform: String?, version: String?, publisher: String?, deviceCount: Int?, installomatorLabel: String) {
        self.displayName = displayName
        self.id = id
        self.platform = platform
        self.version = version
        self.publisher = publisher
        self.deviceCount = deviceCount
        self.installomatorLabel = installomatorLabel
    }
    
    // ✅ Fix for the error: Explicitly create a copy with a new label
    func withLabel(_ label: String) -> DetectedApp {
        return DetectedApp(
            displayName: self.displayName,
            id: self.id,
            platform: self.platform,
            version: self.version,
            publisher: self.publisher,
            deviceCount: self.deviceCount,
            installomatorLabel: label  // Assign a unique label per row
        )
    }
}

struct DeviceInfo: Codable {
    let deviceName: String
    let id: String
    let emailAddress: String
}


/// Model for Graph API response
struct GraphResponseDetectedApp: Decodable {
    let value: [DetectedApp]
    let nextLink: String?
    
    enum CodingKeys: String, CodingKey {
        case value
        case nextLink = "@odata.nextLink"
    }
}


