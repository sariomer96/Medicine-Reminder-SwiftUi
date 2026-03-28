//
//  DoseConfirmationSheet.swift
//  Medicine Reminder
//
//  Created by Codex on 28.03.2026.
//

import SwiftUI
import SwiftData

struct DoseConfirmationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query private var medications: [LocalMedication]
    @Query private var medicationLogs: [LocalMedicationLog]

    @State private var errorMessage: String?
    @State private var isConfirming = false

    let logId: String

    private var medicationLog: LocalMedicationLog? {
        medicationLogs.first(where: { $0.logId == logId })
    }

    private var medication: LocalMedication? {
        guard let medicationLog else { return nil }

        return medications.first {
            $0.medicationId == medicationLog.medicationId && !$0.isDeleted
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.appBackground
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        headerCard

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
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Kapat") {
                        dismiss()
                    }
                    .foregroundStyle(AppTheme.textSecondary)
                }
            }
        }
    }

    @ViewBuilder
    private var headerCard: some View {
        if let medicationLog, let medication {
            VStack(alignment: .leading, spacing: 18) {
                Text("Doz onayi")
                    .font(.headline)
                    .foregroundStyle(AppTheme.textSecondary)

                Text(medication.name)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)

                detailRow(title: "Saat", value: formattedDate(medicationLog.scheduledTime))

                let trimmedDosage = medication.dosage.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmedDosage.isEmpty {
                    detailRow(title: "Doz", value: trimmedDosage)
                }

                if medicationLog.taken {
                    Text("Bu doz zaten onaylanmis.")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.success)
                } else {
                    Button {
                        confirmDose()
                    } label: {
                        Text(isConfirming ? "Kaydediliyor..." : "Bu dozu aldim")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(AppTheme.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(isConfirming)
                    .opacity(isConfirming ? 0.7 : 1)
                }
            }
            .padding(22)
            .background(AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(AppTheme.border, lineWidth: 1)
            )
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Text("Doz bulunamadi")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppTheme.textPrimary)

                Text("Bu bildirimle bagli doz kaydi artik bulunamiyor veya daha once temizlenmis olabilir.")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .padding(22)
            .background(AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(AppTheme.border, lineWidth: 1)
            )
        }
    }

    private func detailRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppTheme.textSecondary)

            Text(value)
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)
        }
    }

    private func formattedDate(_ date: Date) -> String {
        date.formatted(
            Date.FormatStyle()
                .weekday(.wide)
                .day(.twoDigits)
                .month(.wide)
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
            dismiss()
        } catch {
            errorMessage = "Doz onayi kaydedilemedi: \(error.localizedDescription)"
        }

        isConfirming = false
    }
}

#Preview {
    DoseConfirmationSheet(logId: "preview")
}
