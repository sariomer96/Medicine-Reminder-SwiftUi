import Foundation
import SwiftData

@Model
final class LocalUser {
    @Attribute(.unique) var userId: String
    var isGuest: Bool
    var isActive: Bool
    var createdAt: Date

    init(userId: String,
         isGuest: Bool,
         isActive: Bool = false,
         createdAt: Date = Date()) {
        self.userId = userId
        self.isGuest = isGuest
        self.isActive = isActive
        self.createdAt = createdAt
    }
}
