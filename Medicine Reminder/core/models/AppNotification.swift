//
//  AppNotification.swift
//  Medicine Reminder
//
//  Created by Codex on 25.03.2026.
//

import Foundation
import FirebaseFirestore

enum NotificationType: String, Codable {
    case missedMedication = "missed_medication"
}

struct AppNotification: Codable, Identifiable {
    @DocumentID var id: String?

    let toUserId: String
    let fromUserId: String
    let patientId: String
    let medicationLogId: String
    let type: NotificationType
    let message: String
    let createdAt: Date
    let read: Bool

    init(
        id: String? = nil,
        toUserId: String,
        fromUserId: String,
        patientId: String,
        medicationLogId: String,
        type: NotificationType = .missedMedication,
        message: String,
        createdAt: Date = Date(),
        read: Bool = false
    ) {
        self.id = id
        self.toUserId = toUserId
        self.fromUserId = fromUserId
        self.patientId = patientId
        self.medicationLogId = medicationLogId
        self.type = type
        self.message = message
        self.createdAt = createdAt
        self.read = read
    }
}
