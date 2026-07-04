//
//  OnboardingVideoPlayer.swift
//  Core451
//
//  Cross-platform looping, muted, full-bleed video player used by the shared
//  onboarding walkthrough. Videos ship inside the Core451 resource bundle
//  (`Bundle.module` / Resources/Onboarding), copied from the Signator app.
//

import SwiftUI
import AVKit

/// Plays a bundled onboarding video full-bleed, muted and looping. Shows a
/// black placeholder if the named resource can't be found.
public struct OnboardingVideoPlayer: View {
    private let videoName: String

    @State private var player: AVPlayer?
    @State private var loopObserver: NSObjectProtocol?

    public init(videoName: String) {
        self.videoName = videoName
    }

    public var body: some View {
        Group {
            if let player {
                PlatformVideoView(player: player)
            } else {
                Color.black
            }
        }
        .onAppear { setupPlayer() }
        .onDisappear { teardownPlayer() }
    }

    private func setupPlayer() {
        guard player == nil,
              let url = Bundle.module.url(forResource: videoName, withExtension: "mov", subdirectory: "Onboarding")
                ?? Bundle.module.url(forResource: videoName, withExtension: "mov")
        else { return }

        let newPlayer = AVPlayer(url: url)
        newPlayer.isMuted = true
        newPlayer.volume = 0

        loopObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: newPlayer.currentItem,
            queue: .main
        ) { _ in
            newPlayer.seek(to: .zero)
            newPlayer.play()
        }

        player = newPlayer
        newPlayer.play()
    }

    private func teardownPlayer() {
        player?.pause()
        if let loopObserver {
            NotificationCenter.default.removeObserver(loopObserver)
        }
        loopObserver = nil
        player = nil
    }
}

// MARK: - Platform bridge

#if canImport(UIKit)
private struct PlatformVideoView: UIViewControllerRepresentable {
    let player: AVPlayer

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = false
        controller.videoGravity = .resizeAspectFill
        controller.view.backgroundColor = .black
        return controller
    }

    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {}
}
#elseif canImport(AppKit)
private struct PlatformVideoView: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.player = player
        view.controlsStyle = .none
        view.videoGravity = .resizeAspectFill
        return view
    }

    func updateNSView(_ view: AVPlayerView, context: Context) {}
}
#endif
