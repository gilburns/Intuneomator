//
//  AzureStorageTestViewController.swift
//  Intuneomator
//
//  Created by Gil Burns on 7/23/25.
//

import Cocoa

/// Temporary test interface for Azure Storage upload and notification functionality
/// This will be removed once the full scheduling system is implemented
class AzureStorageTestViewController: NSViewController {
    
    // MARK: - UI Outlets
    
    @IBOutlet weak var labelTitle: NSTextField!
    @IBOutlet weak var popupStorageConfig: NSPopUpButton!
    @IBOutlet weak var buttonSelectFile: NSButton!
    @IBOutlet weak var labelSelectedFile: NSTextField!
    @IBOutlet weak var buttonUpload: NSButton!
    @IBOutlet weak var popupLinkExpiration: NSPopUpButton!
    @IBOutlet weak var buttonGenerateLink: NSButton!
    @IBOutlet weak var textViewLink: NSTextView!
    @IBOutlet weak var buttonSendTeamsNotification: NSButton!
    @IBOutlet weak var textViewStatus: NSTextView!
    @IBOutlet weak var progressIndicator: NSProgressIndicator!
    
    // MARK: - File Management UI (Added Programmatically)
    
    private weak var buttonListFiles: NSButton?
    private weak var buttonDeleteFile: NSButton?
    private weak var buttonDeleteOldFiles: NSButton?
    
    // MARK: - Properties
    
    private var selectedFileURL: URL?
    private var uploadedFileName: String?
    private var storageConfigurations: [[String: Any]] = []
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadStorageConfigurations()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        labelTitle.stringValue = "Azure Storage Test Interface"
        labelSelectedFile.stringValue = "No file selected"
        textViewLink.string = ""
        textViewStatus.string = "Ready to test Azure Storage functionality"
        
        setupLinkExpirationPopup()
        setupFileManagementButtons()
        updateButtonStates()
        
        progressIndicator.isHidden = true
    }
    
    private func setupFileManagementButtons() {
        let contentView = view
        
        // Create List Files button
        let listFilesButton = NSButton(frame: NSRect(x: 220, y: 351, width: 120, height: 32))
        listFilesButton.title = "List Files"
        listFilesButton.bezelStyle = .rounded
        listFilesButton.target = self
        listFilesButton.action = #selector(listFiles(_:))
        contentView.addSubview(listFilesButton)
        self.buttonListFiles = listFilesButton
        
        // Create Delete File button
        let deleteFileButton = NSButton(frame: NSRect(x: 350, y: 351, width: 120, height: 32))
        deleteFileButton.title = "Delete File"
        deleteFileButton.bezelStyle = .rounded
        deleteFileButton.target = self
        deleteFileButton.action = #selector(deleteFile(_:))
        contentView.addSubview(deleteFileButton)
        self.buttonDeleteFile = deleteFileButton
        
        // Create Delete Old Files button
        let deleteOldFilesButton = NSButton(frame: NSRect(x: 480, y: 351, width: 140, height: 32))
        deleteOldFilesButton.title = "Delete Old Files..."
        deleteOldFilesButton.bezelStyle = .rounded
        deleteOldFilesButton.target = self
        deleteOldFilesButton.action = #selector(deleteOldFiles(_:))
        contentView.addSubview(deleteOldFilesButton)
        self.buttonDeleteOldFiles = deleteOldFilesButton
    }
    
    private func setupLinkExpirationPopup() {
        popupLinkExpiration.removeAllItems()
        popupLinkExpiration.addItems(withTitles: [
            "1 day",
            "2 days", 
            "3 days",
            "7 days"
        ])
        popupLinkExpiration.selectItem(at: 2) // Default to 3 days
    }
    
    private func loadStorageConfigurations() {
        XPCManager.shared.getAzureStorageConfigurationSummaries { [weak self] summaries in
            DispatchQueue.main.async {
                self?.storageConfigurations = summaries
                self?.populateStorageConfigPopup()
            }
        }
    }
    
    private func populateStorageConfigPopup() {
        popupStorageConfig.removeAllItems()
        
        if storageConfigurations.isEmpty {
            popupStorageConfig.addItem(withTitle: "No configurations available")
            popupStorageConfig.isEnabled = false
        } else {
            for config in storageConfigurations {
                if let name = config["name"] as? String,
                   let accountName = config["accountName"] as? String,
                   let authMethod = config["authMethod"] as? String {
                    popupStorageConfig.addItem(withTitle: "\(name) (\(accountName) - \(authMethod))")
                }
            }
            popupStorageConfig.isEnabled = true
        }
        
        updateButtonStates()
    }
    
    private func updateButtonStates() {
        let hasConfig = !storageConfigurations.isEmpty
        let hasFile = selectedFileURL != nil
        let hasUploadedFile = uploadedFileName != nil
        
        buttonUpload.isEnabled = hasConfig && hasFile
        buttonGenerateLink.isEnabled = hasConfig && hasUploadedFile
        buttonSendTeamsNotification.isEnabled = hasConfig && hasUploadedFile && !textViewLink.string.isEmpty
    }
    
    // MARK: - Actions
    
    @IBAction func selectFile(_ sender: NSButton) {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.json, .commaSeparatedText, .xml, .plainText, .archive]
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.title = "Select Test Report File"
        openPanel.message = "Select a report file to upload to Azure Storage"
        
        openPanel.begin { [weak self] result in
            if result == .OK, let selectedURL = openPanel.url {
                self?.selectedFileURL = selectedURL
                self?.labelSelectedFile.stringValue = selectedURL.lastPathComponent
                self?.addStatus("Selected file: \(selectedURL.lastPathComponent)")
                self?.updateButtonStates()
            }
        }
    }
    
    @IBAction func uploadFile(_ sender: NSButton) {
        guard let fileURL = selectedFileURL,
              let selectedConfig = getSelectedConfiguration() else {
            addStatus("❌ Error: No file or configuration selected")
            return
        }
        
        addStatus("📤 Starting upload...")
        setUIEnabled(false)
        progressIndicator.isHidden = false
        progressIndicator.startAnimation(nil)
        
        do {
            let fileData = try Data(contentsOf: fileURL)
            let fileName = fileURL.lastPathComponent
            
            // Upload via XPC
            XPCManager.shared.uploadFileToAzureStorage(
                fileName: fileName,
                fileData: fileData,
                configurationName: selectedConfig["name"] as? String ?? ""
            ) { [weak self] success in
                DispatchQueue.main.async {
                    self?.setUIEnabled(true)
                    self?.progressIndicator.stopAnimation(nil)
                    self?.progressIndicator.isHidden = true
                    
                    if let success = success, success {
                        self?.uploadedFileName = fileName
                        self?.addStatus("✅ Upload successful: \(fileName)")
                    } else {
                        self?.uploadedFileName = nil
                        self?.addStatus("❌ Upload failed")
                    }
                    
                    self?.updateButtonStates()
                }
            }
        } catch {
            setUIEnabled(true)
            progressIndicator.stopAnimation(nil)
            progressIndicator.isHidden = true
            addStatus("❌ Error reading file: \(error.localizedDescription)")
        }
    }
    
    @IBAction func generateDownloadLink(_ sender: NSButton) {
        guard let fileName = uploadedFileName,
              let selectedConfig = getSelectedConfiguration() else {
            addStatus("❌ Error: No uploaded file or configuration selected")
            return
        }
        
        let expirationDays = getSelectedExpirationDays()
        addStatus("🔗 Generating download link (expires in \(expirationDays) days)...")
        
        setUIEnabled(false)
        progressIndicator.isHidden = false
        progressIndicator.startAnimation(nil)
        
        XPCManager.shared.generateAzureStorageDownloadLink(
            fileName: fileName,
            configurationName: selectedConfig["name"] as? String ?? "",
            expiresInDays: expirationDays
        ) { [weak self] downloadURL in
            DispatchQueue.main.async {
                self?.setUIEnabled(true)
                self?.progressIndicator.stopAnimation(nil)
                self?.progressIndicator.isHidden = true
                
                if let url = downloadURL {
                    self?.textViewLink.string = url.absoluteString
                    self?.addStatus("✅ Download link generated (expires in \(expirationDays) days)")
                } else {
                    self?.textViewLink.string = ""
                    self?.addStatus("❌ Failed to generate download link")
                }
                
                self?.updateButtonStates()
            }
        }
    }
    
    @IBAction func sendTeamsNotification(_ sender: NSButton) {
        guard let fileName = uploadedFileName,
              !textViewLink.string.isEmpty else {
            addStatus("❌ Error: No uploaded file or download link available")
            return
        }
        
        addStatus("📢 Sending Teams notification...")
        setUIEnabled(false)
        
        let message = createTeamsMessage(fileName: fileName, downloadLink: textViewLink.string)
        
        XPCManager.shared.sendTeamsNotification(message: message) { [weak self] success in
            DispatchQueue.main.async {
                self?.setUIEnabled(true)
                
                if let success = success, success {
                    self?.addStatus("✅ Teams notification sent successfully")
                } else {
                    self?.addStatus("❌ Failed to send Teams notification")
                }
            }
        }
    }
    
    @IBAction func clearStatus(_ sender: NSButton) {
        textViewStatus.string = "Status cleared"
    }
    
    @IBAction func clearAll(_ sender: NSButton) {
        selectedFileURL = nil
        uploadedFileName = nil
        labelSelectedFile.stringValue = "No file selected"
        textViewLink.string = ""
        textViewStatus.string = "Ready to test Azure Storage functionality"
        updateButtonStates()
    }
    
    @IBAction func listFiles(_ sender: NSButton) {
        guard let selectedConfig = getSelectedConfiguration() else {
            addStatus("❌ Error: No configuration selected")
            return
        }
        
        addStatus("📂 Listing files in Azure Storage...")
        setUIEnabled(false)
        progressIndicator.isHidden = false
        progressIndicator.startAnimation(nil)
        
        XPCManager.shared.listAzureStorageFiles(configurationName: selectedConfig["name"] as? String ?? "") { [weak self] fileList in
            DispatchQueue.main.async {
                self?.setUIEnabled(true)
                self?.progressIndicator.stopAnimation(nil)
                self?.progressIndicator.isHidden = true
                
                if let files = fileList, !files.isEmpty {
                    self?.addStatus("✅ Found \(files.count) files:")
                    for file in files {
                        let name = file["name"] as? String ?? "unknown"
                        let size = file["sizeFormatted"] as? String ?? "unknown size"
                        let modified = file["lastModifiedFormatted"] as? String ?? "unknown date"
                        self?.addStatus("  📄 \(name) (\(size)) - \(modified)")
                    }
                } else {
                    self?.addStatus("📂 No files found in Azure Storage")
                }
            }
        }
    }
    
    @IBAction func deleteFile(_ sender: NSButton) {
        guard let fileName = uploadedFileName,
              let selectedConfig = getSelectedConfiguration() else {
            addStatus("❌ Error: No uploaded file or configuration selected")
            return
        }
        
        // Confirm deletion
        let alert = NSAlert()
        alert.messageText = "Delete File"
        alert.informativeText = "Are you sure you want to delete '\(fileName)' from Azure Storage? This action cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return }
        
        addStatus("🗑️ Deleting file: \(fileName)")
        setUIEnabled(false)
        progressIndicator.isHidden = false
        progressIndicator.startAnimation(nil)
        
        XPCManager.shared.deleteAzureStorageFile(fileName: fileName, configurationName: selectedConfig["name"] as? String ?? "") { [weak self] success in
            DispatchQueue.main.async {
                self?.setUIEnabled(true)
                self?.progressIndicator.stopAnimation(nil)
                self?.progressIndicator.isHidden = true
                
                if let success = success, success {
                    self?.addStatus("✅ File deleted successfully: \(fileName)")
                    self?.uploadedFileName = nil
                    self?.textViewLink.string = ""
                } else {
                    self?.addStatus("❌ Failed to delete file: \(fileName)")
                }
                
                self?.updateButtonStates()
            }
        }
    }
    
    @IBAction func deleteOldFiles(_ sender: NSButton) {
        guard let selectedConfig = getSelectedConfiguration() else {
            addStatus("❌ Error: No configuration selected")
            return
        }
        
        // Get age threshold from user
        let alert = NSAlert()
        alert.messageText = "Delete Old Files"
        alert.informativeText = "Delete files older than how many days?"
        alert.alertStyle = .informational
        
        let inputField = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        inputField.stringValue = "7"
        inputField.placeholderString = "Number of days"
        alert.accessoryView = inputField
        
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        guard response == .alertFirstButtonReturn,
              let days = Int(inputField.stringValue), days > 0 else { return }
        
        // Confirm deletion
        let confirmAlert = NSAlert()
        confirmAlert.messageText = "Confirm Deletion"
        confirmAlert.informativeText = "This will delete all files older than \(days) days from Azure Storage. This action cannot be undone."
        confirmAlert.alertStyle = .warning
        confirmAlert.addButton(withTitle: "Delete")
        confirmAlert.addButton(withTitle: "Cancel")
        
        let confirmResponse = confirmAlert.runModal()
        guard confirmResponse == .alertFirstButtonReturn else { return }
        
        addStatus("🧹 Deleting files older than \(days) days...")
        setUIEnabled(false)
        progressIndicator.isHidden = false
        progressIndicator.startAnimation(nil)
        
        XPCManager.shared.deleteOldAzureStorageFiles(configurationName: selectedConfig["name"] as? String ?? "", olderThanDays: days) { [weak self] summary in
            DispatchQueue.main.async {
                self?.setUIEnabled(true)
                self?.progressIndicator.stopAnimation(nil)
                self?.progressIndicator.isHidden = true
                
                if let summary = summary {
                    let deletedCount = summary["deletedCount"] as? Int ?? 0
                    let freedSize = summary["freedSizeFormatted"] as? String ?? "unknown"
                    let remainingCount = summary["remainingCount"] as? Int ?? 0
                    
                    self?.addStatus("✅ Cleanup completed:")
                    self?.addStatus("  📊 Deleted: \(deletedCount) files")
                    self?.addStatus("  💾 Freed: \(freedSize)")
                    self?.addStatus("  📂 Remaining: \(remainingCount) files")
                    
                    if deletedCount > 0 && self?.uploadedFileName != nil {
                        // Clear uploaded file info if it might have been deleted
                        self?.uploadedFileName = nil
                        self?.textViewLink.string = ""
                        self?.updateButtonStates()
                    }
                } else {
                    self?.addStatus("❌ Failed to delete old files")
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func getSelectedConfiguration() -> [String: Any]? {
        let selectedIndex = popupStorageConfig.indexOfSelectedItem
        guard selectedIndex >= 0 && selectedIndex < storageConfigurations.count else {
            return nil
        }
        return storageConfigurations[selectedIndex]
    }
    
    private func getSelectedExpirationDays() -> Int {
        switch popupLinkExpiration.indexOfSelectedItem {
        case 0: return 1
        case 1: return 2
        case 2: return 3
        case 3: return 7
        default: return 3
        }
    }
    
    private func createTeamsMessage(fileName: String, downloadLink: String) -> String {
        let expirationDays = getSelectedExpirationDays()
        let expirationDate = Calendar.current.date(byAdding: .day, value: expirationDays, to: Date()) ?? Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        
        return """
        📊 **Report Ready for Download**
        
        **File**: \(fileName)
        **Generated**: \(dateFormatter.string(from: Date()))
        **Download Link**: [Click here to download](\(downloadLink))
        **Expires**: \(dateFormatter.string(from: expirationDate))
        
        *This is a test notification from the Azure Storage test interface.*
        """
    }
    
    private func addStatus(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let statusMessage = "[\(timestamp)] \(message)\n"
        textViewStatus.string += statusMessage
        
        // Scroll to bottom
        let range = NSRange(location: textViewStatus.string.count, length: 0)
        textViewStatus.scrollRangeToVisible(range)
    }
    
    private func setUIEnabled(_ enabled: Bool) {
        buttonSelectFile.isEnabled = enabled
        buttonUpload.isEnabled = enabled && selectedFileURL != nil && !storageConfigurations.isEmpty
        buttonGenerateLink.isEnabled = enabled && uploadedFileName != nil && !storageConfigurations.isEmpty
        buttonSendTeamsNotification.isEnabled = enabled && uploadedFileName != nil && !textViewLink.string.isEmpty
        popupStorageConfig.isEnabled = enabled && !storageConfigurations.isEmpty
        popupLinkExpiration.isEnabled = enabled
        
        // File management buttons
        buttonListFiles?.isEnabled = enabled && !storageConfigurations.isEmpty
        buttonDeleteFile?.isEnabled = enabled && uploadedFileName != nil && !storageConfigurations.isEmpty
        buttonDeleteOldFiles?.isEnabled = enabled && !storageConfigurations.isEmpty
    }
}

// Note: XPC methods for Azure Storage testing are now implemented in XPCManager+AzureStorage.swift
