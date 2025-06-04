//
//  WelcomeWizardViewController.swift
//  Intuneomator
//
//  Created by Gil Burns on 3/1/25.
//

import Cocoa

/// Main coordinator view controller for the Entra ID setup wizard
/// Manages multi-step wizard flow with sidebar navigation and step validation
/// Handles transition between setup steps and final configuration completion
class WelcomeWizardViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource {
    
    /// Current active step index in the wizard flow
    var currentStepIndex = 0
    
    /// Array of view controllers representing each wizard step
    var stepViewControllers: [NSViewController] = []
    
    /// Reference to main window controller for post-setup navigation
    var mainWindowController: MainWindowController?

    /// Log type identifier for logging operations
    private let logType = "Settings"
    
    // MARK: - Interface Builder Outlets
    
    /// Container view that hosts the current wizard step's view
    @IBOutlet weak var containerView: NSView!
    
    /// Button to advance to the next wizard step or complete setup
    @IBOutlet weak var nextButton: NSButton!
    
    /// Button to return to the previous wizard step
    @IBOutlet weak var backButton: NSButton!
    
    /// Table view displaying wizard steps in the sidebar for navigation
    @IBOutlet weak var tableView: NSTableView!

    /// Data structure representing a single step in the wizard flow
    /// Used for sidebar display and navigation state management
    struct WizardStep {
        /// Display title for the wizard step
        let title: String
        /// Whether this step is currently active/selected
        var isActive: Bool
    }
    
    /// Array of wizard steps defining the complete setup flow
    /// Each step corresponds to a specific configuration aspect
    var wizardSteps: [WizardStep] = [
        WizardStep(title: "Introduction", isActive: true),
        WizardStep(title: "Entra ID Setup", isActive: false),
        WizardStep(title: "Authentication", isActive: false),
        WizardStep(title: "Entra ID Settings", isActive: false),
        WizardStep(title: "Notification Settings", isActive: false)
    ]

    
    /// Called after the view controller's view is loaded into memory
    /// Configures table view, initializes step view controllers, and displays first step
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Configure sidebar table view
        tableView.delegate = self
        tableView.dataSource = self
        tableView.reloadData()
        
        // Initialize wizard step view controllers in order
        stepViewControllers = [
            IntroViewController.create(),
            EntraInstructionsViewController.create(),
            AuthChoiceViewController.create(),
            ValidationViewController.create(),
            TeamsNotificationsViewController.create()
        ]

        // Display the initial introduction step
        showStep(index: 0)
    }

    
    /// Displays a specific wizard step by index with smooth transition animation
    /// Handles view controller lifecycle, validation setup, and UI state updates
    /// - Parameter index: Zero-based index of the step to display
    func showStep(index: Int) {
        guard index >= 0, index < stepViewControllers.count else { return }

        let newVC = stepViewControllers[index]
        let currentVC = children.first

        // Add new view controller and configure view frame
        addChild(newVC)
        newVC.view.frame = containerView.bounds

        // Perform crossfade transition or initial display
        if let currentVC = currentVC {
            transition(from: currentVC, to: newVC, options: .crossfade) {
                currentVC.removeFromParent()
            }
        } else {
            containerView.addSubview(newVC.view)
        }

        // Configure step validation if the view controller supports it
        if var stepVC = newVC as? WizardStepProtocol {
            stepVC.onCompletionStatusChanged = { [weak self] isComplete in
                self?.nextButton.isEnabled = isComplete
            }
            nextButton.isEnabled = stepVC.isStepCompleted // Set initial validation state
        }
        else {
            nextButton.isEnabled = true // Always enable for non-validating steps
        }

        // Update sidebar to reflect active step
        for i in 0..<wizardSteps.count {
            wizardSteps[i].isActive = (i == index)
        }

        // Refresh table view to show visual changes
        tableView.reloadData()

        currentStepIndex = index
        updateButtonStates()
    }

    

    /// Updates navigation button states based on current wizard position
    /// Enables/disables back button and sets appropriate next button text
    func updateButtonStates() {
        backButton.isEnabled = (currentStepIndex > 0)
        nextButton.title = (currentStepIndex == stepViewControllers.count - 1) ? "Finish" : "Next"
    }

    /// Handles next button click to advance wizard or complete setup
    /// Proceeds to next step or calls finalization if on the last step
    /// - Parameter sender: The next/finish button that triggered the action
    @IBAction func nextButtonClicked(_ sender: NSButton) {
        if currentStepIndex < stepViewControllers.count - 1 {
            showStep(index: currentStepIndex + 1)
        } else {
            finalizeSetup()
        }
    }

    /// Handles back button click to return to previous wizard step
    /// Only navigates backwards if not on the first step
    /// - Parameter sender: The back button that triggered the action
    @IBAction func backButtonClicked(_ sender: NSButton) {
        if currentStepIndex > 0 {
            showStep(index: currentStepIndex - 1)
        }
    }

    /// Handles cancel button click to exit the wizard without completing setup
    /// Closes the wizard window without saving configuration changes
    /// - Parameter sender: The cancel button that triggered the action
    @IBAction func cancelButtonClicked(_ sender: NSButton) {
        self.view.window?.close()
    }

    /// Completes the wizard setup process and transitions to main application
    /// Marks first run as completed, shows main window, and closes wizard
    func finalizeSetup() {
        Logger.logUser("Wizard completed. Processing configuration...", logType: logType)
        
        // Update first run completion status via XPC
        XPCManager.shared.setFirstRunCompleted(true) { [self] success in
            Logger.logUser("First run updated: \(success == true ? "✅" : "❌")", logType: logType)
        }

        // Show main application window
        self.showMainWindow()

        // Close wizard window after brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.view.window?.close()
        }
    }

    
    /// Instantiates and displays the main application window after wizard completion
    /// Lazy-loads the main window controller from storyboard if not already created
    func showMainWindow() {
        // Create main window controller if not already instantiated
        if mainWindowController == nil {
            let storyboard = NSStoryboard(name: "Main", bundle: nil)
            mainWindowController = storyboard.instantiateController(withIdentifier: "MainWindow") as? MainWindowController
        }

        // Display main window and bring to front
        if let window = mainWindowController?.window {
            window.delegate = mainWindowController // Ensure delegate is properly set
            window.makeKeyAndOrderFront(nil)
        } else {
            Logger.logUser("Error: mainWindowController has no window.", logType: logType)
        }
    }

    
    // MARK: - NSTableViewDataSource Methods
    
    /// Returns the number of rows in the wizard steps table view
    /// - Parameter tableView: The table view requesting the row count
    /// - Returns: Number of wizard steps for sidebar display
    func numberOfRows(in tableView: NSTableView) -> Int {
        return wizardSteps.count
    }
    

    
    /// Creates and configures table view cells for wizard step display
    /// Applies visual styling based on step active state
    /// - Parameters:
    ///   - tableView: The table view requesting the cell
    ///   - tableColumn: The table column (unused in this implementation)
    ///   - row: The row index corresponding to wizard step
    /// - Returns: Configured SidebarTableCellView or nil if creation fails
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let step = wizardSteps[row]

        if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("StepCell"), owner: nil) as? SidebarTableCellView {
            // Configure step title with appropriate styling
            cell.textField?.stringValue = step.title
            cell.textField?.font = step.isActive ? NSFont.boldSystemFont(ofSize: 14) : NSFont.systemFont(ofSize: 13)
            cell.textField?.textColor = step.isActive ? NSColor.systemBlue : NSColor.gray

            // Configure bullet point icon with active state styling
            let imageName = step.isActive ? "largecircle.fill.circle" : "circle"
            if let symbolImage = NSImage(systemSymbolName: imageName, accessibilityDescription: nil) {
                let coloredImage = symbolImage.withSymbolConfiguration(.init(paletteColors: [step.isActive ? NSColor.systemBlue : NSColor.gray]))
                cell.bulletImageView.image = coloredImage
            }

            return cell
        }
        return nil
    }
    
    
    /// Prevents row selection in the wizard steps table view
    /// Maintains custom visual styling without selection highlighting
    /// - Parameters:
    ///   - tableView: The table view requesting selection permission
    ///   - row: The row index being considered for selection
    /// - Returns: Always false to prevent selection
    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        return false  // Prevent row selection from changing colors
    }
    
        
    /// Updates sidebar selection to reflect current wizard step
    /// Programmatically selects the row corresponding to active step
    func updateSidebarSelection() {
        tableView.selectRowIndexes(IndexSet(integer: currentStepIndex), byExtendingSelection: false)
    }
    
}

