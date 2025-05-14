//
//  EditOtherViewController.swift
//  Intuneomator
//
//  Created by Gil Burns on 4/30/25.
//

import Foundation
import Cocoa


protocol EditOtherViewControllerDelegate: AnyObject {
    /// Called when the sheet saves data.
    func editOtherDidSave(
        returnedMetadataPartial: MetadataPartial
    )
}


class EditOtherViewController: NSViewController, NSTextStorageDelegate {
    
    @IBOutlet weak var labelAppName: NSTextField!
    
    @IBOutlet weak var fieldDeveloper: NSTextField!
    @IBOutlet weak var fieldInfomationURL: NSTextField!
    @IBOutlet weak var fieldNotes: NSTextView!
    @IBOutlet weak var fieldOwner: NSTextField!
    @IBOutlet weak var fieldPrivacyInfomationURL: NSTextField!

    @IBOutlet weak var buttonSave: NSButton!
    
    // track changes for the metadata.json file
    var hasUnsavedChanges = false
    
    var appName: String?
    
    // Passed when the view opens
    var lastMetadataPartial: MetadataPartial?
    var currentMetadataPartial: MetadataPartial?

    // Delegate connection
    weak var delegate: EditOtherViewControllerDelegate?

    // Create a reusable HelpPopover instance
    private let helpPopover = HelpPopover()


    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
//        print("Current AppMetadata: \(String(describing: lastMetadataPartial))")
//        print("Last AppMetadata: \(String(describing: currentMetadataPartial))")

        
        // Set the NSTextStorage delegate
        if let textStorage = fieldNotes.textStorage {
            textStorage.delegate = self
//            print("Text storage delegate set successfully.")
        } else {
//            print("Failed to access text storage.")
        }

    }
    
    override func viewWillAppear() {
        super.viewWillAppear()

        // Load the saved size or use the default size
        let defaultSize = NSSize(width: 700, height: 400)
        let savedSize = loadSavedSheetSize() ?? defaultSize

        if let sheetWindow = view.window {
            sheetWindow.setContentSize(savedSize) // Apply the saved or default size
            sheetWindow.minSize = NSSize(width: 700, height: 400) // Set minimum size
        }
        
        labelAppName.stringValue = "\(appName ?? "Unknown App") Optional Details:"
        
        populateFieldsFromData()
        trackChanges()

    }

    
    // Load the size from UserDefaults
    private func loadSavedSheetSize() -> NSSize? {
        if let sizeDict = UserDefaults.standard.dictionary(forKey: "EditOtherViewSheetSize") as? [String: CGFloat],
           let width = sizeDict["width"], let height = sizeDict["height"] {
            return NSSize(width: width, height: height)
        }
        return nil
    }

    
    
    // MARK: - Actions
    
    @IBAction func saveAndDismiss(_ sender: NSButton) {
        
        currentMetadataPartial?.developer = fieldDeveloper.stringValue
        currentMetadataPartial?.informationUrl = fieldInfomationURL.stringValue
        currentMetadataPartial?.notes = fieldNotes.string
        currentMetadataPartial?.owner = fieldOwner.stringValue
        currentMetadataPartial?.privacyInformationUrl = fieldPrivacyInfomationURL.stringValue
        
        delegate?.editOtherDidSave(
            returnedMetadataPartial: currentMetadataPartial!
        )
        
        self.dismiss(self)
    }
    
    @IBAction func dismissSheet(_ sender: NSButton) {
        self.dismiss(self)
    }

    
    
    
    private func populateFieldsFromData() {
        
        fieldDeveloper.stringValue = currentMetadataPartial?.developer ?? ""
        fieldInfomationURL.stringValue = currentMetadataPartial?.informationUrl ?? ""
        fieldOwner.stringValue = currentMetadataPartial?.owner ?? ""
        fieldPrivacyInfomationURL.stringValue = currentMetadataPartial?.privacyInformationUrl ?? ""
        
        fieldNotes.string = currentMetadataPartial?.notes ?? ""

    }
    
    // MARK: - Track Changes in the GUI
    @IBAction func fieldDeveloperDidChange(_ sender: NSTextField) {
        trackChanges()
    }

    @IBAction func fieldInfoURLDidChange(_ sender: NSTextField) {
        trackChanges()
    }

    @IBAction func fieldOwnerDidChange(_ sender: NSTextField) {
        trackChanges()
    }
    
    @IBAction func fieldPrivacyURLDidChange(_ sender: NSTextField) {
        trackChanges()
    }


    // NSTextStorageDelegate method
    func textStorage(_ textStorage: AppKit.NSTextStorage, didProcessEditing editedMask: AppKit.NSTextStorageEditActions, range editedRange: NSRange, changeInLength delta: Int) {

        // Trigger tracking changes
//        print("Tracking")
        trackChanges()
    }

    
    func trackChanges() {
                        
        currentMetadataPartial?.developer = fieldDeveloper.stringValue
        currentMetadataPartial?.informationUrl = fieldInfomationURL.stringValue
        currentMetadataPartial?.notes = fieldNotes.string
        currentMetadataPartial?.owner = fieldOwner.stringValue
        currentMetadataPartial?.privacyInformationUrl = fieldPrivacyInfomationURL.stringValue

        
        highlightChangedFields()

        if currentMetadataPartial != lastMetadataPartial {
            hasUnsavedChanges = true
            buttonSave.isEnabled = true
//            print("Changes detected in EditView.")
        
        } else {
            hasUnsavedChanges = false
            buttonSave.isEnabled = false
//            print("No changes detected in EditView.")
        }
    }
    
    private func clearFieldHighlights() {

        fieldDeveloper.backgroundColor = nil
        fieldInfomationURL.backgroundColor = nil
        fieldOwner.backgroundColor = nil
        fieldPrivacyInfomationURL.backgroundColor = nil

        setTextViewBorder(field: fieldNotes, color: NSColor.clear)

    }

    func highlightChangedFields() {
        
//        print("Highlighting changed fields")
//        print("Developer: \(String(describing: currentMetadataPartial?.developer!))")
//        print("Developer: \(String(describing: lastMetadataPartial?.developer!))")
//        print("informationUrl: \(String(describing: currentMetadataPartial?.informationUrl!))")
//        print("informationUrl: \(String(describing: lastMetadataPartial?.informationUrl!))")
//        print("owner: \(String(describing: currentMetadataPartial?.owner!))")
//        print("owner: \(String(describing: lastMetadataPartial?.owner!))")
//        print("privacyInformationUrl: \(String(describing: currentMetadataPartial?.privacyInformationUrl!))")
//        print("privacyInformationUrl: \(String(describing: lastMetadataPartial?.privacyInformationUrl!))")
//        print("Notes: \(String(describing: currentMetadataPartial?.notes!))")
//        print("Notes: \(String(describing: lastMetadataPartial?.notes!))")

        
        // Highlight developer field if changed
        if currentMetadataPartial?.developer != lastMetadataPartial?.developer {
            highlightField(fieldDeveloper)
        } else {
            clearHighlight(fieldDeveloper)
        }

        // Highlight informationUrl field if changed
        if currentMetadataPartial?.informationUrl != lastMetadataPartial?.informationUrl {
            highlightField(fieldInfomationURL)
        } else {
            clearHighlight(fieldInfomationURL)
        }

        // Highlight owner field if changed
        if currentMetadataPartial?.owner != lastMetadataPartial?.owner {
            highlightField(fieldOwner)
        } else {
            clearHighlight(fieldOwner)
        }

        // Highlight privacyInformationUrl field if changed
        if currentMetadataPartial?.privacyInformationUrl != lastMetadataPartial?.privacyInformationUrl {
            highlightField(fieldPrivacyInfomationURL)
        } else {
            clearHighlight(fieldPrivacyInfomationURL)
        }

        // Check notes
        if currentMetadataPartial?.notes != lastMetadataPartial?.notes {
            setTextViewBorder(field: fieldNotes, color: NSColor.systemYellow)
        } else {
            setTextViewBorder(field: fieldNotes, color: NSColor.clear)
        }

        
    }
    
    // Highlight a field
    private func highlightField(_ field: NSControl) {
        if let textField = field as? NSTextField {
            textField.backgroundColor = NSColor.systemYellow
        } else if let button = field as? NSButton {
            button.layer?.backgroundColor = NSColor.systemYellow.cgColor
        }
    }


    // Clear field highlight
    func clearHighlight(_ field: NSControl) {
        if let textField = field as? NSTextField {
            textField.backgroundColor = nil
        } else if let button = field as? NSButton {
            button.layer?.backgroundColor = NSColor.clear.cgColor
//            button.backgroundColor = nil // Optionally ensure backgroundColor is reset
        }
    }
    
//    func clearHighlight(_ field: NSControl) {
//        if let textField = field as? NSTextField {
//            textField.layer?.borderColor = NSColor.clear.cgColor
//            textField.layer?.borderWidth = 0.0
//        } else if let button = field as? NSButton {
//            button.layer?.backgroundColor = NSColor.clear.cgColor
//        }
//    }

    
    
    func setTextViewBorder(field: NSTextView, color: NSColor) {
        guard let scrollView = field.enclosingScrollView else {
            #if DEBUG
            print("No enclosing NSScrollView found.")
            #endif
            return
        }
        scrollView.layer?.borderColor = color.cgColor
        scrollView.layer?.borderWidth = 2.0
        scrollView.layer?.cornerRadius = 4.0  // Optional: Rounded corners
        scrollView.wantsLayer = true  // Ensure the layer is active
    }

    
    // MARK: - Help Buttons
    @IBAction func showHelpForDeveloper(_ sender: NSButton) {
        // Create the full string
        let helpText = NSMutableAttributedString(string: "Optionally, enter the Developer of this app. The Developer does not appears in the Company Portal app.\n\nThis only appears in the Intune Management Console.")

        // Add custom styling for the rest of the text
        helpText.addAttributes([
            .foregroundColor: NSColor.textColor,
            .font: NSFont.systemFont(ofSize: 13)
        ], range: NSRange(location: 0, length: helpText.length))

        // Show the popover
        helpPopover.showHelp(anchorView: sender, helpText: helpText)
    }

    @IBAction func showHelpForInformationURL(_ sender: NSButton) {
        // Create the full string
        let helpText = NSMutableAttributedString(string: "Optionally, enter the URL of a website that contains information about this app.\n\nThis URL appears in the Company Portal app.")

        // Add custom styling for the rest of the text
        helpText.addAttributes([
            .foregroundColor: NSColor.textColor,
            .font: NSFont.systemFont(ofSize: 13)
        ], range: NSRange(location: 0, length: helpText.length))

        // Show the popover
        helpPopover.showHelp(anchorView: sender, helpText: helpText)
    }

    @IBAction func showHelpForOwner(_ sender: NSButton) {
        // Create the full string
        let helpText = NSMutableAttributedString(string: "Optionally, enter the owner for this application. The owner does not appears in the Company Portal app.\n\nThis only appears in the Intune Management Console.")

        // Add custom styling for the rest of the text
        helpText.addAttributes([
            .foregroundColor: NSColor.textColor,
            .font: NSFont.systemFont(ofSize: 13)
        ], range: NSRange(location: 0, length: helpText.length))

        // Show the popover
        helpPopover.showHelp(anchorView: sender, helpText: helpText)
    }

    @IBAction func showHelpForPrivacyURL(_ sender: NSButton) {
        // Create the full string
        let helpText = NSMutableAttributedString(string: "Optionally, enter the URL of a website that contains privacy information about this app.\n\nThis URL appears in the Company Portal app.")

        // Add custom styling for the rest of the text
        helpText.addAttributes([
            .foregroundColor: NSColor.textColor,
            .font: NSFont.systemFont(ofSize: 13)
        ], range: NSRange(location: 0, length: helpText.length))

        // Show the popover
        helpPopover.showHelp(anchorView: sender, helpText: helpText)
    }

    @IBAction func showHelpForNotes(_ sender: NSButton) {
        // Create the full string
        let helpText = NSMutableAttributedString(string: "Optionally, enter notes about this app.\n\nThis only appears in the Intune Management Console.")

        // Add custom styling for the rest of the text
        helpText.addAttributes([
            .foregroundColor: NSColor.textColor,
            .font: NSFont.systemFont(ofSize: 13)
        ], range: NSRange(location: 0, length: helpText.length))

        // Show the popover
        helpPopover.showHelp(anchorView: sender, helpText: helpText)
    }

    
}


    
