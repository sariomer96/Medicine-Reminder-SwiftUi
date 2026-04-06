//
//  UserStore.swift
//  Medicine Reminder
//
//  Created by Codex on 25.03.2026.
//

import Foundation
import FirebaseFirestore


final class UserStore {
    private let db = Firestore.firestore()
    private let collectionName = "users"

    func createUser(userId: String, name: String, email: String) async throws {
        let user = UserProfilePayload(
            name: name,
            email: email
        )

        try db.collection(collectionName)
            .document(userId)
            .setData(from: user)
    }

    func fetchUser(userId: String) async -> UserProfile? {
        do {
            let snapshot = try await db.collection(collectionName)
                .document(userId)
                .getDocument()

            return try snapshot.data(as: UserProfile.self)
        } catch {
            print("UserStore.fetchUser failed for \(userId): \(error.localizedDescription)")
            return nil
        }
    }

    func upsertUser(userId: String, name: String, email: String) async throws -> UserProfile {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let profile = UserProfilePayload(
            name: trimmedName.isEmpty ? inferredDisplayName(from: trimmedEmail) : trimmedName,
            email: trimmedEmail
        )

        try db.collection(collectionName)
            .document(userId)
            .setData(from: profile, merge: true)

        return UserProfile(
            id: userId,
            name: profile.name,
            email: profile.email
        )
    }

    func updateUser(userId: String, name: String, email: String, currentVersion: Int) async throws {
        let now = Date()

        try await db.collection(collectionName)
            .document(userId)
            .updateData([
                "name": name,
                "email": email,
                "updatedAt": Timestamp(date: now),
                "version": currentVersion + 1
            ])
    }

    private func inferredDisplayName(from email: String) -> String {
        let localPart = email.split(separator: "@").first.map(String.init) ?? ""
        let trimmedLocalPart = localPart.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedLocalPart.isEmpty ? L10n.string("common.user") : trimmedLocalPart
    }
}

private struct UserProfilePayload: Encodable {
    let name: String
    let email: String
    let createdAt: Date
    let updatedAt: Date
    let version: Int

    init(
        name: String,
        email: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        version: Int = 1
    ) {
        self.name = name
        self.email = email
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.version = version
    }
}
