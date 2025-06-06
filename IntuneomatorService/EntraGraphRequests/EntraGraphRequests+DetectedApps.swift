//
//  EntraGraphRequests+DetectedApps.swift
//  Intuneomator
//
//  Created by Gil Burns on 5/22/25.
//

import Foundation

// MARK: - Detected Applications Extension

/// Extension for handling Microsoft Graph API detected applications operations
/// Provides functionality to discover and analyze applications installed across managed devices
extension EntraGraphRequests {
    
    // MARK: - Detected Applications
    // Microsoft Graph API Reference: https://learn.microsoft.com/en-us/graph/api/intune-devices-detectedapp-list?view=graph-rest-1.0&tabs=http
    
    /// Fetches all detected applications from Microsoft Graph API with pagination support
    /// Used to discover applications installed across all managed devices in the tenant
    /// - Parameter authToken: OAuth bearer token for Microsoft Graph authentication
    /// - Returns: Array of DetectedApp objects representing all discovered applications
    /// - Throws: Network errors, authentication errors, or JSON decoding errors
    static func fetchAllDetectedApps(authToken: String) async throws -> [DetectedApp] {
        let graphEndpoint = "https://graph.microsoft.com/beta/deviceManagement/detectedApps"

        var allApps: [DetectedApp] = []
        var nextLink: String? = graphEndpoint

        // Handle pagination through all results
        while let url = nextLink {
            guard let requestURL = URL(string: url) else {
                throw NSError(domain: "Invalid URL", code: 0, userInfo: nil)
            }

            var request = URLRequest(url: requestURL)
            request.httpMethod = "GET"
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Accept")

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw NSError(domain: "No HTTP response", code: 0, userInfo: nil)
            }

            print("HTTP Status Code: \(httpResponse.statusCode)")

            // Handle permission errors
            if httpResponse.statusCode == 403 {
                Logger.log("Missing permissions. Please grant permissions in Enterprise App settings.")
                throw NSError(domain: "Graph API Forbidden", code: 403, userInfo: nil)
            }

            // Handle other HTTP errors
            if httpResponse.statusCode != 200 {
                if let responseBody = String(data: data, encoding: .utf8) {
                    print("Response Body: \(responseBody)")
                }
                throw NSError(domain: "Invalid server response", code: httpResponse.statusCode, userInfo: nil)
            }

            // Parse JSON response and accumulate results
            do {
                let decodedResponse = try JSONDecoder().decode(GraphResponseDetectedApp.self, from: data)
                allApps.append(contentsOf: decodedResponse.value)
                nextLink = decodedResponse.nextLink
            } catch {
                print("JSON Decoding Error: \(error)")
                throw error
            }
        }

        print(allApps.count)
        return allApps
    }

    /// Fetches detected applications and filters for macOS platform only
    /// Simplifies the detected apps list to focus on relevant macOS applications
    /// - Parameter authToken: OAuth bearer token for Microsoft Graph authentication
    /// - Returns: Array of DetectedApp objects filtered for macOS platform
    /// - Throws: Errors from fetchAllDetectedApps operation
    static func fetchMacOSDetectedApps(authToken: String) async throws -> [DetectedApp] {
        let allApps = try await fetchAllDetectedApps(authToken: authToken)
        
        // Debug output for platform analysis (commented out)
        // print("Checking platforms in detected apps:")
        // for app in allApps {
        //     print(" - \(app.displayName ?? "Unknown App"): \(app.platform ?? "Unknown Platform")")
        // }

        // Filter for macOS applications only
        let macApps = allApps.filter { ($0.platform?.lowercased() ?? "") == "macos" }
        
        print("Found \(macApps.count) macOS apps")
        return macApps
    }

    /// Fetches managed devices that have a specific detected application installed
    /// Used to understand deployment scope and identify devices for targeted management
    /// - Parameters:
    ///   - authToken: OAuth bearer token for Microsoft Graph authentication
    ///   - appID: Unique identifier of the detected application
    /// - Returns: Array of tuples containing device information (name, ID, email)
    /// - Throws: Network errors, authentication errors, or JSON decoding errors
    static func fetchDevices(authToken: String, forAppID appID: String) async throws -> [(deviceName: String, id: String, emailAddress: String)] {
        let graphEndpoint = "https://graph.microsoft.com/beta/deviceManagement/detectedApps"

        // Build URL with OData select for specific device properties
        let urlString = "\(graphEndpoint)/\(appID)/managedDevices?$select=deviceName,id,emailAddress"
        guard let url = URL(string: urlString) else { 
            throw NSError(domain: "Invalid URL", code: 400, userInfo: nil) 
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "Invalid server response", code: (response as? HTTPURLResponse)?.statusCode ?? 500, userInfo: nil)
        }

        // Local structures for parsing device information
        struct APIResponse: Decodable {
            let value: [Device]
        }

        struct Device: Decodable {
            let deviceName: String?
            let id: String?
            let emailAddress: String?
        }

        let decodedResponse = try JSONDecoder().decode(APIResponse.self, from: data)

        // Map to tuples with fallback values for missing data
        return decodedResponse.value.map { 
            ($0.deviceName ?? "Unknown Device", $0.id ?? "Missing ID", $0.emailAddress ?? "No Email") 
        }
    }
}
