//
//  XPCService+TaskScheduling.swift
//  Intuneomator
//
//  Created by Gil Burns on 5/4/25.
//

import Foundation

extension XPCService {
    
    // MARK: Task Scheduling
    func createOrUpdateScheduledTask(
        label: String,
        argument: String,
        scheduleData: Data,
        withReply reply: @escaping (Bool, String?) -> Void
    ) {
        Logger.log("createOrUpdateScheduledTask called for \(label)", logType: "TaskScheduling")
        
        do {
            guard let decoded = try NSKeyedUnarchiver.unarchivedObject(ofClasses: [NSArray.self, ScheduledTime.self], from: scheduleData) as? [ScheduledTime] else {
                reply(false, "Failed to decode schedule data.")
                return
            }
            
            let converted = decoded.map { schedule in
                return (
                    weekday: schedule.weekday?.intValue,
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
    
    func removeScheduledTask(
        label: String,
        withReply reply: @escaping (Bool, String?) -> Void
    ) {
        Logger.log("XPCService: createOrUpdateScheduledTask called for \(label)", logType: "TaskScheduling")
        
        ScheduledTaskManager.removeScheduledTask(label: label, completion: reply)
    }
    
    func taskExists(label: String, withReply reply: @escaping (Bool) -> Void) {
        reply(ScheduledTaskManager.taskExists(label: label))
    }
    

    
}
