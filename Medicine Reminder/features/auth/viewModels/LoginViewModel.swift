//
//  LoginViewModel.swift
//  Medicine Reminder
//
//  Created by Codex on 25.03.2026.
//

import Foundation
import CoreData
import FirebaseAuth

@MainActor
final class LoginViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isLoggedIn = false
    @Published var authenticatedUserId: String?
    @Published var sessionDisplayName = ""

    private let authRepository: AuthRepositoryProtocol

    init(authRepository: AuthRepositoryProtocol = AuthRepository()) {
        self.authRepository = authRepository
    }

    func login(email: String, password: String, modelContext: NSManagedObjectContext) async {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedEmail.isEmpty, !trimmedPassword.isEmpty else {
            errorMessage = "E-posta ve sifre zorunludur."
            return
        }

        isLoading = true
        errorMessage = nil
        authenticatedUserId = nil
        sessionDisplayName = ""

        do {
            let user = try await authRepository.login(email: trimmedEmail, password: trimmedPassword)
            let sessionName = await fetchSessionDisplayName(
                userId: user.uid,
                fallbackEmail: user.email
            )

            activateSession(
                userId: user.uid,
                isGuest: false,
                displayName: sessionName,
                modelContext: modelContext
            )
        } catch {
            errorMessage = error.localizedDescription
            isLoggedIn = false
        }

        isLoading = false
    }

    func loginAsGuest(modelContext: NSManagedObjectContext) {
        errorMessage = nil
        activateSession(userId: "guest", isGuest: true, displayName: "Guest", modelContext: modelContext)
    }

    func restoreSessionIfNeeded(hasRestoredSession: inout Bool, modelContext: NSManagedObjectContext) {
        guard !hasRestoredSession else { return }
        hasRestoredSession = true

        Task {
            do {
                let users = try modelContext.fetch(LocalUser.fetchRequest())
                let firebaseUser = Auth.auth().currentUser

                if let firebaseUser {
                    let sessionName = await fetchSessionDisplayName(
                        userId: firebaseUser.uid,
                        fallbackEmail: firebaseUser.email
                    )

                    activateSession(
                        userId: firebaseUser.uid,
                        isGuest: false,
                        displayName: sessionName,
                        modelContext: modelContext
                    )
                    return
                }

                if let activeGuest = users.first(where: { $0.isGuest && $0.isActive }) {
                    activateSession(
                        userId: activeGuest.userId,
                        isGuest: true,
                        displayName: "Guest",
                        modelContext: modelContext
                    )
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
                errorMessage = "Oturum geri yuklenemedi: \(error.localizedDescription)"
            }
        }
    }

    private func activateSession(
        userId: String,
        isGuest: Bool,
        displayName: String,
        modelContext: NSManagedObjectContext
    ) {
        do {
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
            isLoggedIn = true
            authenticatedUserId = userId
            sessionDisplayName = displayName
            errorMessage = nil
        } catch {
            errorMessage = "Oturum acilamadi: \(error.localizedDescription)"
            isLoggedIn = false
        }
    }

    private func resolvedSessionDisplayName(userName: String?, fallbackEmail: String?) -> String {
        let trimmedName = userName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if !trimmedName.isEmpty {
            return trimmedName
        }

        if let fallbackEmail, !fallbackEmail.isEmpty {
            return fallbackEmail
        }

        return "Kullanici"
    }

    private func fetchSessionDisplayName(userId: String, fallbackEmail: String?) async -> String {
        let profile = await authRepository.fetchUserProfile(userId: userId)
        return resolvedSessionDisplayName(
            userName: profile?.name,
            fallbackEmail: fallbackEmail
        )
    }
}
