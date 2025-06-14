//
//  ScriptViewController.swift
//  Intuneomator
//
//  Created by Gil Burns on 1/11/25.
//

import Foundation
import Cocoa
import UniformTypeIdentifiers

/// View controller for editing pre-install and post-install scripts for PKG deployments
/// Provides interface for creating and managing shell scripts that run before and after
/// application installation in Microsoft Intune PKG-type deployments
/// 
/// **Key Features:**
/// - Supports pre-install and post-install script editing for PKG deployments only
/// - Validates script syntax (shebang requirement) and length limits (15,360 characters)
/// - Provides script import functionality from external files
/// - Shows real-time validation warnings and feedback
/// - Implements custom tab interface with visual indicators for script presence
/// - Handles deployment type restrictions (scripts unavailable for DMG and LOB apps)
/// - Tracks unsaved changes with visual feedback
class ScriptViewController: NSViewController, NSTextViewDelegate, Configurable, UnsavedChangesHandling {
    
    @IBOutlet weak var scriptsTabView: NSTabView!
    @IBOutlet weak var scriptsTabButtonsStackView: NSStackView! // A vertical stack view for buttons
    
    @IBOutlet weak var fieldPreInstallScript: NSTextView!
    @IBOutlet weak var fieldPostInstallScript: NSTextView!
    @IBOutlet weak var warningLabel: NSTextField! // Label to show warnings about invalid scripts
    @IBOutlet weak var unavailableLabel: NSTextField!
    @IBOutlet weak var importButton: NSButton! // Outlet for the Import button

    @IBOutlet weak var prePostHelpButton: NSButton!

    /// Array of custom tab buttons for script selection
    private var tabButtons: [NSButton] = []

    /// Application data containing label and GUID information
    var appData: AppInfo?
    /// Reference to parent tab view controller for save state management
    var parentTabViewController: TabViewController?
    /// Flag indicating whether there are unsaved script changes
    var hasUnsavedChanges: Bool = false

    /// Saved state of pre-install script for change detection
    var savedPreInstallScript: String = ""
    /// Saved state of post-install script for change detection
    var savedPostInstallScript: String = ""
    
    /// Reusable help popover instance for contextual assistance
    private let helpPopover = HelpPopover()

// MARK: - Configuration
    
    /// Configures the script view controller with application data and parent reference
    /// - Parameters:
    ///   - data: AppInfo object containing application details
    ///   - parent: Parent TabViewController for save state coordination
    func configure(with data: Any, parent: TabViewController) {
        guard let appData = data as? AppInfo else {
            Logger.error("Invalid data passed to ScriptViewController", category: .core, toUserDirectory: true)
            return
        }
        self.appData = appData
        self.parentTabViewController = parent
    }


// MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        // Use appData to configure the view
        guard appData != nil else {
            Logger.error("Error: appData is nil in ScriptViewController viewDidLoad.", category: .core, toUserDirectory: true)
            return
        }
        
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
                
    }

    override func viewDidAppear() {
        super.viewDidAppear()

    }

    override func viewWillAppear() {
        super.viewWillAppear()
        updateScriptAvailability()
        updatePlaceholders()
    }
    
    /// Updates script availability based on current deployment type
    /// Scripts are only supported for PKG deployments in Microsoft Intune
    private func updateScriptAvailability() {
        let appType = AppDataManager.shared.currentAppType
        

        
        switch appType {
        case "macOSLobApp":
            fieldPreInstallScript.isEditable = false
            fieldPostInstallScript.isEditable = false
            importButton.isEnabled = false
            unavailableLabel.isHidden = false
            prePostHelpButton.isEnabled = false
            for index in 0...1 {
                if let button = scriptsTabButtonsStackView.arrangedSubviews[index] as? NSButton {
                    button.title = "Unavailable"
                    button.isEnabled = false
                    button.bezelColor = .controlColor
                }
            }
        case "macOSPkgApp":
            fieldPreInstallScript.isEditable = true
            fieldPostInstallScript.isEditable = true
            importButton.isEnabled = true
            unavailableLabel.isHidden = true
            prePostHelpButton.isEnabled = true
            if let button = scriptsTabButtonsStackView.arrangedSubviews[0] as? NSButton {
                button.title = "Pre-Install Script"
                button.isEnabled = true
                button.bezelColor = .selectedControlColor
            }
            if let button = scriptsTabButtonsStackView.arrangedSubviews[1] as? NSButton {
                button.title = "Post-Install Script"
                button.isEnabled = true
                button.bezelColor = .controlColor
            }
        case "macOSDmgApp":
            fieldPreInstallScript.isEditable = false
            fieldPostInstallScript.isEditable = false
            importButton.isEnabled = false
            unavailableLabel.isHidden = false
            prePostHelpButton.isEnabled = false
            for index in 0...1 {
                if let button = scriptsTabButtonsStackView.arrangedSubviews[index] as? NSButton {
                    button.title = "Unavailable"
                    button.isEnabled = false
                    button.bezelColor = .controlColor
                }
            }
        default:
            fieldPreInstallScript.isEditable = false
            fieldPostInstallScript.isEditable = false
            importButton.isEnabled = false
            unavailableLabel.isHidden = false
            prePostHelpButton.isEnabled = false
            for index in 0...1 {
                if let button = scriptsTabButtonsStackView.arrangedSubviews[index] as? NSButton {
                    button.title = "Unavailable"
                    button.isEnabled = false
                    button.bezelColor = .controlColor
                }
            }
        }
    }

// MARK: - Script View Placeholders
    
    /// Updates placeholder text in script editors based on deployment type
    /// Shows appropriate guidance or restriction messages for each deployment type
    func updatePlaceholders() {
        
        let appType = AppDataManager.shared.currentAppType
        let placeholderPreInstallScript: String
        let placeholderPostInstallScript: String
        
        switch appType {
        case "macOSLobApp":
            placeholderPreInstallScript = "Scripts are not supported by Intune for Line of Business deployment type."
            placeholderPostInstallScript = "Scripts are not supported by Intune for Line of Business deployment type."
            
        case "macOSPkgApp":
            placeholderPreInstallScript = "#!/bin/zsh\n\necho \"Hello, world!\"\n\necho \"This is my Pre-install script!\"\n\nexit 0"
            placeholderPostInstallScript = "#!/bin/zsh\n\necho \"Hello, world!\"\n\necho \"This is my Post-install script!\"\n\nexit 0"
            
        case "macOSDmgApp":
            placeholderPreInstallScript = "Scripts are not supported by Intune for DMG deployment type."
            placeholderPostInstallScript = "Scripts are not supported by Intune for DMG deployment type."
            
        default:
            placeholderPreInstallScript = "Scripts are only supported by Intune for PKG deployment type."
            placeholderPostInstallScript = "Scripts are only supported by Intune for PKG deployment type."
            
        }

        let attributes: [NSAttributedString.Key: Any] =
          [.foregroundColor: NSColor.secondaryLabelColor]

        fieldPreInstallScript.setValue(NSAttributedString(string: placeholderPreInstallScript, attributes: attributes), forKey: "placeholderAttributedString")

        fieldPostInstallScript.setValue(NSAttributedString(string: placeholderPostInstallScript, attributes: attributes), forKey: "placeholderAttributedString")

    }
    
    
// MARK: - Actions
    
    /// Imports a script file from the file system into the current script editor
    /// Supports shell scripts, text files, Python scripts, and PowerShell scripts
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
        Logger.info("Import Script for \(selectedTab.label)", category: .core, toUserDirectory: true)

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
        dialog.allowedContentTypes = [
            .shellScript,           // sh, bash, zsh, ksh
            .text,                  // txt
            .pythonScript,          // python
            UTType(filenameExtension: "ps1")! // PowerShell
        ]
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
    
    /// Updates save button state based on script validation
    /// Performs validation for shebang requirements and character limits
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
    
    
    /// Validates both pre-install and post-install scripts
    /// - Returns: True if both scripts meet validation requirements (shebang and length)
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

        return isPreInstallValid && isPostInstallValid
    }

    
    /// Handles text change notifications from script editors
    /// Updates unsaved changes flag and triggers validation
    /// - Parameter notification: Text change notification from NSTextView
    func textDidChange(_ notification: Notification) {
        let preInstallChanged = fieldPreInstallScript.string != savedPreInstallScript
        let postInstallChanged = fieldPostInstallScript.string != savedPostInstallScript

        if preInstallChanged {
        }
        if postInstallChanged {
        }

        hasUnsavedChanges = preInstallChanged || postInstallChanged

        if hasUnsavedChanges == false {
        }
        updateSaveButtonState()
    }
    
    
    /// Loads existing script content from saved files
    /// Reads pre-install and post-install scripts from the managed titles directory
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
                Logger.error("Error loading preinstall script: \(error)", category: .core, toUserDirectory: true)
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
                Logger.error("Error loading postinstall script: \(error)", category: .core, toUserDirectory: true)
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


    // MARK: - Custom Tab Interface
    
    /// Sets up custom tab buttons in the stack view
    /// Creates buttons for pre-install and post-install script tabs with visual indicators
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

        scriptsTabButtonsStackView.alignment = .top
        
        scriptsTabButtonsStackView.orientation = .vertical
        scriptsTabButtonsStackView.distribution = .fillEqually
        scriptsTabButtonsStackView.spacing = 5
        scriptsTabButtonsStackView.wantsLayer = true

        scriptsTabButtonsStackView.layer?.backgroundColor = NSColor.lightGray.cgColor
        scriptsTabButtonsStackView.edgeInsets = NSEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        scriptsTabButtonsStackView.arrangedSubviews.forEach { $0.wantsLayer = true }

        scriptsTabButtonsStackView.translatesAutoresizingMaskIntoConstraints = false

    }

    /// Handles custom tab button clicks
    /// Switches between pre-install and post-install script tabs
    /// - Parameter sender: The tab button that was clicked
    @objc private func tabButtonClicked(_ sender: NSButton) {
        // Switch to the corresponding tab
        scriptsTabView.selectTabViewItem(at: sender.tag)
        updateButtonStates(selectedIndex: sender.tag)
        let buttonTitle = scriptsTabView.selectedTabViewItem?.label ?? ""
        importButton.title = "Import \(buttonTitle)…"
    }

    
    /// Updates visual states of custom tab buttons
    /// Highlights selected tab and shows script file existence indicators
    /// - Parameter selectedIndex: Index of the currently selected tab
    private func updateButtonStates(selectedIndex: Int) {
        for (index, button) in tabButtons.enumerated() {
            if index == selectedIndex {
                // Highlight selected button
                button.state = .off
                button.bezelColor = .selectedControlColor
            } else {
                // Grey out other buttons
                button.state = .on
                button.bezelColor = .controlColor
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
    
    // MARK: - Help Actions
    
    /// Shows contextual help for pre-install or post-install scripts
    /// Displays different help content based on currently selected tab
    /// - Parameter sender: Help button that triggered the action
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

    /// Shows general help information about script requirements and limitations
    /// Displays Microsoft Intune script prerequisites and character limits
    /// - Parameter sender: Help button that triggered the action
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

// MARK: - TabSaveable Protocol

extension ScriptViewController: TabSaveable {
    /// Saves both pre-install and post-install scripts via XPC service
    /// Uses dispatch group to coordinate saving both scripts simultaneously
    func saveMetadata() {
        guard let appData = appData else { return }

        let labelFolder = "\(appData.label)_\(appData.guid)"
        let group = DispatchGroup()

        let preInstallContents = fieldPreInstallScript.string.trimmingCharacters(in: .whitespacesAndNewlines)
        let postInstallContents = fieldPostInstallScript.string.trimmingCharacters(in: .whitespacesAndNewlines)

        group.enter()
        XPCManager.shared.savePreInstallScriptToLabel(preInstallContents, labelFolder) { reply in
            if reply == true {
                Logger.info("Saved preinstall script: \(labelFolder)", category: .core, toUserDirectory: true)
            } else {
                Logger.info("Failed to save preinstall script.", category: .core, toUserDirectory: true)
            }
            group.leave()
        }

        group.enter()
        XPCManager.shared.savePostInstallScriptToLabel(postInstallContents, labelFolder) { reply in
            if reply == true {
                Logger.info("Saved postinstall script: \(labelFolder)", category: .core, toUserDirectory: true)
            } else {
                Logger.info("Failed to save postinstall script.", category: .core, toUserDirectory: true)
            }
            group.leave()
        }

        group.notify(queue: .main) {
            Logger.info("Scripts both saved successfully.", category: .core, toUserDirectory: true)
            // Sheet dismissal is handled by the parent view once all tabs complete saving.
        }
    }
}
