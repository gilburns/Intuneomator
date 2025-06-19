//
//  EntraInstructionsViewController.swift
//  Intuneomator
//
//  Created by Gil Burns on 3/1/25.
//

import Cocoa
import PDFKit

/// Wizard step for displaying Entra ID app registration instructions
/// Displays pre-generated PDF documentation with professional formatting
/// Provides printing and PDF export capabilities for offline reference
/// Implements WizardStepProtocol for integration with the multi-step wizard flow
class EntraInstructionsViewController: NSViewController, WizardStepProtocol {
    // MARK: - WizardStepProtocol Properties
    
    /// Callback closure for notifying wizard of completion status changes
    var onCompletionStatusChanged: ((Bool) -> Void)?
    
    /// Indicates if this step has been completed (always true for instructional step)
    var isStepCompleted: Bool { return true } // Read-only step, so always complete


    // MARK: - Interface Builder Outlets
    
    /// PDF view for displaying the bundled setup instructions PDF
    @IBOutlet weak var pdfView: PDFView!

    
    /// Called after the view controller's view is loaded into memory
    /// Configures PDF view and loads bundled setup instructions
    override func viewDidLoad() {
        super.viewDidLoad()
        loadPDFInstructions()
    }

    /// Factory method for creating an instance from the Wizard storyboard
    /// Provides type-safe instantiation from storyboard with proper identifier
    /// - Returns: Configured EntraInstructionsViewController instance
    static func create() -> EntraInstructionsViewController {
        let storyboard = NSStoryboard(name: "Wizard", bundle: nil)
        return storyboard.instantiateController(withIdentifier: "EntraInstructionsViewController") as! EntraInstructionsViewController
    }
    
    
    // MARK: - PDF Content Loading
    
    /// Loads and displays the Entra ID setup instructions from bundled PDF file
    /// Uses the pre-generated PDF for consistent formatting and reliable display
    func loadPDFInstructions() {
        guard let pdfURL = Bundle.main.url(forResource: "entra-app-setup", withExtension: "pdf") else {
            Logger.info("PDF file not found in bundle", category: .core, toUserDirectory: true)
            return
        }

        guard let pdfDocument = PDFDocument(url: pdfURL) else {
            Logger.info("Failed to load PDF document", category: .core, toUserDirectory: true)
            return
        }

        // Configure PDF view for optimal display
        pdfView.document = pdfDocument
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        
        Logger.info("PDF instructions loaded successfully", category: .core, toUserDirectory: true)
    }
    
    
    // MARK: - Printing Operations
    
    /// Handles print button action to print the PDF instructions
    /// Uses PDFDocument's built-in print operation for reliable multi-page printing
    /// - Parameter sender: The print button that triggered the action
    @IBAction func printInstructionsClicked(_ sender: NSButton) {
        guard let pdfDocument = pdfView.document else {
            Logger.info("No PDF document loaded for printing", category: .core, toUserDirectory: true)
            return
        }
        
        // Create print info with appropriate settings
        let printInfo = NSPrintInfo()
        printInfo.paperSize = NSSize(width: 612, height: 792) // US Letter
        printInfo.topMargin = 36    // 0.5 inch
        printInfo.bottomMargin = 36 // 0.5 inch  
        printInfo.leftMargin = 36   // 0.5 inch
        printInfo.rightMargin = 36  // 0.5 inch
        printInfo.horizontalPagination = .automatic
        printInfo.verticalPagination = .automatic
        printInfo.orientation = .portrait
        
        // Create print operation using PDF document
        guard let printOperation = pdfDocument.printOperation(for: printInfo, scalingMode: .pageScaleToFit, autoRotate: true) else {
            Logger.info("Failed to create print operation", category: .core, toUserDirectory: true)
            return
        }
        
        printOperation.showsPrintPanel = true
        printOperation.showsProgressPanel = true
        
        // Run the operation
        if let window = view.window {
            printOperation.runModal(for: window, delegate: nil, didRun: nil, contextInfo: nil)
        } else {
            printOperation.run()
        }
    }
    
    
    
    
    // MARK: - PDF Export Operations
    
    /// Handles save button action to export instructions as PDF file
    /// Copies the bundled PDF to the user-selected location
    /// - Parameter sender: The save button that triggered the action
    @IBAction func saveInstructionsClicked(_ sender: NSButton) {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.pdf]
        savePanel.nameFieldStringValue = "Entra_App_Setup.pdf"

        savePanel.begin { response in
            if response == .OK, let saveURL = savePanel.url {
                self.exportBundledPDF(to: saveURL)
            }
        }
    }
        
    /// Exports the bundled PDF file to the specified URL
    /// Simply copies the PDF from the app bundle to the user's chosen location
    /// - Parameter url: Destination URL for the exported PDF file
    func exportBundledPDF(to url: URL) {
        guard let bundledPDFURL = Bundle.main.url(forResource: "entra-app-setup", withExtension: "pdf") else {
            Logger.info("Bundled PDF file not found", category: .core, toUserDirectory: true)
            return
        }
        
        do {
            // Remove destination file if it exists
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
            
            // Copy the bundled PDF to the destination
            try FileManager.default.copyItem(at: bundledPDFURL, to: url)
            Logger.info("PDF successfully saved at: \(url)", category: .core, toUserDirectory: true)
        } catch {
            Logger.info("Failed to save PDF: \(error.localizedDescription)", category: .core, toUserDirectory: true)
        }
    }
    
    
    // MARK: - WizardStepProtocol Implementation
    
    /// Determines if the user can proceed from this wizard step
    /// Instructions step has no validation requirements, so always returns true
    /// - Returns: Always true as instructions require no user input or validation
    func canProceed() -> Bool {
        return true
    }
    
    /// Validates the current wizard step before proceeding
    /// Instructions step has no validation requirements, so always returns true
    /// - Returns: Always true as instructions have no validation logic
    func validateStep() -> Bool {
        return true
    }
    
    /// Provides the title for this wizard step for UI display
    /// Used by the wizard controller for step navigation and progress indication
    /// - Returns: Localized title string for the Entra ID setup instructions step
    func getStepTitle() -> String {
        return "Entra ID Setup"
    }
    
    /// Provides a description of this wizard step for UI display
    /// Used by the wizard controller for step information and progress indication
    /// - Returns: Localized description string explaining the instructions step purpose
    func getStepDescription() -> String {
        return "App registration instructions"
    }
}
