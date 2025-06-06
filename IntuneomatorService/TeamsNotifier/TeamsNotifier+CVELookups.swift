//
//  TeamsNotifier+CVELookups.swift
//  Intuneomator
//
//  Created by Gil Burns on 5/24/25.
//

import Foundation

// MARK: - CVE Lookup and Formatting Extension

/// Extension for generating Microsoft Teams adaptive card sections from CVE (Common Vulnerabilities and Exposures) data
/// Provides formatted vulnerability information with severity categorization and links to detailed CVE records
extension TeamsNotifier {
    
    /// Creates adaptive card sections displaying CVE vulnerability information for Teams notifications
    /// Formats vulnerability data with severity indicators, descriptions, and links to National Vulnerability Database
    /// - Parameter cves: Array of VulnerabilityEntry objects containing CVE data to display
    /// - Returns: Array of adaptive card section dictionaries formatted for Microsoft Teams
    func createCVESections(_ cves: [VulnerabilityEntry]) -> [[String: Any]] {
        // Handle case where no vulnerabilities are found
        guard !cves.isEmpty else {
            return [
                // Section separator
                [
                    "type": "TextBlock",
                    "text": "---",
                    "weight": "Lighter",
                    "spacing": "Medium",
                    "separator": true
                ],
                // Vulnerabilities section header
                [
                    "type": "TextBlock",
                    "text": "**Security Vulnerabilities:**",
                    "weight": "Bolder",
                    "spacing": "Medium"
                ],
                // No vulnerabilities found message
                [
                    "type": "TextBlock",
                    "text": "🟢 No recent security vulnerabilities found",
                    "color": "good"
                ]
            ]
        }
        
        // Categorize vulnerabilities by severity level for summary statistics
        let critical = cves.filter { $0.severity?.uppercased() == "CRITICAL" }.count
        let high = cves.filter { $0.severity?.uppercased() == "HIGH" }.count
        let medium = cves.filter { $0.severity?.uppercased() == "MEDIUM" }.count
        let low = cves.filter { $0.severity?.uppercased() == "LOW" }.count

        // Build human-readable severity breakdown string
        var severitySummary = ""
        if critical > 0 { severitySummary += "\(critical) CRITICAL" }
        if high > 0 {
            if !severitySummary.isEmpty { severitySummary += ", " }
            severitySummary += "\(high) HIGH"
        }
        if medium > 0 {
            if !severitySummary.isEmpty { severitySummary += ", " }
            severitySummary += "\(medium) MEDIUM"
        }
        if low > 0 {
            if !severitySummary.isEmpty { severitySummary += ", " }
            severitySummary += "\(low) LOW"
        }

        // Handle case where severity information is not available
        if severitySummary.isEmpty {
            severitySummary = "severity unknown"
        }

        let summary = "Found \(cves.count) recent CVEs (\(severitySummary) severity)"
        
        // Build formatted CVE details with links and severity indicators
        var cveDetails = ""
        for cve in cves {
            let cveId = cve.cve.id
            let nvdUrl = "https://nvd.nist.gov/vuln/detail/\(cveId)"
            let scoreText = cve.baseScore != nil ? " | \(cve.severity ?? "Unknown") (\(cve.baseScore!))" : ""
            
            // Select appropriate emoji based on severity level for visual classification
            let severityEmoji = if cve.severity?.lowercased() == "critical" || cve.severity?.lowercased() == "high" {
                "🔴"  // Red circle for HIGH/CRITICAL severity
            } else if cve.severity?.lowercased() == "medium" {
                "🟡"    // Yellow circle for MEDIUM severity
            } else {
                "🔵"     // Blue circle for LOW/UNKNOWN severity
            }

            // Truncate vulnerability description to maintain readability in Teams cards
            let fullDescription = cve.englishDescription ?? "No description"
            let truncatedDescription = fullDescription.count > 200
            ? String(fullDescription.prefix(200)) + "..."
            : fullDescription
            
            // Format CVE entry with clickable link to National Vulnerability Database
            cveDetails += "\(severityEmoji) **[\(cveId)](\(nvdUrl))**\(scoreText)\n"
            cveDetails += "\(truncatedDescription) [Read more](\(nvdUrl))\n\n"
        }
        
        // Determine overall color scheme based on highest severity level found
        let color = if critical > 0 || high > 0 {
            "attention"  // Red color for HIGH/CRITICAL vulnerabilities
        } else if medium > 0 {
            "warning"    // Yellow color for MEDIUM vulnerabilities
        } else {
            "accent"     // Blue color for LOW/UNKNOWN vulnerabilities
        }

        // Return adaptive card sections for vulnerabilities display
        return [
            // Section separator line
            [
                "type": "TextBlock",
                "text": "---",
                "weight": "Lighter",
                "spacing": "Medium",
                "separator": true
            ],
            // Vulnerabilities section header
            [
                "type": "TextBlock",
                "text": "**Security Vulnerabilities:**",
                "weight": "Bolder",
                "spacing": "Medium"
            ],
            // Summary count and severity breakdown with color coding
            [
                "type": "TextBlock",
                "text": summary,
                "color": color
            ],
            // Detailed CVE listings with descriptions and links
            [
                "type": "TextBlock",
                "text": cveDetails,
                "wrap": true
            ]
        ]
    }
}
