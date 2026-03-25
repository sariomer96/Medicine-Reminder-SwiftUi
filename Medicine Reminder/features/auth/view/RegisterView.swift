//
//  RegisterView.swift
//  Medicine Reminder
//
//  Created by Codex on 25.03.2026.
//

import SwiftUI

struct RegisterView: View {
    @State private var fullName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""

    var body: some View {
        ZStack {
            AppTheme.appBackground
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .center) {
                  
                    Image("medicine")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 120, height: 120)
                        .frame(maxWidth: .infinity, alignment: .center)
                     
                    VStack(alignment: .leading, spacing: 18) {
                        AuthField(
                            title: "Ad Soyad",
                            placeholder: "Adinizi girin",
                            text: $fullName
                        )

                        AuthField(
                            title: "E-posta",
                            placeholder: "ornek@mail.com",
                            text: $email
                        )

                        AuthSecureField(
                            title: "Sifre",
                            placeholder: "Sifrenizi olusturun",
                            text: $password
                        )

                        AuthSecureField(
                            title: "Sifre Tekrar",
                            placeholder: "Sifrenizi tekrar girin",
                            text: $confirmPassword
                        )

                        Button {
                        } label: {
                            Text("Kayit ol")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(AppTheme.primary)
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
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
                .padding(.top, 32)
            }
        }
    }
}


#Preview {
    RegisterView()
}
