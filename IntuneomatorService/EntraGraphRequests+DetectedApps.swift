//
//  EntraGraphRequests+DetectedApps.swift
//  Intuneomator
//
//  Created by Gil Burns on 5/22/25.
//

import Foundation
import CommonCrypto

extension EntraGraphRequests {
    
    // MARK: - Detected Applications
    // https://learn.microsoft.com/en-us/graph/api/intune-devices-detectedapp-list?view=graph-rest-1.0&tabs=http
    
    
    /// Fetches all detected apps from Microsoft Graph, handling pagination.
    static func fetchAllDetectedApps(authToken: String) async throws -> [DetectedApp] {
        
        let graphEndpoint = "https://graph.microsoft.com/beta/deviceManagement/detectedApps"

        var allApps: [DetectedApp] = []
        var nextLink: String? = graphEndpoint


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

            print("ℹ️ HTTP Status Code: \(httpResponse.statusCode)")

            if httpResponse.statusCode == 403 {
                Logger.log("Missing permissions. Please grant permissions in Enterprise App settings.")
                throw NSError(domain: "Graph API Forbidden", code: 403, userInfo: nil)
            }

            if httpResponse.statusCode != 200 {
                if let responseBody = String(data: data, encoding: .utf8) {
                    print("❌ Response Body: \(responseBody)")
                }
                throw NSError(domain: "Invalid server response", code: httpResponse.statusCode, userInfo: nil)
            }

            do {
                let decodedResponse = try JSONDecoder().decode(GraphResponseDetectedApp.self, from: data)
                allApps.append(contentsOf: decodedResponse.value)
                nextLink = decodedResponse.nextLink
            } catch {
                print("❌ JSON Decoding Error: \(error)")
                throw error
            }
        }

        print(allApps.count)
        return allApps
    }

    
    /// Fetches and filters detected apps to return only macOS applications.
    static func fetchMacOSDetectedApps(authToken: String) async throws -> [DetectedApp] {
        let allApps = try await fetchAllDetectedApps(authToken: authToken)
        
//        print("🔍 Checking platforms in detected apps:")
//        for app in allApps {
//            print(" - \(app.displayName ?? "Unknown App"): \(app.platform ?? "Unknown Platform")")
//        }

        let macApps = allApps.filter { ($0.platform?.lowercased() ?? "") == "macos" }
        
        print("✅ Found \(macApps.count) macOS apps")
        return macApps
    }

    
    // Function to fetch devices for a given detected app ID
    static func fetchDevices(authToken: String, forAppID appID: String) async throws -> [(deviceName: String, id: String, emailAddress: String)] {
        
        let graphEndpoint = "https://graph.microsoft.com/beta/deviceManagement/detectedApps"

        let urlString = "\(graphEndpoint)/\(appID)/managedDevices?$select=deviceName,id,emailAddress"
        guard let url = URL(string: urlString) else { throw NSError(domain: "Invalid URL", code: 400, userInfo: nil) }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "Invalid server response", code: (response as? HTTPURLResponse)?.statusCode ?? 500, userInfo: nil)
        }

        // Parse JSON response
        struct APIResponse: Decodable {
            let value: [Device]
        }

        struct Device: Decodable {
            let deviceName: String?
            let id: String?
            let emailAddress: String?
        }

        let decodedResponse = try JSONDecoder().decode(APIResponse.self, from: data)

        return decodedResponse.value.map { ($0.deviceName ?? "Unknown Device", $0.id ?? "Missing ID", $0.emailAddress ?? "No Email") }
    }

}
