import Foundation
import CoreData

@objc(LocalMedicationLog)
final class LocalMedicationLog: NSManagedObject {
    @NSManaged var logId: String
    @NSManaged var userId: String
    @NSManaged var medicationId: String
    @NSManaged var scheduledTime: Date
    @NSManaged var taken: Bool
    @NSManaged var takenAt: Date?
    @NSManaged var updatedAt: Date
    @NSManaged var syncStatus: String

    convenience init(
        context: NSManagedObjectContext,
        logId: String,
        userId: String,
        medicationId: String,
        scheduledTime: Date,
        taken: Bool = false,
        takenAt: Date? = nil,
        updatedAt: Date = Date(),
        syncStatus: String = "pending"
    ) {
        self.init(entity: Self.entity(), insertInto: context)
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

extension LocalMedicationLog {
    @nonobjc class func fetchRequest() -> NSFetchRequest<LocalMedicationLog> {
        NSFetchRequest<LocalMedicationLog>(entityName: "LocalMedicationLog")
    }
}

extension LocalMedicationLog: Identifiable {}
