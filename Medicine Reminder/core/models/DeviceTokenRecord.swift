//
//  DeviceTokenRecord.swift
//  Medicine Reminder
//
//  Created by Codex on 29.03.2026.
//

import Foundation
import FirebaseFirestore


struct DeviceTokenRecord: Codable, Identifiable {
    @DocumentID var id: String?

    let userId: String
    let deviceId: String
    let fcmToken: String
    let platform: String
    let updatedAt: Date

    init(
        id: String? = nil,
        userId: String,
        deviceId: String,
        fcmToken: String,
        platform: String = "ios",
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.deviceId = deviceId
        self.fcmToken = fcmToken
        self.platform = platform
        self.updatedAt = updatedAt
    }
}
