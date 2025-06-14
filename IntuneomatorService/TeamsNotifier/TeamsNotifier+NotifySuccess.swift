//
//  TeamsNotifier+NotifySuccess.swift
//  Intuneomator
//
//  Created by Gil Burns on 2/19/25.
//

import Foundation

// MARK: - Success Notification Extension

/// Extension for sending Microsoft Teams notifications about successful application deployments
/// Provides comprehensive deployment reporting with metadata, group assignments, and CVE information
extension TeamsNotifier {
    
    /// Sends a detailed Microsoft Teams notification for successful application deployment
    /// Creates an adaptive card with comprehensive deployment information, optional group assignments, and CVE data
    /// - Parameters:
    ///   - title: The application display name
    ///   - version: The deployed application version
    ///   - size: The file size of the deployed application
    ///   - time: The deployment completion timestamp
    ///   - imageURL: The URL for the application icon to display
    ///   - deploymentType: Optional deployment type (LOB, MSI, etc.)
    ///   - architecture: Optional architecture information (Universal, ARM64, x86_64)
    ///   - releaseNotesURL: Optional URL to application release notes or update details
    ///   - assignedGroups: Array of group assignment information for the deployed application
    func sendSuccessNotification(
        title: String,
        version: String,
        size: String,
        time: String,
        imageURL: String,
        deploymentType: String?,
        architecture: String?,
        releaseNotesURL: String?,
        assignedGroups: [[String : Any]]
    ) async {
        
        // Read configuration settings for optional notification content
        let includeGroups = ConfigManager.readPlistValue(key: "TeamsNotificationsForGroups") ?? false
        let includeCVEs = ConfigManager.readPlistValue(key: "TeamsNotificationsForCVEs") ?? false

        // Build core application facts for the adaptive card
        var facts: [[String: String]] = [
            ["title": "Version:", "value": version],
            ["title": "Size:", "value": size],
            ["title": "Time:", "value": time]
        ]
        
        // Add optional deployment metadata if provided
        if let deploymentType = deploymentType {
            facts.append(["title": "Deployment Type:", "value": deploymentType])
        }
        if let architecture = architecture {
            facts.append(["title": "Architecture:", "value": architecture])
        }
        if let releaseNotesURL = releaseNotesURL {
            facts.append(["title": "Release Notes:", "value": "[Update Details](\(releaseNotesURL))"])
        }
        
        // Build adaptive card body content with header, application icon, and success indicator
        var bodyContent: [[String: Any]] = [
            // Header row with application icon, spacer, and success status indicator
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
            // Application title
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
            // Section separator
            [
                "type": "TextBlock",
                "text": "---",
                "weight": "Lighter",
                "spacing": "Medium",
                "separator": true
            ],
            // Software details section header
            [
                "type": "TextBlock",
                "text": "**Software Details:**",
                "weight": "Bolder",
                "spacing": "Medium"
            ],
            // Application metadata facts display
            [
                "type": "FactSet",
                "facts": facts
            ]
        ]
        
        // Add group assignment information if configured to include groups
        if includeGroups {
            let groupInfoBlocks = formatAssignedGroups(assignedGroups)
            bodyContent.append(contentsOf: groupInfoBlocks)
        }
        
        // Add CVE (Common Vulnerabilities and Exposures) information if configured
        if includeCVEs {
            Logger.error("Loading CVEs for \(title)...", category: .core)
            let fetcher = CVEFetcher()
            
            // Fetch CVE data asynchronously and send notification when complete
            fetcher.fetchCVEsSimple(for: title) { [self] result in
                switch result {
                case .success(let cves):
                    // Add CVE information sections to the notification body
                    let cveSections = createCVESections(cves)
                    bodyContent.append(contentsOf: cveSections)
                case .failure(let error):
                    Logger.error("Error fetching CVEs: \(error)", category: .core)
                    // Continue without CVE data if fetch fails
                }
                
                // Send the constructed adaptive card notification to Microsoft Teams
                self.sendTeamsNotification(bodyContent: bodyContent)
            }
        } else {
            // Send notification immediately without CVE data
            sendTeamsNotification(bodyContent: bodyContent)
        }
    }

}
