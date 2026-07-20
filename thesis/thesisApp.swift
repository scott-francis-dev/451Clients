//
//  wordsmatterApp.swift
//  wordsmatter
//
//  Created by User451 on 9/8/25.
//

import SwiftUI
import RichTextKit

#if os(macOS)
/// This command customizes the app's About panel.
struct AboutCommand: Commands {
    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("About thesis") {
                NSApplication.shared
                    .orderFrontStandardAboutPanel(
                        options: .thesis
                    )
            }
        }
    }
}

extension Dictionary where Key == NSApplication.AboutPanelOptionKey, Value == Any {
    static var thesis: [NSApplication.AboutPanelOptionKey: Any] {
        [
            .applicationName: "thesis",
            .credits: NSAttributedString(
                string: "thesis - A powerful text editing and publishing platform.",
                attributes: [
                    .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
                    .paragraphStyle: {
                        let style = NSMutableParagraphStyle()
                        style.lineSpacing = 8
                        return style
                    }()
                ]
            )
        ]
    }
}
#endif

@main
struct MyApp: App {
    @StateObject private var personaManager = PersonaManager()

    var body: some Scene {
        WindowGroup {
            // Shared 451 app-root flow: typewriter splash -> first-run video
            // onboarding -> main app. thesis is a soft-gate client, so no
            // full-screen persona gate here (persona is required at publish time).
            AppRootScaffold(
                clientApp: .thesis,
                configuration: .standard(for: .thesis)
            ) { onFinished in
                IntroView(onFinished: onFinished)
            } content: {
                MainAppView()
            }
            .environmentObject(personaManager)
            .onAppear {
                // If you want the splash every launch instead of once, comment out the @AppStorage
                // and replace with a simple @State var that defaults to true on each run.
                    // Existing comment…
                    #if os(macOS)
                    print("DEBUG: Running native macOS target")
                    #elseif targetEnvironment(macCatalyst)
                    print("DEBUG: Running Mac Catalyst build")
                    #else
                    print("DEBUG: Running iOS/iPadOS/visionOS")
                    #endif
                
            }
        }
        #if os(macOS)
        .defaultSize(width: 1280, height: 860)
        #endif
        .commands {
            SidebarCommands()
#if os(macOS)
            AboutCommand()
#endif
            RichTextCommand.FormatMenu()
        }
    }
}

struct MainAppView: View {
    @EnvironmentObject private var personaManager: PersonaManager

    var body: some View {
        TabView {
            // Discover and Create supply their own NavigationStack, so they are
            // not wrapped again here (the other tabs rely on the stacks below).
            DiscoveryView()
            .tabItem {
                SwiftUI.Label {
                    Text("Discover")
                } icon: {
                    Image(systemName: "house.fill")
                }
            }

            EnhancedCreateView()
            .tabItem {
                SwiftUI.Label {
                    Text("Create")
                } icon: {
                    Image(systemName: "doc.text.fill")
                }
            }

            NavigationStack {
                ValidateRequestFlowView(personaManager: personaManager)
            }
            .tabItem {
                SwiftUI.Label {
                    Text("Publish/Validate")
                } icon: {
                    Image(systemName: "checkmark.seal.fill")
                }
            }

            NavigationStack {
                ActionsTabView()
            }
            .tabItem {
                SwiftUI.Label {
                    Text("Actions")
                } icon: {
                    Image(systemName: "bolt.fill")
                }
            }

            NavigationStack {
                PersonaManagerView()
            }
            .tabItem {
                SwiftUI.Label {
                    Text("Personas")
                } icon: {
                    Image(systemName: "person.2.fill")
                }
            }
        }
    }
}

// MARK: Date Formatter
private let dateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateStyle = .short
    f.timeStyle = .short
    return f
}()
