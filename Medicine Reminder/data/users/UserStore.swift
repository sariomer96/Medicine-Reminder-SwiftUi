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
        let user = UserProfile(
            id: userId,
            name: name,
            email: email,
            
        )

        try db.collection(collectionName)
            .document(userId)
            .setData(from: user)
    }

    func fetchUser(userId: String) async throws -> UserProfile? {
        let snapshot = try await db.collection(collectionName)
            .document(userId)
            .getDocument()

        return try snapshot.data(as: UserProfile.self)
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
}
