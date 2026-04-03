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
            AppRootView()
            .tint(AppTheme.primary)
            .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}

private struct AppRootView: View {
    @AppStorage("app.hasSeenOnboarding") private var hasSeenOnboarding = false
    @AppStorage("app.hasRequestedNotificationPermission") private var hasRequestedNotificationPermission = false

    var body: some View {
        ZStack {
            if hasSeenOnboarding {
                LoginView()
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .opacity
                    ))
            } else {
                OnboardingView {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        hasSeenOnboarding = true
                    }
                }
                .transition(.asymmetric(
                    insertion: .opacity,
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
            }
        }
        .animation(.easeInOut(duration: 0.4), value: hasSeenOnboarding)
        .task {
            guard !hasRequestedNotificationPermission else { return }
            hasRequestedNotificationPermission = true
            _ = try? await NotificationManager.shared.requestAuthorizationIfNeeded()
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
