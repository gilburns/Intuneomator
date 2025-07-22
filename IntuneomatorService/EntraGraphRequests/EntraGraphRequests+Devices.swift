//
//  EntraGraphRequests+Devices.swift
//  Intuneomator
//
//  Created by Gil Burns on 7/20/25.
//

import Foundation

// MARK: - Device Management Extension

/// Extension for handling Microsoft Graph API device operations
/// Provides functionality for fetching and managing devices
extension EntraGraphRequests {
    
    // MARK: - Fetch All Devices
    
    /// Searches for all managed devices in Intune
    /// - Parameters:
    ///   - authToken: Valid access token for Microsoft Graph API
    /// - Returns: Array of managed devices
    /// - Throws: GraphAPIError for various request and processing failures
    static func fetchManagedDevices(authToken: String) async throws -> [[String: Any]] {
        var allManagedDevices: [[String: Any]] = []
        
        // Construct the initial URL
        let baseURL = "https://graph.microsoft.com/beta/deviceManagement/managedDevices"
        let select = "id,deviceName,ownerType,managementState,operatingSystem,serialNumber,manufacturer,model,enrolledDateTime,deviceEnrollmentType,lastSyncDateTime,azureADDeviceId,userPrincipalName,userDisplayName,userId"
        let initialURL = "\(baseURL)?$select=\(select)"
        var nextPageUrl: String? = initialURL
        var pageCount = 0
        
        Logger.info("Starting paginated fetch of Intune Managed Devices...", category: .core)
        
        // Follow pagination until all managed devices are fetched
        while let urlString = nextPageUrl {
            Logger.info("Fetching managed devices from URL: \(urlString)", category: .core)
            
            guard let url = URL(string: urlString) else {
                throw NSError(domain: "EntraGraphRequests.DevicesReporting", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid pagination URL: \(urlString)"])
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                let responseString = String(data: data, encoding: .utf8) ?? "No response data"
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                Logger.error("HTTP \(statusCode) error fetching managed devices (page \(pageCount + 1)): \(responseString)", category: .core)
                throw NSError(domain: "EntraGraphRequests.DevicesReporting", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch managed devices data (page \(pageCount + 1)): HTTP \(statusCode) - \(responseString)"])
            }
            
            // Parse JSON response
            guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
                throw NSError(domain: "EntraGraphRequests.DevicesReporting", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON response format for managed devices data (page \(pageCount + 1))"])
            }
            
            // Extract managed devices from this page
            guard let pageManagedDevices = json["value"] as? [[String: Any]] else {
                throw NSError(domain: "EntraGraphRequests.DevicesReporting", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid response format for managed devices data (page \(pageCount + 1))"])
            }
            
            allManagedDevices.append(contentsOf: pageManagedDevices)
            pageCount += 1
            
            // Check for next page
            nextPageUrl = json["@odata.nextLink"] as? String
            
            Logger.info("Fetched page \(pageCount) with \(pageManagedDevices.count) managed devices (total: \(allManagedDevices.count))", category: .core)
            
            // Safety check to prevent infinite loops
            if pageCount > 100 {
                Logger.error("Safety limit reached: stopping after 100 pages of managed devices", category: .core)
                break
            }
        }
        
        Logger.info("Completed fetching \(allManagedDevices.count) total managed devices across \(pageCount) pages", category: .core)
        
        // Sort all managed devices alphabetically by device name
        return allManagedDevices.sorted {
            guard let name1 = $0["deviceName"] as? String, let name2 = $1["deviceName"] as? String else { return false }
            return name1.localizedCaseInsensitiveCompare(name2) == .orderedAscending
        }
    }

    
    /// Retrieves comprehensive details about a specific managed device from Microsoft Intune
    ///
    /// This function fetches complete metadata and content for a specific managed device,
    ///
    /// - Parameters:
    ///   - authToken: Valid OAuth 2.0 bearer token with DeviceManagementConfiguration.Read.All permissions
    ///   - deviceId: Unique identifier (GUID) of the device to retrieve
    /// - Returns: Dictionary containing complete managed device
    /// - Throws:
    ///   - `NSError` with domain "DevicesReporting" and code 500: Invalid URL, HTTP request failure, or JSON parsing failure
    ///   - Network-related errors from URLSession
    ///
    /// **Required Permissions:**
    /// - DeviceManagementConfiguration.Read.All (Application or Delegated)
    ///
    static func getManagedDeviceDetails(authToken: String, byId deviceId: String) async throws -> [String: Any] {
        
        let baseURL = "https://graph.microsoft.com/beta/deviceManagement/managedDevices/\(deviceId)"
        let expandColumns = "detectedApps,deviceCategory,logCollectionRequests,windowsProtectionState"
        
        let deviceDetailsURL = "\(baseURL)?$expand=\(expandColumns)"

        var request = URLRequest(url: URL(string: deviceDetailsURL)!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let responseStr = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "DevicesReporting", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch managed device details. Response: \(responseStr)"])
        }
        
        // Decode JSON response
        guard var deviceDetails = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
            throw NSError(domain: "DevicesReporting", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON format."])
        }
        
        return deviceDetails
    }

    /// Retrieves device compliance policy states for a specific managed device
    /// - Parameters:
    ///   - authToken: Valid access token for Microsoft Graph API
    ///   - deviceId: Unique identifier (GUID) of the managed device
    /// - Returns: Array of compliance policy state dictionaries
    /// - Throws: Network errors or JSON parsing errors
    static func getDeviceCompliancePolicyStates(authToken: String, deviceId: String) async throws -> [[String: Any]] {
        let url = "https://graph.microsoft.com/beta/deviceManagement/managedDevices/\(deviceId)/deviceCompliancePolicyStates"
        
        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let responseStr = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "DevicesReporting", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch device compliance policy states. Response: \(responseStr)"])
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
              let policyStates = json["value"] as? [[String: Any]] else {
            throw NSError(domain: "DevicesReporting", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON format for compliance policy states."])
        }
        
        return policyStates
    }

    /// Retrieves device configuration states for a specific managed device
    /// - Parameters:
    ///   - authToken: Valid access token for Microsoft Graph API
    ///   - deviceId: Unique identifier (GUID) of the managed device
    /// - Returns: Array of configuration state dictionaries
    /// - Throws: Network errors or JSON parsing errors
    static func getDeviceConfigurationStates(authToken: String, deviceId: String) async throws -> [[String: Any]] {
        let url = "https://graph.microsoft.com/beta/deviceManagement/managedDevices/\(deviceId)/deviceConfigurationStates"
        
        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let responseStr = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "DevicesReporting", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch device configuration states. Response: \(responseStr)"])
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
              let configStates = json["value"] as? [[String: Any]] else {
            throw NSError(domain: "DevicesReporting", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON format for configuration states."])
        }
        
        return configStates
    }

    /// Retrieves Windows protection state for a specific managed Windows device
    /// - Parameters:
    ///   - authToken: Valid access token for Microsoft Graph API
    ///   - deviceId: Unique identifier (GUID) of the managed Windows device
    /// - Returns: Windows protection state dictionary
    /// - Throws: Network errors or JSON parsing errors
    static func getWindowsProtectionState(authToken: String, deviceId: String) async throws -> [String: Any] {
        let url = "https://graph.microsoft.com/beta/deviceManagement/managedDevices/\(deviceId)/windowsProtectionState"
        
        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let responseStr = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "DevicesReporting", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch Windows protection state. Response: \(responseStr)"])
        }
        
        guard let protectionState = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
            throw NSError(domain: "DevicesReporting", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON format for Windows protection state."])
        }
        
        return protectionState
    }

}
