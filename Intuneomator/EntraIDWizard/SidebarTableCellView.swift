//
//  SidebarTableCellView.swift
//  Intuneomator
//
//  Created by Gil Burns on 3/1/25.
//

import Cocoa

class SidebarTableCellView: NSTableCellView {
    @IBOutlet weak var bulletImageView: NSImageView!

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Prevent default row highlight (removes blue background)
//        if self.isSelected {
//            NSColor.clear.setFill()
//            dirtyRect.fill()
//        }
    }
}
