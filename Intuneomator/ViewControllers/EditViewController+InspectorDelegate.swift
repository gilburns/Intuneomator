//
//  EditViewController+InspectorDelegate.swift
//  Intuneomator
//
//  Created by Gil Burns on 5/23/25.
//

import Foundation

// MARK: PkgInspector Closed
extension EditViewController: PkgInspectorDelegate {
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


// MARK: AppInspector Closed
extension EditViewController: AppInspectorDelegate {
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
