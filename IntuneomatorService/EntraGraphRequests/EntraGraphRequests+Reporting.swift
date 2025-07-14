//
//  EntraGraphRequests+AppsReporting.swift
//  Intuneomator
//
//  Created by Gil Burns on 7/11/25.
//

import Foundation

extension EntraGraphRequests {
    // MARK: - Fetch All Apps
    
    /// Searches for macOS apps in Intune of the types: macOSDmgApp, macOSPkgApp, macOSLobApp
    /// - Parameters:
    ///   - authToken: Valid access token for Microsoft Graph API
    ///   - trackingID: Unique tracking identifier to search for in app notes
    /// - Returns: Array of apps matching the types
    /// - Throws: GraphAPIError for various request and processing failures
    static func fetchIntuneApps(authToken: String) async throws -> [[String: Any]] {
        var allIntuneApps: [[String: Any]] = []
        
        // Construct the initial URL
        let baseURL = "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps"
        let filter = "(isof('microsoft.graph.macOSDmgApp') or isof('microsoft.graph.macOSPkgApp') or isof('microsoft.graph.macOSLobApp'))"
        let select = "displayName,isAssigned,id,createdDateTime,lastModifiedDateTime,notes"
//        let initialURL = "\(baseURL)?$filter=\(filter)&$select=\(select)"
        let initialURL = "\(baseURL)?$select=\(select)"
        var nextPageUrl: String? = initialURL
        var pageCount = 0
        
        Logger.info("Starting paginated fetch of Intune Apps...", category: .core)
        
        // Follow pagination until all Intune apps are fetched
        while let urlString = nextPageUrl {
            Logger.info("Fetching Intune apps from URL: \(urlString)", category: .core)
            
            guard let url = URL(string: urlString) else {
                throw NSError(domain: "EntraGraphRequests.AppsReporting", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid pagination URL: \(urlString)"])
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                let responseString = String(data: data, encoding: .utf8) ?? "No response data"
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                Logger.error("HTTP \(statusCode) error fetching Intune apps (page \(pageCount + 1)): \(responseString)", category: .core)
                throw NSError(domain: "EntraGraphRequests.AppsReporting", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch Intune app data (page \(pageCount + 1)): HTTP \(statusCode) - \(responseString)"])
            }
            
            // Parse JSON response
            guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
                throw NSError(domain: "EntraGraphRequests.AppsReporting", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON response format for Intune app data (page \(pageCount + 1))"])
            }
            
            // Extract Intune apps from this page
            guard let pageIntuneApps = json["value"] as? [[String: Any]] else {
                throw NSError(domain: "EntraGraphRequests.AppsReporting", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid response format for Intune app data (page \(pageCount + 1))"])
            }
            
            allIntuneApps.append(contentsOf: pageIntuneApps)
            pageCount += 1
            
            // Check for next page
            nextPageUrl = json["@odata.nextLink"] as? String
            
            Logger.info("Fetched page \(pageCount) with \(pageIntuneApps.count) Intune apps (total: \(allIntuneApps.count))", category: .core)
            
            // Safety check to prevent infinite loops
            if pageCount > 100 {
                Logger.error("Safety limit reached: stopping after 100 pages of Intune apps", category: .core)
                break
            }
        }
        
        Logger.info("Completed fetching \(allIntuneApps.count) total Intune apps across \(pageCount) pages", category: .core)
        
        // Sort all Intune apps alphabetically by display name
        return allIntuneApps.sorted {
            guard let name1 = $0["displayName"] as? String, let name2 = $1["displayName"] as? String else { return false }
            return name1.localizedCaseInsensitiveCompare(name2) == .orderedAscending
        }
    }

    // MARK: - Device App Installation Status Reports
    
    /// Retrieves device app installation status report for a specific app from Microsoft Graph reports endpoint
    /// Posts to the reports API and handles pagination to get detailed installation status across all devices where the app is assigned
    /// - Parameters:
    ///   - authToken: Valid access token for Microsoft Graph API
    ///   - appId: Unique identifier (GUID) of the app to get installation status for
    /// - Returns: Array of device installation status dictionaries containing device and installation details
    /// - Throws: Network errors, authentication errors, or JSON parsing errors
    static func getDeviceAppInstallationStatusReport(authToken: String, appId: String) async throws -> [[String: Any]] {
        Logger.info("Fetching device app installation status report for app: \(appId)", category: .core)
        
        var allDeviceInstallationData: [[String: Any]] = []
        var pageCount = 0
        var skipToken: String? = nil
        
        // Initial request payload
        var requestBody: [String: Any] = [
            "filter": "(ApplicationId eq '\(appId)')"
//            "select": [
//                "DeviceId",
//                "DeviceName", 
//                "UserId",
//                "UserPrincipalName",
//                "UserName",
//                "InstallState",
//                "InstallStateDetail",
//                "AppVersion",
//                "AppInstallState",
//                "AppInstallStateDetails",
//                "AppVersion",
//                "ErrorCode",
//                "HexErrorCode",
//                "LastModifiedDateTime"
//            ]
        ]
        
        // Follow pagination until all device installation data is fetched
        repeat {
            let urlString = "https://graph.microsoft.com/beta/deviceManagement/reports/microsoft.graph.retrieveDeviceAppInstallationStatusReport"
            
            guard let url = URL(string: urlString) else {
                throw NSError(domain: "EntraGraphRequests.AppsReporting", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid reports endpoint URL"])
            }
            
            // Add skip token for pagination if available
            if let skipToken = skipToken {
                requestBody["skip"] = skipToken
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            } catch {
                throw NSError(domain: "EntraGraphRequests.AppsReporting", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to serialize request body: \(error.localizedDescription)"])
            }
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NSError(domain: "EntraGraphRequests.AppsReporting", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid response type"])
            }
            
            guard httpResponse.statusCode == 200 else {
                let responseStr = String(data: data, encoding: .utf8) ?? "Unknown error"
                Logger.error("Failed to fetch device app installation status report for app \(appId) (page \(pageCount + 1)): \(responseStr)", category: .core)
                throw NSError(domain: "EntraGraphRequests.AppsReporting", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch device app installation status report (page \(pageCount + 1)). Status: \(httpResponse.statusCode), Response: \(responseStr)"])
            }
            
            guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
                throw NSError(domain: "EntraGraphRequests.AppsReporting", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON response format for device app installation status report (page \(pageCount + 1))"])
            }
            
            // The reports API typically returns data in a different format than regular Graph endpoints
            // Check for both "value" array (standard) and other possible response formats
            var pageDeviceInstallationData: [[String: Any]] = []
            
            if let reportData = json["value"] as? [[String: Any]] {
                pageDeviceInstallationData = reportData
            } else if let reportValues = json["Values"] as? [[String: Any]] {
                // Some reports endpoints use "Values" instead of "value"
                pageDeviceInstallationData = reportValues
            } else if let reportSchema = json["Schema"] as? [[String: Any]], 
                      let reportValues = json["Values"] as? [[Any]] {
                // Handle structured report format with schema and values arrays
                pageDeviceInstallationData = try parseStructuredReportData(schema: reportSchema, values: reportValues)
            } else {
                throw NSError(domain: "EntraGraphRequests.AppsReporting", code: 500, userInfo: [NSLocalizedDescriptionKey: "Unexpected response format for device app installation status report (page \(pageCount + 1))"])
            }
            
            allDeviceInstallationData.append(contentsOf: pageDeviceInstallationData)
            pageCount += 1
            
            // Check for pagination - reports API may use different pagination formats
            skipToken = nil
            if let nextLink = json["@odata.nextLink"] as? String,
               let urlComponents = URLComponents(string: nextLink),
               let skipValue = urlComponents.queryItems?.first(where: { $0.name == "$skip" })?.value {
                skipToken = skipValue
            } else if let odataSkip = json["@odata.skip"] as? String {
                skipToken = odataSkip
            } else if let hasMoreData = json["hasMoreData"] as? Bool, 
                      hasMoreData,
                      let totalRecords = json["totalRecords"] as? Int {
                // Some reports use hasMoreData flag and provide skip value
                let currentRecords = allDeviceInstallationData.count
                if currentRecords < totalRecords {
                    skipToken = String(currentRecords)
                }
            }
            
            Logger.info("Fetched page \(pageCount) with \(pageDeviceInstallationData.count) device installation records (total: \(allDeviceInstallationData.count))", category: .core)
            
            // Safety check to prevent infinite loops
            if pageCount > 100 {
                Logger.error("Safety limit reached: stopping after 100 pages of device app installation status", category: .core)
                break
            }
            
        } while skipToken != nil
        
        Logger.info("Successfully fetched \(allDeviceInstallationData.count) device installation records for app \(appId) across \(pageCount) pages", category: .core)
        
        // Sort by device name for consistent presentation
        return allDeviceInstallationData.sorted { record1, record2 in
            let deviceName1 = record1["DeviceName"] as? String ?? ""
            let deviceName2 = record2["DeviceName"] as? String ?? ""
            return deviceName1.localizedCaseInsensitiveCompare(deviceName2) == .orderedAscending
        }
    }
    
    /// Parses structured report data with separate schema and values arrays
    /// - Parameters:
    ///   - schema: Array of column definitions from the report
    ///   - values: Array of value arrays corresponding to the schema
    /// - Returns: Array of dictionaries mapping column names to values
    /// - Throws: Parsing errors if data structure is invalid
    private static func parseStructuredReportData(schema: [[String: Any]], values: [[Any]]) throws -> [[String: Any]] {
        // Extract column names from schema - try both "Name" and "Column" keys
        var columnNames: [String] = []
        for schemaItem in schema {
            if let name = schemaItem["Name"] as? String {
                columnNames.append(name)
            } else if let column = schemaItem["Column"] as? String {
                columnNames.append(column)
            }
        }
        
        guard !columnNames.isEmpty else {
            throw NSError(domain: "EntraGraphRequests.AppsReporting", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid schema format: no column names found"])
        }
        
        var parsedData: [[String: Any]] = []
        
        for valueRow in values {
            guard valueRow.count <= columnNames.count else {
                Logger.warning("Skipping row with too many values: expected \(columnNames.count), got \(valueRow.count)", category: .core)
                continue
            }
            
            var rowData: [String: Any] = [:]
            for (index, value) in valueRow.enumerated() {
                if index < columnNames.count {
                    rowData[columnNames[index]] = value
                }
            }
            parsedData.append(rowData)
        }
        
        return parsedData
    }


}
