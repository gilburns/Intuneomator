//
//  ScheduleEditorViewController.swift
//  Intuneomator
//
//  Created by Gil Burns on 5/4/25.
//

import Cocoa


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
    
    // MARK: - Properties
    var taskLabel: String = ""
    var taskArgument: String = ""
    var taskImageName: String = ""
    var taskDescription: String = ""
    var entries: [ScheduleEntry] = []
    
    private var originalEntries: [ScheduleEntry] = []
    private var selectedRowIndex: Int?
    
    let taskMappings: [String: (label: String, argument: String, image: String, description: String)] = [
        "Automation": ("com.gilburns.intuneomator.automation", "intune-automation", "gearshape.arrow.trianglehead.2.clockwise.rotate.90", "This schedule controls the execution of automation tasks. It is recommended that you schedule this task to run once at least once a day."),
        "Cache Cleanup": ("com.gilburns.intuneomator.cachecleaner", "cache-cleanup", "arrow.down.app.fill", "This schedule controls the execution of the cache cleanup task. It is recommended that you schedule this task to run at least once a week."),
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

    
    // Load the size from UserDefaults
    private func loadSavedSheetSize() -> NSSize? {
        if let sizeDict = UserDefaults.standard.dictionary(forKey: "ScheduleEditorViewSheetSize") as? [String: CGFloat],
           let width = sizeDict["width"], let height = sizeDict["height"] {
            return NSSize(width: width, height: height)
        }
        return nil
    }

    
    func setupUI() {
        // Populate weekday popup
        popupWeekday.removeAllItems()
        popupWeekday.addItem(withTitle: "Daily")
        popupWeekday.addItems(withTitles: Weekday.allCases.map { $0.name })
        
        // Load existing plist if it exists
        loadScheduleFromPlist()
        labelCacheCleanupRule.isHidden = true
        
        buttonAdd.isEnabled = true
        buttonUpdate.isEnabled = false
        buttonDelete.isEnabled = false
    }
    
    func getAppsToKeep() {
        XPCManager.shared.getAppsToKeep { appsToKeep in
            DispatchQueue.main.async {
                let appsToKeep = appsToKeep ?? 2
                self.labelCacheCleanupRule.stringValue = "Keeping: \(String(appsToKeep)) versions"
            }
        }
    }

    
    // MARK: - IBActions
    @IBAction func buttonAddClicked(_ sender: Any) {
        let (hour, minute, weekday) = getPickerValues()
        let newEntry = ScheduleEntry(weekday: weekday, hour: hour, minute: minute)
        entries.append(newEntry)
        tableView.reloadData()
        checkForChanges()
    }
    
    @IBAction func buttonUpdateClicked(_ sender: Any) {
        guard let index = selectedRowIndex else { return }
        let (hour, minute, weekday) = getPickerValues()
        entries[index] = ScheduleEntry(weekday: weekday, hour: hour, minute: minute)
        selectedRowIndex = nil
        tableView.deselectAll(nil)
        tableView.reloadData()
        checkForChanges()
        updateButtonStates()
    }
    
    @IBAction func buttonDeleteClicked(_ sender: Any) {
        let selected = tableView.selectedRow
        guard selected >= 0 && selected < entries.count else { return }

        entries.remove(at: selected)
        selectedRowIndex = nil
        tableView.deselectAll(nil)
        tableView.reloadData()
        checkForChanges()
        updateButtonStates()
    }
    
    @IBAction func buttonSaveClicked(_ sender: Any) {
        
        
        if entries.isEmpty {
            // No schedules left — remove the LaunchDaemon
            XPCManager.shared.removeScheduledTask(label: taskLabel) { success, message in
                DispatchQueue.main.async {
                    if success {
//                        self.dismissSheet()
                        self.buttonSave.isEnabled = false
                    } else {
                        self.presentErrorAlert(message ?? "Failed to remove scheduled task.")
                    }
                }
            }
        } else {
            // Create or update the LaunchDaemon
            let scheduledTimes = entries.map { $0.toScheduledTime() }

            print("GUI: Sending \(scheduledTimes.count) schedule(s) to \(taskLabel)")
            scheduledTimes.forEach { print($0.weekday ?? -1, $0.hour, $0.minute) }

            
            XPCManager.shared.createOrUpdateScheduledTask(
                label: taskLabel,
                argument: taskArgument,
                schedules: scheduledTimes
            ) { success, message in
                DispatchQueue.main.async {
                    if success {
//                        self.dismissSheet()
                        self.buttonSave.isEnabled = false
                    } else {
                        self.presentErrorAlert(message ?? "Failed to save scheduled task.")
                    }
                }
            }
        }
    }
    
    
    @IBAction func buttonCancelClicked(_ sender: Any) {
        dismissSheet()
    }
    
    
    @IBAction func taskTypeDidChange(_ sender: NSPopUpButton) {
        updateSaveButtonTitle()
        updateTaskSelection()
        if sender.titleOfSelectedItem == "Cache Cleanup" {
            labelCacheCleanupRule.isHidden = false
        } else {
            labelCacheCleanupRule.isHidden = true
        }
    }
    
    
    // MARK: - Helper functions
    
    func encodeScheduledTimes(_ schedules: [ScheduledTime]) -> Data? {
        do {
            return try NSKeyedArchiver.archivedData(withRootObject: schedules, requiringSecureCoding: true)
        } catch {
            print("❌ Failed to encode schedules: \(error)")
            return nil
        }
    }
    
    func dismissSheet() {
        self.view.window?.sheetParent?.endSheet(self.view.window!)
    }
    
    func updateSaveButtonTitle() {
        let saveType = popupTaskType.titleOfSelectedItem ?? ""
        buttonSave.title = "Save Schedule for \(saveType)"
    }
    
    func presentErrorAlert(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Error Saving Schedule"
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    func updateTaskSelection() {
        let selectedTitle = popupTaskType.titleOfSelectedItem ?? ""
        if let mapping = taskMappings[selectedTitle] {
            taskLabel = mapping.label
            taskArgument = mapping.argument
            taskImageName = mapping.image
            taskDescription = mapping.description
//            print("taskLabel: \(taskLabel)")
//            print("taskArgument: \(taskArgument)")
            
            labelTaskDescription.stringValue = taskDescription
            buttonImage.image = NSImage(systemSymbolName: taskImageName, accessibilityDescription: nil)

            
            loadScheduleFromPlist()
        }
    }
    
    func checkForChanges() {
        let changed = entries.count != originalEntries.count ||
            !zip(entries, originalEntries).allSatisfy { $0.displayString() == $1.displayString() }

        buttonSave.isEnabled = changed
    }
    
    private func getPickerValues() -> (hour: Int, minute: Int, weekday: Weekday?) {
        let calendar = Calendar.current
        let selectedDate = timePicker.dateValue
        let hour = calendar.component(.hour, from: selectedDate)
        let minute = calendar.component(.minute, from: selectedDate)
        let weekdayIndex = popupWeekday.indexOfSelectedItem
        let weekday = Weekday(rawValue: weekdayIndex)
        return (hour, minute, weekday)
    }
    
    
    private func updateButtonStates() {
        let hasSelection = (selectedRowIndex != nil)

        buttonAdd.isEnabled = !hasSelection
        buttonUpdate.isEnabled = hasSelection
        buttonDelete.isEnabled = hasSelection
    }
    
    // MARK: - Table View
    func numberOfRows(in tableView: NSTableView) -> Int {
        return entries.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("ScheduleCell"), owner: self) as? NSTableCellView
        cell?.textField?.stringValue = entries[row].displayString()
        return cell
    }
    
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
            popupWeekday.selectItem(at: selected.weekday?.rawValue ?? 0)
        }
    }
    
    // MARK: - Load Existing Schedule
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
            print("Failed to load plist: \(error.localizedDescription)")
        }
        
        originalEntries = entries.map { ScheduleEntry(weekday: $0.weekday, hour: $0.hour, minute: $0.minute) }
        
        checkForChanges()
        
        tableView.reloadData()
    }
}
