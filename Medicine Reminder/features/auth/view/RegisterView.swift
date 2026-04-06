//
//  RegisterView.swift
//  Medicine Reminder
//
//  Created by Codex on 25.03.2026.
//

import SwiftUI

struct RegisterView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = RegisterViewModel()
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
                   
                     
                    VStack(alignment: .leading, spacing: 18) {
                        AuthField(
                            title: L10n.string("auth.full_name"),
                            placeholder: L10n.string("auth.full_name_placeholder"),
                            text: $fullName
                        )

                        AuthField(
                            title: L10n.string("auth.email"),
                            placeholder: L10n.string("auth.email_placeholder"),
                            text: $email
                        )

                        AuthSecureField(
                            title: L10n.string("auth.password"),
                            placeholder: L10n.string("auth.password_create_placeholder"),
                            text: $password
                        )

                        AuthSecureField(
                            title: L10n.string("auth.password_confirm"),
                            placeholder: L10n.string("auth.password_confirm_placeholder"),
                            text: $confirmPassword
                        )

                        if let errorMessage = viewModel.errorMessage {
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }

                        Button {
                            Task {
                                await viewModel.register(
                                    fullName: fullName,
                                    email: email,
                                    password: password,
                                    confirmPassword: confirmPassword
                                )
                            }
                        } label: {
                            Group {
                                if viewModel.isLoading {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .tint(.white)
                                } else {
                                    Text(L10n.string("auth.register"))
                                        .font(.headline)
                                        .foregroundStyle(.white)
                                }
                            }
                                .frame(maxWidth: .infinity)
                                .frame(height: 24)
                                .padding(.vertical, 16)
                                .background(AppTheme.primary)
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                        .disabled(viewModel.isLoading)
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
        .onChange(of: viewModel.isRegistered) { isRegistered in
            if isRegistered {
                dismiss()
            }
        }
        .navigationTitle(L10n.string("auth.register_title"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                        Text(L10n.string("common.back"))
                    }
                    .foregroundStyle(AppTheme.primary)
                }
            }
        }
        .dismissKeyboardOnTap()
    }
}


#Preview {
    RegisterView()
}
