//
//  WKWebView+Printing.swift
//  Intuneomator
//
//  Created by Gil Burns on 3/2/25.
//

import WebKit
import Cocoa
import Foundation


extension WKWebView {
    func printWebViewContent(window: NSWindow?) {
        self.evaluateJavaScript("document.body.scrollHeight") { result, error in
            guard let height = result as? CGFloat, error == nil else {
                Logger.info("Error getting document height: \(error?.localizedDescription ?? "Unknown error")", category: .core, toUserDirectory: true)
                return
            }

            let fullSize = NSSize(width: self.bounds.width, height: height)
            self.setFrameSize(fullSize)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { // Allow resizing
                let printOperation = NSPrintOperation(view: self)
                printOperation.showsPrintPanel = true
                printOperation.showsProgressPanel = true
                if let window = window {
                    printOperation.runModal(for: window, delegate: nil, didRun: nil, contextInfo: nil)
                }
            }
        }
    }
}

