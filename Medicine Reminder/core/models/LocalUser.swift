import Foundation
import CoreData

@objc(LocalUser)
final class LocalUser: NSManagedObject {
    @NSManaged var userId: String
    @NSManaged var isGuest: Bool
    @NSManaged var isActive: Bool
    @NSManaged var createdAt: Date

    convenience init(
        context: NSManagedObjectContext,
        userId: String,
        isGuest: Bool,
        isActive: Bool = false,
        createdAt: Date = Date()
    ) {
        self.init(entity: Self.entity(), insertInto: context)
        self.userId = userId
        self.isGuest = isGuest
        self.isActive = isActive
        self.createdAt = createdAt
    }
}

extension LocalUser {
    @nonobjc class func fetchRequest() -> NSFetchRequest<LocalUser> {
        NSFetchRequest<LocalUser>(entityName: "LocalUser")
    }
}

extension LocalUser: Identifiable {}
