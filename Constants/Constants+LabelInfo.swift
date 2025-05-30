//
//  Constants+LabelInfo.swift
//  Intuneomator
//
//  Created by Gil Burns on 3/14/25.
//

import Foundation


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


