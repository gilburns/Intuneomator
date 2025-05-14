//
//  ScheduledTime.swift
//  Intuneomator
//
//  Created by Gil Burns on 5/4/25.
//

import Foundation

@objc(ScheduledTime)
class ScheduledTime: NSObject, NSSecureCoding {
    static var supportsSecureCoding: Bool = true

    let weekday: NSNumber?   // Optional Int as NSNumber
    let hour: Int
    let minute: Int

    init(weekday: NSNumber?, hour: Int, minute: Int) {
        self.weekday = weekday
        self.hour = hour
        self.minute = minute
    }

    required init?(coder: NSCoder) {
        self.weekday = coder.decodeObject(of: NSNumber.self, forKey: "weekday")
        self.hour = coder.decodeInteger(forKey: "hour")
        self.minute = coder.decodeInteger(forKey: "minute")
    }

    func encode(with coder: NSCoder) {
        if let weekday = weekday {
            coder.encode(weekday, forKey: "weekday")
        }
        coder.encode(hour, forKey: "hour")
        coder.encode(minute, forKey: "minute")
    }
}

