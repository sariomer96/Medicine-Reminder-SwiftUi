//
//  HomeView.swift
//  Medicine Reminder
//
//  Created by Omer on 25.03.2026.
//

import SwiftUI

struct HomeView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var errorMessage: String?

    private let authRepository: AuthRepositoryProtocol = AuthRepository()

    var body: some View {
        ZStack {
            AppTheme.appBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .top, spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Bugunku Ilaclar")
                                .font(.system(size: 30, weight: .bold, design: .rounded))
                                .foregroundStyle(AppTheme.textPrimary)

                            Text("Takip, bildirim ve log ekranlari icin temel renk sistemi hazir.")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.textSecondary)
                        }

                        Spacer()

                        Button {
                            signOut()
                        } label: {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(AppTheme.primary)
                                .frame(width: 44, height: 44)
                                .background(AppTheme.surface)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                        .stroke(AppTheme.border, lineWidth: 1)
                                )
                        }
                    }

                    if let errorMessage {
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

    private func signOut() {
        do {
            try authRepository.signOut()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    HomeView()
}
