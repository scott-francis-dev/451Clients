//
//  ClientApp.swift
//  Core451
//
//  Identifies which 451 client app is running. Injected explicitly at launch
//  (a deliberate choice, not bundle-id sniffing) so shared UI can adapt.
//

import SwiftUI

/// The concrete 451 client app that is currently running.
public enum ClientApp: String, Sendable, CaseIterable {
    case thesis
    case signator
}

private struct ClientAppKey: EnvironmentKey {
    static let defaultValue: ClientApp = .thesis
}

public extension EnvironmentValues {
    /// The 451 client app that is currently running.
    var clientApp: ClientApp {
        get { self[ClientAppKey.self] }
        set { self[ClientAppKey.self] = newValue }
    }
}
