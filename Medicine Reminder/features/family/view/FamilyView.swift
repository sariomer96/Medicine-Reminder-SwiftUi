//
//  FamilyView.swift
//  Medicine Reminder
//
//  Created by Codex on 28.03.2026.
//

import SwiftUI
import CoreData

struct FamilyView: View {
    @FetchRequest(sortDescriptors: [])
    private var users: FetchedResults<LocalUser>

    @StateObject private var viewModel = FamilyViewModel()

    private var activeUser: LocalUser? {
        users.first(where: \.isActive)
    }

    var body: some View {
        ZStack {
            AppTheme.appBackground
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                  

                    if let errorMessage = viewModel.errorMessage {
                        messageCard(
                            text: errorMessage,
                            color: AppTheme.danger.opacity(0.12),
                            stroke: AppTheme.danger.opacity(0.22),
                            foreground: AppTheme.danger
                        )
                    }

                    if let successMessage = viewModel.successMessage {
                        messageCard(
                            text: successMessage,
                            color: AppTheme.success.opacity(0.12),
                            stroke: AppTheme.success.opacity(0.22),
                            foreground: AppTheme.success
                        )
                    }

                    if viewModel.isGuestSession {
                        guestStateCard
                    } else {
                        shareCodeCard
                        redeemCodeCard
                        connectionsSection
                        alertsSection
                    }
                }
                .padding(24)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle("Aile Takibi")
        .navigationBarTitleDisplayMode(.inline)
        .dismissKeyboardOnTap()
        .task {
            await viewModel.load(activeUser: activeUser)
        }
    }

   

    private var guestStateCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Aile ozelligi icin hesap gerekli")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)

            Text("Takip kodu olusturmak ve baska cihazlarla eslesmek icin giris yapmis bir hesap kullanman gerekiyor.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .padding(20)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        )
    }

    private var shareCodeCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Takip kodun")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)

            Text(viewModel.shareCode ?? "Henuz kod uretilmedi")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .tracking(2)
                .foregroundStyle(viewModel.shareCode == nil ? AppTheme.textSecondary : AppTheme.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
                .background(AppTheme.surfaceMuted)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

            Text("Bu kodu kopyalayip ilac takibini alacak aile bireyine gonder.")
                .font(.footnote)
                .foregroundStyle(AppTheme.textSecondary)

            HStack(spacing: 10) {
                Button {
                    Task {
                        await viewModel.generateInviteCode()
                    }
                } label: {
                    Text(viewModel.shareCode == nil ? "Kod olustur" : "Kodu yenile")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppTheme.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .disabled(viewModel.isGeneratingCode)

                Button {
                    viewModel.copyInviteCode()
                } label: {
                    Text("Kopyala")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppTheme.surfaceMuted)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .disabled(viewModel.shareCode == nil)
            }
        }
        .padding(20)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        )
    }

    private var redeemCodeCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Kodla esles")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)

            Text("Yakininin paylastigi kodu gir. Eslesmeden sonra geciken ilac uyarilari sana da dusecek.")
                .font(.footnote)
                .foregroundStyle(AppTheme.textSecondary)

            TextField("Ornek: A7K2-P9QD", text: $viewModel.inviteCodeInput)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .foregroundStyle(AppTheme.textPrimary)
                .tint(AppTheme.primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 15)
                .background(AppTheme.surfaceMuted)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            Button {
                Task {
                    await viewModel.redeemInviteCode(activeUser: activeUser)
                }
            } label: {
                Text(viewModel.isRedeemingCode ? "Eslestiriliyor..." : "Kodu Onayla")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(AppTheme.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .disabled(viewModel.isRedeemingCode)
        }
        .padding(20)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        )
    }

    private var connectionsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Bagli kisiler")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)

            if viewModel.followers.isEmpty && viewModel.following.isEmpty {
                Text("Henuz aile eslesmesi yok. Kodu paylasarak ilk baglantini kurabilirsin.")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(AppTheme.border, lineWidth: 1)
                    )
            } else {
                if !viewModel.followers.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Beni takip edenler")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.textSecondary)

                        ForEach(viewModel.followers) { connection in
                            connectionCard(
                                title: connection.counterpart.name,
                                subtitle: connection.counterpart.email,
                                badge: "Takipci"
                            )
                        }
                    }
                }

                if !viewModel.following.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Takip ettiklerim")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.textSecondary)

                        ForEach(viewModel.following) { connection in
                            connectionCard(
                                title: connection.counterpart.name,
                                subtitle: connection.counterpart.email,
                                badge: "Bildirim aliyorum"
                            )
                        }
                    }
                }
            }
        }
    }

    private var alertsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                Text("Geciken ilac uyarilari")
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)

                Spacer(minLength: 0)

                if !viewModel.alerts.isEmpty {
                    Button {
                        Task {
                            await viewModel.clearAllAlerts()
                        }
                    } label: {
                        Text(viewModel.isDeletingAlerts ? "Siliniyor..." : "Tumunu sil")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.danger)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                          
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isDeletingAlerts)
                }
            }

            if viewModel.alerts.isEmpty {
                Text("Sana iletilmis aktif bir gecikme uyarisi yok.")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(AppTheme.border, lineWidth: 1)
                    )
            } else {
                ForEach(viewModel.alerts) { alert in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .top, spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(AppTheme.accent.opacity(0.18))
                                    .frame(width: 48, height: 48)

                                Image(systemName: "bell.badge.fill")
                                    .foregroundStyle(AppTheme.accent)
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Text(alert.patientName)
                                    .font(.headline)
                                    .foregroundStyle(AppTheme.textPrimary)

                                Text(alert.medicationName)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppTheme.primary)

                                let trimmedDosage = alert.dosage.trimmingCharacters(in: .whitespacesAndNewlines)
                                if !trimmedDosage.isEmpty {
                                    Text(trimmedDosage)
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.textSecondary)
                                }
                            }

                            Spacer(minLength: 0)

                            Button {
                                Task {
                                    await viewModel.removeAlert(alert)
                                }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                            .buttonStyle(.plain)
                            .disabled(viewModel.isDeletingAlerts)
                        }

                        Text("\(formattedDate(alert.scheduledTime)) dozunda gecikme gorundu.")
                            .font(.footnote)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    .padding(18)
                    .background(AppTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(AppTheme.border, lineWidth: 1)
                    )
                }
            }
        }
    }

    private func connectionCard(title: String, subtitle: String, badge: String) -> some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppTheme.surfaceMuted)
                    .frame(width: 46, height: 46)

                Image(systemName: "person.2.fill")
                    .foregroundStyle(AppTheme.primary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer(minLength: 0)
 
        }
        .padding(18)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        )
    }

    private func messageCard(
        text: String,
        color: Color,
        stroke: Color,
        foreground: Color
    ) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(foreground)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(stroke, lineWidth: 1)
            )
    }

    private func formattedDate(_ date: Date) -> String {
        date.formatted(
            Date.FormatStyle()
                .day(.twoDigits)
                .month(.wide)
                .hour(.twoDigits(amPM: .omitted))
                .minute(.twoDigits)
        )
    }
}

#Preview {
    FamilyView()
}
