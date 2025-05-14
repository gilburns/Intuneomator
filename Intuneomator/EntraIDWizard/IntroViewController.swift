//
//  IntroViewController.swift
//  Intuneomator
//
//  Created by Gil Burns on 3/1/25.
//

import Cocoa

class IntroViewController: NSViewController, WizardStepProtocol {
    
    var onCompletionStatusChanged: ((Bool) -> Void)?
    var isStepCompleted: Bool { return true } // ✅ Read-only, so always complete

    
    override func viewDidLoad() {
        super.viewDidLoad()
    }

    static func create() -> IntroViewController {
        let storyboard = NSStoryboard(name: "Wizard", bundle: nil)
        return storyboard.instantiateController(withIdentifier: "IntroViewController") as! IntroViewController
    }

    @IBAction func viewLicenseClicked(_ sender: NSButton) {
        showLicenseSheet()
    }

    func showLicenseSheet() {
        let storyboard = NSStoryboard(name: "Wizard", bundle: nil)
        if let licenseVC = storyboard.instantiateController(withIdentifier: "LicenseViewController") as? LicenseViewController {
            self.presentAsSheet(licenseVC)
        }
    }

    
    
//    override func loadView() {
//        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 500, height: 300))
//        let label = NSTextField(labelWithString: "Welcome to the Setup Wizard!")
//        label.frame = NSRect(x: 20, y: 100, width: 460, height: 20)
//        view.addSubview(label)
//    }
}
