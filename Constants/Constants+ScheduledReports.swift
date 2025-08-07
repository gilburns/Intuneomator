//
//  Constants+ScheduledReports.swift
//  Intuneomator
//
//  Created by Gil Burns on 7/25/25.
//

import Foundation

// MARK: - Scheduled Report Data Models

/// Represents a scheduled report configuration
struct ScheduledReport: Codable {
    let id: UUID
    var name: String
    var description: String?
    var reportType: String
    var reportDisplayName: String
    var format: String // "csv" or "json"
    var filters: [String: String]
    var selectedColumns: [String]? // Column keys to include (nil = use defaults)
    var schedule: ScheduleConfiguration
    var delivery: DeliveryConfiguration
    var notifications: NotificationConfiguration
    var isEnabled: Bool
    var created: Date
    var modified: Date
    var lastRun: Date?
    var nextRun: Date?
    var lastRunResult: RunResult?
    
    init(name: String, reportType: String, reportDisplayName: String, format: String = "csv") {
        self.id = UUID()
        self.name = name
        self.reportType = reportType
        self.reportDisplayName = reportDisplayName
        self.format = format
        self.filters = [:]
        self.selectedColumns = nil // Use defaults initially
        self.schedule = ScheduleConfiguration()
        self.delivery = DeliveryConfiguration()
        self.notifications = NotificationConfiguration()
        self.isEnabled = true
        self.created = Date()
        self.modified = Date()
        // Calculate initial next run time
        self.nextRun = self.schedule.calculateNextRun(from: Date())
    }
    
    /// Updates the modified date when the schedule is changed
    mutating func markAsModified() {
        self.modified = Date()
    }
    
    /// Updates run tracking information
    mutating func updateRunResult(_ result: RunResult) {
        self.lastRun = Date()
        self.lastRunResult = result
        self.nextRun = schedule.calculateNextRun(from: Date())
        markAsModified()
    }
    
    /// Gets a human-readable description of the schedule
    var scheduleDescription: String {
        return schedule.humanReadableDescription
    }
    
    /// Gets the file name for storing this schedule
    var fileName: String {
        return "\(id.uuidString).json"
    }
}

/// Configuration for when and how often a report should run
struct ScheduleConfiguration: Codable {
    var frequency: ScheduleFrequency
    var timeOfDay: String // "09:00" format
    var timeZone: TimeZone
    var dayOfWeek: Int? // 1-7 (Sunday = 1) for weekly schedules  
    var dayOfMonth: Int? // 1-31 for monthly schedules
    var startDate: Date
    var endDate: Date?
    
    init() {
        self.frequency = .weekly
        self.timeOfDay = "09:00"
        self.timeZone = TimeZone.current
        self.startDate = Date()
    }
    
    /// Calculates the next run date based on the schedule configuration
    func calculateNextRun(from currentDate: Date) -> Date? {
        // Create a calendar configured for the report's time zone
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        
        // Get date components in the report's time zone  
        var components = calendar.dateComponents([.year, .month, .day], from: currentDate)
        
        // Parse time of day
        let timeParts = timeOfDay.split(separator: ":")
        guard timeParts.count == 2,
              let hour = Int(timeParts[0]),
              let minute = Int(timeParts[1]) else {
            return nil
        }
        
        // Set the target time in the report's time zone
        components.hour = hour
        components.minute = minute
        components.second = 0
        components.timeZone = timeZone
        
        var nextDate: Date?
        
        switch frequency {
        case .daily:
            // Next day at specified time in the report's time zone
            if let baseDate = calendar.date(from: components) {
                // If the scheduled time today has already passed, schedule for tomorrow
                if baseDate < currentDate {
                    nextDate = calendar.date(byAdding: .day, value: 1, to: baseDate)
                } else {
                    nextDate = baseDate
                }
            }
            
        case .weekly:
            // Next occurrence of specified weekday at specified time
            if let targetWeekday = dayOfWeek {
                components.weekday = targetWeekday
                if let baseDate = calendar.date(from: components) {
                    if baseDate < currentDate {
                        nextDate = calendar.date(byAdding: .weekOfYear, value: 1, to: baseDate)
                    } else {
                        nextDate = baseDate
                    }
                }
            }
            
        case .monthly:
            // Next occurrence of specified day of month at specified time
            if let targetDay = dayOfMonth {
                let maxDayInMonth = calendar.range(of: .day, in: .month, for: currentDate)?.count ?? 31
                components.day = min(targetDay, maxDayInMonth)
                if let baseDate = calendar.date(from: components) {
                    if baseDate < currentDate {
                        nextDate = calendar.date(byAdding: .month, value: 1, to: baseDate)
                        // Adjust for months with fewer days
                        if let adjustedDate = nextDate {
                            let adjustedComponents = calendar.dateComponents([.year, .month], from: adjustedDate)
                            let maxDay = calendar.range(of: .day, in: .month, for: adjustedDate)?.count ?? 31
                            var finalComponents = adjustedComponents
                            finalComponents.day = min(targetDay, maxDay)
                            finalComponents.hour = hour
                            finalComponents.minute = minute
                            finalComponents.timeZone = timeZone
                            nextDate = calendar.date(from: finalComponents)
                        }
                    } else {
                        nextDate = baseDate
                    }
                }
            }
        }
        
        // Check if next date is before end date (if specified)
        if let endDate = endDate, let calculatedDate = nextDate, calculatedDate > endDate {
            return nil
        }
        
        return nextDate
    }
    
    /// Human-readable description of the schedule
    var humanReadableDescription: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.timeZone = timeZone
        
        let timeString = timeOfDay
        
        switch frequency {
        case .daily:
            return "Daily at \(timeString)"
        case .weekly:
            if let weekday = dayOfWeek {
                let weekdayName = Calendar.current.weekdaySymbols[weekday - 1]
                return "\(weekdayName)s at \(timeString)"
            }
            return "Weekly at \(timeString)"
        case .monthly:
            if let day = dayOfMonth {
                let suffix = day.ordinalSuffix
                return "Monthly on the \(day)\(suffix) at \(timeString)"
            }
            return "Monthly at \(timeString)"
        }
    }
}

/// How frequently a report should run
enum ScheduleFrequency: String, Codable, CaseIterable {
    case daily = "Daily"
    case weekly = "Weekly" 
    case monthly = "Monthly"
    
    var displayName: String {
        return self.rawValue
    }
}

/// Configuration for where and how to deliver the generated report
struct DeliveryConfiguration: Codable {
    var azureStorageConfigName: String
    var folderPath: String
    var fileNameTemplate: String
    var createShareableLink: Bool
    var linkExpirationDays: Int?
    
    init() {
        self.azureStorageConfigName = ""
        self.folderPath = "reports/{reportType}/"
        self.fileNameTemplate = "{reportName}_{date}_{time}.{extension}"
        self.createShareableLink = false
        self.linkExpirationDays = 7
    }
    
    /// Generates the actual file name based on the template and current context
    func generateFileName(reportName: String, reportType: String, format: String) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let date = dateFormatter.string(from: Date())
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH-mm-ss"
        let time = timeFormatter.string(from: Date())
        
        let cleanReportName = reportName.replacingOccurrences(of: " ", with: "")
        let fileExtension = format.lowercased()
        
        return fileNameTemplate
            .replacingOccurrences(of: "{reportName}", with: cleanReportName)
            .replacingOccurrences(of: "{reportType}", with: reportType)
            .replacingOccurrences(of: "{date}", with: date)
            .replacingOccurrences(of: "{time}", with: time)
            .replacingOccurrences(of: "{extension}", with: fileExtension)
    }
    
    /// Generates the folder path based on the template and current context
    func generateFolderPath(reportType: String) -> String {
        return folderPath.replacingOccurrences(of: "{reportType}", with: reportType.lowercased())
    }
}

/// Configuration for Teams notifications about report completion
struct NotificationConfiguration: Codable {
    var enabled: Bool
    var useGlobalWebhook: Bool
    var customWebhookURL: String?
    var messageTemplate: String?
    
    init() {
        self.enabled = false
        self.useGlobalWebhook = true
        self.messageTemplate = NotificationConfiguration.defaultMessageTemplate
    }
    
    /// Default Teams message template
    static let defaultMessageTemplate = """
📊 **Scheduled Report Complete: {status}**

**{reportName}** generated
- **Records:** {recordCount}
- **File Size:** {fileSize}
- **Format:** {format}

🔗 **Download:** [{reportName} Report]({azureLink})

⏰ **Link expires:** {expirationDate}
"""
    
    /// Generates the actual notification message based on the template and run result
    func generateMessage(reportName: String, result: RunResult, azureLink: String?) -> String {
        let template = messageTemplate ?? NotificationConfiguration.defaultMessageTemplate
        
        let recordCount = result.recordCount.map { "\($0)" } ?? "Unknown"
        let fileSize = result.fileSize.map { ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) } ?? "Unknown"
        
        var message = template
            .replacingOccurrences(of: "{reportName}", with: reportName)
            .replacingOccurrences(of: "{recordCount}", with: recordCount)
            .replacingOccurrences(of: "{fileSize}", with: fileSize)
            .replacingOccurrences(of: "{format}", with: result.format.uppercased())
        
        if let link = azureLink {
            message = message.replacingOccurrences(of: "{azureLink}", with: link)
            
            if let expirationDays = result.linkExpirationDays {
                let expirationDate = Calendar.current.date(byAdding: .day, value: expirationDays, to: Date())
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                let expirationString = expirationDate.map { formatter.string(from: $0) } ?? "Unknown"
                message = message.replacingOccurrences(of: "{expirationDate}", with: expirationString)
            } else {
                message = message.replacingOccurrences(of: "{expirationDate}", with: "Never")
            }
        } else {
            message = message.replacingOccurrences(of: "{azureLink}", with: "Not available")
            message = message.replacingOccurrences(of: "{expirationDate}", with: "N/A")
        }
        
        return message
    }
}

/// Result of a scheduled report run
struct RunResult: Codable {
    let success: Bool
    let error: String?
    let fileName: String?
    let fileSize: Int64?
    let recordCount: Int?
    let format: String
    let azureLink: String?
    let linkExpirationDays: Int?
    let runDuration: TimeInterval
    let completedAt: Date
    
    init(success: Bool, format: String, error: String? = nil, fileName: String? = nil, fileSize: Int64? = nil, recordCount: Int? = nil, azureLink: String? = nil, linkExpirationDays: Int? = nil, runDuration: TimeInterval = 0) {
        self.success = success
        self.error = error
        self.fileName = fileName
        self.fileSize = fileSize
        self.recordCount = recordCount
        self.format = format
        self.azureLink = azureLink
        self.linkExpirationDays = linkExpirationDays
        self.runDuration = runDuration
        self.completedAt = Date()
    }
}

// MARK: - Extensions

extension Int {
    /// Returns the ordinal suffix for a number (1st, 2nd, 3rd, etc.)
    var ordinalSuffix: String {
        let ones = self % 10
        let tens = (self / 10) % 10
        
        if tens == 1 {
            return "th"
        } else {
            switch ones {
            case 1: return "st"
            case 2: return "nd"
            case 3: return "rd"
            default: return "th"
            }
        }
    }
}

