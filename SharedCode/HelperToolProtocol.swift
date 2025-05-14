//
//  HelperToolProtocol.swift
//  Intuneomator
//
//  Created by Gil Burns on 3/16/25.
//

import Foundation

@objc protocol HelperToolProtocol {
    func startDaemon(reply: @escaping (Bool) -> Void)
    func stopDaemon(reply: @escaping (Bool) -> Void)
}
