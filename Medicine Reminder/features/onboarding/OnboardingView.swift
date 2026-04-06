//
//  OnboardingView.swift
//  Medicine Reminder
//
//  Created by Omer on 25.03.2026.
//

import SwiftUI

enum OnboardingPage: Int, CaseIterable {
    case pillTracking
    case familyPillTracking

    var imageName: String {
        switch self {
        case .pillTracking:
            return "medicine1"
        case .familyPillTracking:
            return "family"
        }
    }

    var lottieFileName: String {
        switch self {
        case .pillTracking:
            return "MedicPills"
        case .familyPillTracking:
            return "MedicShield"
        }
    }

    var title: String {
        switch self {
        case .pillTracking:
            return L10n.string("onboarding.track_medicine_title")
        case .familyPillTracking:
            return L10n.string("onboarding.family_tracking_title")
        }
    }

    var description: String {
        switch self {
        case .pillTracking:
            return L10n.string("onboarding.track_medicine_description")
        case .familyPillTracking:
            return L10n.string("onboarding.family_tracking_description")
        }
    }

    var buttonTitle: String {
        isLastPage ? L10n.string("onboarding.start") : L10n.string("onboarding.continue")
    }

    var isLastPage: Bool {
        self == OnboardingPage.allCases.last
    }
}

struct OnboardingView: View {
    @State private var currentPage = 0
    private let showsStaticImages = false
    let onFinish: () -> Void

    var body: some View {
        ZStack {
            AppTheme.appBackground
                .ignoresSafeArea()

            VStack(spacing: 24) {
                TabView(selection: $currentPage) {
                    ForEach(OnboardingPage.allCases, id: \.rawValue) { page in
                        getPageView(for: page)
                            .tag(page.rawValue)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))

                VStack(spacing: 20) {
                    HStack(spacing: 12) {
                        ForEach(Array(OnboardingPage.allCases.indices), id: \.self) { index in
                            Circle()
                                .fill(currentPage == index ? AppTheme.primary : AppTheme.primarySoft)
                                .opacity(currentPage == index ? 1 : 0.55)
                                .frame(width: currentPage == index ? 12 : 8, height: currentPage == index ? 12 : 8)
                        }
                    }

                    Button(action: handleContinueTapped) {
                        Text(currentPageModel.buttonTitle)
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(AppTheme.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
    }

    private var currentPageModel: OnboardingPage {
        OnboardingPage(rawValue: currentPage) ?? .pillTracking
    }

    private func handleContinueTapped() {
        let nextPage = currentPage + 1

        if nextPage < OnboardingPage.allCases.count {
            withAnimation(.easeInOut) {
                currentPage = nextPage
            }
        } else {
            onFinish()
        }
    }

    @ViewBuilder
    private func mediaView(for page: OnboardingPage) -> some View {
        ZStack {
            OnboardingLottieView(animationName: page.lottieFileName)
                .frame(maxWidth: 280, maxHeight: 260)
                .frame(maxWidth: .infinity, minHeight: 300, maxHeight: 300)
                .padding(.horizontal, 24)

            if showsStaticImages {
                Image(page.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 280, maxHeight: 260)
                    .frame(maxWidth: .infinity, minHeight: 300, maxHeight: 300)
                    .padding(.horizontal, 24)
            }
        }
        .frame(height: 340)
    }

    @ViewBuilder
    private func getPageView(for page: OnboardingPage) -> some View {
        VStack(spacing: 30) {
            Spacer(minLength: 20)

            mediaView(for: page)

            VStack(spacing: 20) {
                Text(page.title)
                    .font(.system(.largeTitle, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Text(page.description)
                    .font(.system(.title3, design: .rounded))
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer(minLength: 0)
        }
        .padding(.top, 24)
    }
}

#Preview {
    OnboardingView(onFinish: {})
}
