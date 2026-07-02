//
//  IntroView.swift
//  thesis
//
//  Created for thesis app startup experience
//

import SwiftUI
import Core451

/// Typewriter-themed splash screen for the thesis app.
/// The onFinished closure is called when the animation completes.
struct IntroView: View {
    @State private var textShown = ""
    @State private var showTagline = false
    
    var onFinished: () -> Void = {}
    
    let fullText = "thesis"
    let typingSpeed = 0.25 // seconds per character for typewriter effect
    
    var body: some View {
        ZStack {
            // Paper-like background
            Color.white
                .ignoresSafeArea()
            
            VStack(spacing: 32) {
                Spacer()
                
                // Main "thesis" text with typewriter effect
                Text(textShown)
                    .font(.custom("Courier New", size: 72))
                    .fontWeight(.bold)
                    .tracking(36) // Double spacing between letters
                    .foregroundColor(.black)
                    .textCase(.lowercase)
                
                // "words matter" tagline
                if showTagline {
                    Text("words matter")
                        .font(.custom("Courier New", size: 24))
                        .tracking(12)
                        .foregroundColor(.black.opacity(0.7))
                        .textCase(.lowercase)
                        .transition(.opacity.combined(with: .scale(0.95)))
                }
                
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear(perform: animateText)
    }
    
    private func animateText() {
        textShown = ""
        var charIndex = 0.0
        
        for (i, letter) in fullText.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + charIndex * typingSpeed) {
                self.textShown.append(letter)
                
                // Optional: Add typewriter sound effect here
                #if canImport(UIKit) && !os(visionOS)
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred()
                #endif
                
                if i == fullText.count - 1 {
                    // Last character typed, show tagline
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        withAnimation(.easeInOut(duration: 0.6)) {
                            self.showTagline = true
                        }
                        
                        // Wait longer before dismissing - total animation now ~4.5 seconds
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.3) {
                            self.onFinished()
                        }
                    }
                }
            }
            charIndex += 1
        }
    }
}

#Preview {
    IntroView()
}
