//
//  TeamsNotifier+NotifyLabelUpdate.swift
//  Intuneomator
//
//  Created by Gil Burns on 6/1/25.
//

import Foundation

/// Extension for TeamsNotifier that handles Installomator label update notifications.
/// This module sends Teams notifications when the system updates Installomator label files,
/// providing status updates on version changes and any labels that were modified during
/// the update process. Supports both success and failure scenarios with detailed error reporting.
extension TeamsNotifier {
    
    /// Sends a Microsoft Teams notification for Installomator label update operations.
    /// 
    /// Creates and sends a formatted Teams Adaptive Card notification containing details about
    /// the label update process, including version information, updated labels, and status.
    /// Handles both successful updates and failure scenarios with appropriate visual styling.
    /// 
    /// - Parameters:
    ///   - initialVersion: The version of Installomator labels before the update
    ///   - updatedVersion: The new version of Installomator labels after the update
    ///   - updatedLabels: Array of label names that were modified during the update
    ///   - isSuccess: Boolean indicating whether the update operation succeeded
    ///   - errorMessage: Optional error message displayed when isSuccess is false
    /// 
    /// **Visual Elements:**
    /// - Dynamic status indicator (green SUCCESS or red FAILED)
    /// - Version comparison showing before/after states
    /// - Bulleted list of updated label files
    /// - Error details container with attention styling (failure cases only)
    /// - Professional card layout with Intuneomator branding
    /// 
    /// **Behavior:**
    /// - Automatically sorts updated labels alphabetically for consistent display
    /// - Handles singular/plural grammar for label count descriptions
    /// - Only displays error section when update fails and error message is provided
    func sendLabelUpdateNotification(
        initialVersion: String,
        updatedVersion: String,
        updatedLabels: [String],
        isSuccess: Bool,
        errorMessage: String? = nil
    ) async {
        
        Logger.debug("Sending label update notification...", category: .debug)
        let title = "Intuneomator Service"
        let intuneomatorIconUrl: String = "https://icons.intuneomator.org/intuneomator.png"
        
        // Version comparison information displayed as structured facts
        let versionFacts: [[String: String]] = [
            ["title": "Initial Version:", "value": initialVersion],
            ["title": "Updated Version:", "value": updatedVersion]
        ]
        
        let labelUpdateCount = updatedLabels.count
        let sortedLabelUpdates = updatedLabels.sorted(by: { $0 < $1 })
        
        // Create bulleted list of updated labels for display
        let labelTextBlock = [
            "type": "TextBlock",
            "text": sortedLabelUpdates.map { "• \($0)" }.joined(separator: "  \n"),
            "wrap": true,
            "spacing": "Small"
        ] as [String : Any]
        
        // Build Adaptive Card body with dynamic status, version info, and labels
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
        
        // Add updated labels section if any labels were modified
        if labelUpdateCount > 0 {
            // Generate grammatically correct label count description
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
        }
        
        // Add error details section for failed updates (only if error message provided)
        if !isSuccess, let errorMessage = errorMessage, !errorMessage.trimmingCharacters(in: .whitespaces).isEmpty {
            bodyContent.append([
                "type": "TextBlock",
                "text": "**Error Details**",
                "weight": "Bolder",
                "size": "Medium",
                "color": "Attention",
                "spacing": "Medium"
            ])
            
            // Error message in attention-styled container
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
