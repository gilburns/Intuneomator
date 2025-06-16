//
//  TabViewController.swift
//  Intuneomator
//
//  Created by Gil Burns on 1/17/25.
//

import Foundation
import Cocoa


protocol TabSaveable {
    func saveMetadata()
}

protocol UnsavedChangesHandling {
    var hasUnsavedChanges: Bool { get }
}


/// Modal sheet view controller for managing application metadata across multiple tabbed interfaces
/// Provides coordinated editing environment for app details, scripts, and group assignments
/// Implements lazy loading and caching of tab view controllers for optimal performance
class TabViewController: NSViewController {

    // MARK: - Interface Builder Outlets
    
    /// Label displaying the name of the application being edited
    @IBOutlet weak var labelAppName: NSTextField!
    
    /// Image view showing cloud upload status with visual indicators
    @IBOutlet weak var imageCloudStatus: NSImageView!

    /// Main tab view container hosting Edit, Scripts, and Assignments tabs
    @IBOutlet var tabView: NSTabView!
    
    /// Button to save changes across all tabs
    @IBOutlet weak var saveButton: NSButton!
    
    /// Button to cancel editing and dismiss the sheet
    @IBOutlet weak var cancelButton: NSButton!
    
    /// Label for custom Installomator label toggle functionality
    @IBOutlet weak var labelCustomLabel: NSTextField!
    
    /// Switch to toggle between standard and custom Installomator labels
    @IBOutlet weak var buttonCustomOnOff: NSSwitch!
    
    // MARK: - Data Properties
    
    /// Application metadata passed from the main view controller
    var appData: AppInfo?

    /// Identifiers for dynamically loaded tab view controllers
    private let tabIdentifiers = [
        "EditView",
        "ScriptPrePostView",
        "GroupAssignmentsView"
    ]

    /// Reference to the scripts tab for validation and conditional access
    private var secondTabItem: NSTabViewItem?

    /// Cache for instantiated view controllers to improve performance
    private var viewControllerCache: [String: NSViewController] = [:]
    
    private var keyMonitor: Any?
    
    // MARK: - View Lifecycle Methods
    
    /// Called after the view controller's view is loaded into memory
    /// Initializes tab view, sets up delegate, and configures initial display
    override func viewDidLoad() {
        super.viewDidLoad()

        labelAppName.stringValue = "Editing: \(appData?.name ?? "Application:")"

        tabView.delegate = self
        setupTabs()
        
        secondTabItem = tabView.tabViewItems[1]
    }

    /// Called when the view controller's view is about to appear
    /// Loads initial tabs, restores window size, and updates cloud status
    override func viewWillAppear() {
        super.viewWillAppear()
        
        // Ensure the first tab is loaded
        if let firstTab = tabView.tabViewItems.first {
            loadTabViewController(for: firstTab)
        }

        // Preload the ScriptViewController for validation
        if let scriptTab = tabView.tabViewItems.first(where: { $0.identifier as? String == "ScriptPrePostView" }) {
            loadTabViewController(for: scriptTab)
        }

        // Restore saved window size or apply default dimensions
        let defaultSize = NSSize(width: 820, height: 730)
        let savedSize = loadSavedSheetSize() ?? defaultSize

        if let window = view.window {
            window.setContentSize(savedSize)
            window.minSize = NSSize(width: 820, height: 730)
        }

        setCloudStatusIcon()
    }

    /// Called when the view controller's view has appeared on screen
    /// Updates custom label status and saves current window size
    override func viewDidAppear() {
        super.viewDidAppear()
        self.view.window?.makeFirstResponder(self)

        checkCustomLabel()
        setToggleCustomButtonAvailability()

        // Save current window size for next session
        if let window = view.window {
            saveSheetSize(window.frame.size)
        }
        
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }

            if event.modifierFlags.contains(.command),
               let chars = event.charactersIgnoringModifiers {
                switch chars {
                case "1":
                    self.tabView.selectTabViewItem(at: 0)
                    return nil
                case "2":
                    self.tabView.selectTabViewItem(at: 1)
                    return nil
                case "3":
                    self.tabView.selectTabViewItem(at: 2)
                    return nil
                default:
                    break
                }
            }

            return event
        }

        
    }
    
    /// Called when the view controller's view has disappeared from screen
    /// Saves final window size to preserve user preferences
    override func viewDidDisappear() {
        super.viewDidDisappear()

        // Save the sheet size when the view is dismissed
        if let window = view.window {
            saveSheetSize(window.frame.size)
        }
        
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }

    }

    
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard event.modifierFlags.contains(.command),
              let characters = event.charactersIgnoringModifiers else {
            return super.performKeyEquivalent(with: event)
        }

        switch characters {
        case "1":
            tabView.selectTabViewItem(at: 0)
            return true
        case "2":
            tabView.selectTabViewItem(at: 1)
            return true
        case "3":
            tabView.selectTabViewItem(at: 2)
            return true
        default:
            return super.performKeyEquivalent(with: event)
        }
    }

    // MARK: - Save Action Methods
    
    /// Handles save button click to persist changes across all tabs
    /// Triggers validation and saves metadata for all loaded view controllers
    /// - Parameter sender: The save button that triggered the action
    @IBAction func saveAllTabs(_ sender: Any) {
        saveAllTabsData()
    }
    
    /// Coordinates saving across all cached tab view controllers
    /// Validates script tabs before saving and notifies completion via notification
    /// Dismisses the modal sheet after successful save operations
    func saveAllTabsData() {
        for (_, viewController) in viewControllerCache {
            if let scriptVC = viewController as? ScriptViewController {
                // Skip saving scripts if there are validation warnings
                if scriptVC.warningLabel.isHidden {
                    scriptVC.saveMetadata()
                } else {
                    Logger.warning("Script tab has validation issues. Skipping script save.", category: .core, toUserDirectory: true)
                }
            } else if let saveableVC = viewController as? TabSaveable {
                // Save other tabs that conform to TabSaveable protocol
                saveableVC.saveMetadata()
            } else {
                Logger.warning("ViewController \(String(describing: viewController)) does not conform to TabSaveable.", category: .core, toUserDirectory: true)
            }
        }

        DispatchQueue.main.async { [self] in
            // Notify completion to refresh main view
            NotificationCenter.default.post(
                name: .labelEditCompleted,
                object: nil,
                userInfo: ["label": self.appData!.label as Any, "guid": self.appData!.guid as Any]
            )
        }
        dismiss(nil)
    }

    /// Updates save button enabled state based on unsaved changes and script validation
    /// Save button is enabled only when there are unsaved changes AND scripts are valid
    func updateSaveButtonState() {
        // Check for unsaved changes across all tabs
        let hasUnsavedChanges = viewControllerCache.values.contains { viewController in
            (viewController as? UnsavedChangesHandling)?.hasUnsavedChanges == true
        }

        // Check if the Script tab is valid
        if let scriptVC = viewControllerCache["ScriptPrePostView"] as? ScriptViewController {
            let isScriptValid = scriptVC.isValid
            saveButton.isEnabled = hasUnsavedChanges && isScriptValid
        } else {
            saveButton.isEnabled = hasUnsavedChanges
        }
    }

    // MARK: - Custom Label Management Methods
    
    /// Handles custom Installomator label toggle switch changes
    /// Switches between standard and custom label implementations via XPC service
    /// Updates UI visual indicators and notifies other components of changes
    /// - Parameter sender: The toggle switch that triggered the action
    @IBAction func toggleCustom(_ sender: NSButton) {
        let toggleState = (sender.state == .on)
        
        let labelName = appData?.label ?? ""
        let labelGuid = appData?.guid ?? ""
        let directoryPath = "\(labelName)_\(labelGuid)"
                
        XPCManager.shared.toggleCustomLabel(directoryPath, toggleState) { success in
            if success! {
                DispatchQueue.main.async {
                    // Update visual indicators based on toggle state
                    if toggleState == true {
                        self.labelCustomLabel.textColor = .systemRed
                    } else {
                        self.labelCustomLabel.textColor = .lightGray
                    }
                    
                    // Notify other components of custom label state change
                    NotificationCenter.default.post(
                        name: .customLabelToggled,
                        object: nil,
                        userInfo: nil)
                }
            } else {
                Logger.info("Toggle Custom Label Failed: \(directoryPath)", category: .core, toUserDirectory: true)
            }
        }
    }
    /// Configures custom label toggle button availability and display text
    /// Checks for existence of both standard and custom Installomator labels
    /// Updates button state and label text based on label availability
    func setToggleCustomButtonAvailability() {
        let labelName = appData?.label ?? ""
        let labelGUID = appData?.guid ?? ""
        
        let directoryPath = "\(labelName)_\(labelGUID)"
        
        let isCustomInUseURL = AppConstants.intuneomatorManagedTitlesFolderURL
            .appendingPathComponent(directoryPath, isDirectory: true)
            .appendingPathComponent(".custom")
        
        let isCustomLabelEnabled: Bool
        isCustomLabelEnabled = FileManager.default.fileExists(atPath: isCustomInUseURL.path)
        
        let standardLabelURL = AppConstants.installomatorLabelsFolderURL
            .appendingPathComponent("\(labelName).sh")

        let customLabelURL = AppConstants.installomatorCustomLabelsFolderURL
            .appendingPathComponent("\(labelName).sh")

        let standardLabelExists = FileManager.default.fileExists(atPath: standardLabelURL.path)
        let customLabelExists = FileManager.default.fileExists(atPath: customLabelURL.path)
                
        // Configure button and label based on available label types
        if standardLabelExists && customLabelExists {
            buttonCustomOnOff.isEnabled = true
            labelCustomLabel.stringValue = "Use Custom Label"
        } else if customLabelExists && !standardLabelExists{
            buttonCustomOnOff.isEnabled = false
            labelCustomLabel.stringValue = "Custom Only Label"
        } else {
            buttonCustomOnOff.isEnabled = false
            labelCustomLabel.stringValue = "No Custom Label Available"
        }
        
        // Set visual state based on current custom label usage
        if !isCustomLabelEnabled {
            buttonCustomOnOff.state = .off
            labelCustomLabel.textColor = .lightGray
        } else {
            buttonCustomOnOff.state = .on
            labelCustomLabel.textColor = .systemRed
        }
    }
    
    
    // MARK: - Cancel Action Methods
    
    /// Handles cancel button click with unsaved changes validation
    /// Prompts user to confirm if there are unsaved changes before dismissing
    /// - Parameter sender: The cancel button that triggered the action
    @IBAction func cancelButtonClicked(_ sender: NSButton) {
        
        // Check for unsaved changes across all tabs
        let hasUnsavedChanges = viewControllerCache.values.contains { viewController in
            (viewController as? UnsavedChangesHandling)?.hasUnsavedChanges == true
        }

        if hasUnsavedChanges {
            let alert = NSAlert()
            alert.messageText = "Unsaved Changes"
            alert.informativeText = "You have unsaved changes. Are you sure you want to discard them?"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Discard Changes")
            alert.addButton(withTitle: "Cancel")
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                // User chose to discard changes
                self.dismiss(self)
            }
        } else {
            self.dismiss(self)
        }
    }

    
    // MARK: - Delete Action Method
    
    /**
     * Removes the selected app automation entry after user confirmation.
     *
     * This method:
     * 1. Gets the selected table row and validates selection
     * 2. Shows a confirmation dialog with app details
     * 3. Deletes the associated directory via XPC service
     * 4. Updates the data arrays and refreshes the UI
     *
     * The deletion is permanent and cannot be undone.
     *
     * - Parameter sender: The UI control that triggered this action
     */
    @IBAction func removeLabelAutomation(_ sender: Any) {
        
        guard let itemLabel = appData?.label else { return }
        guard let itemGuid = appData?.guid else { return }
        guard let itemName = appData?.name else { return }
        
        let folderName = "\(itemLabel)_\(itemGuid)"
        
        // Get the name of the selected item for the confirmation dialog
        Logger.info("Button clicked to delete '\(itemName)' directory.", category: .core, toUserDirectory: true)

        // Create a confirmation dialog
        let alert = NSAlert()
        alert.messageText = "Confirm Deletion"
        alert.informativeText = "Are you sure you want to delete '\(itemName) - \(itemLabel)'? This action cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")

        // Show the dialog and handle the response
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            // User confirmed deletion
            Logger.info("User confirmed deletion of '\(itemName)' directory.", category: .core, toUserDirectory: true)
            // Remove the directory associated with the item
            let directoryPath = (AppConstants.intuneomatorManagedTitlesFolderURL.path as NSString).appendingPathComponent("\(itemLabel)_\(itemGuid)")

            
            XPCManager.shared.removeLabelContent(directoryPath) { success in
                if let success = success, success {
                    
                    Logger.info("Deleted directory: \(directoryPath)", category: .core, toUserDirectory: true)

                    NotificationCenter.default.post(
                        name: .labelDeleteCompleted,
                        object: nil,
                        userInfo: ["label": itemLabel, "guid": itemGuid]
                    )
                    
                    DispatchQueue.main.async {
                        self.dismiss(self)
                    }

                } else {
                    Logger.info("Failed to delete directory: \(directoryPath)", category: .core, toUserDirectory: true)
                    return
                }
            }
    
        } else {
            // User canceled deletion
            Logger.info("User canceled deletion", category: .core, toUserDirectory: true)
        }
    }

    
    // MARK: - Alert Helper Methods
    
    /// Displays warning alert dialog with custom title and message
    /// Used for error notifications and user feedback throughout the tab interface
    /// - Parameters:
    ///   - title: Alert dialog title text
    ///   - message: Alert dialog message text
    func showAlert(withTitle title: String, message: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    
    // MARK: - Window Size Management Methods
    
    /// Saves the current sheet size to UserDefaults for persistence
    /// Preserves user's preferred window dimensions across application sessions
    /// - Parameter size: NSSize representing the current window dimensions
    private func saveSheetSize(_ size: NSSize) {
        let sizeDict = ["width": size.width, "height": size.height]
        UserDefaults.standard.set(sizeDict, forKey: "TabViewSheetSize")
    }

    /// Loads the previously saved sheet size from UserDefaults
    /// Returns nil if no saved size exists, triggering default size usage
    /// - Returns: Optional NSSize with saved dimensions, or nil if not found
    private func loadSavedSheetSize() -> NSSize? {
        if let sizeDict = UserDefaults.standard.dictionary(forKey: "TabViewSheetSize") as? [String: CGFloat],
           let width = sizeDict["width"], let height = sizeDict["height"] {
            return NSSize(width: width, height: height)
        }
        return nil
    }

    
    // MARK: - Cloud Status Icon Methods
    
    /// Creates and displays cloud status icon with upload count overlay
    /// Reads upload count from .uploaded file and generates visual indicator
    /// Green cloud with blue overlay indicates successful uploads, gray indicates no uploads
    private func setCloudStatusIcon() {
        let baseURL = AppConstants.intuneomatorManagedTitlesFolderURL
        let folderURL = baseURL
            .appendingPathComponent("\(appData!.label)_\(appData!.guid)")

        var labelUploadCount: Int = 0
        var cloudImageIcon: NSImage?
        let labelUploadStateURL = folderURL.appendingPathComponent(".uploaded")
        
        // Read upload count from tracking file
        if FileManager.default.fileExists(atPath: labelUploadStateURL.path) {
            if let data = FileManager.default.contents(atPath: labelUploadStateURL.path),
               let countString = String(data: data, encoding: .utf8),
               let count = Int(countString) {
                labelUploadCount = count
            }
        }

        // Configure colors and symbols based on upload status
        let symbolName: String
        let symbolNumber: String
        var tintColor: NSColor
        var tintColorOverlay: NSColor
        var tintColorNumber: NSColor
        if labelUploadCount > 0 {
            symbolName = "circle.fill"
            symbolNumber = "\(labelUploadCount).circle"
            tintColor = NSColor.systemGreen
            tintColorNumber = NSColor.white
            tintColorOverlay = NSColor.systemBlue
        } else {
            symbolName = "circle.fill"
            symbolNumber = "\(labelUploadCount).circle"
            tintColor = NSColor.lightGray
            tintColorNumber = NSColor.white
            tintColorOverlay = NSColor.darkGray
        }

        let baseSize = NSSize(width: 30, height: 26)
        let overlaySize = NSSize(width: 16, height: 16)
        let overlayOrigin = NSPoint(x: 6.5, y: 3.5)

        let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .light)

        // Compose layered icon with cloud base, status overlay, and count number
        if let tintedBase = tintedSymbolImage(named: "cloud", color: tintColor, size: baseSize, config: config),
           let tintedOverlay = tintedSymbolImage(named: symbolName, color: tintColorOverlay, size: overlaySize, config: config),
            let tintedNumber = tintedSymbolImage(named: symbolNumber, color: tintColorNumber, size: overlaySize, config: config) {

            let composed = NSImage(size: baseSize)
            composed.lockFocus()
            NSGraphicsContext.current?.imageInterpolation = .high

            tintedBase.draw(in: NSRect(origin: .zero, size: baseSize))
            tintedOverlay.draw(in: NSRect(origin: overlayOrigin, size: overlaySize))
            tintedNumber.draw(in: NSRect(origin: overlayOrigin, size: overlaySize))

            composed.unlockFocus()
            composed.isTemplate = false

            cloudImageIcon = composed
        } else {
            print ("Could not create cloud icon")
        }

        imageCloudStatus.image = cloudImageIcon
    }
    
    /// Creates a tinted SF Symbol image with specified color and configuration
    /// Used for generating colored icon elements in the cloud status display
    /// - Parameters:
    ///   - name: SF Symbol name to create
    ///   - color: NSColor to apply as tint
    ///   - size: Target size for the rendered image
    ///   - config: Symbol configuration for weight and point size
    /// - Returns: Tinted NSImage or nil if symbol creation fails
    func tintedSymbolImage(named name: String, color: NSColor, size: NSSize, config: NSImage.SymbolConfiguration) -> NSImage? {
        guard let baseImage = NSImage(systemSymbolName: name, accessibilityDescription: nil)?.withSymbolConfiguration(config) else {
            return nil
        }

        let tinted = NSImage(size: size)
        tinted.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high

        baseImage.draw(in: NSRect(origin: .zero, size: size))
        color.set()
        NSRect(origin: .zero, size: size).fill(using: .sourceAtop)

        tinted.unlockFocus()
        tinted.isTemplate = false
        return tinted
    }

    
    // MARK: - Tab Management Methods
    
    /// Configures the tab view with Edit, Scripts, and Assignments tabs
    /// Creates tab view items with emoji titles and sets up lazy loading
    private func setupTabs() {
        tabView.tabViewItems.removeAll()

        let tabData: [(identifier: String, title: String)] = [
            ("EditView", "✏️ Edit"),
            ("ScriptPrePostView", "📜 Scripts"),
            ("GroupAssignmentsView", "🖥️ Assignments")
        ]

        for data in tabData {
            let tabViewItem = NSTabViewItem(identifier: data.identifier)
            tabViewItem.label = data.title
            tabViewItem.view = nil // View will be loaded dynamically
            tabView.addTabViewItem(tabViewItem)
        }

        // Set initial tab to the first one
        tabView.selectTabViewItem(at: 0)
    }

    /// Updates the Group Assignments view controller with current app data
    /// Synchronizes package transformation state between tabs
    func updateGroupAssignmentsView() {
        // Ensure the GroupAssignmentsViewController is loaded
        if let groupVC = viewControllerCache["GroupAssignmentsView"] as? GroupAssignViewController {
            Logger.info("Updating GroupAssignmentsViewController with new transformToPkg state", category: .core, toUserDirectory: true)
            groupVC.appData?.transformToPkg = appData?.transformToPkg ?? false
        }
    }
    
    /// Checks and updates custom label visual state based on file system markers
    /// Sets button state and label color based on .custom file existence
    private func checkCustomLabel() {
        let labelFolder = "\(appData!.label)_\(appData!.guid)"
        
        let customCheckURL = AppConstants.intuneomatorManagedTitlesFolderURL
            .appendingPathComponent(labelFolder)
            .appendingPathComponent(".custom")
        
        if FileManager.default.fileExists(atPath: customCheckURL.path) {
            labelCustomLabel.textColor = .systemRed
            buttonCustomOnOff.state = .on
        } else {
            labelCustomLabel.textColor = .lightGray
            buttonCustomOnOff.state = .off
        }
    }


    /// Dynamically loads and caches view controllers for tab view items
    /// Implements lazy loading pattern to improve performance and memory usage
    /// Configures view controllers with app data if they conform to Configurable protocol
    /// - Parameter tabViewItem: The tab view item requiring a view controller
    private func loadTabViewController(for tabViewItem: NSTabViewItem) {
        guard let identifier = tabViewItem.identifier as? String else {
            Logger.warning("TabViewItem identifier is missing", category: .core, toUserDirectory: true)
            return
        }

        // Check if the view controller is already cached
        if let cachedVC = viewControllerCache[identifier] {
            tabViewItem.view = cachedVC.view
            return
        }

        // Load the view controller dynamically from storyboard
        let storyboard = NSStoryboard(name: "Main", bundle: nil)
        guard let newViewController = storyboard.instantiateController(withIdentifier: identifier) as? NSViewController else {
            Logger.error("Failed to load view controller with identifier: \(identifier)", category: .core, toUserDirectory: true)
            return
        }

        // Configure view controller with app data if it supports configuration
        if let configurableVC = newViewController as? Configurable {
            if let appItemData = appData {
                // Pass both the app data and the TabViewController reference
                configurableVC.configure(with: appItemData, parent: self)
            } else {
                Logger.warning("No appItemData provided for \(identifier)", category: .core, toUserDirectory: true)
            }
        }

        // Cache the view controller and set its view
        viewControllerCache[identifier] = newViewController
        tabViewItem.view = newViewController.view
    }
}

// MARK: - NSTabViewDelegate Extension

/// Extension implementing NSTabViewDelegate for handling tab selection events
/// Manages dynamic loading and save button state updates during tab navigation
extension TabViewController: NSTabViewDelegate {
    
    /// Called when a tab is about to be selected
    /// Triggers dynamic loading of the tab's view controller if not already cached
    /// - Parameters:
    ///   - tabView: The tab view managing the selection
    ///   - tabViewItem: The tab view item about to be selected
    public func tabView(_ tabView: NSTabView, willSelect tabViewItem: NSTabViewItem?) {
        guard let tabViewItem = tabViewItem else { return }
        loadTabViewController(for: tabViewItem)
    }

    /// Called when a tab has been selected
    /// Updates save button state based on the newly selected tab's status
    /// - Parameters:
    ///   - tabView: The tab view managing the selection
    ///   - tabViewItem: The tab view item that was selected
    public func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        updateSaveButtonState()
    }
}
