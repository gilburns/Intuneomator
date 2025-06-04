//
//  ScheduledTime.swift
//  Intuneomator
//
//  Created by Gil Burns on 5/4/25.
//

import Foundation

/// Represents a scheduled time for automation tasks with optional weekday specification
/// Conforms to NSSecureCoding for safe archiving and unarchiving in configuration storage
@objc(ScheduledTime)
class ScheduledTime: NSObject, NSSecureCoding {
    /// Indicates this class supports secure coding for safe serialization
    static var supportsSecureCoding: Bool = true

    /// Optional weekday (1-7, where 1=Sunday) as NSNumber, nil for daily execution
    let weekday: NSNumber?
    
    /// Hour of the day (0-23) when the task should run
    let hour: Int
    
    /// Minute of the hour (0-59) when the task should run
    let minute: Int

    /// Initializes a new scheduled time
    /// - Parameters:
    ///   - weekday: Optional weekday (1-7, where 1=Sunday), nil for daily execution
    ///   - hour: Hour of the day (0-23)
    ///   - minute: Minute of the hour (0-59)
    init(weekday: NSNumber?, hour: Int, minute: Int) {
        self.weekday = weekday
        self.hour = hour
        self.minute = minute
    }

    /// Initializes from archived data using NSSecureCoding
    /// - Parameter coder: The coder containing the archived ScheduledTime data
    required init?(coder: NSCoder) {
        self.weekday = coder.decodeObject(of: NSNumber.self, forKey: "weekday")
        self.hour = coder.decodeInteger(forKey: "hour")
        self.minute = coder.decodeInteger(forKey: "minute")
    }

    /// Encodes the scheduled time data for archiving using NSSecureCoding
    /// - Parameter coder: The coder to encode the ScheduledTime data into
    func encode(with coder: NSCoder) {
        if let weekday = weekday {
            coder.encode(weekday, forKey: "weekday")
        }
        coder.encode(hour, forKey: "hour")
        coder.encode(minute, forKey: "minute")
    }
}

