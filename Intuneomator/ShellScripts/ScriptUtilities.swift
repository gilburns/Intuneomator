//
//  ScriptUtilities.swift
//  Intuneomator
//
//  Created by Gil Burns on 2/22/25.
//

import Foundation

struct ScriptUtilities {
    static func executionFrequencyValue(for index: Int) -> String {
        let durations = [
            "PT0M",
            "PT15M",
            "PT30M",
            "PT1H",
            "PT2H",
            "PT3H",
            "PT6H",
            "PT12H",
            "P1D",
            "P1W"
        ]
        return index >= 0 && index < durations.count ? durations[index] : "PT0M"
    }

    static func executionFrequencyIndex(for value: String) -> Int {
        let durations = [
            "PT0M",
            "PT15M",
            "PT30M",
            "PT1H",
            "PT2H",
            "PT3H",
            "PT6H",
            "PT12H",
            "P1D",
            "P1W"
        ]
        return durations.firstIndex(of: value) ?? 0
    }
}

