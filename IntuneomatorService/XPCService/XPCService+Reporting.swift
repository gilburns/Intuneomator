//
//  XPCService+AppsReporting.swift
//  Intuneomator
//
//  Created by Gil Burns on 7/11/25.
//

import Foundation

/// XPCService extension for Microsoft Intune App management operations
/// Handles secure communication with Microsoft Graph API endpoints for Intune App operations
/// All operations use authenticated tokens and provide comprehensive error handling through async callbacks
extension XPCService {
    // MARK: - Intune App Reporting Management
 
    /// Retrieves all apps from Microsoft Intune
    /// - Parameter reply: Callback with array of Intune app dictionaries or nil on failure
    func fetchIntuneApps(reply: @escaping ([[String : Any]]?) -> Void) {
        Task {
            do {
                let entraAuthenticator = EntraAuthenticator.shared
                let authToken = try await entraAuthenticator.getEntraIDToken()
                let webClips = try await EntraGraphRequests.fetchIntuneApps(authToken: authToken)
                reply(webClips)
            } catch {
                Logger.error("Failed to fetch Intune Apps: \(error.localizedDescription)", category: .core)
                reply(nil)
            }
        }
    }
    
    func getDeviceAppInstallationStatusReport(appId: String, reply: @escaping ([[String : Any]]?) -> Void) {
        Task {
            do {
                let entraAuthenticator = EntraAuthenticator.shared
                let authToken = try await entraAuthenticator.getEntraIDToken()
                let installationStatus = try await EntraGraphRequests.getDeviceAppInstallationStatusReport(authToken: authToken, appId: appId)
                reply(installationStatus)
            } catch {
                Logger.error("Failed to fetch Intune App installation status: \(error.localizedDescription)", category: .core)
                reply(nil)
            }
        }

    }
    
    // MARK: - Intune Configuration Profile Reporting Management

    /// Retrieves all configuration profiles from Microsoft Intune across all platforms
    /// - Parameter reply: Callback with array of Intune configuration profile dictionaries or nil on failure
    func fetchIntuneConfigurationProfiles(reply: @escaping ([[String : Any]]?) -> Void) {
        Task {
            do {
                let entraAuthenticator = EntraAuthenticator.shared
                let authToken = try await entraAuthenticator.getEntraIDToken()
                let configurationProfiles = try await EntraGraphRequests.fetchIntuneConfigurationProfiles(authToken: authToken)
                reply(configurationProfiles)
            } catch {
                Logger.error("Failed to fetch Intune Configuration Profiles: \(error.localizedDescription)", category: .core)
                reply(nil)
            }
        }
    }
    
    /// Retrieves device configuration profile deployment status report for a specific profile
    /// - Parameters:
    ///   - profileId: Unique identifier (GUID) of the configuration profile to get deployment status for
    ///   - reply: Callback with array of device deployment status dictionaries or nil on failure
    func getDeviceConfigProfileDeploymentStatusReport(profileId: String, reply: @escaping ([[String : Any]]?) -> Void) {
        Task {
            do {
                let entraAuthenticator = EntraAuthenticator.shared
                let authToken = try await entraAuthenticator.getEntraIDToken()
                
                // Check if this is a compliance policy based on profile data
                // For compliance policies, use the compliance-specific reporting endpoint
                let deploymentStatus = try await EntraGraphRequests.getDeviceConfigProfileDeploymentStatusReport(authToken: authToken, profileId: profileId)
                reply(deploymentStatus)
            } catch {
                Logger.error("Failed to fetch configuration profile deployment status: \(error.localizedDescription)", category: .core)
                reply(nil)
            }
        }
    }
    
    // MARK: - Microsoft Graph Export Jobs API
    
    /// Creates a new export job for a specific report type
    /// - Parameters:
    ///   - reportName: Name of the report to export (e.g., "DeviceInstallStatusByApp")
    ///   - filter: Optional OData filter string
    ///   - select: Optional array of column names to include
    ///   - format: Export format ("csv" or "json", defaults to "csv")
    ///   - reply: Callback with export job ID or nil on failure
    func createExportJob(reportName: String, filter: String?, select: [String]?, format: String, reply: @escaping (String?) -> Void) {
        Task {
            do {
                let entraAuthenticator = EntraAuthenticator.shared
                let authToken = try await entraAuthenticator.getEntraIDToken()
                let jobId = try await EntraGraphRequests.createExportJob(
                    authToken: authToken,
                    reportName: reportName,
                    filter: filter,
                    select: select,
                    format: format
                )
                reply(jobId)
            } catch {
                Logger.error("Failed to create export job for \(reportName): \(error.localizedDescription)", category: .core)
                reply(nil)
            }
        }
    }
    
    /// Checks the status of an export job
    /// - Parameters:
    ///   - jobId: Export job ID to check
    ///   - reply: Callback with job status dictionary or nil on failure
    func getExportJobStatus(jobId: String, reply: @escaping ([String: Any]?) -> Void) {
        Task {
            do {
                let entraAuthenticator = EntraAuthenticator.shared
                let authToken = try await entraAuthenticator.getEntraIDToken()
                let jobStatus = try await EntraGraphRequests.getExportJobStatus(authToken: authToken, jobId: jobId)
                reply(jobStatus)
            } catch {
                Logger.error("Failed to get export job status for \(jobId): \(error.localizedDescription)", category: .core)
                reply(nil)
            }
        }
    }
    
    /// Downloads completed export job data
    /// - Parameters:
    ///   - downloadUrl: Download URL from completed export job
    ///   - reply: Callback with downloaded data or nil on failure
    func downloadExportJobData(downloadUrl: String, reply: @escaping (Data?) -> Void) {
        Task {
            do {
                let entraAuthenticator = EntraAuthenticator.shared
                let authToken = try await entraAuthenticator.getEntraIDToken()
                let data = try await EntraGraphRequests.downloadExportJobData(authToken: authToken, downloadUrl: downloadUrl)
                reply(data)
            } catch {
                Logger.error("Failed to download export job data from \(downloadUrl): \(error.localizedDescription)", category: .core)
                reply(nil)
            }
        }
    }
    
    /// Polls an export job until completion and downloads the result
    /// - Parameters:
    ///   - jobId: Export job ID to poll
    ///   - maxWaitTimeSeconds: Maximum time to wait for completion (default: 300)
    ///   - pollIntervalSeconds: Interval between status checks (default: 5)
    ///   - reply: Callback with downloaded data or nil on failure
    func pollAndDownloadExportJob(jobId: String, maxWaitTimeSeconds: Int, pollIntervalSeconds: Int, reply: @escaping (Data?) -> Void) {
        Task {
            do {
                let entraAuthenticator = EntraAuthenticator.shared
                let authToken = try await entraAuthenticator.getEntraIDToken()
                let data = try await EntraGraphRequests.pollAndDownloadExportJob(
                    authToken: authToken,
                    jobId: jobId,
                    maxWaitTimeSeconds: maxWaitTimeSeconds,
                    pollIntervalSeconds: pollIntervalSeconds
                )
                reply(data)
            } catch {
                Logger.error("Failed to poll and download export job \(jobId): \(error.localizedDescription)", category: .core)
                reply(nil)
            }
        }
    }

    // MARK: - Export Jobs Report Types
    /// Creates a DeviceInstallStatusByApp export job with filtering options
    /// - Parameters:
    ///   - applicationId: Optional filter by specific application ID
    ///   - deviceName: Optional filter by device name
    ///   - userName: Optional filter by user name
    ///   - includeColumns: Optional array of specific columns to include
    ///   - format: Export format ("csv" or "json")
    ///   - reply: Callback with export job ID or nil on failure
    func createDeviceInstallStatusByAppExportJob(applicationId: String?, deviceName: String?, userName: String?, includeColumns: [String]?, format: String, reply: @escaping (String?) -> Void) {
        Task {
            do {
                let entraAuthenticator = EntraAuthenticator.shared
                let authToken = try await entraAuthenticator.getEntraIDToken()
                let jobId = try await EntraGraphRequests.createDeviceInstallStatusByAppExportJob(
                    authToken: authToken,
                    applicationId: applicationId,
                    deviceName: deviceName,
                    userName: userName,
                    includeColumns: includeColumns,
                    format: format
                )
                reply(jobId)
            } catch {
                Logger.error("Failed to create DeviceInstallStatusByApp export job: \(error.localizedDescription)", category: .core)
                reply(nil)
            }
        }
    }

    /// Creates a UserInstallStatusAggregateByApp export job with filtering options
    /// - Parameters:
    ///   - applicationId: Optional filter by specific application ID
    ///   - deviceName: Optional filter by device name
    ///   - userName: Optional filter by user name
    ///   - includeColumns: Optional array of specific columns to include
    ///   - reply: Callback with export job ID or nil on failure
    func createUserInstallStatusAggregateByAppExportJob(applicationId: String?, deviceName: String?, userName: String?, includeColumns: [String]?, format: String, reply: @escaping (String?) -> Void) {
        Task {
            do {
                let entraAuthenticator = EntraAuthenticator.shared
                let authToken = try await entraAuthenticator.getEntraIDToken()
                let jobId = try await EntraGraphRequests.createUserInstallStatusAggregateByAppExportJob(
                    authToken: authToken,
                    applicationId: applicationId,
                    deviceName: deviceName,
                    userName: userName,
                    includeColumns: includeColumns,
                    format: format
                )
                reply(jobId)
            } catch {
                Logger.error("Failed to create UserInstallStatusAggregateByApp export job: \(error.localizedDescription)", category: .core)
                reply(nil)
            }
        }
    }

    /// Creates a AppInvByDevice export job with filtering options
    /// - Parameters:
    ///   - deviceId: Mandatory filter by specific device ID
    ///   - includeColumns: Optional array of specific columns to include
    ///   - format: Export format ("csv" or "json")
    ///   - reply: Callback with export job ID or nil on failure
    func createAppInvByDeviceExportJob(deviceId: String, includeColumns: [String]?, format: String, reply: @escaping (String?) -> Void) {
        Task {
            do {
                let entraAuthenticator = EntraAuthenticator.shared
                let authToken = try await entraAuthenticator.getEntraIDToken()
                let jobId = try await EntraGraphRequests.createAppInvByDeviceExportJob(
                    authToken: authToken,
                    deviceId: deviceId,
                    includeColumns: includeColumns,
                    format: format
                )
                reply(jobId)
            } catch {
                Logger.error("Failed to create AppInvByDevice export job: \(error.localizedDescription)", category: .core)
                reply(nil)
            }
        }
    }

    /// Creates an AllAppsList export job
    /// - Parameters:
    ///   - includeColumns: Optional array of specific columns to include
    ///   - format: Export format ("csv" or "json")
    ///   - reply: Callback with export job ID or nil on failure
    func createAllAppsListExportJob(includeColumns: [String]?, format: String, reply: @escaping (String?) -> Void) {
        Task {
            do {
                let entraAuthenticator = EntraAuthenticator.shared
                let authToken = try await entraAuthenticator.getEntraIDToken()
                let jobId = try await EntraGraphRequests.createAllAppsListExportJob(
                    authToken: authToken,
                    includeColumns: includeColumns,
                    format: format
                )
                reply(jobId)
            } catch {
                Logger.error("Failed to create AllAppsList export job: \(error.localizedDescription)", category: .core)
                reply(nil)
            }
        }
    }

    /// Creates an AppInstallStatusAggregate export job
    /// - Parameters:
    ///   - platform: Optional filter by specific platform
    ///   - failedDevicePercentage: Optional filter by device failed percentage
    ///   - includeColumns: Optional array of specific columns to include
    ///   - format: Export format ("csv" or "json")
    ///   - reply: Callback with export job ID or nil on failure
    func createAppInstallStatusAggregateExportJob(platform: String?, failedDevicePercentage: String?, includeColumns: [String]?, format: String, reply: @escaping (String?) -> Void) {
        Task {
            do {
                let entraAuthenticator = EntraAuthenticator.shared
                let authToken = try await entraAuthenticator.getEntraIDToken()
                let jobId = try await EntraGraphRequests.createAppInstallStatusAggregateExportJob(
                    authToken: authToken,
                    platform: platform,
                    failedDevicePercentage: failedDevicePercentage,
                    includeColumns: includeColumns,
                    format: format
                )
                reply(jobId)
            } catch {
                Logger.error("Failed to create AppInstallStatusAggregate export job: \(error.localizedDescription)", category: .core)
                reply(nil)
            }
        }
    }

    /// Creates an AppInvAggregate export job
    /// - Parameters:
    ///   - includeColumns: Optional array of specific columns to include
    ///   - format: Export format ("csv" or "json")
    ///   - reply: Callback with export job ID or nil on failure
    func createAppInvAggregateExportJob(includeColumns: [String]?, format: String, reply: @escaping (String?) -> Void) {
        Task {
            do {
                let entraAuthenticator = EntraAuthenticator.shared
                let authToken = try await entraAuthenticator.getEntraIDToken()
                let jobId = try await EntraGraphRequests.createAppInvAggregateExportJob(
                    authToken: authToken,
                    includeColumns: includeColumns,
                    format: format
                )
                reply(jobId)
            } catch {
                Logger.error("Failed to create AppInvAggregate export job: \(error.localizedDescription)", category: .core)
                reply(nil)
            }
        }
    }

    /// Creates an AppInvRawData export job with filtering options
    /// - Parameters:
    ///   - applicationName: Optional filter by application name
    ///   - applicationPublisher: Optional filter by application publisher
    ///   - applicationShortVersion: Optional filter by application short version
    ///   - applicationVersion: Optional filter by application version
    ///   - deviceId: Optional filter by device ID
    ///   - deviceName: Optional filter by device name
    ///   - osDescription: Optional filter by OS description
    ///   - osVersion: Optional filter by OS version
    ///   - platform: Optional filter by platform
    ///   - userId: Optional filter by user ID
    ///   - emailAddress: Optional filter by email address
    ///   - userName: Optional filter by user name
    ///   - includeColumns: Optional array of specific columns to include
    ///   - format: Export format ("csv" or "json")
    ///   - reply: Callback with export job ID or nil on failure
    func createAppInvRawDataExportJob(applicationName: String?, applicationPublisher: String?, applicationShortVersion: String?, applicationVersion: String?, deviceId: String?, deviceName: String?, osDescription: String?, osVersion: String?, platform: String?, userId: String?, emailAddress: String?, userName: String?, includeColumns: [String]?, format: String, reply: @escaping (String?) -> Void) {
        Task {
            do {
                let entraAuthenticator = EntraAuthenticator.shared
                let authToken = try await entraAuthenticator.getEntraIDToken()
                let jobId = try await EntraGraphRequests.createAppInvRawDataExportJob(
                    authToken: authToken,
                    applicationName: applicationName,
                    applicationPublisher: applicationPublisher,
                    applicationShortVersion: applicationShortVersion,
                    applicationVersion: applicationVersion,
                    deviceId: deviceId,
                    deviceName: deviceName,
                    osDescription: osDescription,
                    osVersion: osVersion,
                    platform: platform,
                    userId: userId,
                    emailAddress: emailAddress,
                    userName: userName,
                    includeColumns: includeColumns,
                    format: format
                )
                reply(jobId)
            } catch {
                Logger.error("Failed to create AppInvRawData export job: \(error.localizedDescription)", category: .core)
                reply(nil)
            }
        }
    }

    /// Creates a DeviceCompliance export job with filtering options
    /// - Parameters:
    ///   - complianceState: Optional filter by compliance state
    ///   - os: Optional filter by operating system
    ///   - ownerType: Optional filter by owner type
    ///   - deviceType: Optional filter by device type
    ///   - includeColumns: Optional array of specific columns to include
    ///   - format: Export format ("csv" or "json")
    ///   - reply: Callback with export job ID or nil on failure
    func createDeviceComplianceExportJob(complianceState: String?, os: String?, ownerType: String?, deviceType: String?, includeColumns: [String]?, format: String, reply: @escaping (String?) -> Void) {
        Task {
            do {
                let entraAuthenticator = EntraAuthenticator.shared
                let authToken = try await entraAuthenticator.getEntraIDToken()
                let jobId = try await EntraGraphRequests.createDeviceComplianceExportJob(
                    authToken: authToken,
                    complianceState: complianceState,
                    os: os,
                    ownerType: ownerType,
                    deviceType: deviceType,
                    includeColumns: includeColumns,
                    format: format
                )
                reply(jobId)
            } catch {
                Logger.error("Failed to create DeviceCompliance export job: \(error.localizedDescription)", category: .core)
                reply(nil)
            }
        }
    }

    /// Creates a DeviceNonCompliance export job with filtering options
    /// - Parameters:
    ///   - complianceState: Optional filter by compliance state
    ///   - os: Optional filter by operating system
    ///   - ownerType: Optional filter by owner type
    ///   - deviceType: Optional filter by device type
    ///   - userId: Optional filter by user ID
    ///   - includeColumns: Optional array of specific columns to include
    ///   - format: Export format ("csv" or "json")
    ///   - reply: Callback with export job ID or nil on failure
    func createDeviceNonComplianceExportJob(complianceState: String?, os: String?, ownerType: String?, deviceType: String?, userId: String?, includeColumns: [String]?, format: String, reply: @escaping (String?) -> Void) {
        Task {
            do {
                let entraAuthenticator = EntraAuthenticator.shared
                let authToken = try await entraAuthenticator.getEntraIDToken()
                let jobId = try await EntraGraphRequests.createDeviceNonComplianceExportJob(
                    authToken: authToken,
                    complianceState: complianceState,
                    os: os,
                    ownerType: ownerType,
                    deviceType: deviceType,
                    userId: userId,
                    includeColumns: includeColumns,
                    format: format
                )
                reply(jobId)
            } catch {
                Logger.error("Failed to create DeviceNonCompliance export job: \(error.localizedDescription)", category: .core)
                reply(nil)
            }
        }
    }

    /// Creates a Devices export job with filtering options
    /// - Parameters:
    ///   - ownerType: Optional filter by owner type
    ///   - deviceType: Optional filter by device type
    ///   - managementAgents: Optional filter by management agents
    ///   - categoryName: Optional filter by category name
    ///   - managementState: Optional filter by management state
    ///   - compliantState: Optional filter by compliant state
    ///   - jailBroken: Optional filter by jail broken status
    ///   - enrollmentType: Optional filter by enrollment type
    ///   - includeColumns: Optional array of specific columns to include
    ///   - format: Export format ("csv" or "json")
    ///   - reply: Callback with export job ID or nil on failure
    func createDevicesExportJob(ownerType: String?, deviceType: String?, managementAgents: String?, categoryName: String?, managementState: String?, compliantState: String?, jailBroken: String?, enrollmentType: String?, includeColumns: [String]?, format: String, reply: @escaping (String?) -> Void) {
        Task {
            do {
                let entraAuthenticator = EntraAuthenticator.shared
                let authToken = try await entraAuthenticator.getEntraIDToken()
                let jobId = try await EntraGraphRequests.createDevicesExportJob(
                    authToken: authToken,
                    ownerType: ownerType,
                    deviceType: deviceType,
                    managementAgents: managementAgents,
                    categoryName: categoryName,
                    managementState: managementState,
                    compliantState: compliantState,
                    jailBroken: jailBroken,
                    enrollmentType: enrollmentType,
                    includeColumns: includeColumns,
                    format: format
                )
                reply(jobId)
            } catch {
                Logger.error("Failed to create Devices export job: \(error.localizedDescription)", category: .core)
                reply(nil)
            }
        }
    }

    /// Creates a DevicesWithInventory export job with filtering options
    /// - Parameters:
    ///   - createdDate: Optional filter by created date
    ///   - lastContact: Optional filter by last contact
    ///   - categoryName: Optional filter by category name
    ///   - compliantState: Optional filter by management agents
    ///   - managementAgents: Optional filter by management agents
    ///   - ownerType: Optional filter by specific owner type
    ///   - managementState: Optional filter by management state
    ///   - deviceType: Optional filter by device type
    ///   - jailBroken: Optional filter by jail broken state
    ///   - enrollmentType: Optional filter by enrollment type
    ///   - includeColumns: Optional array of specific columns to include
    ///   - format: Export format ("csv" or "json", defaults to "csv")
    ///   - reply: Callback with export job ID or nil on failure
    func createDevicesWithInventoryExportJob(createdDate: String?, lastContact: String?, categoryName: String?, compliantState: String?, managementAgents: String?, ownerType: String?, managementState: String?, deviceType: String?, jailBroken: String?, enrollmentType: String?, includeColumns: [String]?, format: String, reply: @escaping (String?) -> Void) {
        Task {
            do {
                let entraAuthenticator = EntraAuthenticator.shared
                let authToken = try await entraAuthenticator.getEntraIDToken()
                let jobId = try await EntraGraphRequests.createDevicesWithInventoryExportJob(
                    authToken: authToken,
                    createdDate: createdDate,
                    lastContact: lastContact,
                    categoryName: categoryName,
                    compliantState: compliantState,
                    managementAgents: managementAgents,
                    ownerType: ownerType,
                    managementState: managementState,
                    deviceType: deviceType,
                    jailBroken: jailBroken,
                    enrollmentType: enrollmentType,
                    includeColumns: includeColumns,
                    format: format
                )
                reply(jobId)
            } catch {
                Logger.error("Failed to create DevicesWithInventory export job: \(error.localizedDescription)", category: .core)
                reply(nil)
            }
        }
    }

    /// Creates a DefenderAgents export job with filtering options
    /// - Parameters:
    ///   - deviceState: Optional filter by device state
    ///   - signatureUpdateOverdue: Optional filter by signature update overdue status
    ///   - malwareProtectionEnabled: Optional filter by malware protection enabled status
    ///   - realTimeProtectionEnabled: Optional filter by real-time protection enabled status
    ///   - networkInspectionSystemEnabled: Optional filter by network inspection system enabled status
    ///   - includeColumns: Optional array of specific columns to include
    ///   - format: Export format ("csv" or "json")
    ///   - reportType: Report type identifier (defaults to "DefenderAgents")
    ///   - reply: Callback with export job ID or nil on failure
    func createDefenderAgentsExportJob(deviceState: String?, signatureUpdateOverdue: String?, malwareProtectionEnabled: String?, realTimeProtectionEnabled: String?, networkInspectionSystemEnabled: String?, includeColumns: [String]?, format: String, reportType: String, reply: @escaping (String?) -> Void) {
        Task {
            do {
                let entraAuthenticator = EntraAuthenticator.shared
                let authToken = try await entraAuthenticator.getEntraIDToken()
                let jobId = try await EntraGraphRequests.createDefenderAgentsExportJob(
                    authToken: authToken,
                    deviceState: deviceState,
                    signatureUpdateOverdue: signatureUpdateOverdue,
                    malwareProtectionEnabled: malwareProtectionEnabled,
                    realTimeProtectionEnabled: realTimeProtectionEnabled,
                    networkInspectionSystemEnabled: networkInspectionSystemEnabled,
                    includeColumns: includeColumns,
                    format: format,
                    reportType: reportType
                )
                reply(jobId)
            } catch {
                Logger.error("Failed to create DefenderAgents export job: \(error.localizedDescription)", category: .core)
                reply(nil)
            }
        }
    }

    /// Creates a FirewallStatus export job with filtering options
    /// - Parameters:
    ///   - firewallStatus: Optional filter by firewall status
    ///   - includeColumns: Optional array of specific columns to include
    ///   - format: Export format ("csv" or "json")
    ///   - reply: Callback with export job ID or nil on failure
    func createFirewallStatusExportJob(firewallStatus: String?, includeColumns: [String]?, format: String, reply: @escaping (String?) -> Void) {
        Task {
            do {
                let entraAuthenticator = EntraAuthenticator.shared
                let authToken = try await entraAuthenticator.getEntraIDToken()
                let jobId = try await EntraGraphRequests.createFirewallStatusExportJob(
                    authToken: authToken,
                    firewallStatus: firewallStatus,
                    includeColumns: includeColumns,
                    format: format
                )
                reply(jobId)
            } catch {
                Logger.error("Failed to create FirewallStatus export job: \(error.localizedDescription)", category: .core)
                reply(nil)
            }
        }
    }

    /// Creates a Malware export job with filtering options
    /// - Parameters:
    ///   - severity: Optional filter by severity
    ///   - executionState: Optional filter by execution state
    ///   - state: Optional filter by state
    ///   - includeColumns: Optional array of specific columns to include
    ///   - format: Export format ("csv" or "json")
    ///   - reportType: Report type identifier (defaults to "Malware")
    ///   - reply: Callback with export job ID or nil on failure
    func createMalwareExportJob(severity: String?, executionState: String?, state: String?, includeColumns: [String]?, format: String, reportType: String, reply: @escaping (String?) -> Void) {
        Task {
            do {
                let entraAuthenticator = EntraAuthenticator.shared
                let authToken = try await entraAuthenticator.getEntraIDToken()
                let jobId = try await EntraGraphRequests.createMalwareExportJob(
                    authToken: authToken,
                    severity: severity,
                    executionState: executionState,
                    state: state,
                    includeColumns: includeColumns,
                    format: format,
                    reportType: reportType
                )
                reply(jobId)
            } catch {
                Logger.error("Failed to create Malware export job: \(error.localizedDescription)", category: .core)
                reply(nil)
            }
        }
    }

    /// Creates a MAMAppProtectionStatus export job
    /// - Parameters:
    ///   - includeColumns: Optional array of specific columns to include
    ///   - format: Export format ("csv" or "json")
    ///   - reply: Callback with export job ID or nil on failure
    func createMAMAppProtectionStatusExportJob(includeColumns: [String]?, format: String, reply: @escaping (String?) -> Void) {
        Task {
            do {
                let entraAuthenticator = EntraAuthenticator.shared
                let authToken = try await entraAuthenticator.getEntraIDToken()
                let jobId = try await EntraGraphRequests.createMAMAppProtectionStatusExportJob(
                    authToken: authToken,
                    includeColumns: includeColumns,
                    format: format
                )
                reply(jobId)
            } catch {
                Logger.error("Failed to create MAMAppProtectionStatus export job: \(error.localizedDescription)", category: .core)
                reply(nil)
            }
        }
    }

    /// Creates a MAMAppConfigurationStatus export job
    /// - Parameters:
    ///   - includeColumns: Optional array of specific columns to include
    ///   - format: Export format ("csv" or "json")
    ///   - reply: Callback with export job ID or nil on failure
    func createMAMAppConfigurationStatusExportJob(includeColumns: [String]?, format: String, reply: @escaping (String?) -> Void) {
        Task {
            do {
                let entraAuthenticator = EntraAuthenticator.shared
                let authToken = try await entraAuthenticator.getEntraIDToken()
                let jobId = try await EntraGraphRequests.createMAMAppConfigurationStatusExportJob(
                    authToken: authToken,
                    includeColumns: includeColumns,
                    format: format
                )
                reply(jobId)
            } catch {
                Logger.error("Failed to create MAMAppConfigurationStatus export job: \(error.localizedDescription)", category: .core)
                reply(nil)
            }
        }
    }

    /// Creates a FeatureUpdatePolicyFailuresAggregate export job
    /// - Parameters:
    ///   - includeColumns: Optional array of specific columns to include
    ///   - format: Export format ("csv" or "json")
    ///   - reply: Callback with export job ID or nil on failure
    func createFeatureUpdatePolicyFailuresAggregateExportJob(includeColumns: [String]?, format: String, reply: @escaping (String?) -> Void) {
        Task {
            do {
                let entraAuthenticator = EntraAuthenticator.shared
                let authToken = try await entraAuthenticator.getEntraIDToken()
                let jobId = try await EntraGraphRequests.createFeatureUpdatePolicyFailuresAggregateExportJob(
                    authToken: authToken,
                    includeColumns: includeColumns,
                    format: format
                )
                reply(jobId)
            } catch {
                Logger.error("Failed to create FeatureUpdatePolicyFailuresAggregate export job: \(error.localizedDescription)", category: .core)
                reply(nil)
            }
        }
    }

    /// Creates a QualityUpdateDeviceStatusByPolicy export job with filtering options
    /// - Parameters:
    ///   - policyID: Required policy ID filter
    ///   - aggregateState: Optional filter by aggregate state
    ///   - ownerType: Optional filter by owner type
    ///   - includeColumns: Optional array of specific columns to include
    ///   - format: Export format ("csv" or "json")
    ///   - reply: Callback with export job ID or nil on failure
    func createQualityUpdateDeviceStatusByPolicyExportJob(policyID: String, aggregateState: String?, ownerType: String?, includeColumns: [String]?, format: String, reply: @escaping (String?) -> Void) {
        Task {
            do {
                let entraAuthenticator = EntraAuthenticator.shared
                let authToken = try await entraAuthenticator.getEntraIDToken()
                let jobId = try await EntraGraphRequests.createQualityUpdateDeviceStatusByPolicyExportJob(
                    authToken: authToken,
                    policyID: policyID,
                    aggregateState: aggregateState,
                    ownerType: ownerType,
                    includeColumns: includeColumns,
                    format: format
                )
                reply(jobId)
            } catch {
                Logger.error("Failed to create QualityUpdateDeviceStatusByPolicy export job: \(error.localizedDescription)", category: .core)
                reply(nil)
            }
        }
    }

}
