import Foundation
import SwiftData

@Model
final class LocalUser {
    @Attribute(.unique) var userId: String
    var isGuest: Bool
    var createdAt: Date

    init(userId: String,
         isGuest: Bool,
         createdAt: Date = Date()) {
        self.userId = userId
        self.isGuest = isGuest
        self.createdAt = createdAt
    }
}
