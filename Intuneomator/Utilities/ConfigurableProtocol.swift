//
//  ConfigurableProtocol.swift
//  Intuneomator
//
//  Created by Gil Burns on 1/11/25.
//

// ConfigurableProtocol.swift
import Foundation

protocol Configurable {
    func configure(with data: Any, parent: TabViewController)
}

