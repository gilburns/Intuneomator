//
//  CVEFetcher.swift
//  Intuneomator
//
//  Created by Gil Burns on 5/24/25.
//

import Foundation

/// Fetches Common Vulnerabilities and Exposures (CVE) data from the NIST National Vulnerability Database
/// Supports multiple search methods including CPE-based searches, keyword searches, and multi-CPE lookups
class CVEFetcher {
    /// URL session for making network requests
    private let session: URLSession
    
    /// Base URL for the NIST CVE API
    private let baseURL = "https://services.nvd.nist.gov/rest/json/cves/2.0"
    
    /// Base URL for the NIST CPE API
    private let cpeBaseURL = "https://services.nvd.nist.gov/rest/json/cpes/2.0"
    
    /// Optional API key for enhanced rate limits
    private let apiKey: String?
    
    /// Log type identifier for logging operations
    let logType = "CVE"
    
    /// Initializes a CVE fetcher with optional API key for enhanced rate limits
    /// - Parameters:
    ///   - session: URL session to use for requests (defaults to shared session)
    ///   - apiKey: Optional NIST API key for higher rate limits
    init(session: URLSession = .shared, apiKey: String? = nil) {
        self.session = session
        self.apiKey = apiKey
    }
    
    /// Main method to fetch CVEs using various search strategies
    /// - Parameters:
    ///   - product: Product name to search for
    ///   - version: Optional specific version to search for
    ///   - filter: Search filter strategy (application, OS, keyword, or multi-CPE)
    ///   - daysBack: Number of days back to search (default 60)
    ///   - maxResults: Maximum number of results to return (default 5)
    ///   - completion: Callback with array of vulnerability entries or error
    func fetchCVEs(
        product: String,
        version: String? = nil,
        filter: CVEFilter,
        daysBack: Int? = 60, // Default to 60 days
        maxResults: Int? = 5, // Default to 5
        completion: @escaping (Result<[VulnerabilityEntry], Error>) -> Void
    ) {
        // Handle multi-CPE search separately (main use case)
        if case .multiCPE(let applicationName) = filter {
            searchMultipleCPEsAndFetchCVEs(
                applicationName: applicationName,
                daysBack: daysBack,
                maxResults: maxResults,
                completion: completion
            )
            return
        }
        
        // Build URL for single CPE searches
        var comps = URLComponents(string: baseURL)!
        var queryItems: [URLQueryItem] = []
        
        switch filter {
        case .application(let vendor, let prod):
            let cpe = "cpe:2.3:a:\(vendor):\(prod):*:*:*:*:*:*:*:*"
            queryItems.append(URLQueryItem(name: "cpeName", value: cpe))
        case .operatingSystem(let vendor, let os):
            let cpe = "cpe:2.3:o:\(vendor):\(os):\(version ?? "*"):*:*:*:*:*:*:*"
            queryItems.append(URLQueryItem(name: "cpeName", value: cpe))
        case .keyword:
            let kw = version != nil ? "\(product) \(version!)" : product
            queryItems.append(URLQueryItem(name: "keywordSearch", value: kw))
        case .multiCPE:
            // Handled above
            break
        }
        
        // Add date filtering
        if let daysBack = daysBack {
            let endDate = Date()
            let startDate = Calendar.current.date(byAdding: .day, value: -daysBack, to: endDate)!
            
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            
            queryItems.append(URLQueryItem(name: "pubStartDate", value: formatter.string(from: startDate)))
            queryItems.append(URLQueryItem(name: "pubEndDate", value: formatter.string(from: endDate)))
        }
        
        // Set results per page
        if let maxResults = maxResults {
            queryItems.append(URLQueryItem(name: "resultsPerPage", value: "\(min(maxResults, 100))"))
        }
        
        comps.queryItems = queryItems
        
        guard let url = comps.url else {
            return completion(.failure(CVEFetcherError.invalidURL))
        }

        var req = URLRequest(url: url)
        req.setValue("application/json", forHTTPHeaderField: "Accept")

        // Add API key in header
        if let apiKey = apiKey {
            req.setValue(apiKey, forHTTPHeaderField: "apiKey")
        }
        
        Logger.log("🔍 [CVEFetcher] Starting request to: \(url.absoluteString)", logType: logType)
        
        let task = session.dataTask(with: req) { data, resp, err in
            self.handleCVEResponse(data: data, response: resp, error: err, completion: completion)
        }
        
        task.resume()
    }
    
    /// Searches for multiple Common Platform Enumeration (CPE) identifiers and fetches CVEs for all matches
    /// This provides more comprehensive vulnerability coverage than single CPE searches
    /// - Parameters:
    ///   - applicationName: Name of the application to search CPEs for
    ///   - daysBack: Number of days back to search for vulnerabilities
    ///   - maxResults: Maximum number of results to return
    ///   - completion: Callback with consolidated vulnerability results
    private func searchMultipleCPEsAndFetchCVEs(
        applicationName: String,
        daysBack: Int?,
        maxResults: Int?,
        completion: @escaping (Result<[VulnerabilityEntry], Error>) -> Void
    ) {
        Logger.log("🔍 [CVEFetcher] Searching for multiple CPEs for: \(applicationName)", logType: logType)
        
        // Get multiple CPE names for the app
        searchMultipleCPEs(for: applicationName) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let cpeNames):
                if cpeNames.isEmpty {
                    Logger.log("❌ [CVEFetcher] No CPE names found for \(applicationName)", logType: logType)
                    completion(.success([]))
                    return
                }
                
                Logger.log("📋 [CVEFetcher] Found \(cpeNames.count) CPE names for \(applicationName)", logType: logType)
                
                // Fetch CVEs for all CPE names
                self.fetchCVEsForMultipleCPEs(cpeNames, daysBack: daysBack, maxResults: maxResults, completion: completion)
                
            case .failure(let error):
                Logger.log("❌ [CVEFetcher] Failed to search CPEs: \(error)", logType: logType)
                completion(.failure(error))
            }
        }
    }
    
    /// Searches the NIST CPE dictionary for multiple relevant CPE identifiers
    /// Returns up to 3 CPEs: a wildcard version and 2 most recent specific versions
    /// - Parameters:
    ///   - applicationName: Name of the application to find CPEs for
    ///   - completion: Callback with array of CPE identifier strings
    func searchMultipleCPEs(
        for applicationName: String,
        completion: @escaping (Result<[String], Error>) -> Void
    ) {
        var comps = URLComponents(string: cpeBaseURL)!
        comps.queryItems = [
            URLQueryItem(name: "keywordSearch", value: applicationName),
            URLQueryItem(name: "resultsPerPage", value: "100") // Get more results to filter
        ]
        
        guard let url = comps.url else {
            completion(.failure(NSError(domain: "CVEFetcher", code: 0,
                                        userInfo: [NSLocalizedDescriptionKey: "Invalid CPE search URL"])))
            return
        }
        
        var req = URLRequest(url: url)
        req.setValue("application/json", forHTTPHeaderField: "Accept")

        // Add API key in headers
        if let apiKey = apiKey {
            req.setValue(apiKey, forHTTPHeaderField: "apiKey")
        }
        
        Logger.log("🔍 [CVEFetcher] Searching CPE dictionary for: \(applicationName)", logType: logType)
        
        let task = session.dataTask(with: req) { data, resp, err in
            if let err = err {
                return completion(.failure(err))
            }
            
            guard let http = resp as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode) else {
                return completion(.failure(NSError(domain: "CVEFetcher", code: 1,
                                                   userInfo: [NSLocalizedDescriptionKey: "CPE search failed"])))
            }
            
            guard let data = data else {
                return completion(.success([]))
            }
            
            do {
                let cpeResp = try JSONDecoder().decode(CPEResponse.self, from: data)
                
                // Filter for applications with exact product name match
                let matchingCPEs = cpeResp.products.filter { product in
                    let cpe = product.cpe.cpeName
                    
                    // Must be application CPE
                    guard cpe.starts(with: "cpe:2.3:a:") else { return false }
                    
                    let components = cpe.split(separator: ":")
                    guard components.count > 4 else { return false }
                    
                    let productName = String(components[4])
                    
                    // case-insensitive match
                    return productName.lowercased() == applicationName.lowercased()
                }
                
                // Sort by created date - newest first
                let sortedCPEs = matchingCPEs.sorted { cpe1, cpe2 in
                    let formatter = ISO8601DateFormatter()
                    let date1 = formatter.date(from: cpe1.cpe.created) ?? Date.distantPast
                    let date2 = formatter.date(from: cpe2.cpe.created) ?? Date.distantPast
                    return date1 > date2
                }
                
                // Take the 3 most useful CPEs: wildcard + 2 most recent versions
                let recentCPEs = Array(sortedCPEs.prefix(2)) // Only 2 specific versions
                var cpeNames = recentCPEs.map { $0.cpe.cpeName }
                
                // Add a wildcard CPE for broader coverage
                if let firstCPE = recentCPEs.first {
                    let components = firstCPE.cpe.cpeName.split(separator: ":")
                    if components.count > 4 {
                        let vendor = components[3]
                        let product = components[4]
                        let wildcardCPE = "cpe:2.3:a:\(vendor):\(product):*:*:*:*:*:*:*:*"
                        
                        // Add wildcard CPE at the beginning for priority
                        cpeNames.insert(wildcardCPE, at: 0)
                    }
                }
                
                // Limit to max 3 CPEs to speed things up
                let limitedCPEs = Array(cpeNames.prefix(3))
                
                Logger.log("📋 [CVEFetcher] Found \(limitedCPEs.count) matching CPEs:", logType: self.logType)
                for (index, cpeName) in limitedCPEs.enumerated() {
                    Logger.log("  \(index + 1). \(cpeName)", logType: self.logType)
                }
                
                completion(.success(limitedCPEs))
            } catch {
                completion(.failure(error))
            }
        }
        
        task.resume()
    }
    
    /// Fetches CVEs for multiple CPE identifiers concurrently and deduplicates results
    /// Uses rate limiting to avoid overwhelming the NIST API
    /// - Parameters:
    ///   - cpeNames: Array of CPE identifier strings to search
    ///   - daysBack: Number of days back to search for vulnerabilities
    ///   - maxResults: Maximum number of final results to return
    ///   - completion: Callback with deduplicated vulnerability results
    private func fetchCVEsForMultipleCPEs(
        _ cpeNames: [String],
        daysBack: Int?,
        maxResults: Int?,
        completion: @escaping (Result<[VulnerabilityEntry], Error>) -> Void
    ) {
        let group = DispatchGroup()
        var allCVEs: [VulnerabilityEntry] = []
        var errors: [Error] = []
        let lock = NSLock()
        
        Logger.log("🔍 [CVEFetcher] Fetching CVEs for \(cpeNames.count) CPE names...", logType: logType)
        
        for (index, cpeName) in cpeNames.enumerated() {
            group.enter()
            
            // Add delay between requests to avoid rate limiting
            DispatchQueue.global().asyncAfter(deadline: .now() + Double(index) * 0.5) {
                self.fetchCVEsForSpecificCPE(
                    cpeName: cpeName,
                    daysBack: daysBack,
                    maxResults: 50
                ) { result in
                    lock.lock()
                    switch result {
                    case .success(let cves):
                        allCVEs.append(contentsOf: cves)
                        Logger.log("✅ [CVEFetcher] Found \(cves.count) CVEs for CPE: \(cpeName)", logType: self.logType)
                    case .failure(let error):
                        errors.append(error)
                        Logger.log("❌ [CVEFetcher] Failed for CPE \(cpeName): \(error)", logType: self.logType)
                    }
                    lock.unlock()
                    group.leave()
                }
            }
        }
        
        group.notify(queue: .global()) {
            Logger.log("🔄 [CVEFetcher] Processing \(allCVEs.count) total CVEs...", logType: self.logType)
            
            if allCVEs.isEmpty {
                if !errors.isEmpty {
                    Logger.log("❌ [CVEFetcher] All requests failed", logType: self.logType)
                    completion(.failure(errors.first!))
                } else {
                    Logger.log("📭 [CVEFetcher] No CVEs found", logType: self.logType)
                    completion(.success([]))
                }
                return
            }
            
            // Deduplicate by CVE ID and keep most recent
            Logger.log("🔄 [CVEFetcher] Deduplicating CVEs...", logType: self.logType)
            let deduplicatedCVEs = self.deduplicateCVEs(allCVEs)
            Logger.log("🔄 [CVEFetcher] After deduplication: \(deduplicatedCVEs.count) unique CVEs", logType: self.logType)
            
            // Sort by published date (newest first)
            Logger.log("🔄 [CVEFetcher] Sorting CVEs by date...", logType: self.logType)
            let sortedCVEs = deduplicatedCVEs.sorted { cve1, cve2 in
                guard let date1 = cve1.publishedDate, let date2 = cve2.publishedDate else {
                    return cve1.publishedDate != nil
                }
                return date1 > date2
            }
            
            // Take the most recent ones
            let finalResults = Array(sortedCVEs.prefix(maxResults ?? 5))
            
            Logger.log("✅ [CVEFetcher] Final results: \(finalResults.count) unique CVEs (from \(allCVEs.count) total)", logType: self.logType)
            Logger.log("🎯 [CVEFetcher] Calling completion handler...", logType: self.logType)
            
            completion(.success(finalResults))
        }
    }
    
    /// Fetches CVEs for a single specific CPE identifier
    /// - Parameters:
    ///   - cpeName: Specific CPE identifier string to search
    ///   - daysBack: Number of days back to search for vulnerabilities
    ///   - maxResults: Maximum number of results to return
    ///   - completion: Callback with vulnerability results for this CPE
    private func fetchCVEsForSpecificCPE(
        cpeName: String,
        daysBack: Int?,
        maxResults: Int?,
        completion: @escaping (Result<[VulnerabilityEntry], Error>) -> Void
    ) {
        var comps = URLComponents(string: baseURL)!
        var queryItems: [URLQueryItem] = []
        
        // Use the exact CPE name
        queryItems.append(URLQueryItem(name: "cpeName", value: cpeName))
        
        // Add date filtering
        if let daysBack = daysBack {
            let endDate = Date()
            let startDate = Calendar.current.date(byAdding: .day, value: -daysBack, to: endDate)!
            
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            
            queryItems.append(URLQueryItem(name: "pubStartDate", value: formatter.string(from: startDate)))
            queryItems.append(URLQueryItem(name: "pubEndDate", value: formatter.string(from: endDate)))
        }
        
        // Set results per page
        if let maxResults = maxResults {
            queryItems.append(URLQueryItem(name: "resultsPerPage", value: "\(min(maxResults, 100))"))
        }
        
        comps.queryItems = queryItems
        
        guard let url = comps.url else {
            return completion(.failure(CVEFetcherError.invalidURL))
        }
        
        var req = URLRequest(url: url)
        req.setValue("application/json", forHTTPHeaderField: "Accept")

        // Add API key in headers
        if let apiKey = apiKey {
            req.setValue(apiKey, forHTTPHeaderField: "apiKey")
        }
        
        Logger.log("🔍 [CVEFetcher] Starting request for CPE \(cpeName) to: \(url.absoluteString)", logType: logType)
        
        let task = session.dataTask(with: req) { data, resp, err in
            self.handleCVEResponse(data: data, response: resp, error: err, completion: completion)
        }
        
        task.resume()
    }
    
    /// Removes duplicate CVE entries by ID, keeping the most recently published version
    /// - Parameter cves: Array of vulnerability entries that may contain duplicates
    /// - Returns: Array of unique vulnerability entries
    private func deduplicateCVEs(_ cves: [VulnerabilityEntry]) -> [VulnerabilityEntry] {
        var uniqueCVEs: [String: VulnerabilityEntry] = [:]
        
        for cve in cves {
            let cveId = cve.cve.id
            
            if let existing = uniqueCVEs[cveId] {
                // Keep the one with the more recent published date, or just keep the first one if dates are problematic
                if let cveDate = cve.publishedDate,
                   let existingDate = existing.publishedDate {
                    if cveDate > existingDate {
                        uniqueCVEs[cveId] = cve
                    }
                    // Otherwise keep existing
                } else if cve.publishedDate != nil && existing.publishedDate == nil {
                    // Prefer CVE with valid date
                    uniqueCVEs[cveId] = cve
                }
                // Otherwise keep existing (first one wins)
            } else {
                uniqueCVEs[cveId] = cve
            }
        }
        
        return Array(uniqueCVEs.values)
    }
    
    /// Processes API responses from NIST CVE endpoints with error handling
    /// - Parameters:
    ///   - data: Response data from the API
    ///   - response: HTTP response object
    ///   - error: Network error if any occurred
    ///   - completion: Callback with parsed vulnerability results or error
    private func handleCVEResponse(
        data: Data?,
        response: URLResponse?,
        error: Error?,
        completion: @escaping (Result<[VulnerabilityEntry], Error>) -> Void
    ) {
        if let error = error {
            Logger.log("❌ [CVEFetcher] Network error: \(error)", logType: logType)
            return completion(.failure(CVEFetcherError.networkError(error)))
        }

        guard let http = response as? HTTPURLResponse else {
            return completion(.failure(CVEFetcherError.httpError(-1)))
        }

        guard (200..<300).contains(http.statusCode) else {
            Logger.log("❌ [CVEFetcher] HTTP Error: \(http.statusCode)", logType: logType)
            return completion(.failure(CVEFetcherError.httpError(http.statusCode)))
        }

        guard let data = data else {
            if http.statusCode == 200 {
                Logger.log("📭 [CVEFetcher] No CVEs found for the given query.", logType: logType)
                return completion(.success([])) // Valid empty response
            } else {
                Logger.log("❌ [CVEFetcher] Unexpected empty response.", logType: logType)
                return completion(.failure(CVEFetcherError.emptyResponse)) // Unexpected empty response
            }
        }
        
        do {
            let apiResp = try JSONDecoder().decode(NVDResponse.self, from: data)
            completion(.success(apiResp.vulnerabilities))
        } catch {
            Logger.log("❌ [CVEFetcher] Decode error: \(error)", logType: logType)
            completion(.failure(CVEFetcherError.decodeError(error)))
        }
    }
    
    /// Handles and logs CVE fetcher errors with descriptive messages
    /// - Parameter error: The CVE fetcher error to handle
    func handleError(_ error: CVEFetcherError) {
        switch error {
        case .invalidURL:
            print("❌ [CVEFetcher] Error: Invalid URL")
        case .networkError(let networkError):
            print("❌ [CVEFetcher] Network Error:", networkError.localizedDescription)
        case .httpError(let statusCode):
            print("❌ [CVEFetcher] HTTP Error with status code:", statusCode)
        case .emptyResponse:
            print("❌ [CVEFetcher] Error: Empty response from server")
        case .decodeError(let decodeError):
            print("❌ [CVEFetcher] Decode Error:", decodeError.localizedDescription)
        case .cpeSearchFailed(let message):
            print("❌ [CVEFetcher] CPE Search Failed:", message)
        }
    }
    
    /// Convenience method for fetching CVEs for an application using multi-CPE search
    /// This is the recommended method for comprehensive vulnerability discovery
    /// - Parameters:
    ///   - applicationName: Name of the application to search vulnerabilities for
    ///   - daysBack: Number of days back to search (default 90)
    ///   - maxResults: Maximum number of results to return (default 5)
    ///   - completion: Callback with vulnerability results
    func fetchCVEsForApplication(
        _ applicationName: String,
        daysBack: Int? = 90,
        maxResults: Int? = 5,
        completion: @escaping (Result<[VulnerabilityEntry], Error>) -> Void
    ) {
        fetchCVEs(
            product: applicationName,
            version: nil,
            filter: .multiCPE(applicationName: applicationName),
            daysBack: daysBack,
            maxResults: maxResults,
            completion: completion
        )
    }
    
    /// Simple keyword-based CVE search (faster but less comprehensive than CPE search)
    /// - Parameters:
    ///   - applicationName: Name of the application to search for
    ///   - daysBack: Number of days back to search (default 60)
    ///   - maxResults: Maximum number of results to return (default 5)
    ///   - completion: Callback with vulnerability results
    func fetchCVEsSimple(
        for applicationName: String,
        daysBack: Int? = 60,
        maxResults: Int? = 5,
        completion: @escaping (Result<[VulnerabilityEntry], Error>) -> Void
    ) {
        Logger.log("🔍 [CVEFetcher] Using simple keyword search for: \(applicationName)", logType: logType)
        
        fetchCVEs(
            product: applicationName,
            version: nil,
            filter: .keyword,
            daysBack: daysBack,
            maxResults: maxResults,
            completion: completion
        )
    }
    
    /// Quick check for recent CVEs in the last 30 days (limited to 3 results)
    /// - Parameters:
    ///   - applicationName: Name of the application to check
    ///   - completion: Callback with recent vulnerability results
    func checkRecentCVEs(
        for applicationName: String,
        completion: @escaping (Result<[VulnerabilityEntry], Error>) -> Void
    ) {
        fetchCVEsForApplication(applicationName, daysBack: 30, maxResults: 3, completion: completion)
    }
}

