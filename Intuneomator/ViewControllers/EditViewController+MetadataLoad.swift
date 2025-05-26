//
//  EditViewController+LoadMetadata.swift
//  Intuneomator
//
//  Created by Gil Burns on 5/25/25.
//

import Foundation
import AppKit

extension EditViewController {
    
    // MARK: - Load Metadata File - if present
    func loadMetadata() {
        guard let labelName = appData?.label else {
            //            print("Label name is missing.")
            return
        }
        
        guard let labelGUID = appData?.guid else {
            //            print("GUID is missing.")
            return
        }
        
        let filePath = AppConstants.intuneomatorManagedTitlesFolderURL
            .appendingPathComponent("\(labelName)_\(labelGUID)")
            .appendingPathComponent("metadata.json")
        
        do {
            let data = try Data(contentsOf: filePath)
            appMetadata = try JSONDecoder().decode(Metadata.self, from: data)
            
        } catch {
            //            print("Failed to load metadata: \(error)")
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
    
    private func setDefaultMetadataValues() {
        //        print("Setting default metadata values.")
        
        // Set default values for GUI items
        fieldPublisher.stringValue = ""
        if let defaultOsItem = buttonPopUpMinimumOs.item(withTitle: "macOS Ventura 13.0") {
            buttonPopUpMinimumOs.select(defaultOsItem)
        } else {
            buttonPopUpMinimumOs.select(nil) // Clear selection if default item not found
        }
        fieldIntuneID.stringValue = ""
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
