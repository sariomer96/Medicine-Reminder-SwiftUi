//
//  Medicine_ReminderApp.swift
//  Medicine Reminder
//
//  Created by Omer on 25.03.2026.
//

import SwiftUI
import CoreData
import FirebaseCore
import FirebaseAuth
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
    @Environment(\.managedObjectContext) private var modelContext
    @AppStorage("app.hasSeenOnboarding") private var hasSeenOnboarding = false
    @AppStorage("app.hasRequestedNotificationPermission") private var hasRequestedNotificationPermission = false
    private let reviewPromptCoordinator = ReviewPromptCoordinator.shared
    @State private var isCheckingSession = true
    @State private var hasActiveSession = false
    @State private var sessionDisplayName = ""

    private let authRepository = AuthRepository()

    var body: some View {
        ZStack {
            if hasSeenOnboarding {
                if isCheckingSession {
                    launchLoadingView
                        .transition(.opacity)
                } else if hasActiveSession {
                    AppNavigatorView(
                        sessionDisplayName: sessionDisplayName,
                        onSessionEnded: {
                            hasActiveSession = false
                            sessionDisplayName = ""
                        }
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .opacity
                    ))
                } else {
                    LoginView()
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .opacity
                        ))
                }
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
        .animation(.easeInOut(duration: 0.25), value: isCheckingSession)
        .animation(.easeInOut(duration: 0.25), value: hasActiveSession)
        .task {
            reviewPromptCoordinator.registerInstallIfNeeded()
            guard !hasRequestedNotificationPermission else { return }
            hasRequestedNotificationPermission = true
            _ = try? await NotificationManager.shared.requestAuthorizationIfNeeded()
        }
        .task(id: hasSeenOnboarding) {
            guard hasSeenOnboarding else { return }
            await restoreInitialSession()
        }
    }

    private var launchLoadingView: some View {
        ZStack {
            AppTheme.appBackground
                .ignoresSafeArea()

            ProgressView()
                .progressViewStyle(.circular)
                .tint(AppTheme.primary)
                .scaleEffect(1.2)
        }
    }

    private func restoreInitialSession() async {
        guard isCheckingSession else { return }

        defer {
            isCheckingSession = false
        }

        do {
            let users = try modelContext.fetch(LocalUser.fetchRequest())

            if let firebaseUser = Auth.auth().currentUser {
                let displayName = await fetchSessionDisplayName(
                    userId: firebaseUser.uid,
                    fallbackEmail: firebaseUser.email
                )

                try activateSession(
                    userId: firebaseUser.uid,
                    isGuest: false,
                    displayName: displayName
                )

                await DeviceTokenStore.shared.syncCurrentDeviceTokenIfPossible()
                return
            }

            if let activeGuest = users.first(where: { $0.isGuest && $0.isActive }) {
                hasActiveSession = true
                sessionDisplayName = L10n.string("common.guest")
                return
            }

            let staleUsers = users.filter { !$0.isGuest && $0.isActive }
            if !staleUsers.isEmpty {
                for user in staleUsers {
                    user.isActive = false
                }
                try modelContext.save()
            }
        } catch {
            hasActiveSession = false
            sessionDisplayName = ""
        }
    }

    private func activateSession(
        userId: String,
        isGuest: Bool,
        displayName: String
    ) throws {
        let users = try modelContext.fetch(LocalUser.fetchRequest())

        for user in users {
            user.isActive = false
        }

        if let existingUser = users.first(where: { $0.userId == userId }) {
            existingUser.isGuest = isGuest
            existingUser.isActive = true
        } else {
            _ = LocalUser(context: modelContext, userId: userId, isGuest: isGuest, isActive: true)
        }

        try modelContext.save()
        hasActiveSession = true
        sessionDisplayName = displayName
    }

    private func fetchSessionDisplayName(userId: String, fallbackEmail: String?) async -> String {
        let profile = await authRepository.fetchUserProfile(userId: userId)
        let trimmedName = profile?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if !trimmedName.isEmpty {
            return trimmedName
        }

        if let fallbackEmail, !fallbackEmail.isEmpty {
            return fallbackEmail
        }

        return L10n.string("common.user")
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
