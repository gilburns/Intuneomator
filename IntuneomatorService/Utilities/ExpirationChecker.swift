//
//  ExpirationChecker.swift
//  Intuneomator
//
//  Created by Gil Burns on 5/23/25.
//

import Foundation

/// Monitors and notifies about expiring certificates and client secrets
/// Checks expiration dates against a configurable threshold and sends Teams notifications
class ExpirationChecker {
    
    /// Calendar instance for date calculations
    private let calendar = Calendar.current
    
    /// Date formatter for displaying expiration and import dates in notifications
    private let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        df.timeZone = .current
        return df
    }()
    
    /// Number of days before expiration to trigger notifications
    private let thresholdDays = 30


    
    // MARK: - Check Certificate Expiration & Notify
    
    /// Checks if the configured certificate is approaching expiration and sends Teams notification if needed
    /// Only sends notification if certificate expires within the threshold period and Teams notifications are enabled
    func checkCertificateExpirationAndNotify() {

        // Read saved certificate details
        guard let plistDict: [String: Any] = ConfigManager.readPlistValue(key: "CertificateDetails") else {
            Logger.info("Certificate info plist not found or empty.", category: .core)
            return
        }

        guard let expirationDate = plistDict["ExpirationDate"] as? Date,
        let importDate = plistDict["ImportDate"] as? Date,
        let thumbprint = plistDict["Thumbprint"] as? String else {
            Logger.info("Certificate details not found or incomplete for expiration check.", category: .core)
            return
        }

        // Calculate days until expiration
        let today = Date()
        let components = calendar.dateComponents([.day], from: today, to: expirationDate)
        let daysUntilExpiry = components.day ?? 0
        Logger.info("Days until certificate expiration: \(daysUntilExpiry)", category: .core)

        // only fire if within threshold
        guard daysUntilExpiry <= thresholdDays else {
            Logger.info("Certificate expires in more than \(thresholdDays) days. No notification sent.", category: .core)
            return
        }

        // Format dates and DNS names
        let expiryString = dateFormatter.string(from: expirationDate)
        let importString = dateFormatter.string(from: importDate)
        let dnsNamesArray = plistDict["DNSNames"] as? [String] ?? []
        let dnsNamesString = dnsNamesArray.joined(separator: ", ")

        // Check Teams notification setting
        let sendTeamNotification = ConfigManager.readPlistValue(key: "TeamsNotificationsEnabled") ?? false
        guard sendTeamNotification else {
            Logger.info("Teams notifications disabled; skipping certificate-expiry alert.", category: .core)
            return
        }

        let webhookURL = ConfigManager.readPlistValue(key: "TeamsWebhookURL") ?? ""
        guard !webhookURL.isEmpty else {
            Logger.info("No Teams Webhook URL set. Not sending certificate expiration notification.", category: .core)
            return
        }

        let teamsNotifier = TeamsNotifier(webhookURL: webhookURL)
        teamsNotifier.sendCertExpiringNotification(
            expirationDate: expiryString,
            importDate: importString,
            thumbprint: thumbprint,
            dnsNames: dnsNamesString
        )
        Logger.info("Certificate expiration notification sent.", category: .core)
    }


    /// Checks if the configured client secret is approaching expiration and sends Teams notification if needed
    /// Only sends notification if secret expires within the threshold period and Teams notifications are enabled
    func checkSecretExpirationAndNotify() {

        // Read saved secret details
        guard let expirationDate = ConfigManager.readPlistValue(key: "SecretExpirationDate") as Date? else {
            Logger.info("No SecretExpirationDate configured.", category: .core)
            return
        }
        guard let importDate = ConfigManager.readPlistValue(key: "SecretImportDate") as Date? else {
            Logger.info("No SecretImportDate configured.", category: .core)
            return
        }

        let now = Date()
        let daysRemaining = calendar.dateComponents([.day], from: now, to: expirationDate).day ?? Int.max
        Logger.info("Days until secret expiration: \(daysRemaining)", category: .core)

        // only fire if within threshold
        guard daysRemaining <= thresholdDays else {
            Logger.info("Secret expires in more than \(thresholdDays) days. No notification sent.", category: .core)
            return
        }

        // Format the Teams Notifications
        let expiryString = dateFormatter.string(from: expirationDate)
        let importString = dateFormatter.string(from: importDate)

        // Check Teams notification setting
        let sendTeamNotification = ConfigManager.readPlistValue(key: "TeamsNotificationsEnabled") ?? false
        guard sendTeamNotification else {
            Logger.info("Teams notifications disabled; skipping secret-expiry alert.", category: .core)
            return
        }

        let webhookURL = ConfigManager.readPlistValue(key: "TeamsWebhookURL") ?? ""
        guard !webhookURL.isEmpty else {
            Logger.info("No Teams Webhook URL set. Not sending secret expiration notification.", category: .core)
            return
        }

        let teamsNotifier = TeamsNotifier(webhookURL: webhookURL)
        teamsNotifier.sendSecretExpiringNotification(
            expirationDate: expiryString,
            importDate: importString
        )
        Logger.info("Secret expiration notification sent.", category: .core)
    }
    
}
