//
//  AllMedicationsView.swift
//  Medicine Reminder
//
//  Created by Codex on 27.03.2026.
//

import SwiftUI
import CoreData

struct AllMedicationsView: View {
    @Environment(\.managedObjectContext) private var modelContext

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \LocalMedication.updatedAt, ascending: false)])
    private var medications: FetchedResults<LocalMedication>
    @FetchRequest(sortDescriptors: [])
    private var users: FetchedResults<LocalUser>

    @State private var errorMessage: String?
    @State private var isSyncing = false
    @State private var hiddenMedicationIds = Set<String>()
    @State private var medicationPendingDeletionId: String?
    @State private var medicationBeingEdited: LocalMedication?
    @State private var draftSelectedWeekdays: Set<Int> = []
    @State private var draftReminderTimes: [Date] = []

    private let medicationStore = MedicationStore()

    private let weekdayOrder = [2, 3, 4, 5, 6, 7, 1]
    private let weekdayTitles = [
        1: "Paz",
        2: "Pzt",
        3: "Sal",
        4: "Car",
        5: "Per",
        6: "Cum",
        7: "Cmt"
    ]

    private var activeUser: LocalUser? {
        users.first(where: \.isActive)
    }

    private var visibleMedications: [LocalMedication] {
        guard let activeUser else { return [] }

        return medications.filter {
            $0.userId == activeUser.userId
                && !$0.deletedFlag
                && !hiddenMedicationIds.contains($0.medicationId)
        }
    }

    private var areAllDraftDaysSelected: Bool {
        draftSelectedWeekdays.count == weekdayOrder.count
    }

    private var medicationPendingDeletion: LocalMedication? {
        guard let medicationPendingDeletionId else { return nil }
        return medications.first(where: { $0.medicationId == medicationPendingDeletionId })
    }

    var body: some View {
        ZStack {
            AppTheme.appBackground
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(AppTheme.danger)
                    }

                    if visibleMedications.isEmpty {
                        emptyState
                    } else {
                        overviewCard

                        ForEach(visibleMedications) { medication in
                            medicationCard(for: medication)
                        }
                    }
                }
                .padding(24)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle("Tum ilaclarim")
        .navigationBarTitleDisplayMode(.inline)
        .dismissKeyboardOnTap()
        .alert(
            "Ilaci kaldir",
            isPresented: Binding(
                get: { medicationPendingDeletionId != nil },
                set: { if !$0 { medicationPendingDeletionId = nil } }
            ),
            presenting: medicationPendingDeletion
        ) { medication in
            Button("Vazgec", role: .cancel) {
                medicationPendingDeletionId = nil
            }

            Button("Ilaci kaldir", role: .destructive) {
                Task {
                    await removeMedication(medicationId: medication.medicationId)
                }
            }
        } message: { medication in
            Text("\(medication.name) kaldirmak istediginizden emin misiniz ?")
        }
        .sheet(item: $medicationBeingEdited) { medication in
            editMedicationSheet(for: medication)
                .appSheetPresentation()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "pills.circle")
                .font(.system(size: 58))
                .foregroundStyle(AppTheme.primary)

            Text("Henuz ilac eklenmedi")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.textPrimary)

            Text("Ilac ekledikten sonra tekrar gunlerini ve saatlerini burada duzenleyebilirsin.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
    }

    private var overviewCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Ilac planlarin")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.92))

            Text("\(visibleMedications.count) aktif ilac")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("Gunleri ve saatleri buradan duzenleyebilir, artik kullanmadigin ilaclari kaldirabilirsin.")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.82))
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.heroGradient)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private func medicationCard(for medication: LocalMedication) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(AppTheme.surfaceMuted)
                        .frame(width: 54, height: 54)

                    Image(systemName: "pills.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(AppTheme.primary)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(medication.name)
                        .font(.headline)
                        .foregroundStyle(AppTheme.textPrimary)

                    Text(resolvedDaySummary(for: medication))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.primary)

                    Text(resolvedTimeSummary(for: medication))
                        .font(.footnote)
                        .foregroundStyle(AppTheme.textSecondary)
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 10) {
                Button {
                    prepareEditDraft(for: medication)
                } label: {
                    Label("Duzenle", systemImage: "slider.horizontal.3")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppTheme.surfaceMuted)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)

                Button {
                    medicationPendingDeletionId = medication.medicationId
                } label: {
                    Label("Kaldir", systemImage: "trash")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.danger)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppTheme.surfaceMuted)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)
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

    private func editMedicationSheet(for medication: LocalMedication) -> some View {
        NavigationView {
            ZStack {
                AppTheme.appBackground
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(medication.name)
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundStyle(AppTheme.textPrimary)

                            Text("Bildirim gunlerini ve saatlerini buradan guncelleyebilirsin.")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.textSecondary)
                        }

                        editDaysCard
                        editTimesCard

                        Button {
                            Task {
                                await saveMedicationEdits(for: medication)
                            }
                        } label: {
                            Text(isSyncing ? "Kaydediliyor..." : "Degisiklikleri kaydet")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 18)
                                .background(AppTheme.primary)
                                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        }
                        .disabled(isSyncing)
                        .opacity(isSyncing ? 0.7 : 1)
                    }
                    .padding(24)
                    .padding(.bottom, 24)
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kapat") {
                        medicationBeingEdited = nil
                    }
                    .foregroundStyle(AppTheme.textSecondary)
                }
            }
        }
    }

    private var editDaysCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Gunler")
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)

                Spacer()

                Button {
                    draftSelectedWeekdays = Set(weekdayOrder)
                } label: {
                    Label("Her gun", systemImage: areAllDraftDaysSelected ? "checkmark.circle.fill" : "calendar.badge.plus")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(areAllDraftDaysSelected ? .white : AppTheme.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(areAllDraftDaysSelected ? AppTheme.primary : AppTheme.surfaceMuted)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                ForEach(weekdayOrder, id: \.self) { weekday in
                    Button {
                        if draftSelectedWeekdays.contains(weekday) {
                            draftSelectedWeekdays.remove(weekday)
                        } else {
                            draftSelectedWeekdays.insert(weekday)
                        }
                    } label: {
                        Text(weekdayTitles[weekday] ?? "")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(draftSelectedWeekdays.contains(weekday) ? .white : AppTheme.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(draftSelectedWeekdays.contains(weekday) ? AppTheme.primary : AppTheme.surfaceMuted)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
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

    private var editTimesCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Saatler")
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)

                Spacer()

                Button {
                    draftReminderTimes.append(Date.now)
                } label: {
                    Label("Saat ekle", systemImage: "plus")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AppTheme.primary)
                }
                .buttonStyle(.plain)
            }

            VStack(spacing: 12) {
                ForEach(Array(draftReminderTimes.enumerated()), id: \.offset) { index, _ in
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(AppTheme.surfaceMuted)
                                .frame(width: 46, height: 46)

                            Image(systemName: "clock")
                                .foregroundStyle(AppTheme.primary)
                        }

                        DatePicker(
                            "",
                            selection: Binding(
                                get: { draftReminderTimes[index] },
                                set: { draftReminderTimes[index] = $0 }
                            ),
                            displayedComponents: .hourAndMinute
                        )
                        .labelsHidden()

                        Spacer()

                        if draftReminderTimes.count > 1 {
                            Button {
                                draftReminderTimes.remove(at: index)
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundStyle(AppTheme.danger)
                                    .frame(width: 34, height: 34)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(14)
                    .background(AppTheme.surfaceMuted)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
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

    private func prepareEditDraft(for medication: LocalMedication) {
        draftSelectedWeekdays = Set(medication.selectedWeekdays)
        draftReminderTimes = medication.reminderTimes.compactMap(makeDate(from:))

        if draftReminderTimes.isEmpty {
            draftReminderTimes = [Date.now]
        }

        medicationBeingEdited = medication
    }

    private func saveMedicationEdits(for medication: LocalMedication) async {
        let updatedWeekdays = weekdayOrder.filter { draftSelectedWeekdays.contains($0) }
        let updatedTimes = draftReminderTimes
            .sorted()
            .compactMap(timeString(from:))

        guard !updatedWeekdays.isEmpty, !updatedTimes.isEmpty else {
            errorMessage = "Lutfen en az bir gun ve bir saat sec."
            return
        }

        isSyncing = true
        errorMessage = nil

        medication.selectedWeekdays = updatedWeekdays
        medication.reminderTimes = updatedTimes
        medication.updatedAt = Date()
        medication.version += 1

        do {
            try modelContext.save()
            try LocalMedicationLogBuilder.replaceUpcomingLogs(
                for: medication,
                userId: medication.userId,
                syncStatus: activeUser?.isGuest == true ? "local_only" : "pending",
                modelContext: modelContext
            )
            let medicationLogs = try fetchMedicationLogs(for: medication.medicationId)
            try await NotificationManager.shared.syncNotifications(
                for: medication,
                logs: medicationLogs
            )

            if activeUser?.isGuest != true {
                try await medicationStore.saveMedication(
                    documentId: medication.medicationId,
                    userId: medication.userId,
                    name: medication.name,
                    dosage: medication.dosage,
                    selectedWeekdays: medication.selectedWeekdays,
                    reminderTimes: medication.reminderTimes,
                    updatedAt: medication.updatedAt,
                    version: Int(medication.version),
                    isDeleted: medication.deletedFlag
                )
            }

            medicationBeingEdited = nil
        } catch {
            errorMessage = activeUser?.isGuest == true
                ? "Ilac guncellenemedi: \(error.localizedDescription)"
                : "Ilac cihaza guncellendi ama buluta senkronize edilemedi: \(error.localizedDescription)"
        }

        isSyncing = false
    }

    private func removeMedication(medicationId: String) async {
        guard let medication = medications.first(where: { $0.medicationId == medicationId }) else {
            medicationPendingDeletionId = nil
            errorMessage = "Silinecek ilac bulunamadi."
            return
        }

        isSyncing = true
        errorMessage = nil
        hiddenMedicationIds.insert(medicationId)

        let userId = medication.userId
        let nextVersion = medication.version + 1
        let deletionDate = Date()

        do {
            try LocalMedicationLogBuilder.removeUpcomingLogs(
                for: medicationId,
                modelContext: modelContext
            )
            await NotificationManager.shared.removeNotifications(for: medicationId)
            medication.deletedFlag = true
            medication.updatedAt = deletionDate
            medication.version = nextVersion
            try modelContext.save()

            if activeUser?.isGuest != true {
                try await medicationStore.deleteMedication(
                    documentId: medicationId,
                    userId: userId,
                    updatedAt: deletionDate,
                    version: Int(nextVersion)
                )
            }

            medicationPendingDeletionId = nil
        } catch {
            hiddenMedicationIds.remove(medicationId)
            errorMessage = activeUser?.isGuest == true
                ? "Ilac kaldirilamadi: \(error.localizedDescription)"
                : "Ilac cihazdan kaldirilamadi ya da buluta senkronize edilemedi: \(error.localizedDescription)"
        }

        isSyncing = false
    }

    private func resolvedDaySummary(for medication: LocalMedication) -> String {
        let orderedDays = weekdayOrder.filter { medication.selectedWeekdays.contains($0) }

        if orderedDays.count == weekdayOrder.count {
            return "Her gun"
        }

        return orderedDays
            .compactMap { weekdayTitles[$0] }
            .joined(separator: " • ")
    }

    private func resolvedTimeSummary(for medication: LocalMedication) -> String {
        medication.reminderTimes.joined(separator: "   ")
    }

    private func makeDate(from value: String) -> Date? {
        let components = value.split(separator: ":")

        guard components.count == 2,
              let hour = Int(components[0]),
              let minute = Int(components[1]) else {
            return nil
        }

        return Calendar.current.date(
            bySettingHour: hour,
            minute: minute,
            second: 0,
            of: Date.now
        )
    }

    private func timeString(from date: Date) -> String? {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)

        guard let hour = components.hour, let minute = components.minute else {
            return nil
        }

        return String(format: "%02d:%02d", hour, minute)
    }

    private func fetchMedicationLogs(for medicationId: String) throws -> [LocalMedicationLog] {
        let logs = try modelContext.fetch(LocalMedicationLog.fetchRequest())
        return logs.filter { $0.medicationId == medicationId }
    }
}

#Preview {
    NavigationView {
        AllMedicationsView()
    }
}
