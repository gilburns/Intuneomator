//
//  TeamsNotifier+NotifyUpdate.swift
//  Intuneomator
//
//  Created by Gil Burns on 2/19/25.
//

import Foundation

extension TeamsNotifier {
    
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

}

