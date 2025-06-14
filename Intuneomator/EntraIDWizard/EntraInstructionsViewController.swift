//
//  EntraInstructionsViewController.swift
//  Intuneomator
//
//  Created by Gil Burns on 3/1/25.
//

import Cocoa
@preconcurrency import WebKit
import Ink
import PDFKit

/// Wizard step for displaying Entra ID app registration instructions
/// Renders markdown-based setup documentation in a web view with syntax highlighting
/// Provides printing and PDF export capabilities for offline reference
/// Implements WizardStepProtocol for integration with the multi-step wizard flow
class EntraInstructionsViewController: NSViewController, WizardStepProtocol {
    // MARK: - WizardStepProtocol Properties
    
    /// Callback closure for notifying wizard of completion status changes
    var onCompletionStatusChanged: ((Bool) -> Void)?
    
    /// Indicates if this step has been completed (always true for instructional step)
    var isStepCompleted: Bool { return true } // Read-only step, so always complete


    // MARK: - Interface Builder Outlets
    
    /// Web view for displaying markdown-rendered instructions with syntax highlighting
    @IBOutlet weak var webView: WKWebView!

    
    /// Called after the view controller's view is loaded into memory
    /// Configures web view navigation and loads markdown instructions
    override func viewDidLoad() {
        super.viewDidLoad()
        webView.navigationDelegate = self
        loadMarkdownInstructions()
    }

    /// Factory method for creating an instance from the Wizard storyboard
    /// Provides type-safe instantiation from storyboard with proper identifier
    /// - Returns: Configured EntraInstructionsViewController instance
    static func create() -> EntraInstructionsViewController {
        let storyboard = NSStoryboard(name: "Wizard", bundle: nil)
        return storyboard.instantiateController(withIdentifier: "EntraInstructionsViewController") as! EntraInstructionsViewController
    }
    
    
    // MARK: - Markdown Content Loading
    
    /// Loads and displays the Entra ID setup instructions from bundled markdown file
    /// Converts markdown to styled HTML and loads it in the web view
    func loadMarkdownInstructions() {
        guard let filePath = Bundle.main.path(forResource: "entra-app-setup", ofType: "md") else {
            Logger.info("Markdown file not found in bundle", category: .core, toUserDirectory: true)
            return
        }

        do {
            let markdownText = try String(contentsOfFile: filePath, encoding: .utf8)
            let htmlText = convertMarkdownToHTML(markdownText)
            webView.loadHTMLString(htmlText, baseURL: nil)
        } catch {
            Logger.info("Failed to load Markdown file.", category: .core, toUserDirectory: true)
        }
    }

    /// Converts markdown content to styled HTML with syntax highlighting
    /// Applies professional styling and includes external libraries for code highlighting
    /// - Parameter markdown: Raw markdown string content
    /// - Returns: Complete HTML document with embedded CSS and JavaScript
    func convertMarkdownToHTML(_ markdown: String) -> String {
        let parser = MarkdownParser()
        let htmlBody = parser.html(from: markdown)

        // Create styled HTML with syntax highlighting and Apple system fonts
        let styledHTML = """
        <html>
        <head>
            <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.7.0/styles/github-dark.min.css">
            <script src="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.7.0/highlight.min.js"></script>
            <script>hljs.highlightAll();</script>
            <style>
                body { font-family: -apple-system, sans-serif; padding: 20px; }
                pre { background: #282c34; padding: 10px; border-radius: 5px; overflow-x: auto; }
                code { font-family: monospace; font-size: 14px; color: #abb2bf; }
            </style>
        </head>
        <body>
            \(htmlBody)
        </body>
        </html>
        """
        
        return styledHTML
    }
    
    
    // MARK: - Printing Operations
    
    /// Handles print button action to generate and print instructions
    /// Creates PDF from web view content and sends to system print dialog
    /// - Parameter sender: The print button that triggered the action
    @IBAction func printInstructionsClicked(_ sender: NSButton) {
        webView.createPDF { [self] result in
            switch result {
            case .success(let pdfData):
                self.printPDFData(pdfData)
            case .failure(let error):
                Logger.info("Failed to create PDF for printing: \(error.localizedDescription)", category: .core, toUserDirectory: true)
            }
        }
    }
    
    /// Configures and executes print operation for PDF data
    /// Sets up proper page formatting and displays system print dialog
    /// - Parameter pdfData: PDF data generated from web view content
    func printPDFData(_ pdfData: Data) {
        guard let pdfDocument = PDFDocument(data: pdfData) else {
            Logger.info("Error: Failed to create PDF document from data", category: .core, toUserDirectory: true)
            return
        }

        // Create PDF view with standard Letter size dimensions
        let pdfView = PDFView(frame: NSRect(x: 0, y: 0, width: 612, height: 792))
        pdfView.document = pdfDocument
        pdfView.autoScales = true  // Ensures proper scaling and full content display

        // Configure print settings with appropriate margins and pagination
        let printInfo = NSPrintInfo.shared
        printInfo.horizontalPagination = .automatic
        printInfo.verticalPagination = .automatic
        printInfo.isHorizontallyCentered = true
        printInfo.isVerticallyCentered = true
        printInfo.topMargin = 10
        printInfo.bottomMargin = 10
        printInfo.leftMargin = 10
        printInfo.rightMargin = 10

        // Execute print operation with user interaction
        let printOperation = NSPrintOperation(view: pdfView, printInfo: printInfo)
        printOperation.showsPrintPanel = true
        printOperation.showsProgressPanel = true
        printOperation.runModal(for: view.window!, delegate: nil, didRun: nil, contextInfo: nil)
    }
    
    
    
    // MARK: - PDF Export Operations
    
    /// Handles save button action to export instructions as PDF file
    /// Displays save dialog and exports web view content to user-selected location
    /// - Parameter sender: The save button that triggered the action
    @IBAction func saveInstructionsClicked(_ sender: NSButton) {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.pdf]
        savePanel.nameFieldStringValue = "Entra_App_Setup.pdf"

        savePanel.begin { response in
            if response == .OK, let saveURL = savePanel.url {
                self.exportWebViewToPDF(to: saveURL)
            }
        }
    }
        
    /// Exports web view content to PDF file at specified URL
    /// Requires macOS 12.0 or later for WKWebView PDF creation capabilities
    /// - Parameter url: Destination URL for the exported PDF file
    func exportWebViewToPDF(to url: URL) {
        if #available(macOS 12.0, *) {
            webView.createPDF { [self] result in
                switch result {
                case .success(let data):
                    do {
                        try data.write(to: url)
                        Logger.info("PDF successfully saved at: \(url)", category: .core, toUserDirectory: true)
                    } catch {
                        Logger.info("Failed to save PDF: \(error)", category: .core, toUserDirectory: true)
                    }
                case .failure(let error):
                    Logger.info("Failed to create PDF: \(error.localizedDescription)", category: .core, toUserDirectory: true)
                }
            }
        } else {
            Logger.info("PDF export is only supported on macOS 12 or later.", category: .core, toUserDirectory: true)
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

// MARK: - WKNavigationDelegate Extension

/// Extension implementing WKNavigationDelegate for handling web view navigation
/// Ensures external links open in system browser while allowing internal HTML navigation
extension EntraInstructionsViewController: WKNavigationDelegate {
    
    /// Handles navigation policy decisions for web view requests
    /// Opens external links in system browser while allowing internal content
    /// - Parameters:
    ///   - webView: The web view requesting navigation policy
    ///   - navigationAction: Details about the requested navigation
    ///   - decisionHandler: Completion handler with policy decision
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let url = navigationAction.request.url, navigationAction.navigationType == .linkActivated {
            NSWorkspace.shared.open(url) // Open external links in system browser
            decisionHandler(.cancel) // Prevent loading in WKWebView
            return
        }
        decisionHandler(.allow) // Allow other navigation (internal HTML content)
    }
}
