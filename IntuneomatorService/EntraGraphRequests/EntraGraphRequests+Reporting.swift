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
        let select = "displayName,isAssigned,id,createdDateTime,lastModifiedDateTime,notes"
        let initialURL = "\(baseURL)?$select=\(select)"
        var nextPageUrl: String? = initialURL
        var pageCount = 0
        
        Logger.info("Starting paginated fetch of Intune Apps...", category: .reports)
        
        // Follow pagination until all Intune apps are fetched
        while let urlString = nextPageUrl {
            Logger.info("Fetching Intune apps from URL: \(urlString)", category: .reports)
            
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
                Logger.error("HTTP \(statusCode) error fetching Intune apps (page \(pageCount + 1)): \(responseString)", category: .reports)
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
            
            Logger.info("Fetched page \(pageCount) with \(pageIntuneApps.count) Intune apps (total: \(allIntuneApps.count))", category: .reports)
            
            // Safety check to prevent infinite loops
            if pageCount > 100 {
                Logger.error("Safety limit reached: stopping after 100 pages of Intune apps", category: .reports)
                break
            }
        }
        
        Logger.info("Completed fetching \(allIntuneApps.count) total Intune apps across \(pageCount) pages", category: .reports)
        
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
        Logger.info("Fetching device app installation status report for app: \(appId)", category: .reports)
        
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
                Logger.error("Failed to fetch device app installation status report for app \(appId) (page \(pageCount + 1)): \(responseStr)", category: .reports)
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
            
            Logger.info("Fetched page \(pageCount) with \(pageDeviceInstallationData.count) device installation records (total: \(allDeviceInstallationData.count))", category: .reports)
            
            // Safety check to prevent infinite loops
            if pageCount > 100 {
                Logger.error("Safety limit reached: stopping after 100 pages of device app installation status", category: .reports)
                break
            }
            
        } while skipToken != nil
        
        Logger.info("Successfully fetched \(allDeviceInstallationData.count) device installation records for app \(appId) across \(pageCount) pages", category: .reports)
        
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
                Logger.warning("Skipping row with too many values: expected \(columnNames.count), got \(valueRow.count)", category: .reports)
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
    
    // MARK: - Fetch All Configuration Profiles
    
    /// Fetches all configuration profiles from Intune across all platforms with assignment status
    /// - Parameters:
    ///   - authToken: Valid access token for Microsoft Graph API
    /// - Returns: Array of configuration profiles for all platforms, each containing an isAssigned boolean field
    /// - Throws: GraphAPIError for various request and processing failures
    static func fetchIntuneConfigurationProfiles(authToken: String) async throws -> [[String: Any]] {
        var allConfigurationProfiles: [[String: Any]] = []
        
        // Define multiple endpoints with their specific field requirements
        let endpoints = [
            (
                url: "https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations",
                select: "displayName,id,createdDateTime,lastModifiedDateTime,description,version",
                expand: "assignments"
            ),
            (
                url: "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies",
                select: "name,id,createdDateTime,lastModifiedDateTime,description,platforms,technologies",
                expand: "assignments"
            ),
            (
                url: "https://graph.microsoft.com/beta/deviceManagement/groupPolicyConfigurations",
                select: "displayName,id,createdDateTime,lastModifiedDateTime,description",
                expand: "assignments"
            )
            //            (
            //                url: "https://graph.microsoft.com/beta/deviceManagement/deviceCompliancePolicies",
            //                select: "displayName,id,createdDateTime,lastModifiedDateTime,description,version",
            //                expand: "assignments"
            //            ),
            //            (
            //                url: "https://graph.microsoft.com/beta/deviceManagement/windowsFeatureUpdateProfiles",
            //                select: "displayName,id,createdDateTime,lastModifiedDateTime,description",
            //                expand: "assignments"
            //            ),
            //            (
            //                url: "https://graph.microsoft.com/beta/deviceManagement/windowsQualityUpdateProfiles",
            //                select: "displayName,id,createdDateTime,lastModifiedDateTime,description",
            //                expand: "assignments"
            //            ),
            //            (
            //                url: "https://graph.microsoft.com/beta/deviceManagement/windowsQualityUpdatePolicies",
            //                select: "displayName,id,createdDateTime,lastModifiedDateTime,description",
            //                expand: "assignments"
            //            ),
            //            (
            //                url: "https://graph.microsoft.com/beta/deviceManagement/windowsDriverUpdateProfiles",
            //                select: "displayName,id,createdDateTime,lastModifiedDateTime,description",
            //                expand: "assignments"
            //            )
        ]
        
        Logger.info("Starting paginated fetch of Intune Configuration Profiles from multiple endpoints...", category: .reports)
        
        // Fetch from each endpoint
        for (endpointIndex, endpoint) in endpoints.enumerated() {
            Logger.info("Fetching from endpoint \(endpointIndex + 1)/\(endpoints.count): \(endpoint.url)", category: .reports)
            
            let initialURL = "\(endpoint.url)?$select=\(endpoint.select)&$expand=\(endpoint.expand)"
            var nextPageUrl: String? = initialURL
            var pageCount = 0
            
            // Follow pagination for this endpoint
            while let urlString = nextPageUrl {
                Logger.info("Fetching configuration profiles from URL: \(urlString)", category: .reports)
                
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
                    Logger.error("HTTP \(statusCode) error fetching configuration profiles from \(endpoint.url) (page \(pageCount + 1)): \(responseString)", category: .reports)
                    
                    // Continue to next endpoint instead of failing completely
                    Logger.warning("Skipping endpoint \(endpoint.url) due to error, continuing with other endpoints", category: .reports)
                    break
                }
                
                // Parse JSON response
                guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
                    Logger.error("Invalid JSON response format for configuration profile data from \(endpoint.url) (page \(pageCount + 1))", category: .reports)
                    break
                }
                
                // Extract configuration profiles from this page
                guard let pageConfigurationProfiles = json["value"] as? [[String: Any]] else {
                    Logger.error("Invalid response format for configuration profile data from \(endpoint.url) (page \(pageCount + 1))", category: .reports)
                    break
                }
                
                // Process each configuration profile to add isAssigned status and normalize field names
                let processedProfiles = pageConfigurationProfiles.map { profile -> [String: Any] in
                    var processedProfile = profile
                    
                    // Normalize field names - configurationPolicies uses 'name' instead of 'displayName'
                    if let name = profile["name"] as? String, profile["displayName"] == nil {
                        processedProfile["displayName"] = name
                    }
                    
                    // Check if profile has any assignments
                    if let assignments = profile["assignments"] as? [[String: Any]] {
                        processedProfile["isAssigned"] = !assignments.isEmpty
                    } else {
                        processedProfile["isAssigned"] = false
                    }
                    
                    // Inject platform information for Windows-specific endpoints that don't provide it
                    if endpoint.url.contains("groupPolicyConfigurations") || endpoint.url.contains("windowsFeatureUpdateProfiles") ||
                        endpoint.url.contains("windowsQualityUpdateProfiles") ||
                        endpoint.url.contains("windowsQualityUpdatePolicies") ||
                        endpoint.url.contains("windowsDriverUpdateProfiles") {
                        processedProfile["platforms"] = "windows"
                        processedProfile["_injectedPlatform"] = true // Mark as injected for debugging
                    }
                    
                    // Inject profile type hint for Windows endpoints
                    if endpoint.url.contains("groupPolicyConfigurations") {
                        processedProfile["_profileTypeHint"] = "AdministrativeTemplates"
                    } else if endpoint.url.contains("windowsFeatureUpdateProfiles") {
                        processedProfile["_profileTypeHint"] = "WindowsFeatureUpdate"
                    } else if endpoint.url.contains("windowsQualityUpdateProfiles") ||
                                endpoint.url.contains("windowsQualityUpdatePolicies") {
                        processedProfile["_profileTypeHint"] = "WindowsQualityUpdate"
                    } else if endpoint.url.contains("windowsDriverUpdateProfiles") {
                        processedProfile["_profileTypeHint"] = "WindowsDriverUpdate"
                    }
                    
                    return processedProfile
                }
                
                allConfigurationProfiles.append(contentsOf: processedProfiles)
                pageCount += 1
                
                // Check for next page
                nextPageUrl = json["@odata.nextLink"] as? String
                
                Logger.info("Fetched page \(pageCount) with \(pageConfigurationProfiles.count) configuration profiles from \(endpoint.url) (total so far: \(allConfigurationProfiles.count))", category: .reports)
                
                // Safety check to prevent infinite loops
                if pageCount > 100 {
                    Logger.error("Safety limit reached: stopping after 100 pages for endpoint \(endpoint.url)", category: .reports)
                    break
                }
            }
        }
        
        Logger.info("Completed fetching \(allConfigurationProfiles.count) total configuration profiles across all endpoints", category: .reports)
        
        // Sort all configuration profiles alphabetically by display name
        return allConfigurationProfiles.sorted {
            guard let name1 = $0["displayName"] as? String, let name2 = $1["displayName"] as? String else { return false }
            return name1.localizedCaseInsensitiveCompare(name2) == .orderedAscending
        }
    }
    
    // MARK: - Device Configuration Profile Status Reports
    
    /// Retrieves device configuration profile deployment status report for a specific profile from Microsoft Graph reports endpoint
    /// Posts to the reports API and handles pagination to get detailed deployment status across all devices where the profile is assigned
    /// - Parameters:
    ///   - authToken: Valid access token for Microsoft Graph API
    ///   - profileId: Unique identifier (GUID) of the configuration profile to get deployment status for
    /// - Returns: Array of device deployment status dictionaries containing device and deployment details
    /// - Throws: Network errors, authentication errors, or JSON parsing errors
    static func getDeviceConfigProfileDeploymentStatusReport(authToken: String, profileId: String) async throws -> [[String: Any]] {
        Logger.info("Fetching device configuration profile deployment status report for profile: \(profileId)", category: .reports)
        
        var allDeviceDeploymentData: [[String: Any]] = []
        var pageCount = 0
        var skipToken: String? = nil
        
        // Initial request payload
        var requestBody: [String: Any] = [
            "select": [
                "DeviceName",
                "IntuneDeviceId",
                "UPN",
                "UserId",
                "ReportStatus",
                "UnifiedPolicyType",
                "UnifiedPolicyPlatformType",
                "Manufacturer",
                "Model",
                "PspdpuLastModifiedTimeUtc",
                "PolicyStatus",
                "PolicyId",
                "PolicyBaseTypeName"
            ],
            "skip": 0,
            "top": 50,
            "filter": "((PolicyBaseTypeName eq 'Microsoft.Management.Services.Api.DeviceConfiguration') or (PolicyBaseTypeName eq 'DeviceManagementConfigurationPolicy') or (PolicyBaseTypeName eq 'DeviceConfigurationAdmxPolicy') or (PolicyBaseTypeName eq 'Microsoft.Management.Services.Api.DeviceManagementIntent') or (PolicyBaseTypeName eq 'Microsoft.Management.Services.Api.DeviceCompliancePolicy')) and (PolicyId eq '\(profileId)')",
            "orderBy": []
        ]
        
        // Follow pagination until all device deployment data is fetched
        repeat {
            let urlString = "https://graph.microsoft.com/beta/deviceManagement/reports/getConfigurationPolicyDevicesReport"
            
            guard let url = URL(string: urlString) else {
                throw NSError(domain: "EntraGraphRequests.AppsReporting", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid reports endpoint URL"])
            }
            
            // Add skip token for pagination if available
            if let skipToken = skipToken {
                requestBody["skip"] = Int(skipToken) ?? 0
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
                Logger.error("Failed to fetch device configuration profile deployment status report for profile \(profileId) (page \(pageCount + 1)): \(responseStr)", category: .reports)
                throw NSError(domain: "EntraGraphRequests.AppsReporting", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch device configuration profile deployment status report (page \(pageCount + 1)). Status: \(httpResponse.statusCode), Response: \(responseStr)"])
            }
            
            guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
                throw NSError(domain: "EntraGraphRequests.AppsReporting", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON response format for device configuration profile deployment status report (page \(pageCount + 1))"])
            }
            
            // The reports API typically returns data in a different format than regular Graph endpoints
            // Check for both "value" array (standard) and other possible response formats
            var pageDeviceDeploymentData: [[String: Any]] = []
            
            if let reportData = json["value"] as? [[String: Any]] {
                pageDeviceDeploymentData = reportData
            } else if let reportValues = json["Values"] as? [[String: Any]] {
                // Some reports endpoints use "Values" instead of "value"
                pageDeviceDeploymentData = reportValues
            } else if let reportSchema = json["Schema"] as? [[String: Any]],
                        let reportValues = json["Values"] as? [[Any]] {
                // Handle structured report format with schema and values arrays
                pageDeviceDeploymentData = try parseStructuredReportData(schema: reportSchema, values: reportValues)
            } else {
                throw NSError(domain: "EntraGraphRequests.AppsReporting", code: 500, userInfo: [NSLocalizedDescriptionKey: "Unexpected response format for device configuration profile deployment status report (page \(pageCount + 1))"])
            }
            
            allDeviceDeploymentData.append(contentsOf: pageDeviceDeploymentData)
            pageCount += 1
            
            // Check for pagination - the new API uses different pagination format
            skipToken = nil
            if let totalRowCount = json["TotalRowCount"] as? Int,
               let currentRecords = allDeviceDeploymentData.count as Int?,
               currentRecords < totalRowCount {
                // Update skip value for next page
                requestBody["skip"] = currentRecords
                skipToken = String(currentRecords)
            } else if pageDeviceDeploymentData.count >= 50 {
                // If we got a full page of 50 records, there might be more
                let currentRecords = allDeviceDeploymentData.count
                requestBody["skip"] = currentRecords
                skipToken = String(currentRecords)
            }
            
            Logger.info("Fetched page \(pageCount) with \(pageDeviceDeploymentData.count) device deployment records (total: \(allDeviceDeploymentData.count))", category: .reports)
            
            // Safety check to prevent infinite loops
            if pageCount > 100 {
                Logger.error("Safety limit reached: stopping after 100 pages of device configuration profile deployment status", category: .reports)
                break
            }
            
        } while skipToken != nil
        
        Logger.info("Successfully fetched \(allDeviceDeploymentData.count) device deployment records for configuration profile \(profileId) across \(pageCount) pages", category: .reports)
        
        // Sort by device name for consistent presentation
        return allDeviceDeploymentData.sorted { record1, record2 in
            let deviceName1 = record1["DeviceName"] as? String ?? ""
            let deviceName2 = record2["DeviceName"] as? String ?? ""
            return deviceName1.localizedCaseInsensitiveCompare(deviceName2) == .orderedAscending
        }
    }
    
    // MARK: - Export Jobs API
    /// https://learn.microsoft.com/en-us/intune/intune-service/fundamentals/reports-export-graph-apis
    
    /// Creates an export job for Intune reports using Microsoft Graph export jobs API
    /// This is a generic function that can handle different report types with customizable parameters
    /// - Parameters:
    ///   - authToken: Valid access token for Microsoft Graph API
    ///   - reportName: Name of the report to export (e.g., "DeviceInstallStatusByApp", "DeviceComplianceOrg")
    ///   - filter: Optional filter string for the report data
    ///   - select: Optional array of columns to include in the export
    ///   - format: Export format (default: "csv", can also be "json")
    ///   - localizationType: Localization type (default: "localizedValuesAsAdditionalColumn")
    /// - Returns: Export job ID that can be used to check status and download results
    /// - Throws: Network errors, authentication errors, or JSON parsing errors
    static func createExportJob(
        authToken: String,
        reportName: String,
        filter: String? = nil,
        select: [String]? = nil,
        format: String = "csv",
        localizationType: String = "LocalizedValuesAsAdditionalColumn"
    ) async throws -> String {
        Logger.info("Creating export job for report: \(reportName)", category: .reports)
        
        let urlString = "https://graph.microsoft.com/beta/deviceManagement/reports/exportJobs"
        
        guard let url = URL(string: urlString) else {
            throw NSError(domain: "EntraGraphRequests.ExportJobs", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid export jobs endpoint URL"])
        }
        
        // Build request body
        var requestBody: [String: Any] = [
            "reportName": reportName,
            "format": format,
            "localizationType": localizationType
        ]
        
        // Add optional parameters if provided
        if let filter = filter {
            requestBody["filter"] = filter
        }
        
        if let select = select {
            requestBody["select"] = select
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            
            // Debug logging
            if let jsonData = request.httpBody,
               let jsonString = String(data: jsonData, encoding: .utf8) {
                Logger.info("Export job request body: \(jsonString)", category: .reports)
            }
        } catch {
            throw NSError(domain: "EntraGraphRequests.ExportJobs", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to serialize export job request body: \(error.localizedDescription)"])
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "EntraGraphRequests.ExportJobs", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid response type"])
        }
        
        guard httpResponse.statusCode == 200 || httpResponse.statusCode == 201 else {
            let responseStr = String(data: data, encoding: .utf8) ?? "Unknown error"
            Logger.error("Failed to create export job for report \(reportName): \(responseStr)", category: .reports)
            throw NSError(domain: "EntraGraphRequests.ExportJobs", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to create export job for \(reportName). Status: \(httpResponse.statusCode), Response: \(responseStr)"])
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
            throw NSError(domain: "EntraGraphRequests.ExportJobs", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON response format for export job creation"])
        }
        
        guard let jobId = json["id"] as? String else {
            throw NSError(domain: "EntraGraphRequests.ExportJobs", code: 500, userInfo: [NSLocalizedDescriptionKey: "Export job ID not found in response"])
        }
        
        Logger.info("Successfully created export job for \(reportName) with ID: \(jobId)", category: .reports)
        return jobId
    }
    
    /// Checks the status of an export job and returns the job details
    /// - Parameters:
    ///   - authToken: Valid access token for Microsoft Graph API
    ///   - jobId: Export job ID returned from createExportJob
    /// - Returns: Dictionary containing job status and details (status, downloadUrl, etc.)
    /// - Throws: Network errors, authentication errors, or JSON parsing errors
    static func getExportJobStatus(authToken: String, jobId: String) async throws -> [String: Any] {
        Logger.info("Checking status of export job: \(jobId)", category: .reports)
        
        let urlString = "https://graph.microsoft.com/beta/deviceManagement/reports/exportJobs('\(jobId)')"
        
        guard let url = URL(string: urlString) else {
            throw NSError(domain: "EntraGraphRequests.ExportJobs", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid export job status endpoint URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "EntraGraphRequests.ExportJobs", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid response type"])
        }
        
        guard httpResponse.statusCode == 200 else {
            let responseStr = String(data: data, encoding: .utf8) ?? "Unknown error"
            Logger.error("Failed to get export job status for job \(jobId): \(responseStr)", category: .reports)
            throw NSError(domain: "EntraGraphRequests.ExportJobs", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to get export job status. Status: \(httpResponse.statusCode), Response: \(responseStr)"])
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
            throw NSError(domain: "EntraGraphRequests.ExportJobs", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON response format for export job status"])
        }
        
        let status = json["status"] as? String ?? "unknown"
        Logger.info("Export job \(jobId) status: \(status)", category: .reports)
        
        return json
    }
    
    /// Downloads the completed export job data from the provided download URL
    /// - Parameters:
    ///   - authToken: Valid access token for Microsoft Graph API (not used for Azure blob storage download)
    ///   - downloadUrl: Download URL from the completed export job (contains SAS token authentication)
    /// - Returns: Raw data from the export (CSV or JSON format depending on job creation)
    /// - Throws: Network errors, authentication errors, or download errors
    static func downloadExportJobData(authToken: String, downloadUrl: String) async throws -> Data {
        Logger.info("Downloading export job data from: \(downloadUrl)", category: .reports)
        
        guard let url = URL(string: downloadUrl) else {
            throw NSError(domain: "EntraGraphRequests.ExportJobs", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid download URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        // Note: Do NOT add Authorization header for Azure blob storage URLs
        // The download URL includes SAS token authentication in the URL itself
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "EntraGraphRequests.ExportJobs", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid response type"])
        }
        
        guard httpResponse.statusCode == 200 else {
            let responseStr = String(data: data, encoding: .utf8) ?? "Unknown error"
            Logger.error("Failed to download export job data: \(responseStr)", category: .reports)
            throw NSError(domain: "EntraGraphRequests.ExportJobs", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to download export job data. Status: \(httpResponse.statusCode)"])
        }
        
        Logger.info("Successfully downloaded export job data (\(data.count) bytes)", category: .reports)
        return data
    }
    
    /// Polls an export job until completion and returns the downloaded data
    /// - Parameters:
    ///   - authToken: Valid access token for Microsoft Graph API
    ///   - jobId: Export job ID to poll
    ///   - maxWaitTimeSeconds: Maximum time to wait for completion (default: 300 seconds)
    ///   - pollIntervalSeconds: Interval between status checks (default: 5 seconds)
    /// - Returns: Downloaded export data
    /// - Throws: Timeout errors, network errors, or job failure errors
    static func pollAndDownloadExportJob(
        authToken: String,
        jobId: String,
        maxWaitTimeSeconds: Int = 300,
        pollIntervalSeconds: Int = 5
    ) async throws -> Data {
        Logger.info("Polling export job \(jobId) for completion", category: .reports)
        
        let startTime = Date()
        let maxWaitTime = TimeInterval(maxWaitTimeSeconds)
        let pollInterval = TimeInterval(pollIntervalSeconds)
        
        while Date().timeIntervalSince(startTime) < maxWaitTime {
            let jobStatus = try await getExportJobStatus(authToken: authToken, jobId: jobId)
            
            guard let status = jobStatus["status"] as? String else {
                throw NSError(domain: "EntraGraphRequests.ExportJobs", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid job status response"])
            }
            
            switch status.lowercased() {
            case "completed":
                guard let downloadUrl = jobStatus["url"] as? String else {
                    throw NSError(domain: "EntraGraphRequests.ExportJobs", code: 500, userInfo: [NSLocalizedDescriptionKey: "Download URL not found in completed job"])
                }
                Logger.info("Export job \(jobId) completed, downloading data", category: .reports)
                return try await downloadExportJobData(authToken: authToken, downloadUrl: downloadUrl)
                
            case "failed":
                let errorMessage = jobStatus["errorMessage"] as? String ?? "Unknown error"
                throw NSError(domain: "EntraGraphRequests.ExportJobs", code: 500, userInfo: [NSLocalizedDescriptionKey: "Export job failed: \(errorMessage)"])
                
            case "inprogress", "notstarted":
                Logger.info("Export job \(jobId) status: \(status), waiting \(pollInterval) seconds", category: .reports)
                try await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
                
            default:
                Logger.warning("Unknown export job status: \(status)", category: .reports)
                try await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
            }
        }
        
        throw NSError(domain: "EntraGraphRequests.ExportJobs", code: 408, userInfo: [NSLocalizedDescriptionKey: "Export job timed out after \(maxWaitTimeSeconds) seconds"])
    }
    
    // MARK: - Export Jobs Report Types
    /// https://learn.microsoft.com/en-us/intune/intune-service/fundamentals/reports-export-graph-available-reports

}
