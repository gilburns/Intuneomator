//
//  XPCServiceProtocol.swift
//  Intuneomator
//
//  Created by Gil Burns on 3/12/25.
//

import Foundation

@objc protocol XPCServiceProtocol {
    func beginOperation(identifier: String, timeout: TimeInterval, completion: @escaping (Bool) -> Void)
    func endOperation(identifier: String, completion: @escaping (Bool) -> Void)
    
    
    func sendMessage(_ message: String, reply: @escaping (String) -> Void)
    
    func ping(completion: @escaping (Bool) -> Void)
    
    func getCertificate(reply: @escaping (Data?) -> Void)
    
    // Entra Auth Settings
    func importP12Certificate(p12Data: Data, passphrase: String, reply: @escaping (Bool) -> Void)
    func privateKeyExists(reply: @escaping (Bool) -> Void)
    
    func importEntraIDSecretKey(secretKey: String, reply: @escaping (Bool) -> Void)
    func entraIDSecretKeyExists(reply: @escaping (Bool) -> Void)
    
    func validateCredentials(reply: @escaping (Bool) -> Void)
    
//    func getCertificateDetails(reply: @escaping (String?) -> Void)
    
    // Main View Controller
    func scanAllManagedLabels(reply: @escaping (Bool) -> Void)
    func updateAppMetadata(_ labelFolderName: String, _ displayName: String, reply: @escaping (String?) -> Void)

    func updateAppScripts(_ labelFolderName: String, _ displayName: String, reply: @escaping (String?) -> Void)

    func updateAppAssignments(_ labelFolderName: String, _ displayName: String, reply: @escaping (String?) -> Void)

    func deleteAutomationsFromIntune(_ labelFolderName: String, _ displayName: String, reply: @escaping (String?) -> Void)

    func onDemandLabelAutomation(_ labelFolderName: String, _ displayName: String, reply: @escaping (String?) -> Void)

    func checkIntuneForAutomation(reply: @escaping (Bool) -> Void)

    // Installomator Labels
    func addNewLabelContent(_ labelName: String, _ source: String, reply: @escaping (String?) -> Void)
    func updateLabelsFromGitHub(reply: @escaping (Bool) -> Void)

    func removeLabelContent(_ labelDirectory: String, reply: @escaping (Bool) -> Void)
    
    // TabView Settings
    func saveLabelContent(_ labelFolder: String, _ content: NSDictionary, reply: @escaping (Bool) -> Void)

    func toggleCustomLabel(_ labelFolder: String, _ toggle: Bool, reply: @escaping (Bool) -> Void)

    // Label Edit View Controller
    func importIconToLabel(_ iconPath: String, _ labelFolder: String, reply: @escaping (Bool) -> Void)
    func importGenericIconToLabel(_ labelFolder: String, reply: @escaping (Bool) -> Void)
    
    func saveMetadataForLabel(_ labelMetadata: String, _ labelFolder: String, reply: @escaping (Bool) -> Void)

    
    
    // Scripts View Controller
    func savePreInstallScriptForLabel(_ script: String, _ labelFolder: String, reply: @escaping (Bool) -> Void)

    func savePostInstallScriptForLabel(_ script: String, _ labelFolder: String, reply: @escaping (Bool) -> Void)

    
    // Group Assignment View Controller
    func saveGroupAssignmentsForLabel(_ groupAssignments: [[String: Any]], _ labelFolder: String, reply: @escaping (Bool) -> Void)
    
    // Discovered Apps
    func fetchDiscoveredMacApps(reply: @escaping (Data?) -> Void)
    
    /// Returns JSON-encoded `[DeviceInfo]` for the given appID, or `nil` on error
    func fetchDevices(forAppID appID: String, reply: @escaping (Data?) -> Void)

    // Task scheduling
    func createOrUpdateScheduledTask(
        label: String,
        argument: String,
        scheduleData: Data,
        withReply reply: @escaping (Bool, String?) -> Void
    )
    
    func removeScheduledTask(
        label: String,
        withReply reply: @escaping (Bool, String?) -> Void
    )
    
    func taskExists(
        label: String,
        withReply reply: @escaping (Bool) -> Void
    )
    
    // Graph API
    func fetchMobileAppCategories(reply: @escaping ([[String: Any]]?) -> Void)
    func fetchEntraGroups(reply: @escaping ([[String: Any]]?) -> Void)
    func fetchAssignmentFiltersForMac(reply: @escaping ([[String: Any]]?) -> Void)
    
    // Send info to Daemon
    func setAppsToKeep(_ appCount: Int, reply: @escaping (Bool) -> Void)
    func setFirstRunStatus(_ completed: Bool, reply: @escaping (Bool) -> Void)
    func setAuthMethod(_ method: String, reply: @escaping (Bool) -> Void)
    func setTenantID(_ tenantID: String, reply: @escaping (Bool) -> Void)
    func setApplicationID(_ applicationID: String, reply: @escaping (Bool) -> Void)
    func setTeamsNotificationsEnabled(_ enabled: Bool, reply: @escaping (Bool) -> Void)
    func setTeamsWebhookURL(_ url: String, reply: @escaping (Bool) -> Void)
    func setLogAgeMax(_ logAgeMax: Int, reply: @escaping (Bool) -> Void)
    func setLogSizeMax(_ logSizeMax: Int, reply: @escaping (Bool) -> Void)

    
    // Get info from daemon
    func getAppsToKeep(reply: @escaping (Int) -> Void)
    func getFirstRunStatus(reply: @escaping (Bool) -> Void)
    func getAuthMethod(reply: @escaping (String) -> Void)
    func getTenantID(reply: @escaping (String) -> Void)
    func getApplicationID(reply: @escaping (String) -> Void)
    func getTeamsNotificationsEnabled(reply: @escaping (Bool) -> Void)
    func getTeamsWebhookURL(reply: @escaping (String) -> Void)
    func getCertThumbprint(reply: @escaping (String?) -> Void)
    func getCertExpiration(reply: @escaping (Date?) -> Void)
    func getClientSecret(reply: @escaping (String?) -> Void)
    func getLogAgeMax(reply: @escaping (Int) -> Void)
    func getLogSizeMax(reply: @escaping (Int) -> Void)

    
    func getCacheFolderSize(completion: @escaping (Int64) -> Void)
    func getLogFolderSize(completion: @escaping (Int64) -> Void)
}
