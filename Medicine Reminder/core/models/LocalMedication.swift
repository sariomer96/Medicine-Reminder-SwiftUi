import Foundation
import CoreData

@objc(LocalMedication)
final class LocalMedication: NSManagedObject {
    @NSManaged var medicationId: String
    @NSManaged var userId: String
    @NSManaged var name: String
    @NSManaged var dosage: String
    @NSManaged private var selectedWeekdaysData: Data
    @NSManaged private var reminderTimesData: Data
    @NSManaged var updatedAt: Date
    @NSManaged var version: Int64
    @NSManaged var deletedFlag: Bool

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

    convenience init(
        context: NSManagedObjectContext,
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
        self.init(entity: Self.entity(), insertInto: context)
        self.medicationId = medicationId
        self.userId = userId
        self.name = name
        self.dosage = dosage
        self.selectedWeekdaysData = (try? JSONEncoder().encode(selectedWeekdays)) ?? Data()
        self.reminderTimesData = (try? JSONEncoder().encode(reminderTimes)) ?? Data()
        self.updatedAt = updatedAt
        self.version = Int64(version)
        self.deletedFlag = isDeleted
    }
}

extension LocalMedication {
    @nonobjc class func fetchRequest() -> NSFetchRequest<LocalMedication> {
        NSFetchRequest<LocalMedication>(entityName: "LocalMedication")
    }
}

extension LocalMedication: Identifiable {}
