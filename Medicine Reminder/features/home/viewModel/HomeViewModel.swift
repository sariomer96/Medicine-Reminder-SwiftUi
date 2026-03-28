//
//  HomeViewModel.swift
//  Medicine Reminder
//
//  Created by Codex on 26.03.2026.
//

import Foundation
import CoreData

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var errorMessage: String?

    private let authRepository: AuthRepositoryProtocol

    init(authRepository: AuthRepositoryProtocol = AuthRepository()) {
        self.authRepository = authRepository
    }

    func signOut(modelContext: NSManagedObjectContext) -> Bool {
        do {
            let existingUsers = try modelContext.fetch(LocalUser.fetchRequest())
            let activeUsers = existingUsers.filter(\.isActive)
            let activeGuestSession = activeUsers.contains(where: \.isGuest)

            for user in activeUsers {
                user.isActive = false
            }

            try modelContext.save()

            if !activeGuestSession {
                try authRepository.signOut()
            }

            errorMessage = nil
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
