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
            errorMessage = "Ad soyad, e-posta ve sifre zorunludur."
            return
        }

        guard trimmedPassword == trimmedConfirmPassword else {
            errorMessage = "Sifreler birbiriyle eslesmiyor."
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
