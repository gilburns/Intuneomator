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
    
    func sendNotification(
        title: String,
        version: String,
        size: String,
        time: String,
        imageURL: String,
        deploymentType: String?,
        architecture: String?,
        releaseNotesURL: String?,
        requiredGroups: String?,
        availableGroups: String?,
        uninstallGroups: String?,
        isSuccess: Bool,
        errorMessage: String? = nil
    ) {
        var facts: [[String: String]] = [
            ["title": "Version:", "value": version],
            ["title": "Size:", "value": size],
            ["title": "Time:", "value": time]
        ]
        
        if let deploymentType = deploymentType {
            facts.append(["title": "Deployment Type:", "value": deploymentType])
        }
        if let architecture = architecture {
            facts.append(["title": "Architecture:", "value": architecture])
        }
        if let releaseNotesURL = releaseNotesURL {
            facts.append(["title": "Release Notes:", "value": "[Update Details](\(releaseNotesURL))"])
        }

        // ✅ Main Card Content (Image, Title, Separator, Details)
        var bodyContent: [[String: Any]] = [
            [
                "type": "ColumnSet",
                "columns": [
                    [
                        "type": "Column",
                        "items": [
                            ["type": "Image", "url": imageURL, "size": "Medium", "style": "Person"]
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
                                        "value": isSuccess ? "🟢 **SUCCESS**" : "🔴 **FAILED**",
                                        "color": isSuccess ? "Good" : "Attention",
                                    ]
                                ]
                            ]
                        ],
                        "width": "auto",
                        "style": isSuccess ? "good" : "attention",
                    ]
                ]
            ],
            [
                "type": "TextBlock",
                "text": "**\(title)**",
                "weight": "Bolder",
                "spacing": "None",
                "size": "Large"
            ],
            [
                "type": "TextBlock",
                "text": "Intuneomator deployment update",
                "weight": "Lighter",
                "spacing": "Small",
                "size": "Small"
            ],
            [
                "type": "TextBlock",
                "text": "---",
                "weight": "Lighter",
                "spacing": "Medium",
                "separator": true
            ],
            [
                "type": "FactSet",
                "facts": facts
            ]
        ]
        // ✅ Handle Failure Case: Show Error Box Instead of Assignments
        if !isSuccess, let errorMessage = errorMessage, !errorMessage.trimmingCharacters(in: .whitespaces).isEmpty {
            bodyContent.append([
                "type": "TextBlock",
                "text": "**Error Details**",
                "weight": "Bolder",
                "size": "Medium",
                "color": "Attention",
                "spacing": "Medium"
            ])
            
            bodyContent.append([
                "type": "Container",
                "items": [
                    [
                        "type": "TextBlock",
                        "text": errorMessage,
                        "wrap": true,
                        "color": "Attention",
                        "spacing": "Small"
                    ]
                ],
                "style": "attention",
                "bleed": true
            ])
        }
        // ✅ Only Add Assignments If No Failure Occurred
        // ✅ Handle Failure Case: Show Error Box Instead of Assignments
        if isSuccess {
            var assignments: [[String: String]] = []

            if let requiredGroups = requiredGroups, !requiredGroups.trimmingCharacters(in: .whitespaces).isEmpty {
                assignments.append(["title": "Required", "value": requiredGroups])
            }
            if let availableGroups = availableGroups, !availableGroups.trimmingCharacters(in: .whitespaces).isEmpty {
                assignments.append(["title": "Available", "value": availableGroups])
            }
            if let uninstallGroups = uninstallGroups, !uninstallGroups.trimmingCharacters(in: .whitespaces).isEmpty {
                assignments.append(["title": "Uninstall", "value": uninstallGroups])
            }

            // ✅ Ensure Assignments Exist Before Adding the Section
            if !assignments.isEmpty {
                bodyContent.append([
                    "type": "TextBlock",
                    "text": "**Assignments**",
                    "weight": "Bolder",
                    "size": "Medium",
                    "spacing": "Medium"
                ])

                // ✅ Table Header Row
                let tableHeader: [String: Any] = [
                    "type": "ColumnSet",
                    "columns": [
                        [
                            "type": "Column",
                            "items": [
                                ["type": "TextBlock", "text": "**Intent**", "weight": "Bolder", "wrap": true]
                            ],
                            "width": "stretch"
                        ],
                        [
                            "type": "Column",
                            "items": [
                                ["type": "TextBlock", "text": "**Group**", "weight": "Bolder", "wrap": true]
                            ],
                            "width": "stretch"
                        ]
                    ]
                ]

                // ✅ Assignment Data Rows
                let tableRows: [[String: Any]] = assignments.map { assignment in
                    return [
                        "type": "ColumnSet",
                        "columns": [
                            [
                                "type": "Column",
                                "items": [
                                    ["type": "TextBlock", "text": assignment["title"] ?? "", "wrap": true]
                                ],
                                "width": "stretch"
                            ],
                            [
                                "type": "Column",
                                "items": [
                                    ["type": "TextBlock", "text": assignment["value"] ?? "", "wrap": true]
                                ],
                                "width": "stretch"
                            ]
                        ],
                        "separator": true
                    ]
                }

                // ✅ Append Assignments Table (Header + Rows)
                bodyContent.append(tableHeader)
                bodyContent.append(contentsOf: tableRows)
            }
            
        }
        // ✅ Final Adaptive Card Payload
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
