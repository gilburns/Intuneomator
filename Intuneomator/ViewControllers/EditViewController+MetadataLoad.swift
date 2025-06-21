///
///  EditViewController+LoadMetadata.swift
///  Intuneomator
///
///  Extension for `EditViewController` to load application metadata.
///  Handles reading the `metadata.json` file for a given label, decoding it into
///  a `Metadata` object, populating UI fields, and setting default metadata values
///  when no file is found.
///

//
//  EditViewController+LoadMetadata.swift
//  Intuneomator
//
//  Created by Gil Burns on 5/25/25.
//

import Foundation
import AppKit

/// Extension for `EditViewController` that adds metadata loading functionality.
/// Implements methods to read and decode metadata from disk and initialize default
/// values for UI controls when no metadata file exists.
extension EditViewController {
    
    /// Attempts to load metadata from `metadata.json` for the currently selected label.
    ///
    /// This method constructs the file path using `appData.label` and `appData.guid`,
    /// reads the JSON data, decodes it into `appMetadata`, and populates the UI fields.
    /// If loading or decoding fails (e.g., file not found), it calls
    /// `setDefaultMetadataValues()` to initialize default UI values.
    ///
    /// After loading (or setting defaults), it extracts specific fields (developer,
    /// information URL, notes, owner, and privacy information URL) to populate
    /// both `lastMetadataPartial` and `currentMetadataPartial` for change tracking.
    func loadMetadata() {
        guard let labelName = appData?.label else {
            return
        }
        
        guard let labelGUID = appData?.guid else {
            return
        }
        
        let filePath = AppConstants.intuneomatorManagedTitlesFolderURL
            .appendingPathComponent("\(labelName)_\(labelGUID)")
            .appendingPathComponent("metadata.json")
        
        do {
            let data = try Data(contentsOf: filePath)
            appMetadata = try JSONDecoder().decode(Metadata.self, from: data)
            
        } catch {
            setDefaultMetadataValues() // Set defaults when no metadata file is found
        }
        
        populateFieldsFromAppMetadata()
        
        let developer = appMetadata?.developer ?? ""
        let informationURL = appMetadata?.informationUrl ?? ""
        let notes = appMetadata?.notes ?? ""
        let owner = appMetadata?.owner ?? ""
        let privacyInformationURL = appMetadata?.privacyInformationUrl ?? ""
        
        appMetadata?.developer = developer
        appMetadata?.informationUrl = informationURL
        appMetadata?.notes = notes
        appMetadata?.owner = owner
        appMetadata?.privacyInformationUrl = privacyInformationURL
        
        lastMetadataPartial = MetadataPartial(
            developer: developer,
            informationUrl: informationURL,
            notes: notes,
            owner: owner,
            privacyInformationUrl: privacyInformationURL
        )
        
        currentMetadataPartial = lastMetadataPartial!
        
    }
    
    /// Sets default metadata values for all relevant UI controls when no metadata file is found.
    ///
    /// Initializes text fields (publisher, Intune ID), radio buttons (version detection,
    /// featured app, managed app), deployment type pulldown, and category selections.
    /// It also constructs a `defaultMetadata` object to represent baseline metadata and
    /// assigns it to `lastLoadedMetadata` for future comparison.
    private func setDefaultMetadataValues() {
        
        // Set default values for GUI items
        fieldPublisher.stringValue = ""
        if let defaultOsItem = buttonPopUpMinimumOs.item(withTitle: "macOS Ventura 13.0") {
            buttonPopUpMinimumOs.select(defaultOsItem)
        } else {
            buttonPopUpMinimumOs.select(nil) // Clear selection if default item not found
        }
        fieldIntuneID.stringValue = ""
        AppDataManager.shared.currentAppBundleID = ""
        radioYes.state = .off
        radioNo.state = .on
        buttonFeatureApp.state = .off
        buttonManagedApp.state = .off
        buttonDeploymentType.selectItem(withTag: 0)
        
        // Set default categories
        selectedCategories = [] // No categories selected
        populateCategories()
        updateCategoryButtonTitle()
        
        // Create a default metadata object to use as baseline
        let defaultMetadata = Metadata(
            categories: [],
            description: "",
            deployAsArchTag: 0,
            deploymentTypeTag: 0,
            developer: "",
            informationUrl: "",
            ignoreVersionDetection: false,
            isFeatured: false,
            isManaged: false,
            minimumOS: "v13_0",
            minimumOSDisplay: "macOS Ventura 13.0",
            notes: "",
            owner: "",
            privacyInformationUrl: "",
            publisher: "",
            CFBundleIdentifier: ""
        )
        lastLoadedMetadata = defaultMetadata // Use this for future change comparisons
    }

    
}
