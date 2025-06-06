//
//  Constants+CVEFetcher.swift
//  Intuneomator
//
//  Created by Gil Burns on 5/24/25.
//

import Foundation

// MARK: - CVE Fetcher Data Structures

/// Errors that can occur during CVE fetching operations
/// Used by CVEFetcher for National Vulnerability Database (NVD) API interactions
enum CVEFetcherError: Error {
    /// Invalid URL provided for API request
    case invalidURL
    
    /// Network communication error
    case networkError(Error)
    
    /// HTTP error with status code
    case httpError(Int)
    
    /// Empty response received from API
    case emptyResponse
    
    /// JSON decoding error
    case decodeError(Error)
    
    /// CPE (Common Platform Enumeration) search failed with context
    case cpeSearchFailed(String)
}

/// Search filter types for CVE queries
/// Defines different ways to scope vulnerability searches
enum CVEFilter {
    /// Search for application vulnerabilities by vendor and product
    case application(vendor: String, product: String)
    
    /// Search for operating system vulnerabilities by vendor and product
    case operatingSystem(vendor: String, product: String)
    
    /// Generic keyword-based search
    case keyword
    
    /// Multi-CPE search using application name
    case multiCPE(applicationName: String)
}

// MARK: - CPE (Common Platform Enumeration) Response Structures

/// Response structure for CPE search queries
/// Used to identify software/hardware platforms before CVE searches
struct CPEResponse: Codable {
    /// Total number of CPE entries found
    let totalResults: Int
    
    /// Array of CPE product entries
    let products: [CPEProduct]
}

/// Individual CPE product entry
struct CPEProduct: Codable {
    /// CPE details container
    let cpe: CPEDetails
    
    /// Detailed CPE information
    struct CPEDetails: Codable {
        /// Full CPE name (e.g., "cpe:2.3:a:vendor:product:version")
        let cpeName: String
        
        /// Creation timestamp
        let created: String
        
        /// Localized titles for the product
        let titles: [CPETitle]
        
        /// Individual title entry with language
        struct CPETitle: Codable {
            /// Product title/name
            let title: String
            
            /// Language code (e.g., "en")
            let lang: String
        }
    }
}

// MARK: - NVD CVE Response Structures

/// Main response structure from NVD v2.0 CVE API
/// Contains vulnerability information for security analysis
struct NVDResponse: Codable {
    /// Total number of vulnerabilities found
    let totalResults: Int
    
    /// Array of vulnerability entries
    let vulnerabilities: [VulnerabilityEntry]
}

/// Individual vulnerability entry containing CVE details
struct VulnerabilityEntry: Codable {
    /// Core CVE information
    let cve: CVE
    
    /// Common Vulnerabilities and Exposures entry
    struct CVE: Codable {
        /// CVE identifier (e.g., "CVE-2023-1234")
        let id: String
        
        /// Vulnerability descriptions in multiple languages
        let descriptions: [Description]
        
        /// Publication date in ISO 8601 format
        let published: String?
        
        /// Last modification date in ISO 8601 format
        let lastModified: String?
        
        /// CVSS scoring metrics
        let metrics: Metrics?
        
        /// Vulnerability description entry
        struct Description: Codable {
            /// Language code
            let lang: String
            
            /// Description text
            let value: String
        }
        
        /// Container for different CVSS versions
        struct Metrics: Codable {
            /// CVSS v3.1 metrics (preferred)
            let cvssMetricV31: [CVSSMetric]?
            
            /// CVSS v3.0 metrics
            let cvssMetricV30: [CVSSMetric]?
            
            /// CVSS v2.0 metrics (legacy)
            let cvssMetricV2: [CVSSMetric]?
        }
        
        /// CVSS scoring metric for a specific version
        struct CVSSMetric: Codable {
            /// Core CVSS data
            let cvssData: CVSSData
            
            /// Base severity rating
            let baseSeverity: String?
            
            /// CVSS scoring data
            struct CVSSData: Codable {
                /// Numeric score (0.0-10.0)
                let baseScore: Double
                
                /// Severity rating (LOW, MEDIUM, HIGH, CRITICAL)
                let baseSeverity: String?
            }
        }
    }
    
    // MARK: - Computed Properties
    
    /// Base CVSS score with version preference (3.1 > 3.0 > 2.0)
    var baseScore: Double? {
        if let v31 = cve.metrics?.cvssMetricV31?.first {
            return v31.cvssData.baseScore
        } else if let v30 = cve.metrics?.cvssMetricV30?.first {
            return v30.cvssData.baseScore
        } else if let v2 = cve.metrics?.cvssMetricV2?.first {
            return v2.cvssData.baseScore
        }
        return nil
    }
    
    /// Severity rating with version preference (3.1 > 3.0 > 2.0)
    var severity: String? {
        if let v31 = cve.metrics?.cvssMetricV31?.first {
            return v31.cvssData.baseSeverity ?? v31.baseSeverity
        } else if let v30 = cve.metrics?.cvssMetricV30?.first {
            return v30.cvssData.baseSeverity ?? v30.baseSeverity
        } else if let v2 = cve.metrics?.cvssMetricV2?.first {
            return v2.baseSeverity
        }
        return nil
    }
    
    /// Publication date as Swift Date object
    var publishedDate: Date? {
        guard let published = cve.published else { return nil }
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: published)
    }
    
    /// English language description of the vulnerability
    var englishDescription: String? {
        return cve.descriptions.first { $0.lang == "en" }?.value
    }
}

