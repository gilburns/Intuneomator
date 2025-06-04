//
//  WizardStepProtocol.swift
//  Intuneomator
//
//  Created by Gil Burns on 3/3/25.
//

import Foundation

/// Protocol defining the interface for wizard step view controllers in the Entra ID setup flow
/// Provides standardized completion tracking, validation, and metadata for multi-step wizard navigation
/// Implemented by all wizard step view controllers to enable consistent wizard management
protocol WizardStepProtocol {
    
    // MARK: - Completion Status Properties
    
    /// Indicates whether this wizard step has been completed successfully
    /// Used by the wizard controller to determine if the user can proceed to the next step
    /// Should return true when all required inputs/actions for this step are satisfied
    var isStepCompleted: Bool { get }
    
    /// Callback closure invoked when the step's completion status changes
    /// Allows the wizard controller to respond immediately to step completion state changes
    /// Set by the wizard controller during step initialization to receive status updates
    var onCompletionStatusChanged: ((Bool) -> Void)? { get set }
    
    // MARK: - Navigation Control Methods
    
    /// Determines if the user can proceed from this wizard step to the next
    /// Called by the wizard controller when the next button is pressed
    /// Should perform any final validation before allowing navigation
    /// - Returns: Boolean indicating if navigation to the next step is allowed
    func canProceed() -> Bool
    
    /// Validates the current wizard step's inputs and configuration
    /// Called by the wizard controller before step completion
    /// Should verify all required data is present and properly formatted
    /// - Returns: Boolean indicating if step validation passed
    func validateStep() -> Bool
    
    // MARK: - Step Metadata Methods
    
    /// Provides the display title for this wizard step
    /// Used by the wizard controller for sidebar navigation and progress indication
    /// Should return a concise, user-friendly title describing the step's purpose
    /// - Returns: Localized string representing the step title
    func getStepTitle() -> String
    
    /// Provides a brief description of this wizard step's purpose
    /// Used by the wizard controller for additional context and help text
    /// Should return a short description explaining what the user needs to do
    /// - Returns: Localized string describing the step's function
    func getStepDescription() -> String
}

