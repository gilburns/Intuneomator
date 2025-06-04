//
//  ScheduleEntry.swift
//  Intuneomator
//
//  Created by Gil Burns on 5/4/25.
//

import Foundation

/// Model representing a user-configured schedule entry for task automation
/// Provides user-friendly weekday selection and time specification with display formatting
/// Converts to ScheduledTime objects for system-level Launch Daemon scheduling
class ScheduleEntry: NSObject {
    /// Optional weekday specification using the Weekday enum
    /// nil indicates daily execution, otherwise specifies a particular day of the week
    var weekday: Weekday?
    
    /// Hour of execution in 24-hour format (0-23)
    var hour: Int
    
    /// Minute of execution (0-59)
    var minute: Int

    /// Initializes a schedule entry with weekday and time specification
    /// - Parameters:
    ///   - weekday: Optional weekday using Weekday enum. nil for daily execution
    ///   - hour: Hour in 24-hour format (0-23)
    ///   - minute: Minute (0-59)
    init(weekday: Weekday?, hour: Int, minute: Int) {
        self.weekday = weekday
        self.hour = hour
        self.minute = minute
    }

    /// Generates a user-friendly display string for the schedule entry
    /// Formats weekday and time in a readable format for UI display
    /// - Returns: Formatted string like "Monday @ 14:30" or "Daily @ 09:00"
    func displayString() -> String {
        let weekdayPart = weekday?.name ?? "Daily"
        let timePart = String(format: "%02d:%02d", hour, minute)
        return "\(weekdayPart) @ \(timePart)"
    }

    /// Converts the schedule entry to a ScheduledTime object for system scheduling
    /// Maps the Weekday enum to NSNumber format required by Launch Daemon configuration
    /// - Returns: ScheduledTime object suitable for XPC transmission and daemon scheduling
    func toScheduledTime() -> ScheduledTime {
        return ScheduledTime(weekday: weekday.map { NSNumber(value: $0.rawValue) }, hour: hour, minute: minute)
    }
}
