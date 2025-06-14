///
///  EditViewController+TrackChanges.swift
///  Intuneomator
///
///  Extension for `EditViewController` to track and highlight changes in the Edit View.
///  Compares current UI data against loaded metadata and default values, highlighting fields
///  with unsaved changes. Provides utility methods to clear and set highlights.
///

//
//  EditViewController+TrackChanges.swift
//  Intuneomator
//
//  Created by Gil Burns on 5/23/25.
//

import Foundation
import AppKit

/// Extension adding change-tracking functionality to `EditViewController`.
/// Monitors UI fields and metadata objects to detect modifications, highlights
/// changed controls, and notifies the parent view to update save button state.
extension EditViewController {
    
    /// Evaluates whether the current metadata in the UI differs from the last loaded metadata or defaults.
    /// Builds a `currentMetadata` object from UI fields and partial metadata, compares it to `lastLoadedMetadata`.
    /// If no previous metadata exists, highlights any non-default fields. If differences are found,
    /// highlights individual fields that have changed. Updates `hasUnsavedChanges` and notifies parent.
    func trackChanges() {
        // Build the current metadata state from the UI
        
        let developer = currentMetadataPartial?.developer ?? ""
        let informationURL = currentMetadataPartial?.informationUrl ?? ""
        let notes = currentMetadataPartial?.notes ?? ""
        let owner = currentMetadataPartial?.owner ?? ""
        let privacyInformationURL = currentMetadataPartial?.privacyInformationUrl ?? ""

        
        currentMetadata = Metadata(
            categories: getSelectedCategories().compactMap { id in
                if let category = categories.first(where: { $0["id"] as? String == id }),
                   let displayName = category["displayName"] as? String {
                    return Category(displayName: displayName, id: id)
                }
                return nil
            },
            description: fieldLabelDescription.string,
            deployAsArchTag: getDeployAsArchTag() ?? 0,
            deploymentTypeTag: getDeploymentTypeTag() ?? 0,
            developer: developer,
            informationUrl: informationURL,
            ignoreVersionDetection: (radioYes.state == .on),
            isFeatured: (buttonFeatureApp.state == .on),
            isManaged: (buttonManagedApp.state == .on),
            minimumOS: getSelectedMinimumOsID() ?? "",
            minimumOSDisplay: buttonPopUpMinimumOs.selectedItem?.title ?? "",
            notes: notes,
            owner: owner,
            privacyInformationUrl: privacyInformationURL,
            publisher: fieldPublisher.stringValue,
            CFBundleIdentifier: fieldIntuneID.stringValue
        )
        
        // Case 1: No previously loaded metadata
        guard let lastMetadata = lastLoadedMetadata else {
            hasUnsavedChanges = false
            highlightChangesAgainstDefaults(currentMetadata: currentMetadata!)
            
            // Notify TabViewController to update the Save button state
            parentTabViewController?.updateSaveButtonState()
            return
        }

        // Case 2: Compare current metadata with last loaded metadata
        _ = Set(currentMetadata!.categories.map { $0.id })
        _ = Set(lastMetadata.categories.map { $0.id })

        if currentMetadata != lastMetadata {
            hasUnsavedChanges = true
            highlightChangedFields(currentMetadata: currentMetadata!, lastMetadata: lastMetadata)
        } else {
            hasUnsavedChanges = false
            clearFieldHighlights()
        }

        // Notify TabViewController to update the Save button state
        parentTabViewController?.updateSaveButtonState()
    }

    
    /// Highlights fields whose values differ from assumed default metadata values.
    /// Examines each property in `currentMetadata` and applies a yellow background to any control
    /// whose value is not the default. Marks `hasUnsavedChanges` if any highlights occur.
    private func highlightChangesAgainstDefaults(currentMetadata: Metadata) {
        hasUnsavedChanges = false // Reset state before comparing fields

        // Highlight if categories are non-empty
        if !currentMetadata.categories.isEmpty {
            highlightField(buttonSelectCategories)
            hasUnsavedChanges = true
        }


        // Highlight if publisher is not empty
        if !currentMetadata.publisher.isEmpty {
            highlightField(fieldPublisher)
            hasUnsavedChanges = true
        }

        // Highlight if minimumOS is not empty
        if !currentMetadata.minimumOS.isEmpty {
            highlightField(buttonPopUpMinimumOs)
            hasUnsavedChanges = true
        }

        // Highlight if deployAsArchTag is not empty
        if (currentMetadata.deployAsArchTag >= 0) {
            highlightField(buttonDeployAsArch)
            hasUnsavedChanges = true
        }

        // Highlight if deploymentTypeTag is not empty
        if (currentMetadata.deploymentTypeTag >= 0) {
            highlightField(buttonDeploymentType)
            hasUnsavedChanges = true
        }

        
        // Highlight if CFBundleIdentifier is not empty
        if !currentMetadata.CFBundleIdentifier.isEmpty {
            highlightField(fieldIntuneID)
            hasUnsavedChanges = true
        }

        // Highlight if ignoreVersionDetection is not its default value
        if currentMetadata.ignoreVersionDetection != true { // Assume true as default
            highlightField(radioNo)
            hasUnsavedChanges = true
        }

        // Highlight if isFeature is not its default value
        if currentMetadata.isFeatured != false { // Assume false as default
            highlightField(buttonFeatureApp)
            hasUnsavedChanges = true
        }

        // Highlight if isManaged is not its default value
        if currentMetadata.isManaged != false { // Assume false as default
            highlightField(buttonManagedApp)
            hasUnsavedChanges = true
        }

        // Highlight the description field
        if !currentMetadata.description.isEmpty {
            setTextViewBorder(field: fieldLabelDescription, color: NSColor.systemYellow)
            hasUnsavedChanges = true
        }
        

        // Notify TabViewController about unsaved changes if any
        parentTabViewController?.updateSaveButtonState()
    }


    /// Clears all highlight backgrounds and borders from tracked UI fields.
    /// Resets any visual indicators of unsaved changes.
    private func clearFieldHighlights() {
        clearHighlight(buttonSelectCategories)
//        fieldInfoURL.backgroundColor = nil
        fieldPublisher.backgroundColor = nil
        buttonPopUpMinimumOs.layer?.backgroundColor = nil
        buttonDeployAsArch.layer?.backgroundColor = nil
        fieldIntuneID.backgroundColor = nil
        radioYes.layer?.backgroundColor = nil
        radioNo.layer?.backgroundColor = nil
        buttonFeatureApp.layer?.backgroundColor = nil
        buttonManagedApp.layer?.backgroundColor = nil
        buttonDeploymentType.layer?.backgroundColor = nil
        setTextViewBorder(field: fieldLabelDescription, color: NSColor.clear)
        clearHighlight(buttonEditOther)
    }

    
    /// Compares `currentMetadata` and `lastMetadata`, highlighting each UI field where values differ.
    /// For each metadata property (publisher, bundle ID, categories, etc.), sets a yellow background
    /// on the corresponding control if changed, or clears it if unchanged.
    func highlightChangedFields(currentMetadata: Metadata, lastMetadata: Metadata) {
        // Highlight informationUrl field if changed
//        if currentMetadata.informationUrl != lastMetadata.informationUrl {
//            highlightField(fieldInfoURL)
//        } else {
//            clearHighlight(fieldInfoURL)
//        }

        // Highlight publisher field if changed
        if currentMetadata.publisher != lastMetadata.publisher {
            highlightField(fieldPublisher)
        } else {
            clearHighlight(fieldPublisher)
        }

        // Highlight CFBundleIdentifier field if changed
        if currentMetadata.CFBundleIdentifier != lastMetadata.CFBundleIdentifier {
            highlightField(fieldIntuneID)
        } else {
            clearHighlight(fieldIntuneID)
        }

        // Check categories
        let currentCategoryIDs = Set(currentMetadata.categories.map { $0.id })
        let lastCategoryIDs = Set(lastMetadata.categories.map { $0.id })
        if currentCategoryIDs != lastCategoryIDs {
            highlightField(buttonSelectCategories)
        } else {
            clearHighlight(buttonSelectCategories)
        }

        // Check minimumOS
        if currentMetadata.minimumOSDisplay != lastMetadata.minimumOSDisplay {
            highlightField(buttonPopUpMinimumOs)
        } else {
            clearHighlight(buttonPopUpMinimumOs)
        }

        // Check deploy as arch
        if currentMetadata.deployAsArchTag != lastMetadata.deployAsArchTag {
            highlightField(buttonDeployAsArch)
        } else {
            clearHighlight(buttonDeployAsArch)
        }

        // Check deployment type
        if currentMetadata.deploymentTypeTag != lastMetadata.deploymentTypeTag {
            highlightField(buttonDeploymentType)
        } else {
            clearHighlight(buttonDeploymentType)
        }

        
        // Check ignoreVersionDetection
        if currentMetadata.ignoreVersionDetection != lastMetadata.ignoreVersionDetection {
            highlightField(radioYes)
            highlightField(radioNo)
        } else {
            clearHighlight(radioYes)
            clearHighlight(radioNo)
        }

        // Check feature in Company Portal
        if currentMetadata.isFeatured != lastMetadata.isFeatured {
            highlightField(buttonFeatureApp)
        } else {
            clearHighlight(buttonFeatureApp)
        }
        
        // Check Managed App
        if currentMetadata.isManaged != lastMetadata.isManaged {
            highlightField(buttonManagedApp)
        } else {
            clearHighlight(buttonManagedApp)
        }
        

        // Check description
        if currentMetadata.description != lastMetadata.description {
            setTextViewBorder(field: fieldLabelDescription, color: NSColor.systemYellow)
        } else {
            setTextViewBorder(field: fieldLabelDescription, color: NSColor.clear)
        }

            // Check other metadata fields
            if currentMetadata.developer != lastMetadata.developer ||
               currentMetadata.informationUrl != lastMetadata.informationUrl ||
               currentMetadata.notes != lastMetadata.notes ||
               currentMetadata.owner != lastMetadata.owner ||
               currentMetadata.privacyInformationUrl != lastMetadata.privacyInformationUrl {
                highlightField(buttonEditOther)
            } else {
                clearHighlight(buttonEditOther)
            }

    }

    /// Applies a yellow background to the given control to indicate a changed state.
    /// Supports `NSTextField` and `NSButton` types.
    private func highlightField(_ field: NSControl) {
        if let textField = field as? NSTextField {
            textField.backgroundColor = NSColor.systemYellow
        } else if let button = field as? NSButton {
            button.layer?.backgroundColor = NSColor.systemYellow.cgColor
        }
    }


    /// Removes background highlight or border color from the given control, returning it to default appearance.
    func clearHighlight(_ field: NSControl) {
        if let textField = field as? NSTextField {
            textField.layer?.borderColor = NSColor.clear.cgColor
            textField.layer?.borderWidth = 0.0
        } else if let button = field as? NSButton {
            button.layer?.backgroundColor = NSColor.clear.cgColor
        }
    }
    
    /// Adjusts the border of an `NSTextView`'s enclosing scroll view to the specified color.
    /// Used to visually indicate changes in multiline text fields.
    func setTextViewBorder(field: NSTextView, color: NSColor) {
        guard let scrollView = field.enclosingScrollView else {
            #if DEBUG
            Logger.warning("No enclosing NSScrollView found.", category: .core, toUserDirectory: true)
            #endif
            return
        }
        scrollView.layer?.borderColor = color.cgColor
        scrollView.layer?.borderWidth = 2.0
        scrollView.layer?.cornerRadius = 4.0  // Optional: Rounded corners
        scrollView.wantsLayer = true  // Ensure the layer is active
    }


    /// Called when the corresponding UI field value changes, triggering the change-tracking process.
    /// Invokes `trackChanges()` to re-evaluate unsaved modifications.
    /// - Parameter sender: The control that changed (e.g., `NSTextField` or `NSPopUpButton`).
    @IBAction func fieldIntuneIdDidChange(_ sender: NSTextField) {
        trackChanges()
    }

    /// Called when the corresponding UI field value changes, triggering the change-tracking process.
    /// Invokes `trackChanges()` to re-evaluate unsaved modifications.
    /// - Parameter sender: The control that changed (e.g., `NSTextField` or `NSPopUpButton`).
    @IBAction func fieldInfoURLDidChange(_ sender: NSTextField) {
        trackChanges()
    }

    /// Called when the corresponding UI field value changes, triggering the change-tracking process.
    /// Invokes `trackChanges()` to re-evaluate unsaved modifications.
    /// - Parameter sender: The control that changed (e.g., `NSTextField` or `NSPopUpButton`).
    @IBAction func fieldPublisherDidChange(_ sender: NSTextField) {
        trackChanges()
    }

    /// Called when the corresponding UI field value changes, triggering the change-tracking process.
    /// Invokes `trackChanges()` to re-evaluate unsaved modifications.
    /// - Parameter sender: The control that changed (e.g., `NSTextField` or `NSPopUpButton`).
    @IBAction func buttonPopUpMinimumOsDidChange(_ sender: NSPopUpButton) {
        trackChanges()
    }

    /// Called when the corresponding UI field value changes, triggering the change-tracking process.
    /// Invokes `populateFieldsFromAppData()` and `trackChanges()` to update dependent fields and re-evaluate unsaved modifications.
    /// - Parameter sender: The control that changed (e.g., `NSTextField` or `NSPopUpButton`).
    @IBAction func buttonDeployAsArchDidChange(_ sender: NSPopUpButton) {
        populateFieldsFromAppData()
        trackChanges()
        
    }

    /// Called when the corresponding UI field value changes, triggering the change-tracking process.
    /// Updates UI elements and app type based on deployment type selection, then refreshes fields and tracks changes.
    /// - Parameter sender: The control that changed (e.g., `NSTextField` or `NSPopUpButton`).
    @IBAction func buttonDeploymentTypeDidChange(_ sender: NSPopUpButton) {
        
        if sender.selectedItem?.tag == 0 {
//            if buttonDeployAsArch.selectedItem?.tag == 2 {
//                buttonDeployAsArch.selectItem(withTag: 0)
//            }
            menuItemUniversalPkg.isHidden = true
        } else if sender.selectedItem?.tag == 1 {
//            if buttonDeployAsArch.selectedItem?.tag == 0 {
//                buttonDeployAsArch.selectItem(withTag: 2)
//            }
//            if buttonDeployAsArch.selectedItem?.tag == 1 {
//                buttonDeployAsArch.selectItem(withTag: 2)
//            }
            menuItemUniversalPkg.isHidden = false
        }
        
        if sender.selectedItem?.tag == 2 {
            buttonManagedApp.isEnabled = true
            labelManagedApp.textColor = .labelColor

        } else {
            buttonManagedApp.isEnabled = false
            buttonManagedApp.state = .off
            labelManagedApp.textColor = .lightGray

        }
        
        switch sender.selectedItem?.tag {
        case 0:
            AppDataManager.shared.currentAppType = "macOSDmgApp"
        case 1:
            AppDataManager.shared.currentAppType = "macOSPkgApp"
        case 2:
            AppDataManager.shared.currentAppType = "macOSLobApp"
        default:
            AppDataManager.shared.currentAppType = ""
        }
    
        populateFieldsFromAppData()
        trackChanges()
        
    }

    /// Called when the corresponding UI field value changes, triggering the change-tracking process.
    /// Invokes `trackChanges()` to re-evaluate unsaved modifications.
    /// - Parameter sender: The control that changed (e.g., `NSTextField` or `NSPopUpButton`).
    @IBAction func radioButtonDidChange(_ sender: NSButton) {
        trackChanges()
    }

    /// Called when the corresponding UI field value changes, triggering the change-tracking process.
    /// Invokes `trackChanges()` to re-evaluate unsaved modifications.
    /// - Parameter sender: The control that changed (e.g., `NSTextField` or `NSPopUpButton`).
    @IBAction func fieldDescriptionDidChange(_ sender: NSTextView) {
        trackChanges()
    }

    /// Called when the corresponding UI field value changes, triggering the change-tracking process.
    /// Invokes `trackChanges()` to re-evaluate unsaved modifications.
    /// - Parameter sender: The control that changed (e.g., `NSTextField` or `NSPopUpButton`).
    @IBAction func buttonFeatureAppDidChange(_ sender: NSButton) {
        trackChanges()
    }

    /// Called when the corresponding UI field value changes, triggering the change-tracking process.
    /// Invokes `trackChanges()` to re-evaluate unsaved modifications.
    /// - Parameter sender: The control that changed (e.g., `NSTextField` or `NSPopUpButton`).
    @IBAction func buttonManagedAppDidChange(_ sender: NSButton) {
        trackChanges()
    }

    
    /// Marks the view state as having unsaved changes.
    /// Sets `hasUnsavedChanges = true` and notifies the parent TabViewController to update its save button.
    func markUnsavedChanges() {
        hasUnsavedChanges = true
        if let parentVC = parent as? TabViewController {
            parentVC.updateSaveButtonState()
        } else {
        }
        parentTabViewController?.updateSaveButtonState()
    }

    /// Marks that changes have been saved.
    /// Clears `hasUnsavedChanges` and updates the parent TabViewController to disable the save button.
    func markChangesSaved() {
        hasUnsavedChanges = false
        (parent as? TabViewController)?.updateSaveButtonState()
    }

    /// NSTextStorageDelegate callback invoked after text editing in an `NSTextView`.
    /// Triggers `trackChanges()` to detect modifications in text fields.
    func textStorage(_ textStorage: AppKit.NSTextStorage, didProcessEditing editedMask: AppKit.NSTextStorageEditActions, range editedRange: NSRange, changeInLength delta: Int) {

        // Trigger tracking changes
        trackChanges()
    }


    
}
