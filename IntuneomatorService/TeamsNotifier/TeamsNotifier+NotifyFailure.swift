//
//  TeamsNotifier+NotifyFailure.swift
//  Intuneomator
//
//  Created by Gil Burns on 2/19/25.
//

import Foundation

extension TeamsNotifier {
    
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
        
        // Send Teams Notification
        sendTeamsNotification(bodyContent: bodyContent)
    }

}
