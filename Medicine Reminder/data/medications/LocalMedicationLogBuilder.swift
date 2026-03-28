//
//  LocalMedicationLogBuilder.swift
//  Medicine Reminder
//
//  Created by Codex on 28.03.2026.
//

import Foundation
import SwiftData

@MainActor
enum LocalMedicationLogBuilder {
    static func ensureUpcomingLogs(
        for medication: LocalMedication,
        userId: String,
        syncStatus: String,
        modelContext: ModelContext,
        daysAhead: Int = 30
    ) throws {
        let calendar = Calendar.current
        let startDate = calendar.startOfDay(for: Date())
        guard let endDate = calendar.date(byAdding: .day, value: daysAhead, to: startDate) else {
            return
        }

        let existingLogs = try modelContext.fetch(FetchDescriptor<LocalMedicationLog>())
        let existingLogIds = Set(
            existingLogs
                .filter { $0.medicationId == medication.medicationId }
                .map(\.logId)
        )

        let occurrences = buildOccurrences(
            selectedWeekdays: medication.selectedWeekdays,
            reminderTimes: medication.reminderTimes,
            from: startDate,
            through: endDate
        )

        for scheduledTime in occurrences {
            let logId = makeLogId(medicationId: medication.medicationId, scheduledTime: scheduledTime)

            guard !existingLogIds.contains(logId) else {
                continue
            }

            modelContext.insert(
                LocalMedicationLog(
                    logId: logId,
                    userId: userId,
                    medicationId: medication.medicationId,
                    scheduledTime: scheduledTime,
                    syncStatus: syncStatus
                )
            )
        }

        try modelContext.save()
    }

    static func makeLogId(medicationId: String, scheduledTime: Date) -> String {
        "\(medicationId)_\(iso8601String(from: scheduledTime))"
    }

    static func replaceUpcomingLogs(
        for medication: LocalMedication,
        userId: String,
        syncStatus: String,
        modelContext: ModelContext,
        daysAhead: Int = 30
    ) throws {
        try removeUpcomingLogs(for: medication.medicationId, modelContext: modelContext)
        try ensureUpcomingLogs(
            for: medication,
            userId: userId,
            syncStatus: syncStatus,
            modelContext: modelContext,
            daysAhead: daysAhead
        )
    }

    static func removeUpcomingLogs(for medicationId: String, modelContext: ModelContext) throws {
        let now = Date()
        let existingLogs = try modelContext.fetch(FetchDescriptor<LocalMedicationLog>())

        for log in existingLogs where log.medicationId == medicationId && log.scheduledTime >= now {
            modelContext.delete(log)
        }

        try modelContext.save()
    }

    private static func buildOccurrences(
        selectedWeekdays: [Int],
        reminderTimes: [String],
        from startDate: Date,
        through endDate: Date
    ) -> [Date] {
        let calendar = Calendar.current
        let weekdaySet = Set(selectedWeekdays)
        let normalizedTimes = reminderTimes.compactMap(parseTime).sorted { lhs, rhs in
            if lhs.hour == rhs.hour {
                return lhs.minute < rhs.minute
            }

            return lhs.hour < rhs.hour
        }

        guard !weekdaySet.isEmpty, !normalizedTimes.isEmpty else {
            return []
        }

        var occurrences: [Date] = []
        var currentDate = startDate

        while currentDate <= endDate {
            let weekday = calendar.component(.weekday, from: currentDate)

            if weekdaySet.contains(weekday) {
                for time in normalizedTimes {
                    if let scheduledTime = calendar.date(
                        bySettingHour: time.hour,
                        minute: time.minute,
                        second: 0,
                        of: currentDate
                    ) {
                        occurrences.append(scheduledTime)
                    }
                }
            }

            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else {
                break
            }

            currentDate = nextDate
        }

        return occurrences
    }

    private static func parseTime(_ value: String) -> (hour: Int, minute: Int)? {
        let components = value.split(separator: ":")

        guard components.count == 2,
              let hour = Int(components[0]),
              let minute = Int(components[1]),
              (0...23).contains(hour),
              (0...59).contains(minute) else {
            return nil
        }

        return (hour, minute)
    }

    private static func iso8601String(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}
