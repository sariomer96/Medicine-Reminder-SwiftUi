//
//  HomeView.swift
//  Medicine Reminder
//
//  Created by Omer on 25.03.2026.
//

import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = HomeViewModel()
    let sessionDisplayName: String

    var body: some View {
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

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Siradaki doz")
                            .font(.headline)
                            .foregroundStyle(.white.opacity(0.9))

                        Text("08:30")
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)

                        Text("Vitamin D - 1 tablet")
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.heroGradient)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

                    HStack(spacing: 14) {
                        summaryCard(
                            title: "Tamamlandi",
                            value: "4",
                            tint: AppTheme.success
                        )

                        summaryCard(
                            title: "Geciken",
                            value: "1",
                            tint: AppTheme.accent
                        )
                    }

                    Button {
                    } label: {
                        Text("Yeni ilac ekle")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(AppTheme.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                }
                .padding(24)
            }
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

    private func summaryCard(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Circle()
                .fill(tint.opacity(0.18))
                .frame(width: 42, height: 42)
                .overlay {
                    Circle()
                        .fill(tint)
                        .frame(width: 16, height: 16)
                }

            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.textPrimary)

            Text(title)
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        )
    }
}

#Preview {
    HomeView(sessionDisplayName: "Guest")
}
