//
//  AppCategoryManagerViewController.swift
//  Intuneomator
//
//  Created by Gil Burns on 6/30/25.
//

import Cocoa

class AppCategoryManagerViewController: NSViewController {
    // MARK: - Properties
    var categories: [[String: Any]] = []
    private var isLoading: Bool = false

    // MARK: - UI Elements
    @IBOutlet weak var activityIndicator: NSProgressIndicator!
    
    @IBOutlet weak var tableView: NSTableView!
    
    @IBOutlet weak var addButton: NSButton!
    @IBOutlet weak var editButton: NSButton!
    @IBOutlet weak var deleteButton: NSButton!
    @IBOutlet weak var refreshButton: NSButton!

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Intune App Categories"
        setupUI()
        loadCategories()
        
        // Safety check for tableView
        if let tableView = tableView {
            tableView.reloadData()
        }
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        // Verify IBOutlets are connected
        guard let tableView = tableView,
              let editButton = editButton,
              let deleteButton = deleteButton,
              let activityIndicator = activityIndicator else {
            fatalError("IBOutlets are not properly connected in Interface Builder")
        }
        
        // Configure table view
        tableView.target = self
        tableView.doubleAction = #selector(editCategory)
        
        // Initially disable edit/delete buttons
        editButton.isEnabled = false
        deleteButton.isEnabled = false
    }
    
    // MARK: - Data Loading
    private func loadCategories() {
        // Prevent concurrent loading
        guard !isLoading else {
            Logger.info("Categories already loading, skipping duplicate request", toUserDirectory: true)
            return
        }
        
        // Safety check for activityIndicator
        guard let activityIndicator = activityIndicator else {
            Logger.error("activityIndicator is nil - IBOutlet not connected", category: .core, toUserDirectory: true)
            return
        }
        
        isLoading = true
        activityIndicator.isHidden = false
        activityIndicator.startAnimation(nil)
        
                
        XPCManager.shared.fetchMobileAppCategories { [weak self] categories in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if let categories = categories {
                    // Update the categories array
                    self.categories = categories
                    
                    // Validate data structure
                    for (index, category) in categories.enumerated() {
                        Logger.info("Category [\(index)]: \(category)", toUserDirectory: true)
                    }
                    
                    // Sort categories and reload table view consistently
                    self.reloadTableData()
                    
                    // Reset selection and update button state
                    self.tableView?.deselectAll(nil)
                    self.updateButtonState()
                    
                    Logger.info("Loaded \(self.categories.count) categories", toUserDirectory: true)
                } else {
                    Logger.error("Failed to fetch mobile app categories", category: .core, toUserDirectory: true)
                    self.showAlert(title: "Error", message: "Failed to load categories from Intune")
                }
                
                // Stop activity indicator and reset loading flag
                self.activityIndicator?.stopAnimation(nil)
                self.activityIndicator?.isHidden = true
                self.isLoading = false
            }
        }

    }
    
    // Ensuring sorting consistency
    func reloadTableData() {
        sortCategories()
        
        // Light debugging - just the count and first category
        Logger.info("Sorted \(categories.count) categories. First: \(categories.first?["displayName"] as? String ?? "None")", toUserDirectory: true)
        
        tableView?.reloadData()
    }

    
    // Helper to identify system categories
    private func isSystemCategory(categoryID: String) -> Bool {
        // Default system categories can be identified by:
        // Specific IDs that match the pattern of default categories
        
        // Check for default category IDs
        let systemCategoryIDs = [
            "0720a99e-562b-4a77-83f0-9a7523fcf13e", // Other Apps
            "f1fc9fe2-728d-4867-9a72-a61e18f8c606", // Books & Reference
            "046e0b16-76ce-4b49-bf1b-1cc5bd94fb47", // Data Management
            "ed899483-3019-425e-a470-28e901b9790e", // Productivity
            "2b73ae71-12c8-49be-b462-3dae769ccd9d", // Business
            "79bc98d4-7ddf-4841-9bc1-5c84a26d7ee8", // Development & Design
            "5dcd7a90-0306-4f09-a75d-6b97a243f04e", // Photos & Media
            "f79135dc-8e41-48c1-9a59-ab9a7259c38e", // Collaboration & Social
            "981deed8-6857-4e78-a50e-c3f61d312737"  // Computer Management
        ]
        
        // Check if this is a known system category by ID
        if systemCategoryIDs.contains(categoryID) {
            return true
        }
        
        return false
    }
    
    // MARK: - Actions
    @IBAction func addButtonClicked(_ sender: NSButton) {
        addCategory()
    }
    
    @IBAction func editButtonClicked(_ sender: NSButton) {
        editCategory()
    }
    
    @IBAction func deleteButtonClicked(_ sender: NSButton) {
        deleteCategory()
    }
    
    @IBAction func refreshButtonClicked(_ sender: NSButton) {
        refreshCategories()
    }
    
    @IBAction func tableViewDoubleClicked(_ sender: NSTableView) {
        editCategory()
    }
    
    // MARK: - Button Actions
    
    @objc private func refreshCategories() {
        loadCategories()
    }
    
    @objc private func addCategory() {
        let alert = NSAlert()
        alert.messageText = "Add New Category"
        alert.informativeText = "Enter the display name for the new category:"
        
        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        alert.accessoryView = textField
        
        alert.addButton(withTitle: "Add")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn && !textField.stringValue.isEmpty {
            createCategory(name: textField.stringValue)
        }
    }
    
    @objc private func editCategory() {
        let selectedRow = tableView.selectedRow
        guard selectedRow >= 0, selectedRow < categories.count else {
            return
        }
        
        let category = categories[selectedRow]
        let categoryName = category["displayName"] as? String ?? "Unknown"
        let categoryId = category["id"] as? String ?? "Unknown"
        let isSystem = isSystemCategory(categoryID: categoryId)
        
        // Debug logging
        Logger.info("Edit attempt: Row \(selectedRow) - \(categoryName) (\(isSystem ? "System" : "Custom"))", toUserDirectory: true)
        
        // Prevent editing system categories
        if isSystem {
            showAlert(title: "Cannot Edit System Category", 
                     message: "System categories cannot be modified. Only custom categories can be edited.")
            return
        }
        
        let alert = NSAlert()
        alert.messageText = "Edit Category"
        alert.informativeText = "Update the display name for this category:"
        
        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        textField.stringValue = category["displayName"] as? String ?? ""
        alert.accessoryView = textField
        
        alert.addButton(withTitle: "Update")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn && !textField.stringValue.isEmpty {
            guard let categoryId = category["id"] as? String else {
                showAlert(title: "Error", message: "Category ID is missing")
                return
            }
            
            updateCategory(id: categoryId, name: textField.stringValue)
        }
    }
    
    @objc private func deleteCategory() {
        let selectedRow = tableView.selectedRow
        guard selectedRow >= 0, selectedRow < categories.count else {
            return
        }
        
        // Use the selectedRow to get the exact category
        let category = categories[selectedRow]
        
        // Check if this is a system category
        let isSystem = isSystemCategory(categoryID: category["id"] as? String ?? "")
        
        // Prevent deleting system categories
        if isSystem {
            showAlert(title: "Cannot Delete System Category", 
                     message: "System categories cannot be deleted. Only custom categories can be removed.")
            return
        }
        
        let alert = NSAlert()
        alert.messageText = "Delete Category"
        alert.informativeText = "Are you sure you want to delete '\(category["displayName"] ?? "unknown")'?\n\nThis action cannot be undone."
        alert.alertStyle = .warning
        
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            guard let categoryId = category["id"] as? String else {
                showAlert(title: "Error", message: "Category ID is missing")
                return
            }
            
            // Pass both the ID and the selected row index
            deleteCategory(id: categoryId, at: selectedRow)
            reloadTableData()
            
            // Maintain selection
            if !categories.isEmpty {
                let newIndex = min(selectedRow, categories.count - 1)
                tableView.selectRowIndexes(IndexSet(integer: newIndex), byExtendingSelection: false)
            }
            updateButtonState()

        }
    }
    
    // MARK: - API Operations
    private func createCategory(name: String) {
        activityIndicator?.isHidden = false
        activityIndicator?.startAnimation(nil)
        
        let categoryData = ["displayName": name]
        XPCManager.shared.createMobileAppCategory(categoryData: categoryData) { [weak self] categoryId in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if let categoryId = categoryId {
                    Logger.info("Category created successfully with ID: \(categoryId)", category: .core, toUserDirectory: true)
                    
                    // Notify other components that categories have been updated
                    self.notifyCategoryUpdate(action: "create")
                    
                    // Keep spinner running and refresh quickly
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.loadCategories()
                    }
                } else {
                    Logger.error("Failed to create category", category: .core, toUserDirectory: true)
                    
                    // Stop activity indicator
                    self.activityIndicator?.stopAnimation(nil)
                    self.activityIndicator?.isHidden = true
                    
                    self.showAlert(title: "Error", message: "Failed to create category")
                }
            }
        }
    }
    
    // Helper method to sort categories consistently
    private func sortCategories() {
        Logger.info("Sorting \(categories.count) categories alphabetically...", toUserDirectory: true)
        
        // Simple alphabetical sort by display name
        categories.sort { (a, b) -> Bool in
            let aName = a["displayName"] as? String ?? ""
            let bName = b["displayName"] as? String ?? ""
            return aName.localizedCaseInsensitiveCompare(bName) == .orderedAscending
        }
        
        Logger.info("Sorting complete. First category: \(categories.first?["displayName"] as? String ?? "None")", toUserDirectory: true)
    }
    
    private func updateCategory(id: String, name: String) {
        activityIndicator?.isHidden = false
        activityIndicator?.startAnimation(nil)
        
        
        let nameUpdate: [String: Any] = [
            "displayName": name
        ]
        XPCManager.shared.updateMobileAppCategory(
            categoryId: id,
            updatedData: nameUpdate
        ) { [weak self] success in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if success == true {
                    Logger.info("Category name updated successfully", category: .core, toUserDirectory: true)
                    
                    // Notify other components that categories have been updated
                    self.notifyCategoryUpdate(action: "update")
                    
                    // Keep spinner running and refresh quickly
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.loadCategories()
                    }
                } else if success == false {
                    Logger.error("Failed to update category name", category: .core, toUserDirectory: true)
                    // Stop spinner on failure
                    self.activityIndicator?.stopAnimation(nil)
                    self.activityIndicator?.isHidden = true
                    self.showAlert(title: "Error", message: "Failed to update category")
                } else {
                    Logger.error("XPC communication failed", category: .core, toUserDirectory: true)
                    // Stop spinner on failure
                    self.activityIndicator?.stopAnimation(nil)
                    self.activityIndicator?.isHidden = true
                    self.showAlert(title: "Error", message: "Communication failed")
                }
            }
        }
    }
    
    private func deleteCategory(id: String, at index: Int) {
        // Verify the index is still valid
        guard index >= 0, index < categories.count else {
            Logger.info("Error: Index out of bounds when attempting to delete category", toUserDirectory: true)
            showAlert(title: "Error", message: "Category selection has changed. Please try again.")
            return
        }
        
        activityIndicator?.isHidden = false
        activityIndicator?.startAnimation(nil)
        
        // Keep a local reference to the category being deleted
        let categoryToDelete = categories[index]
        let categoryName = categoryToDelete["displayName"] as? String
        
        // Safely extract categoryId with proper error handling
        guard let categoryId = categoryToDelete["id"] as? String else {
            activityIndicator?.stopAnimation(nil)
            activityIndicator?.isHidden = true
            showAlert(title: "Error", message: "Category ID is missing or invalid")
            return
        }
        
        // Always confirm before deletion
        let alert = NSAlert()
        alert.messageText = "Delete Category '\(categoryName ?? "Unknown")'"
        alert.informativeText = """
            WARNING: This will permanently delete the category and may affect app organization.
            
            This action cannot be undone. Continue?
            """
        alert.addButton(withTitle: "Delete Category")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .critical
        
        if alert.runModal() == .alertFirstButtonReturn {
            XPCManager.shared.deleteMobileAppCategory(categoryId: categoryId) { success in
                    DispatchQueue.main.async {
                        if success == true {
                            Logger.info("Category '\(categoryName ?? "Unknown")' deleted successfully", category: .core, toUserDirectory: true)
                            
                            // Notify other components that categories have been updated
                            self.notifyCategoryUpdate(action: "delete")
                            
                            // Refresh category lists and update UI
                            self.categories.remove(at: index)
                            self.reloadTableData()
                            self.updateButtonState()

                        } else if success == false {
                            Logger.error("Failed to delete category '\(categoryName ?? "Unknown")'", category: .core, toUserDirectory: true)
                            self.loadCategories()
                            self.updateButtonState()

                            // Show error to user
                        } else {
                            Logger.error("XPC communication failed during category deletion", category: .core, toUserDirectory: true)
                        }
                        
                        self.activityIndicator.stopAnimation(nil)
                        self.activityIndicator.isHidden = true
                        
                        // Disable edit/delete buttons if no selection
                        self.updateButtonState()
                        
                        // Quick refresh to update the list
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                            self?.loadCategories()
                        }
                    }
                }
            }
    }
    
    // MARK: - Helpers
    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    /// Posts a notification to inform other components that categories have been updated
    /// This ensures the AppDataManager refreshes its cached category data
    private func notifyCategoryUpdate(action: String) {
        Logger.info("Posting category update notification for action: \(action)", category: .core, toUserDirectory: true)
        NotificationCenter.default.post(
            name: .categoryManagerDidUpdateCategories,
            object: self,
            userInfo: ["action": action, "timestamp": Date()]
        )
    }
    
    private func updateButtonState() {
        let selectedRow = tableView.selectedRow
        let isRowSelected = selectedRow >= 0
        
        if isRowSelected && selectedRow < categories.count {
            let selectedCategory = categories[selectedRow]
            let categoryName = selectedCategory["displayName"] as? String ?? "Unknown"
            let categoryId = selectedCategory["id"] as? String ?? "Unknown"
            let isSystem = isSystemCategory(categoryID: categoryId)
            
            // Debug logging for button state updates
            Logger.info("Selection: Row \(selectedRow) - \(categoryName) (\(isSystem ? "System" : "Custom")), Buttons: \(!isSystem ? "Enabled" : "Disabled")", toUserDirectory: true)
            
            // Enable edit/delete only for custom categories
            editButton?.isEnabled = !isSystem
            deleteButton?.isEnabled = !isSystem
        } else {
            Logger.info("No valid selection - disabling buttons", toUserDirectory: true)
            editButton?.isEnabled = false
            deleteButton?.isEnabled = false
        }
    }
}

// MARK: - NSTableViewDataSource
extension AppCategoryManagerViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return categories.count
    }
}

// MARK: - NSTableViewDelegate
extension AppCategoryManagerViewController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let category = categories[row]
        let categoryName = category["displayName"] as? String ?? "Unknown"
        let categoryId = category["id"] as? String ?? "Unknown"
        let isSystem = isSystemCategory(categoryID: categoryId)
        
        guard let identifier = tableColumn?.identifier else {
            return nil
        }
        
        // Light debugging - only first few rows
        if identifier == NSUserInterfaceItemIdentifier("displayNameColumn") && row < 2 {
            Logger.info("Rendering row \(row): \(categoryName) (\(isSystem ? "System" : "Custom"))", toUserDirectory: true)
        }
        
        let cellIdentifier = NSUserInterfaceItemIdentifier("CellID")
        
        // Try to reuse an existing cell
        var cellView: NSTableCellView
        if let reusedCell = tableView.makeView(withIdentifier: cellIdentifier, owner: self) as? NSTableCellView {
            cellView = reusedCell
        } else {
            // Create new cell if none available for reuse
            cellView = NSTableCellView()
            cellView.identifier = cellIdentifier
            
            let textField = NSTextField()
            textField.isBezeled = false
            textField.drawsBackground = false
            textField.isEditable = false
            textField.isSelectable = true
            textField.translatesAutoresizingMaskIntoConstraints = false
            
            cellView.addSubview(textField)
            cellView.textField = textField
            
            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 2),
                textField.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -2),
                textField.centerYAnchor.constraint(equalTo: cellView.centerYAnchor)
            ])
        }
        
        // Always update the cell content regardless of whether it's reused or new
        guard let textField = cellView.textField else { return cellView }
        
        if identifier == NSUserInterfaceItemIdentifier("displayNameColumn") {
            textField.stringValue = category["displayName"] as? String ?? "Unknown"
            
            // Style system categories differently
            let isSystem = isSystemCategory(categoryID: category["id"] as? String ?? "")
            if isSystem {
                textField.textColor = .secondaryLabelColor
                textField.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
            } else {
                textField.textColor = .labelColor
                textField.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
            }
            
        } else if identifier == NSUserInterfaceItemIdentifier("idColumn") {
            textField.stringValue = category["id"] as? String ?? "Unknown"
            textField.textColor = .tertiaryLabelColor
            textField.font = NSFont.monospacedSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
            
        } else if identifier == NSUserInterfaceItemIdentifier("systemColumn") {
            let isSystem = isSystemCategory(categoryID: category["id"] as? String ?? "")
            textField.stringValue = isSystem ? "System" : "Custom"
            
            if isSystem {
                textField.textColor = .systemOrange
                textField.font = NSFont.systemFont(ofSize: NSFont.systemFontSize, weight: .medium)
            } else {
                textField.textColor = .systemBlue
                textField.font = NSFont.systemFont(ofSize: NSFont.systemFontSize, weight: .regular)
            }
        }
        
        return cellView
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        updateButtonState()
    }
}

// MARK: - Window Controller
class AppCategoryManagerWindowController: NSWindowController, NSWindowDelegate {
    convenience init() {
        let viewController = AppCategoryManagerViewController()
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = viewController
        window.title = "Intune App Categories"
        window.center()
        
        self.init(window: window)
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
        
        // Set window delegate to handle close events
        window?.delegate = self
    }
    
    // MARK: - NSWindowDelegate
    
    func windowWillClose(_ notification: Notification) {
        Logger.info("Category manager window closing - posting final category update notification", category: .core, toUserDirectory: true)
        
        // Post notification to ensure AppDataManager refreshes categories when window closes
        // This serves as a safety net in case any changes were made but notifications weren't properly sent
        NotificationCenter.default.post(
            name: .categoryManagerDidUpdateCategories,
            object: self,
            userInfo: ["action": "window_close", "timestamp": Date()]
        )
    }
}
