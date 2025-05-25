//
//  TeamsNotifier+GroupsFormatting.swift
//  Intuneomator
//
//  Created by Gil Burns on 5/25/25.
//

import Foundation

extension TeamsNotifier {
    
    func formatAssignedGroups(_ assignedGroups: [[String: Any]]) -> [[String: Any]] {
        guard !assignedGroups.isEmpty else {
            return []
        }
        
        // Group by assignment type
        let groupedByType = Dictionary(grouping: assignedGroups) { group in
            group["assignmentType"] as? String ?? "Unknown"
        }
        
        // Define the order of assignment types
        let assignmentTypeOrder = ["Required", "Available", "Uninstall"]
        
        var textBlocks: [[String: Any]] = []
        
        // Add separator and title
        textBlocks.append([
            "type": "TextBlock",
            "text": "---",
            "weight": "Lighter",
            "spacing": "Medium",
            "separator": true
        ])
        
        let groupCount = assignedGroups.count
        let groupLabel = groupCount == 1 ? "Group" : "Groups"
        textBlocks.append([
            "type": "TextBlock",
            "text": "**Assigned \(groupLabel) (\(groupCount)):**",
            "weight": "Bolder",
            "spacing": "Medium"
        ])
        
        // Create separate TextBlocks for each assignment type
        for assignmentType in assignmentTypeOrder {
            guard let groups = groupedByType[assignmentType], !groups.isEmpty else {
                continue
            }
            
            // Assignment type header
            textBlocks.append([
                "type": "TextBlock",
                "text": "**\(assignmentType):**",
                "weight": "Bolder",
                "spacing": "Small"
            ])
            
            // Individual group entries
            for group in groups {
                var groupLine: [String] = []
                
                // Get group mode and name
                if let groupMode = group["mode"] as? String,
                   let displayName = group["displayName"] as? String {
                    let isVirtual = group["isVirtual"] as? Int == 1
                    let formattedName = isVirtual ? "\(displayName) (Virtual Group)" : displayName
                    let capitalizedMode = groupMode.capitalized
                    groupLine.append("\(capitalizedMode) - \(formattedName)")
                }
                
                // Get filter mode and name if present
                if let filter = group["filter"] as? [String: Any],
                   let filterDisplayName = filter["displayName"] as? String,
                   !filterDisplayName.isEmpty,
                   let filterMode = filter["mode"] as? String {
                    let capitalizedFilterMode = filterMode.capitalized
                    groupLine.append("Filter: \(capitalizedFilterMode) - \(filterDisplayName)")
                }
                
                if !groupLine.isEmpty {
                    textBlocks.append([
                        "type": "TextBlock",
                        "text": "• \(groupLine.joined(separator: " | "))",
                        "wrap": true,
                        "spacing": "None"
                    ])
                }
            }
        }
        
        return textBlocks
    }
}


// Usage Example:

/*
      
 let groupInfoBlocks = formatAssignedGroups(assignedGroups)
 bodyContent.append(contentsOf: groupInfoBlocks)
 
 */
