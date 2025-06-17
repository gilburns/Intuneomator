//
//  Weekday.swift
//  Intuneomator
//
//  Created by Gil Burns on 5/22/25.
//

import Foundation

/// Represents a weekday (Monday = 1 ... Sunday = 7).
enum Weekday: Int, CaseIterable, CustomStringConvertible {
    case monday = 1, tuesday, wednesday, thursday, friday, saturday, sunday

    /// The full name of the weekday.
    var name: String {
        switch self {
        case .monday: return "Monday"
        case .tuesday: return "Tuesday"
        case .wednesday: return "Wednesday"
        case .thursday: return "Thursday"
        case .friday: return "Friday"
        case .saturday: return "Saturday"
        case .sunday: return "Sunday"
        }
    }

    /// Conforms to CustomStringConvertible.
    var description: String { name }
}
