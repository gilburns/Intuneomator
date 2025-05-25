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
    
    func sendSuccessNotification(
        title: String,
        version: String,
        size: String,
        time: String,
        imageURL: String,
        deploymentType: String?,
        architecture: String?,
        releaseNotesURL: String?,
        assignedGroups: [[String : Any]]
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
        
        // ✅ Success Card Content (Image, Title, Separator, Details)
        var bodyContent: [[String: Any]] = [
            [
                "type": "ColumnSet",
                "columns": [
                    [
                        "type": "Column",
                        "items": [
                            ["type": "Image", "url": imageURL, "size": "Medium"]
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
                                        "value": "🟢 **SUCCESS**",
                                        "color": "Good",
                                    ]
                                ]
                            ]
                        ],
                        "width": "auto",
                        "style": "good",
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
                "type": "TextBlock",
                "text": "**Software Details:**",
                "weight": "Bolder",
                "spacing": "Medium"
            ],
            [
                "type": "FactSet",
                "facts": facts
            ]
        ]
        
        // ✅ Add Assignment Groups for Success
        let groupInfoBlocks = formatAssignedGroups(assignedGroups)
        bodyContent.append(contentsOf: groupInfoBlocks)
        
        // Fetch CVEs and send notification when complete
        Logger.log("Loading CVEs for \(title)...", logType: "Teams")
        let fetcher = CVEFetcher()
        
        fetcher.fetchCVEsSimple(for: title) { [self] result in
            // Add CVE sections to bodyContent
            switch result {
            case .success(let cves):
                let cveSections = createCVESections(cves)
                bodyContent.append(contentsOf: cveSections)
                Logger.log("CVE fetch complete. Found \(cves.count) CVEs", logType: "Teams")
            case .failure(let error):
                Logger.log("Error fetching CVEs: \(error)", logType: "Teams")
                // Continue without CVE data
            }
            
            // Send Teams Notification
            self.sendTeamsNotification(bodyContent: bodyContent)
        }
    }
    
    func sendErrorNotification(
        title: String,
        version: String,
        size: String,
        time: String,
        imageURL: String,
        deploymentType: String?,
        architecture: String?,
        errorMessage: String
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
        
        // ✅ Error Card Content (Image, Title, Separator, Details)
        var bodyContent: [[String: Any]] = [
            [
                "type": "ColumnSet",
                "columns": [
                    [
                        "type": "Column",
                        "items": [
                            ["type": "Image", "url": imageURL, "size": "Medium"]
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
                                        "value": "🔴 **FAILED**",
                                        "color": "Attention",
                                    ]
                                ]
                            ]
                        ],
                        "width": "auto",
                        "style": "attention",
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
        
        // ✅ Add Error Details
        if !errorMessage.trimmingCharacters(in: .whitespaces).isEmpty {
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
        
        // Send Teams Notification directly (no CVEs for errors)
        sendTeamsNotification(bodyContent: bodyContent)
    }

    func sendUpdateNotification(
        initialVersion: String,
        updatedVersion: String,
        daemonStatus: [String: String],
        isSuccess: Bool,
        errorMessage: String? = nil
    ) {
        let title = "Intuneomator Service"
        let intuneomatorIconUrl: String = "https://icons.intuneomator.org/intuneomator.png"        
        
        let versionFacts: [[String: String]] = [
            ["title": "Initial Version:", "value": initialVersion],
            ["title": "Updated Version:", "value": updatedVersion]
        ]
        
        let sortedDaemonStatus = daemonStatus.sorted { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }

        let daemonRows: [[String: Any]] = sortedDaemonStatus.map { key, value in
            return [
                "type": "ColumnSet",
                "columns": [
                    [
                        "type": "Column",
                        "width": "stretch",
                        "items": [
                            ["type": "TextBlock", "text": "**\(key)**", "wrap": true]
                        ]
                    ],
                    [
                        "type": "Column",
                        "width": "auto",
                        "items": [
                            ["type": "TextBlock", "text": value, "wrap": true]
                        ]
                    ]
                ],
                "separator": true
            ]
        }
        
        var bodyContent: [[String: Any]] = [
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
                "text": isSuccess ? "Intuneomator service was updated" : "Intuneomator service update failed",
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
                "type": "TextBlock",
                "text": "**Version Information:**",
                "weight": "Bolder",
                "size": "Medium",
                "spacing": "Medium"
            ],
            [
                "type": "FactSet",
                "facts": versionFacts
            ],
            [
                "type": "TextBlock",
                "text": "---",
                "weight": "Lighter",
                "spacing": "Medium",
                "separator": true
            ]
        ]
        
        // Add Daemon info
        bodyContent.append([
            "type": "TextBlock",
            "text": "**Post Update Daemon Status:**",
            "weight": "Bolder",
            "size": "Medium",
            "spacing": "Medium"
        ])
        bodyContent.append(contentsOf: daemonRows)

        // Add possible error info
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

        // Send Teams Notification
        self.sendTeamsNotification(bodyContent: bodyContent)

    }
    
    
    func sendCertExpiringNotification(
        expirationDate: String,
        importDate: String,
        thumbprint: String,
        dnsNames: String
    ) {
        let title = "Intuneomator Service"
        let intuneomatorIconUrl: String = "https://icons.intuneomator.org/intuneomator.png"
        
        let certFacts: [[String: String]] = [
            ["title": "Expiration Date:", "value": expirationDate],
            ["title": "Import Date:", "value": importDate],
            ["title": "Thumbprint:", "value": thumbprint],
            ["title": "DNS Names:", "value": dnsNames]
        ]
                
        let bodyContent: [[String: Any]] = [
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
                                        "value": "🔴 **Expiring**",
                                        "color": "Attention",
                                    ]
                                ]
                            ]
                        ],
                        "width": "auto",
                        "style": "attention",
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
                "text": "Intuneomator authentication certificate is expiring",
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
                "type": "TextBlock",
                "text": "**Certificate Information:**",
                "weight": "Bolder",
                "size": "Medium",
                "spacing": "Medium"
            ],
            [
                "type": "FactSet",
                "facts": certFacts
            ],
            [
                "type": "TextBlock",
                "text": "---",
                "weight": "Lighter",
                "spacing": "Medium",
                "separator": true
            ]
        ]
        
        // Send Teams Notification
        self.sendTeamsNotification(bodyContent: bodyContent)

    }

    
    func sendSecretExpiringNotification(
        expirationDate: String,
        importDate: String
    ) {
        let title = "Intuneomator Service"
        let intuneomatorIconUrl: String = "https://icons.intuneomator.org/intuneomator.png"
        
        let secretFacts: [[String: String]] = [
            ["title": "Expiration Date:", "value": expirationDate],
            ["title": "Import Date:", "value": importDate]
        ]
                
        let bodyContent: [[String: Any]] = [
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
                                        "value": "🔴 **Expiring**",
                                        "color": "Attention",
                                    ]
                                ]
                            ]
                        ],
                        "width": "auto",
                        "style": "attention",
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
                "text": "Intuneomator authentication secret is expiring",
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
                "type": "TextBlock",
                "text": "**Client Secret Information:**",
                "weight": "Bolder",
                "size": "Medium",
                "spacing": "Medium"
            ],
            [
                "type": "FactSet",
                "facts": secretFacts
            ],
            [
                "type": "TextBlock",
                "text": "---",
                "weight": "Lighter",
                "spacing": "Medium",
                "separator": true
            ]
        ]
        
        // Send Teams Notification
        self.sendTeamsNotification(bodyContent: bodyContent)
    }
    
    
    private func sendTeamsNotification(bodyContent: [[String: Any]]) {
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
