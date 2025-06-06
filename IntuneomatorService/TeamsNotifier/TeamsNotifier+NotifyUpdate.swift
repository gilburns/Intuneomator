//
//  TeamsNotifier+NotifyUpdate.swift
//  Intuneomator
//
//  Created by Gil Burns on 2/19/25.
//

import Foundation

// MARK: - Service Update Notification Extension

/// Extension for sending Microsoft Teams notifications about Intuneomator service updates
/// Provides comprehensive update status reporting including version changes and daemon health checks
extension TeamsNotifier {
    
    /// Sends a detailed Microsoft Teams notification about service update status
    /// Creates an adaptive card with version information, daemon status, and error details if applicable
    /// - Parameters:
    ///   - initialVersion: The version number before the update
    ///   - updatedVersion: The version number after the update
    ///   - daemonStatus: Dictionary containing status of system daemons after update
    ///   - isSuccess: Boolean indicating whether the update completed successfully
    ///   - errorMessage: Optional error message to include if update failed
    func sendUpdateNotification(
        initialVersion: String,
        updatedVersion: String,
        daemonStatus: [String: String],
        isSuccess: Bool,
        errorMessage: String? = nil
    ) {
        // Configure notification branding and metadata
        let title = "Intuneomator Service"
        let intuneomatorIconUrl: String = "https://icons.intuneomator.org/intuneomator.png"
        
        // Create version comparison facts for the adaptive card
        let versionFacts: [[String: String]] = [
            ["title": "Initial Version:", "value": initialVersion],
            ["title": "Updated Version:", "value": updatedVersion]
        ]
        
        // Sort daemon status alphabetically for consistent presentation
        let sortedDaemonStatus = daemonStatus.sorted { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }

        // Create daemon status rows as adaptive card column sets
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
        
        // Build adaptive card body content with header, status, and version information
        var bodyContent: [[String: Any]] = [
            // Header row with icon, spacer, and status indicator
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
            // Main title
            [
                "type": "TextBlock",
                "text": "**\(title)**",
                "weight": "Bolder",
                "spacing": "None",
                "size": "Large"
            ],
            // Status description
            [
                "type": "TextBlock",
                "text": isSuccess ? "Intuneomator service was updated" : "Intuneomator service update failed",
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
            // Version information section header
            [
                "type": "TextBlock",
                "text": "**Version Information:**",
                "weight": "Bolder",
                "size": "Medium",
                "spacing": "Medium"
            ],
            // Version facts display
            [
                "type": "FactSet",
                "facts": versionFacts
            ],
            // Section separator
            [
                "type": "TextBlock",
                "text": "---",
                "weight": "Lighter",
                "spacing": "Medium",
                "separator": true
            ]
        ]
        
        // Add daemon status information section
        bodyContent.append([
            "type": "TextBlock",
            "text": "**Post Update Daemon Status:**",
            "weight": "Bolder",
            "size": "Medium",
            "spacing": "Medium"
        ])
        bodyContent.append(contentsOf: daemonRows)

        // Add error information section if update failed
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

        // Send the constructed adaptive card notification to Microsoft Teams
        self.sendTeamsNotification(bodyContent: bodyContent)

    }

}

