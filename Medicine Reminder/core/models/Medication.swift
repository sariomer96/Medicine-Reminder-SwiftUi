//
//  Medication.swift
//  Medicine Reminder
//
//  Created by Codex on 25.03.2026.
//

import Foundation
import FirebaseFirestore

struct Medication: Codable, Identifiable {
    @DocumentID var id: String?

    let userId: String
    let name: String
    let dosage: String
    let selectedWeekdays: [Int]
    let reminderTimes: [String]
    let updatedAt: Date
    let version: Int
    let isDeleted: Bool

    init(
        id: String? = nil,
        userId: String,
        name: String,
        dosage: String,
        selectedWeekdays: [Int],
        reminderTimes: [String],
        updatedAt: Date = Date(),
        version: Int = 1,
        isDeleted: Bool = false
    ) {
        self.id = id
        self.userId = userId
        self.name = name
        self.dosage = dosage
        self.selectedWeekdays = selectedWeekdays
        self.reminderTimes = reminderTimes
        self.updatedAt = updatedAt
        self.version = version
        self.isDeleted = isDeleted
    }
}
