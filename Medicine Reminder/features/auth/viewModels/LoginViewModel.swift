//
//  LoginViewModel.swift
//  Medicine Reminder
//
//  Created by Codex on 25.03.2026.
//

import Foundation

@MainActor
final class LoginViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isLoggedIn = false

    private let authRepository: AuthRepositoryProtocol

    init(authRepository: AuthRepositoryProtocol = AuthRepository()) {
        self.authRepository = authRepository
    }

    func login(email: String, password: String) async {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedEmail.isEmpty, !trimmedPassword.isEmpty else {
            errorMessage = "E-posta ve sifre zorunludur."
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            try await authRepository.login(email: trimmedEmail, password: trimmedPassword)
            isLoggedIn = true
        } catch {
            errorMessage = error.localizedDescription
            isLoggedIn = false
        }

        isLoading = false
    }
}
