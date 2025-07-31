//
//  ReportRegistry.swift
//  Intuneomator
//
//  Created by Gil Burns on 7/25/25.
//

import Foundation
import AppKit

/// Centralized registry for all available Intune reports
/// Provides metadata, filter definitions, and validation for report generation
class ReportRegistry {
    
    // MARK: - Singleton
    static let shared = ReportRegistry()
    private init() {
        loadReportDefinitions()
    }
    
    // MARK: - Data Structures
    
    /// Defines a filter parameter for a report
    struct FilterDefinition {
        let key: String
        let displayName: String
        let type: FilterType
        let isRequired: Bool
        let options: [String]? // For dropdown/selection filters
        let optionValues: [String: String]? // Maps display options to API values
        let placeholder: String? // For text input filters
        
        enum FilterType {
            case text
            case dropdown
            case boolean
            case applicationId
            case deviceId
            case userId
            case date
        }
        
        init(key: String, displayName: String, type: FilterType, isRequired: Bool = false, 
             options: [String]? = nil, optionValues: [String: String]? = nil, placeholder: String? = nil) {
            self.key = key
            self.displayName = displayName
            self.type = type
            self.isRequired = isRequired
            self.options = options
            self.optionValues = optionValues
            self.placeholder = placeholder
        }
        
        /// Gets the API value for a display option
        func getAPIValue(for displayOption: String) -> String {
            return optionValues?[displayOption] ?? displayOption
        }
    }
    
    /// Defines a column that can be included in report output
    struct ColumnDefinition {
        let key: String
        let displayName: String
        let isDefault: Bool // Whether this column is included by default
        
        init(key: String, displayName: String, isDefault: Bool = false) {
            self.key = key
            self.displayName = displayName
            self.isDefault = isDefault
        }
    }
    
    /// Complete definition of a report type
    struct ReportDefinition {
        let type: String
        let displayName: String
        let description: String
        let category: String
        let intuneConsolePath: String? // Path to find this report in Intune Console
        let supportedFilters: [FilterDefinition]
        let supportedColumns: [ColumnDefinition]
        let requiredParameters: [String] // Keys of filters that are required
        let supportsCSV: Bool
        let supportsJSON: Bool
        
        init(type: String, displayName: String, description: String, category: String, 
             intuneConsolePath: String? = nil, supportedFilters: [FilterDefinition] = [], supportedColumns: [ColumnDefinition] = [],
             requiredParameters: [String] = [], supportsCSV: Bool = true, supportsJSON: Bool = true) {
            self.type = type
            self.displayName = displayName
            self.description = description
            self.category = category
            self.intuneConsolePath = intuneConsolePath
            self.supportedFilters = supportedFilters
            self.supportedColumns = supportedColumns
            self.requiredParameters = requiredParameters
            self.supportsCSV = supportsCSV
            self.supportsJSON = supportsJSON
        }
        
        /// Validates that all required parameters are provided
        func validateParameters(_ parameters: [String: String]) -> String? {
            for requiredParam in requiredParameters {
                guard let value = parameters[requiredParam], !value.isEmpty else {
                    let filter = supportedFilters.first { $0.key == requiredParam }
                    let displayName = filter?.displayName ?? requiredParam
                    return "Required parameter '\(displayName)' is missing or empty"
                }
            }
            return nil
        }
        
        /// Gets the filter definition for a given key
        func getFilterDefinition(for key: String) -> FilterDefinition? {
            return supportedFilters.first { $0.key == key }
        }
        
        /// Creates a formatted tooltip combining description and console path
        func formattedTooltip() -> String {
            var tooltip = description
            
            if let consolePath = intuneConsolePath {
                tooltip += "\n\nIntune Console Location:\n\(consolePath)"
            }
            
            return tooltip
        }
    }
    
    // MARK: - Properties
    
    private var reports: [String: ReportDefinition] = [:]
    
    // MARK: - Public Methods
    
    /// Gets all available reports
    func getAllReports() -> [ReportDefinition] {
        return Array(reports.values).sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }
    
    /// Gets reports for a specific category
    func getReportsForCategory(_ category: String) -> [ReportDefinition] {
        return reports.values.filter { $0.category == category }.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }
    
    /// Gets all available categories
    func getCategories() -> [String] {
        let categories = Set(reports.values.map { $0.category })
        return Array(categories).sorted()
    }
    
    /// Gets a specific report definition
    func getReportDefinition(for type: String) -> ReportDefinition? {
        return reports[type]
    }
    
    /// Gets a list of report types and display names (for compatibility with existing code)
    func getReportTypesAndNames() -> [(type: String, displayName: String)] {
        return getAllReports().map { ($0.type, $0.displayName) }
    }
    
    /// Validates parameters for a specific report type
    func validateReportParameters(_ parameters: [String: String], for reportType: String) -> String? {
        guard let report = getReportDefinition(for: reportType) else {
            return "Unknown report type: \(reportType)"
        }
        return report.validateParameters(parameters)
    }
    
    /// Creates filter controls dynamically based on report definition
    /// Returns a dictionary mapping filter keys to UI controls
    func createFilterControls(for reportType: String, in containerView: NSView) -> [String: NSControl] {
        guard let report = getReportDefinition(for: reportType) else {
            return [:]
        }
        
        // Clear existing subviews
        for subview in containerView.subviews {
            subview.removeFromSuperview()
        }
        
        var controls: [String: NSControl] = [:]
        let filters = report.supportedFilters
        
        // For scroll view compatibility, position absolutely from the bottom (y=0) upward
        // Calculate total required height first
        let controlHeight: CGFloat = 22
        let controlWidth: CGFloat = 120
        let labelWidth: CGFloat = 110  // Increased for longer display names
        let labelControlSpacing: CGFloat = 10  // More space between label and control
        let verticalSpacing: CGFloat = 28
        let columnSpacing: CGFloat = 280
        let leftColumnX: CGFloat = 10
        let rightColumnX: CGFloat = leftColumnX + columnSpacing
        
        // Calculate how many rows we need (2 columns)
        let filtersPerColumn = Int(ceil(Double(filters.count) / 2.0))
        
        let contentHeight: CGFloat
        if filters.count > 0 {
            // For reports with filters: tight spacing
            let titleSpace: CGFloat = 45  // Space for title and margin above first control
            let bottomPadding: CGFloat = 5  // Minimal bottom padding
            contentHeight = CGFloat(filtersPerColumn) * verticalSpacing + titleSpace + bottomPadding
        } else {
            // For reports with no filters: use container height for proper centering
            contentHeight = containerView.frame.height
        }
        
        // Position title/message based on filter availability
        let titleY = contentHeight - 20
        if filters.count > 0 {
            let filtersTitle = NSTextField(labelWithString: "Filters:")
            filtersTitle.frame = NSRect(x: 10, y: titleY, width: 80, height: 18)
            filtersTitle.font = NSFont.boldSystemFont(ofSize: 12)
            filtersTitle.textColor = NSColor.labelColor
            containerView.addSubview(filtersTitle)
        } else {
            // Show "No filters available" message centered
            let noFiltersLabel = NSTextField(labelWithString: "No filters available for this report")
            noFiltersLabel.frame = NSRect(x: 10, y: contentHeight / 2 - 9, width: 300, height: 18)
            noFiltersLabel.font = NSFont.systemFont(ofSize: 11)
            noFiltersLabel.textColor = NSColor.secondaryLabelColor
            containerView.addSubview(noFiltersLabel)
        }
        
        // First control starts below the title
        let firstControlY = titleY - 25
        
        
        for (index, filter) in filters.enumerated() {
            let isLeftColumn = index < filtersPerColumn
            let columnIndex = isLeftColumn ? index : index - filtersPerColumn
            let xPosition = isLeftColumn ? leftColumnX : rightColumnX
            let yPosition = firstControlY - CGFloat(columnIndex) * verticalSpacing
            let controlY = yPosition + 2  // Align controls slightly higher than labels
            
            var control: NSControl?
            
            switch filter.type {
            case .dropdown:
                let controlX = xPosition + labelWidth + labelControlSpacing
                let popup = NSPopUpButton(frame: NSRect(x: controlX, y: controlY, width: controlWidth, height: controlHeight))
                popup.controlSize = .small
                popup.font = NSFont.systemFont(ofSize: 11)
                
                // Add options
                if let options = filter.options {
                    for option in options {
                        popup.addItem(withTitle: option)
                    }
                }
                
                control = popup
                
            case .text, .applicationId, .deviceId, .userId:
                let controlX = xPosition + labelWidth + labelControlSpacing
                let textField = NSTextField(frame: NSRect(x: controlX, y: controlY, width: controlWidth, height: controlHeight))
                textField.controlSize = .small
                textField.font = NSFont.systemFont(ofSize: 11)
                textField.placeholderString = filter.placeholder ?? filter.displayName
                
                control = textField
                
            case .boolean:
                let checkbox = NSButton(checkboxWithTitle: filter.displayName, target: nil, action: nil)
                checkbox.frame = NSRect(x: xPosition, y: controlY, width: controlWidth + labelWidth, height: controlHeight)
                checkbox.controlSize = .small
                checkbox.font = NSFont.systemFont(ofSize: 11)
                
                control = checkbox
                
            case .date:
                let controlX = xPosition + labelWidth + labelControlSpacing
                let datePicker = NSDatePicker(frame: NSRect(x: controlX, y: controlY, width: controlWidth, height: controlHeight))
                datePicker.controlSize = .small
                datePicker.font = NSFont.systemFont(ofSize: 11)
                datePicker.datePickerStyle = .textField
                datePicker.datePickerElements = .yearMonthDay
                
                control = datePicker
            }
            
            if let control = control {
                // Add label for non-checkbox controls (label goes before control)
                if filter.type != .boolean {
                    let labelText = filter.displayName + (filter.isRequired ? " *:" : ":")
                    let label = NSTextField(labelWithString: labelText)
                    label.frame = NSRect(x: xPosition, y: yPosition + 2, width: labelWidth, height: 18)
                    label.font = NSFont.systemFont(ofSize: 10)
                    label.textColor = filter.isRequired ? NSColor.systemRed : NSColor.labelColor
                    label.alignment = .right // Right-align labels for better visual connection to controls
                    containerView.addSubview(label)
                }
                
                containerView.addSubview(control)
                controls[filter.key] = control
            }
        }
        
        return controls
    }
    
    /// Extracts filter values from UI controls, applying API value mapping
    func extractFilterValues(from controls: [String: NSControl], for reportType: String) -> [String: String] {
        guard let report = getReportDefinition(for: reportType) else {
            return [:]
        }
        
        var filters: [String: String] = [:]
        
        for (key, control) in controls {
            guard let filterDef = report.getFilterDefinition(for: key) else { continue }
            
            var value: String?
            
            switch control {
            case let popup as NSPopUpButton:
                let selectedTitle = popup.titleOfSelectedItem ?? ""
                if selectedTitle != "All" && !selectedTitle.isEmpty {
                    // Apply API value mapping if available
                    value = filterDef.getAPIValue(for: selectedTitle)
                }
                
            case let textField as NSTextField:
                let text = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty {
                    value = text
                }
                
            case let checkbox as NSButton:
                if checkbox.state == .on {
                    value = "true"
                }
                
            case let datePicker as NSDatePicker:
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                value = formatter.string(from: datePicker.dateValue)
                
            default:
                break
            }
            
            if let value = value {
                filters[key] = value
            }
        }
        
        return filters
    }
    
    /// Builds an OData filter string from filter parameters
    func buildODataFilter(from filters: [String: String], for reportType: String) -> String? {
        guard let report = getReportDefinition(for: reportType) else { return nil }
        
        var filterComponents: [String] = []
        
        for (key, value) in filters {
            guard !value.isEmpty && value != "All",
                  let filterDef = report.getFilterDefinition(for: key) else { continue }
            
            // Apply API value mapping if available
            let apiValue = filterDef.getAPIValue(for: value)
            
            // Build filter component based on filter type
            switch filterDef.type {
            case .text:
                // Text filters use 'contains' for partial matching
//                filterComponents.append("contains(\(key),'\(apiValue)')")
                filterComponents.append("(\(key) eq '\(apiValue)')")
            case .applicationId, .deviceId, .userId:
                // ID filters use exact equality, not partial matching
                filterComponents.append("(\(key) eq '\(apiValue)')")
            case .dropdown:
                // Dropdown filters use exact equality
                filterComponents.append("(\(key) eq '\(apiValue)')")
            case .boolean:
                // Boolean filters
                let boolValue = apiValue.lowercased() == "true"
                filterComponents.append("(\(key) eq \(boolValue))")
            case .date:
                // Date filters (need more info on the format and logic to fully implement)
                filterComponents.append("(\(key) eq '\(apiValue)')")
            }
        }
        
        return filterComponents.isEmpty ? nil : filterComponents.joined(separator: " and ")
    }
    
    /// Gets default columns for a report type
    func getDefaultColumns(for reportType: String) -> [String]? {
        guard let report = getReportDefinition(for: reportType) else { return nil }
        
        let defaultColumns = report.supportedColumns
            .filter { $0.isDefault }
            .map { $0.key }
        
        return defaultColumns.isEmpty ? nil : defaultColumns
    }
    
    /// Gets all available columns for a report type
    func getAllColumns(for reportType: String) -> [String]? {
        guard let report = getReportDefinition(for: reportType) else { return nil }
        
        return report.supportedColumns.map { $0.key }
    }
    
    /// Populates filter controls with existing values
    func populateFilterValues(_ filters: [String: String], into controls: [String: NSControl], for reportType: String) {
        guard let report = getReportDefinition(for: reportType) else { return }
        
        for (key, value) in filters {
            guard let control = controls[key],
                  let filterDef = report.getFilterDefinition(for: key) else { continue }
            
            switch control {
            case let popup as NSPopUpButton:
                // For dropdown filters, we need to find the display value that maps to the API value
                var displayValue = value
                
                // Check if we need to reverse-lookup from API value to display value
                if let optionValues = filterDef.optionValues {
                    if let foundDisplayValue = optionValues.first(where: { $0.value == value })?.key {
                        displayValue = foundDisplayValue
                    }
                }
                
                // Select the item
                if let item = popup.menu?.items.first(where: { $0.title == displayValue }) {
                    popup.select(item)
                }
                
            case let textField as NSTextField:
                textField.stringValue = value
                
            case let checkbox as NSButton:
                checkbox.state = (value.lowercased() == "true") ? .on : .off
                
            case let datePicker as NSDatePicker:
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                if let date = formatter.date(from: value) {
                    datePicker.dateValue = date
                }
                
            default:
                break
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// Loads all report definitions
    private func loadReportDefinitions() {
        
        // MARK: - Application Management Reports
        
        reports["AllAppsList"] = ReportDefinition(
            type: "AllAppsList",
            displayName: "All Apps List",
            description: "List of all applications managed by Intune",
            category: "Application Management",
            intuneConsolePath: "Apps > All apps",
            supportedFilters: [
            ],
            supportedColumns: [
                ColumnDefinition(key: "AppIdentifier", displayName: "Application ID", isDefault: true),
                ColumnDefinition(key: "Assigned", displayName: "Assigned", isDefault: true),
                ColumnDefinition(key: "DateCreated", displayName: "Date Created", isDefault: true),
                ColumnDefinition(key: "Description", displayName: "Description", isDefault: true),
                ColumnDefinition(key: "Developer", displayName: "Developer", isDefault: true),
                ColumnDefinition(key: "ExpirationDate", displayName: "Expiration Date", isDefault: true),
                ColumnDefinition(key: "FeaturedApp", displayName: "Featured App", isDefault: true),
                ColumnDefinition(key: "LastModified", displayName: "Last Modified", isDefault: true),
                ColumnDefinition(key: "MoreInformationURL", displayName: "More Information URL", isDefault: true),
                ColumnDefinition(key: "Name", displayName: "Name", isDefault: true),
                ColumnDefinition(key: "Notes", displayName: "Notes", isDefault: true),
                ColumnDefinition(key: "Owner", displayName: "Owner", isDefault: true),
                ColumnDefinition(key: "Platform", displayName: "Platform", isDefault: true),
                ColumnDefinition(key: "PrivacyInformationURL", displayName: "Privacy Information URL", isDefault: true),
                ColumnDefinition(key: "Publisher", displayName: "Publisher", isDefault: true),
                ColumnDefinition(key: "Status", displayName: "Status", isDefault: true),
                ColumnDefinition(key: "StoreURL", displayName: "Store URL", isDefault: true),
                ColumnDefinition(key: "Type", displayName: "Type", isDefault: true),
                ColumnDefinition(key: "Version", displayName: "Version", isDefault: true)
            ]
        )
        
        reports["AppInstallStatusAggregate"] = ReportDefinition(
            type: "AppInstallStatusAggregate",
            displayName: "App Install Status Aggregate",
            description: "Aggregated view of application installation status across devices",
            category: "Application Management",
            intuneConsolePath: "Under Apps > Monitor > App install status",
            supportedFilters: [
                FilterDefinition(key: "Platform", displayName: "Platform", type: .dropdown,
                               options: ["All", "Android", "iOS", "macOS", "Windows"]),
                FilterDefinition(key: "FailedDevicePercentage", displayName: "Failed Device Percentage", type: .text,
                               placeholder: "Enter percentage threshold")
            ],
            supportedColumns: [
                ColumnDefinition(key: "AppPlatform", displayName: "Application Platform", isDefault: true),
                ColumnDefinition(key: "ApplicationId", displayName: "Application Id", isDefault: true),
                ColumnDefinition(key: "AppVersion", displayName: "Application Version", isDefault: true),
                ColumnDefinition(key: "DisplayName", displayName: "Display Name", isDefault: true),
                ColumnDefinition(key: "FailedDeviceCount", displayName: "Failed Device Count", isDefault: true),
                ColumnDefinition(key: "FailedDevicePercentage", displayName: "Failed Device Percentage", isDefault: true),
                ColumnDefinition(key: "FailedUserCount", displayName: "Failed User Count", isDefault: true),
                ColumnDefinition(key: "InstalledDeviceCount", displayName: "Installed Device Count", isDefault: true),
                ColumnDefinition(key: "InstalledUserCount", displayName: "Installed User Count", isDefault: true),
                ColumnDefinition(key: "NotApplicableDeviceCount", displayName: "Not Applicable Device Count", isDefault: true),
                ColumnDefinition(key: "NotApplicableUserCount", displayName: "Not Applicable User Count", isDefault: true),
                ColumnDefinition(key: "NotInstalledDeviceCount", displayName: "Not Installed Device Count", isDefault: true),
                ColumnDefinition(key: "NotInstalledUserCount", displayName: "Not Installed User Count", isDefault: true),
                ColumnDefinition(key: "PendingInstallDeviceCount", displayName: "Pending Install Device Count", isDefault: true),
                ColumnDefinition(key: "PendingInstallUserCount", displayName: "Pending Install User Count", isDefault: true),
                ColumnDefinition(key: "Platform", displayName: "Platform", isDefault: true),
                ColumnDefinition(key: "Publisher", displayName: "Publisher", isDefault: true)
            ]
        )
        
        reports["AppInvAggregate"] = ReportDefinition(
            type: "AppInvAggregate",
            displayName: "App Inventory Aggregate",
            description: "Aggregated view of installed applications across all devices",
            category: "Application Management",
            intuneConsolePath: "Under Apps > Monitor > Discovered apps > Export",
            supportedFilters: [
            ],
            supportedColumns: [
                ColumnDefinition(key: "ApplicationId", displayName: "Application Id", isDefault: true),
                ColumnDefinition(key: "ApplicationKey", displayName: "Application Key", isDefault: true),
                ColumnDefinition(key: "ApplicationName", displayName: "Application Name", isDefault: true),
                ColumnDefinition(key: "ApplicationPublisher", displayName: "Application Publisher", isDefault: true),
                ColumnDefinition(key: "ApplicationShortVersion", displayName: "Application Short Version", isDefault: true),
                ColumnDefinition(key: "ApplicationVersion", displayName: "Application Version", isDefault: true),
                ColumnDefinition(key: "DeviceCount", displayName: "Device Count", isDefault: true),
                ColumnDefinition(key: "Platform", displayName: "Platform", isDefault: true)
            ]
        )
        
        reports["AppInvByDevice"] = ReportDefinition(
            type: "AppInvByDevice",
            displayName: "App Inventory By Device",
            description: "Application inventory for a specific device",
            category: "Application Management",
            intuneConsolePath: "Under Devices > All Devices > Device > Discovered Apps",
            supportedFilters: [
                FilterDefinition(key: "DeviceId", displayName: "Device ID", type: .deviceId, isRequired: true,
                               placeholder: "Enter device ID (required)")
            ],
            supportedColumns: [
                ColumnDefinition(key: "ApplicationId", displayName: "Application Id", isDefault: true),
                ColumnDefinition(key: "ApplicationKey", displayName: "Application Key", isDefault: true),
                ColumnDefinition(key: "ApplicationName", displayName: "Application Name", isDefault: true),
                ColumnDefinition(key: "ApplicationPublisher", displayName: "Application Publisher", isDefault: true),
                ColumnDefinition(key: "ApplicationShortVersion", displayName: "Application Short Version", isDefault: true),
                ColumnDefinition(key: "ApplicationVersion", displayName: "Application Version", isDefault: true),
                ColumnDefinition(key: "DeviceId", displayName: "Device Id", isDefault: true),
                ColumnDefinition(key: "DeviceName", displayName: "Device Name", isDefault: true),
                ColumnDefinition(key: "EmailAddress", displayName: "Email Address", isDefault: true),
                ColumnDefinition(key: "OSDescription", displayName: "OSDescription", isDefault: true),
                ColumnDefinition(key: "OSVersion", displayName: "OSVersion", isDefault: true),
                ColumnDefinition(key: "Platform", displayName: "Platform", isDefault: true),
                ColumnDefinition(key: "UserId", displayName: "User Id", isDefault: true),
                ColumnDefinition(key: "UserName", displayName: "User Name", isDefault: true)
            ],
            requiredParameters: ["DeviceId"]
        )
        
        reports["AppInvRawData"] = ReportDefinition(
            type: "AppInvRawData",
            displayName: "App Inventory Raw Data",
            description: "Detailed raw data of all installed applications on devices",
            category: "Application Management",
            intuneConsolePath: "Under Apps > Monitor > Discovered apps > Export",
            supportedFilters: [
                FilterDefinition(key: "ApplicationName", displayName: "Application Name", type: .text,
                               placeholder: "Enter application name"),
                FilterDefinition(key: "ApplicationPublisher", displayName: "Application Publisher", type: .text,
                               placeholder: "Enter publisher name"),
                FilterDefinition(key: "Platform", displayName: "Platform", type: .dropdown,
                               options: ["All", "Windows", "MacOS", "IOS", "AndroidWorkProfile", "AndroidFullyManagedDedicated", "AndroidDeviceAdministrator", "Other"]),
                FilterDefinition(key: "DeviceName", displayName: "Device Name", type: .text,
                               placeholder: "Enter device name"),
                FilterDefinition(key: "OSDescription", displayName: "OS Description", type: .text,
                               placeholder: "Enter OS description"),
                FilterDefinition(key: "UserName", displayName: "User Name", type: .text,
                               placeholder: "Enter user name"),
                FilterDefinition(key: "EmailAddress", displayName: "Email Address", type: .text,
                               placeholder: "Enter email address")
            ],
            supportedColumns: [
                ColumnDefinition(key: "ApplicationKey", displayName: "Application Key", isDefault: true),
                ColumnDefinition(key: "ApplicationName", displayName: "Application Name", isDefault: true),
                ColumnDefinition(key: "ApplicationPublisher", displayName: "Application Publisher", isDefault: true),
                ColumnDefinition(key: "ApplicationShortVersion", displayName: "Application Short Version", isDefault: true),
                ColumnDefinition(key: "ApplicationVersion", displayName: "Application Version", isDefault: true),
                ColumnDefinition(key: "DeviceId", displayName: "Device Id", isDefault: true),
                ColumnDefinition(key: "DeviceName", displayName: "Device Name", isDefault: true),
                ColumnDefinition(key: "EmailAddress", displayName: "Email Address", isDefault: true),
                ColumnDefinition(key: "OSDescription", displayName: "OS Description", isDefault: true),
                ColumnDefinition(key: "OSVersion", displayName: "OS Version", isDefault: true),
                ColumnDefinition(key: "Platform", displayName: "Platform", isDefault: true),
                ColumnDefinition(key: "UserId", displayName: "User Id", isDefault: true),
                ColumnDefinition(key: "UserName", displayName: "User Name", isDefault: true)
            ]
        )
        
        reports["CatalogAppsUpdateList"] = ReportDefinition(
            type: "CatalogAppsUpdateList",
            displayName: "Catalog Apps Update List",
            description: "Enterprise App Catalog apps with updates",
            category: "Application Management",
            intuneConsolePath: "Under Apps > Monitor > Enterprise App Catalog apps with updates",
            supportedFilters: [
            ],
            supportedColumns: [
                ColumnDefinition(key: "ApplicationId", displayName: "Application Id", isDefault: true),
                ColumnDefinition(key: "ApplicationName", displayName: "Application Name", isDefault: true),
                ColumnDefinition(key: "CurrentAppVersion", displayName: "Current App Version", isDefault: true),
                ColumnDefinition(key: "CurrentRevisionId", displayName: "Current Revision Id", isDefault: true),
                ColumnDefinition(key: "IsSuperseded", displayName: "Is Superseded", isDefault: true),
                ColumnDefinition(key: "LatestAvailableVersion", displayName: "Latest Available Version", isDefault: true),
                ColumnDefinition(key: "LatestRevisionId", displayName: "Latest Revision Id", isDefault: true),
                ColumnDefinition(key: "Publisher", displayName: "Publisher", isDefault: true),
                ColumnDefinition(key: "UpdateAvailable", displayName: "Update Available", isDefault: true),
                ColumnDefinition(key: "UpdateEligible", displayName: "Update Eligible", isDefault: true)
            ]
        )
        
        reports["DependentAppsInstallStatus"] = ReportDefinition(
            type: "DependentAppsInstallStatus",
            displayName: "Dependent Apps Install Status",
            description: "Dependent Application Install Status",
            category: "Application Management",
            intuneConsolePath: "Under Apps > All Apps > select the dependent app > Device install status",
            supportedFilters: [
            ],
            supportedColumns: [
                ColumnDefinition(key: "ApplicationId", displayName: "Application Id", isDefault: true),
                ColumnDefinition(key: "AppVersion", displayName: "App Version", isDefault: true),
                ColumnDefinition(key: "DeviceId", displayName: "Device Id", isDefault: true),
                ColumnDefinition(key: "DisplayName", displayName: "Display Name", isDefault: true),
                ColumnDefinition(key: "ErrorCode", displayName: "Error Code", isDefault: true),
                ColumnDefinition(key: "InstallState", displayName: "Install State", isDefault: true),
                ColumnDefinition(key: "InstallStateDetail", displayName: "Install State Detail", isDefault: true),
                ColumnDefinition(key: "LastModifiedDateTime", displayName: "Last Modified Date Time", isDefault: true),
                ColumnDefinition(key: "Relationship", displayName: "Relationship", isDefault: true),
                ColumnDefinition(key: "Replaced", displayName: "Replaced", isDefault: true),
                ColumnDefinition(key: "SourceIds", displayName: "Source Ids", isDefault: true),
                ColumnDefinition(key: "UserId", displayName: "User Id", isDefault: true),
                ColumnDefinition(key: "UserPrincipalName", displayName: "User Principal Name", isDefault: true)
            ]
        )

        reports["DeviceInstallStatusByApp"] = ReportDefinition(
            type: "DeviceInstallStatusByApp",
            displayName: "Device Install Status By App",
            description: "See device install status by application",
            category: "Application Management",
            intuneConsolePath: "Under Apps > All Apps > Select an individual app",
            supportedFilters: [
                FilterDefinition(key: "ApplicationId", displayName: "Application Id", type: .applicationId, isRequired: true, placeholder: "Enter application ID"),
                FilterDefinition(key: "AppInstallState", displayName: "App Install State", type: .dropdown,
                options: ["All", "Installed", "Not Installed", "Error", "Unknown"]),
                FilterDefinition(key: "HexErrorCode", displayName: "Hex Error Code", type: .text, placeholder: "Enter error code")
            ],
            supportedColumns: [
                ColumnDefinition(key: "AppInstallState", displayName: "App Install State", isDefault: true),
                ColumnDefinition(key: "AppInstallStateDetails", displayName: "App Install State Details", isDefault: true),
                ColumnDefinition(key: "ApplicationId", displayName: "Application Id", isDefault: true),
                ColumnDefinition(key: "AppVersion", displayName: "App Version", isDefault: true),
                ColumnDefinition(key: "AssignmentFilterIdsExist", displayName: "Assignment Filter Ids Exist", isDefault: true),
                ColumnDefinition(key: "DeviceId", displayName: "Device Id", isDefault: true),
                ColumnDefinition(key: "DeviceName", displayName: "Device Name", isDefault: true),
                ColumnDefinition(key: "ErrorCode", displayName: "Error Code", isDefault: true),
                ColumnDefinition(key: "HexErrorCode", displayName: "Hex Error Code", isDefault: true),
                ColumnDefinition(key: "InstallState", displayName: "Install State", isDefault: true),
                ColumnDefinition(key: "InstallStateDetail", displayName: "Install State Detail", isDefault: true),
                ColumnDefinition(key: "LastModifiedDateTime", displayName: "Last Modified Date Time", isDefault: true),
                ColumnDefinition(key: "Platform", displayName: "Platform", isDefault: true),
                ColumnDefinition(key: "UserId", displayName: "User Id", isDefault: true),
                ColumnDefinition(key: "UserName", displayName: "User Name", isDefault: true),
                ColumnDefinition(key: "UserPrincipalName", displayName: "User Principal Name", isDefault: true)
            ],
            requiredParameters: ["ApplicationId"]
        )

        reports["UserInstallStatusAggregateByApp"] = ReportDefinition(
            type: "UserInstallStatusAggregateByApp",
            displayName: "User Install Status Aggregate By App",
            description: "See user install status by application",
            category: "Application Management",
            intuneConsolePath: "Under Apps > All Apps > Select an individual app",
            supportedFilters: [
                FilterDefinition(key: "ApplicationId", displayName: "Application Id", type: .applicationId, isRequired: true, placeholder: "Enter application ID")
            ],
            supportedColumns: [
                ColumnDefinition(key: "ApplicationId", displayName: "Application Id", isDefault: true),
                ColumnDefinition(key: "FailedCount", displayName: "Failed Count", isDefault: true),
                ColumnDefinition(key: "InstalledCount", displayName: "Installed Count", isDefault: true),
                ColumnDefinition(key: "NotApplicableCount", displayName: "Not Applicable Count", isDefault: true),
                ColumnDefinition(key: "NotInstalledCount", displayName: "Not Installed Count", isDefault: true),
                ColumnDefinition(key: "PendingInstallCount", displayName: "Pending Install Count", isDefault: true),
                ColumnDefinition(key: "UserId", displayName: "User Id", isDefault: true),
                ColumnDefinition(key: "UserName", displayName: "User Name", isDefault: true),
                ColumnDefinition(key: "UserPrincipalName", displayName: "User Principal Name", isDefault: true)
            ],
            requiredParameters: ["ApplicationId"]
        )


        // MARK: - Device Enrollment Reports
        
        reports["AutopilotV1DeploymentStatus"] = ReportDefinition(
            type: "AutopilotV1DeploymentStatus",
            displayName: "Autopilot V1 Deployment Status",
            description: "Status  of Autopilot V1 Deployments",
            category: "Device Enrollment",
            intuneConsolePath: "Under Devices > Windows > Enrollment > Windows Autopilot",
            supportedFilters: [
            ],
            supportedColumns: [
                ColumnDefinition(key: "AccountSetupDuration", displayName: "Account Setup Duration", isDefault: true),
                ColumnDefinition(key: "AutopilotProfileName", displayName: "Autopilot Profile Name", isDefault: true),
                ColumnDefinition(key: "DeploymentDuration", displayName: "Deployment Duration", isDefault: true),
                ColumnDefinition(key: "DeploymentEndDateTime", displayName: "Deployment End Date Time", isDefault: true),
                ColumnDefinition(key: "DeploymentStartDateTime", displayName: "Deployment Start Date Time", isDefault: true),
                ColumnDefinition(key: "DeploymentState", displayName: "Deployment State", isDefault: true),
                ColumnDefinition(key: "DeploymentTotalDuration", displayName: "Deployment Total Duration", isDefault: true),
                ColumnDefinition(key: "DeviceId", displayName: "Device Id", isDefault: true),
                ColumnDefinition(key: "DeviceName", displayName: "Device Name", isDefault: true),
                ColumnDefinition(key: "DeviceRegisteredDateTime", displayName: "Device Registered Date Time", isDefault: true),
                ColumnDefinition(key: "DeviceSerialNumber", displayName: "Device Serial Number", isDefault: true),
                ColumnDefinition(key: "DeviceSetupDuration", displayName: "Device Setup Duration", isDefault: true),
                ColumnDefinition(key: "DeviceSetupStatus", displayName: "Device Setup Status", isDefault: true),
                ColumnDefinition(key: "EnrollmentDateTime", displayName: "Enrollment Date Time", isDefault: true),
                ColumnDefinition(key: "EnrollmentMethod", displayName: "Enrollment Method", isDefault: true),
                ColumnDefinition(key: "EnrollmentStatus", displayName: "Enrollment Status", isDefault: true),
                ColumnDefinition(key: "ESPPolicyId", displayName: "ESPPolicy Id", isDefault: true),
                ColumnDefinition(key: "ESPPolicyName", displayName: "ESPPolicy Name", isDefault: true),
                ColumnDefinition(key: "EspDeviceSetupFailureDetails", displayName: "Esp Device Setup Failure Details", isDefault: true),
                ColumnDefinition(key: "EspUserSetupFailureDetails", displayName: "Esp User Setup Failure Details", isDefault: true),
                ColumnDefinition(key: "FailureDetails", displayName: "Failure Details", isDefault: true),
                ColumnDefinition(key: "FailureReason", displayName: "Failure Reason", isDefault: true),
                ColumnDefinition(key: "OS", displayName: "OS", isDefault: true),
                ColumnDefinition(key: "OSVersion", displayName: "OSVersion", isDefault: true),
                ColumnDefinition(key: "UPN", displayName: "UPN", isDefault: true),
                ColumnDefinition(key: "UserId", displayName: "User Id", isDefault: true),
                ColumnDefinition(key: "UserSetupStatus", displayName: "User Setup Status", isDefault: true)
            ]
        )

        reports["AutopilotV2DeploymentStatus"] = ReportDefinition(
            type: "AutopilotV2DeploymentStatus",
            displayName: "Autopilot V2 Deployment Status",
            description: "Status  of Autopilot V2 Deployments",
            category: "Device Enrollment",
            intuneConsolePath: "Under Devices > Windows > Enrollment > Windows Autopilot",
            supportedFilters: [
            ],
            supportedColumns: [
                ColumnDefinition(key: "CurrentProvisioningPhase", displayName: "Current Provisioning Phase", isDefault: true),
                ColumnDefinition(key: "DeploymentDurationTimeInSeconds", displayName: "Deployment Duration Time In Seconds", isDefault: true),
                ColumnDefinition(key: "DeploymentStatus", displayName: "Deployment Status", isDefault: true),
                ColumnDefinition(key: "DeviceId", displayName: "Device Id", isDefault: true),
                ColumnDefinition(key: "DeviceName", displayName: "Device Name", isDefault: true),
                ColumnDefinition(key: "EnrollmentTimeInUtc", displayName: "Enrollment Time In Utc", isDefault: true),
                ColumnDefinition(key: "Phase", displayName: "Phase", isDefault: true),
                ColumnDefinition(key: "ResultCode", displayName: "Result Code", isDefault: true),
                ColumnDefinition(key: "SerialNumber", displayName: "Serial Number", isDefault: true),
                ColumnDefinition(key: "UPN", displayName: "UPN", isDefault: true)
            ]
        )

        reports["AutopilotV2DeploymentStatusDetailedAppInfo"] = ReportDefinition(
            type: "AutopilotV2DeploymentStatusDetailedAppInfo",
            displayName: "Autopilot V2 Deployment Status Detailed App Info",
            description: "Status  of Autopilot V2 with detailed application information",
            category: "Device Enrollment",
            intuneConsolePath: "Under Devices > Windows > Enrollment > Windows Autopilot",
            supportedFilters: [
            ],
            supportedColumns: [
                ColumnDefinition(key: "ApplicationId", displayName: "Application Id", isDefault: true),
                ColumnDefinition(key: "ApplicationName", displayName: "Application Name", isDefault: true),
                ColumnDefinition(key: "AppType", displayName: "App Type", isDefault: true),
                ColumnDefinition(key: "DeviceId", displayName: "Device Id", isDefault: true),
                ColumnDefinition(key: "IsAdminSelected", displayName: "Is Admin Selected", isDefault: true),
                ColumnDefinition(key: "PolicyInstallStatus", displayName: "Policy Install Status", isDefault: true)
            ]
        )

        reports["AutopilotV2DeploymentStatusDetailedScriptInfo"] = ReportDefinition(
            type: "AutopilotV2DeploymentStatusDetailedScriptInfo",
            displayName: "Autopilot V2 Deployment Status Detailed Script Info",
            description: "Status  of Autopilot V2 with detailed script information",
            category: "Device Enrollment",
            intuneConsolePath: "Under Devices > Windows > Enrollment > Windows Autopilot",
            supportedFilters: [
            ],
            supportedColumns: [
                ColumnDefinition(key: "DeviceId", displayName: "Device Id", isDefault: true),
                ColumnDefinition(key: "DisplayName", displayName: "Display Name", isDefault: true),
                ColumnDefinition(key: "PolicyId", displayName: "Policy Id", isDefault: true),
                ColumnDefinition(key: "PolicyInstallStatus", displayName: "Policy Install Status", isDefault: true)
            ]
        )
        
        reports["DeviceEnrollmentFailures"] = ReportDefinition(
            type: "DeviceEnrollmentFailures",
            displayName: "Device Enrollment Failures",
            description: "See device with enrollment failures",
            category: "Device Enrollment",
            intuneConsolePath: "Under Devices > Device onboarding > Enrollment > Monitor",
            supportedFilters: [
                FilterDefinition(key: "EnrollmentFailureDateTime", displayName: "Enrollment Failure Date Time", type: .text),
                FilterDefinition(key: "EnrollmentMethod", displayName: "Enrollment Method", type: .text),
                FilterDefinition(key: "FailureReason", displayName: "Failure Reason", type: .text),
                FilterDefinition(key: "OS", displayName: "OS", type: .text),
                FilterDefinition(key: "UserId", displayName: "User Id", type: .text)
            ],
            supportedColumns: [
                ColumnDefinition(key: "EnrollmentFailureDateTime", displayName: "Enrollment Failure Date Time", isDefault: true),
                ColumnDefinition(key: "EnrollmentMethod", displayName: "Enrollment Method", isDefault: true),
                ColumnDefinition(key: "FailureGuid", displayName: "Failure Guid", isDefault: true),
                ColumnDefinition(key: "FailureReason", displayName: "Failure Reason", isDefault: true),
                ColumnDefinition(key: "OS", displayName: "OS", isDefault: true),
                ColumnDefinition(key: "OSVersion", displayName: "OSVersion", isDefault: true),
                ColumnDefinition(key: "UPN", displayName: "UPN", isDefault: true),
                ColumnDefinition(key: "UserId", displayName: "User Id", isDefault: true)
            ]
        )

        reports["EnrollmentActivity"] = ReportDefinition(
            type: "EnrollmentActivity",
            displayName: "Enrollment Activity",
            description: "See device enrollments",
            category: "Device Enrollment",
            intuneConsolePath: "Under Dashboard > Device enrollmentand/or Intune enrolled devices",
            supportedFilters: [
                FilterDefinition(key: "EnrollmentDateTime", displayName: "Enrollment Date Time", type: .text),
                FilterDefinition(key: "EnrollmentMethod", displayName: "Enrollment Method", type: .text),
                FilterDefinition(key: "FailureReason", displayName: "Failure Reason", type: .text),
                FilterDefinition(key: "OS", displayName: "OS", type: .text),
                FilterDefinition(key: "UserId", displayName: "User Id", type: .text)
            ],
            supportedColumns: [
                ColumnDefinition(key: "AadDeviceId", displayName: "Aad Device Id", isDefault: true),
                ColumnDefinition(key: "Context", displayName: "Context", isDefault: true),
                ColumnDefinition(key: "DeviceId", displayName: "Device Id", isDefault: true),
                ColumnDefinition(key: "DeviceName", displayName: "Device Name", isDefault: true),
                ColumnDefinition(key: "EnrollmentActivityId", displayName: "Enrollment Activity Id", isDefault: true),
                ColumnDefinition(key: "EnrollmentDateTime", displayName: "Enrollment Date Time", isDefault: true),
                ColumnDefinition(key: "EnrollmentMethod", displayName: "Enrollment Method", isDefault: true),
                ColumnDefinition(key: "Failure", displayName: "Failure", isDefault: true),
                ColumnDefinition(key: "FailureDetails", displayName: "Failure Details", isDefault: true),
                ColumnDefinition(key: "FailureReason", displayName: "Failure Reason", isDefault: true),
                ColumnDefinition(key: "OS", displayName: "OS", isDefault: true),
                ColumnDefinition(key: "OSVersion", displayName: "OSVersion", isDefault: true),
                ColumnDefinition(key: "OwnerType", displayName: "Owner Type", isDefault: true),
                ColumnDefinition(key: "Remediation", displayName: "Remediation", isDefault: true),
                ColumnDefinition(key: "SerialNumber", displayName: "Serial Number", isDefault: true),
                ColumnDefinition(key: "UPN", displayName: "UPN", isDefault: true),
                ColumnDefinition(key: "UserId", displayName: "User Id", isDefault: true)
            ]
        )

        reports["EnrollmentConfigurationPoliciesByDevice"] = ReportDefinition(
            type: "EnrollmentConfigurationPoliciesByDevice",
            displayName: "Enrollment Configuration Policies By Device",
            description: "See device enrollment configurations",
            category: "Device Enrollment",
            intuneConsolePath: "Under Devices > Device onboarding > Enrollment",
            supportedFilters: [
                FilterDefinition(key: "DeviceId", displayName: "Device Id", type: .text),
                FilterDefinition(key: "State", displayName: "State", type: .text)
            ],
            supportedColumns: [
                ColumnDefinition(key: "DeviceId", displayName: "Device Id", isDefault: true),
                ColumnDefinition(key: "PolicyId", displayName: "Policy Id", isDefault: true),
                ColumnDefinition(key: "Target", displayName: "Target", isDefault: true),
                ColumnDefinition(key: "PolicyType", displayName: "Policy Type", isDefault: true),
                ColumnDefinition(key: "ProfileName", displayName: "Profile Name", isDefault: true),
                ColumnDefinition(key: "UserId", displayName: "User Id", isDefault: true),
                ColumnDefinition(key: "UserPrincipalName", displayName: "User Principal Name", isDefault: true),
                ColumnDefinition(key: "State", displayName: "State", isDefault: true),
                ColumnDefinition(key: "Priority", displayName: "Priority", isDefault: true),
                ColumnDefinition(key: "FilterIds", displayName: "Filter Ids", isDefault: true),
                ColumnDefinition(key: "LastAppliedTime", displayName: "Last Applied Time", isDefault: true)
            ]
        )

        // MARK: - Device Compliance Reports

        reports["DeviceCompliance"] = ReportDefinition(
            type: "DeviceCompliance",
            displayName: "Device Compliance",
            description: "Comprehensive compliance status and details for all managed devices. Shows compliance policy evaluation results, device information, and user details.",
            category: "Device Compliance",
            intuneConsolePath: "Devices > Compliance policies > Policy compliance",
            supportedFilters: [
                FilterDefinition(key: "ComplianceState", displayName: "Compliance State", type: .dropdown,
                               options: ["All", "Compliant", "Noncompliant", "InGracePeriod", "Unknown"]),
                FilterDefinition(key: "OS", displayName: "OS", type: .dropdown,
                               options: ["All", "Android", "iOS", "macOS", "Windows"]),
                FilterDefinition(key: "OwnerType", displayName: "Owner Type", type: .dropdown,
                               options: ["All", "Company", "Personal"],
                               optionValues: ["Company": "1", "Personal": "2"]),
                FilterDefinition(key: "DeviceType", displayName: "Device Type", type: .dropdown,
                               options: ["All", "Desktop", "Windows", "winMO6", "Nokia", "WindowsPhone", "Mac", "WinCE", "WinEmbedded", "iPhone", "iPad", "iPod", "Android", "iSocConsumer", "Unix", "MacMDM", "HoloLens", "SurfaceHub", "AndroidForWork", "AndroidEnterprise", "Windows10x", "AndroidnGMS", "CloudPC", "Linux"],
                               optionValues: ["Desktop": "0", "Windows": "1", "winMO6": "2", "Nokia": "3", "WindowsPhone": "4", "Mac": "5", "WinCE": "6", "WinEmbedded": "7", "iPhone": "8", "iPad": "9", "iPod": "10", "Android": "11", "iSocConsumer": "12", "Unix": "13", "MacMDM": "14", "HoloLens": "15", "SurfaceHub": "16", "AndroidForWork": "17", "AndroidEnterprise": "18", "Windows10x": "19", "AndroidnGMS": "20", "CloudPC": "21", "Linux": "22"])
            ],
            supportedColumns: [
                ColumnDefinition(key: "DeviceId", displayName: "Device ID", isDefault: true),
                ColumnDefinition(key: "IntuneDeviceId", displayName: "Intune Device ID", isDefault: true),
                ColumnDefinition(key: "AadDeviceId", displayName: "Azure AD Device ID", isDefault: true),
                ColumnDefinition(key: "DeviceName", displayName: "Device Name", isDefault: true),
                ColumnDefinition(key: "DeviceType", displayName: "Device Type", isDefault: true),
                ColumnDefinition(key: "OSDescription", displayName: "OS Description", isDefault: true),
                ColumnDefinition(key: "OSVersion", displayName: "OS Version", isDefault: true),
                ColumnDefinition(key: "OwnerType", displayName: "Owner Type", isDefault: true),
                ColumnDefinition(key: "LastContact", displayName: "Last Contact", isDefault: true),
                ColumnDefinition(key: "InGracePeriodUntil", displayName: "Grace Period Until", isDefault: true),
                ColumnDefinition(key: "IMEI", displayName: "IMEI", isDefault: true),
                ColumnDefinition(key: "SerialNumber", displayName: "Serial Number", isDefault: true),
                ColumnDefinition(key: "ManagementAgents", displayName: "Management Agents", isDefault: true),
                ColumnDefinition(key: "PrimaryUser", displayName: "Primary User", isDefault: true),
                ColumnDefinition(key: "UserId", displayName: "User ID", isDefault: true),
                ColumnDefinition(key: "UPN", displayName: "UPN", isDefault: true),
                ColumnDefinition(key: "UserEmail", displayName: "User Email", isDefault: true),
                ColumnDefinition(key: "UserName", displayName: "User Name", isDefault: true),
                ColumnDefinition(key: "DeviceHealthThreatLevel", displayName: "Health Threat Level", isDefault: true),
                ColumnDefinition(key: "RetireAfterDatetime", displayName: "Retire After", isDefault: true),
                ColumnDefinition(key: "PartnerDeviceId", displayName: "Partner Device ID", isDefault: true),
                ColumnDefinition(key: "ComplianceState", displayName: "Compliance State", isDefault: true),
                ColumnDefinition(key: "OS", displayName: "OS", isDefault: true)
            ]
        )
        
        reports["DeviceComplianceTrend"] = ReportDefinition(
            type: "DeviceComplianceTrend",
            displayName: "Device Compliance Trend",
            description: "Trend for Device Compliance",
            category: "Device Compliance",
            intuneConsolePath: "Under Reports > Device management > Device Compliance > Reports",
            supportedFilters: [
            ],
            supportedColumns: [
                ColumnDefinition(key: "ComplianceState", displayName: "Compliance State", isDefault: true),
                ColumnDefinition(key: "Count", displayName: "Count", isDefault: true),
                ColumnDefinition(key: "Date", displayName: "Date", isDefault: true),
                ColumnDefinition(key: "DeviceType", displayName: "Device Type", isDefault: true),
                ColumnDefinition(key: "OSFamily", displayName: "OSFamily", isDefault: true),
                ColumnDefinition(key: "OwnerType", displayName: "Owner Type", isDefault: true)
            ]
        )

        reports["DeviceNonCompliance"] = ReportDefinition(
            type: "DeviceNonCompliance",
            displayName: "Device Non Compliance",
            description: "Devices that are not compliant with policies",
            category: "Device Compliance",
            supportedFilters: [
                FilterDefinition(key: "Platform", displayName: "Platform", type: .dropdown,
                               options: ["All", "Android", "iOS", "macOS", "Windows"]),
                FilterDefinition(key: "OwnerType", displayName: "Owner Type", type: .dropdown,
                               options: ["All", "Company", "Personal"],
                               optionValues: ["Company": "1", "Personal": "2"])
            ],
            supportedColumns: [
                ColumnDefinition(key: "DeviceName", displayName: "Device Name", isDefault: true),
                ColumnDefinition(key: "ComplianceState", displayName: "Compliance State", isDefault: true),
                ColumnDefinition(key: "NonComplianceReason", displayName: "Non-Compliance Reason", isDefault: true),
                ColumnDefinition(key: "Platform", displayName: "Platform", isDefault: true)
            ]
        )
                
        reports["DevicePoliciesComplianceReport"] = ReportDefinition(
            type: "DevicePoliciesComplianceReport",
            displayName: "Device Policies Compliance Report",
            description: "Device Policies Compliance Report",
            category: "Device Compliance",
            intuneConsolePath: "Under Reports > Device management > Device Compliance > Reports",
            supportedFilters: [
            ],
            supportedColumns: [
                ColumnDefinition(key: "DeviceId", displayName: "Device Id", isDefault: true),
                ColumnDefinition(key: "LastContact", displayName: "Last Contact", isDefault: true),
                ColumnDefinition(key: "PolicyId", displayName: "Policy Id", isDefault: true),
                ColumnDefinition(key: "PolicyName", displayName: "Policy Name", isDefault: true),
                ColumnDefinition(key: "PolicyPlatformType", displayName: "Policy Platform Type", isDefault: true),
                ColumnDefinition(key: "PolicyStatus", displayName: "Policy Status", isDefault: true),
                ColumnDefinition(key: "PolicyVersion", displayName: "Policy Version", isDefault: true),
                ColumnDefinition(key: "UPN", displayName: "UPN", isDefault: true),
                ColumnDefinition(key: "UserEmail", displayName: "User Email", isDefault: true),
                ColumnDefinition(key: "UserId", displayName: "User Id", isDefault: true),
                ColumnDefinition(key: "UserName", displayName: "User Name", isDefault: true)
            ]
        )

        reports["DevicePoliciesComplianceReportV3"] = ReportDefinition(
            type: "DevicePoliciesComplianceReportV3",
            displayName: "Device Policies Compliance Report V3",
            description: "Device Policies Compliance Report V3",
            category: "Device Compliance",
            intuneConsolePath: "Under Reports > Device management > Device Compliance > Reports",
            supportedFilters: [
            ],
            supportedColumns: [
                ColumnDefinition(key: "DeviceId", displayName: "Device Id", isDefault: true),
                ColumnDefinition(key: "LastContact", displayName: "Last Contact", isDefault: true),
                ColumnDefinition(key: "PolicyId", displayName: "Policy Id", isDefault: true),
                ColumnDefinition(key: "PolicyName", displayName: "Policy Name", isDefault: true),
                ColumnDefinition(key: "PolicyPlatformType", displayName: "Policy Platform Type", isDefault: true),
                ColumnDefinition(key: "PolicyStatus", displayName: "Policy Status", isDefault: true),
                ColumnDefinition(key: "PolicyVersion", displayName: "Policy Version", isDefault: true),
                ColumnDefinition(key: "UPN", displayName: "UPN", isDefault: true),
                ColumnDefinition(key: "UserEmail", displayName: "User Email", isDefault: true),
                ColumnDefinition(key: "UserId", displayName: "User Id", isDefault: true),
                ColumnDefinition(key: "UserName", displayName: "User Name", isDefault: true)
            ]
        )

        reports["DevicePolicySettingsComplianceReport"] = ReportDefinition(
            type: "DevicePolicySettingsComplianceReport",
            displayName: "Device Policy Settings Compliance Report",
            description: "Device Policy Setting Compliance Report",
            category: "Device Compliance",
            intuneConsolePath: "Under Reports > Device management > Device Compliance > Reports",
            supportedFilters: [
            ],
            supportedColumns: [
                ColumnDefinition(key: "DeviceId", displayName: "Device Id", isDefault: true),
                ColumnDefinition(key: "ErrorCode", displayName: "Error Code", isDefault: true),
                ColumnDefinition(key: "ErrorType", displayName: "Error Type", isDefault: true),
                ColumnDefinition(key: "PolicyId", displayName: "Policy Id", isDefault: true),
                ColumnDefinition(key: "PolicyVersion", displayName: "Policy Version", isDefault: true),
                ColumnDefinition(key: "SettingId", displayName: "Setting Id", isDefault: true),
                ColumnDefinition(key: "SettingInstanceId", displayName: "Setting Instance Id", isDefault: true),
                ColumnDefinition(key: "SettingName", displayName: "Setting Name", isDefault: true),
                ColumnDefinition(key: "SettingNm", displayName: "Setting Nm", isDefault: true),
                ColumnDefinition(key: "SettingStatus", displayName: "Setting Status", isDefault: true),
                ColumnDefinition(key: "SettingValue", displayName: "Setting Value", isDefault: true),
                ColumnDefinition(key: "StateDetails", displayName: "State Details", isDefault: true),
                ColumnDefinition(key: "UserId", displayName: "User Id", isDefault: true)
            ]
        )

        reports["DevicePolicySettingsComplianceReportV3"] = ReportDefinition(
            type: "DevicePolicySettingsComplianceReportV3",
            displayName: "Device Policy Settings Compliance Report V3",
            description: "Device Policy Setting Compliance Report V3",
            category: "Device Compliance",
            intuneConsolePath: "Under Reports > Device management > Device Compliance > Reports",
            supportedFilters: [
            ],
            supportedColumns: [
                ColumnDefinition(key: "DeviceId", displayName: "Device Id", isDefault: true),
                ColumnDefinition(key: "ErrorCode", displayName: "Error Code", isDefault: true),
                ColumnDefinition(key: "ErrorType", displayName: "Error Type", isDefault: true),
                ColumnDefinition(key: "PolicyId", displayName: "Policy Id", isDefault: true),
                ColumnDefinition(key: "PolicyVersion", displayName: "Policy Version", isDefault: true),
                ColumnDefinition(key: "SettingId", displayName: "Setting Id", isDefault: true),
                ColumnDefinition(key: "SettingInstanceId", displayName: "Setting Instance Id", isDefault: true),
                ColumnDefinition(key: "SettingName", displayName: "Setting Name", isDefault: true),
                ColumnDefinition(key: "SettingNm", displayName: "Setting Nm", isDefault: true),
                ColumnDefinition(key: "SettingStatus", displayName: "Setting Status", isDefault: true),
                ColumnDefinition(key: "SettingValue", displayName: "Setting Value", isDefault: true),
                ColumnDefinition(key: "StateDetails", displayName: "State Details", isDefault: true),
                ColumnDefinition(key: "UserId", displayName: "User Id", isDefault: true)
            ]
        )

        reports["DevicesStatusByPolicyPlatformComplianceReport"] = ReportDefinition(
            type: "DevicesStatusByPolicyPlatformComplianceReport",
            displayName: "Devices Status By Policy Platform Compliance Report",
            description: "Devices Status By Policy Platform Compliance Report",
            category: "Device Compliance",
            intuneConsolePath: "Under Reports > Device management > Device Compliance > Reports",
            supportedFilters: [
            ],
            supportedColumns: [
                ColumnDefinition(key: "AadDeviceId", displayName: "AAD Device Id", isDefault: true),
                ColumnDefinition(key: "ComplianceState", displayName: "Compliance State", isDefault: true),
                ColumnDefinition(key: "DeviceId", displayName: "Device Id", isDefault: true),
                ColumnDefinition(key: "DeviceName", displayName: "Device Name", isDefault: true),
                ColumnDefinition(key: "InGracePeriodUntil", displayName: "In Grace Period Until", isDefault: true),
                ColumnDefinition(key: "LastContact", displayName: "Last Contact", isDefault: true),
                ColumnDefinition(key: "Model", displayName: "Model", isDefault: true),
                ColumnDefinition(key: "OS", displayName: "OS", isDefault: true),
                ColumnDefinition(key: "PolicyId", displayName: "Policy Id", isDefault: true),
                ColumnDefinition(key: "PolicyPlatformType", displayName: "Policy Platform Type", isDefault: true),
                ColumnDefinition(key: "PolicyStatus", displayName: "Policy Status", isDefault: true),
                ColumnDefinition(key: "UPN", displayName: "UPN", isDefault: true)
            ]
        )

        reports["DevicesStatusByPolicyPlatformComplianceReportV3"] = ReportDefinition(
            type: "DevicesStatusByPolicyPlatformComplianceReportV3",
            displayName: "Devices Status By Policy Platform Compliance Report V3",
            description: "Devices Status By Policy Platform Compliance Report V3",
            category: "Device Compliance",
            intuneConsolePath: "Under Reports > Device management > Device Compliance > Reports",
            supportedFilters: [
            ],
            supportedColumns: [
                ColumnDefinition(key: "AadDeviceId", displayName: "AAD Device Id", isDefault: true),
                ColumnDefinition(key: "ComplianceState", displayName: "Compliance State", isDefault: true),
                ColumnDefinition(key: "DeviceId", displayName: "Device Id", isDefault: true),
                ColumnDefinition(key: "DeviceName", displayName: "Device Name", isDefault: true),
                ColumnDefinition(key: "InGracePeriodUntil", displayName: "In Grace Period Until", isDefault: true),
                ColumnDefinition(key: "LastContact", displayName: "Last Contact", isDefault: true),
                ColumnDefinition(key: "Model", displayName: "Model", isDefault: true),
                ColumnDefinition(key: "OS", displayName: "OS", isDefault: true),
                ColumnDefinition(key: "PolicyId", displayName: "Policy Id", isDefault: true),
                ColumnDefinition(key: "PolicyPlatformType", displayName: "Policy Platform Type", isDefault: true),
                ColumnDefinition(key: "PolicyStatus", displayName: "Policy Status", isDefault: true),
                ColumnDefinition(key: "UPN", displayName: "UPN", isDefault: true)
            ]
        )

        reports["DeviceStatusByCompliacePolicyReport"] = ReportDefinition(
            type: "DeviceStatusByCompliacePolicyReport",
            displayName: "Device Status By Compliance Policy Report",
            description: "Device Status By Compliance Policy Report",
            category: "Device Compliance",
            intuneConsolePath: "Under Reports > Device management > Device Compliance > Reports",
            supportedFilters: [
            ],
            supportedColumns: [
                ColumnDefinition(key: "AadDeviceId", displayName: "AAD Device Id", isDefault: true),
                ColumnDefinition(key: "DeviceId", displayName: "Device Id", isDefault: true),
                ColumnDefinition(key: "DeviceName", displayName: "Device Name", isDefault: true),
                ColumnDefinition(key: "LastContact", displayName: "Last Contact", isDefault: true),
                ColumnDefinition(key: "ManagementAgents", displayName: "Management Agents", isDefault: true),
                ColumnDefinition(key: "OS", displayName: "OS", isDefault: true),
                ColumnDefinition(key: "PolicyId", displayName: "Policy Id", isDefault: true),
                ColumnDefinition(key: "PolicyStatus", displayName: "Policy Status", isDefault: true),
                ColumnDefinition(key: "UPN", displayName: "UPN", isDefault: true),
                ColumnDefinition(key: "UserId", displayName: "User Id", isDefault: true),
                ColumnDefinition(key: "UserName", displayName: "User Name", isDefault: true)
            ]
        )

        reports["DeviceStatusByCompliacePolicyReportV3"] = ReportDefinition(
            type: "DeviceStatusByCompliacePolicyReportV3",
            displayName: "Device Status By Compliance Policy Report V3",
            description: "Device Status By Compliance Policy Report V3",
            category: "Device Compliance",
            intuneConsolePath: "Under Reports > Device management > Device Compliance > Reports",
            supportedFilters: [
            ],
            supportedColumns: [
                ColumnDefinition(key: "AadDeviceId", displayName: "AAD Device Id", isDefault: true),
                ColumnDefinition(key: "DeviceId", displayName: "Device Id", isDefault: true),
                ColumnDefinition(key: "DeviceName", displayName: "Device Name", isDefault: true),
                ColumnDefinition(key: "LastContact", displayName: "Last Contact", isDefault: true),
                ColumnDefinition(key: "ManagementAgents", displayName: "Management Agents", isDefault: true),
                ColumnDefinition(key: "OS", displayName: "OS", isDefault: true),
                ColumnDefinition(key: "PolicyId", displayName: "Policy Id", isDefault: true),
                ColumnDefinition(key: "PolicyStatus", displayName: "Policy Status", isDefault: true),
                ColumnDefinition(key: "UPN", displayName: "UPN", isDefault: true),
                ColumnDefinition(key: "UserId", displayName: "User Id", isDefault: true),
                ColumnDefinition(key: "UserName", displayName: "User Name", isDefault: true)
            ]
        )

        reports["DeviceStatusByCompliancePolicySettingReport"] = ReportDefinition(
            type: "DeviceStatusByCompliancePolicySettingReport",
            displayName: "Device Status By Compliance Policy Setting Report",
            description: "Device Status By Compliance Policy Setting Report",
            category: "Device Compliance",
            intuneConsolePath: "Under Reports > Device management > Device Compliance > Reports",
            supportedFilters: [
            ],
            supportedColumns: [
                ColumnDefinition(key: "AadDeviceId", displayName: "AAD Device Id", isDefault: true),
                ColumnDefinition(key: "ComplianceState", displayName: "Compliance State", isDefault: true),
                ColumnDefinition(key: "DeviceId", displayName: "Device Id", isDefault: true),
                ColumnDefinition(key: "DeviceName", displayName: "Device Name", isDefault: true),
                ColumnDefinition(key: "ManagementAgents", displayName: "Management Agents", isDefault: true),
                ColumnDefinition(key: "Model", displayName: "Model", isDefault: true),
                ColumnDefinition(key: "OS", displayName: "OS", isDefault: true),
                ColumnDefinition(key: "PolicyId", displayName: "Policy Id", isDefault: true),
                ColumnDefinition(key: "SettingId", displayName: "Setting Id", isDefault: true),
                ColumnDefinition(key: "SettingName", displayName: "Setting Name", isDefault: true),
                ColumnDefinition(key: "SettingNm", displayName: "Setting Nm", isDefault: true),
                ColumnDefinition(key: "SettingStatus", displayName: "Setting Status", isDefault: true),
                ColumnDefinition(key: "UPN", displayName: "UPN", isDefault: true)
            ]
        )
        
        reports["DeviceStatusByCompliancePolicySettingReportV3"] = ReportDefinition(
            type: "DeviceStatusByCompliancePolicySettingReportV3",
            displayName: "Device Status By Compliance Policy Setting Report V3",
            description: "Device Status By Compliance Policy Setting Report V3",
            category: "Device Compliance",
            intuneConsolePath: "Under Reports > Device management > Device Compliance > Reports",
            supportedFilters: [
            ],
            supportedColumns: [
                ColumnDefinition(key: "AadDeviceId", displayName: "AAD Device Id", isDefault: true),
                ColumnDefinition(key: "ComplianceState", displayName: "Compliance State", isDefault: true),
                ColumnDefinition(key: "DeviceId", displayName: "Device Id", isDefault: true),
                ColumnDefinition(key: "DeviceName", displayName: "Device Name", isDefault: true),
                ColumnDefinition(key: "ManagementAgents", displayName: "Management Agents", isDefault: true),
                ColumnDefinition(key: "Model", displayName: "Model", isDefault: true),
                ColumnDefinition(key: "OS", displayName: "OS", isDefault: true),
                ColumnDefinition(key: "PolicyId", displayName: "Policy Id", isDefault: true),
                ColumnDefinition(key: "SettingId", displayName: "Setting Id", isDefault: true),
                ColumnDefinition(key: "SettingName", displayName: "Setting Name", isDefault: true),
                ColumnDefinition(key: "SettingNm", displayName: "Setting Nm", isDefault: true),
                ColumnDefinition(key: "SettingStatus", displayName: "Setting Status", isDefault: true),
                ColumnDefinition(key: "UPN", displayName: "UPN", isDefault: true)
            ]
        )

        reports["DeviceStatusSummaryByCompliacePolicyReport"] = ReportDefinition(
            type: "DeviceStatusSummaryByCompliacePolicyReport",
            displayName: "Device Status Summary By Compliace Policy Report",
            description: "Device Status Summary By Compliace Policy Report",
            category: "Device Compliance",
            intuneConsolePath: "Under Reports > Device management > Device Compliance > Reports",
            supportedFilters: [
            ],
            supportedColumns: [
                ColumnDefinition(key: "NumberOfCompliantDevices", displayName: "Number Of Compliant Devices", isDefault: true),
                ColumnDefinition(key: "NumberOfNonCompliantDevices", displayName: "Number Of Non Compliant Devices", isDefault: true),
                ColumnDefinition(key: "NumberOfOtherDevices", displayName: "Number Of Other Devices", isDefault: true),
                ColumnDefinition(key: "OS", displayName: "OS", isDefault: true),
                ColumnDefinition(key: "PolicyId", displayName: "Policy Id", isDefault: true)
            ]
        )
        
        reports["DeviceStatusSummaryByCompliacePolicyReportV3"] = ReportDefinition(
            type: "DeviceStatusSummaryByCompliacePolicyReportV3",
            displayName: "Device Status Summary By Compliace Policy Report V3",
            description: "Device Status Summary By Compliace Policy Report V3",
            category: "Device Compliance",
            intuneConsolePath: "Under Reports > Device management > Device Compliance > Reports",
            supportedFilters: [
            ],
            supportedColumns: [
                ColumnDefinition(key: "NumberOfCompliantDevices", displayName: "Number Of Compliant Devices", isDefault: true),
                ColumnDefinition(key: "NumberOfNonCompliantDevices", displayName: "Number Of Non Compliant Devices", isDefault: true),
                ColumnDefinition(key: "NumberOfOtherDevices", displayName: "Number Of Other Devices", isDefault: true),
                ColumnDefinition(key: "OS", displayName: "OS", isDefault: true),
                ColumnDefinition(key: "PolicyId", displayName: "Policy Id", isDefault: true)
            ]
        )
        
        reports["DeviceStatusSummaryByCompliancePolicySettingsReport"] = ReportDefinition(
            type: "DeviceStatusSummaryByCompliancePolicySettingsReport",
            displayName: "Device Status Summary By Compliance Policy Settings Report",
            description: "Device Status Summary By Compliance Policy Settings Report",
            category: "Device Compliance",
            intuneConsolePath: "Under Reports > Device management > Device Compliance > Reports",
            supportedFilters: [
            ],
            supportedColumns: [
                ColumnDefinition(key: "NumberOfCompliantDevices", displayName: "Number Of Compliant Devices", isDefault: true),
                ColumnDefinition(key: "NumberOfErrorDevices", displayName: "Number Of Error Devices", isDefault: true),
                ColumnDefinition(key: "NumberOfNonCompliantDevices", displayName: "Number Of Non Compliant Devices", isDefault: true),
                ColumnDefinition(key: "NumberOfNotApplicableDevices", displayName: "Number Of Not Applicable Devices", isDefault: true),
                ColumnDefinition(key: "NumberOfNotEvaluatedDevices", displayName: "Number Of Not Evaluated Devices", isDefault: true),
                ColumnDefinition(key: "NumberOfOtherDevices", displayName: "Number Of Other Devices", isDefault: true),
                ColumnDefinition(key: "PolicyId", displayName: "Policy Id", isDefault: true),
                ColumnDefinition(key: "SettingId", displayName: "Setting Id", isDefault: true),
                ColumnDefinition(key: "SettingName", displayName: "Setting Name", isDefault: true),
                ColumnDefinition(key: "SettingNm", displayName: "Setting Nm", isDefault: true)
            ]
        )
        
        reports["DeviceStatusSummaryByCompliancePolicySettingsReportV3"] = ReportDefinition(
            type: "DeviceStatusSummaryByCompliancePolicySettingsReportV3",
            displayName: "Device Status Summary By Compliance Policy Settings Report V3",
            description: "Device Status Summary By Compliance Policy Settings Report V3",
            category: "Device Compliance",
            intuneConsolePath: "Under Reports > Device management > Device Compliance > Reports",
            supportedFilters: [
            ],
            supportedColumns: [
                ColumnDefinition(key: "NumberOfCompliantDevices", displayName: "Number Of Compliant Devices", isDefault: true),
                ColumnDefinition(key: "NumberOfErrorDevices", displayName: "Number Of Error Devices", isDefault: true),
                ColumnDefinition(key: "NumberOfNonCompliantDevices", displayName: "Number Of Non Compliant Devices", isDefault: true),
                ColumnDefinition(key: "NumberOfNotApplicableDevices", displayName: "Number Of Not Applicable Devices", isDefault: true),
                ColumnDefinition(key: "NumberOfNotEvaluatedDevices", displayName: "Number Of Not Evaluated Devices", isDefault: true),
                ColumnDefinition(key: "NumberOfOtherDevices", displayName: "Number Of Other Devices", isDefault: true),
                ColumnDefinition(key: "PolicyId", displayName: "Policy Id", isDefault: true),
                ColumnDefinition(key: "SettingId", displayName: "Setting Id", isDefault: true),
                ColumnDefinition(key: "SettingName", displayName: "Setting Name", isDefault: true),
                ColumnDefinition(key: "SettingNm", displayName: "Setting Nm", isDefault: true)
            ]
        )

        reports["DevicesWithoutCompliancePolicy"] = ReportDefinition(
            type: "DevicesWithoutCompliancePolicy",
            displayName: "Devices Without Compliance Policy",
            description: "Devices without compliance policy",
            category: "Device Compliance",
            intuneConsolePath: "Under Reports > Device management > Device Compliance > Reports",
            supportedFilters: [
            ],
            supportedColumns: [
                ColumnDefinition(key: "AadDeviceId", displayName: "AAD Device Id", isDefault: true),
                ColumnDefinition(key: "ComplianceState", displayName: "Compliance State", isDefault: true),
                ColumnDefinition(key: "DeviceId", displayName: "Device Id", isDefault: true),
                ColumnDefinition(key: "DeviceModel", displayName: "Device Model", isDefault: true),
                ColumnDefinition(key: "DeviceName", displayName: "Device Name", isDefault: true),
                ColumnDefinition(key: "DeviceType", displayName: "Device Type", isDefault: true),
                ColumnDefinition(key: "LastContact", displayName: "Last Contact", isDefault: true),
                ColumnDefinition(key: "LastContactedUserId", displayName: "Last Contacted User Id", isDefault: true),
                ColumnDefinition(key: "ManagementAgents", displayName: "Management Agents", isDefault: true),
                ColumnDefinition(key: "OS", displayName: "OS", isDefault: true),
                ColumnDefinition(key: "OSDescription", displayName: "OSDescription", isDefault: true),
                ColumnDefinition(key: "OSVersion", displayName: "OSVersion", isDefault: true),
                ColumnDefinition(key: "OwnerType", displayName: "Owner Type", isDefault: true),
                ColumnDefinition(key: "PrimaryUser", displayName: "Primary User", isDefault: true),
                ColumnDefinition(key: "UPN", displayName: "UPN", isDefault: true),
                ColumnDefinition(key: "UserEmail", displayName: "User Email", isDefault: true),
                ColumnDefinition(key: "UserId", displayName: "User Id", isDefault: true),
                ColumnDefinition(key: "UserName", displayName: "User Name", isDefault: true)
            ]
        )
        
        reports["DevicesWithoutCompliancePolicyV3"] = ReportDefinition(
            type: "DevicesWithoutCompliancePolicyV3",
            displayName: "Devices Without Compliance Policy V3",
            description: "Devices without compliance policy V3",
            category: "Device Compliance",
            intuneConsolePath: "Under Reports > Device management > Device Compliance > Reports",
            supportedFilters: [
            ],
            supportedColumns: [
                ColumnDefinition(key: "AadDeviceId", displayName: "AAD Device Id", isDefault: true),
                ColumnDefinition(key: "ComplianceState", displayName: "Compliance State", isDefault: true),
                ColumnDefinition(key: "DeviceId", displayName: "Device Id", isDefault: true),
                ColumnDefinition(key: "DeviceModel", displayName: "Device Model", isDefault: true),
                ColumnDefinition(key: "DeviceName", displayName: "Device Name", isDefault: true),
                ColumnDefinition(key: "DeviceType", displayName: "Device Type", isDefault: true),
                ColumnDefinition(key: "LastContact", displayName: "Last Contact", isDefault: true),
                ColumnDefinition(key: "LastContactedUserId", displayName: "Last Contacted User Id", isDefault: true),
                ColumnDefinition(key: "ManagementAgents", displayName: "Management Agents", isDefault: true),
                ColumnDefinition(key: "OS", displayName: "OS", isDefault: true),
                ColumnDefinition(key: "OSDescription", displayName: "OSDescription", isDefault: true),
                ColumnDefinition(key: "OSVersion", displayName: "OSVersion", isDefault: true),
                ColumnDefinition(key: "OwnerType", displayName: "Owner Type", isDefault: true),
                ColumnDefinition(key: "PrimaryUser", displayName: "Primary User", isDefault: true),
                ColumnDefinition(key: "UPN", displayName: "UPN", isDefault: true),
                ColumnDefinition(key: "UserEmail", displayName: "User Email", isDefault: true),
                ColumnDefinition(key: "UserId", displayName: "User Id", isDefault: true),
                ColumnDefinition(key: "UserName", displayName: "User Name", isDefault: true)
            ]
        )
        
        reports["WindowsDeviceHealthAttestationReport"] = ReportDefinition(
            type: "WindowsDeviceHealthAttestationReport",
            displayName: "Windows Device Health Attestation Report",
            description: "See Windows Device Health Attestation Report",
            category: "Device Compliance",
            intuneConsolePath: "Under Reports > Device management > Device Compliance > Reports",
            supportedFilters: [
            ],
            supportedColumns: [
                ColumnDefinition(key: "AIKKey", displayName: "AIKKey", isDefault: true),
                ColumnDefinition(key: "AttestationError", displayName: "Attestation Error", isDefault: true),
                ColumnDefinition(key: "BitlockerStatus", displayName: "Bitlocker Status", isDefault: true),
                ColumnDefinition(key: "BootDebuggingStatus", displayName: "Boot Debugging Status", isDefault: true),
                ColumnDefinition(key: "CodeIntegrityStatus", displayName: "Code Integrity Status", isDefault: true),
                ColumnDefinition(key: "DEPPolicy", displayName: "DEPPolicy", isDefault: true),
                ColumnDefinition(key: "DeviceId", displayName: "Device Id", isDefault: true),
                ColumnDefinition(key: "DeviceName", displayName: "Device Name", isDefault: true),
                ColumnDefinition(key: "DeviceOS", displayName: "Device OS", isDefault: true),
                ColumnDefinition(key: "ELAMDriverLoadedStatus", displayName: "ELAMDriver Loaded Status", isDefault: true),
                ColumnDefinition(key: "FirmwareProtectionStatus", displayName: "Firmware Protection Status", isDefault: true),
                ColumnDefinition(key: "HealthCertIssuedDate", displayName: "Health Cert Issued Date", isDefault: true),
                ColumnDefinition(key: "MemoryAccessProtectionStatus", displayName: "Memory Access Protection Status", isDefault: true),
                ColumnDefinition(key: "MemoryIntegrityProtectionStatus", displayName: "Memory Integrity Protection Status", isDefault: true),
                ColumnDefinition(key: "OSKernelDebuggingStatus", displayName: "OSKernel Debugging Status", isDefault: true),
                ColumnDefinition(key: "PrimaryUser", displayName: "Primary User", isDefault: true),
                ColumnDefinition(key: "SafeModeStatus", displayName: "Safe Mode Status", isDefault: true),
                ColumnDefinition(key: "SecuredCorePCStatus", displayName: "Secured Core PCStatus", isDefault: true),
                ColumnDefinition(key: "SecureBootStatus", displayName: "Secure Boot Status", isDefault: true),
                ColumnDefinition(key: "SystemManagementMode", displayName: "System Management Mode", isDefault: true),
                ColumnDefinition(key: "TpmVersion", displayName: "Tpm Version", isDefault: true),
                ColumnDefinition(key: "UPN", displayName: "UPN", isDefault: true),
                ColumnDefinition(key: "VSMStatus", displayName: "VSMStatus", isDefault: true),
                ColumnDefinition(key: "WinPEStatus", displayName: "Win PEStatus", isDefault: true)
            ]
        )

        // MARK: - Device Management Reports
        reports["ADMXSettingsByDeviceByPolicy"] = ReportDefinition(
            type: "ADMXSettingsByDeviceByPolicy",
            displayName: "ADMXSettings By Device By Policy",
            description: "See Quality Update Policy Summary",
            category: "Device Management",
            intuneConsolePath: "Under Reports > Device management > Device Configuration",
            supportedFilters: [
                FilterDefinition(key: "DeviceId", displayName: "Device Id", type: .text),
                FilterDefinition(key: "PolicyId", displayName: "Policy Id", type: .text),
                FilterDefinition(key: "UserId", displayName: "User Id", type: .text)
            ],
            supportedColumns: [
                ColumnDefinition(key: "CreationSource", displayName: "Creation Source", isDefault: true),
                ColumnDefinition(key: "DeviceId", displayName: "Device Id", isDefault: true),
                ColumnDefinition(key: "ErrorCode", displayName: "Error Code", isDefault: true),
                ColumnDefinition(key: "ErrorType", displayName: "Error Type", isDefault: true),
                ColumnDefinition(key: "PolicyId", displayName: "Policy Id", isDefault: true),
                ColumnDefinition(key: "PolicyName", displayName: "Policy Name", isDefault: true),
                ColumnDefinition(key: "PolicyVersion", displayName: "Policy Version", isDefault: true),
                ColumnDefinition(key: "SettingId", displayName: "Setting Id", isDefault: true),
                ColumnDefinition(key: "SettingInstanceId", displayName: "Setting Instance Id", isDefault: true),
                ColumnDefinition(key: "SettingInstancePath", displayName: "Setting Instance Path", isDefault: true),
                ColumnDefinition(key: "SettingName", displayName: "Setting Name", isDefault: true),
                ColumnDefinition(key: "SettingNameStringId", displayName: "Setting Name String Id", isDefault: true),
                ColumnDefinition(key: "SettingStatus", displayName: "Setting Status", isDefault: true),
                ColumnDefinition(key: "UserId", displayName: "User Id", isDefault: true)
            ]
        )

        reports["DeviceRunStatesByScript"] = ReportDefinition(
            type: "DeviceRunStatesByScript",
            displayName: "Device Run States By Script",
            description: "Device RunStates By Script",
            category: "Device Management",
            intuneConsolePath: "Under Devices > Manage devices > Scripts and remediations > select specific script > Device status",
            supportedFilters: [
            ],
            supportedColumns: [
                ColumnDefinition(key: "DeviceId", displayName: "Device Id", isDefault: true),
                ColumnDefinition(key: "DeviceName", displayName: "Device Name", isDefault: true),
                ColumnDefinition(key: "ErrorCode", displayName: "Error Code", isDefault: true),
                ColumnDefinition(key: "ErrorDescription", displayName: "Error Description", isDefault: true),
                ColumnDefinition(key: "ModifiedTime", displayName: "Modified Time", isDefault: true),
                ColumnDefinition(key: "OSVersion", displayName: "OSVersion", isDefault: true),
                ColumnDefinition(key: "PolicyId", displayName: "Policy Id", isDefault: true),
                ColumnDefinition(key: "PolicyResultDetail", displayName: "Policy Result Detail", isDefault: true),
                ColumnDefinition(key: "PolicyResultState", displayName: "Policy Result State", isDefault: true),
                ColumnDefinition(key: "PolicyVersion", displayName: "Policy Version", isDefault: true),
                ColumnDefinition(key: "RunState", displayName: "Run State", isDefault: true),
                ColumnDefinition(key: "UPN", displayName: "UPN", isDefault: true),
                ColumnDefinition(key: "UserEmail", displayName: "User Email", isDefault: true),
                ColumnDefinition(key: "UserId", displayName: "User Id", isDefault: true),
                ColumnDefinition(key: "UserName", displayName: "User Name", isDefault: true)
            ]
        )

        reports["Devices"] = ReportDefinition(
            type: "Devices",
            displayName: "Devices",
            description: "Complete list of all devices managed by Intune, including enrollment status, compliance state, and basic device information. Use this report for device inventory and management overview.",
            category: "Device Management",
            intuneConsolePath: "Devices > All devices",
            supportedFilters: [
                FilterDefinition(key: "OwnerType", displayName: "Owner Type", type: .dropdown,
                               options: ["All", "Company", "Personal"],
                               optionValues: ["Company": "1", "Personal": "2"]),
                FilterDefinition(key: "ComplianceState", displayName: "Compliance State", type: .dropdown,
                               options: ["All", "Compliant", "Noncompliant", "InGracePeriod"]),
                FilterDefinition(key: "ManagementState", displayName: "Management State", type: .dropdown,
                               options: ["All", "Managed", "Discovered", "Unhealthy", "Retire Pending", "Wipe Pending"],
                               optionValues: ["Managed": "0", "Retire Pending": "1", "Wipe Pending": "3", "Unhealthy": "5", "Discovered": "11"]),
                FilterDefinition(key: "DeviceType", displayName: "Device Type", type: .dropdown,
                               options: ["All", "Desktop", "Windows", "winMO6", "Nokia", "WindowsPhone", "Mac", "WinCE", "WinEmbedded", "iPhone", "iPad", "iPod", "Android", "iSocConsumer", "Unix", "MacMDM", "HoloLens", "SurfaceHub", "AndroidForWork", "AndroidEnterprise", "Windows10x", "AndroidnGMS", "CloudPC", "Linux"],
                               optionValues: ["Desktop": "0", "Windows": "1", "winMO6": "2", "Nokia": "3", "WindowsPhone": "4", "Mac": "5", "WinCE": "6", "WinEmbedded": "7", "iPhone": "8", "iPad": "9", "iPod": "10", "Android": "11", "iSocConsumer": "12", "Unix": "13", "MacMDM": "14", "HoloLens": "15", "SurfaceHub": "16", "AndroidForWork": "17", "AndroidEnterprise": "18", "Windows10x": "19", "AndroidnGMS": "20", "CloudPC": "21", "Linux": "22"])
            ],
            supportedColumns: [
                // Essential columns (must be included for API compatibility)
                ColumnDefinition(key: "DeviceId", displayName: "Device ID", isDefault: true),
                ColumnDefinition(key: "DeviceName", displayName: "Device Name", isDefault: true),
                ColumnDefinition(key: "DeviceType", displayName: "Device Type", isDefault: true),
                ColumnDefinition(key: "ClientRegistrationStatus", displayName: "Registration Status", isDefault: true),
                ColumnDefinition(key: "OwnerType", displayName: "Owner Type", isDefault: true),
                ColumnDefinition(key: "CreatedDate", displayName: "Created Date", isDefault: true),
                ColumnDefinition(key: "LastContact", displayName: "Last Contact", isDefault: true),
                ColumnDefinition(key: "ManagementAgents", displayName: "Management Agents", isDefault: true),
                ColumnDefinition(key: "ManagementState", displayName: "Management State", isDefault: true),
                ColumnDefinition(key: "ReferenceId", displayName: "Reference ID", isDefault: true),
                ColumnDefinition(key: "CategoryId", displayName: "Category ID", isDefault: true),
                ColumnDefinition(key: "EnrollmentType", displayName: "Enrollment Type", isDefault: true),
                ColumnDefinition(key: "CertExpirationDate", displayName: "Certificate Expiration", isDefault: true),
                ColumnDefinition(key: "MDMStatus", displayName: "MDM Status", isDefault: true),
                ColumnDefinition(key: "OSVersion", displayName: "OS Version", isDefault: true),
                ColumnDefinition(key: "GraphDeviceIsManaged", displayName: "Graph Device Managed", isDefault: true),
                ColumnDefinition(key: "EasID", displayName: "EAS ID", isDefault: true),
                ColumnDefinition(key: "SerialNumber", displayName: "Serial Number", isDefault: true),
                ColumnDefinition(key: "EnrolledByUser", displayName: "Enrolled By User", isDefault: true),
                ColumnDefinition(key: "Manufacturer", displayName: "Manufacturer", isDefault: true),
                ColumnDefinition(key: "Model", displayName: "Model", isDefault: true),
                ColumnDefinition(key: "OSDescription", displayName: "OS Description", isDefault: true),
                ColumnDefinition(key: "IsManaged", displayName: "Is Managed", isDefault: true),
                ColumnDefinition(key: "EasActivationStatus", displayName: "EAS Activation Status", isDefault: true),
                ColumnDefinition(key: "IMEI", displayName: "IMEI", isDefault: true),
                ColumnDefinition(key: "EasLastSyncSuccessUtc", displayName: "EAS Last Sync", isDefault: true),
                ColumnDefinition(key: "EasStateReason", displayName: "EAS State Reason", isDefault: true),
                ColumnDefinition(key: "EasAccessState", displayName: "EAS Access State", isDefault: true),
                ColumnDefinition(key: "EncryptionStatus", displayName: "Encryption Status", isDefault: true),
                ColumnDefinition(key: "SupervisedStatus", displayName: "Supervised Status", isDefault: true),
                ColumnDefinition(key: "PhoneNumberE164Format", displayName: "Phone Number", isDefault: true),
                ColumnDefinition(key: "InGracePeriodUntil", displayName: "Grace Period Until", isDefault: true),
                ColumnDefinition(key: "WifiMacAddress", displayName: "WiFi MAC Address", isDefault: true),
                ColumnDefinition(key: "StorageTotal", displayName: "Total Storage", isDefault: true),
                ColumnDefinition(key: "StorageFree", displayName: "Free Storage", isDefault: true),
                ColumnDefinition(key: "ManagedDeviceName", displayName: "Managed Device Name", isDefault: true),
                ColumnDefinition(key: "LastLoggedOnUserUPN", displayName: "Last Logged User UPN", isDefault: true),
                ColumnDefinition(key: "UserApprovedEnrollment", displayName: "User Approved Enrollment", isDefault: true),
                ColumnDefinition(key: "ExtendedProperties", displayName: "Extended Properties", isDefault: true),
                ColumnDefinition(key: "EntitySource", displayName: "Entity Source", isDefault: true),
                ColumnDefinition(key: "PrimaryUser", displayName: "Primary User", isDefault: true),
                ColumnDefinition(key: "CategoryName", displayName: "Category Name", isDefault: true),
                ColumnDefinition(key: "UserId", displayName: "User ID", isDefault: true),
                ColumnDefinition(key: "UPN", displayName: "UPN", isDefault: true),
                ColumnDefinition(key: "UserEmail", displayName: "User Email", isDefault: true),
                ColumnDefinition(key: "UserName", displayName: "User Name", isDefault: true),
                ColumnDefinition(key: "RetireAfterDatetime", displayName: "Retire After", isDefault: true),
                ColumnDefinition(key: "HasUnlockToken", displayName: "Has Unlock Token", isDefault: true),
                ColumnDefinition(key: "CompliantState", displayName: "Compliant State", isDefault: true),
                ColumnDefinition(key: "ManagedBy", displayName: "Managed By", isDefault: true),
                ColumnDefinition(key: "Ownership", displayName: "Ownership", isDefault: true),
                ColumnDefinition(key: "DeviceState", displayName: "Device State", isDefault: true),
                ColumnDefinition(key: "DeviceRegistrationState", displayName: "Registration State", isDefault: true),
                ColumnDefinition(key: "SupervisedStatusString", displayName: "Supervised Status String", isDefault: true),
                ColumnDefinition(key: "EncryptionStatusString", displayName: "Encryption Status String", isDefault: true),
                ColumnDefinition(key: "OS", displayName: "OS", isDefault: true),
                ColumnDefinition(key: "JoinType", displayName: "Join Type", isDefault: true)
            ]
        )

        reports["DevicesStatusBySettingReport"] = ReportDefinition(
            type: "DevicesStatusBySettingReport",
            displayName: "Devices Status By Setting Report",
            description: "Devices Status By Setting Report",
            category: "Device Management",
            intuneConsolePath: "Under Reports > Device management > Device Compliance > Reports",
            supportedFilters: [
            ],
            supportedColumns: [
                ColumnDefinition(key: "AadDeviceId", displayName: "AAD Device Id", isDefault: true),
                ColumnDefinition(key: "ComplianceState", displayName: "Compliance State", isDefault: true),
                ColumnDefinition(key: "DeviceId", displayName: "Device Id", isDefault: true),
                ColumnDefinition(key: "DeviceName", displayName: "Device Name", isDefault: true),
                ColumnDefinition(key: "InGracePeriodUntil", displayName: "In Grace Period Until", isDefault: true),
                ColumnDefinition(key: "Model", displayName: "Model", isDefault: true),
                ColumnDefinition(key: "OS", displayName: "OS", isDefault: true),
                ColumnDefinition(key: "PolicyPlatformType", displayName: "Policy Platform Type", isDefault: true),
                ColumnDefinition(key: "PrimaryUser", displayName: "Primary User", isDefault: true),
                ColumnDefinition(key: "SettingId", displayName: "Setting Id", isDefault: true),
                ColumnDefinition(key: "SettingName", displayName: "Setting Name", isDefault: true),
                ColumnDefinition(key: "SettingNm", displayName: "Setting Nm", isDefault: true),
                ColumnDefinition(key: "SettingStatus", displayName: "Setting Status", isDefault: true),
                ColumnDefinition(key: "UPN", displayName: "UPN", isDefault: true)
            ]
        )
        
        reports["DevicesStatusBySettingReportV3"] = ReportDefinition(
            type: "DevicesStatusBySettingReportV3",
            displayName: "Devices Status By Setting Report V3",
            description: "Devices Status By Setting Report V3",
            category: "Device Management",
            intuneConsolePath: "Under Reports > Device management > Device Compliance > Reports",
            supportedFilters: [
            ],
            supportedColumns: [
                ColumnDefinition(key: "AadDeviceId", displayName: "AAD Device Id", isDefault: true),
                ColumnDefinition(key: "ComplianceState", displayName: "Compliance State", isDefault: true),
                ColumnDefinition(key: "DeviceId", displayName: "Device Id", isDefault: true),
                ColumnDefinition(key: "DeviceName", displayName: "Device Name", isDefault: true),
                ColumnDefinition(key: "InGracePeriodUntil", displayName: "In Grace Period Until", isDefault: true),
                ColumnDefinition(key: "Model", displayName: "Model", isDefault: true),
                ColumnDefinition(key: "OS", displayName: "OS", isDefault: true),
                ColumnDefinition(key: "PolicyPlatformType", displayName: "Policy Platform Type", isDefault: true),
                ColumnDefinition(key: "PrimaryUser", displayName: "Primary User", isDefault: true),
                ColumnDefinition(key: "SettingId", displayName: "Setting Id", isDefault: true),
                ColumnDefinition(key: "SettingName", displayName: "Setting Name", isDefault: true),
                ColumnDefinition(key: "SettingNm", displayName: "Setting Nm", isDefault: true),
                ColumnDefinition(key: "SettingStatus", displayName: "Setting Status", isDefault: true),
                ColumnDefinition(key: "UPN", displayName: "UPN", isDefault: true)
            ]
        )

        reports["DevicesWithInventory"] = ReportDefinition(
            type: "DevicesWithInventory",
            displayName: "Devices with Inventory",
            description: "Comprehensive device inventory with hardware details and extended management information. Includes detailed device specifications, network information, and compliance data.",
            category: "Device Management",
            intuneConsolePath: "Devices > Monitor > Managed device reports",
            supportedFilters: [
                FilterDefinition(key: "CreatedDate", displayName: "Created Date", type: .date),
                FilterDefinition(key: "LastContact", displayName: "Last Contact", type: .date), 
                FilterDefinition(key: "CategoryName", displayName: "Category Name", type: .text),
                FilterDefinition(key: "CompliantState", displayName: "Compliance State", type: .dropdown,
                               options: ["All", "Compliant", "Noncompliant", "InGracePeriod"]),
                FilterDefinition(key: "ManagementAgents", displayName: "Management Agents", type: .dropdown,
                               options: ["All", "MDM", "ConfigManager", "EAS", "Intunepc"]),
                FilterDefinition(key: "OwnerType", displayName: "Owner Type", type: .dropdown,
                               options: ["All", "Company", "Personal"],
                               optionValues: ["Company": "1", "Personal": "2"]),
                FilterDefinition(key: "ManagementState", displayName: "Management State", type: .dropdown,
                               options: ["All", "Managed", "Discovered", "Unhealthy", "Retire Pending", "Wipe Pending"],
                               optionValues: ["Managed": "0", "Retire Pending": "1", "Wipe Pending": "3", "Unhealthy": "5", "Discovered": "11"]),
                FilterDefinition(key: "DeviceType", displayName: "Device Type", type: .dropdown,
                               options: ["All", "Desktop", "Windows", "winMO6", "Nokia", "WindowsPhone", "Mac", "WinCE", "WinEmbedded", "iPhone", "iPad", "iPod", "Android", "iSocConsumer", "Unix", "MacMDM", "HoloLens", "SurfaceHub", "AndroidForWork", "AndroidEnterprise", "Windows10x", "AndroidnGMS", "CloudPC", "Linux"],
                               optionValues: ["Desktop": "0", "Windows": "1", "winMO6": "2", "Nokia": "3", "WindowsPhone": "4", "Mac": "5", "WinCE": "6", "WinEmbedded": "7", "iPhone": "8", "iPad": "9", "iPod": "10", "Android": "11", "iSocConsumer": "12", "Unix": "13", "MacMDM": "14", "HoloLens": "15", "SurfaceHub": "16", "AndroidForWork": "17", "AndroidEnterprise": "18", "Windows10x": "19", "AndroidnGMS": "20", "CloudPC": "21", "Linux": "22"]),
                FilterDefinition(key: "JailBroken", displayName: "Jail Broken", type: .dropdown,
                               options: ["All", "Yes", "No"]),
                FilterDefinition(key: "EnrollmentType", displayName: "Enrollment Type", type: .dropdown,
                               options: ["All", "UserEnrollment", "DeviceEnrollmentManager", "AppleBulkWithUser", "AppleBulkWithoutUser", "WindowsAzureADJoin", "WindowsBulkUserless", "WindowsAutoEnrollment", "WindowsBulkAzureDomainJoin", "WindowsCoManagement"])
            ],
            supportedColumns: [
                // Essential columns (must be included for API compatibility)
                ColumnDefinition(key: "DeviceId", displayName: "Device ID", isDefault: true),
                ColumnDefinition(key: "DeviceName", displayName: "Device Name", isDefault: true),
                ColumnDefinition(key: "CreatedDate", displayName: "Created Date", isDefault: true),
                ColumnDefinition(key: "LastContact", displayName: "Last Contact", isDefault: true),
                ColumnDefinition(key: "ReferenceId", displayName: "Reference ID", isDefault: true),
                ColumnDefinition(key: "OSVersion", displayName: "OS Version", isDefault: true),
                ColumnDefinition(key: "GraphDeviceIsManaged", displayName: "Graph Device Managed", isDefault: true),
                ColumnDefinition(key: "EasID", displayName: "EAS ID", isDefault: true),
                ColumnDefinition(key: "SerialNumber", displayName: "Serial Number", isDefault: true),
                ColumnDefinition(key: "Manufacturer", displayName: "Manufacturer", isDefault: true),
                ColumnDefinition(key: "Model", displayName: "Model", isDefault: true),
                ColumnDefinition(key: "EasActivationStatus", displayName: "EAS Activation Status", isDefault: true),
                ColumnDefinition(key: "IMEI", displayName: "IMEI", isDefault: true),
                ColumnDefinition(key: "EasLastSyncSuccessUtc", displayName: "EAS Last Sync", isDefault: true),
                ColumnDefinition(key: "EasStateReason", displayName: "EAS State Reason", isDefault: true),
                ColumnDefinition(key: "EasAccessState", displayName: "EAS Access State", isDefault: true),
                ColumnDefinition(key: "InGracePeriodUntil", displayName: "Grace Period Until", isDefault: true),
                ColumnDefinition(key: "AndroidPatchLevel", displayName: "Android Patch Level", isDefault: true),
                ColumnDefinition(key: "WifiMacAddress", displayName: "WiFi MAC Address", isDefault: true),
                ColumnDefinition(key: "MEID", displayName: "MEID", isDefault: true),
                ColumnDefinition(key: "SubscriberCarrierNetwork", displayName: "Carrier Network", isDefault: true),
                ColumnDefinition(key: "StorageTotal", displayName: "Total Storage", isDefault: true),
                ColumnDefinition(key: "StorageFree", displayName: "Free Storage", isDefault: true),
                ColumnDefinition(key: "ManagedDeviceName", displayName: "Managed Device Name", isDefault: true),
                ColumnDefinition(key: "CategoryName", displayName: "Category Name", isDefault: true),
                ColumnDefinition(key: "UserId", displayName: "User ID", isDefault: true),
                ColumnDefinition(key: "UPN", displayName: "UPN", isDefault: true),
                ColumnDefinition(key: "UserEmail", displayName: "User Email", isDefault: true),
                ColumnDefinition(key: "UserName", displayName: "User Name", isDefault: true),
                ColumnDefinition(key: "WiFiIPv4Address", displayName: "WiFi IPv4 Address", isDefault: true),
                ColumnDefinition(key: "WiFiSubnetID", displayName: "WiFi Subnet ID", isDefault: true),
                ColumnDefinition(key: "ComplianceState", displayName: "Compliance State", isDefault: true),
                ColumnDefinition(key: "ManagementAgent", displayName: "Management Agent", isDefault: true),
                ColumnDefinition(key: "OwnerType", displayName: "Owner Type", isDefault: true),
                ColumnDefinition(key: "ManagementState", displayName: "Management State", isDefault: true),
                ColumnDefinition(key: "DeviceRegistrationState", displayName: "Registration State", isDefault: true),
                ColumnDefinition(key: "IsSupervised", displayName: "Is Supervised", isDefault: true),
                ColumnDefinition(key: "IsEncrypted", displayName: "Is Encrypted", isDefault: true),
                ColumnDefinition(key: "OS", displayName: "OS", isDefault: true),
                ColumnDefinition(key: "SkuFamily", displayName: "SKU Family", isDefault: true),
                ColumnDefinition(key: "JoinType", displayName: "Join Type", isDefault: true),
                ColumnDefinition(key: "PhoneNumber", displayName: "Phone Number", isDefault: true),
                ColumnDefinition(key: "JailBroken", displayName: "Jail Broken", isDefault: true),
                ColumnDefinition(key: "ICCID", displayName: "ICCID", isDefault: true),
                ColumnDefinition(key: "EthernetMAC", displayName: "Ethernet MAC", isDefault: true),
                ColumnDefinition(key: "CellularTechnology", displayName: "Cellular Technology", isDefault: true),
                ColumnDefinition(key: "ProcessorArchitecture", displayName: "Processor Architecture", isDefault: true),
                ColumnDefinition(key: "EID", displayName: "EID", isDefault: true),
                ColumnDefinition(key: "EnrollmentType", displayName: "Enrollment Type", isDefault: true),
                ColumnDefinition(key: "PartnerFeaturesBitmask", displayName: "Partner Features Bitmask", isDefault: true),
                ColumnDefinition(key: "ManagementAgents", displayName: "Management Agents", isDefault: true),
                ColumnDefinition(key: "CertExpirationDate", displayName: "Certificate Expiration", isDefault: true),
                ColumnDefinition(key: "IsManaged", displayName: "Is Managed", isDefault: true),
                ColumnDefinition(key: "SystemManagementBIOSVersion", displayName: "BIOS Version", isDefault: true),
                ColumnDefinition(key: "TPMManufacturerId", displayName: "TPM Manufacturer ID", isDefault: true),
                ColumnDefinition(key: "TPMManufacturerVersion", displayName: "TPM Manufacturer Version", isDefault: true)
            ]
        )
        
        // MARK: - Security Reports
        
        reports["ActiveMalware"] = ReportDefinition(
            type: "ActiveMalware",
            displayName: "Malware (Active)",
            description: "Currently active malware threats on managed devices",
            category: "Security",
            supportedColumns: [
                ColumnDefinition(key: "DeviceName", displayName: "Device Name", isDefault: true),
                ColumnDefinition(key: "MalwareName", displayName: "Malware Name", isDefault: true),
                ColumnDefinition(key: "DetectionTime", displayName: "Detection Time", isDefault: true),
                ColumnDefinition(key: "Severity", displayName: "Severity", isDefault: true)
            ]
        )

        reports["AllDeviceCertificates"] = ReportDefinition(
            type: "AllDeviceCertificates",
            displayName: "All Device Certificates",
            description: "Currently active malware threats on managed devices",
            category: "Security",
            intuneConsolePath: "Under Devices > Monitor > Certificates",
            supportedFilters: [
            ],
            supportedColumns: [
                ColumnDefinition(key: "CertificateStatus", displayName: "Certificate Status", isDefault: true),
                ColumnDefinition(key: "DeviceId", displayName: "Device Id", isDefault: true),
                ColumnDefinition(key: "DeviceName", displayName: "Device Name", isDefault: true),
                ColumnDefinition(key: "EnhancedKeyUsage", displayName: "Enhanced Key Usage", isDefault: true),
                ColumnDefinition(key: "IssuerName", displayName: "Issuer Name", isDefault: true),
                ColumnDefinition(key: "KeyUsage", displayName: "Key Usage", isDefault: true),
                ColumnDefinition(key: "PolicyId", displayName: "Policy Id", isDefault: true),
                ColumnDefinition(key: "SerialNumber", displayName: "Serial Number", isDefault: true),
                ColumnDefinition(key: "SubjectName", displayName: "Subject Name", isDefault: true),
                ColumnDefinition(key: "Thumbprint", displayName: "Thumbprint", isDefault: true),
                ColumnDefinition(key: "UPN", displayName: "UPN", isDefault: true),
                ColumnDefinition(key: "UserId", displayName: "User Id", isDefault: true),
                ColumnDefinition(key: "ValidFrom", displayName: "Valid From", isDefault: true),
                ColumnDefinition(key: "ValidTo", displayName: "Valid To", isDefault: true)
            ]
        )

        reports["CertificatesByRAPolicy"] = ReportDefinition(
            type: "CertificatesByRAPolicy",
            displayName: "Certificates By RA Policy",
            description: "Certificates By RA Policy",
            category: "Security",
            intuneConsolePath: "Under Devices > Monitor > Certificates",
            supportedFilters: [
            ],
            supportedColumns: [
                ColumnDefinition(key: "CaConfiguration", displayName: "CA Configuration", isDefault: true),
                ColumnDefinition(key: "CertificateStatus", displayName: "Certificate Status", isDefault: true),
                ColumnDefinition(key: "DeviceId", displayName: "Device Id", isDefault: true),
                ColumnDefinition(key: "DeviceName", displayName: "Device Name", isDefault: true),
                ColumnDefinition(key: "EnhancedKeyUsage", displayName: "Enhanced Key Usage", isDefault: true),
                ColumnDefinition(key: "IssuerName", displayName: "Issuer Name", isDefault: true),
                ColumnDefinition(key: "KeyUsage", displayName: "Key Usage", isDefault: true),
                ColumnDefinition(key: "PolicyId", displayName: "Policy Id", isDefault: true),
                ColumnDefinition(key: "SerialNumber", displayName: "Serial Number", isDefault: true),
                ColumnDefinition(key: "SubjectName", displayName: "Subject Name", isDefault: true),
                ColumnDefinition(key: "Thumbprint", displayName: "Thumbprint", isDefault: true),
                ColumnDefinition(key: "UPN", displayName: "UPN", isDefault: true),
                ColumnDefinition(key: "UserId", displayName: "User Id", isDefault: true),
                ColumnDefinition(key: "ValidFrom", displayName: "Valid From", isDefault: true),
                ColumnDefinition(key: "ValidTo", displayName: "Valid To", isDefault: true)
            ]
        )

        reports["DefenderAgents"] = ReportDefinition(
            type: "DefenderAgents",
            displayName: "Defender Agents",
            description: "Microsoft Defender Antivirus status and protection information for managed devices. Shows real-time protection status, scan history, and threat detection capabilities.",
            category: "Security",
            intuneConsolePath: "Endpoint security > Antivirus > Reports",
            supportedFilters: [
                FilterDefinition(key: "DeviceState", displayName: "Device State", type: .dropdown,
                               options: ["All", "Active", "Inactive"]),
                FilterDefinition(key: "SignatureUpdateOverdue", displayName: "Signature Update Overdue", type: .dropdown,
                               options: ["All", "True", "False"]),
                FilterDefinition(key: "MalwareProtectionEnabled", displayName: "Malware Protection Enabled", type: .dropdown,
                               options: ["All", "True", "False"]),
                FilterDefinition(key: "RealTimeProtectionEnabled", displayName: "Real Time Protection Enabled", type: .dropdown,
                               options: ["All", "True", "False"]),
                FilterDefinition(key: "NetworkInspectionSystemEnabled", displayName: "Network Inspection System Enabled", type: .dropdown,
                               options: ["All", "True", "False"])
            ],
            supportedColumns: [
                ColumnDefinition(key: "DeviceId", displayName: "Device ID", isDefault: true),
                ColumnDefinition(key: "DeviceName", displayName: "Device Name", isDefault: true),
                ColumnDefinition(key: "DeviceState", displayName: "Device State", isDefault: true),
                ColumnDefinition(key: "PendingFullScan", displayName: "Pending Full Scan", isDefault: true),
                ColumnDefinition(key: "PendingReboot", displayName: "Pending Reboot", isDefault: true),
                ColumnDefinition(key: "PendingManualSteps", displayName: "Pending Manual Steps", isDefault: true),
                ColumnDefinition(key: "PendingOfflineScan", displayName: "Pending Offline Scan", isDefault: true),
                ColumnDefinition(key: "CriticalFailure", displayName: "Critical Failure", isDefault: true),
                ColumnDefinition(key: "MalwareProtectionEnabled", displayName: "Malware Protection Enabled", isDefault: true),
                ColumnDefinition(key: "RealTimeProtectionEnabled", displayName: "Real Time Protection Enabled", isDefault: true),
                ColumnDefinition(key: "NetworkInspectionSystemEnabled", displayName: "Network Inspection System Enabled", isDefault: true),
                ColumnDefinition(key: "SignatureUpdateOverdue", displayName: "Signature Update Overdue", isDefault: true),
                ColumnDefinition(key: "QuickScanOverdue", displayName: "Quick Scan Overdue", isDefault: true),
                ColumnDefinition(key: "FullScanOverdue", displayName: "Full Scan Overdue", isDefault: true),
                ColumnDefinition(key: "RebootRequired", displayName: "Reboot Required", isDefault: true),
                ColumnDefinition(key: "FullScanRequired", displayName: "Full Scan Required", isDefault: true),
                ColumnDefinition(key: "EngineVersion", displayName: "Engine Version", isDefault: true),
                ColumnDefinition(key: "SignatureVersion", displayName: "Signature Version", isDefault: true),
                ColumnDefinition(key: "AntiMalwareVersion", displayName: "Anti Malware Version", isDefault: true),
                ColumnDefinition(key: "LastQuickScanDateTime", displayName: "Last Quick Scan", isDefault: true),
                ColumnDefinition(key: "LastFullScanDateTime", displayName: "Last Full Scan", isDefault: true),
                ColumnDefinition(key: "LastQuickScanSignatureVersion", displayName: "Last Quick Scan Signature", isDefault: true),
                ColumnDefinition(key: "LastFullScanSignatureVersion", displayName: "Last Full Scan Signature", isDefault: true),
                ColumnDefinition(key: "LastReportedDateTime", displayName: "Last Reported", isDefault: true),
                ColumnDefinition(key: "UPN", displayName: "UPN", isDefault: true),
                ColumnDefinition(key: "UserEmail", displayName: "User Email", isDefault: true),
                ColumnDefinition(key: "UserName", displayName: "User Name", isDefault: true)
            ]
        )
        
        reports["EpmAggregationReportByApplicationV2"] = ReportDefinition(
            type: "EpmAggregationReportByApplicationV2",
            displayName: "Endpoint Privilege Management Aggregation report by application V2",
            description: "See all elevations, both managed and unmanaged by application",
            category: "Security",
            intuneConsolePath: "Under Endpoint security > Manage > Endpoint Privilege Management > Elevation report by applications",
            supportedFilters: [
            ],
            supportedColumns: [
                ColumnDefinition(key: "CompanyName", displayName: "Company Name", isDefault: true),
                ColumnDefinition(key: "ElevationCount", displayName: "Elevation Count", isDefault: true),
                ColumnDefinition(key: "ElevationType", displayName: "Elevation Type", isDefault: true),
                ColumnDefinition(key: "FileName", displayName: "File Name", isDefault: true),
                ColumnDefinition(key: "FileVersion", displayName: "File Version", isDefault: true),
                ColumnDefinition(key: "Hash", displayName: "Hash", isDefault: true),
                ColumnDefinition(key: "InternalName", displayName: "Internal Name", isDefault: true),
                ColumnDefinition(key: "IsBackgroundProcess", displayName: "Is Background Process", isDefault: true)
            ]
        )

        reports["EpmAggregationReportByPublisher"] = ReportDefinition(
            type: "EpmAggregationReportByPublisher",
            displayName: "Endpoint Privilege Management Aggregation Report By Publisher",
            description: "See number of elevations by publisher",
            category: "Security",
            intuneConsolePath: "Under Endpoint security > Manage > Endpoint Privilege Management > Elevation report by publisher",
            supportedFilters: [
            ],
            supportedColumns: [
                ColumnDefinition(key: "CompanyName", displayName: "Company Name", isDefault: true),
                ColumnDefinition(key: "ElevationCount", displayName: "Elevation Count", isDefault: true),
                ColumnDefinition(key: "ElevationType", displayName: "Elevation Type", isDefault: true)
            ]
        )

        reports["EpmAggregationReportByPublisherV2"] = ReportDefinition(
            type: "EpmAggregationReportByPublisherV2",
            displayName: "Endpoint Privilege Management Aggregation Report By Publisher V2",
            description: "See number of elevations by publisher V2",
            category: "Security",
            intuneConsolePath: "Under Endpoint security > Manage > Endpoint Privilege Management > Elevation report by publisher",
            supportedFilters: [
            ],
            supportedColumns: [
                ColumnDefinition(key: "CompanyName", displayName: "Company Name", isDefault: true),
                ColumnDefinition(key: "ElevationCount", displayName: "Elevation Count", isDefault: true),
                ColumnDefinition(key: "ElevationType", displayName: "Elevation Type", isDefault: true)
            ]
        )

        reports["EpmAggregationReportByUser"] = ReportDefinition(
            type: "EpmAggregationReportByUser",
            displayName: "Endpoint Privilege Management Aggregation Report User",
            description: "See number of elevations by each user",
            category: "Security",
            intuneConsolePath: "Under Endpoint security > Manage > Endpoint Privilege Management > Elevation report by user",
            supportedFilters: [
            ],
            supportedColumns: [
                ColumnDefinition(key: "ManagedCount", displayName: "Managed Count", isDefault: true),
                ColumnDefinition(key: "TotalCount", displayName: "Total Count", isDefault: true),
                ColumnDefinition(key: "UnmanagedCount", displayName: "Unmanaged Count", isDefault: true),
                ColumnDefinition(key: "Upn", displayName: "Upn", isDefault: true),
            ]
        )

        reports["EpmAggregationReportByUserV2"] = ReportDefinition(
            type: "EpmAggregationReportByUserV2",
            displayName: "Endpoint Privilege Management Aggregation Report User V2",
            description: "See number of elevations by each user",
            category: "Security",
            intuneConsolePath: "Under Endpoint security > Manage > Endpoint Privilege Management > Elevation report by user",
            supportedFilters: [
            ],
            supportedColumns: [
                ColumnDefinition(key: "ManagedCount", displayName: "Managed Count", isDefault: true),
                ColumnDefinition(key: "TotalCount", displayName: "Total Count", isDefault: true),
                ColumnDefinition(key: "UnmanagedCount", displayName: "Unmanaged Count", isDefault: true),
                ColumnDefinition(key: "Upn", displayName: "Upn", isDefault: true),
            ]
        )

        reports["EpmAggregationReportByUserAppByMonth"] = ReportDefinition(
            type: "EpmAggregationReportByUserAppByMonth",
            displayName: "Endpoint Privilege Management Aggregation Report By User App By Month",
            description: "See number of elevations by user by month",
            category: "Security",
            intuneConsolePath: "Under Endpoint security > Manage > Endpoint Privilege Management > Elevation report by user",
            supportedFilters: [
            ],
            supportedColumns: [
                ColumnDefinition(key: "DeviceId", displayName: "Device Id", isDefault: true),
                ColumnDefinition(key: "DeviceName", displayName: "Device Name", isDefault: true),
                ColumnDefinition(key: "ElevationType", displayName: "Elevation Type", isDefault: true),
                ColumnDefinition(key: "FileDescription", displayName: "File Description", isDefault: true),
                ColumnDefinition(key: "FileInternalName", displayName: "File Internal Name", isDefault: true),
                ColumnDefinition(key: "FileName", displayName: "File Name", isDefault: true),
                ColumnDefinition(key: "FileProductName", displayName: "File Product Name", isDefault: true),
                ColumnDefinition(key: "FileVersion", displayName: "File Version", isDefault: true),
                ColumnDefinition(key: "HashValue", displayName: "Hash Value", isDefault: true),
                ColumnDefinition(key: "MonthElevationCount", displayName: "Month Elevation Count", isDefault: true),
                ColumnDefinition(key: "Publisher", displayName: "Publisher", isDefault: true),
                ColumnDefinition(key: "UserName", displayName: "User Name", isDefault: true)
            ]
        )

        reports["EpmDeniedReport"] = ReportDefinition(
            type: "EpmDeniedReport",
            displayName: "Endpoint Privilege Management Denied Report",
            description: "See denied elevations",
            category: "Security",
            intuneConsolePath: "Under Endpoint security > Manage > Endpoint Privilege Management > Elevation report",
            supportedFilters: [
            ],
            supportedColumns: [
                ColumnDefinition(key: "UserName", displayName: "User Name", isDefault: true),
                ColumnDefinition(key: "DeviceId", displayName: "Device Id", isDefault: true),
                ColumnDefinition(key: "DeviceName", displayName: "Device Name", isDefault: true),
                ColumnDefinition(key: "FileName", displayName: "File Name", isDefault: true),
                ColumnDefinition(key: "FileProductName", displayName: "File Product Name", isDefault: true),
                ColumnDefinition(key: "FileDescription", displayName: "File Description", isDefault: true),
                ColumnDefinition(key: "FileInternalName", displayName: "File Internal Name", isDefault: true),
                ColumnDefinition(key: "FileVersion", displayName: "File Version", isDefault: true),
                ColumnDefinition(key: "HashValue", displayName: "Hash Value", isDefault: true),
                ColumnDefinition(key: "Publisher", displayName: "Publisher", isDefault: true),
                ColumnDefinition(key: "ElevationType", displayName: "Elevation Type", isDefault: true),
                ColumnDefinition(key: "MonthElevationCount", displayName: "Month Elevation Count", isDefault: true)
            ]
        )

        reports["FirewallStatus"] = ReportDefinition(
            type: "FirewallStatus",
            displayName: "Firewall Status",
            description: "Windows firewall status across managed devices",
            category: "Security",
            supportedFilters: [
                FilterDefinition(key: "firewallStatus", displayName: "Firewall Status", type: .dropdown,
                               options: ["All", "On", "Off", "Not Configured"])
            ],
            supportedColumns: [
                ColumnDefinition(key: "DeviceName", displayName: "Device Name", isDefault: true),
                ColumnDefinition(key: "FirewallStatus", displayName: "Firewall Status", isDefault: true),
                ColumnDefinition(key: "DomainProfile", displayName: "Domain Profile", isDefault: true),
                ColumnDefinition(key: "PrivateProfile", displayName: "Private Profile", isDefault: true),
                ColumnDefinition(key: "PublicProfile", displayName: "Public Profile", isDefault: true)
            ]
        )
        
        reports["Malware"] = ReportDefinition(
            type: "Malware",
            displayName: "Malware",
            description: "Malware detections across managed devices",
            category: "Security",
            supportedFilters: [
                FilterDefinition(key: "detectionStatus", displayName: "Detection Status", type: .dropdown,
                               options: ["All", "Active", "Cleaned", "Quarantined"])
            ],
            supportedColumns: [
                ColumnDefinition(key: "DeviceName", displayName: "Device Name", isDefault: true),
                ColumnDefinition(key: "MalwareName", displayName: "Malware Name", isDefault: true),
                ColumnDefinition(key: "DetectionTime", displayName: "Detection Time", isDefault: true),
                ColumnDefinition(key: "Status", displayName: "Status", isDefault: true)
            ]
        )
                        
        reports["UnhealthyDefenderAgents"] = ReportDefinition(
            type: "UnhealthyDefenderAgents",
            displayName: "Defender Agents (Unhealthy)",
            description: "Microsoft Defender agents that are not functioning properly",
            category: "Security",
            supportedFilters: [
                FilterDefinition(key: "platform", displayName: "Platform", type: .dropdown,
                               options: ["All", "Windows", "macOS"])
            ],
            supportedColumns: [
                ColumnDefinition(key: "DeviceName", displayName: "Device Name", isDefault: true),
                ColumnDefinition(key: "Issue", displayName: "Issue", isDefault: true),
                ColumnDefinition(key: "LastReportTime", displayName: "Last Report Time", isDefault: true)
            ]
        )
        

        // MARK: - Mobile Application Management Reports
        
        reports["MAMAppConfigurationStatus"] = ReportDefinition(
            type: "MAMAppConfigurationStatus",
            displayName: "MAM App Configuration Status",
            description: "Mobile Application Management app configuration status",
            category: "Mobile Application Management",
            supportedFilters: [
                FilterDefinition(key: "platform", displayName: "Platform", type: .dropdown,
                               options: ["All", "Android", "iOS"]),
                FilterDefinition(key: "configName", displayName: "Configuration Name", type: .text,
                               placeholder: "Enter configuration name")
            ],
            supportedColumns: [
                ColumnDefinition(key: "UserName", displayName: "User Name", isDefault: true),
                ColumnDefinition(key: "AppName", displayName: "App Name", isDefault: true),
                ColumnDefinition(key: "ConfigurationName", displayName: "Configuration Name", isDefault: true),
                ColumnDefinition(key: "Status", displayName: "Status", isDefault: true)
            ]
        )

        reports["MAMAppConfigurationStatusScopedV2"] = ReportDefinition(
            type: "MAMAppConfigurationStatusScopedV2",
            displayName: "MAM App Configuration Status Scoped V2",
            description: "See MAM App Configuration Status Scoped",
            category: "Mobile Application Management",
            intuneConsolePath: "Under Apps > Monitor",
            supportedFilters: [
            ],
            supportedColumns: [
                ColumnDefinition(key: "AADDeviceID", displayName: "AADDevice ID", isDefault: true),
                ColumnDefinition(key: "AndroidMamSdkVersion", displayName: "Android Mam Sdk Version", isDefault: true),
                ColumnDefinition(key: "AndroidSecurityPatchVersion", displayName: "Android Security Patch Version", isDefault: true),
                ColumnDefinition(key: "App", displayName: "App", isDefault: true),
                ColumnDefinition(key: "AppInstanceId", displayName: "App Instance Id", isDefault: true),
                ColumnDefinition(key: "AppVersion", displayName: "App Version", isDefault: true),
                ColumnDefinition(key: "DeviceManufacturer", displayName: "Device Manufacturer", isDefault: true),
                ColumnDefinition(key: "DeviceModel", displayName: "Device Model", isDefault: true),
                ColumnDefinition(key: "DeviceName", displayName: "Device Name", isDefault: true),
                ColumnDefinition(key: "DeviceType", displayName: "Device Type", isDefault: true),
                ColumnDefinition(key: "Email", displayName: "Email", isDefault: true),
                ColumnDefinition(key: "iOSSdkVersion", displayName: "i OSSdk Version", isDefault: true),
                ColumnDefinition(key: "LastSync", displayName: "Last Sync", isDefault: true),
                ColumnDefinition(key: "MDMDeviceID", displayName: "MDMDevice ID", isDefault: true),
                ColumnDefinition(key: "_Platform", displayName: "_Platform", isDefault: true),
                ColumnDefinition(key: "PlatformVersion", displayName: "Platform Version", isDefault: true),
                ColumnDefinition(key: "Policy", displayName: "Policy", isDefault: true),
                ColumnDefinition(key: "User", displayName: "User", isDefault: true)
            ]
        )
        
        reports["MAMAppConfigurationStatusV2"] = ReportDefinition(
            type: "MAMAppConfigurationStatusV2",
            displayName: "MAM App Configuration Status V2",
            description: "See MAM App Configuration Status",
            category: "Mobile Application Management",
            intuneConsolePath: "Under Apps > Monitor",
            supportedFilters: [
            ],
            supportedColumns: [
                ColumnDefinition(key: "AADDeviceID", displayName: "AADDevice ID", isDefault: true),
                ColumnDefinition(key: "AndroidMamSdkVersion", displayName: "Android Mam Sdk Version", isDefault: true),
                ColumnDefinition(key: "AndroidSecurityPatchVersion", displayName: "Android Security Patch Version", isDefault: true),
                ColumnDefinition(key: "App", displayName: "App", isDefault: true),
                ColumnDefinition(key: "AppInstanceId", displayName: "App Instance Id", isDefault: true),
                ColumnDefinition(key: "AppVersion", displayName: "App Version", isDefault: true),
                ColumnDefinition(key: "DeviceManufacturer", displayName: "Device Manufacturer", isDefault: true),
                ColumnDefinition(key: "DeviceModel", displayName: "Device Model", isDefault: true),
                ColumnDefinition(key: "DeviceName", displayName: "Device Name", isDefault: true),
                ColumnDefinition(key: "DeviceType", displayName: "Device Type", isDefault: true),
                ColumnDefinition(key: "Email", displayName: "Email", isDefault: true),
                ColumnDefinition(key: "iOSSdkVersion", displayName: "i OSSdk Version", isDefault: true),
                ColumnDefinition(key: "LastSync", displayName: "Last Sync", isDefault: true),
                ColumnDefinition(key: "MDMDeviceID", displayName: "MDMDevice ID", isDefault: true),
                ColumnDefinition(key: "_Platform", displayName: "_Platform", isDefault: true),
                ColumnDefinition(key: "PlatformVersion", displayName: "Platform Version", isDefault: true),
                ColumnDefinition(key: "Policy", displayName: "Policy", isDefault: true),
                ColumnDefinition(key: "User", displayName: "User", isDefault: true)
            ]
        )
        
        reports["MAMAppProtectionStatus"] = ReportDefinition(
            type: "MAMAppProtectionStatus",
            displayName: "MAM App Protection Status",
            description: "Mobile Application Management app protection policy status",
            category: "Mobile Application Management",
            supportedFilters: [
                FilterDefinition(key: "platform", displayName: "Platform", type: .dropdown,
                                 options: ["All", "Android", "iOS"]),
                FilterDefinition(key: "policyName", displayName: "Policy Name", type: .text,
                                 placeholder: "Enter policy name")
            ],
            supportedColumns: [
                ColumnDefinition(key: "UserName", displayName: "User Name", isDefault: true),
                ColumnDefinition(key: "AppName", displayName: "App Name", isDefault: true),
                ColumnDefinition(key: "PolicyName", displayName: "Policy Name", isDefault: true),
                ColumnDefinition(key: "ComplianceStatus", displayName: "Compliance Status", isDefault: true)
            ]
        )
        
        reports["MAMAppProtectionStatusScopedV2"] = ReportDefinition(
            type: "MAMAppProtectionStatusScopedV2",
            displayName: "MAM App Protection Status Scoped V2",
            description: "See MAM App Protection Status Scoped",
            category: "Mobile Application Management",
            intuneConsolePath: "Under Apps > Monitor",
            supportedFilters: [
            ],
            supportedColumns: [
                ColumnDefinition(key: "AADDeviceID", displayName: "AADDevice ID", isDefault: true),
                ColumnDefinition(key: "AndroidMamSdkVersion", displayName: "Android Mam Sdk Version", isDefault: true),
                ColumnDefinition(key: "AndroidSecurityPatchVersion", displayName: "Android Security Patch Version", isDefault: true),
                ColumnDefinition(key: "App", displayName: "App", isDefault: true),
                ColumnDefinition(key: "AppInstanceId", displayName: "App Instance Id", isDefault: true),
                ColumnDefinition(key: "AppProtectionStatus", displayName: "App Protection Status", isDefault: true),
                ColumnDefinition(key: "AppVersion", displayName: "App Version", isDefault: true),
                ColumnDefinition(key: "ComplianceState", displayName: "Compliance State", isDefault: true),
                ColumnDefinition(key: "DeviceManufacturer", displayName: "Device Manufacturer", isDefault: true),
                ColumnDefinition(key: "DeviceModel", displayName: "Device Model", isDefault: true),
                ColumnDefinition(key: "DeviceName", displayName: "Device Name", isDefault: true),
                ColumnDefinition(key: "DeviceType", displayName: "Device Type", isDefault: true),
                ColumnDefinition(key: "Email", displayName: "Email", isDefault: true),
                ColumnDefinition(key: "iOSSdkVersion", displayName: "i OSSdk Version", isDefault: true),
                ColumnDefinition(key: "LastSync", displayName: "Last Sync", isDefault: true),
                ColumnDefinition(key: "ManagementType", displayName: "Management Type", isDefault: true),
                ColumnDefinition(key: "MDMDeviceID", displayName: "MDMDevice ID", isDefault: true),
                ColumnDefinition(key: "_Platform", displayName: "_Platform", isDefault: true),
                ColumnDefinition(key: "PlatformVersion", displayName: "Platform Version", isDefault: true),
                ColumnDefinition(key: "Policy", displayName: "Policy", isDefault: true),
                ColumnDefinition(key: "User", displayName: "User", isDefault: true)
            ]
        )
        
        reports["MAMAppProtectionStatusV2"] = ReportDefinition(
            type: "MAMAppProtectionStatusV2",
            displayName: "MAM App Protection Status V2",
            description: "See MAM App Protection Status",
            category: "Mobile Application Management",
            intuneConsolePath: "Under Apps > Monitor",
            supportedFilters: [
            ],
            supportedColumns: [
                ColumnDefinition(key: "AADDeviceID", displayName: "AADDevice ID", isDefault: true),
                ColumnDefinition(key: "AndroidMamSdkVersion", displayName: "Android Mam Sdk Version", isDefault: true),
                ColumnDefinition(key: "AndroidSecurityPatchVersion", displayName: "Android Security Patch Version", isDefault: true),
                ColumnDefinition(key: "App", displayName: "App", isDefault: true),
                ColumnDefinition(key: "AppInstanceId", displayName: "App Instance Id", isDefault: true),
                ColumnDefinition(key: "AppProtectionStatus", displayName: "App Protection Status", isDefault: true),
                ColumnDefinition(key: "AppVersion", displayName: "App Version", isDefault: true),
                ColumnDefinition(key: "ComplianceState", displayName: "Compliance State", isDefault: true),
                ColumnDefinition(key: "DeviceManufacturer", displayName: "Device Manufacturer", isDefault: true),
                ColumnDefinition(key: "DeviceModel", displayName: "Device Model", isDefault: true),
                ColumnDefinition(key: "DeviceName", displayName: "Device Name", isDefault: true),
                ColumnDefinition(key: "DeviceType", displayName: "Device Type", isDefault: true),
                ColumnDefinition(key: "Email", displayName: "Email", isDefault: true),
                ColumnDefinition(key: "iOSSdkVersion", displayName: "i OSSdk Version", isDefault: true),
                ColumnDefinition(key: "LastSync", displayName: "Last Sync", isDefault: true),
                ColumnDefinition(key: "ManagementType", displayName: "Management Type", isDefault: true),
                ColumnDefinition(key: "MDMDeviceID", displayName: "MDMDevice ID", isDefault: true),
                ColumnDefinition(key: "_Platform", displayName: "_Platform", isDefault: true),
                ColumnDefinition(key: "PlatformVersion", displayName: "Platform Version", isDefault: true),
                ColumnDefinition(key: "Policy", displayName: "Policy", isDefault: true),
                ColumnDefinition(key: "User", displayName: "User", isDefault: true)
            ]
        )

        // MARK: - Update Management Reports
        
        reports["DriverUpdatePolicyStatusSummary"] = ReportDefinition(
            type: "DriverUpdatePolicyStatusSummary",
            displayName: "Driver Update Policy Status Summary",
            description: "Driver update policy status summary",
            category: "Update Management",
            intuneConsolePath: "Under Devices > Manage updates > Windows updates > Driver updates",
            supportedFilters: [
            ],
            supportedColumns: [
                ColumnDefinition(key: "CountDevicesCancelledStatus", displayName: "Count Devices Cancelled Status", isDefault: true),
                ColumnDefinition(key: "CountDevicesErrorStatus", displayName: "Count Devices Error Status", isDefault: true),
                ColumnDefinition(key: "CountDevicesInProgressStatus", displayName: "Count Devices In Progress Status", isDefault: true),
                ColumnDefinition(key: "CountDevicesSuccessStatus", displayName: "Count Devices Success Status", isDefault: true),
                ColumnDefinition(key: "CountOfNeedsReviewDrivers", displayName: "Count Of Needs Review Drivers", isDefault: true),
                ColumnDefinition(key: "CountOfPausedDrivers", displayName: "Count Of Paused Drivers", isDefault: true),
                ColumnDefinition(key: "PolicyId", displayName: "Policy Id", isDefault: true),
                ColumnDefinition(key: "PolicyName", displayName: "Policy Name", isDefault: true)
            ]
        )

        reports["FeatureUpdatePolicyFailuresAggregate"] = ReportDefinition(
            type: "FeatureUpdatePolicyFailuresAggregate",
            displayName: "Feature Update Policy Failures",
            description: "Aggregated view of Windows feature update policy failures",
            category: "Update Management",
            supportedFilters: [
                FilterDefinition(key: "policyName", displayName: "Policy Name", type: .text,
                               placeholder: "Enter policy name")
            ],
            supportedColumns: [
                ColumnDefinition(key: "PolicyName", displayName: "Policy Name", isDefault: true),
                ColumnDefinition(key: "FailureCount", displayName: "Failure Count", isDefault: true),
                ColumnDefinition(key: "DeviceCount", displayName: "Device Count", isDefault: true),
                ColumnDefinition(key: "FailurePercentage", displayName: "Failure Percentage", isDefault: true)
            ]
        )
        
        reports["QualityUpdateDeviceErrorsByPolicy"] = ReportDefinition(
            type: "QualityUpdateDeviceErrorsByPolicy",
            displayName: "Quality Update Device Errors By Policy",
            description: "See Quality Update Device Errors By Policy",
            category: "Update Management",
            intuneConsolePath: "Under Devices > Monitor > Windows Expedited update failures > Select a profile",
            supportedFilters: [
                FilterDefinition(key: "AlertMessage", displayName: "Alert Message", type: .text),
                FilterDefinition(key: "PolicyId", displayName: "Policy Id", type: .text, isRequired: true)
            ],
            supportedColumns: [
                ColumnDefinition(key: "AlertMessage", displayName: "Alert Message", isDefault: true),
                ColumnDefinition(key: "AlertMessage_loc", displayName: "Alert Message_loc", isDefault: true),
                ColumnDefinition(key: "DeviceId", displayName: "Device Id", isDefault: true),
                ColumnDefinition(key: "DeviceName", displayName: "Device Name", isDefault: true),
                ColumnDefinition(key: "ExpediteQUReleaseDate", displayName: "Expedite QURelease Date", isDefault: true),
                ColumnDefinition(key: "PolicyId", displayName: "Policy Id", isDefault: true),
                ColumnDefinition(key: "UPN", displayName: "UPN", isDefault: true),
                ColumnDefinition(key: "Win32ErrorCode", displayName: "Win32Error Code", isDefault: true)
            ],
            requiredParameters: ["PolicyId"]
        )

        reports["QualityUpdateDeviceStatusByPolicy"] = ReportDefinition(
            type: "QualityUpdateDeviceStatusByPolicy",
            displayName: "Quality Update Device Status By Policy",
            description: "See Quality Update Device Status By Policy",
            category: "Update Management",
            intuneConsolePath: "Under Reports > Windows updates > Reports > Windows Expedited Update Report",
            supportedFilters: [
                FilterDefinition(key: "AggregateState", displayName: "Aggregate State", type: .text),
                FilterDefinition(key: "OwnerType", displayName: "Owner Type", type: .text),
                FilterDefinition(key: "PolicyId", displayName: "Policy Id", type: .text, isRequired: true)
            ],
            supportedColumns: [
                ColumnDefinition(key: "AADDeviceId", displayName: "AADDevice Id", isDefault: true),
                ColumnDefinition(key: "AggregateState", displayName: "Aggregate State", isDefault: true),
                ColumnDefinition(key: "AggregateState_loc", displayName: "Aggregate State_loc", isDefault: true),
                ColumnDefinition(key: "CurrentDeviceUpdateStatus", displayName: "Current Device Update Status", isDefault: true),
                ColumnDefinition(key: "CurrentDeviceUpdateStatus_loc", displayName: "Current Device Update Status_loc", isDefault: true),
                ColumnDefinition(key: "CurrentDeviceUpdateSubstatus", displayName: "Current Device Update Substatus", isDefault: true),
                ColumnDefinition(key: "CurrentDeviceUpdateSubstatus_loc", displayName: "Current Device Update Substatus_loc", isDefault: true),
                ColumnDefinition(key: "DeviceId", displayName: "Device Id", isDefault: true),
                ColumnDefinition(key: "DeviceName", displayName: "Device Name", isDefault: true),
                ColumnDefinition(key: "EventDateTimeUTC", displayName: "Event Date Time UTC", isDefault: true),
                ColumnDefinition(key: "LastWUScanTimeUTC", displayName: "Last WUScan Time UTC", isDefault: true),
                ColumnDefinition(key: "LatestAlertMessage", displayName: "Latest Alert Message", isDefault: true),
                ColumnDefinition(key: "LatestAlertMessage_loc", displayName: "Latest Alert Message_loc", isDefault: true),
                ColumnDefinition(key: "OwnerType", displayName: "Owner Type", isDefault: true),
                ColumnDefinition(key: "PolicyId", displayName: "Policy Id", isDefault: true),
                ColumnDefinition(key: "UPN", displayName: "UPN", isDefault: true)
            ],
            requiredParameters: ["PolicyId"]
        )

        reports["QualityUpdatePolicyStatusSummary"] = ReportDefinition(
            type: "QualityUpdatePolicyStatusSummary",
            displayName: "Quality Update Policy Status Summary",
            description: "See Quality Update Policy Summary",
            category: "Update Management",
            intuneConsolePath: "Under Reports > Device management > Windows updates",
            supportedFilters: [
            ],
            supportedColumns: [
                ColumnDefinition(key: "CountDevicesErrorStatus", displayName: "Count Devices Error Status", isDefault: true),
                ColumnDefinition(key: "CountDevicesInProgressStatus", displayName: "Count Devices In Progress Status", isDefault: true),
                ColumnDefinition(key: "CountDevicesSuccessStatus", displayName: "Count Devices Success Status", isDefault: true),
                ColumnDefinition(key: "ExpediteQUReleaseDate", displayName: "Expedite QURelease Date", isDefault: true),
                ColumnDefinition(key: "PolicyId", displayName: "Policy Id", isDefault: true),
                ColumnDefinition(key: "PolicyName", displayName: "Policy Name", isDefault: true)
            ]
        )

        reports["WindowsUpdatePerPolicyPerDeviceStatus"] = ReportDefinition(
            type: "WindowsUpdatePerPolicyPerDeviceStatus",
            displayName: "Windows Update Per Policy Per Device Status",
            description: "See Windows Update per Policy per Device Status",
            category: "Update Management",
            intuneConsolePath: "Under Devices > Manage updates > Windows updates",
            supportedFilters: [
            ],
            supportedColumns: [
                ColumnDefinition(key: "AggregateState", displayName: "Aggregate State", isDefault: true),
                ColumnDefinition(key: "CurrentDeviceUpdateStatus", displayName: "Current Device Update Status", isDefault: true),
                ColumnDefinition(key: "DeviceId", displayName: "Device Id", isDefault: true),
                ColumnDefinition(key: "DeviceName", displayName: "Device Name", isDefault: true),
                ColumnDefinition(key: "LatestAlertMessage", displayName: "Latest Alert Message", isDefault: true),
                ColumnDefinition(key: "PolicyId", displayName: "Policy Id", isDefault: true),
                ColumnDefinition(key: "UPN", displayName: "UPN", isDefault: true)
            ]
        )

        // MARK: - User Reports
        reports["Users"] = ReportDefinition(
            type: "Users",
            displayName: "Users",
            description: "See all Users",
            category: "Users",
            intuneConsolePath: "Under Users",
            supportedFilters: [
            ],
            supportedColumns: [
                ColumnDefinition(key: "UPN", displayName: "UPN", isDefault: true),
                ColumnDefinition(key: "UserEmail", displayName: "User Email", isDefault: true),
                ColumnDefinition(key: "UserId", displayName: "User Id", isDefault: true),
                ColumnDefinition(key: "UserName", displayName: "User Name", isDefault: true)
            ]
        )

    }
}
