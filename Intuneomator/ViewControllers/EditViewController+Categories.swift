//
//  EditViewController+Categories.swift
//  Intuneomator
//
//  Created by Gil Burns on 5/25/25.
//

///
///  EditViewController+Categories.swift
///  Intuneomator
///
///  Extension to handle loading, displaying, and managing mobile app categories
///  via a popover. Provides functionality to show a list of categories with checkboxes,
///  track user selections, and update the UI accordingly.
///

import Foundation
import AppKit

/// Extension for `EditViewController` to manage the categories popover functionality.
/// It allows loading cached categories, displaying them in a scrollable popover,
/// and tracking selected categories.
extension EditViewController {
    
    // MARK: - Categories Popover
    /// Initializes and configures the `categoriesPopover` for displaying category checkboxes.
    /// Creates the popover, sets it to transient behavior, and sets up a content view
    /// containing a scroll view with a vertical stack view for checkboxes.
    func setupCategoriesPopover() {
        categoriesPopover = NSPopover()
        categoriesPopover.behavior = .transient

        let contentVC = NSViewController()

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.spacing = 4 // Reduced spacing for better alignment
        stackView.edgeInsets = NSEdgeInsets(top: 0, left: 10, bottom: 10, right: 10) // Remove top padding
        stackView.translatesAutoresizingMaskIntoConstraints = false

        scrollView.documentView = stackView
        contentVC.view = scrollView
        categoriesPopover.contentViewController = contentVC
    }

    
    /// Populates the categories popover with checkboxes for each available category.
    ///
    /// Fetches the cached `mobileAppCategories` from `AppDataManager`, clears any existing
    /// checkbox views, and creates a new `NSButton` checkbox for each category. The `identifier`
    /// of each checkbox is set to the category's `id`, and its `state` reflects whether the
    /// category is currently selected. The checkboxes are added to the stack view inside the popover.
    func populateCategories() {
        guard let scrollView = categoriesPopover.contentViewController?.view as? NSScrollView,
              let stackView = scrollView.documentView as? NSStackView else {
//            print("StackView not found!")
            return
        }

        // Clear existing items
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        // Fetch cached categories
        self.categories = AppDataManager.shared.mobileAppCategories

        // Populate the checkboxes
        for category in self.categories {
            if let displayName = category["displayName"] as? String,
               let id = category["id"] as? String {
                let checkbox = NSButton(checkboxWithTitle: displayName, target: self, action: #selector(toggleCategory(_:)))
                checkbox.identifier = NSUserInterfaceItemIdentifier(rawValue: id)
                checkbox.state = self.selectedCategories.contains(id) ? .on : .off
                checkbox.alignment = .left // Align text to the left
                checkbox.translatesAutoresizingMaskIntoConstraints = false

                // Add the checkbox to the stack view
                stackView.addArrangedSubview(checkbox)

                // Now apply constraints
                NSLayoutConstraint.activate([
                    checkbox.leadingAnchor.constraint(equalTo: stackView.leadingAnchor, constant: 10),
                    checkbox.trailingAnchor.constraint(lessThanOrEqualTo: stackView.trailingAnchor, constant: -10)
                ])
            }
        }

        // Trigger layout update
        stackView.needsLayout = true
        stackView.layoutSubtreeIfNeeded()
    }

    /// Displays the categories popover when the user clicks the associated button.
    ///
    /// Populates the checkbox list, updates the button title to reflect current selections,
    /// calculates the popover size based on the number and length of categories, and shows
    /// the popover anchored to the sender button.
    @IBAction func showCategoriesPopover(_ sender: NSButton) {
        populateCategories()
        updateCategoryButtonTitle() // Ensure the button title reflects the current state
        let maxWidth = calculateMaxWidth(for: categories)
        let maxVisibleItems = 10 // Maximum number of items to show before scrolling
        let itemHeight: CGFloat = 20
        let calculatedHeight = min(CGFloat(categories.count) * itemHeight + 10, CGFloat(maxVisibleItems) * itemHeight + 10)
        categoriesPopover.contentSize = NSSize(width: maxWidth, height: calculatedHeight)

        categoriesPopover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .maxY)
    }

    /// Handles toggling of a category checkbox in the popover.
    ///
    /// When a checkbox is clicked, this method adds or removes the `id` from `selectedCategories`
    /// depending on its new `state`. It then updates the category button title and marks that
    /// changes have occurred by calling `trackChanges()`.
    ///
    /// - Parameter sender: The `NSButton` checkbox that was toggled.
    @objc private func toggleCategory(_ sender: NSButton) {
        guard let id = sender.identifier?.rawValue else { return }

        if sender.state == .on {
            selectedCategories.insert(id)
        } else {
            selectedCategories.remove(id)
        }

//        print("Selected Categories: \(selectedCategories)")
        updateCategoryButtonTitle() // Update the button text
        trackChanges() // Track changes after updating categories
    }

    /// Returns the list of currently selected category IDs.
    ///
    /// - Returns: An array of `String` IDs corresponding to the selected categories.
    func getSelectedCategories() -> [String] {
        return Array(selectedCategories)
    }

    /// Calculates the maximum width needed to display category names in the popover.
    ///
    /// Measures each `displayName` using the system font, finds the largest width,
    /// and adds padding to account for the checkbox and margins.
    ///
    /// - Parameter categories: Array of dictionaries representing categories, each containing
    ///   a `"displayName"` key.
    /// - Returns: The calculated width in points for the popover content.
    private func calculateMaxWidth(for categories: [[String: Any]]) -> CGFloat {
        let font = NSFont.systemFont(ofSize: NSFont.systemFontSize) // Default font for NSButton
        let attributes: [NSAttributedString.Key: Any] = [.font: font]

        var maxWidth: CGFloat = 0
        for category in categories {
            if let displayName = category["displayName"] as? String {
                let size = displayName.size(withAttributes: attributes)
                maxWidth = max(maxWidth, size.width)
            }
        }
        return maxWidth + 50 // Add padding for checkbox and margins
    }

    /// Updates the title of the category selection button based on `selectedCategories`.
    ///
    /// If no categories are selected, shows "0 selected". If exactly one is selected, displays
    /// its `displayName`. Otherwise, displays the count (e.g., "3 selected").
    func updateCategoryButtonTitle() {
        let count = selectedCategories.count

        if count == 0 {
            buttonSelectCategories.title = "0 selected"
        } else if count == 1, let id = selectedCategories.first {
            // Find the displayName for the single selected ID
            if let category = categories.first(where: { $0["id"] as? String == id }),
               let displayName = category["displayName"] as? String {
                buttonSelectCategories.title = displayName
            } else {
                buttonSelectCategories.title = "1 selected" // Fallback
            }
        } else {
            buttonSelectCategories.title = "\(count) selected"
        }
    }


    
}
