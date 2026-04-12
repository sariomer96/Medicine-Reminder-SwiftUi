//
//  AddMedicationView.swift
//  Medicine Reminder
//
//  Created by Codex on 27.03.2026.
//

import SwiftUI
import CoreData

struct AddMedicationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var modelContext

    @StateObject private var viewModel = AddMedicationViewModel()
    @State private var showsSearchSheet = false
    @State private var selectedDays: Set<String> = []
    @State private var activeToast: AddMedicationToast?
    @State private var dosageTimes = [
        Date.now,
        Calendar.current.date(byAdding: .hour, value: 8, to: Date.now) ?? Date.now
    ]

    private var areAllDaysSelected: Bool {
        selectedDays.count == weekdaySymbols.count
    }

    private var weekdaySymbols: [String] {
        [
            L10n.string("weekday.monday.short"),
            L10n.string("weekday.tuesday.short"),
            L10n.string("weekday.wednesday.short"),
            L10n.string("weekday.thursday.short"),
            L10n.string("weekday.friday.short"),
            L10n.string("weekday.saturday.short"),
            L10n.string("weekday.sunday.short")
        ]
    }

    var body: some View {
        ZStack {
            AppTheme.appBackground
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    medicationCard
                    scheduleCard
                }
                .padding(24)
                .padding(.bottom, 120)
            }

            if let activeToast {
                VStack {
                    toastView(for: activeToast)
                    Spacer()
                }
                .padding(.top, 12)
                .padding(.horizontal, 20)
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(1)
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
        .navigationTitle(L10n.string("medication.add.navigation_title"))
        .navigationBarTitleDisplayMode(.inline)
        .dismissKeyboardOnTap()
        .sheet(isPresented: $showsSearchSheet) {
            medicationSearchSheet
                .appSheetPresentation()
        }
        .onChange(of: viewModel.errorMessage) { errorMessage in
            guard let errorMessage else { return }
            showToast(message: errorMessage, style: .error)
            viewModel.clearErrorMessage()
        }
        .onChange(of: viewModel.infoMessage) { infoMessage in
            guard let infoMessage else { return }
            showToast(message: infoMessage, style: .info)
            viewModel.clearInfoMessage()
        }
    }

    private var medicationCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.string("medication.info"))
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
                        Text(viewModel.selectedMedicationName.isEmpty ? L10n.string("medication.select") : viewModel.selectedMedicationName)
                            .font(.headline)
                            .foregroundStyle(viewModel.selectedMedicationName.isEmpty ? AppTheme.textSecondary : AppTheme.textPrimary)

                        Text(L10n.string("medication.change_hint"))
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
            Text(L10n.string("medication.plan"))
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(L10n.string("medication.days"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)

                    Spacer()

                    Button {
                        selectedDays = Set(weekdaySymbols)
                    } label: {
                        Label(L10n.string("weekday.every_day"), systemImage: areAllDaysSelected ? "checkmark.circle.fill" : "calendar.badge.plus")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(areAllDaysSelected ? .white : AppTheme.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(areAllDaysSelected ? AppTheme.primary : AppTheme.surfaceMuted)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    if !selectedDays.isEmpty {
                        Button(L10n.string("common.clear")) {
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
                    Text(L10n.string("medication.times"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)

                    Spacer()

                    Button {
                        dosageTimes.append(Date.now)
                    } label: {
                        Label(L10n.string("medication.add_time"), systemImage: "plus")
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
                    ReviewPromptCoordinator.shared.recordMedicationCreated()
                    dismiss()
                }
            }
        } label: {
            Text(viewModel.isSaving ? L10n.string("common.loading_saving") : L10n.string("medication.save"))
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
        NavigationView {
            ZStack {
                AppTheme.appBackground
                    .ignoresSafeArea()

                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.string("medication.search_title"))
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.textPrimary)

                        Text(L10n.string("medication.search_description"))
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.textSecondary)
                    }

                    TextField(L10n.string("medication.search_placeholder"), text: $viewModel.medicationSearchText)
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
                            Text(L10n.string("medication.list_loading"))
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

                                            Text(L10n.string("medication.select_and_continue"))
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
                            Text(L10n.format("medication.add_as_custom", viewModel.resolvedCustomMedicationName))
                                .font(.headline)
                                .foregroundStyle(.white)

                            Text(L10n.string("medication.not_in_list_continue"))
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
            .hiddenNavigationBarCompat()
        }
    }

    private func toastView(for toast: AddMedicationToast) -> some View {
        HStack(spacing: 12) {
            Image(systemName: toast.style.iconName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(toast.style.iconColor)

            Text(toast.message)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(toast.style.backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(toast.style.borderColor, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 8)
    }

    private func showToast(message: String, style: AddMedicationToastStyle) {
        let toast = AddMedicationToast(message: message, style: style)

        withAnimation(.spring(response: 0.36, dampingFraction: 0.82)) {
            activeToast = toast
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) {
            guard activeToast?.id == toast.id else { return }

            withAnimation(.spring(response: 0.36, dampingFraction: 0.82)) {
                activeToast = nil
            }
        }
    }

}

private struct AddMedicationToast: Identifiable, Equatable {
    let id = UUID()
    let message: String
    let style: AddMedicationToastStyle
}

private enum AddMedicationToastStyle: Equatable {
    case error
    case info

    var iconName: String {
        switch self {
        case .error:
            return "exclamationmark.circle.fill"
        case .info:
            return "checkmark.circle.fill"
        }
    }

    var iconColor: Color {
        switch self {
        case .error:
            return AppTheme.danger
        case .info:
            return AppTheme.primary
        }
    }

    var backgroundColor: Color {
        switch self {
        case .error:
            return Color.white
        case .info:
            return Color.white
        }
    }

    var borderColor: Color {
        switch self {
        case .error:
            return AppTheme.danger.opacity(0.24)
        case .info:
            return AppTheme.primary.opacity(0.24)
        }
    }
}

#Preview {
    NavigationView {
        AddMedicationView()
    }
}
