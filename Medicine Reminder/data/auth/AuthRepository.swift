//
//  AuthRepository.swift
//  Medicine Reminder
//
//  Created by Codex on 25.03.2026.
//

import Foundation
import FirebaseAuth

enum AuthRepositoryError: LocalizedError {
    case emailPasswordNotEnabled
    case invalidEmail
    case weakPassword
    case emailAlreadyInUse
    case invalidCredentials
    case networkError
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .emailPasswordNotEnabled:
            return L10n.string("auth.error_email_password_not_enabled")
        case .invalidEmail:
            return L10n.string("auth.error_invalid_email")
        case .weakPassword:
            return L10n.string("auth.error_weak_password")
        case .emailAlreadyInUse:
            return L10n.string("auth.error_email_already_in_use")
        case .invalidCredentials:
            return L10n.string("auth.error_invalid_credentials")
        case .networkError:
            return L10n.string("auth.error_network")
        case .unknown(let message):
            return message
        }
    }
}

protocol AuthRepositoryProtocol {
    func login(email: String, password: String) async throws -> User
    func register(name: String, email: String, password: String) async throws -> String
    func fetchUserProfile(userId: String) async -> UserProfile?
    func signOut() throws
}

final class AuthRepository: AuthRepositoryProtocol {
    private let userStore: UserStore

    init(userStore: UserStore = UserStore()) {
        self.userStore = userStore
    }

    func login(email: String, password: String) async throws -> User  {
        do {
            let authResult = try await Auth.auth().signIn(withEmail: email, password: password)
            return authResult.user
        } catch {
            throw mapAuthError(error)
        }
    }

    func register(name: String, email: String, password: String) async throws -> String {
        let authResult: AuthDataResult

        do {
            authResult = try await Auth.auth().createUser(withEmail: email, password: password)
        } catch {
            throw mapAuthError(error)
        }

        do {
            try await userStore.createUser(
                userId: authResult.user.uid,
                name: name,
                email: email
            )
        } catch {
            try? await authResult.user.delete()
            throw error
        }

        return authResult.user.uid
    }

    func fetchUserProfile(userId: String) async -> UserProfile? {
        await userStore.fetchUser(userId: userId)
    }

    func signOut() throws {
        do {
            try Auth.auth().signOut()
        } catch {
            throw AuthRepositoryError.unknown(error.localizedDescription)
        }
    }

    private func mapAuthError(_ error: Error) -> Error {
        let nsError = error as NSError

        guard let authErrorCode = AuthErrorCode(rawValue: nsError.code) else {
            return AuthRepositoryError.unknown(error.localizedDescription)
        }

        switch authErrorCode {
        case .operationNotAllowed:
            return AuthRepositoryError.emailPasswordNotEnabled
        case .invalidEmail:
            return AuthRepositoryError.invalidEmail
        case .weakPassword:
            return AuthRepositoryError.weakPassword
        case .emailAlreadyInUse:
            return AuthRepositoryError.emailAlreadyInUse
        case .wrongPassword, .invalidCredential, .userNotFound:
            return AuthRepositoryError.invalidCredentials
        case .networkError:
            return AuthRepositoryError.networkError
        case .internalError:
            return AuthRepositoryError.unknown(L10n.string("auth.error_internal_firebase"))
        default:
            return AuthRepositoryError.unknown(error.localizedDescription)
        }
    }
}
