//
//  TeamsNotifier+NotifySuccessSingle.swift
//  Intuneomator
//
//  Created by Gil Burns on 6/2/25.
//

import Foundation

// MARK: - Single Notification Deployment Extension

/// Extension for sending Microsoft Teams notification about all deployment results for a given run
/// Provides comprehensive reporting for multi-app automation workflows with success/failure categorization
extension TeamsNotifier {
    
    /// Sends a Microsoft Teams notification for multiple deployment automation results
    /// Creates an adaptive card summarizing success and failure outcomes with direct Intune app links
    /// - Parameter processingResults: Array of tuples containing deployment results with folder names, display names, status messages, app IDs, and success flags
    func sendSingleSuccessNotification(
        processingResults: [(folder: String, displayName: String, text: String, newAppID: String, success: Bool)]
    ) async {
        // Configure notification branding and metadata
        let title = "Automation Results"
        let intuneomatorIconUrl = "https://icons.intuneomator.org/intuneomator.png"
        let time = "🕰️ \(TeamsNotifier.dateFormatter.string(from: Date()))"
        let intuneAppLink = "https://intune.microsoft.com/#view/Microsoft_Intune_Apps/SettingsMenu/~/0/appId/"
        
        // Initialize arrays to categorize deployment results
        var postiveResults: [(folder: String, displayName: String, text: String, newAppID: String, success: Bool)] = []
        var negativeResults: [(folder: String, displayName: String, text: String, newAppID: String, success: Bool)] = []

        // Categorize processing results into success and failure groups for separate display sections
        for result in processingResults {
            if result.success {
                postiveResults.append(result)
            } else {
                negativeResults.append(result)
            }
        }

        
        // Build markdown-formatted lists for successful deployments with direct app links
        // Format: • ✅ AppName [Intune Link:](url) – Status message
        var positiveMarkdownLines: [String] = []
        for (_, message, displayName, newAppID, success) in postiveResults {
            let prefix = success ? "✅" : "⚠️"

            positiveMarkdownLines.append("• \(prefix) **\(displayName)** [Intune Link:](\(intuneAppLink)\(newAppID)) – \(message)")
        }
        let combinedPositiveList = positiveMarkdownLines.joined(separator: "  \n")

        // Build markdown-formatted lists for failed deployments with folder context
        // Format: • ⚠️ AppName FolderName – Error message
        var negativeMarkdownLines: [String] = []
        for (folder, message, displayName, _, success) in negativeResults {
            let prefix = success ? "✅" : "⚠️"
            
            negativeMarkdownLines.append("• \(prefix) **\(displayName)** \(folder) – \(message)")
        }
        let combinedNegativeList = negativeMarkdownLines.joined(separator: "  \n")

        
        // Build adaptive card body content with header, status indicator, and result details
        let bodyContent: [[String: Any]] = [
            // Header row with icon, spacer, and success status indicator
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
            // Main title
            [
                "type": "TextBlock",
                "text": "**\(title)**",
                "weight": "Bolder",
                "spacing": "None",
                "size": "Large"
            ],
            // Deployment update description
            [
                "type": "TextBlock",
                "text": "Intuneomator deployment update",
                "weight": "Lighter",
                "spacing": "Small",
                "size": "Small"
            ],
            // Timestamp of notification
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
            // Successful deployments section header
            [
                "type": "TextBlock",
                "text": "**Success Details:**",
                "weight": "Bolder",
                "spacing": "Medium"
            ],
            // List of successful deployments with Intune app links
            [
                "type": "TextBlock",
                "text": "\(combinedPositiveList)",
                "wrap": true,
                "spacing": "Small"
            ],
            // Failed deployments section header
            [
                "type": "TextBlock",
                "text": "**Failure Details:**",
                "weight": "Bolder",
                "spacing": "Medium"
            ],
            // List of failed deployments with error messages
            [
                "type": "TextBlock",
                "text": "\(combinedNegativeList)",
                "wrap": true,
                "spacing": "Small"
            ]

        ]
                
        // Send the constructed adaptive card notification to Microsoft Teams
        sendTeamsNotification(bodyContent: bodyContent)

    }

}
