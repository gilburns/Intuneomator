///
///  EditViewController+MetadataSave.swift
///  Intuneomator
///
///  Extension for `EditViewController` to handle saving metadata.
///  Implements the `TabSaveable` protocol to serialize and save application metadata
///  such as categories, descriptions, and other properties to the daemon.
///
  
//
//  EditViewController+MetadataSave.swift
//  Intuneomator
//
//  Created by Gil Burns on 5/25/25.
//

import Foundation

/// Conforms `EditViewController` to `TabSaveable` by implementing the `saveMetadata` method.
/// This extension handles gathering all fields from the UI, encoding them into JSON,
/// and sending the data to the XPC manager to persist metadata for the selected label.

extension EditViewController: TabSaveable {
    /// Collects metadata from various UI fields and partial metadata properties,
    /// encodes them into a structured `Metadata` object, serializes it to JSON,
    /// and invokes the XPC service to save the JSON string into the corresponding label folder.
    ///
    /// The metadata includes:
    ///  - Categories (with display names and IDs)
    ///  - Description text
    ///  - Deployment architecture and type tags
    ///  - Developer, information URL, notes, owner, privacy information URL
    ///  - Publisher name and bundle identifier
    ///  - Flags for version detection, featured app, and managed app
    ///  - Minimum OS ID and display string
    ///
    /// All fields are gathered from `appData`, `currentMetadataPartial`, and UI controls.
    /// Errors during encoding or string conversion are logged via `Logger.logUser`.
    /// On successful save, a confirmation is logged; on failure, an error is logged.
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
