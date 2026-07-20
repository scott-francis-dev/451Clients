//
//  OnboardingModels.swift
//  Core451
//
//  Describes the first-run video walkthrough for a 451 client app. Each app
//  supplies its own pages and declares whether a persona is required up front
//  (hard gate) or only later at publish/sign time (soft gate).
//
//  The pages and copy below are the real Signator onboarding content, now
//  shared. Videos ship in the Core451 resource bundle (Resources/Onboarding).
//

import Foundation

/// A single page in the first-run onboarding walkthrough.
public struct OnboardingPage: Identifiable, Sendable {
    public let id = UUID()
    /// Bundled video resource name (without extension), e.g. "onboarding1".
    public let videoName: String
    public let title: String
    public let description: String

    public init(videoName: String, title: String, description: String) {
        self.videoName = videoName
        self.title = title
        self.description = description
    }
}

/// Configuration for a client app's first-run experience.
public struct OnboardingConfiguration: Sendable {
    public let pages: [OnboardingPage]
    /// When `true` the app presents a full-screen persona gate before content
    /// (hard gate). When `false` the persona is only required later, at the
    /// point of publishing/signing (soft gate).
    public let requiresPersona: Bool

    public init(pages: [OnboardingPage], requiresPersona: Bool) {
        self.pages = pages
        self.requiresPersona = requiresPersona
    }

    /// The standard onboarding configuration for a given client app.
    public static func standard(for app: ClientApp) -> OnboardingConfiguration {
        switch app {
        case .signator:
            return OnboardingConfiguration(pages: signatorPages, requiresPersona: true)
        case .thesis:
            // thesis is a soft-gate client; it reuses the shared 451 walkthrough
            // videos (persona is required later, at publish time) but with its
            // own copy so the branding matches the running app.
            return OnboardingConfiguration(pages: thesisPages, requiresPersona: false)
        }
    }

    /// The thesis onboarding walkthrough. Shares the Core451 walkthrough videos
    /// but with thesis-branded copy (persona is a soft gate here).
    private static let thesisPages: [OnboardingPage] = [
        OnboardingPage(
            videoName: "onboarding1",
            title: "Welcome to thesis",
            description: "Your space for serious writing, powered by the 451 Protocol."
        ),
        OnboardingPage(
            videoName: "onboarding2",
            title: "Create Your Persona",
            description: "Build your decentralized identity with cryptographic security backed by your device's Secure Enclave."
        ),
        OnboardingPage(
            videoName: "onboarding3",
            title: "Publish with Confidence",
            description: "Sign and verify your work with cryptographic signatures that prove authorship and integrity."
        ),
        OnboardingPage(
            videoName: "onboarding7",
            title: "thesis is Built for Documenting Trust",
            description: "Whether you are writing, publishing, verifying facts or providing witness, thesis is built to help you document trust."
        ),
    ]

    /// The real 451 onboarding walkthrough (originally Signator's).
    private static let signatorPages: [OnboardingPage] = [
        OnboardingPage(
            videoName: "onboarding1",
            title: "Welcome to Signator",
            description: "Your secure digital identity and document signing solution powered by the 451 Protocol."
        ),
        OnboardingPage(
            videoName: "onboarding2",
            title: "Create Your Persona",
            description: "Build your decentralized identity with cryptographic security backed by your device's Secure Enclave."
        ),
        OnboardingPage(
            videoName: "onboarding3",
            title: "Sign Documents Securely",
            description: "Sign and verify documents with cryptographic signatures that prove authenticity and integrity."
        ),
        OnboardingPage(
            videoName: "onboarding4",
            title: "Timestamped Witness Data",
            description: "Capture and archive sensitive events with timestamps and verifying info."
        ),
        OnboardingPage(
            videoName: "onboarding5",
            title: "Transfer of Medical Records",
            description: "Provide approval for the secure transfer of medical records from provider to provider."
        ),
        OnboardingPage(
            videoName: "onboarding6",
            title: "Consent for activities & sports",
            description: "Remove messy paper consent forms and let Signator handle all the legalese."
        ),
        OnboardingPage(
            videoName: "onboarding7",
            title: "Signator is Built for Documenting Trust",
            description: "Whether you are signing documents, verifying facts, providing witness, offering consent or more, Signator is built to help you document trust."
        ),
    ]
}
