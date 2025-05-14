//
//  WizardStepProtocol.swift
//  Intuneomator
//
//  Created by Gil Burns on 3/3/25.
//

protocol WizardStepProtocol {
    var isStepCompleted: Bool { get } // ✅ Tracks if the step is complete
    var onCompletionStatusChanged: ((Bool) -> Void)? { get set } // ✅ Callback to notify parent
}

