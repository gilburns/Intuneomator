//
//  XPCManager+TaskScheduling.swift
//  Intuneomator
//
//  Created by Gil Burns on 5/4/25.
//

import Foundation

/// XPCManager extension for Launch Daemon task scheduling operations
/// Provides GUI access to create, modify, and remove scheduled automation tasks
/// All scheduling operations create Launch Daemon plists for system-level execution
extension XPCManager {
    /// Creates or updates a scheduled Launch Daemon task with specified timing
    /// Encodes schedule data and delegates to the privileged service for plist creation
    /// - Parameters:
    ///   - label: Unique identifier for the scheduled task
    ///   - argument: Command line argument to pass to the task
    ///   - schedules: Array of ScheduledTime objects defining when task runs
    ///   - completion: Callback with success status and optional error message
    func createOrUpdateScheduledTask(
        label: String,
        argument: String,
        schedules: [ScheduledTime],
        completion: @escaping (Bool, String?) -> Void
    ) {
        guard let connection = self.connection else {
            completion(false, "XPC connection not available.")
            return
        }
        
        print("Creating/updating scheduled task...")
        print("Label: \(label)")
        print(argument)
        print("Schedules: \(schedules)")
        
        let proxy = connection.remoteObjectProxyWithErrorHandler { error in
            completion(false, "XPC error: \(error.localizedDescription)")
        } as? XPCServiceProtocol

        if proxy == nil {
            print("❌ XPCManager: Proxy cast to XPCServiceProtocol failed — likely interface or class mismatch.")
        } else {
            print("✅ XPCManager: Proxy successfully cast to XPCServiceProtocol.")
        }
        

        guard let encodedSchedules = encodeScheduledTimes(schedules) else {
            completion(false, "Failed to encode schedule data.")
            return
        }

        (connection.remoteObjectProxyWithErrorHandler { error in
            completion(false, "XPC error: \(error.localizedDescription)")
        } as? XPCServiceProtocol)?.createOrUpdateScheduledTask(
            label: label,
            argument: argument,
            scheduleData: encodedSchedules,
            withReply: completion
        )        
    }
    
    /// Removes a scheduled Launch Daemon task and unloads it from the system
    /// Delegates to the privileged service for secure daemon management
    /// - Parameters:
    ///   - label: Unique identifier of the task to remove
    ///   - completion: Callback with success status and optional error message
    func removeScheduledTask(
        label: String,
        completion: @escaping (Bool, String?) -> Void
    ) {
        guard let connection = self.connection else {
            completion(false, "XPC connection not available.")
            return
        }

        (connection.remoteObjectProxyWithErrorHandler { error in
            completion(false, "XPC error: \(error.localizedDescription)")
        } as? XPCServiceProtocol)?.removeScheduledTask(
            label: label,
            withReply: completion
        )
    }
    
    /// Encodes ScheduledTime objects for secure XPC transmission
    /// Uses NSKeyedArchiver with secure coding for safe data serialization
    /// - Parameter schedules: Array of ScheduledTime objects to encode
    /// - Returns: Encoded data suitable for XPC transmission or nil on failure
    func encodeScheduledTimes(_ schedules: [ScheduledTime]) -> Data? {
        do {
            return try NSKeyedArchiver.archivedData(withRootObject: schedules, requiringSecureCoding: true)
        } catch {
            print("❌ Failed to encode schedules: \(error)")
            return nil
        }
    }
    
}
