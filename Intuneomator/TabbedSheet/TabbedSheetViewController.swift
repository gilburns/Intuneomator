//
//  TabbedSheetViewController.swift
//  Intuneomator
//
//  Created by Gil Burns on 6/23/25.
//

import Cocoa

/// Protocol for child view controllers in the tabbed sheet
/// Allows the parent to get data from and provide data to child controllers
protocol TabbedSheetChildProtocol: AnyObject {
    /// Called when the sheet is about to be saved - child should return its current data
    func getDataForSave() -> [String: Any]?
    
    /// Called when the sheet is first presented - provides initial data to the child
    func setInitialData(_ data: [String: Any])
    
    /// Called when data from other tabs might affect this tab
    func updateFromOtherTabs(_ combinedData: [String: Any])
    
    /// Optional validation - return nil if valid, error message if invalid
    func validateData() -> String?
}

/// Reusable tabbed sheet view controller for presenting multiple related views
/// Coordinates data flow between tabs and provides unified save/cancel functionality
class TabbedSheetViewController: NSViewController {
    
    // MARK: - UI Components
    
    @IBOutlet weak var tabView: NSTabView!
    @IBOutlet weak var saveButton: NSButton!
    @IBOutlet weak var cancelButton: NSButton!
    
    // MARK: - Properties
    
    /// Array of view controllers to display as tabs
    var tabChildViewControllers: [NSViewController] = []
    
    /// Array of tab labels corresponding to the child view controllers
    var tabLabels: [String] = []
    
    /// Initial data to provide to child view controllers
    var initialData: [String: Any] = [:]
    
    /// Callback called when user saves - receives combined data from all tabs
    var saveHandler: (([String: Any]) -> Void)?
    
    /// Callback called when user cancels
    var cancelHandler: (() -> Void)?
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTabView()
        setupButtons()
        distributeInitialData()
        
        // Initialize save button state
        saveButton.isEnabled = false
        updateSaveButtonState()
    }
    
    // MARK: - Setup Methods
    
    private func setupTabView() {
        guard !tabChildViewControllers.isEmpty else {
            Logger.error("No child view controllers provided to TabbedSheetViewController", category: .core, toUserDirectory: true)
            return
        }
        
        // Clear existing tabs
        tabView.tabViewItems.removeAll()
        
        // Add child view controllers as tabs
        for (index, childVC) in tabChildViewControllers.enumerated() {
            let tabItem = NSTabViewItem(viewController: childVC)
            
            // Use provided label or fallback to index
            if index < tabLabels.count {
                tabItem.label = tabLabels[index]
            } else {
                tabItem.label = "Tab \(index + 1)"
            }
            
            tabView.addTabViewItem(tabItem)
        }
        
        // Select first tab
        if !tabView.tabViewItems.isEmpty {
            tabView.selectFirstTabViewItem(nil)
        }
    }
    
    private func setupButtons() {
        saveButton.target = self
        saveButton.action = #selector(saveButtonClicked(_:))
        
        cancelButton.target = self
        cancelButton.action = #selector(cancelButtonClicked(_:))
    }
    
    private func distributeInitialData() {
        // Provide initial data to each child that conforms to the protocol
        for childVC in tabChildViewControllers {
            if let protocolChild = childVC as? TabbedSheetChildProtocol {
                protocolChild.setInitialData(initialData)
            }
            
            // Set parent reference for change tracking
            if let scriptEditor = childVC as? ScriptEditorViewController {
                scriptEditor.parentTabViewController = self
            } else if let customAttributeScriptEditor = childVC as? CustomAttributeEditorViewController {
                customAttributeScriptEditor.parentTabViewController = self
            } else if let groupAssignment = childVC as? GroupAssignmentViewController {
                groupAssignment.parentTabbedSheetViewController = self
            }
        }
    }
    
    // MARK: - Public Configuration Methods
    
    /// Configure the tabbed sheet with child view controllers and labels
    /// - Parameters:
    ///   - children: Array of view controllers to display as tabs
    ///   - labels: Array of labels for the tabs (must match children count)
    ///   - data: Initial data to provide to child view controllers
    func configure(children: [NSViewController], labels: [String], initialData: [String: Any]) {
        self.tabChildViewControllers = children
        self.tabLabels = labels
        self.initialData = initialData
        
        // If view is already loaded, refresh the tab view
        if isViewLoaded {
            setupTabView()
            distributeInitialData()
        }
    }
    
    // MARK: - Save Button Management
    
    /// Updates the save button state based on changes in child view controllers
    func updateSaveButtonState() {
        var hasAnyChanges = false
        
        // Check if any child view controller has unsaved changes
        for childVC in tabChildViewControllers {
            var childHasChanges = false
            
            // Check using specific view controller types
            if let scriptEditor = childVC as? ScriptEditorViewController {
                childHasChanges = scriptEditor.hasUnsavedChanges
            } else if let groupAssignment = childVC as? GroupAssignmentViewController {
                childHasChanges = groupAssignment.hasUnsavedChanges
            } else if let customAttributeEditor = childVC as? CustomAttributeEditorViewController {
                childHasChanges = customAttributeEditor.hasUnsavedChanges
            }
            
            if childHasChanges {
                hasAnyChanges = true
                Logger.debug("Found unsaved changes in: \(type(of: childVC))", category: .core, toUserDirectory: true)
                break
            }
        }
        
        // Update save button state
        saveButton.isEnabled = hasAnyChanges
    }
    
    // MARK: - Data Collection and Validation
    
    private func collectDataFromAllTabs() -> [String: Any] {
        var combinedData: [String: Any] = initialData
        
        for (index, childVC) in tabChildViewControllers.enumerated() {
            if let protocolChild = childVC as? TabbedSheetChildProtocol {
                if let childData = protocolChild.getDataForSave() {
                    // Merge child data into combined data
                    for (key, value) in childData {
                        combinedData[key] = value
                    }
                }
            }
        }
        
        return combinedData
    }
    
    private func validateAllTabs() -> String? {
        for (index, childVC) in tabChildViewControllers.enumerated() {
            if let protocolChild = childVC as? TabbedSheetChildProtocol {
                if let errorMessage = protocolChild.validateData() {
                    let tabLabel = index < tabLabels.count ? tabLabels[index] : "Tab \(index + 1)"
                    return "\(tabLabel): \(errorMessage)"
                }
            }
        }
        return nil
    }
    
    private func updateTabsWithCombinedData() {
        let combinedData = collectDataFromAllTabs()
        
        for childVC in tabChildViewControllers {
            if let protocolChild = childVC as? TabbedSheetChildProtocol {
                protocolChild.updateFromOtherTabs(combinedData)
            }
        }
    }
    
    // MARK: - Actions
    
    @IBAction func saveButtonClicked(_ sender: NSButton) {
        // Validate all tabs first
        if let validationError = validateAllTabs() {
            showError(message: validationError)
            return
        }
        
        // Collect data from all tabs
        let combinedData = collectDataFromAllTabs()
        
        // Close the sheet
        dismiss(self)
        
        // Call the save handler with combined data
        saveHandler?(combinedData)
    }
    
    @IBAction func cancelButtonClicked(_ sender: NSButton) {
        // Close the sheet
        dismiss(self)
        
        // Call the cancel handler
        cancelHandler?()
    }
    
    // MARK: - Tab View Delegate
    
    func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        // Update all tabs when switching tabs (in case data from other tabs affects the current tab)
        updateTabsWithCombinedData()
    }
    
    // MARK: - Error Display
    
    private func showError(message: String) {
        let alert = NSAlert()
        alert.messageText = "Validation Error"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

// MARK: - Convenience Factory Methods

extension TabbedSheetViewController {
    
    /// Creates a configured tabbed sheet for script editing
    /// - Parameters:
    ///   - scriptData: Initial script data
    ///   - isNewScript: Whether this is a new script
    ///   - saveHandler: Called when user saves with combined data
    ///   - cancelHandler: Called when user cancels
    /// - Returns: Configured TabbedSheetViewController
    static func createScriptEditor(
        scriptData: [String: Any],
        isNewScript: Bool,
        saveHandler: @escaping ([String: Any]) -> Void,
        cancelHandler: (() -> Void)? = nil
    ) -> TabbedSheetViewController? {
        
        // Load the XIB file
        let tabbedVC = TabbedSheetViewController(nibName: "TabbedSheetViewController", bundle: nil)
        
        // Load child view controllers
        let shellStoryboard = NSStoryboard(name: "ShellScripts", bundle: nil)
        guard let editorVC = shellStoryboard.instantiateController(withIdentifier: "ScriptEditorViewController") as? ScriptEditorViewController else {
            Logger.error("Failed to load ScriptEditorViewController", category: .core, toUserDirectory: true)
            return nil
        }
        
        let groupsStoryboard = NSStoryboard(name: "GroupAssignment", bundle: nil)
        guard let groupsVC = groupsStoryboard.instantiateController(withIdentifier: "GroupAssignmentViewController") as? GroupAssignmentViewController else {
            Logger.error("Failed to load GroupAssignmentViewController", category: .core, toUserDirectory: true)
            return nil
        }
        
        // Configure the child view controllers
        var initialData = scriptData
        initialData["isNewScript"] = isNewScript
        
        // Configure the tabbed view controller
        tabbedVC.configure(
            children: [editorVC, groupsVC],
            labels: ["Script", "Groups"],
            initialData: initialData
        )
        
        tabbedVC.saveHandler = saveHandler
        tabbedVC.cancelHandler = cancelHandler
        
        return tabbedVC
    }
    
    
    
    /// Creates a configured tabbed sheet for script editing
    /// - Parameters:
    ///   - scriptData: Initial custom attribute data
    ///   - isNewScript: Whether this is a new script
    ///   - saveHandler: Called when user saves with combined data
    ///   - cancelHandler: Called when user cancels
    /// - Returns: Configured TabbedSheetViewController
    static func createCustomAttributeEditor(
        scriptData: [String: Any],
        isNewScript: Bool,
        saveHandler: @escaping ([String: Any]) -> Void,
        cancelHandler: (() -> Void)? = nil
    ) -> TabbedSheetViewController? {
        
        // Load the XIB file
        let tabbedVC = TabbedSheetViewController(nibName: "TabbedSheetViewController", bundle: nil)
        
        // Load child view controllers
        let customAttributeStoryboard = NSStoryboard(name: "CustomAttributes", bundle: nil)
        guard let editorVC = customAttributeStoryboard.instantiateController(withIdentifier: "CustomAttributeEditorViewController") as? CustomAttributeEditorViewController else {
            Logger.error("Failed to load CustomAttributeEditorViewController", category: .core, toUserDirectory: true)
            return nil
        }
        
        let groupsStoryboard = NSStoryboard(name: "GroupAssignment", bundle: nil)
        guard let groupsVC = groupsStoryboard.instantiateController(withIdentifier: "GroupAssignmentViewController") as? GroupAssignmentViewController else {
            Logger.error("Failed to load GroupAssignmentViewController", category: .core, toUserDirectory: true)
            return nil
        }
        
        // Configure the child view controllers
        var initialData = scriptData
        initialData["isNewScript"] = isNewScript
        
        // Configure the tabbed view controller
        tabbedVC.configure(
            children: [editorVC, groupsVC],
            labels: ["Custom Attribute", "Groups"],
            initialData: initialData
        )
        
        tabbedVC.saveHandler = saveHandler
        tabbedVC.cancelHandler = cancelHandler
        
        return tabbedVC
    }
}
