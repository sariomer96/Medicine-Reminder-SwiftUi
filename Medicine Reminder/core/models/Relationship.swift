//
//  Relationship.swift
//  Medicine Reminder
//
//  Created by Codex on 25.03.2026.
//

import Foundation
import FirebaseFirestore

enum RelationshipStatus: String, Codable {
    case pending
    case accepted
    case rejected
}

struct Relationship: Codable, Identifiable {
    @DocumentID var id: String?

    let caregiverId: String
    let patientId: String
    let status: RelationshipStatus
    let createdAt: Date
    let updatedAt: Date
    let version: Int
    let lastActionBy: String

    init(
        id: String? = nil,
        caregiverId: String,
        patientId: String,
        status: RelationshipStatus = .pending,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        version: Int = 1,
        lastActionBy: String
    ) {
        self.id = id
        self.caregiverId = caregiverId
        self.patientId = patientId
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.version = version
        self.lastActionBy = lastActionBy
    }
}
