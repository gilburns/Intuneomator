//
//  AzureStorageExample.swift
//  IntuneomatorService
//
//  Created by Gil Burns on 7/22/25.
//

import Foundation

/// Example usage of Azure Storage functionality
/// This file demonstrates how to configure and use Azure Storage for report management
class AzureStorageExample {
    
    // MARK: - Configuration Examples
    
    /// Example: Configure Azure Storage with shared key authentication
    static func configureWithSharedKey() async {
        do {
            // Set up configuration
            let config = AzureStorageManager.StorageConfig(
                accountName: "myintuneomatorstore",
                containerName: "intuneomator-reports",
                authMethod: .storageKey("your-storage-account-key-here")
            )
            
            // Create manager
            let manager = AzureStorageManager(config: config)
            
            // Test connection
            try await manager.testConnection()
            print("✅ Azure Storage configured successfully with shared key")
            
        } catch {
            print("❌ Failed to configure Azure Storage: \(error)")
        }
    }
    
    /// Example: Configure Azure Storage with SAS token authentication
    static func configureWithSASToken() async {
        do {
            // Set up configuration
            let config = AzureStorageManager.StorageConfig(
                accountName: "myintuneomatorstore",
                containerName: "intuneomator-reports",
                authMethod: .sasToken("sv=2023-11-03&ss=bfqt&srt=sco&sp=rwdlacupx&se=2025-12-31T23:59:59Z&st=2025-01-01T00:00:00Z&spr=https&sig=your-sas-signature-here")
            )
            
            // Create manager
            let manager = AzureStorageManager(config: config)
            
            // Test connection
            try await manager.testConnection()
            print("✅ Azure Storage configured successfully with SAS token")
            
        } catch {
            print("❌ Failed to configure Azure Storage: \(error)")
        }
    }
    
    // MARK: - Usage Examples
    
    /// Example: Upload a report file
    static func uploadReportExample() async {
        do {
            // Get configuration
            let config = try AzureStorageConfig.shared.createStorageConfig()
            let manager = AzureStorageManager(config: config)
            
            // Create a sample report file
            let reportURL = createSampleReport()
            
            // Upload the report
            try await manager.uploadReport(fileURL: reportURL)
            print("✅ Report uploaded successfully")
            
            // Clean up
            try? FileManager.default.removeItem(at: reportURL)
            
        } catch {
            print("❌ Failed to upload report: \(error)")
        }
    }
    
    /// Example: Generate a download link
    static func generateDownloadLinkExample() async {
        do {
            // Get configuration
            let config = try AzureStorageConfig.shared.createStorageConfig()
            let manager = AzureStorageManager(config: config)
            
            // Generate download link for a report (valid for 7 days)
            let downloadURL = try await manager.generateDownloadLink(
                for: "DeviceReport_2025-01-22.csv",
                expiresIn: 7
            )
            
            print("✅ Download link generated: \(downloadURL)")
            
        } catch {
            print("❌ Failed to generate download link: \(error)")
        }
    }
    
    /// Example: Clean up old reports
    static func cleanupOldReportsExample() async {
        do {
            // Get configuration
            let config = try AzureStorageConfig.shared.createStorageConfig()
            let manager = AzureStorageManager(config: config)
            
            // Delete reports older than 30 days
            try await manager.deleteOldReports(olderThan: 30)
            print("✅ Old reports cleaned up successfully")
            
        } catch {
            print("❌ Failed to clean up old reports: \(error)")
        }
    }
    
    // MARK: - XPC Integration Examples
    
    /// Example: Configure Azure Storage via XPC
    static func configureViaXPC() {
        XPCManager.shared.configureAzureStorageWithSharedKey(
            accountName: "myintuneomatorstore",
            accountKey: "your-storage-account-key-here",
            containerName: "intuneomator-reports"
        ) { success in
            if success {
                print("✅ Azure Storage configured via XPC")
            } else {
                print("❌ Failed to configure Azure Storage via XPC")
            }
        }
    }
    
    /// Example: Upload report via XPC
    static func uploadReportViaXPC() {
        let reportURL = createSampleReport()
        
        XPCManager.shared.uploadReportToAzureStorage(fileURL: reportURL) { success in
            if success {
                print("✅ Report uploaded via XPC")
            } else {
                print("❌ Failed to upload report via XPC")
            }
            
            // Clean up
            try? FileManager.default.removeItem(at: reportURL)
        }
    }
    
    /// Example: Health check via XPC
    static func performHealthCheckViaXPC() {
        XPCManager.shared.performAzureStorageHealthCheck { status in
            print("Azure Storage Health: \(status.description)")
            
            if status.isHealthy {
                print("✅ Azure Storage is ready for use")
            } else {
                print("❌ Azure Storage needs attention")
            }
        }
    }
    
    // MARK: - Automation Examples
    
    /// Example: Automated report upload workflow
    static func automatedReportWorkflow() async {
        print("🔄 Starting automated report workflow...")
        
        // 1. Check if Azure Storage is configured
        guard AzureStorageConfig.shared.isConfigured else {
            print("❌ Azure Storage not configured - skipping upload")
            return
        }
        
        do {
            // 2. Create manager
            let config = try AzureStorageConfig.shared.createStorageConfig()
            let manager = AzureStorageManager(config: config)
            
            // 3. Create sample reports
            let deviceReport = createSampleDeviceReport()
            let appReport = createSampleAppReport()
            
            // 4. Upload reports
            try await manager.uploadReport(fileURL: deviceReport)
            print("✅ Device report uploaded")
            
            try await manager.uploadReport(fileURL: appReport)
            print("✅ App report uploaded")
            
            // 5. Generate download links
            let deviceDownloadLink = try await manager.generateDownloadLink(
                for: deviceReport.lastPathComponent,
                expiresIn: 7
            )
            print("📎 Device report link: \(deviceDownloadLink)")
            
            // 6. Clean up old reports (older than 90 days)
            try await manager.deleteOldReports(olderThan: 90)
            print("🧹 Old reports cleaned up")
            
            // 7. Clean up local files
            try? FileManager.default.removeItem(at: deviceReport)
            try? FileManager.default.removeItem(at: appReport)
            
            print("✅ Automated workflow completed successfully")
            
        } catch {
            print("❌ Automated workflow failed: \(error)")
        }
    }
    
    // MARK: - Helper Methods
    
    /// Creates a sample report file for testing
    private static func createSampleReport() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let reportURL = tempDir.appendingPathComponent("SampleReport_\(Date().timeIntervalSince1970).csv")
        
        let csvContent = """
        Device Name,Operating System,Last Sync,Compliance Status
        MacBook-Pro-001,macOS 14.6,2025-01-22 10:30:00,Compliant
        MacBook-Air-002,macOS 14.5,2025-01-22 09:45:00,Non-Compliant
        iMac-003,macOS 14.6,2025-01-22 11:15:00,Compliant
        """
        
        try? csvContent.write(to: reportURL, atomically: true, encoding: .utf8)
        return reportURL
    }
    
    /// Creates a sample device report file
    private static func createSampleDeviceReport() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: Date())
        let reportURL = tempDir.appendingPathComponent("DeviceReport_\(timestamp).csv")
        
        let csvContent = """
        Device ID,Device Name,User,Operating System,Compliance,Last Sync
        12345678-1234-1234-1234-123456789012,MacBook-Pro-001,john.doe@company.com,macOS 14.6.1,Compliant,2025-01-22T10:30:00Z
        12345678-1234-1234-1234-123456789013,MacBook-Air-002,jane.smith@company.com,macOS 14.5.2,Non-Compliant,2025-01-22T09:45:00Z
        12345678-1234-1234-1234-123456789014,iMac-003,bob.johnson@company.com,macOS 14.6.1,Compliant,2025-01-22T11:15:00Z
        """
        
        try? csvContent.write(to: reportURL, atomically: true, encoding: .utf8)
        return reportURL
    }
    
    /// Creates a sample app report file
    private static func createSampleAppReport() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: Date())
        let reportURL = tempDir.appendingPathComponent("AppReport_\(timestamp).csv")
        
        let csvContent = """
        App Name,Version,Publisher,Install Status,Device Count
        Microsoft Office,16.80,Microsoft Corporation,Installed,125
        Google Chrome,120.0.6099.234,Google LLC,Installed,98
        Slack,4.36.0,Slack Technologies,Failed,3
        Adobe Acrobat,23.008.20470,Adobe Inc.,Installed,87
        """
        
        try? csvContent.write(to: reportURL, atomically: true, encoding: .utf8)
        return reportURL
    }
}

// MARK: - Launch Daemon Integration Example

/// Example of how this could be integrated into a Launch Daemon task
class AzureStorageScheduledTask {
    
    /// Example scheduled task that uploads reports and cleans up old files using default configuration
    static func performScheduledReportUpload() async {
        Logger.info("Starting scheduled Azure Storage report upload task", category: .core)
        
        guard AzureStorageConfig.shared.isConfigured else {
            Logger.warning("Azure Storage not configured - skipping scheduled upload", category: .core)
            return
        }
        
        do {
            let config = try AzureStorageConfig.shared.createStorageConfig()
            let manager = AzureStorageManager(config: config)
            
            // Upload any pending reports from the reports directory
            let reportsDirectory = URL(fileURLWithPath: "/Library/Application Support/Intuneomator/Reports")
            
            if FileManager.default.fileExists(atPath: reportsDirectory.path) {
                let reportFiles = try FileManager.default.contentsOfDirectory(at: reportsDirectory, includingPropertiesForKeys: nil)
                
                for reportFile in reportFiles where reportFile.pathExtension.lowercased() == "csv" {
                    try await manager.uploadReport(fileURL: reportFile)
                    Logger.info("Uploaded report: \(reportFile.lastPathComponent)", category: .core)
                    
                    // Optionally remove local file after successful upload
                    try FileManager.default.removeItem(at: reportFile)
                }
            }
            
            // Clean up reports older than 30 days
            try await manager.deleteOldReports(olderThan: 30)
            Logger.info("Completed scheduled Azure Storage task", category: .core)
            
        } catch {
            Logger.error("Scheduled Azure Storage task failed: \(error.localizedDescription)", category: .core)
        }
    }
}

// MARK: - Multiple Named Configuration Examples

/// Comprehensive examples for multiple named Azure Storage configurations
class MultipleAzureStorageConfigurationExamples {
    
    // MARK: - Configuration Setup Examples
    
    /// Example: Set up multiple named configurations for different use cases
    static func setupMultipleConfigurations() async {
        print("🔧 Setting up multiple Azure Storage configurations...")
        
        // 1. Teams Reports Configuration (for human consumption via Teams notifications)
        let teamsConfig = AzureStorageConfig.NamedStorageConfiguration(
            name: "teams-reports",
            accountName: "myintuneomatorteams",
            containerName: "teams-notifications",
            authMethod: .storageKey("teams-storage-key-here"),
            description: "Storage for reports shared via Teams notifications for human consumption",
            created: Date(),
            modified: Date()
        )
        
        let teamsSuccess = AzureStorageConfig.shared.setConfiguration(named: "teams-reports", configuration: teamsConfig)
        print(teamsSuccess ? "✅ Teams reports configuration created" : "❌ Failed to create teams configuration")
        
        // 2. Azure Pipelines Configuration (for automated processing)
        let pipelineConfig = AzureStorageConfig.NamedStorageConfiguration(
            name: "azure-pipelines",
            accountName: "myintuneomatorpipeline",
            containerName: "pipeline-automation",
            authMethod: .sasToken("sv=2023-11-03&ss=bfqt&srt=sco&sp=rwdlacupx&se=2025-12-31T23:59:59Z&st=2025-01-01T00:00:00Z&spr=https&sig=pipeline-sas-signature"),
            description: "Storage for automated processing via Azure Pipelines and Runbooks",
            created: Date(),
            modified: Date()
        )
        
        let pipelineSuccess = AzureStorageConfig.shared.setConfiguration(named: "azure-pipelines", configuration: pipelineConfig)
        print(pipelineSuccess ? "✅ Azure Pipelines configuration created" : "❌ Failed to create pipeline configuration")
        
        // 3. Compliance Archive Configuration (for long-term retention)
        let complianceConfig = AzureStorageConfig.NamedStorageConfiguration(
            name: "compliance-archive",
            accountName: "myintuneomatorcompliance",
            containerName: "compliance-archive",
            authMethod: .azureAD(tenantId: "tenant-id-here", clientId: "client-id-here", clientSecret: "client-secret-here"),
            description: "Long-term compliance archive with enhanced security",
            created: Date(),
            modified: Date()
        )
        
        let complianceSuccess = AzureStorageConfig.shared.setConfiguration(named: "compliance-archive", configuration: complianceConfig)
        print(complianceSuccess ? "✅ Compliance archive configuration created" : "❌ Failed to create compliance configuration")
        
        // 4. Development Environment Configuration
        let devConfig = AzureStorageConfig.NamedStorageConfiguration(
            name: "development",
            accountName: "myintuneomatordev",
            containerName: "dev-reports",
            authMethod: .storageKey("dev-storage-key-here"),
            description: "Development environment for testing report uploads",
            created: Date(),
            modified: Date()
        )
        
        let devSuccess = AzureStorageConfig.shared.setConfiguration(named: "development", configuration: devConfig)
        print(devSuccess ? "✅ Development configuration created" : "❌ Failed to create development configuration")
        
        // List all available configurations
        let availableConfigs = AzureStorageConfig.shared.availableConfigurationNames
        print("📋 Available configurations: \(availableConfigs)")
        
        // Get configuration summaries
        let summaries = AzureStorageConfig.shared.getConfigurationSummaries()
        for summary in summaries {
            print("📊 \(summary.name): \(summary.accountName)/\(summary.containerName) (\(summary.authMethod)) - Valid: \(summary.isValid)")
        }
    }
    
    // MARK: - Static Manager Method Examples
    
    /// Example: Using static convenience methods for named configurations
    static func staticManagerMethodExamples() async {
        print("🚀 Testing static manager convenience methods...")
        
        do {
            // Create sample reports
            let deviceReport = createSampleDeviceReport()
            let appReport = createSampleAppReport()
            
            // 1. Upload using named configuration
            try await AzureStorageManager.uploadReport(withConfig: "teams-reports", fileURL: deviceReport)
            print("✅ Uploaded device report to teams-reports using static method")
            
            // 2. Upload with fallback
            let usedConfig = try await AzureStorageManager.uploadReportWithFallback(
                fileURL: appReport,
                primaryConfig: "azure-pipelines",
                fallbackConfig: "teams-reports"
            )
            print("✅ Uploaded app report using config: \(usedConfig)")
            
            // 3. Generate download link using named configuration
            let downloadURL = try await AzureStorageManager.generateDownloadLink(
                withConfig: "teams-reports",
                for: deviceReport.lastPathComponent,
                expiresIn: 7
            )
            print("✅ Generated download link: \(downloadURL)")
            
            // 4. Validate connection
            let isValid = await AzureStorageManager.validateConnection(withConfig: "teams-reports")
            print("✅ Teams configuration validation: \(isValid ? "Valid" : "Invalid")")
            
            // 5. List available configurations
            let configs = AzureStorageManager.availableConfigurationNames()
            print("📋 Available configs via manager: \(configs)")
            
            // Clean up
            try? FileManager.default.removeItem(at: deviceReport)
            try? FileManager.default.removeItem(at: appReport)
            
        } catch {
            print("❌ Static manager example failed: \(error)")
        }
    }
    
    // MARK: - Batch Operations Examples
    
    /// Example: Batch upload to multiple configurations simultaneously
    static func batchUploadExample() async {
        print("📤 Testing batch upload to multiple configurations...")
        
        let reportFile = createSampleDeviceReport()
        
        // Upload to multiple configurations in parallel
        let results = await AzureStorageManager.uploadReportToMultipleConfigs(
            fileURL: reportFile,
            configNames: ["teams-reports", "azure-pipelines", "compliance-archive"]
        )
        
        // Process results
        for (configName, result) in results {
            switch result {
            case .success:
                print("✅ Successfully uploaded to \(configName)")
            case .failure(let error):
                print("❌ Failed to upload to \(configName): \(error.localizedDescription)")
            }
        }
        
        // Clean up
        try? FileManager.default.removeItem(at: reportFile)
    }
    
    // MARK: - XPC Integration Examples (GUI-side usage)
    
    /// Example: How GUI components would use multiple configurations via XPC
    static func xpcIntegrationExamples() {
        print("🔗 XPC Integration examples for GUI usage...")
        
        // 1. Get configuration names for dropdown population
        XPCManager.shared.getConfigurationMenuItems { menuItems in
            print("📋 Menu items for GUI dropdown:")
            for (name, displayLabel) in menuItems {
                print("  • \(name): \(displayLabel)")
            }
        }
        
        // 2. Create new configuration via XPC
        XPCManager.shared.createNamedAzureStorageConfiguration(
            name: "production-reports",
            accountName: "myintuneomatorprod",
            accountKey: "production-key-here",
            containerName: "production-reports",
            description: "Production environment reports"
        ) { success in
            print(success ? "✅ Production config created via XPC" : "❌ Failed to create production config")
        }
        
        // 3. Upload report to specific configuration via XPC
        let sampleReport = createSampleDeviceReport()
        XPCManager.shared.uploadReportToNamedAzureStorage(
            fileURL: sampleReport,
            configurationName: "teams-reports"
        ) { success in
            print(success ? "✅ Report uploaded via XPC" : "❌ XPC upload failed")
            try? FileManager.default.removeItem(at: sampleReport)
        }
        
        // 4. Smart upload with fallback via XPC
        let fallbackReport = createSampleAppReport()
        XPCManager.shared.uploadReportWithFallback(
            fileURL: fallbackReport,
            preferredConfigurationName: "azure-pipelines"
        ) { success, configUsed in
            print("📤 Fallback upload result: \(success ? "Success" : "Failed") using config: \(configUsed)")
            try? FileManager.default.removeItem(at: fallbackReport)
        }
        
        // 5. Get configuration summaries via XPC
        XPCManager.shared.getAzureStorageConfigurationSummaries { summaries in
            print("📊 Configuration summaries via XPC:")
            for summary in summaries {
                if let name = summary["name"] as? String,
                   let accountName = summary["accountName"] as? String,
                   let isValid = summary["isValid"] as? Bool {
                    print("  • \(name): \(accountName) - \(isValid ? "Valid" : "Invalid")")
                }
            }
        }
    }
    
    // MARK: - Real-World Workflow Examples
    
    /// Example: Automated report distribution workflow
    static func automatedReportDistributionWorkflow() async {
        print("🔄 Automated report distribution workflow example...")
        
        do {
            // 1. Generate reports
            let deviceReport = createSampleDeviceReport()
            let complianceReport = createSampleAppReport()
            
            // 2. Upload device report to Teams for immediate human review
            try await AzureStorageManager.uploadReport(withConfig: "teams-reports", fileURL: deviceReport)
            print("✅ Device report sent to Teams for human review")
            
            // 3. Upload device report to Azure Pipelines for automated processing
            try await AzureStorageManager.uploadReport(withConfig: "azure-pipelines", fileURL: deviceReport)
            print("✅ Device report sent to Azure Pipelines for automation")
            
            // 4. Upload compliance report to archive for long-term retention
            try await AzureStorageManager.uploadReport(withConfig: "compliance-archive", fileURL: complianceReport)
            print("✅ Compliance report archived for long-term retention")
            
            // 5. Generate download links for Teams notifications
            let teamsDownloadLink = try await AzureStorageManager.generateDownloadLink(
                withConfig: "teams-reports",
                for: deviceReport.lastPathComponent,
                expiresIn: 7
            )
            print("📎 Teams download link: \(teamsDownloadLink)")
            
            // 6. Cleanup old reports from all configurations
            for configName in ["teams-reports", "azure-pipelines", "compliance-archive"] {
                do {
                    try await AzureStorageManager.deleteOldReports(withConfig: configName, olderThan: 30)
                    print("🧹 Cleaned up old reports from \(configName)")
                } catch {
                    print("⚠️ Cleanup failed for \(configName): \(error.localizedDescription)")
                }
            }
            
            // Clean up local files
            try? FileManager.default.removeItem(at: deviceReport)
            try? FileManager.default.removeItem(at: complianceReport)
            
            print("✅ Automated workflow completed successfully")
            
        } catch {
            print("❌ Automated workflow failed: \(error)")
        }
    }
    
    /// Example: Development to production promotion workflow
    static func developmentToProductionWorkflow() async {
        print("🚀 Development to production promotion workflow...")
        
        do {
            let testReport = createSampleDeviceReport()
            
            // 1. Test upload in development environment
            try await AzureStorageManager.uploadReport(withConfig: "development", fileURL: testReport)
            print("✅ Report tested in development environment")
            
            // 2. Validate production configuration
            let isProductionValid = await AzureStorageManager.validateConnection(withConfig: "teams-reports")
            guard isProductionValid else {
                print("❌ Production configuration is invalid - aborting promotion")
                return
            }
            
            // 3. Promote to production with fallback
            let usedConfig = try await AzureStorageManager.uploadReportWithFallback(
                fileURL: testReport,
                primaryConfig: "teams-reports",
                fallbackConfig: "development"
            )
            
            if usedConfig == "teams-reports" {
                print("✅ Successfully promoted to production")
            } else {
                print("⚠️ Fallback used - check production configuration")
            }
            
            // Clean up
            try? FileManager.default.removeItem(at: testReport)
            
        } catch {
            print("❌ Development to production workflow failed: \(error)")
        }
    }
    
    // MARK: - Configuration Management Examples
    
    /// Example: Configuration validation and health checking
    static func configurationHealthCheck() async {
        print("🏥 Configuration health check example...")
        
        let configNames = AzureStorageManager.availableConfigurationNames()
        
        for configName in configNames {
            print("🔍 Checking configuration: \(configName)")
            
            // Basic validation
            let isValid = AzureStorageManager.isConfigurationValid(configName)
            print("  📋 Basic validation: \(isValid ? "✅ Valid" : "❌ Invalid")")
            
            // Connection test
            let canConnect = await AzureStorageManager.validateConnection(withConfig: configName)
            print("  🔗 Connection test: \(canConnect ? "✅ Connected" : "❌ Failed")")
        }
    }
    
    /// Example: Configuration cleanup and maintenance
    static func configurationMaintenance() {
        print("🧹 Configuration maintenance example...")
        
        // Get all configuration summaries
        let summaries = AzureStorageConfig.shared.getConfigurationSummaries()
        
        for summary in summaries {
            print("📊 Configuration: \(summary.name)")
            print("  Account: \(summary.accountName)")
            print("  Container: \(summary.containerName)")
            print("  Auth Method: \(summary.authMethod)")
            print("  Created: \(summary.created)")
            print("  Modified: \(summary.modified)")
            print("  Valid: \(summary.isValid ? "✅" : "❌")")
            
            // Remove invalid configurations older than 30 days
            if !summary.isValid && summary.created.timeIntervalSinceNow < -30 * 24 * 60 * 60 {
                let removed = AzureStorageConfig.shared.removeConfiguration(named: summary.name)
                print("  🗑️ Removed old invalid configuration: \(removed ? "Success" : "Failed")")
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// Creates a sample device report file
    private static func createSampleDeviceReport() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: Date())
        let reportURL = tempDir.appendingPathComponent("DeviceReport_\(timestamp).csv")
        
        let csvContent = """
        Device ID,Device Name,User,Operating System,Compliance,Last Sync,Location
        12345678-1234-1234-1234-123456789012,MacBook-Pro-001,john.doe@company.com,macOS 14.6.1,Compliant,2025-01-22T10:30:00Z,New York
        12345678-1234-1234-1234-123456789013,MacBook-Air-002,jane.smith@company.com,macOS 14.5.2,Non-Compliant,2025-01-22T09:45:00Z,London
        12345678-1234-1234-1234-123456789014,iMac-003,bob.johnson@company.com,macOS 14.6.1,Compliant,2025-01-22T11:15:00Z,Tokyo
        12345678-1234-1234-1234-123456789015,MacBook-Pro-004,alice.wilson@company.com,macOS 14.6.1,Compliant,2025-01-22T12:00:00Z,Sydney
        """
        
        try? csvContent.write(to: reportURL, atomically: true, encoding: .utf8)
        return reportURL
    }
    
    /// Creates a sample app report file
    private static func createSampleAppReport() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: Date())
        let reportURL = tempDir.appendingPathComponent("AppReport_\(timestamp).csv")
        
        let csvContent = """
        App Name,Version,Publisher,Install Status,Device Count,Compliance Impact
        Microsoft Office,16.80,Microsoft Corporation,Installed,125,Low
        Google Chrome,120.0.6099.234,Google LLC,Installed,98,Medium
        Slack,4.36.0,Slack Technologies,Failed,3,High
        Adobe Acrobat,23.008.20470,Adobe Inc.,Installed,87,Low
        Zoom,5.16.10,Zoom Video Communications,Installed,156,Medium
        """
        
        try? csvContent.write(to: reportURL, atomically: true, encoding: .utf8)
        return reportURL
    }
}
