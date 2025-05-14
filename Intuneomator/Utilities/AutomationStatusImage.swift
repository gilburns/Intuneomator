//
//  AutomationStatusImage.swift
//  Intuneomator
//
//  Created by Gil Burns on 5/13/25.
//

import Cocoa

enum AutomationStatusImage: Int {
    case Ready, NotReady

    var image: NSImage {
        switch self {
        case .Ready:
            return NSImage(named: "NSStatusAvailable")!
        case .NotReady:
            return NSImage(named: "NSStatusPartiallyAvailable")!
        }
    }
}
