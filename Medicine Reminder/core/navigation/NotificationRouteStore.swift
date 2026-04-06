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
    @Published var pendingAppRoute: AppRoute?

    private init() {}

    func openDoseConfirmation(logId: String) {
        pendingDoseTarget = PendingDoseTarget(logId: logId)
    }

    func openFamilyHub() {
        pendingAppRoute = .familyHub
    }

    func consumePendingAppRoute() -> AppRoute? {
        defer { pendingAppRoute = nil }
        return pendingAppRoute
    }

    func clear() {
        pendingDoseTarget = nil
        pendingAppRoute = nil
    }
}
