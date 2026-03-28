import Foundation
import SwiftData

@Model
final class LocalMedication {
    @Attribute(.unique) var medicationId: String
    var userId: String
    var name: String
    var dosage: String
    private var selectedWeekdaysData: Data
    private var reminderTimesData: Data
    var updatedAt: Date
    var version: Int
    var isDeleted: Bool

    var selectedWeekdays: [Int] {
        get {
            (try? JSONDecoder().decode([Int].self, from: selectedWeekdaysData)) ?? []
        }
        set {
            selectedWeekdaysData = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }

    var reminderTimes: [String] {
        get {
            (try? JSONDecoder().decode([String].self, from: reminderTimesData)) ?? []
        }
        set {
            reminderTimesData = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }

    init(
        medicationId: String,
        userId: String,
        name: String,
        dosage: String,
        selectedWeekdays: [Int],
        reminderTimes: [String],
        updatedAt: Date = Date(),
        version: Int = 1,
        isDeleted: Bool = false
    ) {
        self.medicationId = medicationId
        self.userId = userId
        self.name = name
        self.dosage = dosage
        self.selectedWeekdaysData = (try? JSONEncoder().encode(selectedWeekdays)) ?? Data()
        self.reminderTimesData = (try? JSONEncoder().encode(reminderTimes)) ?? Data()
        self.updatedAt = updatedAt
        self.version = version
        self.isDeleted = isDeleted
    }
}
