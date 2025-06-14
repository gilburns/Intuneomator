//
//  PresentSheetExtension.swift
//  Intuneomator
//
//  Created by Gil Burns on 1/11/25.
//

// PresentSheetExtension.swift
import Cocoa

// Extend NSViewController for presenting sheets
extension NSViewController {
    func presentSheet(withIdentifier identifier: String, passing data: AppInfo? = nil, parent: TabViewController? = nil) {
        guard let storyboard = storyboard,
              let sheetController = storyboard.instantiateController(withIdentifier: identifier) as? NSViewController else {
            Logger.error("Failed to instantiate view controller with identifier: \(identifier)", category: .core, toUserDirectory: true)
            return
        }

        if let configurableController = sheetController as? Configurable,
           let passedData = data,
           let parent = parent {
            configurableController.configure(with: passedData, parent: parent)
        }

        presentAsSheet(sheetController)
    }
}
