//
//  TeamsNotifier.swift
//  Teams Notifier
//
//  Created by Gil Burns on 2/19/25.
//

import Foundation

// Swift Class for Sending Teams Workflow Notifications
class TeamsNotifier {
    let webhookURL: String
    
    init(webhookURL: String) {
        self.webhookURL = webhookURL
    }
    
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

            Logger.log("🔹 Sending request to Teams Webhook...", logType: "TeamsNotifier")
            Logger.log("🔹 Payload JSON: \(String(data: jsonData, encoding: .utf8) ?? "Invalid JSON")", logType: "TeamsNotifier")

            let semaphore = DispatchSemaphore(value: 0)

            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    Logger.log("❌ Error sending notification: \(error.localizedDescription)", logType: "TeamsNotifier")
                } else if let httpResponse = response as? HTTPURLResponse {
                    if (200...299).contains(httpResponse.statusCode) {
                        Logger.log("✅ Notification sent successfully!", logType: "TeamsNotifier")
                    } else {
                        Logger.log("❌ Failed to send notification. HTTP Status: \(httpResponse.statusCode)", logType: "TeamsNotifier")
                        if let data = data, let responseBody = String(data: data, encoding: .utf8) {
                            Logger.log("🔹 Response Body: \(responseBody)", logType: "TeamsNotifier")
                        }
                    }
                }
                semaphore.signal()
            }
            
            task.resume()
            semaphore.wait()
        } catch {
            Logger.log("❌ Error serializing JSON: \(error)", logType: "TeamsNotifier")
        }
    }
    
}
