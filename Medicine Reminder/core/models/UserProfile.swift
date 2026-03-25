//
//  UserProfile.swift
//  Medicine Reminder
//
//  Created by Codex on 25.03.2026.
//

import Foundation
import FirebaseFirestore

struct UserProfile: Codable, Identifiable {
    @DocumentID var id: String?

    let name: String
    let email: String
    let createdAt: Date
    let updatedAt: Date
    let version: Int

    init(
        id: String? = nil,
        name: String,
        email: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        version: Int = 1
    ) {
        self.id = id
        self.name = name
        self.email = email
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.version = version
    }
}
