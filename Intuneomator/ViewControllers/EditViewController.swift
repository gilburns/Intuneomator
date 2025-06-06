//
///
///  EditViewController.swift
///  Intuneomator
///
///  Main application editing view controller for configuring Installomator label metadata.
///  Central hub for editing all aspects of application deployment configuration including
///  metadata, categories, deployment settings, and integration with various inspection tools.
///
///  **Key Features:**
///  - Configures application metadata (name, description, publisher, categories)
///  - Manages deployment types (DMG, PKG, LOB) and architecture settings
///  - Integrates with app inspection tools for automatic metadata detection
///  - Handles icon management and category selection
///  - Tracks changes with visual highlighting and unsaved changes detection
///  - Supports multi-architecture deployments and OS version requirements
///  - Provides preview functionality for Installomator labels
//
//  EditViewController.swift
//  Intuneomator
//
//  Created by Gil Burns on 12/30/24.
//

import Foundation
import Cocoa
import AppKit
import UniformTypeIdentifiers

/// `EditViewController` is the primary view controller for editing application deployment settings.
/// It manages UI interactions, metadata loading/saving, inspection workflows, and change tracking.
class EditViewController: NSViewController, URLSessionDownloadDelegate, NSTextStorageDelegate, Configurable, UnsavedChangesHandling, EditOtherViewControllerDelegate {
    
    /// Progress indicator for package inspection/download tasks.
    @IBOutlet weak var progPkgInspect: NSProgressIndicator!

    /// Progress indicator for image/icon processing tasks.
    @IBOutlet weak var progImageEdit: NSProgressIndicator!

    /// Button to launch icon selection or reset functionality.
    @IBOutlet weak var buttonIcon: NSButton!

    /// Button to start downloading and inspecting the target package or app.
    @IBOutlet weak var buttonInspectDownload: NSButton!
    /// Button to open the categories popover for selecting application categories.
    @IBOutlet weak var buttonSelectCategories: NSButton!
    /// Pop-up button for selecting the minimum supported macOS version.
    @IBOutlet weak var buttonPopUpMinimumOs: NSPopUpButton!

    /// Checkbox to mark the application as featured in the Company Portal.
    @IBOutlet weak var buttonFeatureApp: NSButton!
    /// Checkbox to mark the application as managed by Intune.
    @IBOutlet weak var buttonManagedApp: NSButton!
    /// Label indicating the managed app option.
    @IBOutlet weak var labelManagedApp: NSTextField!

    /// Pop-up button for selecting deployment type (DMG, PKG, LOB).
    @IBOutlet weak var buttonDeploymentType: NSPopUpButton!
    /// Menu item representing DMG deployment type.
    @IBOutlet weak var menuItemDMGType: NSMenuItem!
    /// Menu item representing LOB deployment type.
    @IBOutlet weak var menuItemLOBType: NSMenuItem!

    /// Menu item representing universal PKG deployment type.
    @IBOutlet weak var menuItemUniversalPkg: NSMenuItem!

    /// Label for the "Transform to PKG" option (if applicable).
    @IBOutlet weak var fieldTransformLabel: NSTextField!

    /// Pop-up button to select architecture for dual-arch PKGs.
    @IBOutlet weak var buttonDeployAsArch: NSPopUpButton!
    /// Label displayed when deploying as a specific architecture.
    @IBOutlet weak var fieldDeployAsArchLabel: NSTextField!
    /// Label shown when universal architecture is used.
    @IBOutlet weak var fieldDeloyAsArchUniversal: NSTextField!

    /// Radio button to enable ignoring version detection.
    @IBOutlet weak var radioYes: NSButton!
    /// Radio button to disable ignoring version detection.
    @IBOutlet weak var radioNo: NSButton!

    /// Text field for entering or displaying the Intune App/Package ID.
    @IBOutlet weak var fieldIntuneID: NSTextField!
    /// Text field for entering or displaying the Intune App/Package version.
    @IBOutlet weak var fieldIntuneVersion: NSTextField!

    /// Button to preview the generated Installomator label contents.
    @IBOutlet weak var buttonPreviewLabel: NSButton!

    /// Text field for specifying or displaying the new version of the app in the label.
    @IBOutlet weak var fieldAppNewVersion: NSTextField!
    /// Text field for specifying or displaying the output file name for downloads.
    @IBOutlet weak var fieldDownloadFile: NSTextField!
    /// Text field for entering or displaying the download URL of the app/package.
    @IBOutlet weak var fieldDownloadURL: NSTextField!
    /// Text field for entering or displaying the expected Apple developer team ID for signature checks.
    @IBOutlet weak var fieldExpectedTeamID: NSTextField!
    /// Text field for the label name used in Installomator.
    @IBOutlet weak var fieldLabel: NSTextField!
    /// Text view for entering or displaying the detailed description of the label.
    @IBOutlet weak var fieldLabelDescription: NSTextView!
    /// Text field for entering or displaying the human-readable application name.
    @IBOutlet weak var fieldName: NSTextField!
    /// Text field for entering or displaying the package identifier for an LOB app.
    @IBOutlet weak var fieldPackageID: NSTextField!
    /// Text field indicating the content type (pkg, dmg, zip, etc.).
    @IBOutlet weak var fieldType: NSTextField!
    /// Text field displaying current download progress size (e.g., "1 MB of 100 MB").
    @IBOutlet weak var fieldDownloadSize: NSTextField!
    /// Text field for entering or displaying the publisher name of the app.
    @IBOutlet weak var fieldPublisher: NSTextField!
    /// Text field for displaying the unique GUID tracking ID of the label.
    @IBOutlet weak var fieldItemGUID: NSTextField!

    /// Button to open the "Other Metadata" sheet for additional properties.
    @IBOutlet weak var buttonEditOther: NSButton!


    /// Holds the current application’s data (label, GUID, etc.) passed from the parent.
    var appData: AppInfo?
    /// Holds the loaded or edited metadata for the current application.
    var appMetadata: Metadata?
    /// Holds the last loaded partial metadata for change tracking.
    var lastMetadataPartial: MetadataPartial?
    /// Holds the current partial metadata being edited.
    var currentMetadataPartial: MetadataPartial?

    /// Reference to the parent `TabViewController` to notify about unsaved changes.
    var parentTabViewController: TabViewController?

    /// Popover used to display and select categories.
    var categoriesPopover: NSPopover!
    /// Set of IDs for currently selected application categories.
    var selectedCategories: Set<String> = []
    /// Array of all available categories loaded from cache or network.
    var categories: [[String: Any]] = []

    /// HelpPopover instance for showing contextual help messages in the UI.
    let helpPopover = HelpPopover()

    /// Flag indicating whether any metadata changes have not been saved.
    var hasUnsavedChanges = false

    /// Metadata object representing current UI state for comparison and saving.
    var currentMetadata: Metadata?
    /// Metadata object representing previously loaded state for change tracking.
    var lastLoadedMetadata: Metadata?

    /// Placeholder for OpenAI API Key, if needed for AI-driven features.
    let openAIAPIKey = ""

    // MARK: - Lifecycle
    /// Configures the view controller with the given `AppInfo` and parent tab controller.
    /// - Parameters:
    ///   - data: An `AppInfo` object containing label and GUID information.
    ///   - parent: The parent `TabViewController` to which this controller belongs.
    func configure(with data: Any, parent: TabViewController) {
        guard let appData = data as? AppInfo else {
            Logger.logApp("Invalid data passed to EditViewController")
            return
        }
        self.appData = appData
        //        print("appData: \(appData)")
        self.parentTabViewController = parent
        
        setupCategoriesPopover()
        populateCategories()
        
    }
    
    /// View lifecycle callback invoked after the view has been loaded.
    /// Initializes UI elements, loads metadata/icon, and sets up change tracking.
    override func viewDidLoad() {
        super.viewDidLoad()
        //        self.preferredContentSize = self.view.frame.size
        
        // Use appData to configure the view
        if (appData != nil) {
            //            print("Received appData in EditViewController: \(String(describing: appData))")
            populateFieldsFromAppData()
        }
        
        registerNotifications()
        
        // Ignore Version Detection in Intune
        radioYes.state = .off
        radioNo.state = .on // Default to "No"
        
        // Initialize field and checkbox based on appData
        fieldType.stringValue = appData?.type ?? ""
        
        // set availability of deploy as button and label
        setDeployAsState()
        
        loadIcon()
        updateCategoryButtonTitle() // Initialize the button title on view load
        
        buttonDeploymentType.item(at: 0)?.image = iconForFileExtension("dmg")
        buttonDeploymentType.item(at: 1)?.image = iconForFileExtension("pkg")
        
        if let cpIconPath = Bundle.main.path(forResource: "CP", ofType: "png"),
           let icon = NSImage(contentsOfFile: cpIconPath) {
            
            let targetSize = NSSize(width: 32, height: 32) // adjust as needed
            let resized = resizedImage(icon, to: targetSize)
            
            buttonDeploymentType.item(at: 2)?.image = resized
        } else if let icon = iconForApp(bundleIdentifier: "com.microsoft.CompanyPortalMac") {
            buttonDeploymentType.item(at: 2)?.image = icon
        }
        
        
        loadMetadata()
        trackChanges()
        
        // reload field based on Metadata setting
        populateFieldsFromAppData()
        
        // Set the NSTextStorage delegate
        if let textStorage = fieldLabelDescription.textStorage {
            textStorage.delegate = self
            //            print("Text storage delegate set successfully.")
        } else {
            //            print("Failed to access text storage.")
        }
        
        setDeploymentTypeState()
        
        // show or hide the transform check box based on type
        //        let shouldShowTransformControls = ["dmg", "zip", "tbz", "appInDmgInZip"].contains(fieldType.stringValue)
        //        fieldTransformLabel.isHidden = !shouldShowTransformControls
        //        buttonTransformToPkg.isHidden = !shouldShowTransformControls
        //        buttonTransformPkgHelp.isHidden = !shouldShowTransformControls
    }
    
    /// View lifecycle callback invoked before the view appears.
    /// Ensures UI states are consistent based on the selected deployment type.
    override func viewWillAppear() {
        super.viewWillAppear()
        buttonDeploymentTypeDidChange(buttonDeploymentType)
    }
    
    /// View lifecycle callback invoked when the view is about to disappear.
    /// Posts a notification that the label window will close.
    override func viewWillDisappear() {
        super.viewWillDisappear()
        // Notify about closing the view
        NotificationCenter.default.post(
            name: .labelWindowWillClose,
            object: nil,
            userInfo: ["labelInfo": fieldLabel.stringValue]
        )
    }
    
    /// Registers for notifications (e.g., category toggled) to respond to external changes.
    private func registerNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(rePopulateFields(_:)), name: .customLabelToggled, object: nil)
        
    }
    
    // MARK: - Helper Methods
    
    /// Notification handler to re-populate UI fields when custom label settings change.
    /// - Parameter notification: The notification object (expects customLabelToggled).
    @objc private func rePopulateFields(_ notification: Notification) {
        populateFieldsFromAppData()
    }
    
    /// Populates UI fields from the base `AppInfo` plist data (label, downloadURL, etc.).
    /// Reads the label’s .plist file from disk to fill download and label properties.
    func populateFieldsFromAppData() {
        fieldItemGUID.stringValue = "Tracking ID: \(appData!.guid)"
        
        var plistURL: URL
        var plistDictionary: [String: Any] = [:]
        
        if titleIsDualArch() {
            if getDeployAsArchTag() == 0 {
                plistURL = AppConstants.intuneomatorManagedTitlesFolderURL
                    .appendingPathComponent("\(appData!.label)_\(appData!.guid)")
                    .appendingPathComponent("\(appData!.label).plist")
            } else {
                plistURL = AppConstants.intuneomatorManagedTitlesFolderURL
                    .appendingPathComponent("\(appData!.label)_\(appData!.guid)")
                    .appendingPathComponent("\(appData!.label)_i386.plist")
            }
        } else {
            plistURL = AppConstants.intuneomatorManagedTitlesFolderURL
                .appendingPathComponent("\(appData!.label)_\(appData!.guid)")
                .appendingPathComponent("\(appData!.label).plist")
        }
        
        do {
            let plistData = try Data(contentsOf: plistURL)
            plistDictionary = try PropertyListSerialization.propertyList(
                from: plistData,
                options: [],
                format: nil
            ) as! [String: Any]
            
        } catch {
            //            print("Failed to load plist: \(error)")
            return
        }
        
        fieldAppNewVersion.stringValue = plistDictionary["appNewVersion"] as? String ?? ""
        fieldDownloadFile.stringValue = plistDictionary["downloadFile"] as? String ?? ""
        fieldDownloadFile.toolTip = plistDictionary["downloadFile"] as? String ?? ""
        fieldDownloadURL.stringValue = plistDictionary["downloadURL"] as? String ?? ""
        fieldDownloadURL.toolTip = plistDictionary["downloadURL"] as? String ?? ""
        fieldExpectedTeamID.stringValue = plistDictionary["expectedTeamID"] as? String ?? ""
        fieldExpectedTeamID.toolTip = plistDictionary["expectedTeamID"] as? String ?? ""
        fieldLabel.stringValue = plistDictionary["label"] as? String ?? ""
        fieldName.stringValue = plistDictionary["name"] as? String ?? ""
        fieldPackageID.stringValue = plistDictionary["packageID"] as? String ?? ""
        fieldPackageID.toolTip = plistDictionary["packageID"] as? String ?? ""
        fieldType.stringValue = plistDictionary["type"] as? String ?? ""
        
    }
    
    
    /// Populates UI fields from the loaded `Metadata` object.
    /// Sets description, publisher, category selections, deployment options, and flags.
    func populateFieldsFromAppMetadata() {
        
        // Populate UI with loaded data
        fieldLabelDescription.string = appMetadata?.description ?? ""
        fieldPublisher.stringValue = appMetadata?.publisher ?? ""
        if let osItem = buttonPopUpMinimumOs.item(withTitle: appMetadata?.minimumOSDisplay ?? "macOS Ventura 13.0") {
            buttonPopUpMinimumOs.select(osItem)
        }
        
        if let deployAsArchMenuItems = buttonDeployAsArch.menu?.items,
           let index = deployAsArchMenuItems.firstIndex(where: { $0.tag  == appMetadata?.deployAsArchTag }) {
            buttonDeployAsArch.selectItem(at: index)
        }
        
        if let deploymentTypeMenuItems = buttonDeploymentType.menu?.items,
           let index = deploymentTypeMenuItems.firstIndex(where: { $0.tag  == appMetadata?.deploymentTypeTag }) {
            buttonDeploymentType.selectItem(at: index)
        }
        
        let deploymentTypeTag = appMetadata?.deploymentTypeTag ?? 0
        switch deploymentTypeTag {
        case 0:
            AppDataManager.shared.currentAppType = "macOSDmgApp"
        case 1:
            AppDataManager.shared.currentAppType = "macOSPkgApp"
        case 2:
            AppDataManager.shared.currentAppType = "macOSLobApp"
            buttonManagedApp.isEnabled = true
            labelManagedApp.textColor = .labelColor
        default:
            buttonManagedApp.isEnabled = false
            buttonManagedApp.state = .off
            labelManagedApp.textColor = .lightGray
        }
        
        fieldIntuneID.stringValue = appMetadata?.CFBundleIdentifier ?? ""
        buttonFeatureApp.state = appMetadata?.isFeatured ?? false ? .on : .off
        buttonManagedApp.state = appMetadata?.isManaged ?? false ? .on : .off
        radioYes.state = appMetadata?.ignoreVersionDetection ?? false ? .on : .off
        radioNo.state = appMetadata?.ignoreVersionDetection ?? true ? .off : .on
        
        // Populate categories
        let loadedCategoryIDs = appMetadata?.categories.map { $0.id }
        selectedCategories = Set(loadedCategoryIDs ?? []) // Update the selected categories
        populateCategories() // Refresh the UI checkboxes
        updateCategoryButtonTitle() // Update the button title based on loaded categories
        
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
        
        // Store the loaded metadata for future comparison
        lastLoadedMetadata = appMetadata
        //            print("Metadata loaded and stored for change tracking.")
        
        
    }
    
    
    /// Checks whether the label supports dual-architecture (universal/i386).
    /// - Returns: true if an _i386.plist exists in the label folder.
    private func titleIsDualArch() -> Bool {
        guard let label = appData?.label else {
            //            print("Error: appData or label is nil.")
            return false
        }
        
        guard let guid = appData?.guid else {
            //            print("Error: appData or guid is nil.")
            return false
        }
        
        let labelX86PlistPath = AppConstants.intuneomatorManagedTitlesFolderURL
            .appendingPathComponent("\(label)_\(guid)", isDirectory: true)
            .appendingPathComponent("\(label)_i386.plist", isDirectory: true)
        
        return FileManager.default.fileExists(atPath: labelX86PlistPath.path)
    }
    
    
    /// Enables or disables architecture deployment controls based on dual-arch support.
    private func setDeployAsState() {
        let titleIsDualArch = titleIsDualArch()
        
        buttonDeployAsArch.isEnabled = titleIsDualArch
        
        if titleIsDualArch {
            fieldDeloyAsArchUniversal.isHidden = true
        } else {
            buttonDeployAsArch.isHidden = true
            fieldDeloyAsArchUniversal.isHidden = false
        }
    }
    
    
    /// Adjusts visibility of deployment type menu items based on content type.
    private func setDeploymentTypeState() {
        let itemType = appData?.type ?? "dmg"
        
        if ["pkg", "pkgInDmg", "pkgInZip", "pkgInDmgInZip"].contains(itemType) {
            menuItemDMGType.isHidden = true
            menuItemLOBType.isHidden = false
        } else if ["dmg", "zip", "tbz", "appInDmgInZip"].contains(itemType) {
            menuItemDMGType.isHidden = false
            menuItemLOBType.isHidden = true
        }
    }
    
    
    
    /// Updates the `fieldDownloadSize` label to show only the final total size after download completes.
    func setFinalDownloadSize() {
        if let lastDownloadSizeUpdate = fieldDownloadSize.stringValue.split(separator: "of").last?.dropFirst() {
            fieldDownloadSize.stringValue = String(lastDownloadSizeUpdate)
        } else {
            fieldDownloadSize.stringValue = "Unknown Size" // Fallback for unexpected input
        }
    }
    
    
    /// Returns the selected minimum OS identifier from the pop-up menu.
    /// - Returns: The raw value of the selected pop-up item identifier, or nil.
    func getSelectedMinimumOsID() -> String? {
        guard let selectedItem = buttonPopUpMinimumOs.selectedItem else { return nil }
        return selectedItem.identifier?.rawValue
    }
    
    /// Returns the selected deploy-as-architecture tag from the pop-up menu.
    /// - Returns: The tag value of the selected item, or nil.
    func getDeployAsArchTag() -> Int? {
        guard let selectedItem = buttonDeployAsArch.selectedItem else { return nil }
        return selectedItem.tag
    }
    
    /// Returns the selected deployment type tag from the pop-up menu.
    /// - Returns: The tag value of the selected item, or nil.
    func getDeploymentTypeTag() -> Int? {
        guard let selectedItem = buttonDeploymentType.selectedItem else { return nil }
        return selectedItem.tag
    }
    
    
    /// Returns a string indicating whether "Ignore Version" is set to Yes or No.
    func getSelectedIgnoreVersionOption() -> String {
        if radioYes.state == .on {
            return "Yes"
        } else if radioNo.state == .on {
            return "No"
        }
        return "None"
    }
    
    /// Sets the radio buttons for "Ignore Version" based on the given string ("Yes"/"No").
    func setIgnoreVersionOption(to value: String) {
        if value == "Yes" {
            radioYes.state = .on
            radioNo.state = .off
        } else if value == "No" {
            radioYes.state = .off
            radioNo.state = .on
        }
    }
    
    /// Returns a new `NSImage` by tinting the given image with the specified color.
    /// - Parameters:
    ///   - image: The source image to tint.
    ///   - color: The `NSColor` to apply as a tint.
    /// - Returns: A tinted copy of the original image.
    func tintedImage(_ image: NSImage, color: NSColor) -> NSImage {
        let newImage = image.copy() as! NSImage
        newImage.lockFocus()
        color.set()
        let imageRect = NSRect(origin: .zero, size: newImage.size)
        imageRect.fill(using: .sourceAtop)
        newImage.unlockFocus()
        newImage.isTemplate = false
        return newImage
    }
    
    /// Returns a new `NSImage` resized to the specified dimensions.
    /// - Parameters:
    ///   - image: The source image to resize.
    ///   - size: The target size for the new image.
    /// - Returns: A resized copy of the original image.
    func resizedImage(_ image: NSImage, to size: NSSize) -> NSImage {
        let newImage = NSImage(size: size)
        newImage.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: size),
                   from: NSRect(origin: .zero, size: image.size),
                   operation: .sourceOver,
                   fraction: 1.0)
        newImage.unlockFocus()
        return newImage
    }
    
    
    // MARK: - Actions
    /// Opens the URL entered in `fieldDownloadURL` in the default web browser.
    /// - Parameter sender: The control that triggered this action.
    @IBAction func openDownloadURL(_ sender: Any) {
        if let url = URL(string: fieldDownloadURL.stringValue) {
            NSWorkspace.shared.open(url)
        }
    }
    
    
    // MARK: - Preview Label
    /// Reads the selected label script file (built-in or custom) and shows its contents in a popover.
    /// - Parameter sender: The button that triggered the preview action.
    @IBAction func previewLabelContents(_ sender: NSButton) {
        guard let labelName = appData?.label,
              let labelGuid = appData?.guid else { return }
        
        let labelFolder = "\(labelName)_\(labelGuid)"
        
        let customCheckURL = AppConstants.intuneomatorManagedTitlesFolderURL
            .appendingPathComponent(labelFolder)
            .appendingPathComponent(".custom")
        
        var labelURL: URL?
        
        if !FileManager.default.fileExists(atPath: customCheckURL.path) {
            labelURL = AppConstants.installomatorLabelsFolderURL.appendingPathComponent("\(labelName).sh")
        } else {
            labelURL = AppConstants.installomatorCustomLabelsFolderURL.appendingPathComponent("\(labelName).sh")
        }
        
        guard FileManager.default.fileExists(atPath: labelURL!.path) else {
            return
        }
        
        do {
            let labelContents = try String(contentsOfFile: labelURL!.path, encoding: .utf8)
            showPopover(with: labelContents)
        } catch {
            print("❌ Failed to read label file \(labelName).sh: \(error)")
        }
    }
    
    /// Displays a popover containing the given text string in a scrollable text view.
    /// Calculates dynamic height based on text content up to a maximum.
    /// - Parameter text: The string to display inside the popover.
    func showPopover(with text: String) {
        let popover = NSPopover()
        popover.behavior = .transient
        
        // Constants
        let maxHeight: CGFloat = 380
        let width: CGFloat      = 550
        let padding: CGFloat    = 15
        let textWidth           = width - 2*padding
        
        // Compute text height for given width & font
        let font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        let attrs = [NSAttributedString.Key.font: font]
        let bounding = NSString(string: text)
            .boundingRect(
                with: NSSize(width: textWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: attrs
            )
        let textHeight   = ceil(bounding.height)
        let totalHeight  = textHeight + 3*padding
        let popoverHeight = min(maxHeight, totalHeight)
        
        // Build scroll/text views at the new height
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: width, height: popoverHeight))
        scrollView.hasVerticalScroller   = true
        scrollView.hasHorizontalScroller = false
        
        let textView = NSTextView(frame: NSRect(x: padding,
                                                y: padding,
                                                width: textWidth,
                                                height: popoverHeight - 2*padding))
        textView.isEditable          = false
        textView.font                = font
        textView.string              = text
        textView.textContainerInset  = NSSize(width: padding, height: padding)
        
        scrollView.documentView = textView
        
        // Set as popover content
        let vc = NSViewController()
        vc.view = scrollView
        popover.contentViewController = vc
        popover.contentSize = NSSize(width: width, height: popoverHeight)
        
        // Show it
        popover.show(relativeTo: buttonPreviewLabel.bounds,
                     of: buttonPreviewLabel,
                     preferredEdge: .maxY)
    }
    
    // MARK: - Other Metadata
    
    /// Opens the "Other Metadata" sheet for editing developer, notes, owner, and other fields.
    /// - Parameter sender: The button that triggered the action.
    @IBAction func viewOtherMetaData(_ sender: NSButton) {
        
        //        print("app metadata: \(String(describing: self.appMetadata))")
        
        let appName = appData?.name ?? "Unknown App"
        
        self.showOtherMetadataSheet(for: appName, currentMetadataPartial: currentMetadataPartial!, lastMetadataPartial: lastMetadataPartial! )
        
    }
    
    
    // Shows devices in a sheet
    /// Instantiates and presents the `EditOtherViewController` sheet for additional metadata editing.
    /// - Parameters:
    ///   - appName: The display name of the application.
    ///   - currentMetadataPartial: The currently modified partial metadata.
    ///   - lastMetadataPartial: The partial metadata loaded from disk for change tracking.
    func showOtherMetadataSheet(for appName: String, currentMetadataPartial: MetadataPartial, lastMetadataPartial: MetadataPartial ) {
        let storyboard = NSStoryboard(name: "Main", bundle: nil)
        guard let sheetController = storyboard.instantiateController(withIdentifier: "EditOtherViewController") as? EditOtherViewController else {
            //            print("❌ Failed to instantiate EditOtherViewController")
            return
        }
        
        sheetController.appName = appName
        sheetController.currentMetadataPartial = currentMetadataPartial
        sheetController.lastMetadataPartial = lastMetadataPartial
        
        sheetController.delegate = self
        
        self.presentAsSheet(sheetController)
    }
   
    /// Delegate callback invoked when the "Other Metadata" sheet saves changes.
    /// Updates `currentMetadataPartial` with returned values and re-checks for unsaved changes.
    /// - Parameter returnedMetadataPartial: The updated partial metadata returned from the sheet.
    func editOtherDidSave(returnedMetadataPartial: MetadataPartial) {
        
        currentMetadataPartial?.developer  = returnedMetadataPartial.developer ?? ""
        currentMetadataPartial?.informationUrl  = returnedMetadataPartial.informationUrl ?? ""
        currentMetadataPartial?.notes  = returnedMetadataPartial.notes ?? ""
        currentMetadataPartial?.owner  = returnedMetadataPartial.owner ?? ""
        currentMetadataPartial?.privacyInformationUrl  = returnedMetadataPartial.privacyInformationUrl ?? ""
        
        trackChanges()
    }

    // MARK: - Min OS Popup Menu from Inspection

    /// Selects the given OS version title in the minimum OS pop-up menu, if it exists.
    /// - Parameter displayString: The display string of the OS version to select.
    func selectMinimumOSPopupItem(displayString: String) {
        let index = buttonPopUpMinimumOs.indexOfItem(withTitle: displayString)
        if index != -1 {
            buttonPopUpMinimumOs.selectItem(at: index)
        } else {
            //                print("Minimum OS '\(displayString)' not found in popup menu.")
        }
    }

    // MARK: - Show Error Messages

    /// Displays a modal error alert with a given message.
    /// - Parameter message: The error message to show in the alert.
    func showError(message: String) {
        let alert = NSAlert()
        alert.messageText = "Error"
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
