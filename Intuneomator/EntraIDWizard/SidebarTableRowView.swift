//
//  SidebarTableRowView.swift
//  Intuneomator
//
//  Created by Gil Burns on 3/1/25.
//

import Cocoa

class SidebarTableRowView: NSTableRowView {
    override func drawSelection(in dirtyRect: NSRect) {
        // Prevent row background from being highlighted
        NSColor.clear.setFill()
        dirtyRect.fill()
    }
}
