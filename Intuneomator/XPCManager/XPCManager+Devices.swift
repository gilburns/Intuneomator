//
//  XPCManager+Devices.swift
//  Intuneomator
//
//  Created by Gil Burns on 7/20/25.
//

import Foundation

/// XPCManager extension for Microsoft Intune Device management
/// Provides GUI access to custom attribute operations through the privileged XPC service
/// All operations require valid authentication credentials and appropriate Microsoft Graph permissions
extension XPCManager {
    // MARK: - Intune Managed Devices Operations
    
    /// Retrieves all Intune managed device from Microsoft Graph with comprehensive pagination support
    ///
    /// This function fetches all managed devices  in Microsoft Intune by following
    /// pagination links until complete data retrieval. Designed for large environments with
    /// hundreds of devices.
    ///
    /// **Usage Example:**
    /// ```swift
    /// XPCManager.shared.fetchManagedDevices { devices in
    ///     if let devices = devices {
    ///         print("Found \(devices.count) managed devices")
    ///         for devices in devices {
    ///             print("- \(devices["deviceName"] as? String ?? "Unknown")")
    ///         }
    ///     } else {
    ///         print("Failed to fetch managed devices")
    ///     }
    /// }
    /// ```
    ///
    /// **Required Permissions:**
    /// - DeviceManagement.Read.All (Application or Delegated)
    ///
    /// - Parameter completion: Callback with array of managed devices dictionaries (sorted by device name) or nil on failure
    func fetchManagedDevices(completion: @escaping ([[String: Any]]?) -> Void) {
        sendRequest({ $0.fetchManagedDevices(reply: $1) }, completion: completion)
    }

    /// Retrieves comprehensive details about a specific managed device from Microsoft Intune
    ///
    /// This function fetches complete metadata for a specific managed device,
    /// Perfect for device management interfaces and viewing workflows.
    ///
    /// **Usage Example:**
    /// ```swift
    /// XPCManager.shared.getManagedDeviceDetails(deviceId: "12345-abcde-67890") { details in
    ///     if let details = details {
    ///         print("Device: \(details["deviceName"] as? String ?? "Unknown")")
    ///     } else {
    ///         print("Failed to fetch managed device details")
    ///     }
    /// }
    /// ```
    ///
    /// **Required Permissions:**
    /// - DeviceManagementConfiguration.Read.All (Application or Delegated)
    ///
    /// - Parameters:
    ///   - deviceId: Unique identifier (GUID) of the custom attribute to retrieve
    ///   - completion: Callback with complete custom attribute details dictionary or nil on failure
    func getManagedDeviceDetails(deviceId: String, completion: @escaping ([String: Any]?) -> Void) {
        sendRequest({ service, reply in
            service.getManagedDeviceDetails(deviceId: deviceId, reply: reply)
        }, completion: completion)
    }

    /// Retrieves device compliance policy states for a specific managed device
    ///
    /// This function fetches all compliance policy states applied to a specific device,
    /// showing which policies are assigned and their current compliance status.
    ///
    /// **Usage Example:**
    /// ```swift
    /// XPCManager.shared.getDeviceCompliancePolicyStates(deviceId: "12345-abcde-67890") { states in
    ///     if let states = states {
    ///         print("Found \(states.count) compliance policies")
    ///         for state in states {
    ///             print("- \(state["displayName"] as? String ?? "Unknown"): \(state["state"] as? String ?? "Unknown")")
    ///         }
    ///     }
    /// }
    /// ```
    ///
    /// **Required Permissions:**
    /// - DeviceManagementConfiguration.Read.All
    ///
    /// - Parameters:
    ///   - deviceId: Unique identifier (GUID) of the managed device
    ///   - completion: Callback with array of compliance policy state dictionaries or nil on failure
    func getDeviceCompliancePolicyStates(deviceId: String, completion: @escaping ([[String: Any]]?) -> Void) {
        sendRequest({ service, reply in
            service.getDeviceCompliancePolicyStates(deviceId: deviceId, reply: reply)
        }, completion: completion)
    }

    /// Retrieves device configuration states for a specific managed device
    ///
    /// This function fetches all configuration profile states applied to a specific device,
    /// showing which configuration policies are assigned and their current status.
    ///
    /// **Usage Example:**
    /// ```swift
    /// XPCManager.shared.getDeviceConfigurationStates(deviceId: "12345-abcde-67890") { states in
    ///     if let states = states {
    ///         print("Found \(states.count) configuration policies")
    ///         for state in states {
    ///             print("- \(state["displayName"] as? String ?? "Unknown"): \(state["state"] as? String ?? "Unknown")")
    ///         }
    ///     }
    /// }
    /// ```
    ///
    /// **Required Permissions:**
    /// - DeviceManagementConfiguration.Read.All
    ///
    /// - Parameters:
    ///   - deviceId: Unique identifier (GUID) of the managed device
    ///   - completion: Callback with array of configuration state dictionaries or nil on failure
    func getDeviceConfigurationStates(deviceId: String, completion: @escaping ([[String: Any]]?) -> Void) {
        sendRequest({ service, reply in
            service.getDeviceConfigurationStates(deviceId: deviceId, reply: reply)
        }, completion: completion)
    }

    /// Retrieves Windows protection state for a specific managed Windows device
    ///
    /// This function fetches Windows Defender and security-related status information
    /// for Windows devices, including antivirus, firewall, and threat protection states.
    ///
    /// **Usage Example:**
    /// ```swift
    /// XPCManager.shared.getWindowsProtectionState(deviceId: "12345-abcde-67890") { state in
    ///     if let state = state {
    ///         print("Windows Protection State: \(state["realTimeProtectionEnabled"] as? Bool ?? false)")
    ///     }
    /// }
    /// ```
    ///
    /// **Required Permissions:**
    /// - DeviceManagementConfiguration.Read.All
    ///
    /// - Parameters:
    ///   - deviceId: Unique identifier (GUID) of the managed Windows device
    ///   - completion: Callback with Windows protection state dictionary or nil on failure
    func getWindowsProtectionState(deviceId: String, completion: @escaping ([String: Any]?) -> Void) {
        sendRequest({ service, reply in
            service.getWindowsProtectionState(deviceId: deviceId, reply: reply)
        }, completion: completion)
    }

}
