//
//  LoginView.swift
//  Medicine Reminder
//
//  Created by Codex on 25.03.2026.
//

import SwiftUI

struct LoginView: View {
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        ZStack {
            AppTheme.appBackground
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .center, spacing: 12) {
                        Text("Hos Geldiniz")
                            .font(.system(size: 32, weight: .medium, design: .rounded))
                            .foregroundStyle(AppTheme.textPrimary)

                            

                        Image("medicine")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 120, height: 120)
                            .frame(maxWidth: .infinity, alignment: .center)
                         
                    }

                    VStack(alignment: .leading, spacing: 18) {
                        AuthField(
                            title: "E-posta",
                            placeholder: "ornek@mail.com",
                            text: $email
                        )

                        AuthSecureField(
                            title: "Sifre",
                            placeholder: "Sifrenizi girin",
                            text: $password
                        )

                        Button {
                        } label: {
                            Text("Giris yap")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(AppTheme.primary)
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }

                        Button {
                        } label: {
                            Text("Misafir olarak giris yap")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.primary)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.plain)
                        
                        Button {
                        } label: {
                            Text("Kayit Ol")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.primary)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.plain)
                        .padding(.top,16)
                    }
                    .padding(22)
                    .background(AppTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(AppTheme.border, lineWidth: 1)
                    )
                    .shadow(color: AppTheme.primary.opacity(0.10), radius: 16, x: 0, y: 10)

                    
                }
                .padding(24)
            }
        }
    }
}


#Preview {
    LoginView()
}
