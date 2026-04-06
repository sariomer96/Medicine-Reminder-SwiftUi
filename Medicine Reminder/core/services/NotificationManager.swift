//
//  NotificationManager.swift
//  Medicine Reminder
//
//  Created by Codex on 28.03.2026.
//

import Foundation
import UserNotifications

@MainActor
final class NotificationManager {
    static let shared = NotificationManager()

    private let center = UNUserNotificationCenter.current()

    private init() {}

    func authorizationStatus() async -> UNAuthorizationStatus {
        let settings = await center.notificationSettings()
        return settings.authorizationStatus
    }

    func requestAuthorizationIfNeeded() async throws -> UNAuthorizationStatus {
        let currentStatus = await authorizationStatus()

        guard currentStatus == .notDetermined else {
            return currentStatus
        }

        let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
        return granted ? .authorized : .denied
    }

    func syncNotifications(
        for medication: LocalMedication,
        logs: [LocalMedicationLog]
    ) async throws {
        let medicationId = medication.medicationId
        await removeNotifications(for: medicationId)

        let status = await authorizationStatus()
        guard status == .authorized || status == .provisional || status == .ephemeral else {
            return
        }

        let upcomingLogs = logs
            .filter { $0.medicationId == medicationId && !$0.taken && $0.scheduledTime > Date() }
            .sorted { $0.scheduledTime < $1.scheduledTime }

        for log in upcomingLogs {
            let content = UNMutableNotificationContent()
            content.title = L10n.format("notification.medication_title", medication.name)

            let trimmedDosage = medication.dosage.trimmingCharacters(in: .whitespacesAndNewlines)
            content.body = trimmedDosage.isEmpty
                ? L10n.string("notification.medication_body_default")
                : L10n.format("notification.medication_body_dosage", trimmedDosage)
            content.sound = .default
            content.interruptionLevel = .timeSensitive
            content.userInfo = [
                "logId": log.logId,
                "medicationId": medicationId
            ]

            let calendar = Calendar.current
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: log.scheduledTime)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(
                identifier: notificationIdentifier(medicationId: medicationId, logId: log.logId),
                content: content,
                trigger: trigger
            )

            try await center.add(request)
        }
    }

    func scheduleFamilyAlertNotifications(for alerts: [CareAlert]) async throws -> Bool {
        let status = try await requestAuthorizationIfNeeded()
        guard status == .authorized || status == .provisional || status == .ephemeral else {
            return false
        }

        for alert in alerts {
            let identifier = familyAlertNotificationIdentifier(for: alert.id ?? "\(alert.caregiverId)_\(alert.logId)")

            let content = UNMutableNotificationContent()
            content.title = L10n.format("notification.family_alert_title", alert.patientName)

            let trimmedDosage = alert.dosage.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedDosage.isEmpty {
                content.body = L10n.format("notification.family_alert_body_default", alert.medicationName)
            } else {
                content.body = L10n.format("notification.family_alert_body_dosage", alert.medicationName, trimmedDosage)
            }

            content.sound = .default
            content.interruptionLevel = .timeSensitive
            content.userInfo = [
                "careAlertId": alert.id ?? "",
                "patientId": alert.patientId,
                "logId": alert.logId
            ]

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            try await center.add(request)
        }

        return true
    }

    func removeNotifications(for medicationId: String) async {
        let identifiers = await pendingNotificationIdentifiers(for: medicationId)
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    private func pendingNotificationIdentifiers(for medicationId: String) async -> [String] {
        let requests = await center.pendingNotificationRequests()
        let prefix = notificationPrefix(for: medicationId)

        return requests
            .map(\.identifier)
            .filter { $0.hasPrefix(prefix) }
    }

    private func notificationPrefix(for medicationId: String) -> String {
        "medication.\(medicationId)."
    }

    private func notificationIdentifier(medicationId: String, logId: String) -> String {
        "\(notificationPrefix(for: medicationId))\(logId)"
    }

    private func familyAlertNotificationIdentifier(for alertId: String) -> String {
        "family.alert.\(alertId)"
    }
}
