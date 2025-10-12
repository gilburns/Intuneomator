//
//  TeamsNotifier+NotifyTest.swift
//  Intuneomator
//
//  Created by Gil Burns on 10/11/25.
//

import Foundation

// MARK: - Test Notification Extension

/// Extension for sending a test notification to Microsoft Teams
/// Provides a simple way to verify Teams webhook configuration is working correctly
extension TeamsNotifier {

    /// Sends a test notification to Microsoft Teams to verify webhook connectivity
    /// Creates a simple adaptive card with test message and timestamp
    /// - Returns: True if the test notification was sent successfully, false otherwise
    func sendTestNotification() async -> Bool {
        // Configure notification branding and metadata
        let title = "🧪 Test Notification"
        let intuneomatorIconUrl = "https://icons.intuneomator.org/intuneomator.png"
        let time = "🕰️ \(TeamsNotifier.dateFormatter.string(from: Date()))"

        // Build adaptive card body content for test message
        let bodyContent: [[String: Any]] = [
            // Header row with icon and test indicator
            [
                "type": "ColumnSet",
                "columns": [
                    [
                        "type": "Column",
                        "items": [
                            ["type": "Image", "url": intuneomatorIconUrl, "size": "Medium"]
                        ],
                        "width": "auto"
                    ],
                    [
                        "type": "Column",
                        "items": [
                            ["type": "TextBlock", "text": " ", "weight": "Bolder", "size": "Medium"]
                        ],
                        "width": "stretch"
                    ],
                    [
                        "type": "Column",
                        "items": [
                            [
                                "type": "FactSet",
                                "facts": [
                                    [
                                        "title": " ",
                                        "value": "🟢 **TEST**",
                                        "color": "Good"
                                    ]
                                ]
                            ]
                        ],
                        "width": "auto",
                        "style": "good"
                    ]
                ]
            ],
            // Main title
            [
                "type": "TextBlock",
                "text": "**\(title)**",
                "weight": "Bolder",
                "spacing": "None",
                "size": "Large"
            ],
            // Test description
            [
                "type": "TextBlock",
                "text": "This is a test notification from Intuneomator",
                "weight": "Lighter",
                "spacing": "Small",
                "size": "Small"
            ],
            // Timestamp
            [
                "type": "TextBlock",
                "text": "\(time)",
                "weight": "Lighter",
                "spacing": "Small",
                "size": "Small"
            ],
            // Section separator
            [
                "type": "TextBlock",
                "text": "---",
                "weight": "Lighter",
                "spacing": "Medium",
                "separator": true
            ],
            // Test message body
            [
                "type": "TextBlock",
                "text": "✅ Your Teams webhook is configured correctly and notifications are working!",
                "wrap": true,
                "spacing": "Medium"
            ],
            // Additional info
            [
                "type": "TextBlock",
                "text": "If you received this message, Intuneomator can successfully send notifications to your Microsoft Teams channel.",
                "wrap": true,
                "spacing": "Small",
                "size": "Small",
                "isSubtle": true
            ]
        ]

        // Build the payload
        let payload: [String: Any] = [
            "type": "message",
            "attachments": [
                [
                    "contentType": "application/vnd.microsoft.card.adaptive",
                    "content": [
                        "type": "AdaptiveCard",
                        "version": "1.4",
                        "msteams": ["width": "full"],
                        "body": bodyContent
                    ]
                ]
            ]
        ]

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: payload, options: [])
            guard let url = URL(string: webhookURL) else {
                Logger.error("Invalid webhook URL: \(webhookURL)", category: .core)
                return false
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = jsonData

            let (_, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                if (200...299).contains(httpResponse.statusCode) {
                    Logger.log("Test notification sent successfully to Teams!", category: .core)
                    return true
                } else {
                    Logger.error("Failed to send test notification. HTTP Status: \(httpResponse.statusCode)", category: .core)
                    return false
                }
            }

            return false
        } catch {
            Logger.error("Error sending test notification: \(error.localizedDescription)", category: .core)
            return false
        }
    }

}
