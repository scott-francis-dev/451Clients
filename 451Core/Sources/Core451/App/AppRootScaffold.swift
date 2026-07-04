//
//  AppRootScaffold.swift
//  Core451
//
//  Sequences the shared 451 app-root flow: splash -> first-run onboarding
//  (shown once, tracked per-app) -> optional persona gate -> main content.
//
//  Soft-gate apps (e.g. thesis) use the convenience initializer where the
//  gate is `EmptyView` and `configuration.requiresPersona` is `false`, so the
//  gate stage is skipped entirely.
//

import SwiftUI

public struct AppRootScaffold<Splash: View, Content: View, Gate: View>: View {

    private enum Stage {
        case splash
        case onboarding
        case gate
        case content
    }

    private let clientApp: ClientApp
    private let configuration: OnboardingConfiguration
    private let splash: (@escaping () -> Void) -> Splash
    private let gate: (@escaping () -> Void) -> Gate
    private let content: () -> Content

    @AppStorage private var hasCompletedOnboarding: Bool
    @State private var stage: Stage = .splash

    /// Full initializer for hard-gate apps that supply a persona gate.
    public init(
        clientApp: ClientApp,
        configuration: OnboardingConfiguration,
        @ViewBuilder splash: @escaping (@escaping () -> Void) -> Splash,
        @ViewBuilder gate: @escaping (@escaping () -> Void) -> Gate,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.clientApp = clientApp
        self.configuration = configuration
        self.splash = splash
        self.gate = gate
        self.content = content
        self._hasCompletedOnboarding = AppStorage(
            wrappedValue: false,
            "hasCompletedOnboarding_\(clientApp.rawValue)"
        )
    }

    public var body: some View {
        Group {
            switch stage {
            case .splash:
                splash { advanceFromSplash() }
            case .onboarding:
                OnboardingFlowView(configuration: configuration) {
                    hasCompletedOnboarding = true
                    advanceFromOnboarding()
                }
            case .gate:
                gate { stage = .content }
            case .content:
                content()
            }
        }
        .environment(\.clientApp, clientApp)
    }

    private func advanceFromSplash() {
        if hasCompletedOnboarding {
            advanceFromOnboarding()
        } else {
            stage = .onboarding
        }
    }

    private func advanceFromOnboarding() {
        stage = configuration.requiresPersona ? .gate : .content
    }
}

// MARK: - Soft-gate convenience

public extension AppRootScaffold where Gate == EmptyView {
    /// Convenience initializer for soft-gate apps that have no full-screen
    /// persona gate. The persona is enforced later at publish/sign time via
    /// `View.requiresPersona(_:isActive:onSatisfied:createPersona:)`.
    init(
        clientApp: ClientApp,
        configuration: OnboardingConfiguration,
        @ViewBuilder splash: @escaping (@escaping () -> Void) -> Splash,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(
            clientApp: clientApp,
            configuration: configuration,
            splash: splash,
            gate: { _ in EmptyView() },
            content: content
        )
    }
}
