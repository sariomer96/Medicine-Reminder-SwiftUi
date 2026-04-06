//
//  DoseConfirmationSheet.swift
//  Medicine Reminder
//
//  Created by Codex on 28.03.2026.
//

import SwiftUI
import CoreData

struct DoseConfirmationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var modelContext

    @FetchRequest(sortDescriptors: [])
    private var medications: FetchedResults<LocalMedication>
    @FetchRequest(sortDescriptors: [])
    private var medicationLogs: FetchedResults<LocalMedicationLog>

    @State private var errorMessage: String?
    @State private var isConfirming = false
    @State private var showSuccessState = false

    private let familyStore = FamilyStore()
    private let medicationLogStore = MedicationLogStore()

    let logId: String

    private var medicationLog: LocalMedicationLog? {
        medicationLogs.first(where: { $0.logId == logId })
    }

    private var medication: LocalMedication? {
        guard let medicationLog else { return nil }

        return medications.first {
            $0.medicationId == medicationLog.medicationId && !$0.deletedFlag
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.appBackground
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                   
                        contentCard

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundStyle(AppTheme.danger)
                        }
                    }
                    .padding(24)
                    .padding(.bottom, 24)
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kapat") {
                        dismiss()
                    }
                    .foregroundStyle(AppTheme.textSecondary)
                }
            }
        }
        .dismissKeyboardOnTap()
    }

 

    @ViewBuilder
    private var contentCard: some View {
        if let medicationLog, let medication {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top, spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(AppTheme.heroGradient)
                            .frame(width: 62, height: 62)

                        Image(systemName: medicationLog.taken ? "checkmark.circle.fill" : "pills.fill")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text(formattedShortTime(medicationLog.scheduledTime))
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.textPrimary)

                        Text(medication.name)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                            .lineLimit(2)

                        Text(formattedLongDate(medicationLog.scheduledTime))
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    }

                    Spacer(minLength: 0)
                }

                HStack(spacing: 10) {
                    infoChip(
                        title: "Durum",
                        value: medicationLog.taken ? "Onaylandi" : "Bekliyor"
                    )

                    let trimmedDosage = medication.dosage.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmedDosage.isEmpty {
                        infoChip(title: "Doz", value: trimmedDosage)
                    }
                }

                Divider()
                    .overlay(AppTheme.border)

                if medicationLog.taken {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(AppTheme.success)

                        Text("Onaylandı.")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(AppTheme.success)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(AppTheme.success.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                       

                        ZStack {
                            Button {
                                confirmDose()
                            } label: {
                                HStack {
                                    Spacer()

                                    Text(isConfirming ? "Kaydediliyor..." : "Bu dozu aldim")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.white)

                                    Spacer()
                                }
                                .padding(.vertical, 15)
                                .background(AppTheme.primary)
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .disabled(isConfirming || showSuccessState)
                            .opacity(isConfirming || showSuccessState ? 0.25 : 1)

                            if showSuccessState {
                                successOverlay
                                    .transition(.asymmetric(
                                        insertion: .scale(scale: 0.88).combined(with: .opacity),
                                        removal: .opacity
                                    ))
                            }
                        }
                        .animation(.spring(response: 0.42, dampingFraction: 0.82), value: showSuccessState)
                    }
                }
            }
            .padding(24)
            .background(AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(AppTheme.border, lineWidth: 1)
            )
            .shadow(color: AppTheme.primary.opacity(0.08), radius: 18, x: 0, y: 10)
        } else {
            VStack(alignment: .leading, spacing: 14) {
                Text("Doz bulunamadi")
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)

                Text("Bu bildirimle bagli doz kaydi artik bulunamiyor veya daha once temizlenmis olabilir.")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .padding(24)
            .background(AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(AppTheme.border, lineWidth: 1)
            )
        }
    }

    private func infoChip(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.textSecondary)

            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(AppTheme.surfaceMuted)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var successOverlay: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(AppTheme.success)
                .scaleEffect(showSuccessState ? 1 : 0.82)
                .animation(.spring(response: 0.38, dampingFraction: 0.7), value: showSuccessState)

            Text("Onaylandi")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 15)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.94))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppTheme.success.opacity(0.28), lineWidth: 1)
        )
    }

    private func formattedLongDate(_ date: Date) -> String {
        date.formatted(
            Date.FormatStyle()
                .weekday(.wide)
                .day(.twoDigits)
                .month(.wide)
                .year(.defaultDigits)
                .hour(.twoDigits(amPM: .omitted))
                .minute(.twoDigits)
        )
    }

    private func formattedShortTime(_ date: Date) -> String {
        date.formatted(
            Date.FormatStyle()
                .hour(.twoDigits(amPM: .omitted))
                .minute(.twoDigits)
        )
    }

    private func confirmDose() {
        guard let medicationLog else { return }

        isConfirming = true
        errorMessage = nil

        medicationLog.taken = true
        medicationLog.takenAt = Date()
        medicationLog.updatedAt = Date()
        medicationLog.syncStatus = medicationLog.syncStatus == "local_only" ? "local_only" : "pending"

        do {
            try modelContext.save()

            Task {
                try? await familyStore.resolveAlerts(for: logId)
                try? await medicationLogStore.markLogTaken(log: medicationLog)
            }

            withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
                showSuccessState = true
            }

            Task {
                try? await Task.sleep(nanoseconds: 900_000_000)
                await MainActor.run {
                    dismiss()
                }
            }
        } catch {
            errorMessage = "Doz onayi kaydedilemedi: \(error.localizedDescription)"
        }

        isConfirming = false
    }
}

#Preview {
    DoseConfirmationSheet(logId: "preview")
}
