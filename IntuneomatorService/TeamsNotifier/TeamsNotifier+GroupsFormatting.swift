//
//  TeamsNotifier+GroupsFormatting.swift
//  Intuneomator
//
//  Created by Gil Burns on 5/25/25.
//

import Foundation

/// Extension for TeamsNotifier that formats assigned group information for Microsoft Teams notifications.
/// This module handles the formatting of Microsoft Intune group assignment data into structured text blocks
/// for Teams notifications using Adaptive Cards format.
extension TeamsNotifier {
    
    /// Formats Microsoft Intune group assignment data into structured text blocks for Teams notifications.
    /// 
    /// Takes an array of group dictionaries and formats them into Teams-displayable text blocks using Adaptive Cards format.
    /// Groups assignments by type (Required, Available, Uninstall) in a specific order, handles both regular and virtual 
    /// groups with appropriate labeling, and includes filter information when present.
    /// 
    /// - Parameter assignedGroups: Array of group dictionaries containing assignment information
    /// - Returns: Array of text block dictionaries compatible with Microsoft Teams Adaptive Cards
    /// 
    /// **Data Processing:**
    /// - Groups by `assignmentType` field
    /// - Displays group count and appropriate singular/plural labeling  
    /// - Formats group mode, display name, and virtual group indicators
    /// - Handles optional filter information with mode and display name
    /// 
    /// **Output Format:** Returns formatted Adaptive Card text blocks with proper hierarchy and styling,
    /// including separators, headers, and bulleted group entries.
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
