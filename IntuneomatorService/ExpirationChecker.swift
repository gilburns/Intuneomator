//
//  ExpirationChecker.swift
//  Intuneomator
//
//  Created by Gil Burns on 5/23/25.
//

import Foundation

class ExpirationChecker {
    
    private let calendar = Calendar.current
    
    private let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        df.timeZone = .current
        return df
    }()
    
    private let thresholdDays = 30

    private let logType = "ExpirationChecker"

    
    // MARK: - Check Certificate Expiration & Notify
    func checkCertificateExpirationAndNotify() {

        // Read saved certificate details
        guard let plistDict: [String: Any] = ConfigManager.readPlistValue(key: "CertificateDetails") else {
            Logger.log("Certificate info plist not found or empty.", logType: logType)
            return
        }

        guard let expirationDate = plistDict["ExpirationDate"] as? Date,
        let importDate = plistDict["ImportDate"] as? Date,
        let thumbprint = plistDict["Thumbprint"] as? String else {
            Logger.log("Certificate details not found or incomplete for expiration check.", logType: logType)
            return
        }

        // Calculate days until expiration
        let today = Date()
        let components = calendar.dateComponents([.day], from: today, to: expirationDate)
        let daysUntilExpiry = components.day ?? 0
        Logger.log("Days until certificate expiration: \(daysUntilExpiry)", logType: logType)

        // only fire if within threshold
        guard daysUntilExpiry <= thresholdDays else {
            Logger.log("Certificate expires in more than \(thresholdDays) days. No notification sent.", logType: logType)
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
            Logger.log("Teams notifications disabled; skipping certificate-expiry alert.", logType: logType)
            return
        }

        let webhookURL = ConfigManager.readPlistValue(key: "TeamsWebhookURL") ?? ""
        guard !webhookURL.isEmpty else {
            Logger.log("No Teams Webhook URL set. Not sending certificate expiration notification.", logType: logType)
            return
        }

        let teamsNotifier = TeamsNotifier(webhookURL: webhookURL)
        teamsNotifier.sendCertExpiringNotification(
            expirationDate: expiryString,
            importDate: importString,
            thumbprint: thumbprint,
            dnsNames: dnsNamesString
        )
        Logger.log("Certificate expiration notification sent.", logType: logType)
    }

    
    func checkSecretExpiration() {

        // Read saved secret details
        guard let expirationDate = ConfigManager.readPlistValue(key: "SecretExpirationDate") as Date? else {
            Logger.log("No SecretExpirationDate configured.", logType: logType)
            return
        }
        guard let importDate = ConfigManager.readPlistValue(key: "SecretImportDate") as Date? else {
            Logger.log("No SecretImportDate configured.", logType: logType)
            return
        }

        let now = Date()
        let daysRemaining = calendar.dateComponents([.day], from: now, to: expirationDate).day ?? Int.max
        Logger.log("Days until secret expiration: \(daysRemaining)", logType: logType)

        // only fire if within threshold
        guard daysRemaining <= thresholdDays else {
            Logger.log("Secret expires in more than \(thresholdDays) days. No notification sent.", logType: logType)
            return
        }

        // Format the Teams Notifications
        let expiryString = dateFormatter.string(from: expirationDate)
        let importString = dateFormatter.string(from: importDate)

        // Check Teams notification setting
        let sendTeamNotification = ConfigManager.readPlistValue(key: "TeamsNotificationsEnabled") ?? false
        guard sendTeamNotification else {
            Logger.log("Teams notifications disabled; skipping secret-expiry alert.", logType: logType)
            return
        }

        let webhookURL = ConfigManager.readPlistValue(key: "TeamsWebhookURL") ?? ""
        guard !webhookURL.isEmpty else {
            Logger.log("No Teams Webhook URL set. Not sending secret expiration notification.", logType: logType)
            return
        }

        let teamsNotifier = TeamsNotifier(webhookURL: webhookURL)
        teamsNotifier.sendSecretExpiringNotification(
            expirationDate: expiryString,
            importDate: importString
        )
        Logger.log("Secret expiration notification sent.", logType: logType)
    }
    
}
