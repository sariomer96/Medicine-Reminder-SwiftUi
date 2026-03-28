//
//  Medicine_ReminderApp.swift
//  Medicine Reminder
//
//  Created by Omer on 25.03.2026.
//

import SwiftUI
import FirebaseCore
import UserNotifications

@main
struct Medicine_ReminderApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    private let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            LoginView()
                .tint(AppTheme.primary)
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    FirebaseApp.configure()
    UNUserNotificationCenter.current().delegate = self

    return true
  }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard let logId = response.notification.request.content.userInfo["logId"] as? String else {
            return
        }

        await MainActor.run {
            NotificationRouteStore.shared.openDoseConfirmation(logId: logId)
        }
    }
}
