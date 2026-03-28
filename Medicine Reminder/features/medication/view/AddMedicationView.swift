//
//  AddMedicationView.swift
//  Medicine Reminder
//
//  Created by Codex on 27.03.2026.
//

import SwiftUI
import SwiftData

struct AddMedicationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    private let weekdaySymbols = ["Pzt", "Sal", "Car", "Per", "Cum", "Cmt", "Paz"]

    @StateObject private var viewModel = AddMedicationViewModel()
    @State private var showsSearchSheet = false
    @State private var selectedDays: Set<String> = []
    @State private var dosageTimes = [
        Date.now,
        Calendar.current.date(byAdding: .hour, value: 8, to: Date.now) ?? Date.now
    ]

    private var areAllDaysSelected: Bool {
        selectedDays.count == weekdaySymbols.count
    }

    var body: some View {
        ZStack {
            AppTheme.appBackground
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    medicationCard
                    scheduleCard

                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(AppTheme.danger)
                    }

                    if let infoMessage = viewModel.infoMessage {
                        Text(infoMessage)
                            .font(.footnote)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
                .padding(24)
                .padding(.bottom, 120)
            }
        }
        .safeAreaInset(edge: .bottom) {
            saveButton
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 12)
                .background(
                    AppTheme.appBackground
                        .ignoresSafeArea()
                )
        }
        .navigationTitle("Yeni ilac ekle")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showsSearchSheet) {
            medicationSearchSheet
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
        }
    }

    private var medicationCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Ilac bilgisi")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)

            Button {
                viewModel.loadMedicationNamesIfNeeded()
                showsSearchSheet = true
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppTheme.primary)
                        .frame(width: 42, height: 42)
                        .background(AppTheme.surfaceMuted)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.selectedMedicationName.isEmpty ? "Ilac sec" : viewModel.selectedMedicationName)
                            .font(.headline)
                            .foregroundStyle(viewModel.selectedMedicationName.isEmpty ? AppTheme.textSecondary : AppTheme.textPrimary)

                        Text("Ilaci degistirmek veya yenisini yazmak icin dokun")
                            .font(.footnote)
                            .foregroundStyle(AppTheme.textSecondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.surfaceMuted)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        )
    }

    private var scheduleCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Kullanim plani")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Gunler")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)

                    Spacer()

                    Button {
                        selectedDays = Set(weekdaySymbols)
                    } label: {
                        Label("Her gun", systemImage: areAllDaysSelected ? "checkmark.circle.fill" : "calendar.badge.plus")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(areAllDaysSelected ? .white : AppTheme.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(areAllDaysSelected ? AppTheme.primary : AppTheme.surfaceMuted)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    if !selectedDays.isEmpty {
                        Button("Temizle") {
                            selectedDays.removeAll()
                        }
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                        .buttonStyle(.plain)
                    }
                }

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                    ForEach(weekdaySymbols, id: \.self) { day in
                        Button {
                            if selectedDays.contains(day) {
                                selectedDays.remove(day)
                            } else {
                                selectedDays.insert(day)
                            }
                        } label: {
                            Text(day)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(selectedDays.contains(day) ? .white : AppTheme.textPrimary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(selectedDays.contains(day) ? AppTheme.primary : AppTheme.surfaceMuted)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Saatler")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)

                    Spacer()

                    Button {
                        dosageTimes.append(Date.now)
                    } label: {
                        Label("Saat ekle", systemImage: "plus")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(AppTheme.primary)
                    }
                    .buttonStyle(.plain)
                }

                VStack(spacing: 12) {
                    ForEach(Array(dosageTimes.enumerated()), id: \.offset) { index, _ in
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
                                    get: { dosageTimes[index] },
                                    set: { dosageTimes[index] = $0 }
                                ),
                                displayedComponents: .hourAndMinute
                            )
                            .labelsHidden()

                            Spacer()

                            if dosageTimes.count > 1 {
                                Button {
                                    dosageTimes.remove(at: index)
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
        }
        .padding(20)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        )
    }

    private var saveButton: some View {
        Button {
            Task {
                await viewModel.saveMedication(
                    selectedDays: selectedDays,
                    dosageTimes: dosageTimes,
                    modelContext: modelContext
                )

                if viewModel.saveSucceeded {
                    dismiss()
                }
            }
        } label: {
            Text(viewModel.isSaving ? "Kaydediliyor..." : "Ilaci kaydet")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(AppTheme.primary)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .disabled(viewModel.isSaving)
        .opacity(viewModel.isSaving ? 0.7 : 1)
    }

    private var medicationSearchSheet: some View {
        NavigationStack {
            ZStack {
                AppTheme.appBackground
                    .ignoresSafeArea()

                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Ilac ara")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.textPrimary)

                        Text("Ilaci ara, listeden sec ya da yazdigin isimle ekle.")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.textSecondary)
                    }

                    TextField("Ilac adiyla ara", text: $viewModel.medicationSearchText)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                        .background(AppTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(AppTheme.border, lineWidth: 1)
                        )

                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(AppTheme.danger)
                    }

                    if viewModel.isLoading {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("Ilac listesi yukleniyor...")
                                .font(.footnote)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }

                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.filteredMedications, id: \.self) { medication in
                                Button {
                                    viewModel.selectMedication(medication)
                                    showsSearchSheet = false
                                } label: {
                                    HStack(spacing: 14) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                .fill(AppTheme.surfaceMuted)
                                                .frame(width: 48, height: 48)

                                            Image(systemName: "pills.fill")
                                                .foregroundStyle(AppTheme.primary)
                                        }

                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(medication)
                                                .font(.headline)
                                                .foregroundStyle(AppTheme.textPrimary)

                                            Text("Ilaci sec ve plani olusturmaya devam et")
                                                .font(.footnote)
                                                .foregroundStyle(AppTheme.textSecondary)
                                        }

                                        Spacer()

                                        Image(systemName: "plus.circle.fill")
                                            .font(.title3)
                                            .foregroundStyle(AppTheme.primary)
                                    }
                                    .padding(16)
                                    .background(AppTheme.surface)
                                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                                            .stroke(AppTheme.border, lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.bottom, 12)
                    }

                    Button {
                        viewModel.selectMedication(viewModel.resolvedCustomMedicationName)
                        showsSearchSheet = false
                    } label: {
                        VStack(spacing: 4) {
                            Text("\"\(viewModel.resolvedCustomMedicationName)\" olarak ekle")
                                .font(.headline)
                                .foregroundStyle(.white)

                            Text("Ilaci listede bulamazsan bu isimle devam et")
                                .font(.footnote)
                                .foregroundStyle(.white.opacity(0.82))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(AppTheme.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .disabled(viewModel.resolvedCustomMedicationName.isEmpty)
                    .opacity(viewModel.resolvedCustomMedicationName.isEmpty ? 0.5 : 1)
                }
                .padding(24)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

}

#Preview {
    NavigationStack {
        AddMedicationView()
    }
}
