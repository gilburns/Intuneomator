//
//  TabViewController.swift
//  Intuneomator
//
//  Created by Gil Burns on 1/17/25.
//

import Foundation
import Cocoa

class TabViewController: NSViewController {

    @IBOutlet weak var labelAppName: NSTextField!
    
    @IBOutlet weak var imageCloudStatus: NSImageView!

    @IBOutlet var tabView: NSTabView!
    
    @IBOutlet weak var saveButton: NSButton!
    @IBOutlet weak var cancelButton: NSButton!
    
    
    @IBOutlet weak var labelCustomLabel: NSTextField!
    @IBOutlet weak var buttonCustomOnOff: NSSwitch!
    
    // The data passed from the MainViewController
    var appData: AppInfo?

    // Names of the view controllers for each tab
    private let tabIdentifiers = [
        "EditView",
        "ScriptPrePostView",
        "GroupAssignmentsView"
    ]

    private var secondTabItem: NSTabViewItem?

    // Cache for loaded view controllers
    private var viewControllerCache: [String: NSViewController] = [:]
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        labelAppName.stringValue = "Editing: \(appData?.name ?? "Application:")"

        tabView.delegate = self
        setupTabs()
        
        secondTabItem = tabView.tabViewItems[1]
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        
        // Ensure the first tab is loaded
        if let firstTab = tabView.tabViewItems.first {
            loadTabViewController(for: firstTab)
        }

        // Preload the ScriptViewController
        if let scriptTab = tabView.tabViewItems.first(where: { $0.identifier as? String == "ScriptPrePostView" }) {
            loadTabViewController(for: scriptTab)
        }

        // Load the saved size or use the default size
        let defaultSize = NSSize(width: 820, height: 730)
        let savedSize = loadSavedSheetSize() ?? defaultSize

        if let window = view.window {
            window.setContentSize(savedSize) // Apply the saved or default size
            window.minSize = NSSize(width: 820, height: 730) // Set minimum size
//            print("Applied window size: \(savedSize)")
        }

        setCloudStatusIcon()
    }

    
    // Save the sheet size when it changes
    override func viewDidAppear() {
        super.viewDidAppear()

        checkCustomLabel()
        setToggleCustomButtonAvailability()

        // Save the sheet size when the view is dismissed
        if let window = view.window {
            saveSheetSize(window.frame.size)
//            print("Saved sheet size on dismiss: \(window.frame.size)")
        }
    }
    
    override func viewDidDisappear() {
        super.viewDidDisappear()

        // Save the sheet size when the view is dismissed
        if let window = view.window {
            saveSheetSize(window.frame.size)
//            print("Saved sheet size on dismiss: \(window.frame.size)")
        }
        
    }


    // MARK: - Save Actions
    @IBAction func saveAllTabs(_ sender: Any) {
        saveAllTabsData()
    }
    
    
    func saveAllTabsData() {
        for (_, viewController) in viewControllerCache {
            if let scriptVC = viewController as? ScriptViewController {
                // Skip saving scripts if there are validation warnings
                if scriptVC.warningLabel.isHidden {
                    scriptVC.saveMetadata()
                } else {
                    print("Script tab has validation issues. Skipping script save.")
                }
            } else if let saveableVC = viewController as? TabSaveable {
                // Save other tabs
                saveableVC.saveMetadata()
            } else {
                print("ViewController \(String(describing: viewController)) does not conform to TabSaveable.")
            }
        }
//        print("All valid tabs saved.")

        DispatchQueue.main.async { [self] in
            // Close the TabView sheet after saving
            NotificationCenter.default.post(
                name: .labelEditCompleted,
                object: nil,
                userInfo: ["label": self.appData!.label as Any, "guid": self.appData!.guid as Any]
            )
        }
        dismiss(nil)
//        print("All tabs saved and TabView sheet dismissed.")
    }

    
    func updateSaveButtonState() {
//        print("updateSaveButtonState called.")

        // Check for unsaved changes across all tabs
        let hasUnsavedChanges = viewControllerCache.values.contains { viewController in
            (viewController as? UnsavedChangesHandling)?.hasUnsavedChanges == true
        }

        // Check if the Script tab is valid
        if let scriptVC = viewControllerCache["ScriptPrePostView"] as? ScriptViewController {
            let isScriptValid = scriptVC.isValid
//            print("ScriptViewController found. isValid: \(isScriptValid)")
            saveButton.isEnabled = hasUnsavedChanges && isScriptValid
        } else {
//            print("ScriptViewController not found in viewControllerCache.")
            saveButton.isEnabled = hasUnsavedChanges
        }

//        print("Save button state updated: \(saveButton.isEnabled ? "Enabled" : "Disabled")")
    }

    // MARK: - Toggle Custom
    @IBAction func toggleCustom(_ sender: NSButton) {
        let toggleState = (sender.state == .on)
        
        let labelName = appData?.label ?? ""
        let labelGuid = appData?.guid ?? ""
        let directoryPath = "\(labelName)_\(labelGuid)"
                
        XPCManager.shared.toggleCustomLabel(directoryPath, toggleState) { success in
            if success! {
                DispatchQueue.main.async {

                    if toggleState == true {
                        self.labelCustomLabel.textColor = .systemRed
                    } else {
                        self.labelCustomLabel.textColor = .lightGray
                    }
                    NotificationCenter.default.post(
                        name: .customLabelToggled,
                        object: nil,
                        userInfo: nil)
                }
            } else {
                Logger.logUser("Toggle Custom Label Failed: \(directoryPath)")
            }
        }
        

    }
    
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
        
        if !isCustomLabelEnabled {
            buttonCustomOnOff.state = .off
            labelCustomLabel.textColor = .lightGray
        } else {
            buttonCustomOnOff.state = .on
            labelCustomLabel.textColor = .systemRed
        }
    }
    
    
    
    // MARK: - Cancel Button
    
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

    
    
    // MARK: - Alert Helper:
    func showAlert(withTitle title: String, message: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    
    // MARK: - View Size Helpers
    // Save the size to UserDefaults
    private func saveSheetSize(_ size: NSSize) {
        let sizeDict = ["width": size.width, "height": size.height]
        UserDefaults.standard.set(sizeDict, forKey: "TabViewSheetSize")
//        print("Saved sheet size: \(size)")
    }

    // Load the size from UserDefaults
    private func loadSavedSheetSize() -> NSSize? {
        if let sizeDict = UserDefaults.standard.dictionary(forKey: "TabViewSheetSize") as? [String: CGFloat],
           let width = sizeDict["width"], let height = sizeDict["height"] {
//            print("Loaded saved sheet size: \(NSSize(width: width, height: height))")
            return NSSize(width: width, height: height)
        }
//        print("No saved size found, using default.")
        return nil
    }

    
    // MARK: - Cloud Status Image
    private func setCloudStatusIcon() {
        
        let baseURL = AppConstants.intuneomatorManagedTitlesFolderURL
        let folderURL = baseURL
            .appendingPathComponent("\(appData!.label)_\(appData!.guid)")

        var labelUploadCount: Int = 0
        var cloudImageIcon: NSImage?
        let labelUploadStateURL = folderURL.appendingPathComponent(".uploaded")
        if FileManager.default.fileExists(atPath: labelUploadStateURL.path) {
            if let data = FileManager.default.contents(atPath: labelUploadStateURL.path),
               let countString = String(data: data, encoding: .utf8),
               let count = Int(countString) {
                labelUploadCount = count
            }
        }

        // Create an NSImage using SF Symbols with optional overlay
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
    
    
    // MARK: - Color Tint Symbols
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

    
    // MARK: - Tabs Helpers
    // Set up tabs
    private func setupTabs() {
        tabView.tabViewItems.removeAll()

        let tabData: [(identifier: String, title: String)] = [
            ("EditView", "✏️ Edit"),
            ("ScriptPrePostView", "📜 Scripts"),
            ("GroupAssignmentsView", "🖥️ Assignments")
        ]

//        let targetSize = NSSize(width: 24, height: 24) // Target size for tab icons
        for data in tabData {
            let tabViewItem = NSTabViewItem(identifier: data.identifier)
            tabViewItem.label = data.title // Set the custom tab title
            
//            if let image = NSImage(named: data.imageName)?.resized(to: targetSize) {
//                tabViewItem.image = image
//                print("Loaded and resized image: \(data.imageName)")
//            } else {
//                print("Failed to load or resize image: \(data.imageName)")
//            }

            tabViewItem.view = nil // View will be loaded dynamically
            tabView.addTabViewItem(tabViewItem)
        }

        // Set initial tab to the first one
        tabView.selectTabViewItem(at: 0)
    }

    
    func updateGroupAssignmentsView() {
        // Ensure the GroupAssignmentsViewController is loaded
        if let groupVC = viewControllerCache["GroupAssignmentsView"] as? GroupAssignViewController {
            print("Updating GroupAssignmentsViewController with new transformToPkg state")
            groupVC.appData?.transformToPkg = appData?.transformToPkg ?? false
//            groupVC.refreshUI()
        }
    }
    
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


    // Load the view controller dynamically for the given tabViewItem
    private func loadTabViewController(for tabViewItem: NSTabViewItem) {
        guard let identifier = tabViewItem.identifier as? String else {
            print("TabViewItem identifier is missing")
            return
        }

        // Check if the view controller is already cached
        if let cachedVC = viewControllerCache[identifier] {
//            print("Using cached view controller for \(identifier)")
            tabViewItem.view = cachedVC.view
            return
        }

//        print("Loading new view controller for \(identifier)")

        // Load the view controller dynamically
        let storyboard = NSStoryboard(name: "Main", bundle: nil)
        guard let newViewController = storyboard.instantiateController(withIdentifier: identifier) as? NSViewController else {
            print("Failed to load view controller with identifier: \(identifier)")
            return
        }

        // Pass the data and parent to the new view controller if it conforms to Configurable
        if let configurableVC = newViewController as? Configurable {
            if let appItemData = appData {
                // Pass both the app data and the TabViewController
                configurableVC.configure(with: appItemData, parent: self)
            } else {
                print("No appItemData provided for \(identifier)")
            }
        }

        // Cache and set the view
        viewControllerCache[identifier] = newViewController
//        print("ViewControllerCache updated with ViewController: \(identifier)")

        tabViewItem.view = newViewController.view
    }
}

extension TabViewController: NSTabViewDelegate {
    
    public func tabView(_ tabView: NSTabView, willSelect tabViewItem: NSTabViewItem?) {
        guard let tabViewItem = tabViewItem else { return }
//        print("Will select tab with identifier: \(tabViewItem.identifier ?? "unknown")")
        loadTabViewController(for: tabViewItem)
    }

    public func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
//        print("Did select tab with identifier: \(tabViewItem?.identifier ?? "unknown")")
        updateSaveButtonState()
    }
}
