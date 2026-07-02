import SwiftUI

// MARK: - Custom Environment Keys for Persona configuration
private struct IsPublicPersonaKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

private struct UseCustomDomainKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

public extension EnvironmentValues {
    var isPublicPersona: Bool {
        get { self[IsPublicPersonaKey.self] }
        set { self[IsPublicPersonaKey.self] = newValue }
    }

    var useCustomDomain: Bool {
        get { self[UseCustomDomainKey.self] }
        set { self[UseCustomDomainKey.self] = newValue }
    }
}
