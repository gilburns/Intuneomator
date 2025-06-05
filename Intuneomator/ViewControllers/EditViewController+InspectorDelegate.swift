///
///  EditViewController+InspectorDelegate.swift
///  Intuneomator
///
///  Extension for `EditViewController` to handle inspector callbacks.
///  Implements `PkgInspectorDelegate` and `AppInspectorDelegate` to receive metadata
///  (ID, version, publisher, minimum OS) from inspectors and update the corresponding UI fields.
///
  
//
//  EditViewController+InspectorDelegate.swift
//  Intuneomator
//
//  Created by Gil Burns on 5/23/25.
//

import Foundation

/// Conformance to `PkgInspectorDelegate`.
/// Receives package metadata when the pkg inspector finishes and updates UI fields.


// MARK: PkgInspector Closed
extension EditViewController: PkgInspectorDelegate {
    /// Called when the package inspector has saved metadata.
    ///
    /// - Parameters:
    ///   - pkgID: The package identifier, if available.
    ///   - pkgVersion: The package version string, if available.
    ///   - pkgPublisher: The package publisher name, if available.
    ///   - pkgMinOSVersion: The minimum supported macOS version for the package, if available.
    /// 
    /// Updates the corresponding text fields (`fieldIntuneID`, `fieldIntuneVersion`, `fieldPublisher`)
    /// and selects the minimum OS version in the popup. Then performs cleanup, reloads the icon,
    /// and tracks changes on the main thread.
    func pkgInspectorDidSave(pkgID: String?, pkgVersion: String?, pkgPublisher: String?, pkgMinOSVersion: String?) {
        // Update fields based on the returned data
        if let pkgID = pkgID {
            fieldIntuneID.stringValue = pkgID
        }
        if let pkgVersion = pkgVersion {
            fieldIntuneVersion.stringValue = pkgVersion
        }
        if let pkgPublisher = pkgPublisher {
            fieldPublisher.stringValue = pkgPublisher
        }

        if let pkgMinOSVersion = pkgMinOSVersion {
            selectMinimumOSPopupItem(displayString: pkgMinOSVersion)
        }

        cleanupAfterProcessing()

        DispatchQueue.main.async {
            self.loadIcon()
            self.trackChanges()
        }
    }
}

/// Conformance to `AppInspectorDelegate`.
/// Receives application metadata when the app inspector finishes and updates UI fields.


// MARK: AppInspector Closed
extension EditViewController: AppInspectorDelegate {
    /// Called when the app inspector has saved metadata.
    ///
    /// - Parameters:
    ///   - appID: The application identifier (bundle ID), if available.
    ///   - appVersion: The application version string, if available.
    ///   - appPublisher: The application publisher name, if available.
    ///   - appMinOSVersion: The minimum supported macOS version for the application, if available.
    ///
    /// Updates the corresponding text fields (`fieldIntuneID`, `fieldIntuneVersion`, `fieldPublisher`)
    /// and selects the minimum OS version in the popup. Then performs cleanup, reloads the icon,
    /// and tracks changes on the main thread.
    func appInspectorDidSave(appID: String?, appVersion: String?, appPublisher: String?, appMinOSVersion: String?) {
        
        
        // Update fields based on the returned data
        if let appID = appID {
            fieldIntuneID.stringValue = appID
        }
        if let appVersion = appVersion {
            fieldIntuneVersion.stringValue = appVersion
        }
        if let appPublisher = appPublisher {
            fieldPublisher.stringValue = appPublisher
        }
        
        if let appMinOSVersion = appMinOSVersion {
            selectMinimumOSPopupItem(displayString: appMinOSVersion)
        }
                
        cleanupAfterProcessing()

        DispatchQueue.main.async {
            self.loadIcon()
            self.trackChanges()
        }

    }
}
