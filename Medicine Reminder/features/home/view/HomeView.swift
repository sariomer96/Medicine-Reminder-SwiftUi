//
//  HomeView.swift
//  Medicine Reminder
//
//  Created by Omer on 25.03.2026.
//

import SwiftUI
import CoreData
import UserNotifications
import UIKit

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
    @State private var refreshDate = Date()
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var isRequestingNotificationPermission = false
    let sessionDisplayName: String
    let onSessionEnded: () -> Void

    private var activeUser: LocalUser? {
        users.first(where: \.isActive)
    }

    private var visibleMedications: [LocalMedication] {
        guard let activeUser else { return [] }

        return medications.filter {
            $0.userId == activeUser.userId && !$0.deletedFlag
        }
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
                    VStack(alignment: .leading, spacing: 18) {
                        HStack(alignment: .top, spacing: 14) {
                            greetingCard

                            Button {
                                if viewModel.signOut(modelContext: modelContext) {
                                    onSessionEnded()
                                }
                            } label: {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(AppTheme.primary)
                                    .frame(width: 44, height: 44)
                                    .background(AppTheme.surface)
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .stroke(AppTheme.border, lineWidth: 1)
                                    )
                            }
                        }

                        if let errorMessage = viewModel.errorMessage {
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }

                        notificationStatusCard

                        nextDoseSection(nextDoseInfo: currentNextDose)
                        pendingDosesSection(pendingDoses)

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
                        .padding(.top, 24)

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
                        .padding(.top, 16)
                    }
                    .padding(24)
                }
            }
        }
        .onAppear {
            refreshDate = Date()
            Task {
                notificationStatus = await NotificationManager.shared.authorizationStatus()
            }
        }
        .onChange(of: scenePhase) { newPhase in
            guard newPhase == .active else { return }

            Task {
                notificationStatus = await NotificationManager.shared.authorizationStatus()
            }
        }
        .onChange(of: notificationRouteStore.pendingDoseTarget?.id) { _ in
            refreshDate = Date()
        }
    }

    @ViewBuilder
    private var notificationStatusCard: some View {
        if notificationStatus != .authorized && notificationStatus != .provisional && notificationStatus != .ephemeral {
            VStack(alignment: .leading, spacing: 12) {
                Text("Bildirimler")
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)

                Text(notificationStatus == .denied
                     ? "Bildirim izni kapali. Ilac saatlerinde hatirlatma alabilmek icin Ayarlar'dan bildirimi acman gerekiyor."
                     : "Ilac saatlerinde seni uyarmamiz icin bildirim iznini acabilirsin.")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.textSecondary)

                Button {
                    handleNotificationButtonTap()
                } label: {
                    Text(notificationStatus == .denied ? "Ayarlari ac" : "Bildirimleri ac")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(notificationStatus == .denied ? AppTheme.textPrimary : .white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(notificationStatus == .denied ? AppTheme.surfaceMuted : AppTheme.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(isRequestingNotificationPermission)
                .opacity(isRequestingNotificationPermission ? 0.7 : 1)
            }
            .padding(20)
            .background(AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(AppTheme.border, lineWidth: 1)
            )
        }
    }

    private var greetingCard: some View {
        HStack(spacing: 14) {
          
            VStack(alignment: .leading, spacing: 6) {
                Text("Merhaba")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)

                Text(sessionDisplayName)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)

                Text("Bugunku ilac planin hazir.")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        )
        .shadow(color: AppTheme.primary.opacity(0.08), radius: 14, x: 0, y: 8)
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

            Button {
                router.push(.addMedication)
            } label: {
                Text("Ilac ekle")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(AppTheme.surfaceMuted)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
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

    private func handleNotificationButtonTap() {
        if notificationStatus == .denied {
            guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else {
                return
            }

            UIApplication.shared.open(settingsURL)
            return
        }

        Task {
            isRequestingNotificationPermission = true
            notificationStatus = (try? await NotificationManager.shared.requestAuthorizationIfNeeded()) ?? .denied
            isRequestingNotificationPermission = false
        }
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
