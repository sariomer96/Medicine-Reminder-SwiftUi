//
//  HomeViewModel.swift
//  Medicine Reminder
//
//  Created by Codex on 26.03.2026.
//

import Foundation
import CoreData

struct HomeContent {
    let activeUser: LocalUser?
    let shouldShowFamilySection: Bool
    let nextDoseInfo: NextDoseInfo?
    let pendingDoses: [PendingDoseInfo]
    let overdueDoses: [OverdueDosePayload]
}

struct NextDoseInfo {
    let logId: String
    let scheduledTime: Date
    let items: [String]
}

struct PendingDoseInfo: Identifiable {
    let logId: String
    let scheduledTime: Date
    let title: String
    let subtitle: String

    var id: String { logId }
}

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var errorMessage: String?

    private let authRepository: AuthRepositoryProtocol

    init(authRepository: AuthRepositoryProtocol = AuthRepository()) {
        self.authRepository = authRepository
    }

    func makeContent(
        asOf now: Date,
        users: FetchedResults<LocalUser>,
        medications: FetchedResults<LocalMedication>,
        medicationLogs: FetchedResults<LocalMedicationLog>
    ) -> HomeContent {
        let activeUser = activeUser(from: users)
        let visibleMedications = visibleMedications(for: activeUser, medications: medications)

        return HomeContent(
            activeUser: activeUser,
            shouldShowFamilySection: shouldShowFamilySection(for: activeUser),
            nextDoseInfo: nextDoseInfo(
                asOf: now,
                activeUser: activeUser,
                visibleMedications: visibleMedications,
                medicationLogs: medicationLogs
            ),
            pendingDoses: pendingDoseInfos(
                asOf: now,
                activeUser: activeUser,
                visibleMedications: visibleMedications,
                medicationLogs: medicationLogs
            ),
            overdueDoses: overdueDosePayloads(
                asOf: now,
                activeUser: activeUser,
                visibleMedications: visibleMedications,
                medicationLogs: medicationLogs
            )
        )
    }

    func syncFamilyState(for content: HomeContent, familyViewModel: FamilyViewModel) async {
        guard content.shouldShowFamilySection else { return }
        await familyViewModel.load(activeUser: content.activeUser)
    }

    func signOut(modelContext: NSManagedObjectContext) -> Bool {
        do {
            let existingUsers = try modelContext.fetch(LocalUser.fetchRequest())
            let activeUsers = existingUsers.filter(\.isActive)
            let activeGuestSession = activeUsers.contains(where: \.isGuest)
            let signedInUserIds = activeUsers
                .filter { !$0.isGuest }
                .map(\.userId)

            for user in activeUsers {
                user.isActive = false
            }

            try modelContext.save()

            if !activeGuestSession {
                for userId in signedInUserIds {
                    Task {
                        await DeviceTokenStore.shared.removeCurrentDeviceToken(for: userId)
                    }
                }

                try authRepository.signOut()
            }

            errorMessage = nil
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func activeUser(from users: FetchedResults<LocalUser>) -> LocalUser? {
        users.first(where: \.isActive)
    }

    private func visibleMedications(
        for activeUser: LocalUser?,
        medications: FetchedResults<LocalMedication>
    ) -> [LocalMedication] {
        guard let activeUser else { return [] }

        return medications.filter {
            $0.userId == activeUser.userId && !$0.deletedFlag
        }
    }

    private func shouldShowFamilySection(for activeUser: LocalUser?) -> Bool {
        activeUser?.isGuest == false
    }

    private func nextDoseInfo(
        asOf now: Date,
        activeUser: LocalUser?,
        visibleMedications: [LocalMedication],
        medicationLogs: FetchedResults<LocalMedicationLog>
    ) -> NextDoseInfo? {
        guard let activeUser else { return nil }

        let medicationMap = medicationMap(for: visibleMedications)
        let upcomingLogs = medicationLogs
            .filter {
                $0.userId == activeUser.userId
                    && !$0.taken
                    && $0.scheduledTime >= now
                    && medicationMap[$0.medicationId] != nil
            }
            .sorted { $0.scheduledTime < $1.scheduledTime }

        guard let firstLog = upcomingLogs.first else {
            return nil
        }

        let items = upcomingLogs
            .filter { $0.scheduledTime == firstLog.scheduledTime }
            .compactMap { log in
                medicationMap[log.medicationId].map { medication in
                    let trimmedDosage = medication.dosage.trimmingCharacters(in: .whitespacesAndNewlines)
                    return trimmedDosage.isEmpty ? medication.name : "\(medication.name) • \(trimmedDosage)"
                }
            }

        return NextDoseInfo(
            logId: firstLog.logId,
            scheduledTime: firstLog.scheduledTime,
            items: items
        )
    }

    private func pendingDoseInfos(
        asOf now: Date,
        activeUser: LocalUser?,
        visibleMedications: [LocalMedication],
        medicationLogs: FetchedResults<LocalMedicationLog>
    ) -> [PendingDoseInfo] {
        guard let activeUser else { return [] }

        let medicationMap = medicationMap(for: visibleMedications)
        let fifteenMinutesAgo = Calendar.current.date(byAdding: .minute, value: -15, to: now) ?? now

        return medicationLogs
            .filter {
                $0.userId == activeUser.userId
                    && !$0.taken
                    && $0.scheduledTime <= now
                    && $0.scheduledTime >= fifteenMinutesAgo
                    && medicationMap[$0.medicationId] != nil
            }
            .sorted { $0.scheduledTime < $1.scheduledTime }
            .prefix(4)
            .compactMap { log in
                guard let medication = medicationMap[log.medicationId] else {
                    return nil
                }

                let trimmedDosage = medication.dosage.trimmingCharacters(in: .whitespacesAndNewlines)
                let subtitle = trimmedDosage.isEmpty ? medication.name : "\(medication.name) • \(trimmedDosage)"

                return PendingDoseInfo(
                    logId: log.logId,
                    scheduledTime: log.scheduledTime,
                    title: medication.name,
                    subtitle: subtitle
                )
            }
    }

    private func overdueDosePayloads(
        asOf now: Date,
        activeUser: LocalUser?,
        visibleMedications: [LocalMedication],
        medicationLogs: FetchedResults<LocalMedicationLog>
    ) -> [OverdueDosePayload] {
        guard let activeUser else { return [] }

        let medicationMap = medicationMap(for: visibleMedications)
        let familyAlertThreshold = Calendar.current.date(byAdding: .minute, value: -10, to: now) ?? now
        let lookbackDate = Calendar.current.date(byAdding: .hour, value: -24, to: now) ?? now

        return medicationLogs
            .filter {
                $0.userId == activeUser.userId
                    && !$0.taken
                    && $0.scheduledTime <= familyAlertThreshold
                    && $0.scheduledTime >= lookbackDate
                    && medicationMap[$0.medicationId] != nil
            }
            .map { log in
                let medication = medicationMap[log.medicationId]
                return OverdueDosePayload(
                    logId: log.logId,
                    medicationName: medication?.name ?? L10n.string("home.default_medication_name"),
                    dosage: medication?.dosage ?? "",
                    scheduledTime: log.scheduledTime
                )
            }
    }

    private func medicationMap(for visibleMedications: [LocalMedication]) -> [String: LocalMedication] {
        Dictionary(
            uniqueKeysWithValues: visibleMedications.map { ($0.medicationId, $0) }
        )
    }
}
