import SwiftUI

#if canImport(UIKit)
import UIKit

final class KeyboardObserver: ObservableObject {
    @Published var keyboardHeight: CGFloat = 0
    @Published var isVisible: Bool = false

    private var animationDuration: TimeInterval = 0.25
    private var animationCurve: UIView.AnimationCurve = .easeInOut

    private var observers: [NSObjectProtocol] = []

    init() {
        let center = NotificationCenter.default

        observers.append(center.addObserver(forName: UIResponder.keyboardWillChangeFrameNotification,
                                            object: nil,
                                            queue: .main) { [weak self] notification in
            self?.keyboardWillChange(notification: notification)
        })

        observers.append(center.addObserver(forName: UIResponder.keyboardWillHideNotification,
                                            object: nil,
                                            queue: .main) { [weak self] notification in
            self?.keyboardWillHide(notification: notification)
        })
    }

    deinit {
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    private func keyboardWillChange(notification: Notification) {
        guard
            let userInfo = notification.userInfo,
            let screenFrameEnd = (userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue,
            let screenFrameBegin = (userInfo[UIResponder.keyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue,
            let duration = (userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue,
            let curveRaw = (userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? NSNumber)?.intValue,
            let window = UIApplication.shared.windows.first(where: { $0.isKeyWindow })
        else {
            return
        }

        animationDuration = duration
        animationCurve = UIView.AnimationCurve(rawValue: curveRaw) ?? .easeInOut

        let screenHeight = window.bounds.height

        let keyboardFrameInScreen = screenFrameEnd
        let keyboardHeight = max(0, screenHeight - keyboardFrameInScreen.minY)

        withAnimation(Animation.timingCurve(0.25, 0.1, 0.25, 1.0, duration: animationDuration)) {
            self.keyboardHeight = keyboardHeight
            self.isVisible = keyboardHeight > 0
        }
    }

    private func keyboardWillHide(notification: Notification) {
        guard
            let userInfo = notification.userInfo,
            let duration = (userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue
        else {
            return
        }
        animationDuration = duration

        withAnimation(Animation.timingCurve(0.25, 0.1, 0.25, 1.0, duration: animationDuration)) {
            self.keyboardHeight = 0
            self.isVisible = false
        }
    }
}
#endif

struct FloatingToolbarModifier<Toolbar: View>: ViewModifier {
    @ViewBuilder let toolbar: () -> Toolbar
    var background: AnyView
    @State private var safeAreaBottom: CGFloat = 0

    #if canImport(UIKit)
    @StateObject private var keyboard = KeyboardObserver()
    #else
    private let keyboardHeight: CGFloat = 0
    private let isVisible: Bool = false
    #endif

    init(background: AnyView = AnyView(.ultraThinMaterial), @ViewBuilder toolbar: @escaping () -> Toolbar) {
        self.toolbar = toolbar
        self.background = background
    }

    func body(content: Content) -> some View {
        #if canImport(UIKit)
        content
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .preference(key: SafeAreaBottomKey.self,
                                    value: proxy.safeAreaInsets.bottom)
                }
            )
            .onPreferenceChange(SafeAreaBottomKey.self) { value in
                safeAreaBottom = value
            }
            .safeAreaInset(edge: .bottom) {
                if keyboard.isVisible {
                    toolbar()
                        .padding(.bottom, max(0, keyboard.keyboardHeight - safeAreaBottom))
                        .background(background)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .animation(.easeInOut(duration: 0.25), value: keyboard.keyboardHeight)
                }
            }
        #else
        VStack(spacing: 0) {
            content
            toolbar()
                .background(background)
        }
        #endif
    }
}

private struct SafeAreaBottomKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

public extension View {
    func floatingToolbar<Toolbar: View>(alignment: VerticalAlignment = .bottom,
                                        background: AnyView = AnyView(.ultraThinMaterial),
                                        @ViewBuilder toolbar: @escaping () -> Toolbar) -> some View
    {
        modifier(FloatingToolbarModifier(background: background, toolbar: toolbar))
    }
}
