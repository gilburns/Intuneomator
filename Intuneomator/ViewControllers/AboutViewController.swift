//
//  AboutViewController.swift
//  Intuneomator
//
//  Created by Gil Burns on 1/17/25.
//

import Foundation
import Cocoa

/// View controller for the About dialog window
/// Displays application information, version details, and provides links to related projects
/// 
/// **Key Features:**
/// - Displays clickable hyperlinks to Intuneomator and Installomator GitHub repositories
/// - Shows help information about the Installomator project
/// - Manages a fixed-size, non-resizable modal dialog window
class AboutViewController: NSViewController, NSTextViewDelegate {
 
    /// Button that opens the Intuneomator GitHub repository when clicked.
    @IBOutlet weak var aboutIntuneomatorButton: NSButton!
    /// Button that closes the About dialog.
    @IBOutlet weak var okButton: NSButton!

    /// Text view displaying a clickable hyperlink to the Installomator GitHub repository.
    @IBOutlet weak var installomatorLinkTextView: NSTextView!

    /// Text view displaying a clickable hyperlink to the Intuneomator GitHub repository.
    @IBOutlet weak var intuneomatorLinkTextView: NSTextView!

    
    /// Text view displaying version information for the three components
    @IBOutlet weak var versionLabelApp: NSTextField!
    @IBOutlet weak var versionLabelService: NSTextField!
    @IBOutlet weak var versionLabelUpdater: NSTextField!
    
    
    /// Popover used to display contextual help information.
    private var popover: NSPopover!
    
    /// Reusable HelpPopover instance for displaying detailed help within the About dialog.
    private let helpPopover = HelpPopover()

    
    // MARK: - View Lifecycle
    /// Called after the view controller’s view has been loaded into memory.
    /// Initializes hyperlinks for both Intuneomator and Installomator repositories.
    override func viewDidLoad() {
        super.viewDidLoad()

        // Create the hyperlinks
        createIntuneomatorHyperlink()
        createInstallomatorHyperlink()
    
        // Version info
        updateVersionLabels()
    }
    
    /// Called when the view has appeared on screen.
    /// Disables window resizing by fixing the window’s size.
    override func viewDidAppear() {
        super.viewDidAppear()

        // Ensure the window is fixed and non-resizable
        if let window = self.view.window {
            window.styleMask.remove(.resizable) // Remove the resizable property
            window.minSize = window.frame.size  // Set minimum size
            window.maxSize = window.frame.size  // Set maximum size
        }
    }

    // MARK: - Version Information
    
    func updateVersionLabels() {
        
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let appBuild = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        
        versionLabelApp.stringValue = "\(appVersion).\(appBuild)"
        
        versionInfoUpdater()
        versionInfoService()
    }
    
    
    func versionInfoService() {
        XPCManager.shared.getDaemonVersion { daemonVersion in
            DispatchQueue.main.async {
                let version = daemonVersion ?? "Unknown"
                self.versionLabelService.stringValue = "\(version)"
            }
        }
    }

    
    func versionInfoUpdater() {
        XPCManager.shared.getUpdaterVersion { updaterVersion in
            DispatchQueue.main.async {
                let version = updaterVersion ?? "Unknown"
                self.versionLabelUpdater.stringValue = "\(version)"
            }
        }
    }
    
    // MARK: - Hyperlinks
    
    /// Configures `intuneomatorLinkTextView` with an attributed string that
    /// displays “Visit Intuneomator on GitHub” as a clickable hyperlink to the GitHub page.
    private func createIntuneomatorHyperlink() {
        let url = "https://github.com/gilburns/Intuneomator"
        let linkText = "Visit Intuneomator on GitHub"

        // Create an attributed string with hyperlink styling
        let attributedString = NSMutableAttributedString(string: linkText)
        attributedString.addAttributes([
            .foregroundColor: NSColor.systemBlue,
            .underlineStyle: NSUnderlineStyle.single.rawValue,
            .link: URL(string: url)!, // Add the URL to the text
            .font: NSFont.systemFont(ofSize: 12) // Set font size to 12
        ], range: NSRange(location: 0, length: linkText.count))

        // Configure the text view
        intuneomatorLinkTextView.textStorage?.setAttributedString(attributedString)
        intuneomatorLinkTextView.isEditable = false
        intuneomatorLinkTextView.isSelectable = true
        intuneomatorLinkTextView.drawsBackground = false
        intuneomatorLinkTextView.delegate = self // Set the delegate
    }

    
    /// Configures `installomatorLinkTextView` with an attributed string that
    /// displays “Visit Installomator on GitHub” as a clickable hyperlink to the GitHub page.
    private func createInstallomatorHyperlink() {
        let url = "https://github.com/Installomator/Installomator"
        let linkText = "Visit Installomator on GitHub"

        // Create an attributed string with hyperlink styling
        let attributedString = NSMutableAttributedString(string: linkText)
        attributedString.addAttributes([
            .foregroundColor: NSColor.systemBlue,
            .underlineStyle: NSUnderlineStyle.single.rawValue,
            .link: URL(string: url)!, // Add the URL to the text
            .font: NSFont.systemFont(ofSize: 12) // Set font size to 12
        ], range: NSRange(location: 0, length: linkText.count))

        // Configure the text view
        installomatorLinkTextView.textStorage?.setAttributedString(attributedString)
        installomatorLinkTextView.isEditable = false
        installomatorLinkTextView.isSelectable = true
        installomatorLinkTextView.drawsBackground = false
        installomatorLinkTextView.delegate = self // Set the delegate
    }

    
    /// NSTextViewDelegate callback invoked when a hyperlink in either text view is clicked.
    /// Opens the link in the default browser and closes the About dialog.
    ///
    /// - Parameters:
    ///   - textView: The NSTextView where the link was clicked.
    ///   - link: The URL object associated with the clicked text.
    ///   - charIndex: The character index where the click occurred (unused).
    /// - Returns: True if the link click was handled.
    func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
        if let url = link as? URL {
            NSWorkspace.shared.open(url)
        }

        // Close the modal dialog
        self.dismiss(self)
        return true // Indicate the link click was handled
    }

    
    // MARK: - Actions
    
    /// IBAction for the Intuneomator button.
    /// Opens the Installomator GitHub repository in the default browser.
    @IBAction func aboutIntuneomatorButtonAction(_ sender: Any?) {
        NSWorkspace.shared.open(URL(string: "https://github.com/Installomator/Installomator")!)
    }
    
    /// IBAction for the Installomator help button.
    /// Builds a detailed help message about Installomator and shows it in a popover anchored to the button.
    /// 
    /// - Parameter sender: The NSButton that triggered the help popover.
    @IBAction func installomatorHelpButtonClicked(_ sender: NSButton) {
        // Create the full string
        let helpText = NSMutableAttributedString(string: "Installomator is an open source project for macOS. At it's core, Installomator is an installation script to deploy software on Macs. The Installomator labels function as small code snippets to automatically find the latest version of a software title. Then download and install it. The project supports over 950 unique software titles.")

        // Add a hyperlink to "Mozilla's Firefox page"
        let hyperlinkRange = (helpText.string as NSString).range(of: "Installomator is an open source project")
        helpText.addAttribute(.link, value: "https://github.com/Installomator/Installomator", range: hyperlinkRange)
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
