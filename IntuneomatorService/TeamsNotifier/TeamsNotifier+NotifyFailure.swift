//
//  TeamsNotifier+NotifyFailure.swift
//  Intuneomator
//
//  Created by Gil Burns on 2/19/25.
//

import Foundation

/// Extension for TeamsNotifier that handles application deployment failure notifications.
/// This module sends Teams notifications when Intune application deployments fail,
/// providing detailed error information, application metadata, and debugging context
/// to help administrators quickly identify and resolve deployment issues.
extension TeamsNotifier {
    
    /// Sends a Microsoft Teams notification when an application deployment fails.
    /// 
    /// Creates and sends a formatted Teams Adaptive Card notification containing comprehensive
    /// failure details including application metadata, error information, and deployment context.
    /// The notification uses attention styling to clearly indicate the failure status and provide
    /// administrators with the information needed to diagnose and resolve the issue.
    /// 
    /// - Parameters:
    ///   - title: The application name or title that failed to deploy
    ///   - version: The version of the application that failed
    ///   - size: The file size of the application package
    ///   - time: The timestamp when the deployment failure occurred
    ///   - imageURL: URL to the application icon or image for visual identification
    ///   - deploymentType: Optional deployment type (e.g., "Required", "Available")
    ///   - architecture: Optional architecture specification (e.g., "Universal", "ARM64")
    ///   - errorMessage: Detailed error message explaining the failure cause
    /// 
    /// **Visual Elements:**
    /// - Red "FAILED" status indicator with attention styling
    /// - Application icon for easy visual identification
    /// - Structured fact set displaying software details
    /// - Error details container with enhanced visibility
    /// - Professional card layout with clear hierarchy
    /// 
    /// **Behavior:**
    /// - Conditionally includes deployment type and architecture if provided
    /// - Only displays error details section when error message is not empty
    /// - Uses attention color scheme throughout for failure emphasis
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
        // Build application details fact set with core information
        var facts: [[String: String]] = [
            ["title": "Version:", "value": version],
            ["title": "Size:", "value": size],
            ["title": "Time:", "value": time]
        ]
        
        // Add optional deployment metadata if available
        if let deploymentType = deploymentType {
            facts.append(["title": "Deployment Type:", "value": deploymentType])
        }
        if let architecture = architecture {
            facts.append(["title": "Architecture:", "value": architecture])
        }
        
        // Build Adaptive Card body with failure status, app details, and error information
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
        
        // Add detailed error information section (only if error message provided)
        if !errorMessage.trimmingCharacters(in: .whitespaces).isEmpty {
            bodyContent.append([
                "type": "TextBlock",
                "text": "**Error Details**",
                "weight": "Bolder",
                "size": "Medium",
                "color": "Attention",
                "spacing": "Medium"
            ])
            
            // Error message in attention-styled container for enhanced visibility
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
