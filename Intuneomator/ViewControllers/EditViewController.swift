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

    private var categoriesPopover: NSPopover!
    private var selectedCategories: Set<String> = []
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
//        print("Re populating fields...")
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

        if plistDictionary["packageID"] as? String == "" {
            buttonUseInstallomatorPkgID.isEnabled = false
        }
        
        
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

    
    
    private func setFinalDownloadSize() {
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
        
//        print("App Metadata updated")
//        print("Returned Metadata: \(String(describing: returnedMetadataPartial))")

        
        currentMetadataPartial?.developer  = returnedMetadataPartial.developer ?? ""
        currentMetadataPartial?.informationUrl  = returnedMetadataPartial.informationUrl ?? ""
        currentMetadataPartial?.notes  = returnedMetadataPartial.notes ?? ""
        currentMetadataPartial?.owner  = returnedMetadataPartial.owner ?? ""
        currentMetadataPartial?.privacyInformationUrl  = returnedMetadataPartial.privacyInformationUrl ?? ""
        
        
        trackChanges()
        
    }

    
//    func editOtherDidSave(developer: String?, informationUrl: String?, notes: String?, owner: String?, privacyInformationUrl: String?) {
//        print("developer: \(developer ?? "")")
//        print("information url: \(informationUrl ?? "")")
//        print("notes: \(notes ?? "")")
//        print("owner: \(owner ?? "")")
//        print("privacy information url: \(privacyInformationUrl ?? "")")
//
//        appMetadataPartial?.developer = developer
//        appMetadataPartial?.informationUrl = informationUrl
//        appMetadataPartial?.notes = notes
//        appMetadataPartial?.owner = owner
//        appMetadataPartial?.privacyInformationUrl = privacyInformationUrl
//
//        print("App Metadata updated")
//        print("Metadata: \(String(describing: appMetadata))")
//
//        trackChanges()
//    }

        
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
    
    
    // MARK: - Download Inspection
    @IBAction func inspectDownload(_ sender: Any) {

        guard let downloadURL = URL(string: fieldDownloadURL.stringValue) else {
            showError(message: "Invalid download URL")
            self.cleanupAfterProcessing()
            return
        }
        
        buttonInspectDownload.title = "Downloading..."
        buttonInspectDownload.isEnabled = false
        fieldDownloadURL.isEnabled = false
        
        
        let tempDir = AppConstants.intuneomatorTempFolderURL
        let uniqueFolder = tempDir.appendingPathComponent(UUID().uuidString) // Create a unique subfolder
        
        do {
            // Create the unique folder
            try FileManager.default.createDirectory(at: uniqueFolder, withIntermediateDirectories: true, attributes: nil)
        } catch {
            showError(message: "Failed to create temporary folder: \(error.localizedDescription)")
            return
        }
        
        // Configure the session
        let sessionConfig = URLSessionConfiguration.default
        let session = URLSession(configuration: sessionConfig, delegate: self, delegateQueue: nil)
        session.sessionDescription = uniqueFolder.path
        
        // Start the download task
        let downloadTask = session.downloadTask(with: downloadURL)
        downloadTask.resume()
        
        // Reset and show progress bar
        DispatchQueue.main.async {
            self.progPkgInspect.isHidden = false
            self.progPkgInspect.isIndeterminate = false
            self.progPkgInspect.doubleValue = 0
        }
    }

    
    private func presentMenu(items: [String]) {
        guard !items.isEmpty else {
            let alert = NSAlert()
            alert.messageText = "No valid pkg metadata found"
            alert.runModal()
            cleanupAfterProcessing()
            return
        }
        
        let alert = NSAlert()
        alert.messageText = "Select an Option"
        alert.informativeText = "Choose the appropriate identifier-version pair from the list."
        
        let popUp = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 300, height: 30))
        popUp.addItems(withTitles: items)
        alert.accessoryView = popUp
        
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn, let selectedItem = popUp.titleOfSelectedItem {
            // Split selected item into id and version
            let components = selectedItem.split(separator: " - ")
            if components.count == 2 {
                let pkgID = String(components[0])
                let pkgVersion = String(components[1])
                
                // Populate the new fields
                DispatchQueue.main.async {
                    self.fieldIntuneID.stringValue = pkgID
                    self.fieldIntuneVersion.stringValue = pkgVersion
                    self.trackChanges()
                }
            }
        }
        
        cleanupAfterProcessing()
    }
    
    
    @IBAction func handleRadioSelection(_ sender: NSButton) {
        if sender == radioYes {
//            print("Yes selected")
            // Add logic for "Yes" selection
        } else if sender == radioNo {
//            print("No selected")
            // Add logic for "No" selection
        }
        
        trackChanges()
    }
    

    
    // MARK: - Download Inspection Processing Methods
    private func processDownloadedFile(at location: URL) async {
        let fieldType = fieldType.stringValue.lowercased()
        
        DispatchQueue.main.async {
            self.progPkgInspect.isHidden = true
            self.progPkgInspect.stopAnimation(self)
            self.setFinalDownloadSize()
            
            self.buttonInspectDownload.title = "Download and Inspect"
            self.buttonInspectDownload.isEnabled = true
            self.fieldDownloadURL.isEnabled = true
        }

        
        switch fieldType {
        case "pkg":
            await processPkg(at: location)
        case "pkginzip":
            await processPkgInZip(at: location)
        case "pkgindmg":
            await processPkgInDmg(at: location)
        case "pkgindmginzip":
            await processPkgInDmgInZip(at: location)
        case "dmg", "appindmginzip", "zip", "tbz":
            let appInspector = AppInspector()
            processAppType(location: location, type: fieldType, inspector: appInspector)
        default:
            showError(message: "Unsupported type: \(fieldType)")
            cleanupAfterProcessing()
        }
    }

    // MARK: - PKG Types
    private func processPkg(at location: URL) async {
        var signatureResult: [String: Any] = [:]

        // Decode the percent-encoded path
        let decodedPath = location.path.removingPercentEncoding ?? location.path

//        print("Inspecting package at path: \(decodedPath)")

        guard FileManager.default.fileExists(atPath: location.path) else {
//            print("Error: File does not exist at path \(location.path())")
            return
        }

        do {
            signatureResult = try SignatureInspector.inspectPackageSignature(pkgPath: decodedPath)
//            print("Package Signature Inspection Result: \(signatureResult)")
        } catch {
//            print("Error inspecting package signature: \(error)")
            signatureResult = [
                "Accepted": false,
                "DeveloperID": "Unknown",
                "DeveloperTeam": "Unknown"
            ]
        }

        let pkgInspector = PkgInspector()
        pkgInspector.inspect(pkgAt: location) { result in
            DispatchQueue.main.async {
                self.handleInspectionResultPkg(result, type: "pkg", signature: signatureResult, fileURL: location)
            }
        }
    }

    private func processPkgInZip(at location: URL) async {
        let tempDir = AppConstants.intuneomatorTempFolderURL
            .appendingPathComponent(UUID().uuidString)
        let tempZipPath = tempDir.appendingPathComponent("downloaded.zip")

        do {
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: nil)
            try FileManager.default.moveItem(at: location, to: tempZipPath)

            // Unzip the file
            let unzip = Process()
            unzip.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
            unzip.arguments = ["-q", tempZipPath.path, "-d", tempDir.path]
            try unzip.run()
            unzip.waitUntilExit()

            guard unzip.terminationStatus == 0 else {
                throw NSError(domain: "EditViewController", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to unzip pkg in zip"])
            }

            // Recursively find .pkg file
            func findFirstPkgFile(in directory: URL) throws -> URL {
                let contents = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
                for item in contents {
                    if item.pathExtension == "pkg" {
                        return item
                    }
                    var isDir: ObjCBool = false
                    if FileManager.default.fileExists(atPath: item.path, isDirectory: &isDir), isDir.boolValue {
                        if let found = try? findFirstPkgFile(in: item) {
                            return found
                        }
                    }
                }
                throw NSError(domain: "EditViewController", code: 1, userInfo: [NSLocalizedDescriptionKey: "No .pkg file found after unzipping"])
            }

            let pkgPath = try findFirstPkgFile(in: tempDir)
            await processPkg(at: pkgPath)

        } catch {
            showError(message: error.localizedDescription)
            cleanupAfterProcessing()
        }
    }

    private func processPkgInDmg(at location: URL) async {
        let tempDir = location.deletingLastPathComponent()
        let mountPoint = tempDir.appendingPathComponent("mount")
        
        do {
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: nil)

            // Convert the DMG first if it has a Software License Agreement
            if dmgHasSLA(at: location.path) {
                let success = await convertDmgWithSLA(at: location.path)
                if success {
                    Logger.logUser("Successfully converted dmg with SLA", logType: "EditViewController")
                } else {
                    Logger.logUser("Failed to convert dmg with SLA", logType: "EditViewController")
                    throw NSError(domain: "EditViewController", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert dmg containing pkg"])
                }
            }

            // Mount the dmg
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
            process.arguments = ["attach", location.path, "-mountpoint", mountPoint.path, "-nobrowse", "-quiet"]
            try process.run()
            process.waitUntilExit()
            
            guard process.terminationStatus == 0 else {
                throw NSError(domain: "EditViewController", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to mount dmg containing pkg"])
            }

            // Search for .pkg
            let pkgFiles = try FileManager.default.contentsOfDirectory(at: mountPoint, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "pkg" }
            
            guard let pkgPath = pkgFiles.first else {
                throw NSError(domain: "EditViewController", code: 1, userInfo: [NSLocalizedDescriptionKey: "No pkg found in dmg"])
            }

            let pkgName = pkgPath.lastPathComponent
            let destinationpkgPath = tempDir.appendingPathComponent(pkgName)
            
            if FileManager.default.fileExists(atPath: pkgPath.path) {
                try FileManager.default.copyItem(atPath: pkgPath.path, toPath: destinationpkgPath.path)
            }

            // Unmount dmg
            let unmountProcess = Process()
            unmountProcess.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
            unmountProcess.arguments = ["detach", mountPoint.path, "-quiet", "-force"]
            try unmountProcess.run()
            unmountProcess.waitUntilExit()

            await processPkg(at: destinationpkgPath)
        } catch {
            showError(message: error.localizedDescription)
            cleanupAfterProcessing()
        }
    }
    
    
    private func processPkgInDmgInZip(at location: URL) async {
        let tempDir = AppConstants.intuneomatorTempFolderURL
            .appendingPathComponent(UUID().uuidString)
        
        let tempZipPath = tempDir.appendingPathComponent("downloaded.zip")
        
        do {
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: nil)
            try FileManager.default.moveItem(at: location, to: tempZipPath)
            
            // Unzip
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
            process.arguments = ["-q", tempZipPath.path, "-d", tempDir.path]
            try process.run()
            process.waitUntilExit()
            
            guard process.terminationStatus == 0 else {
                throw NSError(domain: "EditViewController", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to unzip dmg in zip"])
            }
            
            // Find .dmg
            let dmgFiles = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "dmg" }
            
            guard let dmgPath = dmgFiles.first else {
                throw NSError(domain: "EditViewController", code: 1, userInfo: [NSLocalizedDescriptionKey: "No dmg found in zip"])
            }
            
            await processPkgInDmg(at: dmgPath)
        } catch {
//            print("Error processing app type: \(error)")
            showError(message: error.localizedDescription)
            cleanupAfterProcessing()
        }
    }
    
    private func handleInspectionResultPkg(_ result: Result<[(String, String)], Error>, type: String, signature: [String: Any], fileURL: URL) {
        switch result {
        case .success(let items):
            guard !items.isEmpty else {
//                print("No valid items found")
                cleanupAfterProcessing()
                return
            }
            
//            print("handleInspectionResult")
//            print("fileURL")
//            print(fileURL)

            // Always present the appropriate modal dialog
            presentPkgInspectorModal(
                pkgItems: items,
                signature: signature,
                pkgURL: fileURL
                )
        case .failure(let error):
            print("Inspection failed: \(error)")
            cleanupAfterProcessing()
        }
    }
    
    private func presentPkgInspectorModal(pkgItems: [(String, String)], signature: [String: Any], pkgURL: URL) {
        guard let appData = appData else {
//            print("Error: appData is missing.")
            return
        }

        let storyboard = NSStoryboard(name: "Main", bundle: nil)
        let pkgInspectorVC = storyboard.instantiateController(withIdentifier: "PkgInspectorViewController") as! PkgInspectorViewController

        // Pass data to the modal
        pkgInspectorVC.pkgItems = pkgItems
        pkgInspectorVC.pkgSignature = signature
        pkgInspectorVC.pkgURL = pkgURL
        pkgInspectorVC.expectedTeamID = appData.expectedTeamID // Use appData for expectedTeamID
        pkgInspectorVC.label = appData.label // Use appData for label
        pkgInspectorVC.itemGUID = appData.guid // Use appData for guid
        pkgInspectorVC.directoryPath = AppConstants.intuneomatorManagedTitlesFolderURL.path
        pkgInspectorVC.delegate = self

        // Show the modal
        presentAsSheet(pkgInspectorVC)
    }


    // MARK: - APP Types
    private func processAppType(location: URL, type: String, inspector: AppInspector) {
        let tempDir = URL(fileURLWithPath: location.deletingLastPathComponent().path)
        
        do {
            switch type {
            case "dmg":
                try processDmg(at: location, tempDir: tempDir, inspector: inspector)
            case "appindmginzip":
                try processAppInDmgInZip(at: location, tempDir: tempDir, inspector: inspector)
            case "zip", "tbz":
                try processCompressedApp(at: location, tempDir: tempDir, inspector: inspector)
            default:
                throw NSError(domain: "EditViewController", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unsupported app type"])
            }
        } catch {
//            print("Error processing app type: \(error)")
            showError(message: error.localizedDescription)
            cleanupAfterProcessing()
        }
    }
    
    private func processDmg(at location: URL, tempDir: URL, inspector: AppInspector) throws {
        // Mount, find app, and inspect
//        print("Processing dmg at \(location)")
        let mountPoint = tempDir.appendingPathComponent("mount")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        process.arguments = ["attach", location.path, "-mountpoint", mountPoint.path, "-nobrowse", "-quiet"]
        try process.run()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            throw NSError(domain: "EditViewController", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to mount dmg"])
        }
        
        // Find the app bundle
        let apps = try FileManager.default.contentsOfDirectory(at: mountPoint, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "app" }
        
        guard let appPath = apps.first else {
            throw NSError(domain: "EditViewController", code: 1, userInfo: [NSLocalizedDescriptionKey: "No app found in dmg"])
        }
        
        // Inspect app signature
        var signatureResult: [String: Any] = [:]
        do {
            signatureResult = try SignatureInspector.inspectAppSignature(appPath: appPath.path)
//            print("App Signature Inspection Result: \(signatureResult)")
        } catch {
//            print("Error inspecting app signature: \(error)")
        }
        
        // Inspect app ID and version
        inspector.inspect(appAt: appPath) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let (id, version, minOSVersion)):
                    // Call the AppInspectorViewController modal
                    self.presentAppInspectorModal(
                        appPath: appPath,
                        appID: id,
                        appVersion: version,
                        appMinOSVersion: minOSVersion,
                        signature: signatureResult                    )
                case .failure(let error):
                    self.showError(message: "App inspection failed: \(error.localizedDescription)")
                }
            }
        }
    }

    private func processAppInDmgInZip(at location: URL, tempDir: URL, inspector: AppInspector) throws {
        // Unzip and process
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-q", location.path, "-d", tempDir.path]
        try process.run()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            throw NSError(domain: "EditViewController", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to unzip dmg in zip"])
        }
        
        let dmgFiles = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "dmg" }
        
        guard let dmgPath = dmgFiles.first else {
            throw NSError(domain: "EditViewController", code: 1, userInfo: [NSLocalizedDescriptionKey: "No dmg found in zip"])
        }
        
        try processDmg(at: dmgPath, tempDir: tempDir, inspector: inspector)
    }
    
    private func processCompressedApp(at location: URL, tempDir: URL, inspector: AppInspector) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        process.arguments = ["-xf", location.path, "-C", tempDir.path]
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw NSError(domain: "EditViewController", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to expand compressed app"])
        }

        let apps = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "app" }

        guard let appPath = apps.first else {
            throw NSError(domain: "EditViewController", code: 1, userInfo: [NSLocalizedDescriptionKey: "No app found in compressed archive"])
        }

        // Inspect app signature
        var signatureResult: [String: Any] = [:]
        do {
            signatureResult = try SignatureInspector.inspectAppSignature(appPath: appPath.path)
//            print("App Signature Inspection Result: \(signatureResult)")
        } catch {
//            print("Error inspecting app signature: \(error)")
        }

        // Inspect the app for its ID and version
        inspector.inspect(appAt: appPath) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let (id, version, minOSVersion)):
                    // Wrap the single result in an array
                    self.handleInspectionResultApp(
                        .success([(id, version, minOSVersion)]),
                        type: "app",
                        signature: signatureResult,
                        fileURL: appPath
                    )
                case .failure(let error):
                    self.handleInspectionResultApp(.failure(error), type: "app", signature: signatureResult, fileURL: appPath)
                }
            }
        }
    }

    
    private func handleInspectionResultApp(_ result: Result<[(String, String, String?)], Error>, type: String, signature: [String: Any], fileURL: URL) {
        switch result {
        case .success(let items):
            guard !items.isEmpty else {
//                print("No valid items found")
                cleanupAfterProcessing()
                return
            }
            
//            print("handleInspectionResult")
//            print("fileURL")
//            print(fileURL)

            // Always present the appropriate modal dialog
                presentAppInspectorModal(
                    appPath: fileURL,
                    appID: items.first?.0 ?? "",   // Default to the first item
                    appVersion: items.first?.1 ?? "", // Default to the first version
                    appMinOSVersion: items.first?.2 ?? "",
                    signature: signature
                )

        case .failure(let error):
//            print("Inspection failed: \(error)")
            cleanupAfterProcessing()
        }
    }


    
    private func presentAppInspectorModal(appPath: URL, appID: String, appVersion: String, appMinOSVersion: String, signature: [String: Any]) {
        guard let appData = appData else {
//            print("Error: appData is missing.")
            return
        }

        let storyboard = NSStoryboard(name: "Main", bundle: nil)
        let appInspectorVC = storyboard.instantiateController(withIdentifier: "AppInspectorViewController") as! AppInspectorViewController

        // Pass data to the modal
        appInspectorVC.appPath = appPath
        appInspectorVC.appID = appID
        appInspectorVC.appVersion = appVersion
        appInspectorVC.appMinOSVersion = appMinOSVersion
        appInspectorVC.signature = signature
        appInspectorVC.expectedTeamID = fieldExpectedTeamID.stringValue
        appInspectorVC.label = appData.label // Use appData for label
        appInspectorVC.itemGUID = appData.guid // Use appData for guid
        appInspectorVC.directoryPath = AppConstants.intuneomatorManagedTitlesFolderURL.path
        appInspectorVC.delegate = self

        // Show the modal
        presentAsSheet(appInspectorVC)
    }

    
    // MARK: - DMG SLA
    private func dmgHasSLA(at path: String) -> Bool {
        let process = Process()
        process.launchPath = "/usr/bin/hdiutil"
        process.arguments = ["imageinfo", path, "-plist"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.launch()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            Logger.logUser("Error: Failed to check for SLA in DMG.", logType: "LabelAutomation")
            return false
        }
        
        let outputData = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let plist = try? PropertyListSerialization.propertyList(from: outputData, options: [], format: nil) as? [String: Any],
              let properties = plist["Properties"] as? [String: Any],
              let hasSLA = properties["Software License Agreement"] as? Bool else {
            return false
        }
        
        return hasSLA
    }
    
    
    func convertDmgWithSLA(at path: String) async -> Bool {
        let fileName = URL(fileURLWithPath: path).lastPathComponent
        let tempDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory())
        let tempFileURL = tempDirectoryURL.appendingPathComponent(fileName)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        process.arguments = ["convert", "-format", "UDRW", "-o", tempFileURL.path, path]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
        } catch {
            Logger.logUser("Error: Could not launch hdiutil: \(error)", logType: "LabelAutomation")
            return false
        }

        // Wait asynchronously for the process to finish
        await withCheckedContinuation { continuation in
            process.terminationHandler = { _ in
                continuation.resume()
            }
        }

        guard process.terminationStatus == 0 else {
            Logger.logUser("Error: hdiutil failed to convert DMG with SLA.", logType: "LabelAutomation")
            return false
        }

        guard FileManager.default.fileExists(atPath: tempFileURL.path) else {
            Logger.logUser("Error: Converted file not found at expected location.", logType: "LabelAutomation")
            return false
        }

        do {
            try FileManager.default.removeItem(atPath: path)
            try FileManager.default.moveItem(atPath: tempFileURL.path, toPath: path)
        } catch {
            Logger.logUser("Failed to finalize converted DMG: \(error)", logType: "LabelAutomation")
            return false
        }

        return true
    }
    
    
    
    // MARK: - Cleanup After Download Processing
    func cleanupAfterProcessing() {
        DispatchQueue.main.async {
            self.progPkgInspect.isIndeterminate = false
            self.progPkgInspect.doubleValue = 0
            self.progPkgInspect.isHidden = true
            self.progPkgInspect.stopAnimation(self)
//            self.setFinalDownloadSize()
        }
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

    
    // MARK: - Categories Popover
    private func setupCategoriesPopover() {
        categoriesPopover = NSPopover()
        categoriesPopover.behavior = .transient

        let contentVC = NSViewController()

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.spacing = 4 // Reduced spacing for better alignment
        stackView.edgeInsets = NSEdgeInsets(top: 0, left: 10, bottom: 10, right: 10) // Remove top padding
        stackView.translatesAutoresizingMaskIntoConstraints = false

        scrollView.documentView = stackView
        contentVC.view = scrollView
        categoriesPopover.contentViewController = contentVC
    }

    
    private func populateCategories() {
        guard let scrollView = categoriesPopover.contentViewController?.view as? NSScrollView,
              let stackView = scrollView.documentView as? NSStackView else {
//            print("StackView not found!")
            return
        }

        // Clear existing items
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        // Fetch cached categories
        self.categories = AppDataManager.shared.mobileAppCategories

        // Populate the checkboxes
        for category in self.categories {
            if let displayName = category["displayName"] as? String,
               let id = category["id"] as? String {
                let checkbox = NSButton(checkboxWithTitle: displayName, target: self, action: #selector(toggleCategory(_:)))
                checkbox.identifier = NSUserInterfaceItemIdentifier(rawValue: id)
                checkbox.state = self.selectedCategories.contains(id) ? .on : .off
                checkbox.alignment = .left // Align text to the left
                checkbox.translatesAutoresizingMaskIntoConstraints = false

                // Add the checkbox to the stack view
                stackView.addArrangedSubview(checkbox)

                // Now apply constraints
                NSLayoutConstraint.activate([
                    checkbox.leadingAnchor.constraint(equalTo: stackView.leadingAnchor, constant: 10),
                    checkbox.trailingAnchor.constraint(lessThanOrEqualTo: stackView.trailingAnchor, constant: -10)
                ])
            }
        }

        // Trigger layout update
        stackView.needsLayout = true
        stackView.layoutSubtreeIfNeeded()
    }

    @IBAction func showCategoriesPopover(_ sender: NSButton) {
        populateCategories()
        updateCategoryButtonTitle() // Ensure the button title reflects the current state
        let maxWidth = calculateMaxWidth(for: categories)
        let maxVisibleItems = 10 // Maximum number of items to show before scrolling
        let itemHeight: CGFloat = 20
        let calculatedHeight = min(CGFloat(categories.count) * itemHeight + 10, CGFloat(maxVisibleItems) * itemHeight + 10)
        categoriesPopover.contentSize = NSSize(width: maxWidth, height: calculatedHeight)

        categoriesPopover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .maxY)
    }

    @objc private func toggleCategory(_ sender: NSButton) {
        guard let id = sender.identifier?.rawValue else { return }

        if sender.state == .on {
            selectedCategories.insert(id)
        } else {
            selectedCategories.remove(id)
        }

//        print("Selected Categories: \(selectedCategories)")
        updateCategoryButtonTitle() // Update the button text
        trackChanges() // Track changes after updating categories
    }

    func getSelectedCategories() -> [String] {
        return Array(selectedCategories)
    }

    private func calculateMaxWidth(for categories: [[String: Any]]) -> CGFloat {
        let font = NSFont.systemFont(ofSize: NSFont.systemFontSize) // Default font for NSButton
        let attributes: [NSAttributedString.Key: Any] = [.font: font]

        var maxWidth: CGFloat = 0
        for category in categories {
            if let displayName = category["displayName"] as? String {
                let size = displayName.size(withAttributes: attributes)
                maxWidth = max(maxWidth, size.width)
            }
        }
        return maxWidth + 50 // Add padding for checkbox and margins
    }

    private func updateCategoryButtonTitle() {
        let count = selectedCategories.count

        if count == 0 {
            buttonSelectCategories.title = "0 selected"
        } else if count == 1, let id = selectedCategories.first {
            // Find the displayName for the single selected ID
            if let category = categories.first(where: { $0["id"] as? String == id }),
               let displayName = category["displayName"] as? String {
                buttonSelectCategories.title = displayName
            } else {
                buttonSelectCategories.title = "1 selected" // Fallback
            }
        } else {
            buttonSelectCategories.title = "\(count) selected"
        }
    }

    
    // MARK: - Show Error Messages
    private func showError(message: String) {
        let alert = NSAlert()
        alert.messageText = "Error"
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
        
    
    // MARK: - URLSessionDownloadDelegate Methods
    // Update progress bar as data is written
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0 else { return } // Avoid division by zero
        
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        
        DispatchQueue.main.async {
            // Update progress bar
            self.progPkgInspect.doubleValue = progress * 100
            
            // Format download sizes
            let totalMB = Double(totalBytesExpectedToWrite) / 1_048_576
            let downloadedMB = Double(totalBytesWritten) / 1_048_576
            
            if totalMB > 1000 {
                let totalGB = totalMB / 1024
                let downloadedGB = downloadedMB / 1024
                if totalGB > 1 {
                    self.fieldDownloadSize.stringValue = String(format: "%.2f GB of %.2f GB", downloadedGB, totalGB)
                } else {
                    self.fieldDownloadSize.stringValue = String(format: "%.1f MB of %.2f GB", downloadedMB, totalGB)
                }
            } else {
                self.fieldDownloadSize.stringValue = String(format: "%.1f MB of %.1f MB", downloadedMB, totalMB)
            }
        }
    }

    // Handle download completion
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // Check the HTTP response for success
        if let response = downloadTask.response as? HTTPURLResponse, !(200...299).contains(response.statusCode) {
            DispatchQueue.main.async {
                self.showError(message: "Download failed: HTTP status code \(response.statusCode)")
                self.cleanupAfterProcessing()
            }
            return
        }

        DispatchQueue.main.async {
            // Change progress bar to indeterminate for post-download tasks
            self.progPkgInspect.isIndeterminate = true
            self.progPkgInspect.startAnimation(self)
        }
        
        let uniqueFolderPath = session.sessionDescription ?? ""
        let uniqueFolder = URL(fileURLWithPath: uniqueFolderPath)
        
        // Determine the file name
        let fileName: String

        if let httpResponse = downloadTask.response as? HTTPURLResponse {
            // Check Content-Disposition header for a file name
            if let contentDisposition = httpResponse.allHeaderFields["Content-Disposition"] as? String,
               let matchedFileName = contentDisposition.split(separator: ";")
                    .first(where: { $0.contains("filename=") })?
                    .split(separator: "=").last?.trimmingCharacters(in: CharacterSet.whitespaces.union(.init(charactersIn: "\""))) {
                fileName = matchedFileName
            } else if let finalURL = httpResponse.url {
                // Fallback to the last path component of the redirected URL
                fileName = finalURL.lastPathComponent.isEmpty ? "downloaded.tmp" : finalURL.lastPathComponent
            } else {
                // Fallback if no name can be determined
                fileName = "downloaded.tmp"
            }
        } else {
            // Absolute fallback
            fileName = "downloaded.tmp"
        }

        let destinationPath = uniqueFolder.appendingPathComponent(fileName)

        do {
            // Move the downloaded file to the destination
            try FileManager.default.moveItem(at: location, to: destinationPath)
            
            Task {
                await self.processDownloadedFile(at: destinationPath)
            }

            // Process the file
//            DispatchQueue.main.async {
//                self.processDownloadedFile(at: destinationPath)
//            }
        } catch {
            DispatchQueue.main.async {
                self.showError(message: "Failed to move downloaded file: \(error.localizedDescription)")
                self.cleanupAfterProcessing()
            }
        }
    }

    // Handle errors
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            DispatchQueue.main.async {
                self.showError(message: "Download failed: \(error.localizedDescription)")
                self.cleanupAfterProcessing()
            }
        }
    }
}

// MARK: - Save Metadata
extension EditViewController: TabSaveable {
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



