///
///  EditViewController+Icon.swift
///  Intuneomator
///
///  Extension for `EditViewController` to manage label icons.
///  Provides functionality to import custom or default icons, load and display the current icon,
///  and retrieve system icons for file types and applications.
///
import Foundation
import AppKit
import UniformTypeIdentifiers

/// Extension for `EditViewController` that adds icon management methods.
/// Includes actions to allow users to select or reset icons for a label,
/// load the current icon into the UI, and utility methods to save and fetch icons.
extension EditViewController {
 
    /// Opens a file dialog for the user to choose a custom icon for the current label.
    /// Shows a progress indicator while importing. Uses XPC to copy the selected image
    /// into the label's folder and reloads the displayed icon on success.
    /// - Parameter sender: The UI element (e.g., button) that triggered this action.
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
    
    /// Resets the label's icon to a generic default by invoking XPC to import the
    /// generic icon. Displays a progress indicator during the operation and reloads
    /// the icon on success.
    /// - Parameter sender: The UI element (e.g., button) that triggered this action.
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
    
    /// Loads the current icon image from the label's folder and sets it on the `buttonIcon`.
    /// If loading fails, no change is made.
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
    
    
    /// Returns the file system path to the label's icon image (PNG) based on its label and GUID.
    /// - Returns: The absolute path to `<label>_<guid>/<label>.png` if available, or `nil` if data is missing.
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
    
    
    /// Saves the given `NSImage` as a PNG file at the specified file system path.
    /// - Parameters:
    ///   - icon: The `NSImage` object to be written.
    ///   - path: The destination file path where the PNG should be saved.
    private func saveIcon(_ icon: NSImage, to path: String) {
        let imageRep = NSBitmapImageRep(data: icon.tiffRepresentation!)
        guard let pngData = imageRep?.representation(using: .png, properties: [:]) else { return }
        do {
            try pngData.write(to: URL(fileURLWithPath: path))
        } catch {
            Logger.logApp("Failed to save icon: \(error)")
        }
    }
    
    
    /// Retrieves the system icon for a file type based on its extension.
    /// - Parameter fileExtension: The file extension (e.g., "txt", "pdf").
    /// - Returns: An `NSImage` representing the icon for that file type, or `nil` if unavailable.
    func iconForFileExtension(_ fileExtension: String) -> NSImage? {
        if let utType = UTType(filenameExtension: fileExtension) {
            return NSWorkspace.shared.icon(for: utType)
        }
        return nil
    }
    
    /// Retrieves the system icon for an installed application by bundle identifier.
    /// - Parameter bundleIdentifier: The app's bundle ID (e.g., "com.apple.Safari").
    /// - Returns: An `NSImage` of the app's icon, or `nil` if the app is not found.
    func iconForApp(bundleIdentifier: String) -> NSImage? {
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
            return NSWorkspace.shared.icon(forFile: appURL.path)
        }
        return nil
    }
    
}
