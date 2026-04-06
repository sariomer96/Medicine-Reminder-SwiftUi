//
//  HomeView.swift
//  Medicine Reminder
//
//  Created by Omer on 25.03.2026.
//

import SwiftUI
import CoreData
import Combine

struct HomeView: View {
    @Environment(\.managedObjectContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var notificationRouteStore: NotificationRouteStore

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \LocalMedication.updatedAt, ascending: false)])
    private var medications: FetchedResults<LocalMedication>
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \LocalMedicationLog.scheduledTime, ascending: true)])
    private var medicationLogs: FetchedResults<LocalMedicationLog>
    @FetchRequest(sortDescriptors: [])
    private var users: FetchedResults<LocalUser>

    @StateObject private var viewModel = HomeViewModel()
    @StateObject private var familyViewModel = FamilyViewModel()
    @State private var refreshDate = Date()
    let sessionDisplayName: String
    let onSessionEnded: () -> Void
    private let familySyncTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    private var activeUser: LocalUser? {
        users.first(where: \.isActive)
    }

    private var visibleMedications: [LocalMedication] {
        guard let activeUser else { return [] }

        return medications.filter {
            $0.userId == activeUser.userId && !$0.deletedFlag
        }
    }

    private var shouldShowFamilySection: Bool {
        activeUser?.isGuest == false
    }

    private func nextDoseInfo(asOf now: Date) -> NextDoseInfo? {
        guard let activeUser else { return nil }

        let medicationMap = Dictionary(
            uniqueKeysWithValues: visibleMedications.map { ($0.medicationId, $0) }
        )

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

        let groupedLogs = upcomingLogs.filter {
            $0.scheduledTime == firstLog.scheduledTime
        }

        let items = groupedLogs.compactMap { log in
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

    private func pendingDoseInfos(asOf now: Date) -> [PendingDoseInfo] {
        guard let activeUser else { return [] }

        let medicationMap = Dictionary(
            uniqueKeysWithValues: visibleMedications.map { ($0.medicationId, $0) }
        )
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

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let effectiveDate = max(context.date, refreshDate)
            let currentNextDose = nextDoseInfo(asOf: effectiveDate)
            let pendingDoses = pendingDoseInfos(asOf: effectiveDate)

            ZStack {
                AppTheme.appBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        greetingCard

                        if let errorMessage = viewModel.errorMessage {
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }

                        nextDoseSection(nextDoseInfo: currentNextDose)
                        pendingDosesSection(pendingDoses)
                        if shouldShowFamilySection {
                            familySection
                        }

                        Button {
                            router.push(.allMedications)
                        } label: {
                            Text("Tum Ilaclarim")
                                .font(.headline)
                                .foregroundStyle(AppTheme.primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(AppTheme.surface)
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .stroke(AppTheme.border, lineWidth: 1)
                                )
                        }
                        .padding(.top, 8)

                        Button {
                            router.push(.addMedication)
                        } label: {
                            Text("Yeni ilac ekle")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(AppTheme.primary)
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                        .padding(.top, 8)
                    }
                    .padding(16)
                }
            }
        }
        .onAppear {
            refreshDate = Date()
            Task {
                await syncFamilyState()
            }
        }
        .onChange(of: scenePhase) { newPhase in
            guard newPhase == .active else { return }

            Task {
                await syncFamilyState()
            }
        }
        .onChange(of: notificationRouteStore.pendingDoseTarget?.id) { _ in
            refreshDate = Date()
        }
        .onReceive(familySyncTimer) { _ in
            Task {
                await syncFamilyState()
            }
        }
    }

    @ViewBuilder
    private var familySection: some View {
        let summary = familyViewModel.summary

        Button {
            router.push(.familyHub)
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Aile Takibi")
                            .font(.headline)
                            .foregroundStyle(AppTheme.textPrimary)

                        Text(summary.isGuestSession ? "Hesapla aktif edilir" : "Kodla baglan ve gecikmeleri paylas")
                            .font(.footnote)
                            .foregroundStyle(AppTheme.textSecondary)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(AppTheme.textSecondary)
                }

                if summary.isGuestSession {
                    Text("Misafir oturumunda aile eslesmesi kapali. Giris yaptiginda takip kodu uretebilirsin.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(AppTheme.surfaceMuted)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                } else {
                    HStack(spacing: 10) {
                        summaryChip(title: "Takipciler", value: "\(summary.followerCount)")
                        summaryChip(title: "Takip ettiklerin", value: "\(summary.followingCount)")
                        summaryChip(title: "Aktif uyari", value: "\(summary.overdueAlertCount)")
                    }

                    Text(summary.shareCode.map { "Paylasilabilir kod: \($0)" } ?? "Takip kodun henuz hazir degil.")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(summary.shareCode == nil ? AppTheme.textSecondary : AppTheme.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(AppTheme.surfaceMuted)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }
            .padding(20)
            .background(AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(AppTheme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func summaryChip(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.textSecondary)

            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(AppTheme.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(AppTheme.surfaceMuted)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func overdueDosePayloads(asOf now: Date) -> [OverdueDosePayload] {
        guard let activeUser else { return [] }

        let medicationMap = Dictionary(
            uniqueKeysWithValues: visibleMedications.map { ($0.medicationId, $0) }
        )
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
                    medicationName: medication?.name ?? "Ilac",
                    dosage: medication?.dosage ?? "",
                    scheduledTime: log.scheduledTime
                )
            }
    }

    private func syncFamilyState() async {
        guard shouldShowFamilySection else { return }

        await familyViewModel.load(activeUser: activeUser)
    }

    private var greetingCard: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(AppTheme.heroGradient)
                    .frame(width: 56, height: 56)

                Image(systemName: "person.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Merhaba")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .textCase(.uppercase)
                    .foregroundStyle(AppTheme.textSecondary)

                Text(sessionDisplayName)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }

            Spacer(minLength: 0)

            Button {
                if viewModel.signOut(modelContext: modelContext) {
                    onSessionEnded()
                }
            } label: {
                VStack(spacing: 6) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(AppTheme.primary)

                   
                }
                .frame(width: 54, height: 54)
                .background(AppTheme.surfaceMuted)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        )
        .shadow(color: AppTheme.primary.opacity(0.10), radius: 18, x: 0, y: 10)
    }

    private func nextDoseSection(nextDoseInfo: NextDoseInfo?) -> some View {
        Group {
            if nextDoseInfo == nil {
                emptyMedicationCard
            } else {
                nextDoseCard(nextDoseInfo: nextDoseInfo)
            }
        }
    }

    private var emptyMedicationCard: some View {
        Button {
            router.push(.addMedication)
        } label: {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(AppTheme.surfaceMuted)
                            .frame(width: 52, height: 52)

                        Image(systemName: "pills.circle")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(AppTheme.primary)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Baslamak icin ilac ekle")
                            .font(.headline)
                            .foregroundStyle(AppTheme.textPrimary)

                        Text("Ilac eklediginde siradaki doz ve bildirim bilgilerini burada goreceksin.")
                            .font(.footnote)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }

                Text("Ilac ekle")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(AppTheme.border, lineWidth: 1)
            )
            .padding(.top, 24)
        }
        .buttonStyle(.plain)
    }

    private func nextDoseCard(nextDoseInfo: NextDoseInfo?) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Siradaki doz")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.9))

                    Text(formattedNextDoseTime(nextDoseInfo: nextDoseInfo))
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text(formattedNextDoseDay(nextDoseInfo: nextDoseInfo))
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.88))
                }

                Spacer()

                Text("\(nextDoseItems(nextDoseInfo: nextDoseInfo).count) ilac")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 7)
                    .background(.white.opacity(0.18))
                    .clipShape(Capsule())
            }
 

            VStack(alignment: .leading, spacing: 8) {
                ForEach(nextDoseItems(nextDoseInfo: nextDoseInfo), id: \.self) { item in
                    HStack(spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(.white.opacity(0.16))
                                .frame(width: 34, height: 34)

                            Image(systemName: "pills.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                        }

                        Text(item)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(14)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.heroGradient)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding(.top, 18)
        .onTapGesture {
            if let logId = nextDoseInfo?.logId {
                notificationRouteStore.openDoseConfirmation(logId: logId)
            }
        }
    }

    @ViewBuilder
    private func pendingDosesSection(_ doses: [PendingDoseInfo]) -> some View {
        if !doses.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Bekleyen dozlar")
                        .font(.headline)
                        .foregroundStyle(AppTheme.textPrimary)

                    Spacer()

                    Text("\(doses.count)")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AppTheme.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(AppTheme.surfaceMuted)
                        .clipShape(Capsule())
                }

                VStack(spacing: 10) {
                    ForEach(doses) { dose in
                        Button {
                            notificationRouteStore.openDoseConfirmation(logId: dose.logId)
                        } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(AppTheme.surfaceMuted)
                                        .frame(width: 42, height: 42)

                                    Image(systemName: "bell.badge.fill")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(AppTheme.primary)
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(dose.title)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(AppTheme.textPrimary)
                                        .lineLimit(1)

                                    Text(formattedPendingDoseTime(dose.scheduledTime))
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.textSecondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                            .padding(14)
                            .background(AppTheme.surfaceMuted)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(18)
            .background(AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(AppTheme.border, lineWidth: 1)
            )
        }
    }

    private func nextDoseItems(nextDoseInfo: NextDoseInfo?) -> [String] {
        nextDoseInfo?.items ?? []
    }

    private func formattedNextDoseTime(nextDoseInfo: NextDoseInfo?) -> String {
        guard let scheduledTime = nextDoseInfo?.scheduledTime else {
            return "--:--"
        }

        return scheduledTime.formatted(
            Date.FormatStyle()
                .hour(.twoDigits(amPM: .omitted))
                .minute(.twoDigits)
        )
    }

    private func formattedNextDoseDay(nextDoseInfo: NextDoseInfo?) -> String {
        guard let scheduledTime = nextDoseInfo?.scheduledTime else {
            return ""
        }

        let weekday = Calendar.current.component(.weekday, from: scheduledTime)
        let turkishWeekdays = [
            1: "Pazar",
            2: "Pazartesi",
            3: "Sali",
            4: "Carsamba",
            5: "Persembe",
            6: "Cuma",
            7: "Cumartesi"
        ]

        return turkishWeekdays[weekday] ?? ""
    }

    private func formattedPendingDoseTime(_ date: Date) -> String {
        date.formatted(
            Date.FormatStyle()
                .weekday(.abbreviated)
                .hour(.twoDigits(amPM: .omitted))
                .minute(.twoDigits)
        )
    }

}

private struct NextDoseInfo {
    let logId: String
    let scheduledTime: Date
    let items: [String]
}

private struct PendingDoseInfo: Identifiable {
    let logId: String
    let scheduledTime: Date
    let title: String
    let subtitle: String

    var id: String { logId }
}

#Preview {
    HomeView(sessionDisplayName: "Guest", onSessionEnded: {})
}
