//
//  Constants+Metadata.swift
//  Intuneomator
//
//  Created by Gil Burns on 3/14/25.
//

import Foundation

// MARK: - Metadata.json file
struct Metadata: Codable, Equatable {
    var categories: [Category]
    var description: String
    var deployAsArchTag: Int = 0
    var deploymentTypeTag: Int = 0
    var developer: String?
    var informationUrl: String?
    var ignoreVersionDetection: Bool
    var isFeatured: Bool
    var isManaged: Bool
    var minimumOS: String
    var minimumOSDisplay: String
    var notes: String?
    var owner: String?
    var privacyInformationUrl: String?
    var publisher: String
    var CFBundleIdentifier: String
}

struct MetadataPartial: Codable, Equatable {
    var developer: String?
    var informationUrl: String?
    var notes: String?
    var owner: String?
    var privacyInformationUrl: String?
        
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
