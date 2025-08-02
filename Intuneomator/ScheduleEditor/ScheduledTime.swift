//
//  ScheduledTime.swift
//  Intuneomator
//
//  Created by Gil Burns on 5/4/25.
//

import Foundation

/// Represents a scheduled time for Launch Daemon task execution
/// Supports both daily and weekly scheduling with precise time specification
/// Implements NSSecureCoding for safe XPC transmission between GUI and service
@objc(ScheduledTime)
class ScheduledTime: NSObject, NSSecureCoding {
    /// Indicates support for secure coding to prevent object substitution attacks
    /// Required for safe transmission over XPC connections
    static var supportsSecureCoding: Bool = true

    /// Optional weekday specification for weekly scheduling
    /// - nil: Executes daily
    /// - 1: Sunday, 2: Monday, 3: Tuesday, 4: Wednesday, 5: Thursday, 6: Friday, 7: Saturday
    /// Uses NSNumber to support optional Int encoding/decoding
    let weekday: NSNumber?
    
    /// Hour of execution in 24-hour format (0-23)
    let hour: Int
    
    /// Minute of execution (0-59)
    let minute: Int

    /// Creates a new scheduled time with weekday and time specification
    /// - Parameters:
    ///   - weekday: Optional weekday (1-7, Sunday-Saturday). Nil for daily execution
    ///   - hour: Hour in 24-hour format (0-23)
    ///   - minute: Minute (0-59)
    init(weekday: NSNumber?, hour: Int, minute: Int) {
        self.weekday = weekday
        self.hour = hour
        self.minute = minute
    }

    /// Initializes from encoded data using NSCoder for XPC transmission
    /// Safely decodes weekday as NSNumber and time components as integers
    /// - Parameter coder: NSCoder containing encoded schedule data
    required init?(coder: NSCoder) {
        self.weekday = coder.decodeObject(of: NSNumber.self, forKey: "weekday")
        self.hour = coder.decodeInteger(forKey: "hour")
        self.minute = coder.decodeInteger(forKey: "minute")
    }

    /// Encodes schedule data using NSCoder for XPC transmission
    /// Safely encodes all properties with appropriate keys for secure transmission
    /// - Parameter coder: NSCoder to store encoded schedule data
    func encode(with coder: NSCoder) {
        if let weekday = weekday {
            coder.encode(weekday, forKey: "weekday")
        }
        coder.encode(hour, forKey: "hour")
        coder.encode(minute, forKey: "minute")
    }
}
