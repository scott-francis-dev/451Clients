import SwiftUI

/// The onFinished closure is called when the splash animation completes, to allow the parent view to handle transition.
struct IntroView: View {
    @State private var textShown = ""
    @StateObject private var api = BlockchainAPI()
    
    var onFinished: () -> Void = {}
    
    let fullText = "Signator"
    let typingSpeed = 0.2 // seconds per character
    
    var body: some View {
        ZStack {
            // VisionOS-style soft background
            LinearGradient(
                gradient: Gradient(colors: [Color.white.opacity(0.6), Color.blue.opacity(0.2)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            GeometryReader { geometry in
                VStack {
                    Spacer()
                    
                    // Translucent floating pane
                    ZStack {
                        RoundedRectangle(cornerRadius: 32, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .shadow(radius: 20)
                        
                        VStack(spacing: 24) {
                            // Animated script logo
                            Text(textShown)
                                .font(.custom("Snell Roundhand", size: 38))
                                .foregroundColor(.primary)
                                .onAppear(perform: animateText)
                            
                            Divider()
                                .frame(width: 140, height: 2.5)
                                .padding(.vertical, 4)
                            Text("WALLET")
                                .font(.system(.headline, design: .rounded).weight(.heavy))
                                .foregroundColor(.secondary)
                                .kerning(6)
                                .padding(.bottom, 4)
                            
                            // SF Symbol below
                            Image(systemName: availableSymbol("rectangle.and.pencil.and.ellipsis", fallback: "square.and.pencil"))
                                .font(.system(size: 48, weight: .regular))
                                .foregroundColor(.primary)
                        }
                        .padding()
                    }
                    .frame(maxWidth: 600)
                    .frame(height: geometry.size.height * 0.7)
                    
                    Spacer()
                }
                .padding()
            }
        }
    }
    
    private func animateText() {
        textShown = ""
        var charIndex = 0.0
        
        for (i, letter) in fullText.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + charIndex * typingSpeed) {
                self.textShown.append(letter)
                        
                if i == fullText.count - 1 {
                    // Full text typed, now pause briefly for user to feel the effect
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
                        self.onFinished()
                    }
                }
            }
            charIndex += 1
        }
    }
}

private func availableSymbol(_ preferred: String, fallback: String) -> String {
    #if canImport(UIKit)
    return UIImage(systemName: preferred) != nil ? preferred : fallback
    #elseif canImport(AppKit)
    return NSImage(systemSymbolName: preferred, accessibilityDescription: nil) != nil ? preferred : fallback
    #else
    return fallback
    #endif
}
