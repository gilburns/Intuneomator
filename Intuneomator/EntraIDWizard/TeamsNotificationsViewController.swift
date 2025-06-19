//
//  TeamsNotificationsViewController.swift
//  Intuneomator
//
//  Created by Gil Burns on 3/1/25.
//

import Cocoa

/// Teams notification configuration view controller for the Entra ID setup wizard
/// Provides interface for enabling/disabling Teams webhook notifications and configuring webhook URL
/// Implements WizardStepProtocol for integration with the multi-step wizard flow
class TeamsNotificationsViewController: NSViewController, WizardStepProtocol {
    
    // MARK: - WizardStepProtocol Properties
    
    /// Callback closure for notifying wizard of completion status changes
    var onCompletionStatusChanged: ((Bool) -> Void)?
    
    /// Indicates if this step has been completed (always true as Teams notifications are optional)
    var isStepCompleted: Bool { return true }


    // MARK: - Interface Builder Outlets
    
    /// Text field for configuring number of application versions to retain (appears misplaced in this controller)
    @IBOutlet weak var fieldAppsToKeep: NSTextField!
    
    /// Text field for log directory configuration (appears misplaced in this controller)
    @IBOutlet weak var fieldLogDirectory: NSTextField!
    
    /// Checkbox button for enabling/disabling Teams webhook notifications globally
    @IBOutlet weak var buttonSendTeamsNotifications: NSButton!
    
    /// Text field for entering the Microsoft Teams webhook URL for notifications
    @IBOutlet weak var fieldTeamsWebhookURL: NSTextField!

    
    // MARK: - View Lifecycle Methods
    
    /// Called after the view controller's view is loaded into memory
    /// Performs any additional setup required for the Teams notifications view
    override func viewDidLoad() {
        super.viewDidLoad()
    }

    /// Called when the view controller's view appears on screen
    /// Loads current Teams notification settings from XPC service and updates UI controls
    override func viewDidAppear() {
        super.viewDidAppear()

        // Load and display current Teams notification enabled status
        XPCManager.shared.getTeamsNotificationsEnabled { isEnabled in
            DispatchQueue.main.async {
                self.buttonSendTeamsNotifications.state = (isEnabled ?? false) ? .on : .off
                self.fieldTeamsWebhookURL.isEnabled = (isEnabled ?? false) ? true : false
            }
        }
        
        // Load and display current Teams webhook URL
        XPCManager.shared.getTeamsWebhookURL { url in
            DispatchQueue.main.async {
                self.fieldTeamsWebhookURL.stringValue = url ?? ""
            }
        }
    }
    
    // MARK: - Factory Method
    
    /// Factory method for creating an instance from the Wizard storyboard
    /// Provides type-safe instantiation from storyboard with proper identifier
    /// - Returns: Configured TeamsNotificationsViewController instance
    static func create() -> TeamsNotificationsViewController {
        let storyboard = NSStoryboard(name: "Wizard", bundle: nil)
        return storyboard.instantiateController(withIdentifier: "TeamsNotificationsViewController") as! TeamsNotificationsViewController
    }
    
    
    // MARK: - User Action Methods
    
    /// Handles Teams notification checkbox state changes
    /// Updates notification enabled status and toggles webhook URL field accessibility
    /// - Parameter sender: The checkbox button that triggered the action
    @IBAction func buttonSendTeamsMessageClicked (_ sender: NSButton) {
        Logger.info("Send Teams Notifications button clicked", category: .core, toUserDirectory: true)
        Logger.info("Button state: \(sender.state)", category: .core, toUserDirectory: true)
        fieldTeamsWebhookURL.isEnabled = sender.state == .on
        
        let isEnabled = sender.state == .on
        XPCManager.shared.setTeamsNotificationsEnabled(isEnabled) { success in
            Logger.info("Teams notifications updated: \(success == true ? "✅" : "❌")", category: .core, toUserDirectory: true)
        }
    }

    /// Handles Teams webhook URL text field changes
    /// Updates the stored webhook URL whenever the user modifies the text field content
    /// - Parameter sender: The text field containing the updated webhook URL
    @IBAction func webhookURLChanged(_ sender: NSTextField) {
        let urlString = sender.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        XPCManager.shared.setTeamsWebhookURL(urlString) { success in
            Logger.info("Webhook URL updated: \(success == true ? "✅" : "❌")", category: .core, toUserDirectory: true)
        }
    }

    
    // MARK: - WizardStepProtocol Implementation
    
    /// Determines if the user can proceed from this wizard step
    /// Teams notifications are optional, so always returns true
    /// - Returns: Always true as Teams notification configuration is optional
    func canProceed() -> Bool {
        return true
    }
    
    /// Validates the current wizard step before proceeding
    /// Teams notifications require no validation, so always returns true
    /// - Returns: Always true as notification settings have no validation requirements
    func validateStep() -> Bool {
        return true
    }
    
    /// Provides the title for this wizard step for UI display
    /// Used by the wizard controller for step navigation and progress indication
    /// - Returns: Localized title string for the Teams notification configuration step
    func getStepTitle() -> String {
        return "Notification Settings"
    }
    
    /// Provides a description of this wizard step for UI display
    /// Used by the wizard controller for step information and progress indication
    /// - Returns: Localized description string explaining the Teams notification configuration purpose
    func getStepDescription() -> String {
        return "Configure Teams notifications"
    }

}
