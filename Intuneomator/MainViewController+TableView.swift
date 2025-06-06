//
//  MainViewController+TableView.swift
//  Intuneomator
//
//  Created by Gil Burns on 3/11/25.
//

import Cocoa

/**
 * MainViewController+TableView
 *
 * This extension implements the table view data source and delegate protocols for displaying
 * app automation data in the main interface. It handles table view configuration, cell population,
 * and user interactions.
 *
 * ## Responsibilities:
 * - Provide row count and cell views for the table
 * - Configure individual cells with app data and icons
 * - Handle table selection changes
 * - Manage keyboard navigation and search
 * - Support double-click actions
 * - Validate automation readiness and display status
 *
 * ## Table Columns:
 * - **IconColumn**: App icon from label folder
 * - **ValidationColumn**: Automation readiness status
 * - **CloudStatusColumn**: Upload count indicator
 * - **NameColumn**: Application name
 * - **ArchColumn**: Architecture (arm64/i386/Universal)
 * - **DeliveryColumn**: Delivery method (DMG/PKG/LOB)
 * - **LabelColumn**: Installomator label name
 * - **SourceColumn**: Source type and download URL
 * - **TeamIDColumn**: Expected developer Team ID
 */
// MARK: - Table View Data Source and Delegate
extension MainViewController: NSTableViewDataSource, NSTableViewDelegate {
    
    /**
     * Returns the number of rows to display in the table view.
     * 
     * Uses the filtered app data count to support search functionality.
     * When no search is active, this equals the full app data count.
     * 
     * - Parameter tableView: The table view requesting the row count
     * - Returns: Number of apps to display after applying current filter
     */
    func numberOfRows(in tableView: NSTableView) -> Int {
        return filteredAppData.count
    }

    /**
     * Configures and returns a cell view for the specified table column and row.
     * 
     * This method handles the complex logic of populating each table cell with appropriate
     * data, icons, and visual indicators. It manages:
     * - Loading app icons and fallback handling
     * - Creating composite cloud status icons with upload counts
     * - Determining architecture and delivery method displays
     * - Validation status indicators
     * - Tooltip configuration for additional context
     * 
     * - Parameter tableView: The table view requesting the cell
     * - Parameter tableColumn: The specific column being populated
     * - Parameter row: The row index in the filtered data
     * - Returns: Configured NSTableCellView or nil if configuration fails
     * 
     * ## Performance Considerations:
     * - Uses validation cache to avoid repeated file system checks
     * - Lazy loads metadata only when needed
     * - Reuses cell views provided by the table view
     */
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let item = filteredAppData[row]

        guard let columnIdentifier = tableColumn?.identifier.rawValue else { return nil }

        // Ensure the cell view exists
        guard let tableColumn = tableColumn,
              let cell = tableView.makeView(withIdentifier: tableColumn.identifier, owner: self) as? NSTableCellView else {
            return nil
        }

        // Construct the folder path for validation
        let baseURL = AppConstants.intuneomatorManagedTitlesFolderURL
        let folderURL = baseURL
            .appendingPathComponent("\(item.label)_\(item.guid)")
        // Icon for label automation title
        let labelIconURL = folderURL.appendingPathComponent("\(item.label).png")
        
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
        let overlaySize = NSSize(width: 16.5, height: 16.5)
        let overlaySizeNumber = NSSize(width: 16, height: 16)
        let overlayOrigin = NSPoint(x: 6.5, y: 3.5)

        let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .light)

        if let tintedBase = tintedSymbolImage(named: "cloud", color: tintColor, size: baseSize, config: config),
           let tintedOverlay = tintedSymbolImage(named: symbolName, color: tintColorOverlay, size: overlaySize, config: config),
            let tintedNumber = tintedSymbolImage(named: symbolNumber, color: tintColorNumber, size: overlaySizeNumber, config: config) {

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
            Logger.logApp("Could not create cloud icon", logType: MainViewController.logType)
        }
        
        var metadata: Metadata!
        // Load metadata.json
        let labelMetaDataURL = folderURL
            .appendingPathComponent("metadata.json")
        do {
            let data = try Data(contentsOf: labelMetaDataURL)
            metadata = try JSONDecoder().decode(Metadata.self, from: data)
        } catch {
            Logger.logApp("Could not load metadata for row \(row)", logType: MainViewController.logType)
        }
        
        // determine Arch string
        var archString: String = ""
        var deployAsArch = 0
        if titleIsDualPlatform(forTable: row) {
            deployAsArch = metadata.deployAsArchTag

            if deployAsArch == 0 {
                archString = "arm64"
            } else if metadata.deployAsArchTag == 1 {
                archString = "i386"
            } else {
                archString = "Universal"
            }
            
        } else {
            archString = "Universal"
        }

        let deploymentType = metadata.deploymentTypeTag
        

        // Check the cache first
        let isValid: Bool
        if let cachedResult = validationCache[folderURL.path] {
            isValid = cachedResult
        } else {
            // Perform validation and cache the result
            isValid = AutomationCheck.validateFolder(at: folderURL.path)
            validationCache[folderURL.path] = isValid
        }
        var readyState: String?
        var iconImage: NSImage!
        // Load the appropriate icon based on validation
        if isValid {
            readyState = String("Ready for Automation")
            iconImage = AutomationStatusImage.Ready.image
        }
        else {
            readyState = String("Not Ready for Automation")
            iconImage = AutomationStatusImage.NotReady.image
        }

        switch columnIdentifier {
        case "IconColumn":
            // Load the icon
            if let icon = NSImage(contentsOfFile: labelIconURL.path) {
                cell.imageView?.image = icon
                cell.toolTip = "\(URL(fileURLWithPath: item.labelIcon).lastPathComponent)"
            } else {
                let fallbackIconPath = Bundle.main.path(forResource: "app_icon", ofType: "png") ?? ""
                cell.imageView?.image = NSImage(contentsOfFile: fallbackIconPath)
                cell.toolTip = "Failed to load icon"
            }
        case "ValidationColumn":
            if let icon = iconImage {
                cell.imageView?.image = icon
                cell.toolTip = readyState
            }
        case "CloudStatusColumn":
            if let icon = cloudImageIcon {
                cell.imageView?.image = icon
                cell.toolTip = "\(labelUploadCount)"
            }
        case "NameColumn":
            cell.textField?.stringValue = item.name
            cell.toolTip = readyState
        case "ArchColumn":
            cell.textField?.stringValue = archString
            cell.toolTip = readyState
        case "DeliveryColumn":
            let iconResult = iconForItemType(item.type, deploymentType)
            cell.imageView?.image = iconResult.0
            if let toolTipText = iconResult.1 {
                cell.toolTip = toolTipText as String
            }
        case "LabelColumn":
            cell.textField?.stringValue = item.label
            cell.toolTip = "Tracking ID: \(item.guid)"
        case "SourceColumn":
            cell.textField?.stringValue = item.type
            cell.toolTip = item.downloadURL
        case "TeamIDColumn":
            cell.textField?.stringValue = item.expectedTeamID
        default:
            cell.textField?.stringValue = ""
        }

        return cell
    }

    
    /**
     * Handles table view selection changes to update UI state.
     * 
     * Enables or disables the edit and remove buttons based on whether
     * a row is currently selected. This prevents actions from being
     * performed when no app is selected.
     * 
     * - Parameter notification: Selection change notification from the table view
     */
    func tableViewSelectionDidChange(_ notification: Notification) {
        let hasSelection = tableView.selectedRow >= 0
        editButton.isEnabled = hasSelection
        removeButton.isEnabled = hasSelection
    }
    
    /**
     * Determines if an app supports dual-platform (Universal/Intel/ARM) deployment.
     * 
     * Checks for the presence of both standard and Intel-specific plist files
     * to determine if the app has been configured for multiple architectures.
     * 
     * - Parameter row: The table row index to check
     * - Returns: true if both standard and Intel plist files exist
     * 
     * ## File Structure for Dual Platform:
     * ```
     * labelname_guid/
     *   ├── labelname.plist        (ARM64/Universal version)
     *   └── labelname_i386.plist   (Intel version)
     * ```
     * 
     * When dual platform support is detected, the architecture column will
     * show the specific deployment target based on metadata settings.
     */
    func titleIsDualPlatform(forTable row: Int) -> Bool {
        let label = filteredAppData[row].label
        let guid = filteredAppData[row].guid
        
        let labelX86PlistPath = AppConstants.intuneomatorManagedTitlesFolderURL
            .appendingPathComponent("\(label)_\(guid)", isDirectory: true)
            .appendingPathComponent("\(label)_i386.plist", isDirectory: true)
        
        let labelPlistPath = AppConstants.intuneomatorManagedTitlesFolderURL
            .appendingPathComponent("\(label)_\(guid)", isDirectory: true)
            .appendingPathComponent("\(label).plist", isDirectory: true)
        
        return FileManager.default.fileExists(atPath: labelX86PlistPath.path) &&
        FileManager.default.fileExists(atPath: labelPlistPath.path)
    }
    
    // MARK: - User Interaction Handlers
    
    /**
     * Handles double-click events on table rows.
     * 
     * Double-clicking any row opens the edit interface for that app,
     * providing a quick way to access app configuration without using
     * the edit button or context menu.
     * 
     * - Parameter sender: The object that triggered the double-click event
     */
    @objc func handleTableViewDoubleClick(_ sender: Any?) {
        guard tableView.selectedRow >= 0 else { return }
        editAppItem(self)
    }


    /**
     * Handles keyboard input for quick table navigation.
     * 
     * Implements typeahead functionality allowing users to quickly navigate
     * to table rows by typing the first few characters of an app name.
     * 
     * - Parameter event: The keyboard event containing the pressed key
     * 
     * ## Behavior:
     * - Escape key: Passes through to default handler (e.g., cancel search)
     * - Other keys: Accumulate in search buffer for name matching
     * - Timer resets buffer after 1 second of inactivity
     * - Matches against app name using prefix matching
     * - Automatically selects and scrolls to matching row
     * 
     * ## Search Logic:
     * - Case-insensitive prefix matching on app names
     * - Uses original appData (not filtered) for consistent behavior
     * - Selects first match found in alphabetical order
     */
    override func keyDown(with event: NSEvent) {
        guard let characters = event.characters else { return }

        // Check if the Escape key was pressed
        if event.keyCode == 53 { // 53 is the key code for Escape
            // Pass the event to the next responder (e.g., default behavior)
            super.keyDown(with: event)
            return
        }

        // Append to the search buffer
        searchBuffer += characters.lowercased()

        // Invalidate any existing timer
        searchTimer?.invalidate()

        // Set a timer to clear the buffer after a short delay
        searchTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
            self?.searchBuffer = ""
        }

        // Search for a matching row
        if let index = appData.firstIndex(where: { $0.name.hasPrefix(searchBuffer) }) {
            tableView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
            tableView.scrollRowToVisible(index)
        }
    }
}

