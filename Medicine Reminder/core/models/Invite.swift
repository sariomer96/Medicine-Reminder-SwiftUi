//
//  Invite.swift
//  Medicine Reminder
//
//  Created by Codex on 25.03.2026.
//

import Foundation
import FirebaseFirestore

enum InviteStatus: String, Codable {
    case pending
    case accepted
    case expired
}

struct Invite: Codable, Identifiable {
    @DocumentID var id: String?

    let fromUserId: String
    let toEmail: String
    let token: String
    let status: InviteStatus
    let createdAt: Date
    let expiresAt: Date
    let consumedBy: String?

    init(
        id: String? = nil,
        fromUserId: String,
        toEmail: String,
        token: String,
        status: InviteStatus = .pending,
        createdAt: Date = Date(),
        expiresAt: Date,
        consumedBy: String? = nil
    ) {
        self.id = id
        self.fromUserId = fromUserId
        self.toEmail = toEmail
        self.token = token
        self.status = status
        self.createdAt = createdAt
        self.expiresAt = expiresAt
        self.consumedBy = consumedBy
    }
}
