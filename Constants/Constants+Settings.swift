//
//  Constants+Settings.swift
//  Intuneomator
//
//  Created by Gil Burns on 3/14/25.
//

import Foundation

// MARK: - Application Settings Configuration

/// Main configuration structure for Intuneomator application settings
/// Stores authentication, notification, and operational preferences
struct Settings: Codable {
    // MARK: - Microsoft Entra Authentication
    
    /// Microsoft Entra tenant ID (directory ID)
    var tenantid: String = ""
    
    /// Enterprise Application ID (client ID) for Graph API access
    var appid: String = ""
    
    /// SHA-1 thumbprint of authentication certificate (for certificate-based auth)
    var certThumbprint: String = ""
    
    /// Client secret for authentication (alternative to certificate)
    var secret: String = ""
    
    /// Path to private key file (.p12) for certificate authentication
    var privateKeyFile: String = ""
    
    /// Authentication method: "certificate" or "secret"
    var connectMethod: String = ""
    
    // MARK: - Application Management
    
    /// Number of previous app versions to retain in Intune (default: "2")
    var appsToKeep: String = ""
    
    /// Update mode for Intuneomator itself (0 = automatic updates, 1 = notify only)
    var intuneomatorUpdateMode: Int = 0
    
    // MARK: - Microsoft Teams Notifications
    
    /// Master toggle for all Teams notifications
    var sendTeamsNotifications: Bool = false
    
    /// Send notifications for cache cleanup operations
    var sendTeamsNotificationsForCleanup: Bool = false
    
    /// Send notifications for CVE (security vulnerability) discoveries
    var sendTeamsNotificationsForCVEs: Bool = false
    
    /// Send notifications for group assignment operations
    var sendTeamsNotificationsForGroups: Bool = false
    
    /// Send notifications for Installomator label updates
    var sendTeamsNotificationsForLabelUpdates: Bool = false
    
    /// Send notifications for application updates
    var sendTeamsNotificationsForUpdates: Bool = false
    
    /// Teams notification style format (0 = individual notification per update, 1 = single notification for a run)
    var sendTeamsNotificationsStyle: Int = 0
    
    /// Microsoft Teams webhook URL for sending notifications
    var teamsWebhookURL: String = ""
    
    // MARK: - Logging Configuration
    
    /// Maximum age for log files before cleanup (e.g., "30d")
    var logAgeMax: String = ""
    
    /// Maximum size for log files before rotation (e.g., "100MB")
    var logSizeMax: String = ""

    /// Default initializer with empty values
    init() {}

    /// Custom decoder providing default values for missing or null properties
    /// Ensures backward compatibility when adding new settings
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
