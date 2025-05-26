//
//  TeamsNotificationsViewController.swift
//  Intuneomator
//
//  Created by Gil Burns on 3/1/25.
//

import Cocoa

class TeamsNotificationsViewController: NSViewController, WizardStepProtocol {
    var onCompletionStatusChanged: ((Bool) -> Void)?
    var isStepCompleted: Bool { return true }

    private let logType = "Settings"

    @IBOutlet weak var fieldAppsToKeep: NSTextField!
    @IBOutlet weak var fieldLogDirectory: NSTextField!
    
    @IBOutlet weak var buttonSendTeamsNotifications: NSButton!
    @IBOutlet weak var fieldTeamsWebhookURL: NSTextField!

    
    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func viewDidAppear() {
        super.viewDidAppear()

        // Set CheckBox
        XPCManager.shared.getTeamsNotificationsEnabled { isEnabled in
            DispatchQueue.main.async {
                self.buttonSendTeamsNotifications.state = (isEnabled ?? false) ? .on : .off
                self.fieldTeamsWebhookURL.isEnabled = (isEnabled ?? false) ? true : false
            }
        }
        
        // Set Text Field
        XPCManager.shared.getTeamsWebhookURL { url in
            DispatchQueue.main.async {
                self.fieldTeamsWebhookURL.stringValue = url ?? ""
            }
        }
    }
        
    static func create() -> TeamsNotificationsViewController {
        let storyboard = NSStoryboard(name: "Wizard", bundle: nil)
        return storyboard.instantiateController(withIdentifier: "TeamsNotificationsViewController") as! TeamsNotificationsViewController
    }
    
    
    @IBAction func buttonSendTeamsMessageClicked (_ sender: NSButton) {
        Logger.logUser("Send Teams Notifications button clicked", logType: logType)
        Logger.logUser("Button state: \(sender.state)", logType: logType)
        fieldTeamsWebhookURL.isEnabled = sender.state == .on
        
        let isEnabled = sender.state == .on
        XPCManager.shared.setTeamsNotificationsEnabled(isEnabled) { [self] success in
            Logger.logUser("Teams notifications updated: \(success == true ? "✅" : "❌")", logType: logType)
        }
    }

    
    @IBAction func webhookURLChanged(_ sender: NSTextField) {
        let urlString = sender.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        XPCManager.shared.setTeamsWebhookURL(urlString) { [self] success in
            Logger.logUser("Webhook URL updated: \(success == true ? "✅" : "❌")", logType: logType)
        }
    }

}
