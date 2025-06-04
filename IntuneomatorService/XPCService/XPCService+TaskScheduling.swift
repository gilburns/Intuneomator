//
//  XPCService+TaskScheduling.swift
//  Intuneomator
//
//  Created by Gil Burns on 5/4/25.
//

import Foundation

/// XPCService extension for Launch Daemon task scheduling operations
/// Manages creation, modification, and removal of scheduled automation tasks
/// All scheduling operations use Launch Daemons for system-level execution
extension XPCService {
    
    // MARK: - Task Scheduling Operations
    /// Creates or updates a scheduled Launch Daemon task with specified timing
    /// Decodes schedule data and configures Launch Daemon plist for automated execution
    /// - Parameters:
    ///   - label: Unique identifier for the scheduled task
    ///   - argument: Command line argument to pass to the task
    ///   - scheduleData: Encoded ScheduledTime array data defining when task runs
    ///   - reply: Callback with success status and optional error message
    func createOrUpdateScheduledTask(
        label: String,
        argument: String,
        scheduleData: Data,
        withReply reply: @escaping (Bool, String?) -> Void
    ) {
        Logger.log("createOrUpdateScheduledTask called for \(label)", logType: logType)
        
        do {
            guard let decoded = try NSKeyedUnarchiver.unarchivedObject(ofClasses: [NSArray.self, ScheduledTime.self], from: scheduleData) as? [ScheduledTime] else {
                reply(false, "Failed to decode schedule data.")
                return
            }
            
            let converted = decoded.map { schedule in
                return (
                    weekday: schedule.weekday.flatMap { Weekday(rawValue: $0.intValue) },
                    hour: schedule.hour,
                    minute: schedule.minute
                )
            }

            ScheduledTaskManager.configureScheduledTask(
                label: label,
                argument: argument,
                schedules: converted,
                completion: reply
            )
        } catch {
            reply(false, "XPC decode error: \(error.localizedDescription)")
        }
    }
    
    /// Removes a scheduled Launch Daemon task and unloads it from the system
    /// Deletes associated plist file and stops any running task instances
    /// - Parameters:
    ///   - label: Unique identifier of the task to remove
    ///   - reply: Callback with success status and optional error message
    func removeScheduledTask(
        label: String,
        withReply reply: @escaping (Bool, String?) -> Void
    ) {
        Logger.log("XPCService: removeScheduledTask called for \(label)", logType: logType)
        
        ScheduledTaskManager.removeScheduledTask(label: label, completion: reply)
    }
    
    /// Checks if a scheduled task with the specified label currently exists
    /// Verifies both plist file existence and Launch Daemon registration
    /// - Parameters:
    ///   - label: Unique identifier of the task to check
    ///   - reply: Callback with boolean indicating task existence status
    func taskExists(label: String, withReply reply: @escaping (Bool) -> Void) {
        reply(ScheduledTaskManager.taskExists(label: label))
    }
    

    
}
