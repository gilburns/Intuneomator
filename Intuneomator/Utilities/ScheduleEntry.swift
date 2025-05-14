//
//  ScheduleEntry.swift
//  Intuneomator
//
//  Created by Gil Burns on 5/4/25.
//

import Foundation

class ScheduleEntry: NSObject {
    var weekday: Int?  // 1 = Sunday ... 7 = Saturday
    var hour: Int
    var minute: Int

    init(weekday: Int?, hour: Int, minute: Int) {
        self.weekday = weekday
        self.hour = hour
        self.minute = minute
    }

    func displayString() -> String {
        let weekdayNames = [nil, "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        let weekdayPart = weekday.flatMap { weekdayNames[$0] } ?? "Daily"
        let timePart = String(format: "%02d:%02d", hour, minute)
        return "\(weekdayPart) @ \(timePart)"
    }

    func toScheduledTime() -> ScheduledTime {
        return ScheduledTime(weekday: weekday.map { NSNumber(value: $0) }, hour: hour, minute: minute)
    }
}
