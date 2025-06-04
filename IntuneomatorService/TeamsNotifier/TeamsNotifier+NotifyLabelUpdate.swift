//
//  TeamsNotifier+NotifyLabelUpdate.swift
//  Intuneomator
//
//  Created by Gil Burns on 6/1/25.
//

import Foundation

extension TeamsNotifier {
    
    func sendLabelUpdateNotification(
        initialVersion: String,
        updatedVersion: String,
        updatedLabels: [String],
        isSuccess: Bool,
        errorMessage: String? = nil
    ) async {
        
        Logger.log("Sending label update notification...", logType: "LabelUpdate")
        let title = "Intuneomator Service"
        let intuneomatorIconUrl: String = "https://icons.intuneomator.org/intuneomator.png"
        
        let versionFacts: [[String: String]] = [
            ["title": "Initial Version:", "value": initialVersion],
            ["title": "Updated Version:", "value": updatedVersion]
        ]
        
        let labelUpdateCount = updatedLabels.count
        let sortedLabelUpdates = updatedLabels.sorted(by: { $0 < $1 })
//        let labelRows: [[String: Any]] = sortedLabelUpdates.map { label in
//            return [
//                "type": "ColumnSet",
//                "columns": [
//                    [
//                        "type": "Column",
//                        "width": "stretch",
//                        "items": [
//                            ["type": "TextBlock", "text": "**\(label)**", "wrap": true]
//                        ]
//                    ]
//                ],
//                "separator": true
//            ]
//        }
        let labelTextBlock = [
            "type": "TextBlock",
            "text": sortedLabelUpdates.map { "• \($0)" }.joined(separator: "  \n"),
            "wrap": true,
            "spacing": "Small"
        ] as [String : Any]
        
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
                "text": isSuccess ? "Intuneomator labels were updated" : "Intuneomator labels update failed",
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
        
        
        // Add Label info
        if labelUpdateCount > 0 {
            var labelUpdateStatusLabel: String = ""
            
            if labelUpdateCount == 1 {
                labelUpdateStatusLabel = "\(labelUpdateCount) label was updated"
            } else if labelUpdateCount > 1 {
                labelUpdateStatusLabel = "\(labelUpdateCount) labels were updated"
            } else {
                labelUpdateStatusLabel = "No labels were updated"
            }

            bodyContent.append([
                "type": "TextBlock",
                "text": "**Label Files Updates (\(labelUpdateStatusLabel)):**",
                "weight": "Bolder",
                "size": "Medium",
                "spacing": "Medium"
            ])
            bodyContent.append(labelTextBlock)
//            bodyContent.append(contentsOf: labelRows)
        }
        

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
