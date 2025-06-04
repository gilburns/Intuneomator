//
//  IntroViewController.swift
//  Intuneomator
//
//  Created by Gil Burns on 3/1/25.
//

import Cocoa

/// Introduction view controller for the Entra ID setup wizard
/// Provides welcome message and access to application license information
/// Implements WizardStepProtocol for integration with the multi-step wizard flow
class IntroViewController: NSViewController, WizardStepProtocol {
    
    // MARK: - WizardStepProtocol Properties
    
    /// Callback closure for notifying wizard of completion status changes
    var onCompletionStatusChanged: ((Bool) -> Void)?
    
    /// Indicates if this step has been completed (always true for introductory step)
    var isStepCompleted: Bool { return true } // Read-only step, so always complete

    
    /// Called after the view controller's view is loaded into memory
    /// Performs any additional setup required for the introduction view
    override func viewDidLoad() {
        super.viewDidLoad()
    }

    /// Factory method for creating an instance from the Wizard storyboard
    /// Provides type-safe instantiation from storyboard with proper identifier
    /// - Returns: Configured IntroViewController instance
    static func create() -> IntroViewController {
        let storyboard = NSStoryboard(name: "Wizard", bundle: nil)
        return storyboard.instantiateController(withIdentifier: "IntroViewController") as! IntroViewController
    }

    /// Handles view license button click to display application license information
    /// Presents the license view controller as a modal sheet
    /// - Parameter sender: The view license button that triggered the action
    @IBAction func viewLicenseClicked(_ sender: NSButton) {
        showLicenseSheet()
    }

    /// Instantiates and presents the license view controller as a modal sheet
    /// Loads the license view controller from storyboard and displays it modally
    func showLicenseSheet() {
        let storyboard = NSStoryboard(name: "Wizard", bundle: nil)
        if let licenseVC = storyboard.instantiateController(withIdentifier: "LicenseViewController") as? LicenseViewController {
            self.presentAsSheet(licenseVC)
        }
    }

    
    
    // MARK: - WizardStepProtocol Implementation
    
    /// Determines if the user can proceed from this wizard step
    /// Introduction screen has no validation requirements, so always returns true
    /// - Returns: Always true as introduction screen requires no user input
    func canProceed() -> Bool {
        return true
    }
    
    /// Validates the current wizard step before proceeding
    /// Introduction screen has no validation requirements, so always returns true
    /// - Returns: Always true as introduction screen has no validation logic
    func validateStep() -> Bool {
        return true
    }
    
    /// Provides the title for this wizard step for UI display
    /// Used by the wizard controller for step navigation and progress indication
    /// - Returns: Localized title string for the introduction step
    func getStepTitle() -> String {
        return "Introduction"
    }
    
    /// Provides a description of this wizard step for UI display
    /// Used by the wizard controller for step information and progress indication
    /// - Returns: Localized description string explaining the introduction step purpose
    func getStepDescription() -> String {
        return "Welcome to Intuneomator setup"
    }
    
    // MARK: - Legacy Code (Commented Out)
    // Alternative programmatic view setup approach - preserved for reference
    //    override func loadView() {
    //        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 500, height: 300))
    //        let label = NSTextField(labelWithString: "Welcome to the Setup Wizard!")
    //        label.frame = NSRect(x: 20, y: 100, width: 460, height: 20)
    //        view.addSubview(label)
    //    }
    
}
