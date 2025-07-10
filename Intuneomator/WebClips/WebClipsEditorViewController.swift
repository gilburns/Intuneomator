//
//  WebClipsEditorViewController.swift
//  Intuneomator
//
//  Created by Gil Burns on 7/7/25.
//

import Cocoa

class WebClipsEditorViewController: NSViewController, TabbedSheetChildProtocol, NSTextViewDelegate {
    @IBOutlet weak var largeIconImageView: NSImageView!
    
    @IBOutlet weak var displayNameTextField: NSTextField!
    @IBOutlet weak var descriptionTextView: NSTextView!
    
    @IBOutlet weak var publisherTextField: NSTextField!
    @IBOutlet weak var appUrlTextField: NSTextField!
    
    @IBOutlet weak var fullScreenEnabledCheckbox: NSButton!
    @IBOutlet weak var preComposedIconEnabledCheckbox: NSButton!

    @IBOutlet weak var featureInCompanyPortalEnabledCheckbox: NSButton!

    /// Button to open the categories popover for selecting application categories.
    @IBOutlet weak var buttonSelectCategories: NSButton!

    @IBOutlet weak var informationUrlTextField: NSTextField!
    @IBOutlet weak var privacyUrlTextField: NSTextField!
    @IBOutlet weak var ownerTextField: NSTextField!
    @IBOutlet weak var developerTextField: NSTextField!
    @IBOutlet weak var notesTextView: NSTextView!

    @IBOutlet weak var webClipID: NSTextField!
    
    @IBOutlet weak var saveToFileButton: NSButton!

    var webClipData: [String: Any]?
    var isNewWebClip = false
    var saveHandler: (([String: Any]) -> Void)?
    var webClipId: String?
    
    // MARK: - Change Tracking Properties
    var hasUnsavedChanges = false
    var originalData: [String: Any] = [:]
    var originalIcon: NSImage?
    
    /// Reference to the parent TabbedSheetViewController to notify about save button state
    weak var parentTabViewController: TabbedSheetViewController?

    /// Popover used to display and select categories.
    var categoriesPopover: NSPopover!
    /// Set of IDs for currently selected application categories.
    var selectedCategories: Set<String> = []
    /// Array of all available categories loaded from cache or network.
    var categories: [[String: Any]] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
    }
    
    // Track if view has been configured to avoid repeating setup
    private var viewConfigured = false
    
    override func viewWillAppear() {
        super.viewWillAppear()

        // Only do one-time setup, not on every tab switch
        if !viewConfigured {
            populateFields()
            
            let effectView = NSVisualEffectView(frame: view.bounds)
            effectView.autoresizingMask = [.width, .height]
            effectView.blendingMode = .withinWindow
            effectView.material = .windowBackground
            effectView.state = .active
            
            self.view.addSubview(effectView, positioned: .below, relativeTo: nil)
            
            if let sheetWindow = view.window {
                sheetWindow.minSize = NSSize(width: 700, height: 650) // Set minimum size
            }
            
            viewConfigured = true
        }
    }

    func setupUI() {
        // Setup any UI elements if needed
        // Checkboxes are already configured in storyboard
        setupCategoriesPopover()
        populateCategories()
    }
    
    func populateFields() {
        guard let webClip = webClipData else { return }
        
        webClipId = webClip["id"] as? String
        webClipID.stringValue = webClipId ?? ""
        
        isNewWebClip = webClip["isNewWebClip"] as? Bool ?? false
        
        // Lock appUrl field for existing web clips (it's immutable after creation)
        appUrlTextField.isEditable = isNewWebClip
        if !isNewWebClip {
            appUrlTextField.textColor = NSColor.secondaryLabelColor
        }
                
        // Populate categories from the webClip data
        if let categories = webClip["categories"] as? [[String: Any]] {
            let loadedCategoryIDs = categories.compactMap { $0["id"] as? String }
            selectedCategories = Set(loadedCategoryIDs)
            } else {
            selectedCategories = Set<String>() // Initialize as empty set for new web clips
        }
        
        // Refresh the UI after loading categories
        populateCategories() // Refresh the UI checkboxes
        updateCategoryButtonTitle() // Update the button title based on loaded categories
        
        // Load and display icon if available
        loadWebClipIcon(from: webClip)
        
        displayNameTextField.stringValue = webClip["displayName"] as? String ?? ""
        appUrlTextField.stringValue = webClip["appUrl"] as? String ?? ""
        
        // Set description if available
        if let description = webClip["description"] as? String {
            descriptionTextView.string = description
        } else {
            descriptionTextView.string = ""
        }

        // Set notes if available
        if let notes = webClip["notes"] as? String {
            notesTextView.string = notes
        } else {
            notesTextView.string = ""
        }

        publisherTextField.stringValue = webClip["publisher"] as? String ?? ""
        privacyUrlTextField.stringValue = webClip["privacyInformationUrl"] as? String ?? ""
        informationUrlTextField.stringValue = webClip["informationUrl"] as? String ?? ""
        ownerTextField.stringValue = webClip["owner"] as? String ?? ""
        developerTextField.stringValue = webClip["developer"] as? String ?? ""

        // Set checkbox states
        featureInCompanyPortalEnabledCheckbox.state = (webClip["isFeatured"] as? Bool ?? false) ? .on : .off
        fullScreenEnabledCheckbox.state = (webClip["fullScreenEnabled"] as? Bool ?? false) ? .on : .off
        preComposedIconEnabledCheckbox.state = (webClip["preComposedIconEnabled"] as? Bool ?? false) ? .on : .off
        
        // Store original data for change tracking
        storeOriginalData()
        
        // Set up change tracking for all controls
        setupChangeTracking()
        
        // Initial state: no unsaved changes
        hasUnsavedChanges = false
        updateSaveButtonState()
    }
    
    // MARK: - Icon Management
    
    /// Loads and displays the web clip icon from the provided data
    private func loadWebClipIcon(from webClip: [String: Any]) {
        // Check for largeIcon in web clip data (base64 encoded)
        if let largeIconData = webClip["largeIcon"] as? [String: Any],
           let value = largeIconData["value"] as? String,
           let iconData = Data(base64Encoded: value) {
            let image = NSImage(data: iconData)
            largeIconImageView.image = image
            originalIcon = image
        } else {
            // Set default icon for new web clips or when no icon is available
            setDefaultIcon()
        }
    }
    
    /// Sets a default icon for the web clip
    private func setDefaultIcon() {
        // Use system web browser icon as default
        let defaultIcon: NSImage
        defaultIcon = NSWorkspace.shared.icon(for: .internetLocation)
        largeIconImageView.image = defaultIcon
        originalIcon = defaultIcon
    }
    
    /// Imports a new icon file for the web clip
    @IBAction func importIcon(_ sender: NSButton) {
        let openPanel = NSOpenPanel()
        openPanel.title = "Select Icon Image"
        openPanel.message = "Choose an image file for the web clip icon"
        openPanel.allowedContentTypes = [.png, .jpeg, .tiff, .bmp, .gif]
        openPanel.allowsMultipleSelection = false
        
        if openPanel.runModal() == .OK, let selectedURL = openPanel.url {
            do {
                let imageData = try Data(contentsOf: selectedURL)
                if let image = NSImage(data: imageData) {
                    // Resize image to appropriate size (typically 512x512 for app icons)
                    let resizedImage = resizeImage(image, to: NSSize(width: 512, height: 512))
                    largeIconImageView.image = resizedImage
                    
                    // Trigger change tracking
                    trackChanges()
                    
                    } else {
                    showError(message: "Could not load the selected image file")
                }
            } catch {
                showError(message: "Failed to read image file: \(error.localizedDescription)")
            }
        }
    }
    
    /// Resizes an image to the specified size while maintaining aspect ratio
    private func resizeImage(_ image: NSImage, to targetSize: NSSize) -> NSImage {
        let sourceSize = image.size
        let aspectRatio = sourceSize.width / sourceSize.height
        
        var newSize = targetSize
        if aspectRatio > 1 {
            // Wider than tall
            newSize.height = targetSize.width / aspectRatio
        } else {
            // Taller than wide
            newSize.width = targetSize.height * aspectRatio
        }
        
        let resizedImage = NSImage(size: newSize)
        resizedImage.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: newSize))
        resizedImage.unlockFocus()
        
        return resizedImage
    }
    
    // MARK: - Change Tracking Implementation
    
    /// Stores the original data for change comparison
    private func storeOriginalData() {
        originalData = [
            "categories": getSelectedCategories().compactMap { id -> [String: Any]? in
                if let category = categories.first(where: { $0["id"] as? String == id }),
                   let displayName = category["displayName"] as? String {
                    return [
                        "id": id,
                        "displayName": displayName
                    ]
                }
                return nil
            },
            "displayName": displayNameTextField.stringValue,
            "description": descriptionTextView.string,
            "publisher": publisherTextField.stringValue,
            "appUrl": appUrlTextField.stringValue,
            "fullScreenEnabled": fullScreenEnabledCheckbox.state == .on,
            "preComposedIconEnabled": preComposedIconEnabledCheckbox.state == .on,
            "isFeatured": featureInCompanyPortalEnabledCheckbox.state == .on,
            "privacyInformationUrl": privacyUrlTextField.stringValue,
            "informationUrl": informationUrlTextField.stringValue,
            "owner": ownerTextField.stringValue,
            "developer": developerTextField.stringValue,
            "notes": notesTextView.string
        ]
    }
    
    /// Sets up change tracking for all UI controls
    private func setupChangeTracking() {
        // Text field change tracking
        displayNameTextField.target = self
        displayNameTextField.action = #selector(fieldDidChange(_:))
        
        publisherTextField.target = self
        publisherTextField.action = #selector(fieldDidChange(_:))

        appUrlTextField.target = self
        appUrlTextField.action = #selector(fieldDidChange(_:))

        informationUrlTextField.target = self
        informationUrlTextField.action = #selector(fieldDidChange(_:))

        privacyUrlTextField.target = self
        privacyUrlTextField.action = #selector(fieldDidChange(_:))

        ownerTextField.target = self
        ownerTextField.action = #selector(fieldDidChange(_:))

        developerTextField.target = self
        developerTextField.action = #selector(fieldDidChange(_:))

        // Text view change tracking (delegate method will handle this)
        descriptionTextView.delegate = self
        notesTextView.delegate = self

        // Checkbox change tracking
        featureInCompanyPortalEnabledCheckbox.target = self
        featureInCompanyPortalEnabledCheckbox.action = #selector(checkboxDidChange(_:))

        fullScreenEnabledCheckbox.target = self
        fullScreenEnabledCheckbox.action = #selector(checkboxDidChange(_:))
        
        preComposedIconEnabledCheckbox.target = self
        preComposedIconEnabledCheckbox.action = #selector(checkboxDidChange(_:))
    }
    
    /// Compares current values with original data and updates UI accordingly
    func trackChanges() {
        hasUnsavedChanges = false // Reset and re-evaluate
        
        // Check text fields
        checkFieldChange(displayNameTextField.stringValue,
                        originalValue: originalData["displayName"] as? String ?? "",
                        control: displayNameTextField)

        checkFieldChange(publisherTextField.stringValue,
                        originalValue: originalData["publisher"] as? String ?? "",
                        control: publisherTextField)

        checkFieldChange(appUrlTextField.stringValue,
                        originalValue: originalData["appUrl"] as? String ?? "",
                        control: appUrlTextField)

        checkFieldChange(informationUrlTextField.stringValue,
                        originalValue: originalData["informationUrl"] as? String ?? "",
                        control: informationUrlTextField)

        checkFieldChange(privacyUrlTextField.stringValue,
                        originalValue: originalData["privacyInformationUrl"] as? String ?? "",
                        control: privacyUrlTextField)

        checkFieldChange(ownerTextField.stringValue,
                        originalValue: originalData["owner"] as? String ?? "",
                        control: ownerTextField)

        checkFieldChange(developerTextField.stringValue,
                        originalValue: originalData["developer"] as? String ?? "",
                        control: developerTextField)

        
        // Check text views
        checkTextViewChange(notesTextView.string,
                           originalValue: originalData["notes"] as? String ?? "",
                           textView: notesTextView)

        checkTextViewChange(descriptionTextView.string,
                           originalValue: originalData["description"] as? String ?? "",
                           textView: descriptionTextView)

        // Check checkboxes
        checkFieldChange(featureInCompanyPortalEnabledCheckbox.state == .on,
                        originalValue: originalData["isFeatured"] as? Bool ?? false,
                        control: featureInCompanyPortalEnabledCheckbox)

        checkFieldChange(fullScreenEnabledCheckbox.state == .on,
                        originalValue: originalData["fullScreenEnabled"] as? Bool ?? false,
                        control: fullScreenEnabledCheckbox)

        checkFieldChange(preComposedIconEnabledCheckbox.state == .on,
                        originalValue: originalData["preComposedIconEnabled"] as? Bool ?? false,
                        control: preComposedIconEnabledCheckbox)
        
        // Check categories for changes
        checkCategoryChanges()
        
        // Check icon for changes
        checkIconChanges()

        updateSaveButtonState()
    }
    
    /// Utility to compare a field's current and original values. Highlights control if changed.
    private func checkFieldChange<T: Equatable>(_ currentValue: T, originalValue: T, control: NSControl) {
        if currentValue != originalValue {
            hasUnsavedChanges = true
            highlightField(control)
        } else {
            clearHighlight(control)
        }
    }
    
    /// Utility to compare a text view's current and original values. Highlights text view if changed.
    private func checkTextViewChange<T: Equatable>(_ currentValue: T, originalValue: T, textView: NSTextView) {
        if currentValue != originalValue {
            hasUnsavedChanges = true
            highlightTextView(textView)
        } else {
            clearHighlightTextView(textView)
        }
    }
    
    /// Compares current selected categories with original categories and highlights button if changed
    private func checkCategoryChanges() {
        // Get original categories from originalData
        let originalCategories: Set<String>
        if let originalCategoryData = originalData["categories"] as? [[String: Any]] {
            originalCategories = Set(originalCategoryData.compactMap { $0["id"] as? String })
        } else {
            originalCategories = Set<String>()
        }
        
        // Compare current selection with original
        if selectedCategories != originalCategories {
            hasUnsavedChanges = true
            highlightField(buttonSelectCategories)
        } else {
            clearHighlight(buttonSelectCategories)
        }
    }
    
    /// Compares current icon with original icon and highlights image view if changed
    private func checkIconChanges() {
        let currentIcon = largeIconImageView.image
        
        // Compare current icon with original
        if !areImagesEqual(currentIcon, originalIcon) {
            hasUnsavedChanges = true
            highlightImageView(largeIconImageView)
        } else {
            clearHighlightImageView(largeIconImageView)
        }
    }
    
    /// Compares two NSImage objects for equality
    private func areImagesEqual(_ image1: NSImage?, _ image2: NSImage?) -> Bool {
        // Handle nil cases
        if image1 == nil && image2 == nil { return true }
        if image1 == nil || image2 == nil { return false }
        
        guard let img1 = image1, let img2 = image2 else { return false }
        
        // Compare image data
        guard let data1 = img1.tiffRepresentation,
              let data2 = img2.tiffRepresentation else { return false }
        
        return data1 == data2
    }
    
    /// Highlights the given image view with a yellow border to indicate change
    private func highlightImageView(_ imageView: NSImageView) {
        imageView.wantsLayer = true
        imageView.layer?.borderColor = NSColor.systemYellow.cgColor
        imageView.layer?.borderWidth = 3.0
        imageView.layer?.cornerRadius = 8.0
    }
    
    /// Removes highlight from the given image view (restores default border)
    private func clearHighlightImageView(_ imageView: NSImageView) {
        imageView.layer?.borderColor = NSColor.clear.cgColor
        imageView.layer?.borderWidth = 0.0
        imageView.layer?.cornerRadius = 0.0
    }
    
    /// Highlights the given control with a yellow background to indicate change
    private func highlightField(_ field: NSControl) {
        if let textField = field as? NSTextField {
            textField.backgroundColor = NSColor.systemYellow
        } else if let button = field as? NSButton {
            button.layer?.backgroundColor = NSColor.systemYellow.cgColor
        }
    }
    
    /// Removes highlight from the given control (restores default background)
    private func clearHighlight(_ field: NSControl) {
        if let textField = field as? NSTextField {
            textField.backgroundColor = NSColor.controlBackgroundColor
        } else if let button = field as? NSButton {
            button.layer?.backgroundColor = NSColor.clear.cgColor
        }
    }
    
    /// Highlights the given text view with a yellow border to indicate change
    private func highlightTextView(_ textView: NSTextView) {
        // Ensure the text view has a layer
        textView.wantsLayer = true
        
        // Set yellow border
        textView.layer?.borderColor = NSColor.systemYellow.cgColor
        textView.layer?.borderWidth = 2.0
        textView.layer?.cornerRadius = 4.0
    }
    
    /// Removes highlight from the given text view (restores default border)
    private func clearHighlightTextView(_ textView: NSTextView) {
        // Clear the border
        textView.layer?.borderColor = NSColor.clear.cgColor
        textView.layer?.borderWidth = 0.0
        textView.layer?.cornerRadius = 0.0
    }
    
    /// Updates the save button state based on unsaved changes
    private func updateSaveButtonState() {
        // For new web clips, always allow saving if there's content
        if isNewWebClip {
            let hasContent = !displayNameTextField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                            !appUrlTextField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            hasUnsavedChanges = hasContent  // Set unsaved changes for new web clips with content
        }
        // For existing web clips, hasUnsavedChanges is already set by trackChanges()
        
        // Notify parent tabbed view controller
        if let parent = parentTabViewController {
                parent.updateSaveButtonState()
        }
    }

    // MARK: - Change Tracking Actions
    
    @objc private func fieldDidChange(_ sender: NSTextField) {
        trackChanges()
    }
    
    @objc private func checkboxDidChange(_ sender: NSButton) {
        trackChanges()
    }
    
    @IBAction func saveChanges(_ sender: Any) {
        guard let handler = saveHandler else { return }
        
        // Use the same optimized data logic as getDataForSave()
        guard let webClipData = getDataForSave() else {
            showError(message: "Failed to prepare web clip data for saving")
            return
        }
        
        handler(webClipData)
        dismiss(self)
    }
        
    @IBAction func saveWebClipToFile(_ sender: Any) {
        let webClipName = displayNameTextField.stringValue
        let webClipUrl = appUrlTextField.stringValue
        let featured = featureInCompanyPortalEnabledCheckbox.state == .on
        let fullScreen = fullScreenEnabledCheckbox.state == .on
        
        
        // Create a simple text representation of the web clip
        let webClipContent = """
        Web Clip: \(webClipName)
        Intune ID: \(webClipID.stringValue)
        Description: \(descriptionTextView.string)
        URL: \(webClipUrl)
        Featured: \(featured ? "Yes" : "No")
        Publisher: \(publisherTextField.stringValue)
        Owner: \(ownerTextField.stringValue)
        Developer: \(developerTextField.stringValue)
        Privacy URL: \(privacyUrlTextField.stringValue)
        Info URL: \(informationUrlTextField.stringValue)
        Notes: \(notesTextView.string)
        Full Screen: \(fullScreen ? "Yes" : "No")
        """
        
        let savePanel = NSSavePanel()
        savePanel.message = "Save Web Clip"
        savePanel.nameFieldStringValue = webClipName + ".txt"
        savePanel.allowedContentTypes = [.text, .plainText]

        savePanel.begin { response in
            if response == .OK, let fileURL = savePanel.url {
                do {
                    try webClipContent.write(to: fileURL, atomically: true, encoding: .utf8)
                } catch {
                    self.showError(message: "Failed to save web clip: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - TabbedSheetChildProtocol
    
    func getDataForSave() -> [String: Any]? {
        if isNewWebClip {
            // For new web clips, include all fields
            var webClipData: [String: Any] = [
                "@odata.type": "#microsoft.graph.macOSWebClip",
                "displayName": displayNameTextField.stringValue,
                "appUrl": appUrlTextField.stringValue,
                "publisher": publisherTextField.stringValue,
                "owner": ownerTextField.stringValue,
                "developer": developerTextField.stringValue,
                "privacyInformationUrl": privacyUrlTextField.stringValue,
                "informationUrl": informationUrlTextField.stringValue,
                "isFeatured": featureInCompanyPortalEnabledCheckbox.state == .on,
                "fullScreenEnabled": fullScreenEnabledCheckbox.state == .on,
                "preComposedIconEnabled": preComposedIconEnabledCheckbox.state == .on
            ]
            
            // Add description if not empty
            let description = descriptionTextView.string.trimmingCharacters(in: .whitespacesAndNewlines)
            if !description.isEmpty {
                webClipData["description"] = description
            }

            // Add notes if not empty
            let notes = notesTextView.string.trimmingCharacters(in: .whitespacesAndNewlines)
            if !notes.isEmpty {
                webClipData["notes"] = notes
            }

            // Include selected categories as dictionaries (XPC compatible)
            let selectedCategoryData = getSelectedCategories().compactMap { id -> [String: Any]? in
                if let category = categories.first(where: { $0["id"] as? String == id }),
                   let displayName = category["displayName"] as? String {
                    return [
                        "id": id,
                        "displayName": displayName
                    ]
                }
                return nil
            }
            webClipData["categories"] = selectedCategoryData
            
            // Include icon data if available
            if let iconImage = largeIconImageView.image,
               let imageData = iconImage.tiffRepresentation,
               let pngData = NSBitmapImageRep(data: imageData)?.representation(using: .png, properties: [:]) {
                let base64String = pngData.base64EncodedString()
                webClipData["largeIcon"] = [
                    "@odata.type": "#microsoft.graph.mimeContent",
                    "type": "image/png",
                    "value": base64String
                ]
            }
            
            return webClipData
        } else {
            // For existing web clips, only include changed fields
            var changedData: [String: Any] = [:]
            
            // Include web clip ID for identification
            if let webClipId = webClipId {
                changedData["id"] = webClipId
                changedData["@odata.type"] = "#microsoft.graph.macOSWebClip"

            }
            
            return getChangedFieldsOnly(changedData: &changedData)
        }
    }
    
    /// Returns only the fields that have changed from their original values
    private func getChangedFieldsOnly(changedData: inout [String: Any]) -> [String: Any] {
        // Check each field for changes and only include changed ones
        
        // Display name
        if displayNameTextField.stringValue != (originalData["displayName"] as? String ?? "") {
            changedData["displayName"] = displayNameTextField.stringValue
        }
        
        // Description
        let currentDescription = descriptionTextView.string.trimmingCharacters(in: .whitespacesAndNewlines)
        let originalDescription = originalData["description"] as? String ?? ""
        if currentDescription != originalDescription {
            if currentDescription.isEmpty {
                changedData["description"] = NSNull() // Explicitly clear the field
            } else {
                changedData["description"] = currentDescription
            }
        }
        
        // Publisher
        if publisherTextField.stringValue != (originalData["publisher"] as? String ?? "") {
            changedData["publisher"] = publisherTextField.stringValue
        }
        
        // Note: appUrl is NOT included - it's immutable after creation
        
        // Full screen enabled
        let currentFullScreen = fullScreenEnabledCheckbox.state == .on
        if currentFullScreen != (originalData["fullScreenEnabled"] as? Bool ?? false) {
            changedData["fullScreenEnabled"] = currentFullScreen
        }
        
        // Pre-composed icon enabled
        let currentPreComposed = preComposedIconEnabledCheckbox.state == .on
        if currentPreComposed != (originalData["preComposedIconEnabled"] as? Bool ?? false) {
            changedData["preComposedIconEnabled"] = currentPreComposed
        }
        
        // Featured status
        let currentFeatured = featureInCompanyPortalEnabledCheckbox.state == .on
        if currentFeatured != (originalData["isFeatured"] as? Bool ?? false) {
            changedData["isFeatured"] = currentFeatured
        }
        
        // URLs
        if informationUrlTextField.stringValue != (originalData["informationUrl"] as? String ?? "") {
            changedData["informationUrl"] = informationUrlTextField.stringValue
        }
        
        if privacyUrlTextField.stringValue != (originalData["privacyInformationUrl"] as? String ?? "") {
            changedData["privacyInformationUrl"] = privacyUrlTextField.stringValue
        }
        
        // Owner and developer
        if ownerTextField.stringValue != (originalData["owner"] as? String ?? "") {
            changedData["owner"] = ownerTextField.stringValue
        }
        
        if developerTextField.stringValue != (originalData["developer"] as? String ?? "") {
            changedData["developer"] = developerTextField.stringValue
        }
        
        // Notes
        let currentNotes = notesTextView.string.trimmingCharacters(in: .whitespacesAndNewlines)
        let originalNotes = originalData["notes"] as? String ?? ""
        if currentNotes != originalNotes {
            if currentNotes.isEmpty {
                changedData["notes"] = NSNull() // Explicitly clear the field
            } else {
                changedData["notes"] = currentNotes
            }
        }
        
        // Categories (compare sets of IDs)
        let originalCategories: Set<String>
        if let originalCategoryData = originalData["categories"] as? [[String: Any]] {
            originalCategories = Set(originalCategoryData.compactMap { $0["id"] as? String })
        } else {
            originalCategories = Set<String>()
        }
        
        if selectedCategories != originalCategories {
            let selectedCategoryData = getSelectedCategories().compactMap { id -> [String: Any]? in
                if let category = categories.first(where: { $0["id"] as? String == id }),
                   let displayName = category["displayName"] as? String {
                    return [
                        "id": id,
                        "displayName": displayName
                    ]
                }
                return nil
            }
            changedData["categories"] = selectedCategoryData
        }
        
        // Icon (compare images)
        if !areImagesEqual(largeIconImageView.image, originalIcon) {
            if let iconImage = largeIconImageView.image,
               let imageData = iconImage.tiffRepresentation,
               let pngData = NSBitmapImageRep(data: imageData)?.representation(using: .png, properties: [:]) {
                let base64String = pngData.base64EncodedString()
                changedData["largeIcon"] = [
                    "@odata.type": "#microsoft.graph.mimeContent",
                    "type": "image/png",
                    "value": base64String
                ]
            }
        }
        
 // -1 to exclude the ID
        return changedData
    }
    
    func setInitialData(_ data: [String: Any]) {
        self.webClipData = data
        self.isNewWebClip = data["isNewWebClip"] as? Bool ?? false
        self.webClipId = data["id"] as? String
        
        // Initialize change tracking state
        hasUnsavedChanges = false
    }
    
    func updateFromOtherTabs(_ combinedData: [String: Any]) {
        // Web clip editor doesn't need to update based on other tabs currently
        // This could be used in the future if group assignments affect web clip properties
    }
    
    func validateData() -> String? {
        // Validate required fields
        if displayNameTextField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Display name is required"
        }
        
        let appUrl = appUrlTextField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if appUrl.isEmpty {
            return "App URL is required"
        }
        
        // Validate URL format
        if !appUrl.hasPrefix("http://") && !appUrl.hasPrefix("https://") {
            return "App URL must start with http:// or https://"
        }
        
        return nil
    }
    
    // MARK: - Error Handling
    private func showError(message: String) {
        let alert = NSAlert()
        alert.messageText = "Error"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

// MARK: - NSTextViewDelegate

extension WebClipsEditorViewController {
    func textDidChange(_ notification: Notification) {
        // Track changes when text views are modified
        trackChanges()
    }
}
