//
//  OnboardingView.swift
//  Signator
//
//  Created on 1/27/26.
//
//  First-run onboarding experience with video walkthrough screens
//

import SwiftUI
import AVKit

/// Individual onboarding page with video and text content
struct OnboardingPage: Identifiable {
    let id: Int
    let videoName: String
    let title: String
    let description: String
}

/// Main onboarding view with swipeable pages
struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var currentPage = 0
    @Environment(\.dismiss) private var dismiss
    
    // Haptic feedback generator
    private let impactFeedback = UIImpactFeedbackGenerator(style: .light)
    private let notificationFeedback = UINotificationFeedbackGenerator()
    
    // Onboarding content - customize these based on your videos and messaging
    private let pages: [OnboardingPage] = [
        OnboardingPage(
            id: 0,
            videoName: "onboarding1", // Just the filename without extension
            title: "Welcome to Signator",
            description: "Your secure digital identity and document signing solution powered by the 451 Protocol."
        ),
        OnboardingPage(
            id: 1,
            videoName: "onboarding2",
            title: "Create Your Persona",
            description: "Build your decentralized identity with cryptographic security backed by your device's Secure Enclave."
        ),
        OnboardingPage(
            id: 2,
            videoName: "onboarding3",
            title: "Sign Documents Securely",
            description: "Sign and verify documents with cryptographic signatures that prove authenticity and integrity."
        ),
        OnboardingPage(
            id: 3,
            videoName: "onboarding4",
            title: "Timestamped Witness Data",
            description: "Capture and archive sensitive events with timestamps and verifying info."
        ),
        OnboardingPage(
            id: 4,
            videoName: "onboarding5",
            title: "Transfer of Medical Records",
            description: "Provide approval for the secure transfer of medical records from provider to provider."
        ),
        OnboardingPage(
            id: 5,
            videoName: "onboarding6",
            title: "Consent for activities & sports",
            description: "Remove messy paper consent forms and let Signator handle all the legalese."
        ),
        OnboardingPage(
            id: 6,
            videoName: "onboarding7",
            title: "Signator is Built for Documenting Trust",
            description: "Whether you are signing documents, verifying facts, providing witness, offering consent or more, Signator is built to help you document trust."
        )
    ]
    
    var body: some View {
        ZStack {
            // Paged content with swipe gesture (full screen)
            TabView(selection: $currentPage) {
                ForEach(pages) { page in
                    OnboardingPageView(page: page)
                        .tag(page.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            .onChange(of: currentPage) { oldValue, newValue in
                // Provide haptic feedback when swiping between pages
                impactFeedback.impactOccurred()
            }
            .ignoresSafeArea()
            
            // Skip button (top right)
            VStack {
                HStack {
                    Spacer()
                    if currentPage < pages.count - 1 {
                        Button("Skip") {
                            withAnimation(.easeInOut) {
                                completeOnboarding()
                            }
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial)
                        .cornerRadius(20)
                        .padding()
                        .transition(.opacity)
                    }
                }
                Spacer()
            }
            .zIndex(10)
            
            // Swipe arrow indicator (lower right) or Get Started button on last page
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    
                    if currentPage < pages.count - 1 {
                        // Swipe arrow
                        Image(systemName: "chevron.right")
                            .font(.system(size: 40, weight: .semibold))
                            .foregroundColor(.white.opacity(0.5))
                            .padding(.trailing, 30)
                            .padding(.bottom, 50)
                    } else {
                        // Get Started button on last page
                        Button(action: {
                            notificationFeedback.notificationOccurred(.success)
                            completeOnboarding()
                        }) {
                            Text("Get Started")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 40)
                                .padding(.vertical, 16)
                                .background(Color.green)
                                .cornerRadius(12)
                        }
                        .padding(.trailing, 30)
                        .padding(.bottom, 50)
                    }
                }
            }
            .zIndex(10)
        }
    }
    
    private func completeOnboarding() {
        hasCompletedOnboarding = true
        // Note: RootView will handle navigation to PersonaCreationView
    }
}

/// Individual page view with video player and text
struct OnboardingPageView: View {
    let page: OnboardingPage
    @State private var player: AVPlayer?
    @State private var observer: NSObjectProtocol?
    
    var body: some View {
        ZStack {
            // Full screen video background
            Group {
                if let videoURL = Bundle.main.url(forResource: page.videoName, withExtension: "mov") {
                    if let player = player {
                        FullScreenVideoPlayer(player: player)
                            .ignoresSafeArea()
                            .onAppear {
                                // Ensure video plays when view appears
                                player.play()
                            }
                    } else {
                        // Loading placeholder
                        Color.black
                            .ignoresSafeArea()
                            .overlay(
                                ProgressView()
                                    .tint(.white)
                            )
                            .onAppear {
                                setupPlayer(url: videoURL)
                            }
                    }
                } else {
                    // Fallback if video not found
                    Color.black
                        .ignoresSafeArea()
                        .overlay(
                            VStack {
                                Image(systemName: "video.slash")
                                    .font(.system(size: 60))
                                    .foregroundColor(.gray)
                                Text("Video not found: \(page.videoName).mov")
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .padding(.top, 8)
                            }
                        )
                }
            }
            .onDisappear {
                cleanupPlayer()
            }
            
            // Text overlay on top of video
            VStack(spacing: 30) {
                Spacer()
                
                VStack(spacing: 20) {
                    // Title with background for readability
                    Text(page.title)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.5), radius: 10, x: 0, y: 2)
                        .padding(.horizontal, 40)
                    
                    // Description with background for readability
                    Text(page.description)
                        .font(.body)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .lineSpacing(4)
                }
                .padding(.vertical, 40)
                .padding(.horizontal, 20)
                .background(
                    // Semi-transparent backdrop for text readability
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)
                        .opacity(0.8)
                )
                .padding(.horizontal, 20)
                
                Spacer()
                    .frame(height: 150) // Space for bottom arrow/button
            }
        }
    }
    
    private func setupPlayer(url: URL) {
        let newPlayer = AVPlayer(url: url)
        
        // Mute the audio
        newPlayer.volume = 0.0
        newPlayer.isMuted = true
        
        player = newPlayer
        
        // Loop the video
        observer = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: newPlayer.currentItem,
            queue: .main
        ) { _ in
            newPlayer.seek(to: .zero)
            newPlayer.play()
        }
        
        // Start playing
        newPlayer.play()
    }
    
    private func cleanupPlayer() {
        player?.pause()
        if let observer = observer {
            NotificationCenter.default.removeObserver(observer)
        }
        observer = nil
        player = nil
    }
}

// MARK: - Full Screen Video Player

/// Custom video player view that fills the entire screen
struct FullScreenVideoPlayer: UIViewControllerRepresentable {
    let player: AVPlayer
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = false
        controller.videoGravity = .resizeAspectFill
        controller.view.backgroundColor = .black
        return controller
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        // No updates needed
    }
}

// MARK: - Instructions View (Reusable for viewing later)

/// Instruction screens that can be shown from the info button
/// This is similar to OnboardingView but doesn't set completion flags
struct InstructionsView: View {
    @State private var currentPage = 0
    @Environment(\.dismiss) private var dismiss
    
    // Haptic feedback generator
    private let impactFeedback = UIImpactFeedbackGenerator(style: .light)
    
    // Same content as onboarding
    private let pages: [OnboardingPage] = [
        OnboardingPage(
            id: 0,
            videoName: "onboarding1",
            title: "Welcome to Signator",
            description: "Your secure digital identity and document signing solution powered by the 451 Protocol."
        ),
        OnboardingPage(
            id: 1,
            videoName: "onboarding2",
            title: "Create Your Persona",
            description: "Build your decentralized identity with cryptographic security backed by your device's Secure Enclave."
        ),
        OnboardingPage(
            id: 2,
            videoName: "onboarding3",
            title: "Sign Documents Securely",
            description: "Sign and verify documents with cryptographic signatures that prove authenticity and integrity."
        ),
        OnboardingPage(
            id: 3,
            videoName: "onboarding4",
            title: "Timestamped Witness Data",
            description: "Capture and archive sensitive events with timestamps and verifying info."
        ),
        OnboardingPage(
            id: 4,
            videoName: "onboarding5",
            title: "Transfer of Medical Records",
            description: "Provide approval for the secure transfer of medical records from provider to provider."
        ),
        OnboardingPage(
            id: 5,
            videoName: "onboarding6",
            title: "Consent for activities & sports",
            description: "Remove messy paper consent forms and let Signator handle all the legalese."
        ),
        OnboardingPage(
            id: 6,
            videoName: "onboarding7",
            title: "Signator is Built for Documenting Trust",
            description: "Whether you are signing documents, verifying facts, providing witness, offering consent or more, Signator is built to help you document trust."
        )
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Paged content with swipe gesture
            TabView(selection: $currentPage) {
                ForEach(pages) { page in
                    OnboardingPageView(page: page)
                        .tag(page.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            .onChange(of: currentPage) { oldValue, newValue in
                // Provide haptic feedback when swiping between pages
                impactFeedback.impactOccurred()
            }
            
            // Bottom action area
            VStack(spacing: 20) {
                // Page indicator
                Text("\(currentPage + 1) of \(pages.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .animation(.easeInOut, value: currentPage)
                
                // Next button
                if currentPage < pages.count - 1 {
                    Button(action: {
                        impactFeedback.impactOccurred()
                        withAnimation(.easeInOut) {
                            currentPage += 1
                        }
                    }) {
                        Text("Next")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 30)
                }
            }
        }
        .navigationTitle("How Signator Works")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Preview

#Preview {
    OnboardingView()
}
