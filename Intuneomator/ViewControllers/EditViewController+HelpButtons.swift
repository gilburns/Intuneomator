//
//  EditViewController+HelpButtons.swift
//  Intuneomator
//
//  Created by Gil Burns on 5/23/25.
//

///
///  EditViewController+HelpButtons.swift
///  Intuneomator
///
///  Provides help-popover IBAction methods for various fields in the Edit View,
///  displaying contextual guidance when the user clicks a help button.
///

import Foundation
import AppKit

/// Extension for `EditViewController` that adds help button actions.
/// Each method constructs an attributed string with guidance text and displays it in a popover.
extension EditViewController {
    
    // MARK: - Help Buttons
    /// Displays help about the "App Description" field.
    /// Shows a popover explaining how the description is used in the Company Portal.
    /// - Parameter sender: The help button that was clicked.
    
    @IBAction func showHelpForAppDescription(_ sender: NSButton) {
        // Create the full string
        let helpText = NSMutableAttributedString(string: "Enter the description of the app. The description appears in the Company Portal.")

        // Add custom styling for the rest of the text
        helpText.addAttributes([
            .foregroundColor: NSColor.textColor,
            .font: NSFont.systemFont(ofSize: 13)
        ], range: NSRange(location: 0, length: helpText.length))

        // Show the popover
        helpPopover.showHelp(anchorView: sender, helpText: helpText)
    }

    /// Displays help about the "Minimum OS Version" selection.
    /// Explains choosing the lowest supported macOS version for the app.
    /// - Parameter sender: The help button that was clicked.

    @IBAction func showHelpForAppMinOS(_ sender: NSButton) {
        // Create the full string
        let helpText = NSMutableAttributedString(string: "From the list, choose the minimum operating system version on which the app can be installed.\n\nIf you assign the app to a device with an earlier operating system, it will not be installed.")

        // Add custom styling for the rest of the text
        helpText.addAttributes([
            .foregroundColor: NSColor.textColor,
            .font: NSFont.systemFont(ofSize: 13)
        ], range: NSRange(location: 0, length: helpText.length))

        // Show the popover
        helpPopover.showHelp(anchorView: sender, helpText: helpText)
    }

    /// Displays help about selecting one or more app categories.
    /// Explains how categories help users find the app in the Company Portal.
    /// - Parameter sender: The help button that was clicked.

    @IBAction func showHelpForAppCategory(_ sender: NSButton) {
        // Create the full string
        let helpText = NSMutableAttributedString(string: "Select one or more of the built-in app categories, or select a category that you created. Categories make it easier for users to find the app when they browse through the Company Portal.")

        // Add custom styling for the rest of the text
        helpText.addAttributes([
            .foregroundColor: NSColor.textColor,
            .font: NSFont.systemFont(ofSize: 13)
        ], range: NSRange(location: 0, length: helpText.length))

        // Show the popover
        helpPopover.showHelp(anchorView: sender, helpText: helpText)
    }

    /// Displays help about the "Publisher" field.
    /// Explains that the publisher name appears in the Company Portal.
    /// - Parameter sender: The help button that was clicked.

    @IBAction func showHelpForAppPublisher(_ sender: NSButton) {
        // Create the full string
        let helpText = NSMutableAttributedString(string: "Enter the name of the publisher of the app. This will be visible in the Company Portal.")

        // Add custom styling for the rest of the text
        helpText.addAttributes([
            .foregroundColor: NSColor.textColor,
            .font: NSFont.systemFont(ofSize: 13)
        ], range: NSRange(location: 0, length: helpText.length))

        // Show the popover
        helpPopover.showHelp(anchorView: sender, helpText: helpText)
    }

    /// Displays help about the "Install as Managed App" option.
    /// Explains requirements and behavior for managed LOB app installation.
    /// - Parameter sender: The help button that was clicked.

    @IBAction func showHelpForInstallAsManaged(_ sender: NSButton) {
        // Create the full string
        let helpText = NSMutableAttributedString(string: """
Install as Managed App: Select Yes to install the Mac LOB app as a managed app on supported devices (macOS 11 and higher). 

A macOS LOB app can only be installed as managed when the app distributable contains a single app without any nested packages and installs to the /Applications directory. 

Managed line-of-business apps are able to be removed using the uninstall assignment type on supported devices (macOS 11 and higher). In addition, removing the MDM profile removes all managed apps from the device.

""")

        // Add custom styling for the rest of the text
        helpText.addAttributes([
            .foregroundColor: NSColor.textColor,
            .font: NSFont.systemFont(ofSize: 13)
        ], range: NSRange(location: 0, length: helpText.length))

        // Show the popover
        helpPopover.showHelp(anchorView: sender, helpText: helpText)
    }

    /// Displays help about featuring the app in the Company Portal.
    /// Explains how to prominently display the app on the main portal page.
    /// - Parameter sender: The help button that was clicked.

    @IBAction func showHelpForFeatureInCompanyPortal(_ sender: NSButton) {
        // Create the full string
        let helpText = NSMutableAttributedString(string: """
Featured App in Company Portal: 

Display the app prominently on the main page of the Company Portal when users browse for apps.
""")

        // Add custom styling for the rest of the text
        helpText.addAttributes([
            .foregroundColor: NSColor.textColor,
            .font: NSFont.systemFont(ofSize: 13)
        ], range: NSRange(location: 0, length: helpText.length))

        // Show the popover
        helpPopover.showHelp(anchorView: sender, helpText: helpText)
    }

    /// Displays help about the "Deploy as Architecture" setting.
    /// Explains deployment options for Apple Silicon, Intel, or Universal binaries.
    /// - Parameter sender: The help button that was clicked.

    @IBAction func showHelpForDeployAsArch(_ sender: NSButton) {
        // Create the full string
        let helpText = NSMutableAttributedString(string: "If enabled for selection, this label has separate binary deployments for Apple Silicon Macs, and Intel Macs.\n\nSelecting \"Apple Silicon\" to deploy for only Apple Silicon Macs.\n\nSelecting \"Intel\" to deploy for only Intel Macs.\n\nSelecting \"Universal\" to deploy for both Apple Silicon and Intel Macs. (Intuneomator will create a pkg file that contains both Intel and Apple Silicon versions.) This effectively doubles the size of the deployment, but it should support deployment of the app for both platforms.\n\n")

        // Add custom styling for the rest of the text
        helpText.addAttributes([
            .foregroundColor: NSColor.textColor,
            .font: NSFont.systemFont(ofSize: 13)
        ], range: NSRange(location: 0, length: helpText.length))

        // Show the popover
        helpPopover.showHelp(anchorView: sender, helpText: helpText)
    }

    /// Displays help about the optional fields section.
    /// Explains that extra fields may appear only in the Intune console.
    /// - Parameter sender: The help button that was clicked.

    @IBAction func showHelpForOptionalFields(_ sender: NSButton) {
        // Create the full string
        let helpText = NSMutableAttributedString(string: "These extra fields can be set to values that meet your needs some of these optional fields only appear in the Intune console, not in Company Portal.\n")

        // Add custom styling for the rest of the text
        helpText.addAttributes([
            .foregroundColor: NSColor.textColor,
            .font: NSFont.systemFont(ofSize: 13)
        ], range: NSRange(location: 0, length: helpText.length))

        // Show the popover
        helpPopover.showHelp(anchorView: sender, helpText: helpText)
    }

    /// Displays help about different deployment types (DMG, PKG, LOB).
    /// Shows details and links for each type based on the selected tag.
    /// - Parameter sender: The help button that was clicked.

    @IBAction func showHelpForDeploymentType(_ sender: NSButton) {
        // Create the full string
        var helpText: NSMutableAttributedString!
        var helpTextHyperlink: String!
        
        let helpTextDMG =
        NSMutableAttributedString(string: """
                                                 DMG:
                                                 
                                                 A DMG app is a disk image file that contains one or more applications within it.
                                                 
                                                 DMG files containing other types of installer files will not be installed.
                                                 
                                                 DMG app is smaller than 8 GB in size.
                                                 
                                                 Learn more: here:\n\nhttps://learn.microsoft.com/en-us/intune/intune-service/apps/lob-apps-macos-dmg
                                                 
                                                 """)

        let helpTextPKG =
        NSMutableAttributedString(string: """
                                                 PKG:
                                                 
                                                 The unmanaged macOS PKG app-type can install the following types of PKG apps:
                                                 
                                                 • Nonflat packages with a hierarchical structure
                                                 • Component packages
                                                 • Unsigned packages
                                                 • Packages without a payload
                                                 • Packages that install apps outside\n /Applications/
                                                 • Custom packages with scripts
                                                 
                                                 A PKG file should be smaller than 8 GB in size.
                                                 \n\nLearn more here:\n\nhttps://learn.microsoft.com/en-us/intune/intune-service/apps/macos-unmanaged-pkg
                                                 
                                                 """)

        let helpTextLOB =
        NSMutableAttributedString(string: """
                                                 LOB:
                                                 
                                                 The .pkg file must satisfy the following requirements to successfully be deployed using Microsoft Intune:
                                                 
                                                 • The .pkg file is a component package or a package containing multiple packages.
                                                 • The .pkg file does not contain a bundle or disk image or .app file.
                                                 • The .pkg file is signed using a "Developer ID Installer" certificate, obtained from an Apple Developer account.
                                                 • The .pkg file contains a payload. Packages without a payload attempt to re-install as long as the app remains assigned to the group.
                                                 \n\nLearn more here:\n\nhttps://learn.microsoft.com/en-us/intune/intune-service/apps/lob-apps-macos
                                                 """)
        let helpTextHyperlinkDMG = "https://learn.microsoft.com/en-us/intune/intune-service/apps/lob-apps-macos-dmg"

        let helpTextHyperlinkPKG = "https://learn.microsoft.com/en-us/intune/intune-service/apps/macos-unmanaged-pkg"

        let helpTextHyperlinkLOB = "https://learn.microsoft.com/en-us/intune/intune-service/apps/lob-apps-macos"
        
        let deploymentTypeTag = buttonDeploymentType.selectedTag()
        
        switch deploymentTypeTag {
        case 0:
            helpText = helpTextDMG
            helpTextHyperlink = helpTextHyperlinkDMG
        case 1:
            helpText = helpTextPKG
            helpTextHyperlink = helpTextHyperlinkPKG
        case 2:
            helpText = helpTextLOB
            helpTextHyperlink = helpTextHyperlinkLOB
        default:
            break
        }
        
        // Add a hyperlink to "Mozilla's Firefox page"
        let hyperlinkRange = (helpText.string as NSString).range(of: helpTextHyperlink)
        helpText.addAttribute(.link, value: helpTextHyperlink ?? "", range: hyperlinkRange)
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

    /// Displays help about detection rules for app install detection.
    /// Explains how to configure rules for managed macOS devices.
    /// - Parameter sender: The help button that was clicked.

    @IBAction func showHelpForDetectionRules(_ sender: NSButton) {
        // Create the full string
        let helpText = NSMutableAttributedString(string: "You can use detection rules to choose how an app installation is detected on a managed macOS device.")

        // Add custom styling for the rest of the text
        helpText.addAttributes([
            .foregroundColor: NSColor.textColor,
            .font: NSFont.systemFont(ofSize: 13)
        ], range: NSRange(location: 0, length: helpText.length))

        // Show the popover
        helpPopover.showHelp(anchorView: sender, helpText: helpText)
    }

    /// Displays help about the "Bundle ID" field.
    /// Explains that the bundle ID should match CFBundleIdentifier in Info.plist.
    /// - Parameter sender: The help button that was clicked.

    @IBAction func showHelpForBundleID(_ sender: NSButton) {
        // Create the full string
        let helpText = NSMutableAttributedString(string: "The Bundle ID should match the one in the Info.plist file of the primary app for the key CFBundleIdentifier.\n\nFor example, to look up the bundle ID of a Company Portal, run the following:\n\ndefaults read \"/Applications/Company Portal.app/Contents/Info\" CFBundleIdentifier")

        // Add custom styling for the rest of the text
        helpText.addAttributes([
            .foregroundColor: NSColor.textColor,
            .font: NSFont.systemFont(ofSize: 13)
        ], range: NSRange(location: 0, length: helpText.length))

        // Show the popover
        helpPopover.showHelp(anchorView: sender, helpText: helpText)
    }

    /// Displays help about the "Ignore Version" option.
    /// Explains when to choose to ignore version checks for app installation.
    /// - Parameter sender: The help button that was clicked.

    @IBAction func showHelpForIgnoreVersion(_ sender: NSButton) {
        // Create the full string
        let helpText = NSMutableAttributedString(string: "Select \"Yes\" to install the app if the app isn't already installed on the device. This will only look for the presence of the app bundle ID. For apps that have an autoupdate mechanism, select \"Yes\".\n\nSelect \"No\" to install the app when it isn't already installed on the device, or if the deploying app's version number doesn't match the version that's already installed on the device.")

        // Add custom styling for the rest of the text
        helpText.addAttributes([
            .foregroundColor: NSColor.textColor,
            .font: NSFont.systemFont(ofSize: 13)
        ], range: NSRange(location: 0, length: helpText.length))

        // Show the popover
        helpPopover.showHelp(anchorView: sender, helpText: helpText)
    }

    /// Displays help about "Installomator" labels.
    /// Explains what Installomator is and links to the GitHub repository.
    /// - Parameter sender: The help button that was clicked.

    @IBAction func showHelpForInstallomator(_ sender: NSButton) {
        // Create the full string
        let helpText = NSMutableAttributedString(string: "Installomator is an open-source project designed for macOS that automates the installation and updating of various applications by downloading the latest versions directly from vendor websites.\n\nThese Installomator \"Label\" files form the basis for creating Intuneomator managed apps.\n\nLearn more here:\n\nhttps://github.com/Installomator/Installomator")

        // Add a hyperlink to "Mozilla's Firefox page"
        let hyperlinkRange = (helpText.string as NSString).range(of: "https://github.com/Installomator/Installomator")
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

    /// Displays help about "Installomator" type options.
    /// Explains which Installomator label types map to Intune app types (DMG, PKG, LOB).
    /// - Parameter sender: The help button that was clicked.

    @IBAction func showHelpForInstallomatorType(_ sender: NSButton) {
        // Create the full string
        let helpText = NSMutableAttributedString(string: "Installomator dmg, zip, tbz, and appInDmgInZip types can be delivered as either a \"macOS DMG app\" or \"macOS PKG app\" type installation with Intune.\n\nInstallomator pkg, pkgInDmg, pkgInZip, or pkgInDmgInZip types can be delivered as either a \"macOS PKG app\" or \"macOS LOB app\" type installation with Intune.")

        
        // Add custom styling for the rest of the text
        helpText.addAttributes([
            .foregroundColor: NSColor.textColor,
            .font: NSFont.systemFont(ofSize: 13)
        ], range: NSRange(location: 0, length: helpText.length))

        // Show the popover
        helpPopover.showHelp(anchorView: sender, helpText: helpText)
    }


}
