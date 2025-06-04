//
//  LicenseViewController.swift
//  Intuneomator
//
//  Created by Gil Burns on 3/1/25.
//

import Cocoa

/// Modal sheet view controller for displaying application license information
/// Loads and presents the bundled LICENSE.md file in a read-only text view
/// Provides simple close functionality for dismissing the license display
class LicenseViewController: NSViewController {
    
    // MARK: - Interface Builder Outlets
    
    /// Text view for displaying the complete license text content
    /// Configured as read-only to prevent user modification of license terms
    @IBOutlet weak var licenseTextView: NSTextView!

    
    // MARK: - View Lifecycle Methods
    
    /// Called after the view controller's view is loaded into memory
    /// Immediately loads and displays the license content from the bundle
    override func viewDidLoad() {
        super.viewDidLoad()
        loadLicenseText()
    }

    /// Loads the application license text from the bundled LICENSE.md file
    /// Displays error messages if the license file cannot be found or loaded
    /// Sets the loaded content directly in the text view for user reading
    func loadLicenseText() {
        guard let licensePath = Bundle.main.path(forResource: "LICENSE", ofType: "md") else {
            licenseTextView.string = "License file not found."
            return
        }

        do {
            let licenseText = try String(contentsOfFile: licensePath, encoding: .utf8)
            licenseTextView.string = licenseText
        } catch {
            licenseTextView.string = "Failed to load license file."
        }
    }

    
    // MARK: - User Action Methods
    
    /// Handles close button click to dismiss the license modal sheet
    /// Returns control to the parent view controller that presented this sheet
    /// - Parameter sender: The close button that triggered the action
    @IBAction func closeButtonClicked(_ sender: NSButton) {
        self.dismiss(self) // Closes the sheet
    }
}
