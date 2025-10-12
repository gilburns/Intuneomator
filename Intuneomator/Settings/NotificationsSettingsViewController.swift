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
    
    @IBOutlet weak var buttonTestTeamsWebhook: NSButton!
    
    
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
        updateTestButtonState()
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
    
    
    @IBAction func testTeamsWebhook(_ sender: Any) {
        // Get the current webhook URL from the text field
        let webhookURL = fieldTeamsWebhookURL.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)

        // Test the URL directly without saving it first
        XPCManager.shared.sendTeamsTestNotification(withURL: webhookURL) { success in
            DispatchQueue.main.async {
                if let success = success {
                    if success {
                        // Show success alert
                        let alert = NSAlert()
                        alert.messageText = "Test Notification Sent"
                        alert.informativeText = "Your Teams webhook is configured correctly! Check your Teams channel for the test message."
                        alert.alertStyle = .informational
                        alert.addButton(withTitle: "OK")
                        alert.runModal()
                    } else {
                        // Show error alert
                        let alert = NSAlert()
                        alert.messageText = "Test Failed"
                        alert.informativeText = "Failed to send test notification. Please verify your webhook URL is correct and try again."
                        alert.alertStyle = .warning
                        alert.addButton(withTitle: "OK")
                        alert.runModal()
                    }
                } else {
                    // XPC connection failed
                    let alert = NSAlert()
                    alert.messageText = "Service Error"
                    alert.informativeText = "Failed to communicate with the Intuneomator service."
                    alert.alertStyle = .critical
                    alert.addButton(withTitle: "OK")
                    alert.runModal()
                }
            }
        }
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
        updateTestButtonState()
    }

    /// Updates the test button enabled state based on webhook URL validity
    private func updateTestButtonState() {
        let webhookURL = fieldTeamsWebhookURL.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)

        // Enable test button only if webhook URL is not empty and looks valid
        let isValid = !webhookURL.isEmpty && webhookURL.hasPrefix("https://")
        buttonTestTeamsWebhook.isEnabled = isValid
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
        updateTestButtonState()
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
                "teams.microsoft.com",       // Teams connectors
                "powerplatform.com",         // PowerPlatform
                "https"                      // Any https URL
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
        updateTestButtonState()
    }
}
