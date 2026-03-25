import Foundation
import SwiftData

@Model
final class LocalMedication {
    @Attribute(.unique) var medicationId: String
    var userId: String
    var name: String
    var dosage: String
    var schedule: [Date]
    var updatedAt: Date
    var version: Int
    var isDeleted: Bool

    init(
        medicationId: String,
        userId: String,
        name: String,
        dosage: String,
        schedule: [Date],
        updatedAt: Date = Date(),
        version: Int = 1,
        isDeleted: Bool = false
    ) {
        self.medicationId = medicationId
        self.userId = userId
        self.name = name
        self.dosage = dosage
        self.schedule = schedule
        self.updatedAt = updatedAt
        self.version = version
        self.isDeleted = isDeleted
    }
}
