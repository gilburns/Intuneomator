//
//  TeamsNotifier+NotifyUpdateAvailable.swift
//  Intuneomator
//
//  Created by Gil Burns on 2/19/25.
//

import Foundation

// MARK: - Update Availability Notification Extension

/// Extension for sending Microsoft Teams notifications about available Intuneomator service updates
/// Provides proactive notifications when new service versions are detected but not yet installed
extension TeamsNotifier {
    
    /// Sends a Microsoft Teams notification alerting administrators about available service updates
    /// Creates an informational adaptive card showing current and available version information
    /// - Parameters:
    ///   - initialVersion: The currently installed version number
    ///   - updatedVersion: The newly available version number for update
    ///   - errorMessage: Optional error message if update detection encountered issues
    func sendUpdateAvailableNotification(
        initialVersion: String,
        updatedVersion: String,
        errorMessage: String? = nil
    ) {
        // Configure notification branding and metadata
        let title = "Intuneomator Service"
        let intuneomatorIconUrl: String = "https://icons.intuneomator.org/intuneomator.png"
        
        // Create version comparison facts for the adaptive card
        let versionFacts: [[String: String]] = [
            ["title": "Current Version:", "value": initialVersion],
            ["title": "Available Version:", "value": updatedVersion]
        ]
                
        // Build adaptive card body content with header and version information
        var bodyContent: [[String: Any]] = [
            // Header row with icon, spacer, and update availability indicator
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
                                        "value": "🟢 **UPDATE AVAILABLE**",
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
            // Update availability description
            [
                "type": "TextBlock",
                "text": "Intuneomator service has an available update.",
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
        
        // Add error information section if update detection encountered issues
        if let errorMessage = errorMessage, !errorMessage.trimmingCharacters(in: .whitespaces).isEmpty {
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

