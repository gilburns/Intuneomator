//
//  EditViewController+Categories.swift
//  Intuneomator
//
//  Created by Gil Burns on 5/25/25.
//

import Foundation
import AppKit

extension EditViewController {
    
    // MARK: - Categories Popover
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

    func getSelectedCategories() -> [String] {
        return Array(selectedCategories)
    }

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
