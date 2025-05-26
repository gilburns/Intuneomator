//
//  WelcomeWizardViewController.swift
//  Intuneomator
//
//  Created by Gil Burns on 3/1/25.
//

import Cocoa

class WelcomeWizardViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource {
    
    var currentStepIndex = 0
    var stepViewControllers: [NSViewController] = []
    
    var mainWindowController: MainWindowController?

    private let logType = "Settings"
    
    @IBOutlet weak var containerView: NSView!
    
    @IBOutlet weak var nextButton: NSButton!
    @IBOutlet weak var backButton: NSButton!
    
    @IBOutlet weak var tableView: NSTableView!

    struct WizardStep {
        let title: String
        var isActive: Bool
    }
    
    var wizardSteps: [WizardStep] = [
        WizardStep(title: "Introduction", isActive: true),
        WizardStep(title: "Entra ID Setup", isActive: false),
        WizardStep(title: "Authentication", isActive: false),
        WizardStep(title: "Entra ID Settings", isActive: false),
        WizardStep(title: "Notification Settings", isActive: false)
    ]

    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.reloadData()
        
        // Initialize steps (replace with actual View Controllers)
        stepViewControllers = [
            IntroViewController.create(),
            EntraInstructionsViewController.create(),
            AuthChoiceViewController.create(),
            ValidationViewController.create(),
            TeamsNotificationsViewController.create()
        ]

        // Show the first step
        showStep(index: 0)
    }

    
    func showStep(index: Int) {
        guard index >= 0, index < stepViewControllers.count else { return }

        let newVC = stepViewControllers[index]
        let currentVC = children.first

        addChild(newVC)
        newVC.view.frame = containerView.bounds

        if let currentVC = currentVC {
            transition(from: currentVC, to: newVC, options: .crossfade) {
                currentVC.removeFromParent()
            }
        } else {
            containerView.addSubview(newVC.view)
        }

        // ✅ If the new step supports validation, listen for changes
        if var stepVC = newVC as? WizardStepProtocol {
            stepVC.onCompletionStatusChanged = { [weak self] isComplete in
                self?.nextButton.isEnabled = isComplete
            }
            nextButton.isEnabled = stepVC.isStepCompleted // Initial state
        }
        else {
            nextButton.isEnabled = true // Always enable for non-validating steps
        }

        
        // ✅ Update active step (ensuring only one is active at a time)
        for i in 0..<wizardSteps.count {
            wizardSteps[i].isActive = (i == index)
        }

        // ✅ Refresh table so the sidebar updates visually
        tableView.reloadData()

        currentStepIndex = index
        updateButtonStates()
    }

    

    func updateButtonStates() {
        backButton.isEnabled = (currentStepIndex > 0)
//        backButton.isEnabled = false
        nextButton.title = (currentStepIndex == stepViewControllers.count - 1) ? "Finish" : "Next"
    }

    @IBAction func nextButtonClicked(_ sender: NSButton) {
        if currentStepIndex < stepViewControllers.count - 1 {
            showStep(index: currentStepIndex + 1)
        } else {
            finalizeSetup()
        }
    }

    @IBAction func backButtonClicked(_ sender: NSButton) {
        if currentStepIndex > 0 {
            showStep(index: currentStepIndex - 1)
        }
    }

    @IBAction func cancelButtonClicked(_ sender: NSButton) {
        self.view.window?.close()
    }

    func finalizeSetup() {
        Logger.logUser("Wizard completed. Processing configuration...", logType: logType)
        
        XPCManager.shared.setFirstRunCompleted(true) { [self] success in
            Logger.logUser("First run updated: \(success == true ? "✅" : "❌")", logType: logType)
        }

        self.showMainWindow()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.view.window?.close()
        }
    }

    
    func showMainWindow() {
        if mainWindowController == nil {
            let storyboard = NSStoryboard(name: "Main", bundle: nil)
            mainWindowController = storyboard.instantiateController(withIdentifier: "MainWindow") as? MainWindowController
        }

        if let window = mainWindowController?.window {
            window.delegate = mainWindowController // Ensure delegate is set
            window.makeKeyAndOrderFront(nil)
        } else {
            Logger.logUser("Error: mainWindowController has no window.", logType: logType)
        }
    }

    
    // TableView DataSource and Delegate Methods
    func numberOfRows(in tableView: NSTableView) -> Int {
        return wizardSteps.count
    }
    

    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let step = wizardSteps[row]

        if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("StepCell"), owner: nil) as? SidebarTableCellView {
            // Update step text
            cell.textField?.stringValue = step.title
            cell.textField?.font = step.isActive ? NSFont.boldSystemFont(ofSize: 14) : NSFont.systemFont(ofSize: 13)
            cell.textField?.textColor = step.isActive ? NSColor.systemBlue : NSColor.gray

            // ✅ Apply blue tint to the bullet when active
            let imageName = step.isActive ? "largecircle.fill.circle" : "circle"
            if let symbolImage = NSImage(systemSymbolName: imageName, accessibilityDescription: nil) {
                let coloredImage = symbolImage.withSymbolConfiguration(.init(paletteColors: [step.isActive ? NSColor.systemBlue : NSColor.gray]))
                cell.bulletImageView.image = coloredImage
            }

            return cell
        }
        return nil
    }
    
    
    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        return false  // Prevent row selection from changing colors
    }
    
        
    func updateSidebarSelection() {
        tableView.selectRowIndexes(IndexSet(integer: currentStepIndex), byExtendingSelection: false)
    }
    
}

