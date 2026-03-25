//
//  MedicationLog.swift
//  Medicine Reminder
//
//  Created by Codex on 25.03.2026.
//

import Foundation
import FirebaseFirestore

struct MedicationLog: Codable, Identifiable {
    @DocumentID var id: String?

    let medicationId: String
    let userId: String
    let scheduledTime: Date
    let taken: Bool
    let takenAt: Date?
    let updatedAt: Date

    init(
        id: String? = nil,
        medicationId: String,
        userId: String,
        scheduledTime: Date,
        taken: Bool = false,
        takenAt: Date? = nil,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.medicationId = medicationId
        self.userId = userId
        self.scheduledTime = scheduledTime
        self.taken = taken
        self.takenAt = takenAt
        self.updatedAt = updatedAt
    }
}
