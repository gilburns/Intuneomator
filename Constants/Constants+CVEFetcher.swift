//
//  Constants+CVEFetcher.swift
//  Intuneomator
//
//  Created by Gil Burns on 5/24/25.
//

import Foundation

/// How we should scope our search
enum CVEFilter {
    case application(vendor: String, product: String)
    case operatingSystem(vendor: String, product: String)
    case keyword
    case multiCPE(applicationName: String)
}

/// The CPE search response
struct CPEResponse: Codable {
    let totalResults: Int
    let products: [CPEProduct]
}

struct CPEProduct: Codable {
    let cpe: CPEDetails
    
    struct CPEDetails: Codable {
        let cpeName: String
        let created: String
        let titles: [CPETitle]
        
        struct CPETitle: Codable {
            let title: String
            let lang: String
        }
    }
}

/// The NVD v2.0 CVE response
struct NVDResponse: Codable {
    let totalResults: Int
    let vulnerabilities: [VulnerabilityEntry]
}

struct VulnerabilityEntry: Codable {
    let cve: CVE
    
    struct CVE: Codable {
        let id: String
        let descriptions: [Description]
        let published: String?
        let lastModified: String?
        let metrics: Metrics?
        
        struct Description: Codable {
            let lang: String
            let value: String
        }
        
        struct Metrics: Codable {
            let cvssMetricV31: [CVSSMetric]?
            let cvssMetricV30: [CVSSMetric]?
            let cvssMetricV2: [CVSSMetric]?
        }
        
        struct CVSSMetric: Codable {
            let cvssData: CVSSData
            let baseSeverity: String?
            
            struct CVSSData: Codable {
                let baseScore: Double
                let baseSeverity: String?
            }
        }
    }
    
    // Helper computed properties for easier access
    var baseScore: Double? {
        // Try CVSS 3.1 first, then 3.0, then 2.0
        if let v31 = cve.metrics?.cvssMetricV31?.first {
            return v31.cvssData.baseScore
        } else if let v30 = cve.metrics?.cvssMetricV30?.first {
            return v30.cvssData.baseScore
        } else if let v2 = cve.metrics?.cvssMetricV2?.first {
            return v2.cvssData.baseScore
        }
        return nil
    }
    
    var severity: String? {
        // Try CVSS 3.1 first, then 3.0, then 2.0
        if let v31 = cve.metrics?.cvssMetricV31?.first {
            return v31.cvssData.baseSeverity ?? v31.baseSeverity
        } else if let v30 = cve.metrics?.cvssMetricV30?.first {
            return v30.cvssData.baseSeverity ?? v30.baseSeverity
        } else if let v2 = cve.metrics?.cvssMetricV2?.first {
            return v2.baseSeverity
        }
        return nil
    }
    
    var publishedDate: Date? {
        guard let published = cve.published else { return nil }
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: published)
    }
    
    var englishDescription: String? {
        return cve.descriptions.first { $0.lang == "en" }?.value
    }
}

