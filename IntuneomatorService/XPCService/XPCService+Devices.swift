//
//  XPCService+Devices.swift
//  Intuneomator
//
//  Created by Gil Burns on 7/20/25.
//

import Foundation

/// XPCService extension for Microsoft Intune  managed devices operations
/// Handles secure communication with Microsoft Graph API endpoints for managed devcies operations
/// All operations use authenticated tokens and provide comprehensive error handling through async callbacks
extension XPCService {
    
    // MARK: - Intune Managed Devices
    
    /// Fetches all Intune managed devices from Microsoft Graph with pagination support
    /// Retrieves complete list of managed devices in Intune with automatic pagination
    /// - Parameter reply: Callback with array of custom attribute dictionaries or nil on failure
    func fetchManagedDevices(reply: @escaping ([[String : Any]]?) -> Void) {
        Task {
            do {
                let entraAuthenticator = EntraAuthenticator.shared
                let authToken = try await entraAuthenticator.getEntraIDToken()
                let customAttributes = try await EntraGraphRequests.fetchManagedDevices(authToken: authToken)
                reply(customAttributes)
            } catch {
                Logger.error("Failed to fetch managed devices: \(error.localizedDescription)", category: .core)
                reply(nil)
            }
        }
        
    }

    /// Retrieves comprehensive details about a specific managed device from Microsoft Intune
    /// - Parameters:
    ///   - deviceId: Unique identifier (GUID) of the managed device to retrieve
    ///   - reply: Callback with complete custom attribute details dictionary or nil on failure
    func getManagedDeviceDetails(deviceId: String, reply: @escaping ([String : Any]?) -> Void) {
        Task {
            do {
                let entraAuthenticator = EntraAuthenticator.shared
                let authToken = try await entraAuthenticator.getEntraIDToken()
                let scriptDetails = try await EntraGraphRequests.getManagedDeviceDetails(authToken: authToken, byId: deviceId)
                reply(scriptDetails)
            } catch {
                Logger.error("Failed to get managed device details for ID '\(deviceId)': \(error.localizedDescription)", category: .core)
                reply(nil)
            }
        }
    }

    /// Retrieves device compliance policy states for a specific managed device
    /// - Parameters:
    ///   - deviceId: Unique identifier (GUID) of the managed device
    ///   - reply: Callback with array of compliance policy state dictionaries or nil on failure
    func getDeviceCompliancePolicyStates(deviceId: String, reply: @escaping ([[String: Any]]?) -> Void) {
        Task {
            do {
                let entraAuthenticator = EntraAuthenticator.shared
                let authToken = try await entraAuthenticator.getEntraIDToken()
                let policyStates = try await EntraGraphRequests.getDeviceCompliancePolicyStates(authToken: authToken, deviceId: deviceId)
                reply(policyStates)
            } catch {
                Logger.error("Failed to get device compliance policy states for device '\(deviceId)': \(error.localizedDescription)", category: .core)
                reply(nil)
            }
        }
    }

    /// Retrieves device configuration states for a specific managed device
    /// - Parameters:
    ///   - deviceId: Unique identifier (GUID) of the managed device
    ///   - reply: Callback with array of configuration state dictionaries or nil on failure
    func getDeviceConfigurationStates(deviceId: String, reply: @escaping ([[String: Any]]?) -> Void) {
        Task {
            do {
                let entraAuthenticator = EntraAuthenticator.shared
                let authToken = try await entraAuthenticator.getEntraIDToken()
                let configStates = try await EntraGraphRequests.getDeviceConfigurationStates(authToken: authToken, deviceId: deviceId)
                reply(configStates)
            } catch {
                Logger.error("Failed to get device configuration states for device '\(deviceId)': \(error.localizedDescription)", category: .core)
                reply(nil)
            }
        }
    }

    /// Retrieves Windows protection state for a specific managed Windows device
    /// - Parameters:
    ///   - deviceId: Unique identifier (GUID) of the managed Windows device
    ///   - reply: Callback with Windows protection state dictionary or nil on failure
    func getWindowsProtectionState(deviceId: String, reply: @escaping ([String: Any]?) -> Void) {
        Task {
            do {
                let entraAuthenticator = EntraAuthenticator.shared
                let authToken = try await entraAuthenticator.getEntraIDToken()
                let protectionState = try await EntraGraphRequests.getWindowsProtectionState(authToken: authToken, deviceId: deviceId)
                reply(protectionState)
            } catch {
                Logger.error("Failed to get Windows protection state for device '\(deviceId)': \(error.localizedDescription)", category: .core)
                reply(nil)
            }
        }
    }

}
