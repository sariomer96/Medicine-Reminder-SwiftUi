//
//  NotificationRouteStore.swift
//  Medicine Reminder
//
//  Created by Codex on 28.03.2026.
//

import Foundation

struct PendingDoseTarget: Identifiable, Equatable {
    let logId: String

    var id: String { logId }
}

@MainActor
final class NotificationRouteStore: ObservableObject {
    static let shared = NotificationRouteStore()

    @Published var pendingDoseTarget: PendingDoseTarget?

    private init() {}

    func openDoseConfirmation(logId: String) {
        pendingDoseTarget = PendingDoseTarget(logId: logId)
    }

    func clear() {
        pendingDoseTarget = nil
    }
}
