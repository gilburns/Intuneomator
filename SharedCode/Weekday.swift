//
//  Weekday.swift
//  Intuneomator
//
//  Created by Gil Burns on 5/22/25.
//

import Foundation

/// Represents a weekday (Sunday = 1 ... Saturday = 7).
enum Weekday: Int, CaseIterable, CustomStringConvertible {
    case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday

    /// The full name of the weekday.
    var name: String {
        switch self {
        case .sunday: return "Sunday"
        case .monday: return "Monday"
        case .tuesday: return "Tuesday"
        case .wednesday: return "Wednesday"
        case .thursday: return "Thursday"
        case .friday: return "Friday"
        case .saturday: return "Saturday"
        }
    }

    /// Conforms to CustomStringConvertible.
    var description: String { name }
}
