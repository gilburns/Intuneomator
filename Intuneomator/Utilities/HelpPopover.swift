//
//  HelpPopover.swift
//  Intuneomator
//
//  Created by Gil Burns on 1/12/25.
//

import Cocoa

/// Utility class for displaying contextual help information in macOS popovers
/// Provides rich text display with hyperlink support and automatic sizing
/// Designed for showing formatted help content anchored to UI elements
class HelpPopover {

    /// The NSPopover instance used for displaying help content
    private let popover: NSPopover

    /// Initializes the help popover with transient behavior
    /// Configures the popover to automatically dismiss when clicking outside
    init() {
        self.popover = NSPopover()
        self.popover.behavior = .transient // Automatically dismisses when clicking outside
    }

    /// Displays help content in a popover anchored to the specified view
    /// Creates a rich text view with automatic sizing and hyperlink support
    /// - Parameters:
    ///   - anchorView: The view to anchor the popover to
    ///   - helpText: Attributed string containing formatted help content with potential hyperlinks
    func showHelp(anchorView: NSView, helpText: NSAttributedString) {
        // Create an NSTextView for rich text with hyperlinks
        let helpTextView = NSTextView()
        helpTextView.isEditable = false
        helpTextView.isSelectable = true
        helpTextView.drawsBackground = false
        helpTextView.textContainerInset = NSSize(width: 10, height: 10)
        helpTextView.textStorage?.setAttributedString(helpText)
        helpTextView.textContainer?.lineBreakMode = .byWordWrapping
        helpTextView.textContainer?.widthTracksTextView = true

        // Create a container view for the NSTextView
        let contentView = NSView()
        contentView.addSubview(helpTextView)
        helpTextView.translatesAutoresizingMaskIntoConstraints = false

        // Define the maximum width and calculate required height
        let maxWidth: CGFloat = 300
        helpTextView.textContainer?.containerSize = NSSize(width: maxWidth, height: CGFloat.greatestFiniteMagnitude)

        // Force layout calculation to determine content size
        helpTextView.layoutManager?.ensureLayout(for: helpTextView.textContainer!)

        // Calculate the size required for the text, adding buffer for proper display
        let calculatedHeight = helpTextView.layoutManager?.usedRect(for: helpTextView.textContainer!).height ?? 150
        let popoverHeight = min(calculatedHeight + 30, 500) // Add buffer and cap maximum height

        // Configure Auto Layout constraints for proper text view sizing
        NSLayoutConstraint.activate([
            helpTextView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            helpTextView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            helpTextView.topAnchor.constraint(equalTo: contentView.topAnchor),
            helpTextView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            helpTextView.widthAnchor.constraint(equalToConstant: maxWidth),
            helpTextView.heightAnchor.constraint(equalToConstant: popoverHeight)
        ])

        // Configure popover content and display
        let contentViewController = NSViewController()
        contentViewController.view = contentView
        popover.contentViewController = contentViewController

        // Set popover size based on calculated dimensions
        popover.contentSize = NSSize(width: maxWidth, height: popoverHeight)

        // Display the popover anchored to the specified view's right edge
        popover.show(relativeTo: anchorView.bounds, of: anchorView, preferredEdge: .maxX)

    }

    /// Programmatically closes the help popover
    /// Can be called to dismiss the popover before automatic dismissal
    func close() {
        popover.close()
    }
}
