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
    
    // MARK: DeviceInstallStatusByApp
    /// Convenience function to create a DeviceInstallStatusByApp export job with common parameters
    /// - Parameters:
    ///   - authToken: Valid access token for Microsoft Graph API
    ///   - applicationId: Non-Optional filter by specific application ID
    ///   - deviceName: Optional filter by device name
    ///   - userName: Optional filter by user name
    ///   - includeColumns: Optional array of specific columns to include
    ///   - format: Export format ("csv" or "json", defaults to "csv")
    /// - Returns: Export job ID that can be used to check status and download results
    /// - Throws: Network errors, authentication errors, or JSON parsing errors
    static func createDeviceInstallStatusByAppExportJob(
        authToken: String,
        applicationId: String? = nil,
        deviceName: String? = nil,
        userName: String? = nil,
        includeColumns: [String]? = nil,
        format: String = "csv"
    ) async throws -> String {
        Logger.info("Creating DeviceInstallStatusByApp export job", category: .reports)
        
        // Build filter string if any filters are provided
        var filterComponents: [String] = []
        
        if let applicationId = applicationId {
            filterComponents.append("ApplicationId eq '\(applicationId)'")
        }
        
        if let deviceName = deviceName {
            filterComponents.append("DeviceName eq '\(deviceName)'")
        }
        
        if let userName = userName {
            filterComponents.append("UserPrincipalName eq '\(userName)'")
        }
        
        let filter = filterComponents.isEmpty ? nil : filterComponents.joined(separator: " and ")
        
        // Default columns for DeviceInstallStatusByApp if none specified
        // Based on Microsoft Graph API documentation for DeviceInstallStatusByApp report
        let defaultColumns = [
            "DeviceName",
            "UserPrincipalName",
            "UserName",
            "Platform",
            "AppVersion",
            "DeviceId",
            "AssignmentFilterIdsExist",
            "LastModifiedDateTime",
            "AppInstallState",
            "AppInstallStateDetails",
            "HexErrorCode"
        ]
        
        let columnsToInclude = includeColumns ?? defaultColumns
        
        return try await createExportJob(
            authToken: authToken,
            reportName: "DeviceInstallStatusByApp",
            filter: filter,
            select: columnsToInclude,
            format: format
        )
    }
    
    // MARK: UserInstallStatusAggregateByApp
    /// Convenience function to create a UserInstallStatusAggregateByApp export job with common parameters
    /// - Parameters:
    ///   - authToken: Valid access token for Microsoft Graph API
    ///   - applicationId: Non-Optional filter by specific application ID
    ///   - deviceName: Optional filter by device name
    ///   - userName: Optional filter by user name
    ///   - includeColumns: Optional array of specific columns to include
    /// - Returns: Export job ID that can be used to check status and download results
    /// - Throws: Network errors, authentication errors, or JSON parsing errors
    static func createUserInstallStatusAggregateByAppExportJob(
        authToken: String,
        applicationId: String? = nil,
        deviceName: String? = nil,
        userName: String? = nil,
        includeColumns: [String]? = nil,
        format: String = "csv"
    ) async throws -> String {
        Logger.info("Creating UserInstallStatusAggregateByApp export job", category: .reports)
        
        // Build filter string if any filters are provided
        var filterComponents: [String] = []
        
        if let applicationId = applicationId {
            filterComponents.append("ApplicationId eq '\(applicationId)'")
        }
        
        if let deviceName = deviceName {
            filterComponents.append("DeviceName eq '\(deviceName)'")
        }
        
        if let userName = userName {
            filterComponents.append("UserPrincipalName eq '\(userName)'")
        }
        
        let filter = filterComponents.isEmpty ? nil : filterComponents.joined(separator: " and ")
        
        // Default columns for UserInstallStatusAggregateByApp if none specified
        // Based on Microsoft Graph API documentation for UserInstallStatusAggregateByApp report
        let defaultColumns = [
            "UserPrincipalName",
            "UserName",
            "FailedCount",
            "InstalledCount",
            "PendingInstallCount",
            "NotInstalledCount",
            "NotApplicableCount"
        ]
        
        let columnsToInclude = includeColumns ?? defaultColumns
        
        return try await createExportJob(
            authToken: authToken,
            reportName: "UserInstallStatusAggregateByApp",
            filter: filter,
            select: columnsToInclude,
            format: format
        )
    }

    // MARK: AppInvByDevice
    /// Convenience function to create a AppInvByDevice export job with common parameters
    /// - Parameters:
    ///   - authToken: Valid access token for Microsoft Graph API
    ///   - deviceId: Non-Optional filter by specific device ID
    ///   - includeColumns: Optional array of specific columns to include
    ///   - format: Export format ("csv" or "json", defaults to "csv")
    /// - Returns: Export job ID that can be used to check status and download results
    /// - Throws: Network errors, authentication errors, or JSON parsing errors
    static func createAppInvByDeviceExportJob(
        authToken: String,
        deviceId: String,
        includeColumns: [String]? = nil,
        format: String = "csv"
    ) async throws -> String {
        Logger.info("Creating AppInvByDevice export job", category: .reports)
        
        // Build filter string if any filters are provided
        var filterComponents: [String] = []
        
        filterComponents.append("DeviceId eq '\(deviceId)'")

        let filter = filterComponents.isEmpty ? nil : filterComponents.joined(separator: " and ")

        // Default columns for AppInvByDevice if none specified
        // Based on Microsoft Graph API documentation for AppInvByDevice report
        let defaultColumns = [
            "DeviceId",
            "ApplicationKey",
            "ApplicationName",
            "ApplicationPublisher",
            "ApplicationShortVersion",
            "ApplicationVersion",
            "DeviceName",
            "OSDescription",
            "OSVersion",
            "Platform",
            "UserId",
            "EmailAddress",
            "UserName"
        ]
        
        let columnsToInclude = includeColumns ?? defaultColumns
        
        return try await createExportJob(
            authToken: authToken,
            reportName: "AppInvByDevice",
            filter: filter,
            select: columnsToInclude,
            format: format
        )
    }

    // MARK: AllAppsList
    /// Convenience function to create a AllAppsList export job with common parameters
    /// - Parameters:
    ///   - authToken: Valid access token for Microsoft Graph API
    ///   - applicationId: Optional filter by specific application ID
    ///   - deviceName: Optional filter by device name
    ///   - userName: Optional filter by user name
    ///   - includeColumns: Optional array of specific columns to include
    ///   - format: Export format ("csv" or "json", defaults to "csv")
    /// - Returns: Export job ID that can be used to check status and download results
    /// - Throws: Network errors, authentication errors, or JSON parsing errors
    static func createAllAppsListExportJob(
        authToken: String,
        includeColumns: [String]? = nil,
        format: String = "csv"
    ) async throws -> String {
        Logger.info("Creating AllAppsList export job", category: .reports)
                
        // Default columns for AllAppsList if none specified
        // Based on Microsoft Graph API documentation for AllAppsList report
        let defaultColumns = [
            "AppIdentifier",
            "Name",
            "Publisher",
            "Platform",
            "Status",
            "Type",
            "Version",
            "Description",
            "Developer",
            "FeaturedApp",
            "Notes",
            "Owner",
            "DateCreated",
            "LastModified",
            "ExpirationDate",
            "MoreInformationURL",
            "PrivacyInformationURL",
            "StoreURL",
            "Assigned"
        ]
        
        let columnsToInclude = includeColumns ?? defaultColumns
        
        return try await createExportJob(
            authToken: authToken,
            reportName: "AllAppsList",
            filter: nil,
            select: columnsToInclude,
            format: format
        )
    }

    // MARK: AppInstallStatusAggregate
    /// Convenience function to create a AllAppsList export job with common parameters
    /// - Parameters:
    ///   - authToken: Valid access token for Microsoft Graph API
    ///   - platform: Optional filter by specific platform
    ///   - failedDevicePercentage: Optional filter by device failed percentage
    ///   - includeColumns: Optional array of specific columns to include
    ///   - format: Export format ("csv" or "json", defaults to "csv")
    /// - Returns: Export job ID that can be used to check status and download results
    /// - Throws: Network errors, authentication errors, or JSON parsing errors
    static func createAppInstallStatusAggregateExportJob(
        authToken: String,
        platform: String? = nil,
        failedDevicePercentage: String? = nil,
        includeColumns: [String]? = nil,
        format: String = "csv"
    ) async throws -> String {
        Logger.info("Creating AppInstallStatusAggregate export job", category: .reports)
                
        // Default columns for AppInstallStatusAggregate if none specified
        // Based on Microsoft Graph API documentation for AppInstallStatusAggregate report
        let defaultColumns = [
            "ApplicationId",
            "DisplayName",
            "Publisher",
            "Platform",
            "AppVersion",
            "InstalledDeviceCount",
            "InstalledUserCount",
            "FailedDeviceCount",
            "FailedUserCount",
            "PendingInstallDeviceCount",
            "PendingInstallUserCount",
            "NotApplicableDeviceCount",
            "NotApplicableUserCount",
            "NotInstalledDeviceCount",
            "NotInstalledUserCount",
            "FailedDevicePercentage"
        ]
        
        let columnsToInclude = includeColumns ?? defaultColumns
        
        return try await createExportJob(
            authToken: authToken,
            reportName: "AppInstallStatusAggregate",
            filter: nil,
            select: columnsToInclude,
            format: format
        )
    }

    // MARK: AppInvAggregate
    /// Convenience function to create a AppInvAggregate export job with common parameters
    /// - Parameters:
    ///   - authToken: Valid access token for Microsoft Graph API
    ///   - includeColumns: Optional array of specific columns to include
    ///   - format: Export format ("csv" or "json", defaults to "csv")
    /// - Returns: Export job ID that can be used to check status and download results
    /// - Throws: Network errors, authentication errors, or JSON parsing errors
    static func createAppInvAggregateExportJob(
        authToken: String,
        includeColumns: [String]? = nil,
        format: String = "csv"
    ) async throws -> String {
        Logger.info("Creating AppInvAggregate export job", category: .reports)
                
        // Default columns for AppInvAggregate if none specified
        // Based on Microsoft Graph API documentation for AppInvAggregate report
        let defaultColumns = [
            "ApplicationKey",
            "ApplicationName",
            "ApplicationPublisher",
            "ApplicationShortVersion",
            "ApplicationVersion",
            "DeviceCount",
            "Platform"
        ]
        
        let columnsToInclude = includeColumns ?? defaultColumns
        
        return try await createExportJob(
            authToken: authToken,
            reportName: "AppInvAggregate",
            filter: nil,
            select: columnsToInclude,
            format: format
        )
    }

    // MARK: AppInvRawData
    /// Convenience function to create a AppInvRawData export job with common parameters
    /// - Parameters:
    ///   - authToken: Valid access token for Microsoft Graph API
    ///   - applicationName: Optional filter by specific application name
    ///   - applicationPublisher: Optional filter by application publisher
    ///   - applicationShortVersion: Optional filter by application short version
    ///   - applicationVersion: Optional filter by application version
    ///   - deviceId: Optional filter by device id
    ///   - deviceName: Optional filter by device name
    ///   - osDescription: Optional filter by os description
    ///   - osVersion: Optional filter by os version
    ///   - platform: Optional filter by platform
    ///   - userId: Optional filter by user id
    ///   - emailAddress: Optional filter by email address
    ///   - userName: Optional filter by user name
    ///   - includeColumns: Optional array of specific columns to include
    ///   - format: Export format ("csv" or "json", defaults to "csv")
    /// - Returns: Export job ID that can be used to check status and download results
    /// - Throws: Network errors, authentication errors, or JSON parsing errors
    static func createAppInvRawDataExportJob(
        authToken: String,
        applicationName: String? = nil,
        applicationPublisher: String? = nil,
        applicationShortVersion: String? = nil,
        applicationVersion: String? = nil,
        deviceId: String? = nil,
        deviceName: String? = nil,
        osDescription: String? = nil,
        osVersion: String? = nil,
        platform: String? = nil,
        userId: String? = nil,
        emailAddress: String? = nil,
        userName: String? = nil,
        includeColumns: [String]? = nil,
        format: String = "csv"
    ) async throws -> String {
        Logger.info("Creating AppInvRawData export job", category: .reports)
        
        // Build filter string if any filters are provided
        var filterComponents: [String] = []
        
        if let applicationName = applicationName {
            filterComponents.append("ApplicationName eq '\(applicationName)'")
        }
        
        if let applicationPublisher = applicationPublisher {
            filterComponents.append("ApplicationPublisher eq '\(applicationPublisher)'")
        }
        
        if let applicationShortVersion = applicationShortVersion {
            filterComponents.append("ApplicationShortVersion eq '\(applicationShortVersion)'")
        }
        
        if let applicationVersion = applicationVersion {
            filterComponents.append("ApplicationVersion eq '\(applicationVersion)'")
        }

        if let deviceId = deviceId {
            filterComponents.append("DeviceId eq '\(deviceId)'")
        }

        if let deviceName = deviceName {
            filterComponents.append("DeviceName eq '\(deviceName)'")
        }

        if let osDescription = osDescription {
            filterComponents.append("OSDescription eq '\(osDescription)'")
        }

        if let osVersion = osVersion {
            filterComponents.append("OSVersion eq '\(osVersion)'")
        }

        if let platform = platform {
            filterComponents.append("Platform eq '\(platform)'")
        }

        if let userId = userId {
            filterComponents.append("UserId eq '\(userId)'")
        }

        if let emailAddress = emailAddress {
            filterComponents.append("EmailAddress eq '\(emailAddress)'")
        }

        if let userName = userName {
            filterComponents.append("UserName eq '\(userName)'")
        }
        
        let filter = filterComponents.isEmpty ? nil : filterComponents.joined(separator: " and ")
        
        // Default columns for AppInvRawData if none specified
        // Based on Microsoft Graph API documentation for AppInvRawData report
        let defaultColumns = [
            "ApplicationKey",
            "ApplicationName",
            "ApplicationPublisher",
            "ApplicationShortVersion",
            "ApplicationVersion",
            "DeviceId",
            "DeviceName",
            "OSDescription",
            "OSVersion",
            "Platform",
            "UserId",
            "EmailAddress",
            "UserName"
        ]
        
        let columnsToInclude = includeColumns ?? defaultColumns
        
        return try await createExportJob(
            authToken: authToken,
            reportName: "AppInvRawData",
            filter: filter,
            select: columnsToInclude,
            format: format
        )
    }

    // MARK: DeviceCompliance
    /// Convenience function to create a DeviceCompliance export job with common parameters
    /// - Parameters:
    ///   - authToken: Valid access token for Microsoft Graph API
    ///   - applicationId: Optional filter by specific application ID
    ///   - deviceName: Optional filter by device name
    ///   - userName: Optional filter by user name
    ///   - includeColumns: Optional array of specific columns to include
    ///   - format: Export format ("csv" or "json", defaults to "csv")
    /// - Returns: Export job ID that can be used to check status and download results
    /// - Throws: Network errors, authentication errors, or JSON parsing errors
    static func createDeviceComplianceExportJob(
        authToken: String,
        complianceState: String? = nil,
        os: String? = nil,
        ownerType: String? = nil,
        deviceType: String? = nil,
        includeColumns: [String]? = nil,
        format: String = "csv"
    ) async throws -> String {
        Logger.info("Creating DeviceCompliance export job", category: .reports)
        
        // Build filter string if any filters are provided
        var filterComponents: [String] = []
        
        if let complianceState = complianceState {
            filterComponents.append("ComplianceState eq '\(complianceState)'")
        }
        
        if let os = os {
            filterComponents.append("OS eq '\(os)'")
        }
        
        if let ownerType = ownerType {
            filterComponents.append("OwnerType eq '\(ownerType)'")
        }
        
        if let deviceType = deviceType {
            filterComponents.append("DeviceType eq '\(deviceType)'")
        }
        
        let filter = filterComponents.isEmpty ? nil : filterComponents.joined(separator: " and ")
        
        // Default columns for DeviceCompliance if none specified
        // Based on Microsoft Graph API documentation for DeviceCompliance report
        let defaultColumns = [
            "DeviceId",
            "IntuneDeviceId",
            "AadDeviceId",
            "DeviceName",
            "DeviceType",
            "OSDescription",
            "OSVersion",
            "OwnerType",
            "LastContact",
            "InGracePeriodUntil",
            "IMEI",
            "SerialNumber",
            "ManagementAgents",
            "PrimaryUser",
            "UserId",
            "UPN",
            "UserEmail",
            "UserName",
            "DeviceHealthThreatLevel",
            "RetireAfterDatetime",
            "PartnerDeviceId",
            "ComplianceState",
            "OS"
        ]
        
        let columnsToInclude = includeColumns ?? defaultColumns
        
        return try await createExportJob(
            authToken: authToken,
            reportName: "DeviceCompliance",
            filter: filter,
            select: columnsToInclude,
            format: format
        )
    }
    
    // MARK: DeviceNonCompliance
    /// Convenience function to create a DeviceNonCompliance export job with common parameters
    /// - Parameters:
    ///   - authToken: Valid access token for Microsoft Graph API
    ///   - applicationId: Optional filter by specific application ID
    ///   - deviceName: Optional filter by device name
    ///   - userName: Optional filter by user name
    ///   - includeColumns: Optional array of specific columns to include
    ///   - format: Export format ("csv" or "json", defaults to "csv")
    /// - Returns: Export job ID that can be used to check status and download results
    /// - Throws: Network errors, authentication errors, or JSON parsing errors
    static func createDeviceNonComplianceExportJob(
        authToken: String,
        complianceState: String? = nil,
        os: String? = nil,
        ownerType: String? = nil,
        deviceType: String? = nil,
        userId: String? = nil,
        includeColumns: [String]? = nil,
        format: String = "csv"
    ) async throws -> String {
        Logger.info("Creating DeviceNonCompliance export job", category: .reports)
        
        // Build filter string if any filters are provided
        var filterComponents: [String] = []
        
        if let complianceState = complianceState {
            filterComponents.append("ComplianceState eq '\(complianceState)'")
        }
        
        if let os = os {
            filterComponents.append("OS eq '\(os)'")
        }
        
        if let ownerType = ownerType {
            filterComponents.append("OwnerType eq '\(ownerType)'")
        }
        
        if let deviceType = deviceType {
            filterComponents.append("DeviceType eq '\(deviceType)'")
        }
        
        if let userId = userId {
            filterComponents.append("UserId eq '\(userId)'")
        }
        
        let filter = filterComponents.isEmpty ? nil : filterComponents.joined(separator: " and ")
        
        // Default columns for DeviceNonCompliance if none specified
        // Based on Microsoft Graph API documentation for DeviceNonCompliance report
        let defaultColumns = [
            "DeviceId",
            "IntuneDeviceId",
            "AadDeviceId",
            "DeviceName",
            "DeviceType",
            "OSDescription",
            "OSVersion",
            "OwnerType",
            "LastContact",
            "InGracePeriodUntil",
            "IMEI",
            "SerialNumber",
            "ManagementAgents",
            "PrimaryUser",
            "UserId",
            "UPN",
            "UserEmail",
            "UserName",
            "DeviceHealthThreatLevel",
            "RetireAfterDatetime",
            "PartnerDeviceId",
            "ComplianceState",
            "OS"
        ]
        
        let columnsToInclude = includeColumns ?? defaultColumns
        
        return try await createExportJob(
            authToken: authToken,
            reportName: "DeviceNonCompliance",
            filter: filter,
            select: columnsToInclude,
            format: format
        )
    }
    
    // MARK: Devices
/// Convenience function to create a Devices export job with common parameters
    /// - Parameters:
    ///   - authToken: Valid access token for Microsoft Graph API
    ///   - ownerType: Optional filter by specific owner type
    ///   - deviceType: Optional filter by device type
    ///   - managementAgents: Optional filter by management agents
    ///   - categoryName: Optional filter by category name
    ///   - managementState: Optional filter by management state
    ///   - compliantState: Optional filter by compliant state
    ///   - jailBroken: Optional filter by jail broken state
    ///   - enrollmentType: Optional filter by enrollment type
    ///   - includeColumns: Optional array of specific columns to include
    ///   - format: Export format ("csv" or "json", defaults to "csv")
    /// - Returns: Export job ID that can be used to check status and download results
    /// - Throws: Network errors, authentication errors, or JSON parsing errors
    static func createDevicesExportJob(
        authToken: String,
        ownerType: String? = nil,
        deviceType: String? = nil,
        managementAgents: String? = nil,
        categoryName: String? = nil,
        managementState: String? = nil,
        compliantState: String? = nil,
        jailBroken: String? = nil,
        enrollmentType: String? = nil,
        includeColumns: [String]? = nil,
        format: String = "csv"
    ) async throws -> String {
        Logger.info("Creating Devices export job", category: .reports)
        
        // Build filter string if any filters are provided
        var filterComponents: [String] = []
        
        if let ownerType = ownerType {
            filterComponents.append("OwnerType eq '\(ownerType)'")
        }
        
        if let deviceType = deviceType {
            filterComponents.append("DeviceType eq '\(deviceType)'")
        }
        
        if let managementAgents = managementAgents {
            filterComponents.append("ManagementAgents eq '\(managementAgents)'")
        }
        
        if let managementState = managementState {
            filterComponents.append("ManagementState eq '\(managementState)'")
        }

        if let compliantState = compliantState {
            filterComponents.append("CompliantState eq '\(compliantState)'")
        }
        
        if let jailBroken = jailBroken {
            filterComponents.append("JailBroken eq '\(jailBroken)'")
        }
        
        if let enrollmentType = enrollmentType {
            filterComponents.append("EnrollmentType eq '\(enrollmentType)'")
        }
        
        let filter = filterComponents.isEmpty ? nil : filterComponents.joined(separator: " and ")
        
        // Default columns for Devices report if none specified
        // Reduced to essential fields to avoid API limits (Microsoft Graph export jobs have column count limits)
        let defaultColumns = [
            "DeviceId",
            "DeviceName",
            "DeviceType",
            "ClientRegistrationStatus",
            "OwnerType",
            "CreatedDate",
            "LastContact",
            "ManagementAgents",
            "ManagementState",
            "ReferenceId",
            "CategoryId",
            "EnrollmentType",
            "CertExpirationDate",
            "MDMStatus",
            "OSVersion",
            "GraphDeviceIsManaged",
            "EasID",
            "SerialNumber",
            "EnrolledByUser",
            "Manufacturer",
            "Model",
            "OSDescription",
            "IsManaged",
            "EasActivationStatus",
            "IMEI",
            "EasLastSyncSuccessUtc",
            "EasStateReason",
            "EasAccessState",
            "EncryptionStatus",
            "SupervisedStatus",
            "PhoneNumberE164Format",
            "InGracePeriodUntil",
//            "AndroidPatchLevel",
            "WifiMacAddress",
//            "SCCMCoManagementFeatures",
//            "MEID",
//            "SubscriberCarrierNetwork",
            "StorageTotal",
            "StorageFree",
            "ManagedDeviceName",
            "LastLoggedOnUserUPN",
//            "MDMWinsOverGPStartTime",
//            "StagedDeviceType",
            "UserApprovedEnrollment",
            "ExtendedProperties",
            "EntitySource",
            "PrimaryUser",
            "CategoryName",
            "UserId",
            "UPN",
            "UserEmail",
            "UserName",
            "RetireAfterDatetime",
//            "PartnerDeviceId",
            "HasUnlockToken",
            "CompliantState",
            "ManagedBy",
            "Ownership",
            "DeviceState",
            "DeviceRegistrationState",
            "SupervisedStatusString",
            "EncryptionStatusString",
            "OS",
//            "SkuFamily",
            "JoinType"
//            "PhoneNumber",
//            "JailBroken",
//            "EasActivationStatusString"
        ]
        
        let columnsToInclude = includeColumns ?? defaultColumns
        
        return try await createExportJob(
            authToken: authToken,
            reportName: "Devices",
            filter: filter,
            select: columnsToInclude,
            format: format
        )
    }

    // MARK: DevicesWithInventory
/// Convenience function to create a DevicesWithInventory export job with common parameters
    /// - Parameters:
    ///   - authToken: Valid access token for Microsoft Graph API
    ///   - createdDate: Optional filter by created date
    ///   - lastContact: Optional filter by last contact
    ///   - categoryName: Optional filter by category name
    ///   - compliantState: Optional filter by management agents
    ///   - managementAgents: Optional filter by management agents
    ///   - ownerType: Optional filter by specific owner type
    ///   - managementState: Optional filter by management state
    ///   - deviceType: Optional filter by device type
    ///   - jailBroken: Optional filter by jail broken state
    ///   - enrollmentType: Optional filter by enrollment type
    ///   - includeColumns: Optional array of specific columns to include
    ///   - format: Export format ("csv" or "json", defaults to "csv")
    /// - Returns: Export job ID that can be used to check status and download results
    /// - Throws: Network errors, authentication errors, or JSON parsing errors
    static func createDevicesWithInventoryExportJob(
        authToken: String,
        createdDate: String? = nil,
        lastContact: String? = nil,
        categoryName: String? = nil,
        compliantState: String? = nil,
        managementAgents: String? = nil,
        ownerType: String? = nil,
        managementState: String? = nil,
        deviceType: String? = nil,
        jailBroken: String? = nil,
        enrollmentType: String? = nil,
        includeColumns: [String]? = nil,
        format: String = "csv"
    ) async throws -> String {
        Logger.info("Creating DevicesWithInventory export job", category: .reports)
        
        // Build filter string if any filters are provided
        var filterComponents: [String] = []
        
        if let createdDate = createdDate {
            filterComponents.append("CreatedDate eq '\(createdDate)'")
        }

        if let lastContact = lastContact {
            filterComponents.append("LastContact eq '\(lastContact)'")
        }

        if let categoryName = categoryName {
            filterComponents.append("CategoryName eq '\(categoryName)'")
        }

        if let compliantState = compliantState {
            filterComponents.append("CompliantState eq '\(compliantState)'")
        }

        if let managementAgents = managementAgents {
            filterComponents.append("ManagementAgents eq '\(managementAgents)'")
        }

        if let ownerType = ownerType {
            filterComponents.append("OwnerType eq '\(ownerType)'")
        }
        
        if let managementState = managementState {
            filterComponents.append("ManagementState eq '\(managementState)'")
        }

        if let deviceType = deviceType {
            filterComponents.append("DeviceType eq '\(deviceType)'")
        }
                
        if let jailBroken = jailBroken {
            filterComponents.append("JailBroken eq '\(jailBroken)'")
        }
        
        if let enrollmentType = enrollmentType {
            filterComponents.append("EnrollmentType eq '\(enrollmentType)'")
        }
        
        let filter = filterComponents.isEmpty ? nil : filterComponents.joined(separator: " and ")
        
        // Default columns for DevicesWithInventory report if none specified
        let defaultColumns = [
            "DeviceId",
            "DeviceName",
            "CreatedDate",
            "LastContact",
            "ReferenceId",
            "OSVersion",
            "GraphDeviceIsManaged",
            "EasID",
            "SerialNumber",
            "Manufacturer",
            "Model",
            "EasActivationStatus",
            "IMEI",
            "EasLastSyncSuccessUtc",
            "EasStateReason",
            "EasAccessState",
            "InGracePeriodUntil",
            "AndroidPatchLevel",
            "WifiMacAddress",
            "MEID",
            "SubscriberCarrierNetwork",
            "StorageTotal",
            "StorageFree",
            "ManagedDeviceName",
            "CategoryName",
            "UserId",
            "UPN",
            "UserEmail",
            "UserName",
            "WiFiIPv4Address",
            "WiFiSubnetID",
            "ComplianceState",
            "ManagementAgent",
            "OwnerType",
            "ManagementState",
            "DeviceRegistrationState",
            "IsSupervised",
            "IsEncrypted",
            "OS",
            "SkuFamily",
            "JoinType",
            "PhoneNumber",
            "JailBroken",
            "ICCID",
            "EthernetMAC",
            "CellularTechnology",
            "ProcessorArchitecture",
            "EID",
            "EnrollmentType",
            "PartnerFeaturesBitmask",
            "ManagementAgents",
            "CertExpirationDate",
            "IsManaged",
            "SystemManagementBIOSVersion",
            "TPMManufacturerId",
            "TPMManufacturerVersion"
        ]
        
        let columnsToInclude = includeColumns ?? defaultColumns
        
        return try await createExportJob(
            authToken: authToken,
            reportName: "DevicesWithInventory",
            filter: filter,
            select: columnsToInclude,
            format: format
        )
    }

    // MARK: DefenderAgents or UnhealthyDefenderAgents
    /// Convenience function to create a DefenderAgents or UnhealthyDefenderAgents export job with common parameters
    /// - Parameters:
    ///   - authToken: Valid access token for Microsoft Graph API
    ///   - deviceState: Optional filter by device state
    ///   - signatureUpdateOverdue: Optional filter by signature Update Overdue
    ///   - malwareProtectionEnabled: Optional filter by malware Protection Enabled
    ///   - realTimeProtectionEnabled: Optional filter by realTime Protection Enabled
    ///   - networkInspectionSystemEnabled: Optional filter by network Inspection System Enabled
    ///   - includeColumns: Optional array of specific columns to include
    ///   - format: Export format ("csv" or "json", defaults to "csv")
    ///   - reportType; Report format to generate
    /// - Returns: Export job ID that can be used to check status and download results
    /// - Throws: Network errors, authentication errors, or JSON parsing errors
    static func createDefenderAgentsExportJob(
        authToken: String,
        deviceState: String? = nil,
        signatureUpdateOverdue: String? = nil,
        malwareProtectionEnabled: String? = nil,
        realTimeProtectionEnabled: String? = nil,
        networkInspectionSystemEnabled: String? = nil,
        includeColumns: [String]? = nil,
        format: String = "csv",
        reportType: String = "DefenderAgents"
    ) async throws -> String {
        Logger.info("Creating DefenderAgents export job", category: .reports)
        
        // Build filter string if any filters are provided
        var filterComponents: [String] = []
        
        if let deviceState = deviceState {
            filterComponents.append("DeviceState eq '\(deviceState)'")
        }
        
        if let signatureUpdateOverdue = signatureUpdateOverdue {
            filterComponents.append("SignatureUpdateOverdue eq '\(signatureUpdateOverdue)'")
        }
        
        if let malwareProtectionEnabled = malwareProtectionEnabled {
            filterComponents.append("MalwareProtectionEnabled eq '\(malwareProtectionEnabled)'")
        }
        
        if let realTimeProtectionEnabled = realTimeProtectionEnabled {
            filterComponents.append("RealTimeProtectionEnabled eq '\(realTimeProtectionEnabled)'")
        }
        
        if let networkInspectionSystemEnabled = networkInspectionSystemEnabled {
            filterComponents.append("NetworkInspectionSystemEnabled eq '\(networkInspectionSystemEnabled)'")
        }
        
        let filter = filterComponents.isEmpty ? nil : filterComponents.joined(separator: " and ")
        
        // Default columns for DefenderAgents or UnhealthyDefenderAgents reports if none specified
        // Based on Microsoft Graph API documentation for DefenderAgents report
        let defaultColumns = [
            "DeviceId",
            "DeviceName",
            "DeviceState",
            "PendingFullScan",
            "PendingReboot",
            "PendingManualSteps",
            "PendingOfflineScan",
            "CriticalFailure",
            "MalwareProtectionEnabled",
            "RealTimeProtectionEnabled",
            "NetworkInspectionSystemEnabled",
            "SignatureUpdateOverdue",
            "QuickScanOverdue",
            "FullScanOverdue",
            "RebootRequired",
            "FullScanRequired",
            "EngineVersion",
            "SignatureVersion",
            "AntiMalwareVersion",
            "LastQuickScanDateTime",
            "LastFullScanDateTime",
            "LastQuickScanSignatureVersion",
            "LastFullScanSignatureVersion",
            "LastReportedDateTime",
            "UPN",
            "UserEmail",
            "UserName"
        ]
        
        let columnsToInclude = includeColumns ?? defaultColumns
        
        return try await createExportJob(
            authToken: authToken,
            reportName: reportType,
            filter: filter,
            select: columnsToInclude,
            format: format
        )
    }
    
    // MARK: FirewallStatus
    /// Convenience function to create a FirewallStatus export job with common parameters
    /// - Parameters:
    ///   - authToken: Valid access token for Microsoft Graph API
    ///   - firewallStatus: Optional filter by specific application ID
    ///   - includeColumns: Optional array of specific columns to include
    ///   - format: Export format ("csv" or "json", defaults to "csv")
    /// - Returns: Export job ID that can be used to check status and download results
    /// - Throws: Network errors, authentication errors, or JSON parsing errors
    static func createFirewallStatusExportJob(
        authToken: String,
        firewallStatus: String? = nil,
        includeColumns: [String]? = nil,
        format: String = "csv"
    ) async throws -> String {
        Logger.info("Creating FirewallStatus export job", category: .reports)
        
        // Build filter string if any filters are provided
        var filterComponents: [String] = []
        
        if let firewallStatus = firewallStatus {
            filterComponents.append("FirewallStatus eq '\(firewallStatus)'")
        }
                
        let filter = filterComponents.isEmpty ? nil : filterComponents.joined(separator: " and ")
        
        // Default columns for DeviceCompliance if none specified
        // Based on Microsoft Graph API documentation for DeviceCompliance report
        let defaultColumns = [
            "DeviceName",
            "FirewallStatus",
            "_ManagedBy",
            "UPN"
        ]
        
        let columnsToInclude = includeColumns ?? defaultColumns
        
        return try await createExportJob(
            authToken: authToken,
            reportName: "FirewallStatus",
            filter: filter,
            select: columnsToInclude,
            format: format
        )
    }
    
    // MARK: Malware or ActiveMalware
    /// Convenience function to create a Malware or ActiveMalware export job with common parameters
    /// - Parameters:
    ///   - authToken: Valid access token for Microsoft Graph API
    ///   - severity: Optional filter by severity
    ///   - executionState: Optional filter by execution state
    ///   - state: Optional filter state
    ///   - includeColumns: Optional array of specific columns to include
    ///   - format: Export format ("csv" or "json", defaults to "csv")
    ///   - reportType; Report format to generate
    /// - Returns: Export job ID that can be used to check status and download results
    /// - Throws: Network errors, authentication errors, or JSON parsing errors
    static func createMalwareExportJob(
        authToken: String,
        severity: String? = nil,
        executionState: String? = nil,
        state: String? = nil,
        includeColumns: [String]? = nil,
        format: String = "csv",
        reportType: String = "Malware"
    ) async throws -> String {
        Logger.info("Creating Malware export job", category: .reports)
        
        // Build filter string if any filters are provided
        var filterComponents: [String] = []
        
        if let severity = severity {
            filterComponents.append("Severity eq '\(severity)'")
        }
        
        if let executionState = executionState {
            filterComponents.append("ExecutionState eq '\(executionState)'")
        }
        
        if let state = state {
            filterComponents.append("State eq '\(state)'")
        }
        
        let filter = filterComponents.isEmpty ? nil : filterComponents.joined(separator: " and ")
        
        // Default columns for DefenderAgents or UnhealthyDefenderAgents reports if none specified
        // Based on Microsoft Graph API documentation for DefenderAgents report
        let defaultColumns = [
            "DeviceId",
            "DeviceName",
            "MalwareId",
            "MalwareName",
            "AdditionalInformationUrl",
            "Severity",
            "MalwareCategory",
            "ExecutionState",
            "State",
            "InitialDetectionDateTime",
            "LastStateChangeDateTime",
            "DetectionCount",
            "UPN",
            "UserEmail",
            "UserName"
        ]
        
        let columnsToInclude = includeColumns ?? defaultColumns
        
        return try await createExportJob(
            authToken: authToken,
            reportName: reportType,
            filter: filter,
            select: columnsToInclude,
            format: format
        )
    }
    
    
    // MARK: MAMAppProtectionStatus
    /// Convenience function to create a MAMAppProtectionStatus export job with common parameters
    /// - Parameters:
    ///   - authToken: Valid access token for Microsoft Graph API
    ///   - includeColumns: Optional array of specific columns to include
    ///   - format: Export format ("csv" or "json", defaults to "csv")
    /// - Returns: Export job ID that can be used to check status and download results
    /// - Throws: Network errors, authentication errors, or JSON parsing errors
    static func createMAMAppProtectionStatusExportJob(
        authToken: String,
        includeColumns: [String]? = nil,
        format: String = "csv"
    ) async throws -> String {
        Logger.info("Creating MAMAppProtectionStatus export job", category: .reports)
                
        // Default columns for MAMAppProtectionStatus if none specified
        // Based on Microsoft Graph API documentation for MAMAppProtectionStatus report
        let defaultColumns = [
            "User",
            "Email",
            "App",
            "AppVersion",
            "SdkVersion",
            "AppInstanceId",
            "DeviceName",
            "DeviceHealth",
            "DeviceType",
            "DeviceManufacturer",
            "DeviceModel",
            "AndroidPatchVersion",
            "AADDeviceID",
            "MDMDeviceID",
            "Platform",
            "PlatformVersion",
            "ManagementType",
            "AppProtectionStatus",
            "Policy",
            "LastSync",
            "ComplianceState"
        ]
        
        let columnsToInclude = includeColumns ?? defaultColumns
        
        return try await createExportJob(
            authToken: authToken,
            reportName: "MAMAppProtectionStatus",
            filter: nil,
            select: columnsToInclude,
            format: format
        )
    }

    // MARK: MAMAppConfigurationStatus
    /// Convenience function to create a MAMAppConfigurationStatus export job with common parameters
    /// - Parameters:
    ///   - authToken: Valid access token for Microsoft Graph API
    ///   - includeColumns: Optional array of specific columns to include
    ///   - format: Export format ("csv" or "json", defaults to "csv")
    /// - Returns: Export job ID that can be used to check status and download results
    /// - Throws: Network errors, authentication errors, or JSON parsing errors
    static func createMAMAppConfigurationStatusExportJob(
        authToken: String,
        includeColumns: [String]? = nil,
        format: String = "csv"
    ) async throws -> String {
        Logger.info("Creating MAMAppConfigurationStatus export job", category: .reports)
                
        // Default columns for MAMAppConfigurationStatus if none specified
        // Based on Microsoft Graph API documentation for MAMAppConfigurationStatus report
        let defaultColumns = [
            "User",
            "Email",
            "App",
            "AppVersion",
            "SdkVersion",
            "AppInstanceId",
            "DeviceName",
            "DeviceHealth",
            "DeviceType",
            "DeviceManufacturer",
            "DeviceModel",
            "AndroidPatchVersion",
            "AADDeviceID",
            "MDMDeviceID",
            "Platform",
            "PlatformVersion",
            "Policy",
            "LastSync"
        ]
        
        let columnsToInclude = includeColumns ?? defaultColumns
        
        return try await createExportJob(
            authToken: authToken,
            reportName: "MAMAppConfigurationStatus",
            filter: nil,
            select: columnsToInclude,
            format: format
        )
    }
    
    // MARK: FeatureUpdatePolicyFailuresAggregate
    /// Convenience function to create a FeatureUpdatePolicyFailuresAggregate export job with common parameters
    /// - Parameters:
    ///   - authToken: Valid access token for Microsoft Graph API
    ///   - includeColumns: Optional array of specific columns to include
    ///   - format: Export format ("csv" or "json", defaults to "csv")
    /// - Returns: Export job ID that can be used to check status and download results
    /// - Throws: Network errors, authentication errors, or JSON parsing errors
    static func createFeatureUpdatePolicyFailuresAggregateExportJob(
        authToken: String,
        includeColumns: [String]? = nil,
        format: String = "csv"
    ) async throws -> String {
        Logger.info("Creating FeatureUpdatePolicyFailuresAggregate export job", category: .reports)
                
        // Default columns for FeatureUpdatePolicyFailuresAggregate if none specified
        // Based on Microsoft Graph API documentation for FeatureUpdatePolicyFailuresAggregate report
        let defaultColumns = [
            "PolicyId",
            "PolicyName",
            "FeatureUpdateVersion",
            "NumberOfDevicesWithErrors"
        ]
        
        let columnsToInclude = includeColumns ?? defaultColumns
        
        return try await createExportJob(
            authToken: authToken,
            reportName: "FeatureUpdatePolicyFailuresAggregate",
            filter: nil,
            select: columnsToInclude,
            format: format
        )
    }

    // MARK: QualityUpdateDeviceStatusByPolicy
    /// Convenience function to create a QualityUpdateDeviceStatusByPolicy export job with common parameters
    /// - Parameters:
    ///   - authToken: Valid access token for Microsoft Graph API
    ///   - policyID: Required filter by policy ID
    ///   - aggregateState: Optional filter by aggregate state
    ///   - ownerType: Optional filter owner type
    ///   - includeColumns: Optional array of specific columns to include
    ///   - format: Export format ("csv" or "json", defaults to "csv")
    /// - Returns: Export job ID that can be used to check status and download results
    /// - Throws: Network errors, authentication errors, or JSON parsing errors
    static func createQualityUpdateDeviceStatusByPolicyExportJob(
        authToken: String,
        policyID: String,
        aggregateState: String? = nil,
        ownerType: String? = nil,
        includeColumns: [String]? = nil,
        format: String = "csv"
    ) async throws -> String {
        Logger.info("Creating QualityUpdateDeviceStatusByPolicy export job", category: .reports)
        
        // Build filter string if any filters are provided
        var filterComponents: [String] = []
        
        filterComponents.append("PolicyId eq '\(policyID)'")
        
        if let aggregateState = aggregateState {
            filterComponents.append("AggregateState eq '\(aggregateState)'")
        }
        
        if let ownerType = ownerType {
            filterComponents.append("OwnerType eq '\(ownerType)'")
        }
        
        let filter = filterComponents.isEmpty ? nil : filterComponents.joined(separator: " and ")
        
        // Default columns for DefenderAgents or UnhealthyDefenderAgents reports if none specified
        // Based on Microsoft Graph API documentation for DefenderAgents report
        let defaultColumns = [
            "PolicyId",
            "DeviceName",
            "UPN",
            "DeviceId",
            "AADDeviceId",
            "EventDateTimeUTC",
            "CurrentDeviceUpdateStatus",
            "CurrentDeviceUpdateStatus_loc",
            "CurrentDeviceUpdateSubstatus",
            "CurrentDeviceUpdateSubstatus_loc",
            "AggregateState",
            "AggregateState_loc",
            "LatestAlertMessage",
            "LatestAlertMessage_loc",
            "LastWUScanTimeUTC",
            "OwnerType"
        ]
        
        let columnsToInclude = includeColumns ?? defaultColumns
        
        return try await createExportJob(
            authToken: authToken,
            reportName: "QualityUpdateDeviceStatusByPolicy",
            filter: filter,
            select: columnsToInclude,
            format: format
        )
    }

}
