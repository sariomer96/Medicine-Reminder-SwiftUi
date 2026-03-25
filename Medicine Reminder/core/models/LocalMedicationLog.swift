import Foundation
import SwiftData

@Model
final class LocalMedicationLog {
    @Attribute(.unique) var logId: String
    var userId: String
    var medicationId: String
    var scheduledTime: Date
    var taken: Bool
    var takenAt: Date?
    var updatedAt: Date
    var syncStatus: String

    init(
        logId: String,
        userId: String,
        medicationId: String,
        scheduledTime: Date,
        taken: Bool = false,
        takenAt: Date? = nil,
        updatedAt: Date = Date(),
        syncStatus: String = "pending"
    ) {
        self.logId = logId
        self.userId = userId
        self.medicationId = medicationId
        self.scheduledTime = scheduledTime
        self.taken = taken
        self.takenAt = takenAt
        self.updatedAt = updatedAt
        self.syncStatus = syncStatus
    }
}
