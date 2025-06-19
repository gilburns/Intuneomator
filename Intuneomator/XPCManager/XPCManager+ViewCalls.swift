//
//  XPCManager+ViewCalls.swift
//  Intuneomator
//
//  Created by Gil Burns on 5/4/25.
//

import Foundation

/// XPCManager extension for main application operations and view controller support
/// Provides GUI access to core automation functionality through the privileged service
/// All operations are executed asynchronously with appropriate error handling
extension XPCManager {
    
    // MARK: - Main Application Operations
    /// Scans and processes all managed Installomator label folders concurrently
    /// Validates folder structure and executes label processing scripts for each managed title
    /// - Parameter completion: Callback with overall success status or nil on XPC failure
    func scanAllInstallomatorManagedLabels(completion: @escaping (Bool?) -> Void) {
        sendRequest({ $0.scanAllManagedLabels(reply: $1) }, completion: completion)
    }
    
    /// Updates metadata for a specific managed application label
    /// Processes folder metadata and synchronizes with Microsoft Graph API
    /// - Parameters:
    ///   - labelFolder: Name of the label folder to process
    ///   - displayName: Human-readable display name for user feedback
    ///   - completion: Callback with success message or nil on XPC failure
    func updateAppMetaData(_ labelFolder: String, _ displayName: String, completion: @escaping (String?) -> Void) {
        sendRequest({ $0.updateAppMetadata(labelFolder, displayName, reply: $1) }, completion: completion)
    }

    /// Updates pre/post-install scripts for a specific managed application label
    /// Processes and uploads custom script content to Microsoft Intune
    /// - Parameters:
    ///   - labelFolder: Name of the label folder to process
    ///   - displayName: Human-readable display name for user feedback
    ///   - completion: Callback with success message or nil on XPC failure
    func updateAppScripts(_ labelFolder: String, _ displayName: String, completion: @escaping (String?) -> Void) {
        sendRequest({ $0.updateAppScripts(labelFolder, displayName, reply: $1) }, completion: completion)
    }

    /// Updates group assignments for a specific managed application label
    /// Processes assignment configurations and applies them to Microsoft Intune
    /// - Parameters:
    ///   - labelFolder: Name of the label folder to process
    ///   - displayName: Human-readable display name for user feedback
    ///   - completion: Callback with success message or nil on XPC failure
    func updateAppAssigments(_ labelFolder: String, _ displayName: String, completion: @escaping (String?) -> Void) {
        sendRequest({ $0.updateAppAssignments(labelFolder, displayName, reply: $1) }, completion: completion)
    }

    /// Removes all automation components from Microsoft Intune for a specific label
    /// Deletes applications, scripts, and assignments associated with the managed title
    /// - Parameters:
    ///   - labelFolder: Name of the label folder to remove from Intune
    ///   - displayName: Human-readable display name for user feedback
    ///   - completion: Callback with success message or nil on XPC failure
    func deleteAutomationsFromIntune(_ labelFolder: String, _ displayName: String, completion: @escaping (String?) -> Void) {
        sendRequest({ $0.deleteAutomationsFromIntune(labelFolder, displayName, reply: $1) }, completion: completion)
    }


    /// Triggers on-demand automation processing for a specific label
    /// Creates trigger file for the Launch Daemon to process the specified label immediately
    /// - Parameters:
    ///   - labelFolder: Name of the label folder to process
    ///   - displayName: Human-readable display name for user feedback
    ///   - completion: Callback with status message or nil on XPC failure
    func onDemandLabelAutomation(_ labelFolder: String, _ displayName: String, completion: @escaping (String?) -> Void) {
        sendRequest({ $0.onDemandLabelAutomation(labelFolder, displayName, reply: $1) }, completion: completion)
    }

    
    /// Verifies existence of managed applications in Microsoft Intune
    /// Scans all managed label folders and checks if corresponding applications exist in Intune
    /// - Parameter completion: Callback with overall verification success status or nil on XPC failure
    func checkIntuneForAutomation(completion: @escaping (Bool?) -> Void) {
        sendRequest({ $0.checkIntuneForAutomation(reply: $1) }, completion: completion)
    }

    
    // MARK: - Label Content Management
    
    /// Creates a new managed label folder with initial content and metadata
    /// Downloads icon, generates metadata, and prepares label for automation processing
    /// - Parameters:
    ///   - newLabel: Name of the Installomator label to create
    ///   - source: Source type ("installomator" or "custom")
    ///   - completion: Callback with new directory path or nil on XPC failure
    func addNewLabel(_ newLabel: String, _ source: String, completion: @escaping (String?) -> Void) {
        sendRequest({ $0.addNewLabelContent(newLabel, source, reply: $1) }, completion: completion)
    }
    
    /// Downloads and updates Installomator labels from the official GitHub repository
    /// Refreshes local label collection with latest versions and new applications
    /// - Parameter completion: Callback with download success status or nil on XPC failure
    func updateLabelsFromGitHub(completion: @escaping (Bool?) -> Void) {
        sendRequest({ $0.updateLabelsFromGitHub(reply: $1) }, completion: completion)
    }
    
    /// Removes a managed label folder and all associated content
    /// Permanently deletes the label directory and all files within it
    /// - Parameters:
    ///   - labelDirectory: Full path to the label directory to remove
    ///   - completion: Callback with removal success status or nil on XPC failure
    func removeLabelContent(_ labelDirectory: String, completion: @escaping (Bool?) -> Void) {
        sendRequest({ $0.removeLabelContent(labelDirectory, reply: $1) }, completion: completion)
    }
    
    // MARK: - Label Configuration Operations
    
    /// Saves label content configuration (placeholder method)
    /// - Parameters:
    ///   - labelFolder: Target label folder name
    ///   - content: Configuration data to save
    ///   - completion: Callback with save operation success status or nil on XPC failure
    func saveLabelContent(_ labelFolder: String, _ content: NSDictionary, completion: @escaping (Bool?) -> Void) {
        sendRequest({ $0.saveLabelContent(labelFolder, content, reply: $1) }, completion: completion)
    }
    
    /// Toggles between standard Installomator and custom label versions
    /// Switches label script source and updates processing accordingly
    /// - Parameters:
    ///   - labelDirectory: Name of the label folder to modify
    ///   - toggle: True to enable custom label, false for standard Installomator
    ///   - completion: Callback with toggle operation success status or nil on XPC failure
    func toggleCustomLabel(_ labelDirectory: String, _ toggle: Bool, completion: @escaping (Bool?) -> Void) {
        sendRequest({ $0.toggleCustomLabel(labelDirectory, toggle, reply: $1) }, completion: completion)
    }

    
    // MARK: - Icon Management Operations
    
    /// Imports an icon file or extracts icon from application bundle for a label
    /// Supports both image files and application bundle icon extraction
    /// - Parameters:
    ///   - iconPath: Path to image file or application bundle
    ///   - labelFolder: Target label folder name
    ///   - completion: Callback with import operation success status or nil on XPC failure
    func importIconToLabel(_ iconPath: String, _ labelFolder: String, completion: @escaping (Bool?) -> Void) {
        sendRequest({ $0.importIconToLabel(iconPath, labelFolder, reply: $1) }, completion: completion)
    }
    
    /// Applies a generic application icon to a label
    /// Uses the default system application icon as fallback
    /// - Parameters:
    ///   - labelFolder: Target label folder name
    ///   - completion: Callback with import operation success status or nil on XPC failure
    func importGenericIconToLabel(_ labelFolder: String, completion: @escaping (Bool?) -> Void) {
        sendRequest({ $0.importGenericIconToLabel(labelFolder, reply: $1) }, completion: completion)
    }
    
    /// Saves application metadata configuration to JSON file
    /// Stores detailed application information for Intune deployment
    /// - Parameters:
    ///   - script: JSON metadata string to save
    ///   - labelFolder: Target label folder name
    ///   - reply: Callback with save operation success status or nil on XPC failure
    func saveMetadataForLabel(_ script: String, _ labelFolder: String, reply: @escaping (Bool?) -> Void) {
        sendRequest({ $0.saveMetadataForLabel(script, labelFolder, reply: $1) }, completion: reply)
    }
    
    // MARK: - Script Management
    
    /// Saves or removes pre-installation script for a label
    /// Handles script content persistence and file permissions
    /// - Parameters:
    ///   - script: Script content (empty string removes the script)
    ///   - labelFolder: Target label folder name
    ///   - reply: Callback with save operation success status or nil on XPC failure
    func savePreInstallScriptToLabel(_ script: String, _ labelFolder: String, reply: @escaping (Bool?) -> Void) {
        sendRequest({ $0.savePreInstallScriptForLabel(script, labelFolder, reply: $1) }, completion: reply)
    }
    
    /// Saves or removes post-installation script for a label
    /// Handles script content persistence and file permissions
    /// - Parameters:
    ///   - script: Script content (empty string removes the script)
    ///   - labelFolder: Target label folder name
    ///   - reply: Callback with save operation success status or nil on XPC failure
    func savePostInstallScriptToLabel(_ script: String, _ labelFolder: String, reply: @escaping (Bool?) -> Void) {
        sendRequest({ $0.savePostInstallScriptForLabel(script, labelFolder, reply: $1) }, completion: reply)
    }
    
    
    // MARK: - Group Assignment Management
    
    /// Saves group assignment configuration for a label
    /// Stores targeting and deployment settings for Microsoft Intune groups
    /// - Parameters:
    ///   - groupAssignments: Array of group assignment dictionaries
    ///   - labelFolder: Target label folder name
    ///   - completion: Callback with save operation success status or nil on XPC failure
    func assignGroupsToLabel(_ groupAssignments: [[String : Any]], _ labelFolder: String, completion: @escaping (Bool?) -> Void) {
        sendRequest({ $0.saveGroupAssignmentsForLabel(groupAssignments, labelFolder, reply: $1) }, completion: completion)
    }
    
    // MARK: - Automation Trigger
    
    /// Triggers daemon for specific types
    /// Creates trigger files for Launch Daemons to process various operations
    /// - Parameters:
    ///   - triggerType: Type of trigger ("automation", "updatecheck", "cachecleaner", "labelupdater")
    ///   - completion: Callback with success status and optional message, or nil on XPC failure
    func triggerDaemon(triggerType: String, completion: @escaping ((Bool, String?)?) -> Void) {
        // Custom implementation since sendRequest doesn't support tuple return types
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let service = self?.connection?.remoteObjectProxyWithErrorHandler({ error in
                Logger.info("XPCManager: XPC connection error during \(triggerType) trigger: \(error)", category: .core, toUserDirectory: true)
                completion(nil)
            }) as? XPCServiceProtocol else {
                completion(nil)
                return
            }
            
            service.triggerDaemon(triggerType: triggerType) { success, message in
                completion((success, message))
            }
        }
    }
    
    /// Checks if automation is currently running
    /// Examines status files to determine if any automation operations are active
    /// - Parameter completion: Callback with running status or nil on XPC failure
    func isAutomationRunning(completion: @escaping (Bool?) -> Void) {
        sendRequest({ $0.isAutomationRunning(reply: $1) }, completion: completion)
    }

}
