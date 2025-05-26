//
//  EditViewController+Icon.swift
//  Intuneomator
//
//  Created by Gil Burns on 5/25/25.
//

import Foundation
import AppKit
import UniformTypeIdentifiers

extension EditViewController {
 
    // MARK: - Icon
    @IBAction func editIcon(_ sender: Any) {
        progImageEdit.startAnimation(self)
        
        let labelFolder = "\(appData!.label)_\(appData!.guid)"
        
        let dialog = NSOpenPanel()
        dialog.allowsMultipleSelection = false
        dialog.allowedContentTypes = [.png, .jpeg, .gif, .bmp, .tiff, .heif, .application]
        dialog.message = "Select an image file or app bundle…"
        
        var url: URL?
        if dialog.runModal() == .OK {
            if dialog.url == nil {
                //                print("No file selected")
                progImageEdit.stopAnimation(self)
                return
            } else {
                url = dialog.url
            }
        }
        
        do {
            XPCManager.shared.importIconToLabel(url!.path, labelFolder) { success in
                if success! {
                    DispatchQueue.main.async {
                        self.loadIcon()
                    }
                } else {
                    //                    print("Failed to reset icon")
                }
            }
        }
        progImageEdit.stopAnimation(self)
    }
    
    @IBAction func defaultIcon(_ sender: Any) {
        progImageEdit.startAnimation(self)
        
        let labelFolder = "\(appData!.label)_\(appData!.guid)"
        
        do {
            XPCManager.shared.importGenericIconToLabel(labelFolder) { success in
                if success! {
                    DispatchQueue.main.async {
                        self.loadIcon()
                        self.progImageEdit.stopAnimation(self)
                    }
                } else {
                    self.progImageEdit.stopAnimation(self)
                    //                    print("Failed to reset icon")
                }
            }
        }
    }
    
    func loadIcon() {
        //        print("Loading icon for label: \(appData!.label)")
        let iconPath = getLabelImagePath()
        if let icon = NSImage(contentsOfFile: iconPath!) {
            //            print("Loaded icon for path: \(iconPath ?? "")")
            buttonIcon.image = icon
        } else {
            //            print("Failed to load icon for path: \(iconPath ?? "")")
        }
    }
    
    
    private func getLabelImagePath() -> String? {
        guard let label = appData?.label else {
            //            print("Error: appData or label is nil.")
            return nil
        }
        
        guard let guid = appData?.guid else {
            //            print("Error: appData or guid is nil.")
            return nil
        }
        
        let labelDirPath = AppConstants.intuneomatorManagedTitlesFolderURL
            .appendingPathComponent("\(label)_\(guid)")
        
        return labelDirPath
            .appendingPathComponent("\(label).png")
            .path
    }
    
    
    private func saveIcon(_ icon: NSImage, to path: String) {
        let imageRep = NSBitmapImageRep(data: icon.tiffRepresentation!)
        guard let pngData = imageRep?.representation(using: .png, properties: [:]) else { return }
        do {
            try pngData.write(to: URL(fileURLWithPath: path))
        } catch {
            Logger.logUser("Failed to save icon: \(error)")
        }
    }
    
    
    func iconForFileExtension(_ fileExtension: String) -> NSImage? {
        if let utType = UTType(filenameExtension: fileExtension) {
            return NSWorkspace.shared.icon(for: utType)
        }
        return nil
    }
    
    func iconForApp(bundleIdentifier: String) -> NSImage? {
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
            return NSWorkspace.shared.icon(forFile: appURL.path)
        }
        return nil
    }
    
}
