//
//  CVEFetcher.swift
//  Intuneomator
//
//  Created by Gil Burns on 5/24/25.
//

import Foundation

class CVEFetcher {
    private let session: URLSession
    private let baseURL = "https://services.nvd.nist.gov/rest/json/cves/2.0"
    private let cpeBaseURL = "https://services.nvd.nist.gov/rest/json/cpes/2.0"
    private let apiKey: String?
    
    init(session: URLSession = .shared, apiKey: String? = nil) {
        self.session = session
        self.apiKey = apiKey
    }
    
    /// Main method to fetch CVEs
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
        
        print("🔍 [CVEFetcher] Starting request to:", url.absoluteString)
        
        let task = session.dataTask(with: req) { data, resp, err in
            self.handleCVEResponse(data: data, response: resp, error: err, completion: completion)
        }
        
        task.resume()
    }
    
    /// Search for multiple CPEs and fetch CVEs for all of them
    private func searchMultipleCPEsAndFetchCVEs(
        applicationName: String,
        daysBack: Int?,
        maxResults: Int?,
        completion: @escaping (Result<[VulnerabilityEntry], Error>) -> Void
    ) {
        print("🔍 [CVEFetcher] Searching for multiple CPEs for: \(applicationName)")
        
        // Get multiple CPE names for the app
        searchMultipleCPEs(for: applicationName) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let cpeNames):
                if cpeNames.isEmpty {
                    print("❌ [CVEFetcher] No CPE names found for \(applicationName)")
                    completion(.success([]))
                    return
                }
                
                print("📋 [CVEFetcher] Found \(cpeNames.count) CPE names for \(applicationName)")
                
                // Fetch CVEs for all CPE names
                self.fetchCVEsForMultipleCPEs(cpeNames, daysBack: daysBack, maxResults: maxResults, completion: completion)
                
            case .failure(let error):
                print("❌ [CVEFetcher] Failed to search CPEs: \(error)")
                completion(.failure(error))
            }
        }
    }
    
    /// Search CPE dictionary for multiple relevant CPEs
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
        
        print("🔍 [CVEFetcher] Searching CPE dictionary for: \(applicationName)")
        
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
                
                print("📋 [CVEFetcher] Found \(limitedCPEs.count) matching CPEs:")
                for (index, cpeName) in limitedCPEs.enumerated() {
                    print("  \(index + 1). \(cpeName)")
                }
                
                completion(.success(limitedCPEs))
            } catch {
                completion(.failure(error))
            }
        }
        
        task.resume()
    }
    
    /// Fetch CVEs for multiple CPE names and deduplicate
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
        
        print("🔍 [CVEFetcher] Fetching CVEs for \(cpeNames.count) CPE names...")
        
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
                        print("✅ [CVEFetcher] Found \(cves.count) CVEs for CPE: \(cpeName)")
                    case .failure(let error):
                        errors.append(error)
                        print("❌ [CVEFetcher] Failed for CPE \(cpeName): \(error)")
                    }
                    lock.unlock()
                    group.leave()
                }
            }
        }
        
        group.notify(queue: .global()) {
            print("🔄 [CVEFetcher] Processing \(allCVEs.count) total CVEs...")
            
            if allCVEs.isEmpty {
                if !errors.isEmpty {
                    print("❌ [CVEFetcher] All requests failed")
                    completion(.failure(errors.first!))
                } else {
                    print("📭 [CVEFetcher] No CVEs found")
                    completion(.success([]))
                }
                return
            }
            
            // Deduplicate by CVE ID and keep most recent
            print("🔄 [CVEFetcher] Deduplicating CVEs...")
            let deduplicatedCVEs = self.deduplicateCVEs(allCVEs)
            print("🔄 [CVEFetcher] After deduplication: \(deduplicatedCVEs.count) unique CVEs")
            
            // Sort by published date (newest first)
            print("🔄 [CVEFetcher] Sorting CVEs by date...")
            let sortedCVEs = deduplicatedCVEs.sorted { cve1, cve2 in
                guard let date1 = cve1.publishedDate, let date2 = cve2.publishedDate else {
                    return cve1.publishedDate != nil
                }
                return date1 > date2
            }
            
            // Take the most recent ones
            let finalResults = Array(sortedCVEs.prefix(maxResults ?? 5))
            
            print("✅ [CVEFetcher] Final results: \(finalResults.count) unique CVEs (from \(allCVEs.count) total)")
            print("🎯 [CVEFetcher] Calling completion handler...")
            
            completion(.success(finalResults))
        }
    }
    
    /// Fetch CVEs for a specific CPE name directly
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
        
        print("🔍 [CVEFetcher] Starting request for CPE \(cpeName) to:", url.absoluteString)
        
        let task = session.dataTask(with: req) { data, resp, err in
            self.handleCVEResponse(data: data, response: resp, error: err, completion: completion)
        }
        
        task.resume()
    }
    
    /// Deduplicate CVEs by ID, keeping the most recently published
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
    
    /// Handle CVE API response (shared by all fetch methods)
    private func handleCVEResponse(
        data: Data?,
        response: URLResponse?,
        error: Error?,
        completion: @escaping (Result<[VulnerabilityEntry], Error>) -> Void
    ) {
        if let error = error {
            print("❌ [CVEFetcher] Network error:", error)
            return completion(.failure(CVEFetcherError.networkError(error)))
        }

        guard let http = response as? HTTPURLResponse else {
            return completion(.failure(CVEFetcherError.httpError(-1)))
        }

        guard (200..<300).contains(http.statusCode) else {
            print("❌ [CVEFetcher] HTTP Error:", http.statusCode)
            return completion(.failure(CVEFetcherError.httpError(http.statusCode)))
        }

        guard let data = data else {
            if http.statusCode == 200 {
                print("📭 [CVEFetcher] No CVEs found for the given query.")
                return completion(.success([])) // Valid empty response
            } else {
                print("❌ [CVEFetcher] Unexpected empty response.")
                return completion(.failure(CVEFetcherError.emptyResponse)) // Unexpected empty response
            }
        }
        
        do {
            let apiResp = try JSONDecoder().decode(NVDResponse.self, from: data)
            completion(.success(apiResp.vulnerabilities))
        } catch {
            print("❌ [CVEFetcher] Decode error:", error)
            completion(.failure(CVEFetcherError.decodeError(error)))
        }
    }
    
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
    
    /// Main convenience method
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
    
    /// Simple method - keyword search
    func fetchCVEsSimple(
        for applicationName: String,
        daysBack: Int? = 60,
        maxResults: Int? = 5,
        completion: @escaping (Result<[VulnerabilityEntry], Error>) -> Void
    ) {
        print("🔍 [CVEFetcher] Using simple keyword search for: \(applicationName)")
        
        fetchCVEs(
            product: applicationName,
            version: nil,
            filter: .keyword,
            daysBack: daysBack,
            maxResults: maxResults,
            completion: completion
        )
    }
    
    /// Quick method for checking recent CVEs
    func checkRecentCVEs(
        for applicationName: String,
        completion: @escaping (Result<[VulnerabilityEntry], Error>) -> Void
    ) {
        fetchCVEsForApplication(applicationName, daysBack: 30, maxResults: 3, completion: completion)
    }
}

