//
//  ReviewPromptCoordinator.swift
//  Medicine Reminder
//
//  Created by Codex on 12.04.2026.
//

import Foundation
import StoreKit
import UIKit

@MainActor
final class ReviewPromptCoordinator: ObservableObject {
    static let shared = ReviewPromptCoordinator()

    @Published private(set) var shouldShowPrompt = false

    private enum Keys {
        static let installDate = "reviewPrompt.installDate"
        static let appOpenCount = "reviewPrompt.appOpenCount"
        static let medicationCreatedCount = "reviewPrompt.medicationCreatedCount"
        static let doseConfirmedCount = "reviewPrompt.doseConfirmedCount"
        static let lastPromptVersion = "reviewPrompt.lastPromptVersion"
        static let lastPromptDate = "reviewPrompt.lastPromptDate"
        static let snoozeUntil = "reviewPrompt.snoozeUntil"
    }

    private let defaults: UserDefaults
    private let calendar: Calendar
    private let nowProvider: () -> Date

    init(
        defaults: UserDefaults = .standard,
        calendar: Calendar = .current,
        nowProvider: @escaping () -> Date = Date.init
    ) {
        self.defaults = defaults
        self.calendar = calendar
        self.nowProvider = nowProvider
    }

    func registerInstallIfNeeded() {
        guard defaults.object(forKey: Keys.installDate) == nil else { return }
        defaults.set(nowProvider(), forKey: Keys.installDate)
    }

    func recordAppOpen() {
        defaults.set(defaults.integer(forKey: Keys.appOpenCount) + 1, forKey: Keys.appOpenCount)
    }

    func recordMedicationCreated() {
        defaults.set(defaults.integer(forKey: Keys.medicationCreatedCount) + 1, forKey: Keys.medicationCreatedCount)
    }

    func recordDoseConfirmed() {
        defaults.set(defaults.integer(forKey: Keys.doseConfirmedCount) + 1, forKey: Keys.doseConfirmedCount)
    }

    func evaluatePromptEligibility() {
        guard !shouldShowPrompt else { return }
        guard isEligibleToPrompt(now: nowProvider()) else { return }
        shouldShowPrompt = true
    }

    func deferPrompt() {
        shouldShowPrompt = false
        let snoozeUntil = calendar.date(byAdding: .day, value: 14, to: nowProvider()) ?? nowProvider()
        defaults.set(snoozeUntil, forKey: Keys.snoozeUntil)
    }

    func requestReview() {
        let now = nowProvider()
        shouldShowPrompt = false
        defaults.set(now, forKey: Keys.lastPromptDate)
        defaults.set(currentAppVersion, forKey: Keys.lastPromptVersion)
        defaults.removeObject(forKey: Keys.snoozeUntil)

        if let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) {
            SKStoreReviewController.requestReview(in: windowScene)
        }
    }

    private func isEligibleToPrompt(now: Date) -> Bool {
        guard let installDate = defaults.object(forKey: Keys.installDate) as? Date else {
            return false
        }

        guard hasReachedThirdDay(since: installDate, now: now) else {
            return false
        }

        if let snoozeUntil = defaults.object(forKey: Keys.snoozeUntil) as? Date, now < snoozeUntil {
            return false
        }

        if let lastPromptDate = defaults.object(forKey: Keys.lastPromptDate) as? Date {
            let minimumNextPromptDate = calendar.date(byAdding: .day, value: 120, to: lastPromptDate) ?? lastPromptDate
            if now < minimumNextPromptDate {
                return false
            }
        }

        let hasMinimumUsageSignal =
            defaults.integer(forKey: Keys.appOpenCount) >= 3 ||
            defaults.integer(forKey: Keys.medicationCreatedCount) >= 1 ||
            defaults.integer(forKey: Keys.doseConfirmedCount) >= 1

        guard hasMinimumUsageSignal else {
            return false
        }

        return defaults.string(forKey: Keys.lastPromptVersion) != currentAppVersion
    }

    private func hasReachedThirdDay(since installDate: Date, now: Date) -> Bool {
        guard let eligibleDate = calendar.date(byAdding: .day, value: 2, to: installDate) else {
            return false
        }

        return now >= eligibleDate
    }

    private var currentAppVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
    }
}
