//
//  TeamsNotifier+NotifySuccess.swift
//  Intuneomator
//
//  Created by Gil Burns on 2/19/25.
//

import Foundation

extension TeamsNotifier {
    
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
        
        
        let includeGroups = ConfigManager.readPlistValue(key: "TeamsNotificationsForGroups") == false
        let includeCVEs = ConfigManager.readPlistValue(key: "TeamsNotificationsForCVEs") == false

                
        var facts: [[String: String]] = [
            ["title": "Version:", "value": version],
            ["title": "Size:", "value": size],
            ["title": "Time:", "value": time]
        ]
        
        if let deploymentType = deploymentType {
            facts.append(["title": "Deployment Type:", "value": deploymentType])
        }
        if let architecture = architecture {
            facts.append(["title": "Architecture:", "value": architecture])
        }
        if let releaseNotesURL = releaseNotesURL {
            facts.append(["title": "Release Notes:", "value": "[Update Details](\(releaseNotesURL))"])
        }
        
        // ✅ Success Card Content (Image, Title, Separator, Details)
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
        
        if includeGroups {
            // ✅ Add Assignment Groups for Success
            let groupInfoBlocks = formatAssignedGroups(assignedGroups)
            bodyContent.append(contentsOf: groupInfoBlocks)
        }
        
        if includeCVEs {
            // Fetch CVEs and send notification when complete
            Logger.log("Loading CVEs for \(title)...", logType: TeamsNotifier.logType)
            let fetcher = CVEFetcher()
            
            fetcher.fetchCVEsSimple(for: title) { [self] result in
                // Add CVE sections to bodyContent
                switch result {
                case .success(let cves):
                    let cveSections = createCVESections(cves)
                    bodyContent.append(contentsOf: cveSections)
                    Logger.log("CVE fetch complete. Found \(cves.count) CVEs", logType: TeamsNotifier.logType)
                case .failure(let error):
                    Logger.log("Error fetching CVEs: \(error)", logType: TeamsNotifier.logType)
                    // Continue without CVE data
                }
                
                // Send Teams Notification
                Logger.log("Sending Teams Notification...", logType: TeamsNotifier.logType)
                self.sendTeamsNotification(bodyContent: bodyContent)
            }
        } else {
            Logger.log("Sending Teams Notification...", logType: TeamsNotifier.logType)
            sendTeamsNotification(bodyContent: bodyContent)
        }
    }

}
