# ReportRegistry Documentation

The `ReportRegistry` is a centralized system for managing all available Intune reports. It provides metadata, filter definitions, and validation for report generation, serving as the single source of truth for report configurations.

## Table of Contents
- [Overview](#overview)
- [Data Structures](#data-structures)
- [FilterDefinition](#filterdefinition)
- [ColumnDefinition](#columndefinition)
- [ReportDefinition](#reportdefinition)
- [Usage Examples](#usage-examples)
- [Microsoft API Compatibility](#microsoft-api-compatibility)
- [Adding New Reports](#adding-new-reports)

## Overview

The ReportRegistry replaces hardcoded report lists throughout the application and provides:
- Centralized report metadata management
- Filter and column definitions for each report type
- Parameter validation (including required parameters)
- Microsoft Graph API compatibility
- Scalable architecture for 150+ report types

## Data Structures

### FilterDefinition

Defines a filter parameter that can be applied to a report.

```swift
struct FilterDefinition {
    let key: String           // Microsoft API parameter name (PascalCase)
    let displayName: String   // Human-readable name for UI
    let type: FilterType      // Type of filter control
    let isRequired: Bool      // Whether this parameter is mandatory
    let options: [String]?    // Available options for dropdown filters
    let placeholder: String?  // Placeholder text for text inputs
}
```

#### FilterType Options

| Type | Description | UI Control | Example |
|------|-------------|------------|---------|
| `.text` | Free text input | NSTextField | Device name, app name |
| `.dropdown` | Selection from predefined options | NSPopUpButton | Platform, compliance state |
| `.boolean` | True/false selection | NSButton (checkbox) | Enabled/disabled |
| `.deviceId` | Device identifier (special validation) | NSTextField | Device GUID |
| `.userId` | User identifier | NSTextField | User GUID |
| `.date` | Date selection | NSDatePicker | Date ranges |

#### Filter Examples

```swift
// Required device ID parameter
FilterDefinition(
    key: "DeviceId", 
    displayName: "Device ID", 
    type: .deviceId, 
    isRequired: true,
    placeholder: "Enter device ID (required)"
)

// Optional platform dropdown
FilterDefinition(
    key: "Platform", 
    displayName: "Platform", 
    type: .dropdown,
    options: ["All", "Android", "iOS", "macOS", "Windows"]
)

// Optional text search
FilterDefinition(
    key: "ApplicationName", 
    displayName: "Application Name", 
    type: .text,
    placeholder: "Enter application name"
)
```

### ColumnDefinition

Defines a data column that can be included in report output.

```swift
struct ColumnDefinition {
    let key: String         // Microsoft API column name (PascalCase)
    let displayName: String // Human-readable column name
    let isDefault: Bool     // Whether included in default column set
}
```

#### isDefault Behavior

- **`true`**: Column is automatically included when generating reports
- **`false`**: Column is available but must be explicitly requested by user

#### Column Selection Logic

```swift
// Default columns (isDefault: true) - automatically included
let defaultColumns = reportDef.supportedColumns
    .filter { $0.isDefault }
    .map { $0.key }
// Result: ["DeviceName", "ApplicationName", "Platform"]

// All available columns - for user selection UI
let allColumns = reportDef.supportedColumns.map { $0.key }
// Result: ["DeviceName", "ApplicationName", "Platform", "OSVersion", "LastSync"]
```

#### Column Examples

```swift
// Essential column (always included)
ColumnDefinition(key: "DeviceName", displayName: "Device Name", isDefault: true)

// Optional detail column (user can add)
ColumnDefinition(key: "OSVersion", displayName: "OS Version", isDefault: false)

// Key identifier (usually default)
ColumnDefinition(key: "ApplicationId", displayName: "Application ID", isDefault: true)
```

### ReportDefinition

Complete definition of a report type with all its metadata and capabilities.

```swift
struct ReportDefinition {
    let type: String                        // Internal report type identifier
    let displayName: String                 // User-friendly report name
    let description: String                 // Detailed description
    let category: String                    // Report category for organization
    let intuneConsolePath: String?          // Path to find report in Intune Console
    let supportedFilters: [FilterDefinition] // Available filter parameters
    let supportedColumns: [ColumnDefinition] // Available output columns
    let requiredParameters: [String]        // Keys of mandatory filters
    let supportsCSV: Bool                   // Whether CSV export is supported
    let supportsJSON: Bool                  // Whether JSON export is supported
}
```

#### Report Categories

| Category | Purpose | Examples |
|----------|---------|----------|
| `"Application Management"` | App deployment and inventory | AllAppsList, AppInventory |
| `"Device Management"` | Device compliance and info | Devices, DeviceCompliance |
| `"Security"` | Security status and threats | DefenderAgents, Malware |
| `"Mobile Application Management"` | MAM policies and status | MAMAppProtection |
| `"Update Management"` | OS and app updates | FeatureUpdatePolicyFailures |

#### Intune Console Path

The optional `intuneConsolePath` field provides the navigation path to find the equivalent report in the Intune web console:

```swift
ReportDefinition(
    type: "Devices",
    displayName: "Devices", 
    description: "Complete list of all devices managed by Intune...",
    category: "Device Management",
    intuneConsolePath: "Devices > All devices"  // Shows where to find in console
)
```

**Tooltip Example:**
```
Complete list of all devices managed by Intune, including enrollment status, compliance state, and basic device information. Use this report for device inventory and management overview.

Intune Console Location:
Devices > All devices
```

#### Required Parameters

The `requiredParameters` array contains the `key` values from `supportedFilters` that must be provided:

```swift
// Report that requires a specific device
ReportDefinition(
    type: "AppInvByDevice",
    // ...
    supportedFilters: [
        FilterDefinition(key: "DeviceId", displayName: "Device ID", 
                        type: .deviceId, isRequired: true)
    ],
    requiredParameters: ["DeviceId"]  // Must match filter key
)
```

## Usage Examples

### Getting Report Information

```swift
let registry = ReportRegistry.shared

// Get all available reports
let allReports = registry.getAllReports()

// Get reports by category
let deviceReports = registry.getReportsForCategory("Device Management")

// Get specific report definition
if let deviceReport = registry.getReportDefinition(for: "Devices") {
    print("Report: \(deviceReport.displayName)")
    print("Required params: \(deviceReport.requiredParameters)")
}
```

### Validating Parameters

```swift
// Validate report parameters before submission
let parameters = ["DeviceId": "12345-67890-abcdef"]
let reportType = "AppInvByDevice"

if let error = registry.validateReportParameters(parameters, for: reportType) {
    print("Validation failed: \(error)")
} else {
    print("Parameters are valid")
}
```

### Building UI Controls

```swift
// Create filter controls from definition
func createFilterControls(for reportType: String) {
    guard let report = registry.getReportDefinition(for: reportType) else { return }
    
    for filter in report.supportedFilters {
        switch filter.type {
        case .dropdown:
            let popup = NSPopUpButton()
            popup.addItems(withTitles: filter.options ?? [])
            // Add required indicator if filter.isRequired
            
        case .text:
            let textField = NSTextField()
            textField.placeholderString = filter.placeholder
            // Add validation if filter.isRequired
            
        case .deviceId:
            let textField = NSTextField()
            textField.placeholderString = filter.placeholder
            // Add device ID validation
        }
    }
}
```

### Column Selection UI

```swift
// Create column selection interface
func setupColumnSelection(for reportType: String) {
    guard let report = registry.getReportDefinition(for: reportType) else { return }
    
    // Default columns (pre-selected)
    let defaultColumns = report.supportedColumns.filter { $0.isDefault }
    
    // Optional columns (user can add)
    let optionalColumns = report.supportedColumns.filter { !$0.isDefault }
    
    // Create checkboxes for column selection
    for column in report.supportedColumns {
        let checkbox = NSButton(checkboxWithTitle: column.displayName, target: self, action: #selector(columnSelectionChanged))
        checkbox.state = column.isDefault ? .on : .off
        checkbox.tag = // column index
    }
}
```

## Microsoft API Compatibility

### Parameter Naming Convention

Microsoft Graph API requires **PascalCase** parameter names:

| ✅ Correct | ❌ Incorrect | Usage |
|------------|--------------|-------|
| `DeviceId` | `deviceId` | Device filters |
| `ApplicationName` | `applicationName` | App filters |
| `Platform` | `platform` | Platform filters |
| `UserName` | `userName` | User filters |
| `OSVersion` | `osVersion` | OS filters |

### Filter Construction

Parameters are converted to Microsoft's OData filter format:

```swift
// Registry definition
FilterDefinition(key: "DeviceId", displayName: "Device ID", type: .deviceId)

// Becomes API filter
"DeviceId eq 'actual-device-guid-here'"

// Multiple filters
"Platform eq 'Windows' and ComplianceState eq 'Compliant'"
```

### Column Selection

Column keys must match Microsoft's API exactly:

```swift
// Default columns for API request
let includeColumns = [
    "DeviceName",           // Not "deviceName"
    "ApplicationName",      // Not "applicationName" 
    "Platform",            // Not "platform"
    "ComplianceState"      // Not "complianceState"
]
```

## Adding New Reports

### Step 1: Research Microsoft's API

Check Microsoft Graph API documentation for:
- Exact parameter names (case-sensitive)
- Required vs optional parameters
- Available columns
- Supported formats

### Step 2: Add to Registry

```swift
// Add new report definition
reports["NewReportType"] = ReportDefinition(
    type: "NewReportType",
    displayName: "Human Readable Name",
    description: "What this report provides",
    category: "Appropriate Category",
    supportedFilters: [
        // Add filter definitions with exact Microsoft parameter names
        FilterDefinition(key: "RequiredParam", displayName: "Required Parameter", 
                        type: .text, isRequired: true),
        FilterDefinition(key: "OptionalParam", displayName: "Optional Parameter", 
                        type: .dropdown, options: ["Option1", "Option2"])
    ],
    supportedColumns: [
        // Add column definitions with exact Microsoft column names
        ColumnDefinition(key: "EssentialColumn", displayName: "Essential Data", isDefault: true),
        ColumnDefinition(key: "DetailColumn", displayName: "Optional Detail", isDefault: false)
    ],
    requiredParameters: ["RequiredParam"]  // Must match filter keys
)
```

### Step 3: Test and Validate

1. Verify parameter names match Microsoft's API exactly
2. Test required parameter validation
3. Confirm column selection works correctly
4. Validate with actual API calls

## Best Practices

### Naming Conventions

- **Registry keys**: Use exact Microsoft API names (PascalCase)
- **Display names**: Use human-friendly titles (Title Case)
- **Descriptions**: Clear, concise explanations of report purpose
- **Categories**: Consistent grouping for related reports

### Required Parameters

- Always mark truly required parameters with `isRequired: true`
- Include all required parameter keys in `requiredParameters` array
- Provide helpful placeholder text for required fields
- Use appropriate filter types (`.deviceId`, `.userId` for special validation)

### Column Defaults

- Mark essential columns as `isDefault: true`
- Keep default column count reasonable (4-6 columns)
- Include key identifiers in default set
- Make detailed/debugging columns optional

### Filter Design

- Provide reasonable default options for dropdowns
- Use clear, descriptive placeholder text
- Consider user workflow when designing filter combinations
- Validate filter dependencies where applicable

## Migration from Hardcoded Lists

### Before (Hardcoded)
```swift
// IntuneReportsViewController
let reportTypes = [
    ("Devices", "Devices"),
    ("DeviceCompliance", "Device Compliance"),
    // ... more hardcoded entries
]
```

### After (Registry-based)
```swift
// Any controller
let reportTypes = ReportRegistry.shared.getReportTypesAndNames()
// Automatically includes all reports with proper metadata
```

This approach provides scalability, maintainability, and consistency across the entire application while ensuring Microsoft API compatibility.