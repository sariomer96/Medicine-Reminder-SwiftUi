//
//  MedicationStore.swift
//  Medicine Reminder
//
//  Created by Codex on 28.03.2026.
//

import Foundation
import FirebaseFirestore

final class MedicationStore {
    private let db = Firestore.firestore()
    private let collectionName = "medications"

    func saveMedication(
        documentId: String,
        userId: String,
        name: String,
        dosage: String,
        selectedWeekdays: [Int],
        reminderTimes: [String],
        updatedAt: Date,
        version: Int,
        isDeleted: Bool
    ) async throws {
        let payload = MedicationPayload(
            userId: userId,
            name: name,
            dosage: dosage,
            selectedWeekdays: selectedWeekdays,
            reminderTimes: reminderTimes,
            updatedAt: updatedAt,
            version: version,
            isDeleted: isDeleted
        )

        try db.collection(collectionName)
            .document(documentId)
            .setData(from: payload)
    }

    func deleteMedication(
        documentId: String,
        userId: String,
        updatedAt: Date,
        version: Int
    ) async throws {
        let payload = MedicationDeletePayload(
            userId: userId,
            isDeleted: true,
            updatedAt: updatedAt,
            version: version
        )

        try db.collection(collectionName)
            .document(documentId)
            .setData(from: payload, merge: true)
    }
}

private struct MedicationPayload: Encodable {
    let userId: String
    let name: String
    let dosage: String
    let selectedWeekdays: [Int]
    let reminderTimes: [String]
    let updatedAt: Date
    let version: Int
    let isDeleted: Bool
}

private struct MedicationDeletePayload: Encodable {
    let userId: String
    let isDeleted: Bool
    let updatedAt: Date
    let version: Int
}
