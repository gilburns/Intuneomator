//
//  AboutViewController.swift
//  Intuneomator
//
//  Created by Gil Burns on 1/17/25.
//

import Foundation
import Cocoa

class AboutViewController: NSViewController, NSTextViewDelegate {
 
    @IBOutlet weak var aboutInstallomatorButton: NSButton!
    @IBOutlet weak var aboutIntuneomatorButton: NSButton!
    @IBOutlet weak var okButton: NSButton!

    @IBOutlet weak var installomatorLinkTextView: NSTextView!
    @IBOutlet weak var intuneomatorLinkTextView: NSTextView!

    private var popover: NSPopover!
    
    // Create a reusable HelpPopover instance
    private let helpPopover = HelpPopover()

    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        // Create the hyperlinks
        createIntuneomatorHyperlink()
        createInstallomatorHyperlink()
                
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()

        // Ensure the window is fixed and non-resizable
        if let window = self.view.window {
            window.styleMask.remove(.resizable) // Remove the resizable property
            window.minSize = window.frame.size  // Set minimum size
            window.maxSize = window.frame.size  // Set maximum size
        }
    }

    
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

    
    func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
        print("Link clicked!")
        if let url = link as? URL {
            NSWorkspace.shared.open(url)
        }

        // Close the modal dialog
        self.dismiss(self)
        return true // Indicate the link click was handled
    }

    
    
    // MARK: - Actions
    @IBAction func aboutInstallomatorButtonAction(_ sender: Any?) {
        NSWorkspace.shared.open(URL(string: "https://www.installomator.com")!)
    }
    
    @IBAction func aboutIntuneomatorButtonAction(_ sender: Any?) {
        NSWorkspace.shared.open(URL(string: "https://www.intuneomator.com")!)
    }
    
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
