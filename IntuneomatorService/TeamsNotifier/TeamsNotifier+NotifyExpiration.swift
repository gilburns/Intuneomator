//
//  TeamsNotifier+NotifyExpiration.swift
//  Intuneomator
//
//  Created by Gil Burns on 2/19/25.
//

import Foundation

extension TeamsNotifier {
    
    func sendCertExpiringNotification(
        expirationDate: String,
        importDate: String,
        thumbprint: String,
        dnsNames: String
    ) {
        let title = "Intuneomator Service"
        let intuneomatorIconUrl: String = "https://icons.intuneomator.org/intuneomator.png"
        
        let certFacts: [[String: String]] = [
            ["title": "Expiration Date:", "value": expirationDate],
            ["title": "Import Date:", "value": importDate],
            ["title": "Thumbprint:", "value": thumbprint],
            ["title": "DNS Names:", "value": dnsNames]
        ]
                
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

    
    func sendSecretExpiringNotification(
        expirationDate: String,
        importDate: String
    ) {
        let title = "Intuneomator Service"
        let intuneomatorIconUrl: String = "https://icons.intuneomator.org/intuneomator.png"
        
        let secretFacts: [[String: String]] = [
            ["title": "Expiration Date:", "value": expirationDate],
            ["title": "Import Date:", "value": importDate]
        ]
                
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
