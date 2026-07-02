//
//  TestPushNotificationView.swift
//  Signator
//
//  Created by Scott Francis on 4/13/25.
//


import SwiftUI
import UserNotifications

struct TestPushNotificationView: View {
    var body: some View {
        Button("Trigger Test Notification") {
            scheduleTestNotification()
        }
        .onAppear {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                print("Permission granted: \(granted)")
            }
        }
    }

    func scheduleTestNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Signature Requested"
        content.body = "Tap to sign ‘Acceptance of Guardianship of Jerry Aldus Berring’"
        content.sound = .default
        content.categoryIdentifier = "SIGN_DOCUMENT"
        content.userInfo = [
            "documentId": "abc123"
        ]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request)
    }
}
