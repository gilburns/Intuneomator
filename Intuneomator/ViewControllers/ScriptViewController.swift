//
//  ScriptViewController.swift
//  Intuneomator
//
//  Created by Gil Burns on 1/11/25.
//

import Foundation
import Cocoa

class ScriptViewController: NSViewController, NSTextViewDelegate, Configurable, UnsavedChangesHandling {
    
    @IBOutlet weak var scriptsTabView: NSTabView!
    @IBOutlet weak var scriptsTabButtonsStackView: NSStackView! // A vertical stack view for buttons
    
    @IBOutlet weak var fieldPreInstallScript: NSTextView!
    @IBOutlet weak var fieldPostInstallScript: NSTextView!
    @IBOutlet weak var warningLabel: NSTextField! // Label to show warnings about invalid scripts
    @IBOutlet weak var unavailableLabel: NSTextField!
    @IBOutlet weak var importButton: NSButton! // Outlet for the Import button


    private var tabButtons: [NSButton] = [] // To keep track of buttons

    var appData: AppInfo?
    var parentTabViewController: TabViewController?
    var hasUnsavedChanges: Bool = false

    // Saved Script States
    var savedPreInstallScript: String = ""
    var savedPostInstallScript: String = ""
    
    // Create a reusable HelpPopover instance
    private let helpPopover = HelpPopover()

// MARK: - Configuration
    func configure(with data: Any, parent: TabViewController) {
        guard let appData = data as? AppInfo else {
            print("Invalid data passed to ScriptViewController")
            return
        }
        self.appData = appData
        self.parentTabViewController = parent
    }


// MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
//        print("ScriptViewController loaded and ready.")

        // Use appData to configure the view
        guard appData != nil else {
            print("Error: appData is nil in ScriptViewController viewDidLoad.")
            return
        }
//        print("Received appData in ScriptViewController: \(appData)")
        
        // Set up custom tab buttons
        setupCustomTabButtons()
        updateButtonStates(selectedIndex: 0) // Default to the first tab
                
        // Load the contents of the script files into the text fields
        loadScriptFields()

        // Set up observers for text field changes
        fieldPreInstallScript.delegate = self
        fieldPostInstallScript.delegate = self

        // Initialize the Save button state
        updateSaveButtonState()
        
        setupImportButton()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
//        print("isValid called in viewDidAppear: \(isValid)")
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        updateScriptAvailability()
    }
    
    private func updateScriptAvailability() {
        let appType = AppDataManager.shared.currentAppType
        switch appType {
        case "macOSLobApp":
            fieldPreInstallScript.isEditable = false
            fieldPostInstallScript.isEditable = false
            importButton.isEnabled = false
            unavailableLabel.isHidden = false
        case "macOSPkgApp":
            fieldPreInstallScript.isEditable = true
            fieldPostInstallScript.isEditable = true
            importButton.isEnabled = true
            unavailableLabel.isHidden = true
        case "macOSDmgApp":
            fieldPreInstallScript.isEditable = false
            fieldPostInstallScript.isEditable = false
            importButton.isEnabled = false
            unavailableLabel.isHidden = false
        default:
            fieldPreInstallScript.isEditable = false
            fieldPostInstallScript.isEditable = false
            importButton.isEnabled = false
            unavailableLabel.isHidden = false
        }
    }

// MARK: - Actions
    @IBAction func importScript(_ sender: Any) {
        // Determine the currently selected tab
        guard let selectedTab = scriptsTabView.selectedTabViewItem else { return }
        
        // Get the target text field based on the tab
        let targetField: NSTextView
        switch selectedTab.label {
        case "Pre-install Script":
            targetField = fieldPreInstallScript
        case "Post-install Script":
            targetField = fieldPostInstallScript
        default:
            return
        }
        print("Import Script for \(selectedTab.label)")

        // Show a warning if the target field already has content
        if !targetField.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let alert = NSAlert()
            alert.messageText = "Overwrite Existing Script?"
            alert.informativeText = "This will overwrite the existing content in the script field. Do you want to continue?"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Yes")
            alert.addButton(withTitle: "No")
            let response = alert.runModal()
            if response != .alertFirstButtonReturn { return }
        }
        
        // Open file dialog
        let dialog = NSOpenPanel()
        dialog.canChooseFiles = true
        dialog.canChooseDirectories = false
        dialog.showsHiddenFiles = false
        dialog.message = "Select a \(selectedTab.label) Script File"
        dialog.prompt = "Import \(selectedTab.label) Script File"
        dialog.allowedFileTypes = ["sh", "bash", "zsh", "ksh", "ps1", "python", "txt"]
        dialog.allowsMultipleSelection = false
        
        if dialog.runModal() == .OK, let fileURL = dialog.url {
            do {
                let fileContents = try String(contentsOf: fileURL, encoding: .utf8)
                targetField.string = fileContents
            } catch {
                let alert = NSAlert()
                alert.messageText = "Error Importing Script"
                alert.informativeText = "Unable to read the file. Please try again."
                alert.alertStyle = .critical
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
        }
        
    }
    
    private func updateSaveButtonState() {
        let maxScriptLength = 15360

        // Get trimmed contents of both fields
        let preInstallContents = fieldPreInstallScript.string.trimmingCharacters(in: .whitespacesAndNewlines)
        let postInstallContents = fieldPostInstallScript.string.trimmingCharacters(in: .whitespacesAndNewlines)

        // Validation checks: a script is valid if it's empty or starts with "#!" and is within the max length.
        let isPreInstallValid = preInstallContents.isEmpty || (preInstallContents.starts(with: "#!") && preInstallContents.count <= maxScriptLength)
        let isPostInstallValid = postInstallContents.isEmpty || (postInstallContents.starts(with: "#!") && postInstallContents.count <= maxScriptLength)

        // Build dynamic warnings based on validation errors.
        var warnings: [String] = []

        if !isPreInstallValid {
            if !preInstallContents.starts(with: "#!") && !preInstallContents.isEmpty {
                warnings.append("Preinstall script must start with '#!'.")
            }
            if preInstallContents.count > maxScriptLength {
                warnings.append("Preinstall script exceeds the maximum length of \(maxScriptLength) characters.")
            }
        }

        if !isPostInstallValid {
            if !postInstallContents.starts(with: "#!") && !postInstallContents.isEmpty {
                warnings.append("Postinstall script must start with '#!'.")
            }
            if postInstallContents.count > maxScriptLength {
                warnings.append("Postinstall script exceeds the maximum length of \(maxScriptLength) characters.")
            }
        }

        // Update warnings UI.
        if warnings.isEmpty {
            warningLabel.isHidden = true
            warningLabel.stringValue = ""
        } else {
            warningLabel.isHidden = false
            warningLabel.stringValue = warnings.joined(separator: "\n")
        }

        // Instead of setting hasUnsavedChanges based on validity,
        // update the save button state directly:
        // Disable the save button if there are warnings (i.e. invalid content),
        // otherwise enable it only if there are unsaved changes.
        if !warnings.isEmpty {
            hasUnsavedChanges = false
        }
        parentTabViewController?.updateSaveButtonState()
    }
    
    
    var isValid: Bool {
        let maxScriptLength = 15360

        // Get trimmed contents of both fields
        let preInstallContents = fieldPreInstallScript.string.trimmingCharacters(in: .whitespacesAndNewlines)
        let postInstallContents = fieldPostInstallScript.string.trimmingCharacters(in: .whitespacesAndNewlines)

        // Validation for preinstall script
        let isPreInstallValidShebang = preInstallContents.isEmpty || preInstallContents.starts(with: "#!")
        let isPreInstallValidLength = preInstallContents.isEmpty || preInstallContents.count <= maxScriptLength

        // Validation for postinstall script
        let isPostInstallValidShebang = postInstallContents.isEmpty || postInstallContents.starts(with: "#!")
        let isPostInstallValidLength = postInstallContents.isEmpty || postInstallContents.count <= maxScriptLength

        // Overall validation must pass for both scripts
        let isPreInstallValid = isPreInstallValidShebang && isPreInstallValidLength
        let isPostInstallValid = isPostInstallValidShebang && isPostInstallValidLength

        // Debugging logs
//        print("Preinstall Script:")
//        print("  Content: \(preInstallContents)")
//        print("  Valid Shebang: \(isPreInstallValidShebang)")
//        print("  Valid Length: \(isPreInstallValidLength)")
//        print("Postinstall Script:")
//        print("  Content: \(postInstallContents)")
//        print("  Valid Shebang: \(isPostInstallValidShebang)")
//        print("  Valid Length: \(isPostInstallValidLength)")

        return isPreInstallValid && isPostInstallValid
    }

    
    func textDidChange(_ notification: Notification) {
        let preInstallChanged = fieldPreInstallScript.string != savedPreInstallScript
        let postInstallChanged = fieldPostInstallScript.string != savedPostInstallScript

        if preInstallChanged {
            print("Preinstall script changed")
        }
        if postInstallChanged {
            print("Postinstall script changed")
        }

        hasUnsavedChanges = preInstallChanged || postInstallChanged

        if hasUnsavedChanges == false {
            print("No changes detected")
        }
        updateSaveButtonState()
    }
    
    
    private func loadScriptFields() {
        guard let appData = appData else { return }

        let basePath = AppConstants.intuneomatorManagedTitlesFolderURL
            .appendingPathComponent("\(appData.label)_\(appData.guid)")

        let preInstallPath = basePath.appendingPathComponent("preinstall.sh")
        let postInstallPath = basePath.appendingPathComponent("postinstall.sh")

        // Load Preinstall Script
        if FileManager.default.fileExists(atPath: preInstallPath.path) {
            do {
                savedPreInstallScript = try String(contentsOf: preInstallPath, encoding: .utf8)
                fieldPreInstallScript.string = savedPreInstallScript
            } catch {
                print("Error loading preinstall script: \(error)")
            }
        } else {
            fieldPreInstallScript.string = "" // Clear if file doesn't exist
        }

        // Load Postinstall Script
        if FileManager.default.fileExists(atPath: postInstallPath.path) {
            do {
                savedPostInstallScript = try String(contentsOf: postInstallPath, encoding: .utf8)
                fieldPostInstallScript.string = savedPostInstallScript
            } catch {
                print("Error loading postinstall script: \(error)")
            }
        } else {
            fieldPostInstallScript.string = "" // Clear if file doesn't exist
        }
    }
    
    // Example of marking unsaved changes
//    func markUnsavedChanges() {
//        hasUnsavedChanges = true
//        parentTabViewController?.updateSaveButtonState()
//    }


    // MARK: - Custom TabView in Stackview
    private func setupCustomTabButtons() {
        
        var firstButton: NSButton?

        for (index, tabViewItem) in scriptsTabView.tabViewItems.enumerated() {
            // Create a button for each tab
            let button = NSButton(title: tabViewItem.label, target: self, action: #selector(tabButtonClicked(_:)))
            button.tag = index
            button.setButtonType(.momentaryPushIn)
            button.bezelStyle = .rounded
            button.alignment = .center

            // Add button to the stack view
            scriptsTabButtonsStackView.addArrangedSubview(button)
            tabButtons.append(button) // Track buttons

            // Ensure equal widths by matching the width of the first button
            if let firstButton = firstButton {
                button.translatesAutoresizingMaskIntoConstraints = false
                button.widthAnchor.constraint(equalTo: firstButton.widthAnchor).isActive = true
            } else {
                firstButton = button
            }

        }
        scriptsTabButtonsStackView.distribution = .fill
        scriptsTabButtonsStackView.alignment = .top
    }

    @objc private func tabButtonClicked(_ sender: NSButton) {
        // Switch to the corresponding tab
        scriptsTabView.selectTabViewItem(at: sender.tag)
        updateButtonStates(selectedIndex: sender.tag)
        let buttonTitle = scriptsTabView.selectedTabViewItem?.label ?? ""
        importButton.title = "Import \(buttonTitle) Script…"
    }

    
    private func updateButtonStates(selectedIndex: Int) {
        for (index, button) in tabButtons.enumerated() {
            if index == selectedIndex {
                // Highlight selected button
                button.state = .off
                button.bezelColor = NSColor.systemBlue
            } else {
                // Grey out other buttons
                button.state = .on
                button.bezelColor = NSColor.lightGray
            }

            // Determine the file path based on the appData and index
            guard let appData = appData else { continue }
            let scriptFileName = index == 0 ? "preinstall.sh" : "postinstall.sh"
            let filePath = AppConstants.intuneomatorManagedTitlesFolderURL
                .appendingPathComponent("\(appData.label)_\(appData.guid)")
                .appendingPathComponent(scriptFileName)

            // Check if the file exists
            let imageName = FileManager.default.fileExists(atPath: filePath.path) ? "code-24-green" : "code-24-grey"

            // Set the button image
            if let image = NSImage(named: imageName) {
                button.image = image
                button.imagePosition = .imageLeading // Adjust this to place the image appropriately
            }
        }
    }
    
    private func setupImportButton() {
        // Add the Import Script button to the stack view
//        importButton.title = "Import Script…"
//        importButton.setButtonType(.momentaryPushIn)
//        importButton.bezelStyle = .rounded
//        importButton.alignment = .center
        
//        scriptsTabButtonsStackView.addArrangedSubview(importButton)
        
        scriptsTabButtonsStackView.orientation = .vertical
        scriptsTabButtonsStackView.distribution = .fillEqually
        scriptsTabButtonsStackView.spacing = 5
        scriptsTabButtonsStackView.wantsLayer = true
//        scriptsTabButtonsStackView.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        scriptsTabButtonsStackView.layer?.backgroundColor = NSColor.lightGray.cgColor
        scriptsTabButtonsStackView.edgeInsets = NSEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        scriptsTabButtonsStackView.arrangedSubviews.forEach { $0.wantsLayer = true }

        scriptsTabButtonsStackView.translatesAutoresizingMaskIntoConstraints = false

//        scriptsTabButtonsStackView.trailingAnchor.constraint(equalTo: importButton.trailingAnchor).isActive = true
//        scriptsTabButtonsStackView.topAnchor.constraint(equalTo: importButton.topAnchor).isActive = true
//        scriptsTabButtonsStackView.bottomAnchor.constraint(equalTo: importButton.bottomAnchor).isActive = true
//        scriptsTabButtonsStackView.leadingAnchor.constraint(equalTo: importButton.leadingAnchor).isActive = true

//        // Ensure equal widths by matching the width of the first button
//        if let firstButton = scriptsTabButtonsStackView.  firstButton {
//            button.translatesAutoresizingMaskIntoConstraints = false
//            button.widthAnchor.constraint(equalTo: firstButton.widthAnchor).isActive = true
//        } else {
//            firstButton = button
//        }

//        scriptsTabButtonsStackView.distribution = .fill
//        scriptsTabButtonsStackView.setContentHuggingPriority(NSLayoutPriorityWindowSizeStayPut, for: NSLayoutConstraint.Attribute.width)
        

    }

    // MARK: - Help Buttons
    @IBAction func showHelpForPrePostScripts(_ sender: NSButton) {
        
        // Detemine Selected Tab
        let selectedTab = scriptsTabView.selectedTabViewItem?.label ?? ""
        var helpText: NSMutableAttributedString!

        // Create the full string
        if selectedTab == "Pre-install Script" {
            helpText = NSMutableAttributedString(string: "Pre-install script:\n\nProvide a script that runs before the pkg type deployment is installed.\n\nOnly when the preinstall script returns zero (indicating success), the app proceeds to install. If the preinstall script returns a nonzero code (indicating failure), the app doesn't install and reports its installation status as \"failed\". The preinstall script runs again for failed installations at the next device check-in (sync).")
        }
        else {
            helpText = NSMutableAttributedString(string: "Post-install script:\n\nProvide a script that runs after the pkg type deployment installs successfully.\n\nIf provided, the post-install script runs after a successful app installation.\n\nIrrespective of the post-install script run status, an installed app reports its installation status as \"success\"")
        }

        // Add a hyperlink to web page"
        let hyperlinkRange = (helpText.string as NSString).range(of: "Prerequisites of shell scripts")
        helpText.addAttribute(.link, value: "https://learn.microsoft.com/en-us/mem/intune/apps/macos-shell-scripts#prerequisites", range: hyperlinkRange)
        helpText.addAttributes([
            .foregroundColor: NSColor.systemBlue,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ], range: hyperlinkRange)

        // Add custom styling for the rest of the text
        helpText.addAttributes([
            .foregroundColor: NSColor.textColor,
            .font: NSFont.systemFont(ofSize: 13)
        ], range: NSRange(location: 0, length: helpText.length))

        // Show the popover
        helpPopover.showHelp(anchorView: sender, helpText: helpText)
    }

    @IBAction func showHelpForScripts(_ sender: NSButton) {
        // Create the full string
        let helpText = NSMutableAttributedString(string: "For PKG type deployments, you can optionally configure a preinstall script and a post-install script to customize the app install.\n\n☞ Each pre-install or post-install script must be less than 15360 characters long.\n\n☞ The Microsoft Intune management agent for macOS version 2309.007 or greater is required to configure pre-install and post-install scripts for macOS PKG apps.\n\n☞ For more details on configuring pre-install and post-install scripts, refer to: Prerequisites of shell scripts.")

        // Add a hyperlink to web page"
        let hyperlinkRange = (helpText.string as NSString).range(of: "Prerequisites of shell scripts")
        helpText.addAttribute(.link, value: "https://learn.microsoft.com/en-us/mem/intune/apps/macos-shell-scripts#prerequisites", range: hyperlinkRange)
        helpText.addAttributes([
            .foregroundColor: NSColor.systemBlue,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ], range: hyperlinkRange)

        // Add custom styling for the rest of the text
        helpText.addAttributes([
            .foregroundColor: NSColor.textColor,
            .font: NSFont.systemFont(ofSize: 13)
        ], range: NSRange(location: 0, length: helpText.length))

        // Show the popover
        helpPopover.showHelp(anchorView: sender, helpText: helpText)
    }
}

extension ScriptViewController: TabSaveable {
    func saveMetadata() {
        guard let appData = appData else { return }

        let labelFolder = "\(appData.label)_\(appData.guid)"
        let group = DispatchGroup()

        let preInstallContents = fieldPreInstallScript.string.trimmingCharacters(in: .whitespacesAndNewlines)
        let postInstallContents = fieldPostInstallScript.string.trimmingCharacters(in: .whitespacesAndNewlines)

        group.enter()
        XPCManager.shared.savePreInstallScriptToLabel(preInstallContents, labelFolder) { reply in
            if reply == true {
                Logger.logUser("Saved preinstall script: \(labelFolder)")
            } else {
                Logger.logUser("Failed to save preinstall script.")
            }
            group.leave()
        }

        group.enter()
        XPCManager.shared.savePostInstallScriptToLabel(postInstallContents, labelFolder) { reply in
            if reply == true {
                Logger.logUser("Saved postinstall script: \(labelFolder)")
            } else {
                Logger.logUser("Failed to save postinstall script.")
            }
            group.leave()
        }

        group.notify(queue: .main) {
            Logger.logUser("Scripts both saved successfully.")
            // Sheet dismissal is handled by the parent view once all tabs complete saving.
        }
    }
}
