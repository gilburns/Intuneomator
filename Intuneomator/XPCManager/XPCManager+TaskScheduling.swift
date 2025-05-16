//
//  XPCManager+ScheduledTasks.swift.swift
//  Intuneomator
//
//  Created by Gil Burns on 5/4/25.
//

import Foundation

extension XPCManager {
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
    
    func encodeScheduledTimes(_ schedules: [ScheduledTime]) -> Data? {
        do {
            return try NSKeyedArchiver.archivedData(withRootObject: schedules, requiringSecureCoding: true)
        } catch {
            print("❌ Failed to encode schedules: \(error)")
            return nil
        }
    }
    
}
