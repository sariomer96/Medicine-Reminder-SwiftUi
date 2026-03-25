//
//  OnboardingView.swift
//  Medicine Reminder
//
//  Created by Omer on 25.03.2026.
//

import SwiftUI

struct OnboardingView: View {
    var body: some View {
        ZStack {
            AppTheme.appBackground
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Medicine Reminder")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.textPrimary)

                    Text("Ilac takibini sade, guven veren ve anlasilir bir deneyimle yonetin.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("merhaba")
                        .font(.headline)
                        .foregroundStyle(AppTheme.textPrimary)

                    Text("Hatirlaticilariniz tek bakista gorunur, kritik bilgiler net sekilde ayrisir.")
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
                .shadow(color: AppTheme.primary.opacity(0.12), radius: 18, x: 0, y: 10)

                VStack(alignment: .leading, spacing: 10) {
                    Label("Sakin ve temiz yesil-mavi tonlar", systemImage: "cross.case.fill")
                    Label("Uyari ve odak icin sicak vurgu rengi", systemImage: "bell.badge.fill")
                    Label("Okunurlugu yuksek kart ve yazi kontrasti", systemImage: "heart.text.square.fill")
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppTheme.primary)
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.surfaceMuted)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

                Spacer(minLength: 0)
            }
            .padding(24)
        }
    }
}

#Preview {
    OnboardingView()
}
