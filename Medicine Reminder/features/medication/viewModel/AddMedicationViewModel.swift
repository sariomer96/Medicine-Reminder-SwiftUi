//
//  AddMedicationViewModel.swift
//  Medicine Reminder
//
//  Created by Codex on 28.03.2026.
//

import Foundation
import CoreData
import UserNotifications

@MainActor
final class AddMedicationViewModel: ObservableObject {
    @Published var selectedMedicationName = ""
    @Published var medicationSearchText = ""
    @Published private(set) var medicationNames: [String] = []
    @Published private(set) var errorMessage: String?
    @Published private(set) var infoMessage: String?
    @Published private(set) var isLoading = false
    @Published private(set) var isSaving = false
    @Published private(set) var saveSucceeded = false

    private var hasLoadedMedicationNames = false
    private let medicationStore: MedicationStore

    init(medicationStore: MedicationStore = MedicationStore()) {
        self.medicationStore = medicationStore
    }

    var filteredMedications: [String] {
        let trimmedQuery = medicationSearchText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedQuery.isEmpty else {
            return Array(medicationNames.prefix(100))
        }

        return medicationNames.filter {
            $0.localizedCaseInsensitiveContains(trimmedQuery)
        }
    }

    var resolvedCustomMedicationName: String {
        medicationSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func selectMedication(_ medicationName: String) {
        selectedMedicationName = medicationName
    }

    func clearErrorMessage() {
        errorMessage = nil
    }

    func clearInfoMessage() {
        infoMessage = nil
    }

    func saveMedication(
        selectedDays: Set<String>,
        dosageTimes: [Date],
        modelContext: NSManagedObjectContext
    ) async {
        let trimmedMedicationName = selectedMedicationName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedMedicationName.isEmpty else {
            errorMessage = "Lutfen bir ilac sec."
            saveSucceeded = false
            return
        }

        guard !selectedDays.isEmpty else {
            errorMessage = "Lutfen en az bir gun sec."
            saveSucceeded = false
            return
        }

        guard !dosageTimes.isEmpty else {
            errorMessage = "Lutfen en az bir saat ekle."
            saveSucceeded = false
            return
        }

        guard let activeUser = fetchActiveUser(modelContext: modelContext) else {
            saveSucceeded = false
            return
        }

        isSaving = true
        errorMessage = nil
        infoMessage = nil
        saveSucceeded = false

        let medicationId = UUID().uuidString
        let selectedWeekdays = weekdayValues(for: selectedDays).sorted()
        let reminderTimes = buildReminderTimes(from: dosageTimes)
        let localMedication = LocalMedication(
            context: modelContext,
            medicationId: medicationId,
            userId: activeUser.userId,
            name: trimmedMedicationName,
            dosage: "",
            selectedWeekdays: selectedWeekdays,
            reminderTimes: reminderTimes
        )
        var localSaveCompleted = false

        do {
            try modelContext.save()
            localSaveCompleted = true

            try LocalMedicationLogBuilder.ensureUpcomingLogs(
                for: localMedication,
                userId: activeUser.userId,
                syncStatus: activeUser.isGuest ? "local_only" : "pending",
                modelContext: modelContext
            )

            let notificationStatus = try await NotificationManager.shared.requestAuthorizationIfNeeded()
            let upcomingLogs = try fetchMedicationLogs(
                for: localMedication.medicationId,
                modelContext: modelContext
            )
            try await NotificationManager.shared.syncNotifications(
                for: localMedication,
                logs: upcomingLogs
            )

            if notificationStatus == .denied {
                infoMessage = "Ilac kaydedildi, fakat bildirim izni kapali oldugu icin hatirlatma kurulmedi."
            }

            guard !activeUser.isGuest else {
                saveSucceeded = true
                isSaving = false
                return
            }

            try await medicationStore.saveMedication(
                documentId: medicationId,
                userId: activeUser.userId,
                name: trimmedMedicationName,
                dosage: "",
                selectedWeekdays: selectedWeekdays,
                reminderTimes: reminderTimes,
                updatedAt: localMedication.updatedAt,
                version: Int(localMedication.version),
                isDeleted: localMedication.deletedFlag
            )
            saveSucceeded = true
        } catch {
            errorMessage = saveFailureMessage(for: error, localSaveCompleted: localSaveCompleted, isGuest: activeUser.isGuest)
            saveSucceeded = false
        }

        isSaving = false
    }

    func loadMedicationNamesIfNeeded() {
        guard !hasLoadedMedicationNames, !isLoading else { return }

        hasLoadedMedicationNames = true
        isLoading = true
        errorMessage = nil

        Task.detached(priority: .userInitiated) {
            do {
                let names = try await Self.loadMedicationNames()

                await MainActor.run {
                    self.medicationNames = names
                    self.errorMessage = names.isEmpty ? "Ilac listesi bos geldi." : nil
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.medicationNames = []
                    self.selectedMedicationName = ""
                    self.errorMessage = "Ilac listesi yuklenemedi: \(error.localizedDescription)"
                    self.hasLoadedMedicationNames = false
                    self.isLoading = false
                }
            }
        }
    }

    private static func loadMedicationNames() throws -> [String] {
        let records = try loadMedicationRecords()
        return uniqueMedicationNames(from: records)
    }

    private static func loadMedicationRecords() throws -> [MedicationRecord] {
        guard let url = Bundle.main.url(forResource: "medDB", withExtension: "json") else {
            throw AddMedicationDataError.fileNotFound
        }

        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([MedicationRecord].self, from: data)
    }

    private static func uniqueMedicationNames(from records: [MedicationRecord]) -> [String] {
        var seen = Set<String>()

        return records.compactMap { record in
            let normalizedName = record.medicineName
                .replacingOccurrences(of: "\n", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard !normalizedName.isEmpty, seen.insert(normalizedName).inserted else {
                return nil
            }

            return normalizedName
        }
    }

    private func fetchActiveUser(modelContext: NSManagedObjectContext) -> LocalUser? {
        do {
            let users = try modelContext.fetch(LocalUser.fetchRequest())
            guard let activeUser = users.first(where: \.isActive) else {
                errorMessage = "Aktif kullanici bulunamadi."
                return nil
            }

            return activeUser
        } catch {
            errorMessage = "Aktif kullanici okunamadi: \(error.localizedDescription)"
            return nil
        }
    }

    private func weekdayValues(for selectedDays: Set<String>) -> [Int] {
        let weekdayMap = [
            "Paz": 1,
            "Pzt": 2,
            "Sal": 3,
            "Car": 4,
            "Per": 5,
            "Cum": 6,
            "Cmt": 7
        ]

        return selectedDays.compactMap { weekdayMap[$0] }
    }

    private func buildReminderTimes(from dosageTimes: [Date]) -> [String] {
        let calendar = Calendar.current

        return dosageTimes
            .sorted()
            .compactMap { date -> String? in
                let components = calendar.dateComponents([.hour, .minute], from: date)

                guard let hour = components.hour, let minute = components.minute else {
                    return nil
                }

                return String(format: "%02d:%02d", hour, minute)
            }
    }

    private func saveFailureMessage(for error: Error, localSaveCompleted: Bool, isGuest: Bool) -> String {
        if !localSaveCompleted {
            return "Ilac kaydedilemedi: \(error.localizedDescription)"
        }

        if isGuest {
            return "Ilac kaydedilemedi: \(error.localizedDescription)"
        }

        return "Ilac cihaza kaydedildi ama buluta senkronize edilemedi: \(error.localizedDescription)"
    }

    private func fetchMedicationLogs(
        for medicationId: String,
        modelContext: NSManagedObjectContext
    ) throws -> [LocalMedicationLog] {
        let logs = try modelContext.fetch(LocalMedicationLog.fetchRequest())
        return logs.filter { $0.medicationId == medicationId }
    }
}

private struct MedicationRecord: Decodable {
    let medicineName: String
}

private enum AddMedicationDataError: LocalizedError {
    case fileNotFound

    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "medDB.json bulunamadi."
        }
    }
}
