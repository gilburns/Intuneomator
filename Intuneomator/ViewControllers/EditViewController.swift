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

class EditViewController: NSViewController, URLSessionDownloadDelegate, NSTextStorageDelegate, Configurable, UnsavedChangesHandling, EditOtherViewControllerDelegate {
    
    @IBOutlet weak var progPkgInspect: NSProgressIndicator!
    @IBOutlet weak var progImageEdit: NSProgressIndicator!
    
    @IBOutlet weak var buttonIcon: NSButton!
    
    @IBOutlet weak var buttonInspectDownload: NSButton!
    @IBOutlet weak var buttonSelectCategories: NSButton!
    @IBOutlet weak var buttonPopUpMinimumOs: NSPopUpButton!
    
    @IBOutlet weak var buttonFeatureApp: NSButton!
    @IBOutlet weak var buttonManagedApp: NSButton!
    @IBOutlet weak var labelManagedApp: NSTextField!
    
    @IBOutlet weak var buttonDeploymentType: NSPopUpButton!
    @IBOutlet weak var menuItemDMGType: NSMenuItem!
    @IBOutlet weak var menuItemLOBType: NSMenuItem!
    
    @IBOutlet weak var menuItemUniversalPkg: NSMenuItem!
    
    @IBOutlet weak var fieldTransformLabel: NSTextField!
    
    @IBOutlet weak var buttonDeployAsArch: NSPopUpButton!
    @IBOutlet weak var fieldDeployAsArchLabel: NSTextField!
    @IBOutlet weak var fieldDeloyAsArchUniversal: NSTextField!
    
    @IBOutlet weak var radioYes: NSButton!
    @IBOutlet weak var radioNo: NSButton!
    
    @IBOutlet weak var fieldIntuneID: NSTextField!
    @IBOutlet weak var fieldIntuneVersion: NSTextField!
    
    @IBOutlet weak var buttonPreviewLabel: NSButton!
    
    @IBOutlet weak var fieldAppNewVersion: NSTextField!
    @IBOutlet weak var fieldDownloadFile: NSTextField!
    @IBOutlet weak var fieldDownloadURL: NSTextField!
    @IBOutlet weak var fieldExpectedTeamID: NSTextField!
    @IBOutlet weak var fieldLabel: NSTextField!
    @IBOutlet weak var fieldLabelDescription: NSTextView!
    @IBOutlet weak var fieldName: NSTextField!
    @IBOutlet weak var fieldPackageID: NSTextField!
    @IBOutlet weak var fieldType: NSTextField!
    @IBOutlet weak var fieldDownloadSize: NSTextField!
    @IBOutlet weak var fieldPublisher: NSTextField!
    @IBOutlet weak var fieldItemGUID: NSTextField!
    
    @IBOutlet weak var buttonEditOther: NSButton!
    
    
    
    var appData: AppInfo?
    var appMetadata: Metadata?
    var lastMetadataPartial: MetadataPartial?
    var currentMetadataPartial: MetadataPartial?
    
    
    var parentTabViewController: TabViewController?
    
    var categoriesPopover: NSPopover!
    var selectedCategories: Set<String> = []
    var categories: [[String: Any]] = []
    
    // Create a reusable HelpPopover instance
    let helpPopover = HelpPopover()
    
    // track changes for the metadata.json file
    var hasUnsavedChanges = false
    
    // last load for tracking changes.
    var currentMetadata: Metadata?
    var lastLoadedMetadata: Metadata?
    
    let openAIAPIKey = ""
    
    
    // MARK: - Lifecycle
    func configure(with data: Any, parent: TabViewController) {
        guard let appData = data as? AppInfo else {
            Logger.logUser("Invalid data passed to EditViewController")
            return
        }
        self.appData = appData
        //        print("appData: \(appData)")
        self.parentTabViewController = parent
        
        setupCategoriesPopover()
        populateCategories()
        
    }
    
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
    
    override func viewWillAppear() {
        super.viewWillAppear()
        buttonDeploymentTypeDidChange(buttonDeploymentType)
    }
    
    override func viewWillDisappear() {
        super.viewWillDisappear()
        // Notify about closing the view
        NotificationCenter.default.post(
            name: .labelWindowWillClose,
            object: nil,
            userInfo: ["labelInfo": fieldLabel.stringValue]
        )
    }
    
    private func registerNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(rePopulateFields(_:)), name: .customLabelToggled, object: nil)
        
    }
    
    // MARK: - Helper Methods
    
    @objc private func rePopulateFields(_ notification: Notification) {
        populateFieldsFromAppData()
    }
    
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
    
    
    
    func setFinalDownloadSize() {
        if let lastDownloadSizeUpdate = fieldDownloadSize.stringValue.split(separator: "of").last?.dropFirst() {
            fieldDownloadSize.stringValue = String(lastDownloadSizeUpdate)
        } else {
            fieldDownloadSize.stringValue = "Unknown Size" // Fallback for unexpected input
        }
    }
    
    
    func getSelectedMinimumOsID() -> String? {
        guard let selectedItem = buttonPopUpMinimumOs.selectedItem else { return nil }
        return selectedItem.identifier?.rawValue
    }
    
    func getDeployAsArchTag() -> Int? {
        guard let selectedItem = buttonDeployAsArch.selectedItem else { return nil }
        return selectedItem.tag
    }
    
    func getDeploymentTypeTag() -> Int? {
        guard let selectedItem = buttonDeploymentType.selectedItem else { return nil }
        return selectedItem.tag
    }
    
    
    func getSelectedIgnoreVersionOption() -> String {
        if radioYes.state == .on {
            return "Yes"
        } else if radioNo.state == .on {
            return "No"
        }
        return "None"
    }
    
    func setIgnoreVersionOption(to value: String) {
        if value == "Yes" {
            radioYes.state = .on
            radioNo.state = .off
        } else if value == "No" {
            radioYes.state = .off
            radioNo.state = .on
        }
    }
    
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
    @IBAction func openDownloadURL(_ sender: Any) {
        if let url = URL(string: fieldDownloadURL.stringValue) {
            NSWorkspace.shared.open(url)
        }
    }
    
    
    // MARK: - Preview Label
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
    
    @IBAction func viewOtherMetaData(_ sender: NSButton) {
        
        //        print("app metadata: \(String(describing: self.appMetadata))")
        
        let appName = appData?.name ?? "Unknown App"
        
        self.showOtherMetadataSheet(for: appName, currentMetadataPartial: currentMetadataPartial!, lastMetadataPartial: lastMetadataPartial! )
        
    }
    
    
    // Shows devices in a sheet
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
    
    func editOtherDidSave(returnedMetadataPartial: MetadataPartial) {
        
        currentMetadataPartial?.developer  = returnedMetadataPartial.developer ?? ""
        currentMetadataPartial?.informationUrl  = returnedMetadataPartial.informationUrl ?? ""
        currentMetadataPartial?.notes  = returnedMetadataPartial.notes ?? ""
        currentMetadataPartial?.owner  = returnedMetadataPartial.owner ?? ""
        currentMetadataPartial?.privacyInformationUrl  = returnedMetadataPartial.privacyInformationUrl ?? ""
        
        trackChanges()
    }

    
    // MARK: - Min OS Popup Menu from Inspection
    
    func selectMinimumOSPopupItem(displayString: String) {
        let index = buttonPopUpMinimumOs.indexOfItem(withTitle: displayString)
        if index != -1 {
            buttonPopUpMinimumOs.selectItem(at: index)
        } else {
            //                print("Minimum OS '\(displayString)' not found in popup menu.")
        }
    }
    
    
    
    // MARK: - Show Error Messages
    func showError(message: String) {
        let alert = NSAlert()
        alert.messageText = "Error"
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
}
    
