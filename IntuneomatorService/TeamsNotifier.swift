//
//  TeamsNotifier.swift
//  Teams Notifier
//
//  Created by Gil Burns on 2/19/25.
//

import Foundation

/// Sends adaptive card notifications to Microsoft Teams via webhook
/// Creates formatted Teams messages for automation results, errors, and status updates
class TeamsNotifier {
    /// The Microsoft Teams webhook URL for sending notifications
    let webhookURL: String
    
    /// Log type identifier for logging operations
    static let logType = "TeamsNotifier"

    /// Initializes a Teams notifier with the specified webhook URL
    /// - Parameter webhookURL: The Microsoft Teams webhook URL for sending notifications
    init(webhookURL: String) {
        self.webhookURL = webhookURL
    }
        
    /// Sends an adaptive card notification to Microsoft Teams
    /// Creates a properly formatted Teams message with the provided body content
    /// - Parameter bodyContent: Array of adaptive card body elements to include in the notification
    func sendTeamsNotification(bodyContent: [[String: Any]]) {
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
            let jsonData = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted])
            var request = URLRequest(url: URL(string: webhookURL)!)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = jsonData

//            Logger.log("🔹 Sending request to Teams Webhook...", logType: TeamsNotifier.logType)
//
            let semaphore = DispatchSemaphore(value: 0)

            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    Logger.log("❌ Error sending notification: \(error.localizedDescription)", logType: TeamsNotifier.logType)
                } else if let httpResponse = response as? HTTPURLResponse {
                    if (200...299).contains(httpResponse.statusCode) {
//                        Logger.log("✅ Notification sent successfully!", logType: TeamsNotifier.logType)
                    } else {
                        Logger.log("❌ Failed to send notification. HTTP Status: \(httpResponse.statusCode)", logType: TeamsNotifier.logType)
                        if let data = data, let responseBody = String(data: data, encoding: .utf8) {
                            Logger.log("🔹 Response Body: \(responseBody)", logType: TeamsNotifier.logType)
                        }
                    }
                }
                semaphore.signal()
            }
            
            task.resume()
            semaphore.wait()
        } catch {
            Logger.log("❌ Error serializing JSON: \(error)", logType: TeamsNotifier.logType)
        }
    }
    
}
