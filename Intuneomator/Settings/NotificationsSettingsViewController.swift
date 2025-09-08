//
//  NotificationsSettingsViewController.swift
//  Intuneomator
//
//  Created by Gil Burns on 7/23/25.
//

import Cocoa

/// View controller for managing Teams webhook notification settings
/// Handles webhook configuration and notification preferences
class NotificationsSettingsViewController: NSViewController {
    
    // MARK: - UI Outlets
    
    @IBOutlet weak var buttonSendTeamsNotifications: NSButton!
    @IBOutlet weak var fieldTeamsWebhookURL: NSTextField!
    @IBOutlet weak var buttonSendTeamsNotificationsForCleanup: NSButton!
    @IBOutlet weak var buttonSendTeamsNotificationsForCVEs: NSButton!
    @IBOutlet weak var buttonSendTeamsNotificationsForGroups: NSButton!
    @IBOutlet weak var buttonSendTeamsNotificationsForLabelUpdates: NSButton!
    @IBOutlet weak var buttonSendTeamsNotificationsForUpdates: NSButton!
    @IBOutlet weak var buttonSendTeamsNotificationsStyle: NSPopUpButton!
    
    // MARK: - Properties
    
    /// Parent tabbed sheet view controller for coordination
    weak var parentTabbedSheetViewController: TabbedSheetViewController?
    
    /// Tracks whether any settings have been modified
    var hasUnsavedChanges = false
    
    /// Initial settings data
    private var initialData: [String: Any] = [:]
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupObservers()
        populateFields()
    }
    
    // MARK: - Setup Methods
    
    private func setupNotificationStylePopup() {
        buttonSendTeamsNotificationsStyle.removeAllItems()
        buttonSendTeamsNotificationsStyle.addItems(withTitles: [
            "Send a notification for each software title update",
            "Send a notification each automation run"
        ])
    }
    
    private func setupObservers() {
        fieldTeamsWebhookURL.delegate = self
    }
    
    // MARK: - Actions
    
    @IBAction func teamsNotificationsToggled(_ sender: NSButton) {
        updateNotificationControlsState()
        markAsChanged()
    }
    
    @IBAction func notificationCategoryToggled(_ sender: NSButton) {
        markAsChanged()
    }
    
    @IBAction func notificationStyleChanged(_ sender: NSPopUpButton) {
        markAsChanged()
    }
    
    // MARK: - Helper Methods
    
    private func updateNotificationControlsState() {
        let isEnabled = buttonSendTeamsNotifications.state == .on
        
        fieldTeamsWebhookURL.isEnabled = isEnabled
        buttonSendTeamsNotificationsForCleanup.isEnabled = isEnabled
        buttonSendTeamsNotificationsForCVEs.isEnabled = isEnabled
        buttonSendTeamsNotificationsForGroups.isEnabled = isEnabled
        buttonSendTeamsNotificationsForLabelUpdates.isEnabled = isEnabled
        buttonSendTeamsNotificationsForUpdates.isEnabled = isEnabled
        buttonSendTeamsNotificationsStyle.isEnabled = isEnabled
    }
    
    private func markAsChanged() {
        hasUnsavedChanges = true
        parentTabbedSheetViewController?.updateSaveButtonState()
    }
    
    private func populateFields() {
        // Extract notification settings from initial data
        if let sendNotifications = initialData["sendTeamsNotifications"] as? Bool {
            buttonSendTeamsNotifications.state = sendNotifications ? .on : .off
        }
        
        if let webhookURL = initialData["teamsWebhookURL"] as? String {
            fieldTeamsWebhookURL.stringValue = webhookURL
        }
        
        if let cleanup = initialData["sendNotificationsForCleanup"] as? Bool {
            buttonSendTeamsNotificationsForCleanup.state = cleanup ? .on : .off
        }
        
        if let cves = initialData["sendNotificationsForCVEs"] as? Bool {
            buttonSendTeamsNotificationsForCVEs.state = cves ? .on : .off
        }
        
        if let groups = initialData["sendNotificationsForGroups"] as? Bool {
            buttonSendTeamsNotificationsForGroups.state = groups ? .on : .off
        }
        
        if let labelUpdates = initialData["sendNotificationsForLabelUpdates"] as? Bool {
            buttonSendTeamsNotificationsForLabelUpdates.state = labelUpdates ? .on : .off
        }
        
        if let updates = initialData["sendNotificationsForUpdates"] as? Bool {
            buttonSendTeamsNotificationsForUpdates.state = updates ? .on : .off
        }
        
        if let style = initialData["notificationStyle"] as? Int {
            buttonSendTeamsNotificationsStyle.selectItem(at: style)
        }
        
        updateNotificationControlsState()
    }
}

// MARK: - TabbedSheetChildProtocol

extension NotificationsSettingsViewController: TabbedSheetChildProtocol {
    
    func getDataForSave() -> [String: Any]? {
        // Ensure view is loaded before accessing outlets
        guard isViewLoaded,
              let notificationsButton = buttonSendTeamsNotifications,
              let webhookField = fieldTeamsWebhookURL,
              let cleanupButton = buttonSendTeamsNotificationsForCleanup,
              let cvesButton = buttonSendTeamsNotificationsForCVEs,
              let groupsButton = buttonSendTeamsNotificationsForGroups,
              let labelUpdatesButton = buttonSendTeamsNotificationsForLabelUpdates,
              let updatesButton = buttonSendTeamsNotificationsForUpdates,
              let styleButton = buttonSendTeamsNotificationsStyle else {
            // Return nil if view isn't loaded yet - don't contribute to save data
            return nil
        }
        
        var data: [String: Any] = [:]
        
        data["sendTeamsNotifications"] = notificationsButton.state == .on
        data["teamsWebhookURL"] = webhookField.stringValue
        data["sendNotificationsForCleanup"] = cleanupButton.state == .on
        data["sendNotificationsForCVEs"] = cvesButton.state == .on
        data["sendNotificationsForGroups"] = groupsButton.state == .on
        data["sendNotificationsForLabelUpdates"] = labelUpdatesButton.state == .on
        data["sendNotificationsForUpdates"] = updatesButton.state == .on
        
        if let selectedIndex = styleButton.selectedItem?.tag {
            data["notificationStyle"] = selectedIndex
        }
        
        return data
    }
    
    func setInitialData(_ data: [String: Any]) {
        self.initialData = data
        if isViewLoaded {
            populateFields()
        }
    }
    
    func updateFromOtherTabs(_ combinedData: [String: Any]) {
        // Notification settings typically don't depend on other tabs
    }
    
    func validateData() -> String? {
        // Ensure view is loaded before accessing outlets
        guard isViewLoaded,
              let notificationsButton = buttonSendTeamsNotifications,
              let webhookField = fieldTeamsWebhookURL else {
            return nil // Skip validation if view isn't loaded yet
        }
        
        // Validate webhook URL if notifications are enabled
        if notificationsButton.state == .on {
            let webhookURL = webhookField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if webhookURL.isEmpty {
                return "Teams webhook URL is required when notifications are enabled"
            }
            
            // Basic URL validation
            if !webhookURL.hasPrefix("https://") {
                return "Teams webhook URL must use HTTPS"
            }
            
            // Teams webhooks can come from various Azure services
            let validDomains = [
                "webhook.office.com",        // Traditional Teams webhooks
                "logic.azure.com",           // Logic Apps webhooks
                "outlook.office.com",        // Outlook connectors
                "teams.microsoft.com"        // Teams connectors
            ]
            
            let hasValidDomain = validDomains.contains { domain in
                webhookURL.contains(domain)
            }
            
            if !hasValidDomain {
                return "Invalid Teams webhook URL format"
            }
        }
        
        return nil
    }
}

// MARK: - NSTextFieldDelegate

extension NotificationsSettingsViewController: NSTextFieldDelegate {
    
    func controlTextDidChange(_ obj: Notification) {
        markAsChanged()
    }
}
