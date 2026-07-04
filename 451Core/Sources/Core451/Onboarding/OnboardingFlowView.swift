//
//  OnboardingFlowView.swift
//  Core451
//
//  Generalized paged first-run walkthrough with full-bleed looping video
//  backgrounds and a readable text overlay. Paged swiping is applied on
//  iOS-family platforms; macOS uses chevron button navigation.
//

import SwiftUI

public struct OnboardingFlowView: View {
    private let configuration: OnboardingConfiguration
    private let onComplete: () -> Void

    @State private var index = 0

    public init(configuration: OnboardingConfiguration, onComplete: @escaping () -> Void) {
        self.configuration = configuration
        self.onComplete = onComplete
    }

    private var pages: [OnboardingPage] { configuration.pages }
    private var isLastPage: Bool { index >= pages.count - 1 }

    public var body: some View {
        Group {
            if pages.isEmpty {
                Color.clear.onAppear(perform: onComplete)
            } else {
                content
            }
        }
        .ignoresSafeArea()
    }

    private var content: some View {
        ZStack {
            #if os(iOS) || os(visionOS) || os(tvOS)
            TabView(selection: $index) {
                ForEach(Array(pages.enumerated()), id: \.offset) { i, page in
                    OnboardingPageView(page: page).tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            .ignoresSafeArea()
            #else
            OnboardingPageView(page: pages[min(index, pages.count - 1)])
                .id(index)
                .transition(.opacity)
            #endif

            controlsOverlay
        }
    }

    @ViewBuilder
    private var controlsOverlay: some View {
        VStack {
            // Skip (top trailing) until the last page.
            HStack {
                Spacer()
                if !isLastPage {
                    Button("Skip") { onComplete() }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding()
                }
            }

            Spacer()

            // Advance / finish (bottom trailing).
            HStack {
                #if os(macOS)
                Button {
                    withAnimation { index = max(0, index - 1) }
                } label: {
                    Label("Back", systemImage: "chevron.left")
                }
                .disabled(index == 0)
                #endif

                Spacer()

                if isLastPage {
                    Button("Get Started") { onComplete() }
                        .font(.headline)
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction)
                } else {
                    Button {
                        withAnimation { index += 1 }
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.rightArrow, modifiers: [])
                }
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 50)
        }
    }
}

/// A single onboarding page: full-bleed looping video with a text overlay.
private struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        ZStack {
            OnboardingVideoPlayer(videoName: page.videoName)
                .ignoresSafeArea()

            VStack(spacing: 30) {
                Spacer()

                VStack(spacing: 20) {
                    Text(page.title)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.5), radius: 10, x: 0, y: 2)
                        .padding(.horizontal, 40)

                    Text(page.description)
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .lineSpacing(4)
                }
                .padding(.vertical, 40)
                .padding(.horizontal, 20)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)
                        .opacity(0.8)
                )
                .padding(.horizontal, 20)

                Spacer().frame(height: 150)
            }
        }
    }
}
