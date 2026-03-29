//
//  FamilyInviteCode.swift
//  Medicine Reminder
//
//  Created by Codex on 28.03.2026.
//

import Foundation
import FirebaseFirestore


struct FamilyInviteCode: Codable, Identifiable {
    @DocumentID var id: String?

    let ownerId: String
    let ownerName: String
    let code: String
    let createdAt: Date
    let updatedAt: Date
    let isActive: Bool

    init(
        id: String? = nil,
        ownerId: String,
        ownerName: String,
        code: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isActive: Bool = true
    ) {
        self.id = id
        self.ownerId = ownerId
        self.ownerName = ownerName
        self.code = code
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isActive = isActive
    }
}
