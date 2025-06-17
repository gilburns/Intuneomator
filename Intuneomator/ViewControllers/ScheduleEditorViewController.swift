//
//  ScheduleEditorViewController.swift
//  Intuneomator
//
//  Created by Gil Burns on 5/4/25.
//

import Cocoa

/// Sheet view controller for editing Launch Daemon schedules for Intuneomator automation tasks
/// Provides interface for configuring when automated tasks (automation, cleanup, label updates, updater)
/// should run using macOS Launch Daemon scheduling system
/// 
/// **Key Features:**
/// - Manages schedules for four task types: Automation, Cleanup, Label Updater, and Updater
/// - Supports daily scheduling or specific weekday scheduling
/// - Creates, updates, and removes Launch Daemon plist files via XPC service
/// - Provides visual feedback for schedule changes and validation
/// - Maintains persistent window size preferences
/// - Real-time schedule conflict detection and validation
class ScheduleEditorViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    
    // MARK: - IBOutlets
    @IBOutlet weak var buttonImage: NSButton!
    
    @IBOutlet weak var popupTaskType: NSPopUpButton!
    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var timePicker: NSDatePicker!
    @IBOutlet weak var popupWeekday: NSPopUpButton!
    
    @IBOutlet weak var buttonAdd: NSButton!
    @IBOutlet weak var buttonUpdate: NSButton!
    @IBOutlet weak var buttonDelete: NSButton!
    @IBOutlet weak var buttonSave: NSButton!
    @IBOutlet weak var buttonCancel: NSButton!
    
    @IBOutlet weak var labelCacheCleanupRule: NSTextField!
    @IBOutlet weak var labelTaskDescription: NSTextField!
    @IBOutlet weak var toggleEnabledButton: NSSwitch!
    
    // MARK: - Properties
    
    /// Launch Daemon label for the currently selected task type
    var taskLabel: String = ""
    /// Command line argument passed to the automation service
    var taskArgument: String = ""
    /// SF Symbol name for the task type icon
    var taskImageName: String = ""
    /// Human-readable description of the selected task type
    var taskDescription: String = ""
    /// Current schedule entries being edited
    var entries: [ScheduleEntry] = []
    
    /// Original schedule entries loaded from plist for change tracking
    private var originalEntries: [ScheduleEntry] = []
    /// Currently selected row index in the schedule table
    private var selectedRowIndex: Int?
    
    /// Mapping of task types to their Launch Daemon configuration
    let taskMappings: [String: (label: String, argument: String, image: String, description: String)] = [
        "Automation": ("com.gilburns.intuneomator.automation", "intune-automation", "gearshape.arrow.trianglehead.2.clockwise.rotate.90", "This schedule controls the execution of automation tasks. It is recommended that you schedule this task to run once at least once a day."),
        "Cleanup": ("com.gilburns.intuneomator.cachecleaner", "cache-cleanup", "arrow.up.trash.fill", "This schedule controls the execution of the cache and log cleanup task. It is recommended that you schedule this task to run at least once a week."),
        "Label Updater": ("com.gilburns.intuneomator.labelupdater", "label-update", "tag.square", "This schedule controls the execution of the Installomator label updater task. It is recommended that you schedule this task to run at least once a week."),
        "Updater": ("com.gilburns.intuneomator.updatecheck", "update-check", "bolt.badge.checkmark", "This schedule controls the execution of the Installomator self updater task. It is recommended that you schedule this task to run only once a week.")
    ]
    
    
    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        updateSaveButtonTitle()
        updateTaskSelection()
        getAppsToKeep()
        updateToggleButtonState()

    }
    
    override func viewWillAppear() {
        super.viewWillAppear()

        // Load the saved size or use the default size
        let defaultSize = NSSize(width: 600, height: 480)
        let savedSize = loadSavedSheetSize() ?? defaultSize

        if let sheetWindow = view.window {
            sheetWindow.setContentSize(savedSize) // Apply the saved or default size
            sheetWindow.minSize = NSSize(width: 600, height: 480) // Set minimum size
            sheetWindow.maxSize = NSSize(width: 600, height: 480) 
        }
    }

    
    /// Loads the saved sheet size from UserDefaults
    /// - Returns: Saved size if found, nil to use default size
    private func loadSavedSheetSize() -> NSSize? {
        if let sizeDict = UserDefaults.standard.dictionary(forKey: "ScheduleEditorViewSheetSize") as? [String: CGFloat],
           let width = sizeDict["width"], let height = sizeDict["height"] {
            return NSSize(width: width, height: height)
        }
        return nil
    }

    
    /// Configures the initial user interface state
    /// Sets up weekday popup, loads existing schedules, and initializes button states
    func setupUI() {
        // Populate weekday popup
        popupWeekday.removeAllItems()
        popupWeekday.addItem(withTitle: "Daily")
        // Add weekdays in the traditional week order: Sunday through Saturday
        popupWeekday.addItems(withTitles: ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"])
        
        // Load existing plist if it exists
        loadScheduleFromPlist()
        labelCacheCleanupRule.isHidden = true
        
        buttonAdd.isEnabled = true
        buttonUpdate.isEnabled = false
        buttonDelete.isEnabled = false
    }
    
    /// Retrieves and displays the number of app versions to keep for cleanup tasks
    /// Shows cache cleanup rule information for the Cleanup task type
    func getAppsToKeep() {
        XPCManager.shared.getAppsToKeep { appsToKeep in
            DispatchQueue.main.async {
                let appsToKeep = appsToKeep ?? 2
                self.labelCacheCleanupRule.stringValue = "Keeping: \(String(appsToKeep)) versions"
            }
        }
    }

    
    // MARK: - IBActions
    
    /// Adds a new schedule entry from the current picker values
    /// Creates a new ScheduleEntry and adds it to the entries array
    @IBAction func buttonAddClicked(_ sender: Any) {
        let (hour, minute, weekday) = getPickerValues()
        let newEntry = ScheduleEntry(weekday: weekday, hour: hour, minute: minute)
        entries.append(newEntry)
        tableView.reloadData()
        checkForChanges()
    }
    
    /// Updates the selected schedule entry with current picker values
    /// Modifies the existing entry at the selected index and clears selection
    @IBAction func buttonUpdateClicked(_ sender: Any) {
        guard let index = selectedRowIndex else { return }
        let (hour, minute, weekday) = getPickerValues()
        entries[index] = ScheduleEntry(weekday: weekday, hour: hour, minute: minute)
        selectedRowIndex = nil
        tableView.deselectAll(nil)
        tableView.reloadData()
        checkForChanges()
        updateButtonStates()
        updateToggleButtonState()
    }
    
    /// Deletes the selected schedule entry
    /// Removes the entry from the array and clears the selection
    @IBAction func buttonDeleteClicked(_ sender: Any) {
        let selected = tableView.selectedRow
        guard selected >= 0 && selected < entries.count else { return }

        entries.remove(at: selected)
        selectedRowIndex = nil
        tableView.deselectAll(nil)
        tableView.reloadData()
        checkForChanges()
        updateButtonStates()
        updateToggleButtonState()
    }
    
    /// Saves the current schedule to Launch Daemon plist via XPC service
    /// Creates, updates, or removes the Launch Daemon based on schedule entries
    @IBAction func buttonSaveClicked(_ sender: Any) {
        
        
        if entries.isEmpty {
            // No schedules left — remove the LaunchDaemon
            XPCManager.shared.removeScheduledTask(label: taskLabel) { success, message in
                DispatchQueue.main.async {
                    if success {
                        self.buttonSave.isEnabled = false
                    } else {
                        self.presentErrorAlert(message ?? "Failed to remove scheduled task.")
                    }
                }
            }
        } else {
            // Create or update the LaunchDaemon
            let scheduledTimes = entries.map { $0.toScheduledTime() }

            Logger.info("GUI: Sending \(scheduledTimes.count) schedule(s) to \(taskLabel)", category: .core, toUserDirectory: true)
            scheduledTimes.forEach { Logger.info("Schedule: weekday=\($0.weekday ?? -1), hour=\($0.hour), minute=\($0.minute)", category: .core, toUserDirectory: true) }

            
            XPCManager.shared.createOrUpdateScheduledTask(
                label: taskLabel,
                argument: taskArgument,
                schedules: scheduledTimes
            ) { success, message in
                DispatchQueue.main.async {
                    if success {
                        self.buttonSave.isEnabled = false
                        self.updateToggleButtonState()

                    } else {
                        self.presentErrorAlert(message ?? "Failed to save scheduled task.")
                    }
                }
            }
        }
    }
    
    
    /// Cancels schedule editing and dismisses the sheet
    /// Discards any unsaved changes
    @IBAction func buttonCancelClicked(_ sender: Any) {
        dismissSheet()
    }
    
    
    /// Handles task type selection changes
    /// Updates UI elements and loads appropriate schedule when task type changes
    @IBAction func taskTypeDidChange(_ sender: NSPopUpButton) {
        updateSaveButtonTitle()
        updateTaskSelection()
        if sender.titleOfSelectedItem == "Cleanup" {
            labelCacheCleanupRule.isHidden = false
        } else {
            labelCacheCleanupRule.isHidden = true
        }
        updateToggleButtonState()
    }
    
    /// Handles toggle switch changes to enable/disable the daemon
    @IBAction func toggleEnabledButtonClicked(_ sender: NSSwitch) {
        let isEnabled = sender.state == .on
        
        XPCManager.shared.toggleScheduledTask(label: taskLabel, enable: isEnabled) { success, message in
            DispatchQueue.main.async {
                if !success {
                    sender.state = isEnabled ? .off : .on
                    let alert = NSAlert()
                    alert.messageText = "Failed to \(isEnabled ? "enable" : "disable") task"
                    alert.informativeText = message ?? "Unknown error occurred"
                    alert.alertStyle = .warning
                    alert.runModal()
                }
            }
        }
    }
    
    
    // MARK: - Helper functions
    
    /// Dismisses the schedule editor sheet
    func dismissSheet() {
        self.view.window?.sheetParent?.endSheet(self.view.window!)
    }
    
    /// Updates the save button title to reflect the selected task type
    func updateSaveButtonTitle() {
        let saveType = popupTaskType.titleOfSelectedItem ?? ""
        buttonSave.title = "Save Schedule for \(saveType)"
    }

    /// Encodes ScheduledTime objects for XPC transmission
    /// - Parameter schedules: Array of ScheduledTime objects to encode
    /// - Returns: Encoded data or nil if encoding fails
    func encodeScheduledTimes(_ schedules: [ScheduledTime]) -> Data? {
        do {
            return try NSKeyedArchiver.archivedData(withRootObject: schedules, requiringSecureCoding: true)
        } catch {
            Logger.error("Failed to encode schedules: \(error)", category: .core, toUserDirectory: true)
            return nil
        }
    }
        
    /// Presents an error alert with the specified message
    /// - Parameter message: Error message to display
    func presentErrorAlert(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Error Saving Schedule"
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    /// Updates task properties based on the selected task type
    /// Configures label, argument, image, and description for the selected task
    func updateTaskSelection() {
        let selectedTitle = popupTaskType.titleOfSelectedItem ?? ""
        if let mapping = taskMappings[selectedTitle] {
            taskLabel = mapping.label
            taskArgument = mapping.argument
            taskImageName = mapping.image
            taskDescription = mapping.description
            
            labelTaskDescription.stringValue = taskDescription
            buttonImage.image = NSImage(systemSymbolName: taskImageName, accessibilityDescription: nil)
            
            loadScheduleFromPlist()
        }
    }
    
    /// Checks if the current schedule differs from the original
    /// Enables/disables the save button based on whether changes were made
    func checkForChanges() {
        let changed = entries.count != originalEntries.count ||
            !zip(entries, originalEntries).allSatisfy { $0.displayString() == $1.displayString() }

        buttonSave.isEnabled = changed
    }
    
    /// Extracts time and weekday values from the UI pickers
    /// - Returns: Tuple containing hour, minute, and optional weekday
    private func getPickerValues() -> (hour: Int, minute: Int, weekday: Weekday?) {
        let calendar = Calendar.current
        let selectedDate = timePicker.dateValue
        let hour = calendar.component(.hour, from: selectedDate)
        let minute = calendar.component(.minute, from: selectedDate)
        let weekdayIndex = popupWeekday.indexOfSelectedItem
        
        // Map popup index to Launch Daemon weekday values
        let weekday: Weekday?
        switch weekdayIndex {
        case 0: weekday = nil // Daily option
        case 1: weekday = .sunday    // Sunday = 7 in Launch Daemon
        case 2: weekday = .monday    // Monday = 1 in Launch Daemon  
        case 3: weekday = .tuesday   // Tuesday = 2 in Launch Daemon
        case 4: weekday = .wednesday // Wednesday = 3 in Launch Daemon
        case 5: weekday = .thursday  // Thursday = 4 in Launch Daemon
        case 6: weekday = .friday    // Friday = 5 in Launch Daemon
        case 7: weekday = .saturday  // Saturday = 6 in Launch Daemon
        default: weekday = nil
        }
        
        return (hour, minute, weekday)
    }
    
    
    /// Updates button enabled states based on table selection
    /// Enables/disables Add, Update, and Delete buttons appropriately
    private func updateButtonStates() {
        let hasSelection = (selectedRowIndex != nil)

        buttonAdd.isEnabled = !hasSelection
        buttonUpdate.isEnabled = hasSelection
        buttonDelete.isEnabled = hasSelection
    }
    
    /// Reads the Disabled state from the daemon plist file
    /// - Parameter label: The daemon label to check
    /// - Returns: True if daemon is disabled, false if enabled or if plist doesn't exist
    private func isDaemonDisabled(label: String) -> Bool {
        let daemonPath = "/Library/LaunchDaemons/\(label).plist"
        
        guard FileManager.default.fileExists(atPath: daemonPath) else {
            return false
        }
        
        do {
            let plistURL = URL(fileURLWithPath: daemonPath)
            let plistData = try Data(contentsOf: plistURL)
            guard let plistDict = try PropertyListSerialization.propertyList(from: plistData, options: [], format: nil) as? [String: Any] else {
                return false
            }
            
            return plistDict["Disabled"] as? Bool ?? false
        } catch {
            return false
        }
    }
    
    /// Updates the toggle switch state based on the current daemon's enabled/disabled status
    private func updateToggleButtonState() {
        guard !taskLabel.isEmpty else {
            toggleEnabledButton.isEnabled = false
            return
        }
        
        let daemonPath = "/Library/LaunchDaemons/\(taskLabel).plist"
        let daemonExists = FileManager.default.fileExists(atPath: daemonPath)
        
        toggleEnabledButton.isEnabled = daemonExists
        
        if daemonExists {
            let isDisabled = isDaemonDisabled(label: taskLabel)
            toggleEnabledButton.state = isDisabled ? .off : .on
        } else {
            toggleEnabledButton.state = .off
        }
    }
    
    // MARK: - Table View Data Source & Delegate
    
    /// Returns the number of schedule entries in the table
    /// - Parameter tableView: The table view requesting the count
    /// - Returns: Number of schedule entries
    func numberOfRows(in tableView: NSTableView) -> Int {
        return entries.count
    }
    
    /// Provides the view for a specific table cell
    /// - Parameters:
    ///   - tableView: The table view requesting the cell view
    ///   - tableColumn: The table column for the cell
    ///   - row: The row index for the cell
    /// - Returns: Configured table cell view
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("ScheduleCell"), owner: self) as? NSTableCellView
        cell?.textField?.stringValue = entries[row].displayString()
        return cell
    }
    
    /// Handles table view selection changes
    /// Updates button states and populates pickers with selected entry values
    /// - Parameter notification: Selection change notification
    func tableViewSelectionDidChange(_ notification: Notification) {
        let row = tableView.selectedRow
        let hasSelection = (row >= 0 && row < entries.count)

        selectedRowIndex = hasSelection ? row : nil
        buttonDelete.isEnabled = hasSelection
        buttonUpdate.isEnabled = hasSelection
        buttonAdd.isEnabled = !hasSelection

        if hasSelection {
            let selected = entries[row]
            timePicker.dateValue = Calendar.current.date(
                bySettingHour: selected.hour,
                minute: selected.minute,
                second: 0,
                of: Date()
            ) ?? Date()
            // Map weekday back to popup index
            let popupIndex: Int
            if let weekday = selected.weekday {
                switch weekday {
                case .sunday: popupIndex = 1
                case .monday: popupIndex = 2  
                case .tuesday: popupIndex = 3
                case .wednesday: popupIndex = 4
                case .thursday: popupIndex = 5
                case .friday: popupIndex = 6
                case .saturday: popupIndex = 7
                }
            } else {
                popupIndex = 0 // Daily
            }
            popupWeekday.selectItem(at: popupIndex)
        }
    }
    
    // MARK: - Schedule Persistence
    
    /// Loads existing schedule from Launch Daemon plist file
    /// Parses the plist and populates the entries array with current schedule
    func loadScheduleFromPlist() {
        let path = "/Library/LaunchDaemons/\(taskLabel).plist"
        
        // Always clear current entries before reloading
        entries.removeAll()
        
        guard let data = FileManager.default.contents(atPath: path) else {
            tableView.reloadData()
            return
        }
        
        do {
            let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any]
            if let scheduleArray = plist?["StartCalendarInterval"] as? [[String: Int]] {
                entries = scheduleArray.map { dict in
                    let weekday = dict["Weekday"].flatMap(Weekday.init(rawValue:))
                    let hour = dict["Hour"] ?? 0
                    let minute = dict["Minute"] ?? 0
                    return ScheduleEntry(weekday: weekday, hour: hour, minute: minute)
                }
            }
        } catch {
            Logger.error("Failed to load plist: \(error.localizedDescription)", category: .core, toUserDirectory: true)
        }
        
        originalEntries = entries.map { ScheduleEntry(weekday: $0.weekday, hour: $0.hour, minute: $0.minute) }
        
        checkForChanges()
        
        tableView.reloadData()
    }
}
