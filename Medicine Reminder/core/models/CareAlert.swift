//
//  CareAlert.swift
//  Medicine Reminder
//
//  Created by Codex on 28.03.2026.
//

import Foundation
import FirebaseFirestore


struct CareAlert: Codable, Identifiable {
    @DocumentID var id: String?

    let caregiverId: String
    let patientId: String
    let patientName: String
    let medicationName: String
    let dosage: String
    let logId: String
    let scheduledTime: Date
    let createdAt: Date
    let deliveredAt: Date?
    let resolvedAt: Date?

    init(
        id: String? = nil,
        caregiverId: String,
        patientId: String,
        patientName: String,
        medicationName: String,
        dosage: String,
        logId: String,
        scheduledTime: Date,
        createdAt: Date = Date(),
        deliveredAt: Date? = nil,
        resolvedAt: Date? = nil
    ) {
        self.id = id
        self.caregiverId = caregiverId
        self.patientId = patientId
        self.patientName = patientName
        self.medicationName = medicationName
        self.dosage = dosage
        self.logId = logId
        self.scheduledTime = scheduledTime
        self.createdAt = createdAt
        self.deliveredAt = deliveredAt
        self.resolvedAt = resolvedAt
    }
}
