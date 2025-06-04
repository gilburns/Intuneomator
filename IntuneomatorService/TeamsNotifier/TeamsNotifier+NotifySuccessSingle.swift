//
//  TeamsNotifier+NotifySuccessSingle.swift
//  Intuneomator
//
//  Created by Gil Burns on 6/2/25.
//

import Foundation

extension TeamsNotifier {
    
    func sendSingleSuccessNotification(
        processingResults: [(folder: String, displayName: String, text: String, newAppID: String, success: Bool)]
    ) async {
        let title = "Automation Results"
        let intuneomatorIconUrl = "https://icons.intuneomator.org/intuneomator.png"
        let time = "🕰️ \(TeamsNotifier.dateFormatter.string(from: Date()))"
        let intuneAppLink = "https://intune.microsoft.com/#view/Microsoft_Intune_Apps/SettingsMenu/~/0/appId/"
        
        
        var postiveResults: [(folder: String, displayName: String, text: String, newAppID: String, success: Bool)] = []
        var negativeResults: [(folder: String, displayName: String, text: String, newAppID: String, success: Bool)] = []

        
        // Filter the results into success/fail for the Teams message.
        for result in processingResults {
            if result.success {
                postiveResults.append(result)
            } else {
                negativeResults.append(result)
            }
        }

        
        // Build a markdown list, e.g.:
        // • ✅ MyFolder1 – All good
        // • ⚠️ MyFolder2 – Warning: minor issue
        var positiveMarkdownLines: [String] = []
        for (_, message, displayName, newAppID, success) in postiveResults {
            let prefix = success ? "✅" : "⚠️"

            positiveMarkdownLines.append("• \(prefix) **\(displayName)** [Intune App Link:](\(intuneAppLink)\(newAppID)) – \(message)")
        }
        let combinedPositiveList = positiveMarkdownLines.joined(separator: "  \n")

        var negativeMarkdownLines: [String] = []
        for (folder, message, displayName, _, success) in negativeResults {
            let prefix = success ? "✅" : "⚠️"
            
            negativeMarkdownLines.append("• \(prefix) **\(displayName)** \(folder) – \(message)")
        }
        let combinedNegativeList = negativeMarkdownLines.joined(separator: "  \n")

        
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
                "text": "**Success Details:**",
                "weight": "Bolder",
                "spacing": "Medium"
            ],
            [
                "type": "TextBlock",
                "text": "\(combinedPositiveList)",
                "wrap": true,
                "spacing": "Small"
            ],
            [
                "type": "TextBlock",
                "text": "**Failure Details:**",
                "weight": "Bolder",
                "spacing": "Medium"
            ],
            [
                "type": "TextBlock",
                "text": "\(combinedNegativeList)",
                "wrap": true,
                "spacing": "Small"
            ]

        ]
                
        Logger.log("Sending Teams Notification...", logType: TeamsNotifier.logType)
        sendTeamsNotification(bodyContent: bodyContent)

    }

}
