//
//  MedicationLogStore.swift
//  Medicine Reminder
//
//  Created by Codex on 30.03.2026.
//

import Foundation
import FirebaseFirestore


final class MedicationLogStore {
    private let db = Firestore.firestore()
    private let collectionName = "medicationLogs"

    func syncUpcomingLogs(
        medication: LocalMedication,
        logs: [LocalMedicationLog]
    ) async throws {
        let remoteSnapshot = try await db.collection(collectionName)
            .whereField("userId", isEqualTo: medication.userId)
            .whereField("medicationId", isEqualTo: medication.medicationId)
            .getDocuments()

        let remoteDocuments = remoteSnapshot.documents
        let desiredLogs = logs.sorted { $0.scheduledTime < $1.scheduledTime }
        let desiredLogIds = Set(desiredLogs.map(\.logId))
        let now = Date()
        let batch = db.batch()

        for log in desiredLogs {
            let reference = db.collection(collectionName).document(log.logId)
            let payload = MedicationLogPayload(
                medicationId: medication.medicationId,
                userId: medication.userId,
                medicationName: medication.name,
                dosage: medication.dosage,
                scheduledTime: log.scheduledTime,
                taken: log.taken,
                takenAt: log.takenAt,
                updatedAt: log.updatedAt,
                alertStatus: log.taken ? "resolved" : "pending"
            )

            try batch.setData(from: payload, forDocument: reference, merge: true)
        }

        for document in remoteDocuments {
            guard !desiredLogIds.contains(document.documentID) else {
                continue
            }

            let scheduledTime = (document.data()["scheduledTime"] as? Timestamp)?.dateValue()
            if let scheduledTime, scheduledTime >= now {
                batch.deleteDocument(document.reference)
            }
        }

        try await batch.commit()
    }

    func markLogTaken(log: LocalMedicationLog) async throws {
        let payload = MedicationLogTakenPayload(
            taken: true,
            takenAt: log.takenAt ?? Date(),
            updatedAt: log.updatedAt,
            alertStatus: "resolved"
        )

        try db.collection(collectionName)
            .document(log.logId)
            .setData(from: payload, merge: true)
    }

    func markMedicationDeleted(medicationId: String, userId: String) async throws {
        let snapshot = try await db.collection(collectionName)
            .whereField("userId", isEqualTo: userId)
            .whereField("medicationId", isEqualTo: medicationId)
            .getDocuments()

        guard !snapshot.documents.isEmpty else { return }

        let batch = db.batch()

        for document in snapshot.documents {
            batch.deleteDocument(document.reference)
        }

        try await batch.commit()
    }
}

private struct MedicationLogPayload: Encodable {
    let medicationId: String
    let userId: String
    let medicationName: String
    let dosage: String
    let scheduledTime: Date
    let taken: Bool
    let takenAt: Date?
    let updatedAt: Date
    let alertStatus: String
}

private struct MedicationLogTakenPayload: Encodable {
    let taken: Bool
    let takenAt: Date
    let updatedAt: Date
    let alertStatus: String
}
