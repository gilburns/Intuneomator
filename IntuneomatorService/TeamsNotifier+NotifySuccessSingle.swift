//
//  TeamsNotifier+NotifySuccessSingle.swift
//  Intuneomator
//
//  Created by Gil Burns on 6/2/25.
//

import Foundation

extension TeamsNotifier {
    
    func sendSingleSuccessNotification(
        processingResults: [(String, String, Bool)]
    ) async {
        let title = "Automation Results"
        let intuneomatorIconUrl = "https://icons.intuneomator.org/intuneomator.png"
        let time = "🕰️ \(TeamsNotifier.dateFormatter.string(from: Date()))"
        
        // Build a markdown list, e.g.:
        // • ✅ MyFolder1 – All good
        // • ⚠️ MyFolder2 – Warning: minor issue
        var markdownLines: [String] = []
        for (folder, message, success) in processingResults {
            let parts = folder.split(separator: "_")
            guard let folderName = parts.first else { continue }
            let prefix = success ? "✅" : "⚠️"
            // You can optionally truncate or format `message` as needed
            markdownLines.append("• \(prefix) **\(folderName)** – \(message)")
        }
        let combinedList = markdownLines.joined(separator: "  \n")

        
        // ✅ Success Card Content (Image, Title, Separator, Details)
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
                "text": "\(time)",
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
                "type": "TextBlock",
                "text": "\(combinedList)",
                "wrap": true,
                "spacing": "Small"
            ]
        ]
                
        Logger.log("Sending Teams Notification...", logType: TeamsNotifier.logType)
        sendTeamsNotification(bodyContent: bodyContent)

    }

}
