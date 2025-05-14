//
//  LicenseViewController.swift
//  Intuneomator
//
//  Created by Gil Burns on 3/1/25.
//

import Cocoa

class LicenseViewController: NSViewController {
    @IBOutlet weak var licenseTextView: NSTextView!

    override func viewDidLoad() {
        super.viewDidLoad()
        loadLicenseText()
    }

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

    @IBAction func closeButtonClicked(_ sender: NSButton) {
        self.dismiss(self) // Closes the sheet
    }
}
