//
//  Constants+Settings.swift
//  Intuneomator
//
//  Created by Gil Burns on 3/14/25.
//

import Foundation

// MARK: - Struct for Settings
struct Settings: Codable {
    var tenantid: String = ""
    var appid: String = ""
    var certThumbprint: String = ""
    var secret: String = ""
    var appsToKeep: String = ""
    var connectMethod: String = ""
    var privateKeyFile: String = ""
    var sendTeamsNotifications: Bool = false
    var sendTeamsNotificationsForCleanup: Bool = false
    var sendTeamsNotificationsForCVEs: Bool = false
    var sendTeamsNotificationsForGroups: Bool = false
    var sendTeamsNotificationsForLabelUpdates: Bool = false
    var sendTeamsNotificationsForUpdates: Bool = false
    var sendTeamsNotificationsStyle: Int = 0
    var teamsWebhookURL: String = ""
    var logAgeMax: String = ""
    var logSizeMax: String = ""

    init() {}

    // Provide defaults during decoding
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        tenantid = try container.decodeIfPresent(String.self, forKey: .tenantid) ?? ""
        appid = try container.decodeIfPresent(String.self, forKey: .appid) ?? ""
        certThumbprint = try container.decodeIfPresent(String.self, forKey: .certThumbprint) ?? ""
        secret = try container.decodeIfPresent(String.self, forKey: .secret) ?? ""
        appsToKeep = try container.decodeIfPresent(String.self, forKey: .appsToKeep) ?? "2"
        connectMethod = try container.decodeIfPresent(String.self, forKey: .connectMethod) ?? "certificate"
        privateKeyFile = try container.decodeIfPresent(String.self, forKey: .privateKeyFile) ?? ""
        sendTeamsNotifications = try container.decodeIfPresent(Bool.self, forKey: .sendTeamsNotifications) ?? false
        teamsWebhookURL = try container.decodeIfPresent(String.self, forKey: .teamsWebhookURL) ?? ""
        logAgeMax = try container.decodeIfPresent(String.self, forKey: .logAgeMax) ?? ""
        logSizeMax = try container.decodeIfPresent(String.self, forKey: .logSizeMax) ?? ""

    }
}
