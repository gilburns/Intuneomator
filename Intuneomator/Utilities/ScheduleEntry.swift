//
//  ScheduleEntry.swift
//  Intuneomator
//
//  Created by Gil Burns on 5/4/25.
//

import Foundation

class ScheduleEntry: NSObject {
    var weekday: Weekday?
    var hour: Int
    var minute: Int

    init(weekday: Weekday?, hour: Int, minute: Int) {
        self.weekday = weekday
        self.hour = hour
        self.minute = minute
    }

    func displayString() -> String {
        let weekdayPart = weekday?.name ?? "Daily"
        let timePart = String(format: "%02d:%02d", hour, minute)
        return "\(weekdayPart) @ \(timePart)"
    }

    func toScheduledTime() -> ScheduledTime {
        return ScheduledTime(weekday: weekday.map { NSNumber(value: $0.rawValue) }, hour: hour, minute: minute)
    }
}
