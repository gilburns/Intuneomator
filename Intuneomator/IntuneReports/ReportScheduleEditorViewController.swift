//
//  ReportScheduleEditorViewController.swift
//  Intuneomator
//
//  Created by Gil Burns on 7/25/25.
//

import Cocoa

/// View controller for creating and editing scheduled report configurations
/// Provides a comprehensive interface for setting up automated report generation and delivery
class ReportScheduleEditorViewController: NSViewController {
    
    // MARK: - UI Outlets
    
    // Basic Configuration
    @IBOutlet weak var fieldScheduleName: NSTextField!
    @IBOutlet weak var fieldDescription: NSTextField? // Optional - may not be connected in storyboard
    
    // Report Configuration
    @IBOutlet weak var reportTypePopup: NSPopUpButton!
    @IBOutlet weak var formatSegmentedControl: NSSegmentedControl!
    @IBOutlet weak var selectColumnsButton: NSButton!
    @IBOutlet weak var columnsStatusLabel: NSTextField!
    @IBOutlet weak var filtersContainerView: NSView!
    @IBOutlet weak var filtersScrollView: NSScrollView!
    
    // Schedule Configuration
    @IBOutlet weak var frequencyPopup: NSPopUpButton!
    @IBOutlet weak var timePicker: NSDatePicker!
    @IBOutlet weak var timeZonePopup: NSPopUpButton!
    @IBOutlet weak var dayOfWeekPopup: NSPopUpButton!
    @IBOutlet weak var dayOfMonthPopup: NSPopUpButton!
    @IBOutlet weak var startDatePicker: NSDatePicker!
    @IBOutlet weak var endDateCheckbox: NSButton!
    @IBOutlet weak var endDatePicker: NSDatePicker!
    
    // Delivery Configuration
    @IBOutlet weak var azureStoragePopup: NSPopUpButton!
    @IBOutlet weak var folderPathField: NSTextField!
    @IBOutlet weak var fileNameTemplateField: NSTextField!
    @IBOutlet weak var createLinkCheckbox: NSButton!
    @IBOutlet weak var linkExpirationField: NSTextField!
    @IBOutlet weak var linkExpirationStepper: NSStepper!
    
    // Notification Configuration
    @IBOutlet weak var enableNotificationsCheckbox: NSButton!
    @IBOutlet weak var useGlobalWebhookRadio: NSButton!
    @IBOutlet weak var useCustomWebhookRadio: NSButton!
    @IBOutlet weak var customWebhookField: NSTextField!
    @IBOutlet weak var messageTemplateTextView: NSTextView!
    
    // Actions
    @IBOutlet weak var testScheduleButton: NSButton? // Optional - may not be connected in storyboard
    @IBOutlet weak var saveButton: NSButton!
    @IBOutlet weak var cancelButton: NSButton!
    
    // Labels that need to be shown/hidden based on frequency
    @IBOutlet weak var dayOfWeekLabel: NSTextField!
    @IBOutlet weak var dayOfMonthLabel: NSTextField!
    
    // MARK: - Properties
    
    /// The scheduled report being edited (nil for new reports)
    var scheduledReport: ScheduledReport?
    
    /// Whether this is a new report or editing existing
    var isNewReport: Bool {
        return scheduledReport == nil
    }
    
    /// Current filter controls for the selected report type
    private var currentFilterControls: [String: NSControl] = [:]
    
    /// Available report types and their display names
    private var availableReportTypes: [(type: String, displayName: String)] = []
    
    /// Currently selected report type
    private var selectedReportType: String?
    
    /// Currently selected columns for the report
    private var selectedColumns: [String]?
    
    /// Callback called when save is successful
    var onSaveComplete: ((ScheduledReport) -> Void)?
    
    /// Flag to prevent validation when user is canceling
    private var isCanceling = false
    
    /// Callback called when cancel is pressed
    var onCancel: (() -> Void)?
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadAvailableReportTypes()
        populateFields()
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        let effectView = NSVisualEffectView(frame: view.bounds)
        effectView.autoresizingMask = [.width, .height]
        effectView.blendingMode = .withinWindow
        effectView.material = .windowBackground
        effectView.state = .active
        
        self.view.addSubview(effectView, positioned: .below, relativeTo: nil)
        
        // Make view accept key events for ESC handling
        view.window?.makeFirstResponder(self)
    }

    // MARK: - Setup Methods
    
    private func setupUI() {
        setupFrequencyPopup()
        setupTimePicker()
        setupTimeZonePopup()
        setupDayPopups()
        setupFormatSegmentedControl()
        setupColumnsSelection()
        setupAzureStoragePopup()
        setupDatePickers()
        setupMessageTemplate()
        setupFieldObservers()
        updateScheduleControlsVisibility()
        updateDeliveryControlsState()
        updateNotificationControlsState()
    }
    
    private func setupFrequencyPopup() {
        frequencyPopup.removeAllItems()
        for frequency in ScheduleFrequency.allCases {
            frequencyPopup.addItem(withTitle: frequency.displayName)
        }
        frequencyPopup.target = self
        frequencyPopup.action = #selector(frequencyChanged(_:))
    }
    
    private func setupTimePicker() {
        // Configure the date picker for time-only input
        timePicker.datePickerStyle = .textField
        timePicker.datePickerElements = .hourMinute
        timePicker.datePickerMode = .single
        
        // Set default time to 9:00 AM
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = 9
        components.minute = 0
        if let defaultTime = calendar.date(from: components) {
            timePicker.dateValue = defaultTime
        }
        
        // Add target for changes
        timePicker.target = self
        timePicker.action = #selector(timePickerChanged(_:))
    }
    
    private func setupTimeZonePopup() {
        timeZonePopup.removeAllItems()
        
        // Add common time zones
        let commonTimeZones = [
            "America/New_York": "Eastern Time",
            "America/Chicago": "Central Time", 
            "America/Denver": "Mountain Time",
            "America/Los_Angeles": "Pacific Time",
            "UTC": "UTC"
        ]
        
        for (identifier, displayName) in commonTimeZones {
            let item = NSMenuItem(title: displayName, action: nil, keyEquivalent: "")
            item.representedObject = identifier
            timeZonePopup.menu?.addItem(item)
        }
        
        // Select current time zone
        let currentTZ = TimeZone.current.identifier
        for (index, (identifier, _)) in commonTimeZones.enumerated() {
            if identifier == currentTZ {
                timeZonePopup.selectItem(at: index)
                break
            }
        }
    }
    
    private func setupDayPopups() {
        // Day of week
        dayOfWeekPopup.removeAllItems()
        let weekdays = Calendar.current.weekdaySymbols
        for (index, weekday) in weekdays.enumerated() {
            let item = NSMenuItem(title: weekday, action: nil, keyEquivalent: "")
            item.tag = index + 1 // Calendar uses 1-based indexing
            dayOfWeekPopup.menu?.addItem(item)
        }
        
        // Day of month
        dayOfMonthPopup.removeAllItems()
        for day in 1...31 {
            let suffix = day.ordinalSuffix
            let item = NSMenuItem(title: "\(day)\(suffix)", action: nil, keyEquivalent: "")
            item.tag = day
            dayOfMonthPopup.menu?.addItem(item)
        }
    }
    
    private func setupFormatSegmentedControl() {
        formatSegmentedControl.setLabel("CSV", forSegment: 0)
        formatSegmentedControl.setLabel("JSON", forSegment: 1)
        formatSegmentedControl.selectedSegment = 0
        formatSegmentedControl.target = self
        formatSegmentedControl.action = #selector(formatChanged(_:))
    }
    
    private func setupColumnsSelection() {
        selectColumnsButton.title = "Select Columns"
        selectColumnsButton.target = self
        selectColumnsButton.action = #selector(selectColumnsClicked(_:))
        
        updateColumnsStatus()
    }
    
    private func updateColumnsStatus() {
        guard let reportType = selectedReportType else {
            columnsStatusLabel.stringValue = "Select a report type first"
            columnsStatusLabel.textColor = .secondaryLabelColor
            selectColumnsButton.isEnabled = false
            return
        }
        
        selectColumnsButton.isEnabled = true
        
        if let selectedColumns = selectedColumns {
            let totalColumns = ReportRegistry.shared.getReportDefinition(for: reportType)?.supportedColumns.count ?? 0
            columnsStatusLabel.stringValue = "\(selectedColumns.count) of \(totalColumns) columns selected"
            columnsStatusLabel.textColor = .labelColor
        } else {
            let defaultCount = ReportRegistry.shared.getDefaultColumns(for: reportType)?.count ?? 0
            let totalColumns = ReportRegistry.shared.getReportDefinition(for: reportType)?.supportedColumns.count ?? 0
            columnsStatusLabel.stringValue = "\(defaultCount) of \(totalColumns) columns (default)"
            columnsStatusLabel.textColor = .secondaryLabelColor
        }
    }
    
    private func setupAzureStoragePopup() {
        azureStoragePopup.target = self
        azureStoragePopup.action = #selector(azureStorageSelectionChanged(_:))
        updateAzureStoragePopup()
    }
    
    private func setupDatePickers() {
        startDatePicker.dateValue = Date()
        endDatePicker.dateValue = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
        endDatePicker.isEnabled = false
        
        endDateCheckbox.target = self
        endDateCheckbox.action = #selector(endDateCheckboxChanged(_:))
        
        // Set up link expiration field action
        linkExpirationField.target = self
        linkExpirationField.action = #selector(linkExpirationFieldChanged(_:))
    }
    
    private func setupMessageTemplate() {
        messageTemplateTextView.string = NotificationConfiguration.defaultMessageTemplate
        messageTemplateTextView.font = NSFont.systemFont(ofSize: 12)
    }
    
    private func setupFieldObservers() {
        // Add observers for various fields that should enable/disable save button
        fieldScheduleName.delegate = self
        fieldDescription?.delegate = self
        folderPathField.delegate = self
        fileNameTemplateField.delegate = self
        customWebhookField.delegate = self
        // Note: timePicker uses action method instead of delegate
    }
    
    // MARK: - Data Loading
    
    private func loadAvailableReportTypes() {
        // Get available report types from ReportRegistry
        // This ensures compatibility with current and future reports
        let allReports = ReportRegistry.shared.getAllReports()
        availableReportTypes = allReports.map { ($0.type, $0.displayName) }
        
        // Populate report type popup with categories as submenus
        reportTypePopup.removeAllItems()
        
        // Add a placeholder item to show current selection
        let placeholderItem = NSMenuItem(title: "Select Report Type...", action: nil, keyEquivalent: "")
        placeholderItem.isEnabled = false
        reportTypePopup.menu?.addItem(placeholderItem)
        
        // Add separator
        reportTypePopup.menu?.addItem(NSMenuItem.separator())
        
        let categories = ReportRegistry.shared.getCategories()
        
        for category in categories {
            // Create category submenu
            let categoryMenu = NSMenu()
            let categoryMenuItem = NSMenuItem(title: category, action: nil, keyEquivalent: "")
            categoryMenuItem.submenu = categoryMenu
            
            // Add reports for this category
            let reportsInCategory = ReportRegistry.shared.getReportsForCategory(category)
            for report in reportsInCategory {
                let reportMenuItem = NSMenuItem(title: report.displayName, action: #selector(reportTypeChanged(_:)), keyEquivalent: "")
                reportMenuItem.toolTip = report.formattedTooltip()
                reportMenuItem.target = self
                reportMenuItem.representedObject = report.type // Store the report type for identification
                categoryMenu.addItem(reportMenuItem)
            }
            
            reportTypePopup.menu?.addItem(categoryMenuItem)
        }
        
        // Select the placeholder item by default
        reportTypePopup.selectItem(at: 0)
    }
    
    private func updateAzureStoragePopup() {
        azureStoragePopup.removeAllItems()
        
        XPCManager.shared.getAzureStorageConfigurationNames { availableConfigs in
            DispatchQueue.main.async {
                if availableConfigs.isEmpty {
                    self.azureStoragePopup.addItem(withTitle: "No Azure Storage configurations available")
                    self.azureStoragePopup.isEnabled = false
                } else {
                    for configName in availableConfigs {
                        self.azureStoragePopup.addItem(withTitle: configName)
                    }
                    self.azureStoragePopup.isEnabled = true
                }
                
                // Now that popup is populated, select the stored configuration if editing existing report
                self.selectStoredAzureStorageConfig()
                
                // Update link expiration validation when storage popup changes
                self.validateLinkExpirationAgainstCleanupRules()
            }
        }
    }
    
    /// Selects the stored Azure Storage configuration in the popup (for existing reports)
    private func selectStoredAzureStorageConfig() {
        guard let report = scheduledReport else { return }
        
        if let index = azureStoragePopup.itemTitles.firstIndex(of: report.delivery.azureStorageConfigName) {
            azureStoragePopup.selectItem(at: index)
        }
    }
    
    /// Validates that link expiration doesn't exceed Azure Storage cleanup rules
    private func validateLinkExpirationAgainstCleanupRules() {
        guard !isCanceling,
              azureStoragePopup.indexOfSelectedItem >= 0,
              let selectedConfigName = azureStoragePopup.titleOfSelectedItem,
              selectedConfigName != "No Azure Storage configurations available",
              createLinkCheckbox.state == .on else {
            return // No validation needed if canceling, no config selected, or links disabled
        }
        
        let requestedExpirationDays = linkExpirationField.integerValue
        
        XPCManager.shared.getNamedAzureStorageConfiguration(name: selectedConfigName) { configData in
            DispatchQueue.main.async {
                guard let config = configData,
                      let cleanupEnabled = config["cleanupEnabled"] as? Bool,
                      cleanupEnabled,
                      let maxFileAge = config["maxFileAgeInDays"] as? Int else {
                    return // No cleanup rules to validate against
                }
                
                // Validate that link expiration doesn't exceed cleanup age
                if requestedExpirationDays > maxFileAge {
                    let message = "Link expiration (\(requestedExpirationDays) days) cannot exceed Azure Storage cleanup age (\(maxFileAge) days) for configuration '\(selectedConfigName)'. Link expiration has been adjusted to \(maxFileAge) days."
                    
                    // Auto-adjust to maximum allowed
                    self.linkExpirationField.integerValue = maxFileAge
                    self.linkExpirationStepper.integerValue = maxFileAge
                    
                    // Show informative message (using success style since it's auto-corrected)
                    self.showSuccess(message)
                }
            }
        }
    }
    
    private func populateFields() {
        guard let report = scheduledReport else {
            // New report - set defaults
            fieldScheduleName.stringValue = ""
            fieldDescription?.stringValue = ""
            // Time picker defaults are set in setupTimePicker()
            folderPathField.stringValue = "reports/{reportType}/"
            fileNameTemplateField.stringValue = "{reportName}_{date}_{time}.{extension}"
            createLinkCheckbox.state = .off
            linkExpirationField.integerValue = 7
            linkExpirationField.isEnabled = false
            linkExpirationStepper.integerValue = 7
            linkExpirationStepper.isEnabled = false
            enableNotificationsCheckbox.state = .off
            useGlobalWebhookRadio.state = .on
            useGlobalWebhookRadio.isEnabled = false
            useCustomWebhookRadio.state = .off
            useCustomWebhookRadio.isEnabled = false
            return
        }
        
        // Existing report - populate from data
        fieldScheduleName.stringValue = report.name
        fieldDescription?.stringValue = report.description ?? ""
        
        // Report configuration
        selectedReportType = report.reportType
        
        // Find and set the report type display name in the placeholder item
        if let reportDef = ReportRegistry.shared.getReportDefinition(for: report.reportType),
           let placeholderItem = reportTypePopup.menu?.item(at: 0) {
            placeholderItem.title = reportDef.displayName
            reportTypePopup.selectItem(at: 0)
        }
        updateFilterControls()
        
        formatSegmentedControl.selectedSegment = report.format.lowercased() == "json" ? 1 : 0
        
        // Restore column selection
        selectedColumns = report.selectedColumns
        updateColumnsStatus()
        
        // Schedule configuration
        if let freqIndex = ScheduleFrequency.allCases.firstIndex(where: { $0.rawValue == report.schedule.frequency.rawValue }) {
            frequencyPopup.selectItem(at: freqIndex)
        }
        
        // Set time picker from timeOfDay string (HH:MM format)
        setTimePickerFromString(report.schedule.timeOfDay)
        startDatePicker.dateValue = report.schedule.startDate
        
        if let endDate = report.schedule.endDate {
            endDateCheckbox.state = .on
            endDatePicker.dateValue = endDate
            endDatePicker.isEnabled = true
        }
        
        if let dayOfWeek = report.schedule.dayOfWeek {
            dayOfWeekPopup.selectItem(withTag: dayOfWeek)
        }
        
        if let dayOfMonth = report.schedule.dayOfMonth {
            dayOfMonthPopup.selectItem(withTag: dayOfMonth)
        }
        
        // Delivery configuration (Azure Storage selection handled in selectStoredAzureStorageConfig after popup is populated)
        folderPathField.stringValue = report.delivery.folderPath
        fileNameTemplateField.stringValue = report.delivery.fileNameTemplate
        createLinkCheckbox.state = report.delivery.createShareableLink ? .on : .off
        
        if let expDays = report.delivery.linkExpirationDays {
            linkExpirationField.integerValue = expDays
            linkExpirationStepper.integerValue = expDays
        }
        
        // Notification configuration
        enableNotificationsCheckbox.state = report.notifications.enabled ? .on : .off
        
        if report.notifications.useGlobalWebhook {
            useGlobalWebhookRadio.state = .on
        } else {
            useCustomWebhookRadio.state = .on
            customWebhookField.stringValue = report.notifications.customWebhookURL ?? ""
        }
        
        messageTemplateTextView.string = report.notifications.messageTemplate ?? NotificationConfiguration.defaultMessageTemplate
        
        updateScheduleControlsVisibility()
        updateDeliveryControlsState()
        updateNotificationControlsState()
    }
    
    // MARK: - UI State Management
    
    private func updateScheduleControlsVisibility() {
        let selectedFrequency = ScheduleFrequency.allCases[frequencyPopup.indexOfSelectedItem]
        
        switch selectedFrequency {
        case .daily:
            dayOfWeekLabel.isHidden = true
            dayOfWeekPopup.isHidden = true
            dayOfMonthLabel.isHidden = true
            dayOfMonthPopup.isHidden = true
            
        case .weekly:
            dayOfWeekLabel.isHidden = false
            dayOfWeekPopup.isHidden = false
            dayOfMonthLabel.isHidden = true
            dayOfMonthPopup.isHidden = true
            
        case .monthly:
            dayOfWeekLabel.isHidden = true
            dayOfWeekPopup.isHidden = true
            dayOfMonthLabel.isHidden = false
            dayOfMonthPopup.isHidden = false
        }
    }
    
    private func updateDeliveryControlsState() {
        let createLink = createLinkCheckbox.state == .on
        linkExpirationField.isEnabled = createLink
        linkExpirationStepper.isEnabled = createLink
    }
    
    private func updateNotificationControlsState() {
        let notificationsEnabled = enableNotificationsCheckbox.state == .on
        
        useGlobalWebhookRadio.isEnabled = notificationsEnabled
        useCustomWebhookRadio.isEnabled = notificationsEnabled
        
        let useCustom = notificationsEnabled && useCustomWebhookRadio.state == .on
        customWebhookField.isEnabled = useCustom
        
        messageTemplateTextView.isEditable = notificationsEnabled
    }
    
    private func updateFilterControls() {
        // Clear existing filter controls
        currentFilterControls.removeAll()
        
        // Get selected report type
        guard let reportType = selectedReportType else {
            // Clear the container and reset scroll view if no report type
            filtersContainerView.subviews.removeAll()
            filtersContainerView.frame.size.height = 88
            filtersScrollView.documentView?.frame.size.height = 88
            return
        }
        
        // Calculate required height first, before creating controls
        let reportDef = ReportRegistry.shared.getReportDefinition(for: reportType)
        let filterCount = reportDef?.supportedFilters.count ?? 0
        let verticalSpacing: CGFloat = 28  // Matches ReportRegistry layout
        let minimumHeight: CGFloat = 88   // Original container height
        
        // Calculate rows needed (2 columns, so divide by 2 and round up)
        let rowsNeeded = filterCount > 0 ? Int(ceil(Double(filterCount) / 2.0)) : 0
        
        let contentHeight: CGFloat
        if filterCount > 0 {
            // For reports with filters: tight spacing
            let titleSpace: CGFloat = 45      // Space for title and margin above first control
            let bottomPadding: CGFloat = 5    // Minimal bottom padding
            contentHeight = CGFloat(rowsNeeded) * verticalSpacing + titleSpace + bottomPadding
        } else {
            // For reports with no filters: just show "No filters available" message centered
            contentHeight = minimumHeight
        }
        let requiredHeight = max(minimumHeight, contentHeight)
        
        // Set the container view height BEFORE creating controls
        var containerFrame = filtersContainerView.frame
        containerFrame.size.height = requiredHeight
        filtersContainerView.frame = containerFrame
        
        // Update the scroll view's document view (content size)
        if let documentView = filtersScrollView.documentView {
            var documentFrame = documentView.frame
            documentFrame.size.height = requiredHeight
            documentView.frame = documentFrame
        }
        
        // Now create filter controls with the correctly sized container
        currentFilterControls = ReportRegistry.shared.createFilterControls(for: reportType, in: filtersContainerView)
        
        // Populate existing filter values if editing
        if let report = scheduledReport {
            ReportRegistry.shared.populateFilterValues(report.filters, into: currentFilterControls, for: reportType)
        }
        
        // Notify the scroll view that content has changed
        filtersScrollView.needsDisplay = true
        filtersScrollView.reflectScrolledClipView(filtersScrollView.contentView)
        
        // Scroll to the top of the content
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let topPoint = NSPoint(x: 0, y: self.filtersContainerView.frame.height - self.filtersScrollView.contentView.frame.height)
            self.filtersScrollView.contentView.scroll(to: topPoint)
            self.filtersScrollView.reflectScrolledClipView(self.filtersScrollView.contentView)
        }
    }
    
    
    // MARK: - Actions
    
    @objc private func frequencyChanged(_ sender: NSPopUpButton) {
        updateScheduleControlsVisibility()
    }
    
    @objc private func timePickerChanged(_ sender: NSDatePicker) {
        // Time picker value changed - no additional validation needed
        // The NSDatePicker handles time validation automatically
    }
    
    @objc private func formatChanged(_ sender: NSSegmentedControl) {
        // Update file name template if it uses the default extension
        let currentTemplate = fileNameTemplateField.stringValue
        let newFormat = sender.selectedSegment == 0 ? "csv" : "json"
        
        if currentTemplate.contains("{extension}") {
            // Template already uses placeholder, no need to change
            return
        } else if currentTemplate.hasSuffix(".csv") || currentTemplate.hasSuffix(".json") {
            // Update explicit extension
            let baseName = currentTemplate.replacingOccurrences(of: ".csv", with: "").replacingOccurrences(of: ".json", with: "")
            fileNameTemplateField.stringValue = "\(baseName).{extension}"
        }
    }
    
    @objc private func reportTypeChanged(_ sender: Any) {
        // Handle selection from submenu items
        if let menuItem = sender as? NSMenuItem,
           let reportType = menuItem.representedObject as? String {
            selectedReportType = reportType
            
            // Update the placeholder item title (first item in the menu)
            if let placeholderItem = reportTypePopup.menu?.item(at: 0) {
                placeholderItem.title = menuItem.title
            }
            
            // Ensure the placeholder item remains selected
            reportTypePopup.selectItem(at: 0)
            
            updateFilterControls()
            updateColumnsStatus()
            
            // Reset column selection when report type changes
            selectedColumns = nil
        }
    }
    
    @objc private func endDateCheckboxChanged(_ sender: NSButton) {
        endDatePicker.isEnabled = sender.state == .on
    }
    
    @objc private func azureStorageSelectionChanged(_ sender: NSPopUpButton) {
        validateLinkExpirationAgainstCleanupRules()
    }
    
    @objc private func linkExpirationFieldChanged(_ sender: NSTextField) {
        // Sync field value to stepper
        linkExpirationStepper.integerValue = sender.integerValue
        validateLinkExpirationAgainstCleanupRules()
    }
    
    @IBAction func createLinkCheckboxChanged(_ sender: NSButton) {
        updateDeliveryControlsState()
        validateLinkExpirationAgainstCleanupRules()
    }
    
    @IBAction func enableNotificationsChanged(_ sender: NSButton) {
        updateNotificationControlsState()
    }
    
    @IBAction func webhookRadioChanged(_ sender: NSButton) {
        if sender == useGlobalWebhookRadio {
            useCustomWebhookRadio.state = .off
        } else {
            useGlobalWebhookRadio.state = .off
        }
        updateNotificationControlsState()
    }
    
    @IBAction func linkExpirationStepperChanged(_ sender: NSStepper) {
        linkExpirationField.integerValue = sender.integerValue
        validateLinkExpirationAgainstCleanupRules()
    }
    
    @IBAction func testScheduleClicked(_ sender: NSButton) {
        performScheduleTest()
    }
    
    @IBAction func saveClicked(_ sender: NSButton) {
        saveScheduledReport()
    }
    
    @IBAction func selectColumnsClicked(_ sender: NSButton) {
        guard let reportType = selectedReportType else {
            showAlert(title: "No Report Selected", message: "Please select a report type first.")
            return
        }
        
        guard let reportDef = ReportRegistry.shared.getReportDefinition(for: reportType) else {
            showAlert(title: "Invalid Report", message: "Selected report type is not valid.")
            return
        }
        
        let columnSelectionVC = ColumnSelectionViewController(nibName: "ColumnSelectionViewController", bundle: nil)
        
        // Use current selection or defaults as preselection
        let preselectedColumns = selectedColumns ?? ReportRegistry.shared.getDefaultColumns(for: reportType) ?? []
        columnSelectionVC.configure(reportType: reportType, reportDisplayName: reportDef.displayName, preselectedColumns: preselectedColumns)
        
        columnSelectionVC.delegate = self
        
        // Present as sheet
        presentAsSheet(columnSelectionVC)
    }
    
    @IBAction func cancelClicked(_ sender: NSButton) {
        isCanceling = true
        dismiss(self)
        onCancel?()
    }
    
    // MARK: - Validation and Saving
    
    private func saveScheduledReport() {
        guard let report = buildScheduledReport() else { return }
        
        // Validate the report
        if let validationError = ScheduledReportsManager.shared.validateScheduledReport(report) {
            showError(validationError)
            return
        }
        
        // Additional validation: Check link expiration against cleanup rules
        if report.delivery.createShareableLink, let linkExpiration = report.delivery.linkExpirationDays {
            let selectedConfigName = azureStoragePopup.titleOfSelectedItem ?? ""
            validateLinkExpirationBeforeSaving(configName: selectedConfigName, linkExpiration: linkExpiration) { [weak self] isValid in
                if isValid {
                    self?.performSave(report: report)
                } else {
                    // Error message already shown by validation method
                }
            }
            return
        }
        
        // No link expiration validation needed, proceed with save
        performSave(report: report)
    }
    
    /// Validates link expiration against cleanup rules before saving
    private func validateLinkExpirationBeforeSaving(configName: String, linkExpiration: Int, completion: @escaping (Bool) -> Void) {
        guard !configName.isEmpty && configName != "No Azure Storage configurations available" else {
            completion(true) // No config to validate against
            return
        }
        
        XPCManager.shared.getNamedAzureStorageConfiguration(name: configName) { configData in
            DispatchQueue.main.async {
                guard let config = configData,
                      let cleanupEnabled = config["cleanupEnabled"] as? Bool,
                      cleanupEnabled,
                      let maxFileAge = config["maxFileAgeInDays"] as? Int else {
                    completion(true) // No cleanup rules to validate against
                    return
                }
                
                if linkExpiration > maxFileAge {
                    let message = "Cannot save report: Link expiration (\(linkExpiration) days) exceeds Azure Storage cleanup age (\(maxFileAge) days) for configuration '\(configName)'. Please reduce the link expiration or disable cleanup for this storage configuration."
                    self.showError(message)
                    completion(false)
                } else {
                    completion(true)
                }
            }
        }
    }
    
    /// Performs the actual save operation
    private func performSave(report: ScheduledReport) {
        ScheduledReportsManager.shared.saveScheduledReport(report) { [weak self] success in
            DispatchQueue.main.async {
                if success {
                    self?.dismiss(self)
                    self?.onSaveComplete?(report)
                } else {
                    self?.showError("Failed to save scheduled report. Please check the logs for details.")
                }
            }
        }
    }
    
    private func buildScheduledReport() -> ScheduledReport? {
        // Basic validation
        let name = fieldScheduleName.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            showError("Schedule name is required")
            return nil
        }
        
        guard let reportType = selectedReportType,
              let reportDef = ReportRegistry.shared.getReportDefinition(for: reportType) else {
            showError("Please select a report type")
            return nil
        }
        
        guard azureStoragePopup.indexOfSelectedItem >= 0,
              azureStoragePopup.isEnabled else {
            showError("Please select an Azure Storage configuration")
            return nil
        }
        
        // Create or update the report
        var report = scheduledReport ?? ScheduledReport(
            name: name,
            reportType: reportType,
            reportDisplayName: reportDef.displayName,
            format: formatSegmentedControl.selectedSegment == 0 ? "csv" : "json"
        )
        
        // Update basic properties
        report.name = name
        report.description = fieldDescription?.stringValue.isEmpty == false ? fieldDescription?.stringValue : nil
        report.reportType = reportType
        report.reportDisplayName = reportDef.displayName
        report.format = formatSegmentedControl.selectedSegment == 0 ? "csv" : "json"
        
        // Extract filter values using ReportRegistry for proper API value mapping
        report.filters = ReportRegistry.shared.extractFilterValues(from: currentFilterControls, for: reportType)
        
        // Set selected columns (nil means use defaults)
        report.selectedColumns = selectedColumns
        
        // Build schedule configuration
        let selectedFrequency = ScheduleFrequency.allCases[frequencyPopup.indexOfSelectedItem]
        let selectedTimeZoneIdentifier = timeZonePopup.selectedItem?.representedObject as? String ?? TimeZone.current.identifier
        
        report.schedule = ScheduleConfiguration()
        report.schedule.frequency = selectedFrequency
        report.schedule.timeOfDay = getTimeStringFromPicker()
        report.schedule.timeZone = TimeZone(identifier: selectedTimeZoneIdentifier) ?? TimeZone.current
        report.schedule.startDate = startDatePicker.dateValue
        report.schedule.endDate = endDateCheckbox.state == .on ? endDatePicker.dateValue : nil
        
        if selectedFrequency == .weekly {
            report.schedule.dayOfWeek = dayOfWeekPopup.selectedTag()
        } else if selectedFrequency == .monthly {
            report.schedule.dayOfMonth = dayOfMonthPopup.selectedTag()
        }
        
        // Build delivery configuration
        report.delivery = DeliveryConfiguration()
        report.delivery.azureStorageConfigName = azureStoragePopup.titleOfSelectedItem ?? ""
        report.delivery.folderPath = folderPathField.stringValue
        report.delivery.fileNameTemplate = fileNameTemplateField.stringValue
        report.delivery.createShareableLink = createLinkCheckbox.state == .on
        report.delivery.linkExpirationDays = createLinkCheckbox.state == .on ? linkExpirationField.integerValue : nil
        
        // Build notification configuration
        report.notifications = NotificationConfiguration()
        report.notifications.enabled = enableNotificationsCheckbox.state == .on
        report.notifications.useGlobalWebhook = useGlobalWebhookRadio.state == .on
        report.notifications.customWebhookURL = useCustomWebhookRadio.state == .on ? customWebhookField.stringValue : nil
        report.notifications.messageTemplate = messageTemplateTextView.string
        
        // Calculate next run time
        report.nextRun = report.schedule.calculateNextRun(from: Date())
        
        // Mark as modified
        report.markAsModified()
        
        return report
    }
    
    private func performScheduleTest() {
        guard let report = buildScheduledReport() else { return }
        
        let alert = NSAlert()
        alert.messageText = "Schedule Test Results"
        
        var message = "Schedule: \(report.scheduleDescription)\n"
        let nextRunString = report.nextRun.map { 
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            return formatter.string(from: $0)
        } ?? "Unable to calculate"
        message += "Next Run: \(nextRunString)\n\n"
        
        // Test Azure Storage configuration
        XPCManager.shared.getNamedAzureStorageConfiguration(name: report.delivery.azureStorageConfigName) { configData in
            DispatchQueue.main.async {
                if let config = configData {
                    let accountName = config["accountName"] as? String ?? "Unknown"
                    let containerName = config["containerName"] as? String ?? "Unknown"
                    message += "✅ Azure Storage configuration found\n"
                    message += "Account: \(accountName)\n"
                    message += "Container: \(containerName)\n"
                } else {
                    message += "❌ Azure Storage configuration not found\n"
                }
                
                alert.informativeText = message
                alert.alertStyle = .informational
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
        }
        
        // Test notification configuration
        if report.notifications.enabled {
            if report.notifications.useGlobalWebhook {
                message += "✅ Will use global Teams webhook\n"
            } else if let customURL = report.notifications.customWebhookURL, !customURL.isEmpty {
                message += "✅ Will use custom webhook\n"
            } else {
                message += "❌ No webhook URL configured\n"
            }
        } else {
            message += "ℹ️ Notifications disabled\n"
        }
        
        // Removed - now handled in the XPC callback above
    }
    
    // MARK: - Helper Methods
    
    /// Converts time picker date to HH:MM string format
    private func getTimeStringFromPicker() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: timePicker.dateValue)
    }
    
    /// Sets time picker from HH:MM string format
    private func setTimePickerFromString(_ timeString: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        
        if let timeDate = formatter.date(from: timeString) {
            // Convert to today's date with the specified time
            let calendar = Calendar.current
            let timeComponents = calendar.dateComponents([.hour, .minute], from: timeDate)
            var todayComponents = calendar.dateComponents([.year, .month, .day], from: Date())
            todayComponents.hour = timeComponents.hour
            todayComponents.minute = timeComponents.minute
            
            if let combinedDate = calendar.date(from: todayComponents) {
                timePicker.dateValue = combinedDate
            }
        } else {
            // Fallback to 9:00 AM if parsing fails
            let calendar = Calendar.current
            var components = calendar.dateComponents([.year, .month, .day], from: Date())
            components.hour = 9
            components.minute = 0
            if let defaultTime = calendar.date(from: components) {
                timePicker.dateValue = defaultTime
            }
        }
    }
    
    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Validation Error"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    private func showSuccess(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Information"
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}


// MARK: - NSTextFieldDelegate

extension ReportScheduleEditorViewController: NSTextFieldDelegate {
    
    func controlTextDidChange(_ obj: Notification) {
        // Enable save button when fields change (basic validation could be added here)
        saveButton.isEnabled = !fieldScheduleName.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

// MARK: - ColumnSelectionDelegate

extension ReportScheduleEditorViewController: ColumnSelectionDelegate {
    
    func columnSelectionDidComplete(_ selectedColumns: [String], displayNames: [String: String]) {
        self.selectedColumns = selectedColumns
        updateColumnsStatus()
        
        Logger.info("Column selection updated for scheduled report: \(selectedColumns.count) columns selected", category: .core, toUserDirectory: true)
    }
    
    func columnSelectionDidCancel() {
        Logger.info("Column selection cancelled for scheduled report", category: .core, toUserDirectory: true)
    }
}
