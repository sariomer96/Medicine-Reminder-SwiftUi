//
//  LoginView.swift
//  Medicine Reminder
//
//  Created by Codex on 25.03.2026.
//

import SwiftUI
import CoreData

struct LoginView: View {
    @Environment(\.managedObjectContext) private var modelContext
    @AppStorage("auth.rememberMe") private var storedRememberMe = false
    @AppStorage("auth.rememberedEmail") private var storedRememberedEmail = ""
    @StateObject private var viewModel = LoginViewModel()
    @State private var email = ""
    @State private var password = ""
    @State private var rememberMe = false
    @State private var hasRestoredSession = false

    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.appBackground
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        Spacer(minLength: 88)

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

                            Toggle("Beni hatirla", isOn: $rememberMe)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(AppTheme.textPrimary)
                                .tint(AppTheme.primary)

                            if let errorMessage = viewModel.errorMessage {
                                Text(errorMessage)
                                    .font(.footnote)
                                    .foregroundStyle(.red)
                            }

                            Button {
                                Task {
                                    await viewModel.login(email: email, password: password, modelContext: modelContext)
                                }
                            } label: {
                                Group {
                                    if viewModel.isLoading {
                                        ProgressView()
                                            .progressViewStyle(.circular)
                                            .tint(.white)
                                    } else {
                                        Text("Giris yap")
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

                            Button {
                                viewModel.loginAsGuest(modelContext: modelContext)
                            } label: {
                                Text("Misafir olarak giris yap")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppTheme.primary)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.plain)

                            NavigationLink {
                                RegisterView()
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

                        Spacer(minLength: 24)
                    }
                    .frame(maxWidth: .infinity, minHeight: UIScreen.main.bounds.height * 0.82)
                    .padding(24)
                }
            }
            .hiddenNavigationBarCompat()
        }
        .fullScreenCover(isPresented: $viewModel.isLoggedIn) {
            AppNavigatorView(
                sessionDisplayName: viewModel.sessionDisplayName,
                onSessionEnded: {
                    viewModel.isLoggedIn = false
                }
            )
            .environment(\.managedObjectContext, modelContext)
        }
        .onAppear {
            viewModel.restoreSessionIfNeeded(
                hasRestoredSession: &hasRestoredSession,
                modelContext: modelContext
            )
            rememberMe = storedRememberMe

            if storedRememberMe {
                email = storedRememberedEmail
            }
        }
        .onChange(of: rememberMe) { newValue in
            storedRememberMe = newValue

            if !newValue {
                storedRememberedEmail = ""
            }
        }
        .onChange(of: viewModel.isLoggedIn) { isLoggedIn in
            guard isLoggedIn else { return }

            if rememberMe {
                storedRememberedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                storedRememberedEmail = ""
            }
        }
        .dismissKeyboardOnTap()
    }
}


#Preview {
    LoginView()
}
