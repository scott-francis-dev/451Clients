import SwiftUI
import Combine
#if canImport(UIKit)
import UIKit
#endif

final class KeyboardObserver: ObservableObject {
    @Published var isVisible: Bool = false
    #if canImport(UIKit)
    @Published var height: CGFloat = 0
    #endif

    static let shared = KeyboardObserver()

    #if canImport(UIKit)
    private var willChangeFrameObserver: NSObjectProtocol?
    private var willHideObserver: NSObjectProtocol?

    init() {
        willChangeFrameObserver = NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillChangeFrameNotification,
            object: nil,
            queue: nil
        ) { [weak self] notification in
            guard let self = self else { return }
            DispatchQueue.main.async {
                if let userInfo = notification.userInfo,
                   let frameValue = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue {
                    let keyboardFrame = frameValue.cgRectValue
                    #if os(visionOS)
                    let visibleHeight = keyboardFrame.height
                    #else
                    let screenHeight = UIApplication.shared.connectedScenes
                        .compactMap { $0 as? UIWindowScene }
                        .first?.screen.bounds.height ?? 0
                    let visibleHeight = screenHeight - keyboardFrame.origin.y
                    #endif
                    self.isVisible = visibleHeight > 0
                    self.height = visibleHeight > 0 ? visibleHeight : 0
                } else {
                    self.isVisible = false
                    self.height = 0
                }
            }
        }

        willHideObserver = NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.isVisible = false
                self.height = 0
            }
        }
    }

    deinit {
        if let observer = willChangeFrameObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = willHideObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    #else
    init() {}
    #endif
}

