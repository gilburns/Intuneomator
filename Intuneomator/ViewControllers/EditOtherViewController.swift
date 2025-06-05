///
///  EditOtherViewController.swift
///  Intuneomator
///
///  View controller for editing optional application metadata fields.
///  Provides UI for developer, owner, information URL, privacy URL, and notes.
///  - Tracks changes and highlights modified fields.
///  - Persists window size preferences.
///  - Uses delegate pattern to notify when changes are saved.
//

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

/// Sheet view controller for editing optional application metadata fields
/// Provides an interface for configuring additional app details that supplement the main metadata
///
/// **Key Features:**
/// - Edits optional metadata: developer, owner, information URL, privacy URL, and notes
/// - Tracks changes and highlights modified fields in real-time
/// - Maintains persistent window size preferences
/// - Provides contextual help for each metadata field
/// - Validates data before saving through delegate pattern
class EditOtherViewController: NSViewController, NSTextStorageDelegate {
    
    /// Label displaying the application name for which optional metadata is being edited.
    @IBOutlet weak var labelAppName: NSTextField!
    
    /// Text field for entering or displaying the "Developer" metadata.
    @IBOutlet weak var fieldDeveloper: NSTextField!
    /// Text field for entering or displaying the "Information URL" for the application.
    @IBOutlet weak var fieldInfomationURL: NSTextField!
    /// Text view for entering or displaying the "Notes" metadata.
    @IBOutlet weak var fieldNotes: NSTextView!
    /// Text field for entering or displaying the "Owner" metadata.
    @IBOutlet weak var fieldOwner: NSTextField!
    /// Text field for entering or displaying the "Privacy Information URL" for the application.
    @IBOutlet weak var fieldPrivacyInfomationURL: NSTextField!

    /// Button to save any changes made to optional metadata and dismiss the sheet.
    @IBOutlet weak var buttonSave: NSButton!
    
    /// Tracks whether any optional metadata fields have been modified since loading.
    var hasUnsavedChanges = false
    
    /// The display name of the application whose metadata is being edited.
    var appName: String?
    
    /// The metadata values loaded when the sheet opened, used for change tracking.
    var lastMetadataPartial: MetadataPartial?
    /// The metadata values currently being edited in the UI.
    var currentMetadataPartial: MetadataPartial?

    /// Delegate to notify when changes are saved via the "Save" button.
    weak var delegate: EditOtherViewControllerDelegate?

    /// Popover instance used to display contextual help messages for metadata fields.
    private let helpPopover = HelpPopover()


    // MARK: - Lifecycle
    /// Called after the view controller’s view has loaded.
    /// - Sets the text storage delegate to track notes changes.
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
    
    /// Called just before the view appears.
    /// - Restores saved sheet size or applies default size.
    /// - Sets the window minimum size.
    /// - Updates the app name label.
    /// - Populates UI fields with existing metadata.
    /// - Initiates change tracking.
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

    
    /// Loads previously saved sheet size from UserDefaults.
    /// - Returns: The saved sheet size, or nil if none was saved.
    private func loadSavedSheetSize() -> NSSize? {
        if let sizeDict = UserDefaults.standard.dictionary(forKey: "EditOtherViewSheetSize") as? [String: CGFloat],
           let width = sizeDict["width"], let height = sizeDict["height"] {
            return NSSize(width: width, height: height)
        }
        return nil
    }

    
    
    // MARK: - Actions
    
    /// Action invoked when the "Save" button is clicked.
    /// - Saves current field values into `currentMetadataPartial`.
    /// - Calls delegate to notify of saved metadata.
    /// - Dismisses the sheet.
    /// - Parameter sender: The "Save" button control.
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
    
    /// Action invoked when the "Cancel" or close button is clicked.
    /// - Dismisses the sheet without saving changes.
    /// - Parameter sender: The control that triggered the dismissal.
    @IBAction func dismissSheet(_ sender: NSButton) {
        self.dismiss(self)
    }

    
    
    
    /// Populates UI fields with values from `currentMetadataPartial`.
    /// - Sets developer, information URL, owner, privacy URL, and notes fields.
    private func populateFieldsFromData() {
        
        fieldDeveloper.stringValue = currentMetadataPartial?.developer ?? ""
        fieldInfomationURL.stringValue = currentMetadataPartial?.informationUrl ?? ""
        fieldOwner.stringValue = currentMetadataPartial?.owner ?? ""
        fieldPrivacyInfomationURL.stringValue = currentMetadataPartial?.privacyInformationUrl ?? ""
        
        fieldNotes.string = currentMetadataPartial?.notes ?? ""

    }
    
    // MARK: - Track Changes in the GUI
    /// Called when the Developer text field value changes.
    /// - Triggers change tracking to update highlights and save button state.
    /// - Parameter sender: The Developer text field.
    @IBAction func fieldDeveloperDidChange(_ sender: NSTextField) {
        trackChanges()
    }

    /// Called when the Information URL text field value changes.
    /// - Triggers change tracking to update highlights and save button state.
    /// - Parameter sender: The Information URL text field.
    @IBAction func fieldInfoURLDidChange(_ sender: NSTextField) {
        trackChanges()
    }

    /// Called when the Owner text field value changes.
    /// - Triggers change tracking to update highlights and save button state.
    /// - Parameter sender: The Owner text field.
    @IBAction func fieldOwnerDidChange(_ sender: NSTextField) {
        trackChanges()
    }
    
    /// Called when the Privacy URL text field value changes.
    /// - Triggers change tracking to update highlights and save button state.
    /// - Parameter sender: The Privacy URL text field.
    @IBAction func fieldPrivacyURLDidChange(_ sender: NSTextField) {
        trackChanges()
    }


    /// NSTextStorageDelegate callback invoked after the notes text view processes editing.
    /// - Triggers change tracking to update highlights and save button state.
    /// - Parameters:
    ///   - textStorage: The NSTextStorage instance for the notes field.
    ///   - didProcessEditing: The editing actions processed.
    ///   - range: The edited text range.
    ///   - changeInLength: The change in text length.
    func textStorage(_ textStorage: AppKit.NSTextStorage, didProcessEditing editedMask: AppKit.NSTextStorageEditActions, range editedRange: NSRange, changeInLength delta: Int) {

        // Trigger tracking changes
//        print("Tracking")
        trackChanges()
    }

    
    /// Compares current UI field values against `lastMetadataPartial`.
    /// - Updates `currentMetadataPartial` with field values.
    /// - Highlights fields whose values differ.
    /// - Enables or disables the Save button based on whether changes exist.
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
    
    /// Clears any visual highlight (background or border) from all metadata input fields.
    private func clearFieldHighlights() {

        fieldDeveloper.backgroundColor = nil
        fieldInfomationURL.backgroundColor = nil
        fieldOwner.backgroundColor = nil
        fieldPrivacyInfomationURL.backgroundColor = nil

        setTextViewBorder(field: fieldNotes, color: NSColor.clear)

    }

    /// Highlights individual fields where `currentMetadataPartial` differs from `lastMetadataPartial`.
    /// - Uses yellow background for text fields and border for notes text view.
    func highlightChangedFields() {
        
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
    
    /// Applies a yellow background to the specified control to indicate it has changed.
    /// - Parameter field: The control (NSTextField or NSButton) to highlight.
    private func highlightField(_ field: NSControl) {
        if let textField = field as? NSTextField {
            textField.backgroundColor = NSColor.systemYellow
        } else if let button = field as? NSButton {
            button.layer?.backgroundColor = NSColor.systemYellow.cgColor
        }
    }


    /// Removes any highlight (background color) from the specified control.
    /// - Parameter field: The control (NSTextField or NSButton) to clear highlight from.
    func clearHighlight(_ field: NSControl) {
        if let textField = field as? NSTextField {
            textField.backgroundColor = nil
        } else if let button = field as? NSButton {
            button.layer?.backgroundColor = NSColor.clear.cgColor
//            button.backgroundColor = nil // Optionally ensure backgroundColor is reset
        }
    }
    
    
    /// Sets a colored border around the enclosing scroll view of a text view.
    /// - Parameters:
    ///   - field: The NSTextView whose border should be updated.
    ///   - color: The NSColor to apply to the border.
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
    /// Shows contextual help for the Developer field in a popover.
    /// - Parameter sender: The help button that was clicked.
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

    /// Shows contextual help for the Information URL field in a popover.
    /// - Parameter sender: The help button that was clicked.
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

    /// Shows contextual help for the Owner field in a popover.
    /// - Parameter sender: The help button that was clicked.
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

    /// Shows contextual help for the Privacy Information URL field in a popover.
    /// - Parameter sender: The help button that was clicked.
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

    /// Shows contextual help for the Notes field in a popover.
    /// - Parameter sender: The help button that was clicked.
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

    
