//
//  TeamsNotifier+CVELookups.swift
//  Intuneomator
//
//  Created by Gil Burns on 5/24/25.
//

import Foundation

/// Generate Teams card sections as dictionary objects
extension TeamsNotifier {
    
    func createCVESections(_ cves: [VulnerabilityEntry]) -> [[String: Any]] {
        guard !cves.isEmpty else {
            return [[
                "type": "TextBlock",
                "text": "✅ No recent security vulnerabilities found",
                "color": "good"
            ]]
        }
        
        // Build severity summary
        let critical = cves.filter { $0.severity?.uppercased() == "CRITICAL" }.count
        let high = cves.filter { $0.severity?.uppercased() == "HIGH" }.count
        let medium = cves.filter { $0.severity?.uppercased() == "MEDIUM" }.count
        let low = cves.filter { $0.severity?.uppercased() == "LOW" }.count

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

        // Handle case where no severity info is available
        if severitySummary.isEmpty {
            severitySummary = "severity unknown"
        }

        let summary = "Found \(cves.count) recent CVEs (\(severitySummary) severity)"
        
        // Build COMPACT CVE details
        var cveDetails = ""
        for cve in cves {
            let cveId = cve.cve.id
            let nvdUrl = "https://nvd.nist.gov/vuln/detail/\(cveId)"
            let scoreText = cve.baseScore != nil ? " | \(cve.severity ?? "Unknown") (\(cve.baseScore!))" : ""
            
            // Truncate description to first 200 characters
            let fullDescription = cve.englishDescription ?? "No description"
            let truncatedDescription = fullDescription.count > 200
            ? String(fullDescription.prefix(200)) + "..."
            : fullDescription
            
            cveDetails += "**[\(cveId)](\(nvdUrl))**\(scoreText)\n"
            cveDetails += "\(truncatedDescription) [Read more](\(nvdUrl))\n\n"
        }
        
        let color = if critical > 0 || high > 0 {
            "attention"  // Red for HIGH/CRITICAL
        } else if medium > 0 {
            "warning"    // Yellow for MEDIUM
        } else {
            "accent"     // Blue for LOW
        }

        return [
            [
                "type": "TextBlock",
                "text": "---",
                "weight": "Lighter",
                "spacing": "Medium",
                "separator": true
            ],
            [
                "type": "TextBlock",
                "text": "**Security Vulnerabilities:**",
                "weight": "Bolder",
                "spacing": "Medium"
            ],
            [
                "type": "TextBlock",
                "text": summary,
                "color": color
            ],
            [
                "type": "TextBlock",
                "text": cveDetails,
                "wrap": true
            ]
        ]
    }
}
