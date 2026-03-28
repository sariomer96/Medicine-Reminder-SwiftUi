//
//  HomeView.swift
//  Medicine Reminder
//
//  Created by Omer on 25.03.2026.
//

import SwiftUI
import SwiftData
import UserNotifications
import UIKit

struct HomeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var router: AppRouter

    @Query(sort: \LocalMedication.updatedAt, order: .reverse) private var medications: [LocalMedication]
    @Query(sort: \LocalMedicationLog.scheduledTime) private var medicationLogs: [LocalMedicationLog]
    @Query private var users: [LocalUser]

    @StateObject private var viewModel = HomeViewModel()
    @State private var refreshDate = Date()
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var isRequestingNotificationPermission = false
    let sessionDisplayName: String

    private var activeUser: LocalUser? {
        users.first(where: \.isActive)
    }

    private var visibleMedications: [LocalMedication] {
        guard let activeUser else { return [] }

        return medications.filter {
            $0.userId == activeUser.userId && !$0.isDeleted
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
            scheduledTime: firstLog.scheduledTime,
            items: items
        )
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let effectiveDate = max(context.date, refreshDate)
            let currentNextDose = nextDoseInfo(asOf: effectiveDate)

            ZStack {
                AppTheme.appBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack(alignment: .top, spacing: 14) {
                            greetingCard

                            Button {
                                if viewModel.signOut(modelContext: modelContext) {
                                    dismiss()
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
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }

            Task {
                notificationStatus = await NotificationManager.shared.authorizationStatus()
            }
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
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.9))

                    Text(formattedNextDoseTime(nextDoseInfo: nextDoseInfo))
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text(formattedNextDoseDay(nextDoseInfo: nextDoseInfo))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.88))
                }

                Spacer()

                Text("\(nextDoseItems(nextDoseInfo: nextDoseInfo).count) ilac")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.white.opacity(0.18))
                    .clipShape(Capsule())
            }
 

            VStack(alignment: .leading, spacing: 10) {
                ForEach(nextDoseItems(nextDoseInfo: nextDoseInfo), id: \.self) { item in
                    HStack(spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(.white.opacity(0.16))
                                .frame(width: 38, height: 38)

                            Image(systemName: "pills.fill")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                        }

                        Text(item)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(16)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.heroGradient)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .padding(.top, 24)
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
    let scheduledTime: Date
    let items: [String]
}

#Preview {
    HomeView(sessionDisplayName: "Guest")
}
