//
//  EditViewController+MetadataSave.swift
//  Intuneomator
//
//  Created by Gil Burns on 5/25/25.
//

import Foundation


extension EditViewController: TabSaveable {
    // MARK: - Save Metadata
    func saveMetadata() {
        // Save logic for the Edit tab
        //        print("Saving data for EditView...")
        
        guard let appData = appData else { return }
        
        let labelFolder = "\(appData.label)_\(appData.guid)"
        
        
        let partialDeveloper = currentMetadataPartial?.developer
        let partialInformationURL = currentMetadataPartial?.informationUrl
        let partialNotes = currentMetadataPartial?.notes
        let partialOwner = currentMetadataPartial?.owner
        let partialPrivacyInformationUrl = currentMetadataPartial?.privacyInformationUrl
        
        // Prepare data for saving
        let metadata = Metadata(
            categories: getSelectedCategories().compactMap { id in
                // Lookup the category by ID to get the displayName
                if let category = categories.first(where: { $0["id"] as? String == id }),
                   let displayName = category["displayName"] as? String {
                    return Category(displayName: displayName, id: id)
                }
                return nil // Skip if not found
            },
            description: fieldLabelDescription.string,
            deployAsArchTag: getDeployAsArchTag() ?? 0,
            deploymentTypeTag: getDeploymentTypeTag() ?? 0,
            developer: partialDeveloper ?? "",
            informationUrl: partialInformationURL ?? "",
            ignoreVersionDetection: (radioNo.state == .off),
            isFeatured: (buttonFeatureApp.state == .on),
            isManaged: (buttonManagedApp.state == .on),
            minimumOS: getSelectedMinimumOsID() ?? "",
            minimumOSDisplay: buttonPopUpMinimumOs.selectedItem?.title ?? "",
            notes: partialNotes,
            owner: partialOwner,
            privacyInformationUrl: partialPrivacyInformationUrl,
            publisher: fieldPublisher.stringValue,
            CFBundleIdentifier: fieldIntuneID.stringValue
        )
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            
            let jsonData = try encoder.encode(metadata)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                XPCManager.shared.saveMetadataForLabel(jsonString, labelFolder) { reply in
                    if reply == true {
                        Logger.logUser("Saved metadata for \(labelFolder)")
                    } else {
                        Logger.logUser("Failed to save metadata for \(labelFolder)")
                    }
                }
            } else {
                Logger.logUser("Failed to convert metadata JSON data to string.")
            }
        } catch {
            Logger.logUser("Error encoding metadata: \(error)")
        }
    }
}

