//
//  RegisterViewModel.swift
//  Medicine Reminder
//
//  Created by Codex on 25.03.2026.
//

import Foundation

@MainActor
final class RegisterViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isRegistered = false

    private let authRepository: AuthRepositoryProtocol

    init(authRepository: AuthRepositoryProtocol = AuthRepository()) {
        self.authRepository = authRepository
    }

    func register(
        fullName: String,
        email: String,
        password: String,
        confirmPassword: String
    ) async {
        let trimmedFullName = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedConfirmPassword = confirmPassword.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedFullName.isEmpty, !trimmedEmail.isEmpty, !trimmedPassword.isEmpty else {
            errorMessage = L10n.string("auth.error_required_full_name_email_password")
            return
        }

        guard trimmedPassword == trimmedConfirmPassword else {
            errorMessage = L10n.string("auth.error_passwords_do_not_match")
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            try await authRepository.register(
                name: trimmedFullName,
                email: trimmedEmail,
                password: trimmedPassword
            )
            isRegistered = true
        } catch {
            errorMessage = error.localizedDescription
            isRegistered = false
        }

        isLoading = false
    }
}
