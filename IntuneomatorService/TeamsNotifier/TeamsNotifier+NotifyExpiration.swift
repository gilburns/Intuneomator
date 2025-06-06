//
//  TeamsNotifier+NotifyExpiration.swift
//  Intuneomator
//
//  Created by Gil Burns on 2/19/25.
//

import Foundation

/// Extension for TeamsNotifier that handles authentication credential expiration notifications.
/// This module sends Teams notifications when certificates or client secrets used for Microsoft Graph
/// authentication are approaching their expiration dates, providing administrators with advance warning
/// to renew credentials and maintain service continuity.
extension TeamsNotifier {
    
    /// Sends a Microsoft Teams notification when an authentication certificate is approaching expiration.
    /// 
    /// Creates and sends a formatted Teams Adaptive Card notification containing certificate details
    /// and expiration information. The notification includes certificate metadata such as thumbprint,
    /// DNS names, and dates to help administrators identify and replace the expiring certificate.
    /// 
    /// - Parameters:
    ///   - expirationDate: The date when the certificate expires (formatted string)
    ///   - importDate: The date when the certificate was imported (formatted string)
    ///   - thumbprint: The certificate's unique thumbprint identifier
    ///   - dnsNames: DNS names associated with the certificate
    /// 
    /// **Visual Elements:**
    /// - Red "Expiring" status indicator with attention styling
    /// - Intuneomator icon and service branding
    /// - Structured fact set displaying certificate details
    /// - Professional card layout with clear hierarchy
    func sendCertExpiringNotification(
        expirationDate: String,
        importDate: String,
        thumbprint: String,
        dnsNames: String
    ) {
        let title = "Intuneomator Service"
        let intuneomatorIconUrl: String = "https://icons.intuneomator.org/intuneomator.png"
        
        // Certificate information displayed as structured facts
        let certFacts: [[String: String]] = [
            ["title": "Expiration Date:", "value": expirationDate],
            ["title": "Import Date:", "value": importDate],
            ["title": "Thumbprint:", "value": thumbprint],
            ["title": "DNS Names:", "value": dnsNames]
        ]
                
        // Build Adaptive Card body with header, status, and certificate details
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
                                        "value": "🔴 **Expiring**",
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
                "text": "Intuneomator authentication certificate is expiring",
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
                "text": "**Certificate Information:**",
                "weight": "Bolder",
                "size": "Medium",
                "spacing": "Medium"
            ],
            [
                "type": "FactSet",
                "facts": certFacts
            ],
            [
                "type": "TextBlock",
                "text": "---",
                "weight": "Lighter",
                "spacing": "Medium",
                "separator": true
            ]
        ]
        
        // Send Teams Notification
        self.sendTeamsNotification(bodyContent: bodyContent)

    }

    
    /// Sends a Microsoft Teams notification when a client secret is approaching expiration.
    /// 
    /// Creates and sends a formatted Teams Adaptive Card notification containing client secret
    /// expiration details. The notification provides administrators with advance warning to renew
    /// the client secret and maintain Microsoft Graph API authentication continuity.
    /// 
    /// - Parameters:
    ///   - expirationDate: The date when the client secret expires (formatted string)
    ///   - importDate: The date when the client secret was created/imported (formatted string)
    /// 
    /// **Visual Elements:**
    /// - Red "Expiring" status indicator with attention styling
    /// - Intuneomator icon and service branding
    /// - Structured fact set displaying secret details (without sensitive information)
    /// - Professional card layout matching certificate notification format
    func sendSecretExpiringNotification(
        expirationDate: String,
        importDate: String
    ) {
        let title = "Intuneomator Service"
        let intuneomatorIconUrl: String = "https://icons.intuneomator.org/intuneomator.png"
        
        // Client secret information displayed as structured facts (no sensitive data)
        let secretFacts: [[String: String]] = [
            ["title": "Expiration Date:", "value": expirationDate],
            ["title": "Import Date:", "value": importDate]
        ]
                
        // Build Adaptive Card body with header, status, and secret details
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
                                        "value": "🔴 **Expiring**",
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
                "text": "Intuneomator authentication secret is expiring",
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
                "text": "**Client Secret Information:**",
                "weight": "Bolder",
                "size": "Medium",
                "spacing": "Medium"
            ],
            [
                "type": "FactSet",
                "facts": secretFacts
            ],
            [
                "type": "TextBlock",
                "text": "---",
                "weight": "Lighter",
                "spacing": "Medium",
                "separator": true
            ]
        ]
        
        // Send Teams Notification
        self.sendTeamsNotification(bodyContent: bodyContent)
    }

}
