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
            return "Firebase Authentication icinde Email/Password giris yontemi aktif degil."
        case .invalidEmail:
            return "Gecersiz bir e-posta adresi girdiniz."
        case .weakPassword:
            return "Sifre en az 6 karakter olmali."
        case .emailAlreadyInUse:
            return "Bu e-posta adresi zaten kullanimda."
        case .invalidCredentials:
            return "E-posta veya sifre hatali."
        case .networkError:
            return "Ag baglantisinda bir sorun olustu. Internet baglantinizi kontrol edin."
        case .unknown(let message):
            return message
        }
    }
}

protocol AuthRepositoryProtocol {
    func login(email: String, password: String) async throws
    func register(name: String, email: String, password: String) async throws
    func signOut() throws
}

final class AuthRepository: AuthRepositoryProtocol {
    private let userStore: UserStore

    init(userStore: UserStore = UserStore()) {
        self.userStore = userStore
    }

    func login(email: String, password: String) async throws {
        do {
            try await Auth.auth().signIn(withEmail: email, password: password)
        } catch {
            throw mapAuthError(error)
        }
    }

    func register(name: String, email: String, password: String) async throws {
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
            return AuthRepositoryError.unknown(
                "Firebase icinde dahili bir hata olustu. Email/Password giris yonteminin aktif oldugunu kontrol edin."
            )
        default:
            return AuthRepositoryError.unknown(error.localizedDescription)
        }
    }
}
