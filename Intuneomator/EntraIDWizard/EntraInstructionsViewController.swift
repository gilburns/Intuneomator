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


class EntraInstructionsViewController: NSViewController, WizardStepProtocol {
    var onCompletionStatusChanged: ((Bool) -> Void)?
    var isStepCompleted: Bool { return true } // ✅ Read-only, so always complete

    
    @IBOutlet weak var webView: WKWebView!

    
    override func viewDidLoad() {
        super.viewDidLoad()
        webView.navigationDelegate = self
        loadMarkdownInstructions()

    }

    static func create() -> EntraInstructionsViewController {
        let storyboard = NSStoryboard(name: "Wizard", bundle: nil)
        return storyboard.instantiateController(withIdentifier: "EntraInstructionsViewController") as! EntraInstructionsViewController
    }
    
    
    // MARK: - Markdown Loading
    func loadMarkdownInstructions() {
        guard let filePath = Bundle.main.path(forResource: "entra-app-setup", ofType: "md") else {
            return
        }

        do {
            let markdownText = try String(contentsOfFile: filePath, encoding: .utf8)
            let htmlText = convertMarkdownToHTML(markdownText)
            webView.loadHTMLString(htmlText, baseURL: nil)
        } catch {
            Logger.logUser("Failed to load Markdown file.", logType: "SetupWizard")
        }
    }

    func convertMarkdownToHTML(_ markdown: String) -> String {
        let parser = MarkdownParser()
        let htmlBody = parser.html(from: markdown)

        // ✅ Inject CSS + JavaScript for Syntax Highlighting
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
    
    
    // MARK: - Printing

    @IBAction func printInstructionsClicked(_ sender: NSButton) {
        webView.createPDF { result in
            switch result {
            case .success(let pdfData):
                self.printPDFData(pdfData)
            case .failure(let error):
                Logger.logUser("Failed to create PDF for printing: \(error.localizedDescription)", logType: "SetupWizard")
            }
        }
    }
    
    func printPDFData(_ pdfData: Data) {
        guard let pdfDocument = PDFDocument(data: pdfData) else {
            Logger.logUser("Error: Failed to create PDF document from data", logType: "SetupWizard")
            return
        }

        let pdfView = PDFView(frame: NSRect(x: 0, y: 0, width: 612, height: 792)) // Standard Letter size
        pdfView.document = pdfDocument
        pdfView.autoScales = true  // ✅ Ensures proper scaling and full content display

        let printInfo = NSPrintInfo.shared
        printInfo.horizontalPagination = .automatic
        printInfo.verticalPagination = .automatic
        printInfo.isHorizontallyCentered = true
        printInfo.isVerticallyCentered = true
        printInfo.topMargin = 10
        printInfo.bottomMargin = 10
        printInfo.leftMargin = 10
        printInfo.rightMargin = 10

        let printOperation = NSPrintOperation(view: pdfView, printInfo: printInfo)
        printOperation.showsPrintPanel = true
        printOperation.showsProgressPanel = true
        printOperation.runModal(for: view.window!, delegate: nil, didRun: nil, contextInfo: nil)
    }
    
    
    
    // MARK: - Saving as PDF

    @IBAction func saveInstructionsClicked(_ sender: NSButton) {
        let savePanel = NSSavePanel()
        savePanel.allowedFileTypes = ["pdf"]
        savePanel.nameFieldStringValue = "Entra_App_Setup.pdf"

        savePanel.begin { response in
            if response == .OK, let saveURL = savePanel.url {
                self.exportWebViewToPDF(to: saveURL)
            }
        }
    }
        
    func exportWebViewToPDF(to url: URL) {
        if #available(macOS 12.0, *) {
            webView.createPDF { result in
                switch result {
                case .success(let data):
                    do {
                        try data.write(to: url)
                        Logger.logUser("PDF successfully saved at: \(url)", logType: "SetupWizard")
                    } catch {
                        Logger.logUser("Failed to save PDF: \(error)", logType: "SetupWizard")
                    }
                case .failure(let error):
                    Logger.logUser("Failed to create PDF: \(error.localizedDescription)", logType: "SetupWizard")
                }
            }
        } else {
            Logger.logUser("PDF export is only supported on macOS 12 or later.", logType: "SetupWizard")
        }
    }
    
}

extension EntraInstructionsViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let url = navigationAction.request.url, navigationAction.navigationType == .linkActivated {
            NSWorkspace.shared.open(url) // ✅ Open in the external browser
            decisionHandler(.cancel) // ✅ Prevent loading in WKWebView
            return
        }
        decisionHandler(.allow) // ✅ Allow other navigation (e.g., internal HTML)
    }
}
