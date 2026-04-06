//
//  FamilyViewModel.swift
//  Medicine Reminder
//
//  Created by Codex on 28.03.2026.
//

import Foundation
import UIKit
import FirebaseAuth

struct FamilySummary {
    let shareCode: String?
    let followerCount: Int
    let followingCount: Int
    let overdueAlertCount: Int
    let isGuestSession: Bool
}

@MainActor
final class FamilyViewModel: ObservableObject {
    @Published var inviteCodeInput = ""
    @Published private(set) var shareCode: String?
    @Published private(set) var followers: [FamilyConnection] = []
    @Published private(set) var following: [FamilyConnection] = []
    @Published private(set) var alerts: [CareAlert] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isGeneratingCode = false
    @Published private(set) var isRedeemingCode = false
    @Published private(set) var isDeletingAlerts = false
    @Published private(set) var isGuestSession = false
    @Published private(set) var currentUserName = ""
    @Published var errorMessage: String?
    @Published var successMessage: String?

    private let familyStore: FamilyStore
    private var currentProfile: UserProfile?

    init(familyStore: FamilyStore = FamilyStore()) {
        self.familyStore = familyStore
    }

    var summary: FamilySummary {
        FamilySummary(
            shareCode: shareCode,
            followerCount: followers.count,
            followingCount: following.count,
            overdueAlertCount: alerts.filter { $0.resolvedAt == nil }.count,
            isGuestSession: isGuestSession
        )
    }

    func load(activeUser: LocalUser?) async {
        errorMessage = nil
        successMessage = nil

        guard let activeUser else {
            return
        }

        isGuestSession = activeUser.isGuest
        guard !activeUser.isGuest else {
            currentUserName = L10n.string("common.guest")
            shareCode = nil
            followers = []
            following = []
            alerts = []
            currentProfile = nil
            return
        }

        isLoading = true

        do {
            let profile = try await resolveCurrentProfile(userId: activeUser.userId)

            currentProfile = profile
            currentUserName = profile.name

            let invite = try await familyStore.fetchActiveInviteCode(ownerId: activeUser.userId)
            let connections = try await familyStore.fetchConnections(for: activeUser.userId)
            let recentAlerts = try await familyStore.fetchRecentAlerts(for: activeUser.userId)

            shareCode = invite?.code
            followers = connections.filter { $0.direction == .caregiverForCurrentUser }
            following = connections.filter { $0.direction == .patientForCurrentUser }
            alerts = recentAlerts
                .filter { $0.resolvedAt == nil }
                .sorted { $0.scheduledTime > $1.scheduledTime }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func generateInviteCode() async {
        guard let currentProfile else {
            errorMessage = FamilyStoreError.profileNotFound.localizedDescription
            return
        }

        isGeneratingCode = true
        errorMessage = nil
        successMessage = nil

        do {
            let invite = try await familyStore.generateInviteCode(for: currentProfile)
            shareCode = invite.code
            successMessage = L10n.string("family.code_ready_to_share")
        } catch {
            errorMessage = error.localizedDescription
        }

        isGeneratingCode = false
    }

    func redeemInviteCode(activeUser: LocalUser?) async {
        guard let activeUser, !activeUser.isGuest else {
            errorMessage = L10n.string("family.guest_cannot_match")
            return
        }

        let normalizedCode = FamilyStore.normalizeInviteCode(inviteCodeInput)
        guard !normalizedCode.isEmpty else {
            errorMessage = L10n.string("family.enter_invite_code")
            return
        }

        guard let currentProfile else {
            errorMessage = FamilyStoreError.profileNotFound.localizedDescription
            return
        }

        isRedeemingCode = true
        errorMessage = nil
        successMessage = nil

        do {
            let profile = try await familyStore.redeemInviteCode(normalizedCode, caregiver: currentProfile)
            inviteCodeInput = ""
            await load(activeUser: activeUser)
            successMessage = L10n.format("family.tracking_enabled_for", profile.name)
        } catch {
            errorMessage = error.localizedDescription
        }

        isRedeemingCode = false
    }

    func copyInviteCode() {
        guard let shareCode else { return }
        UIPasteboard.general.string = shareCode
        successMessage = L10n.string("family.code_copied")
    }

    func removeAlert(_ alert: CareAlert) async {
        guard let alertId = alert.id else { return }

        isDeletingAlerts = true
        errorMessage = nil

        do {
            try await familyStore.removeAlert(alertId: alertId)
            alerts.removeAll { $0.id == alert.id }
            successMessage = L10n.string("family.alert_removed")
        } catch {
            errorMessage = error.localizedDescription
        }

        isDeletingAlerts = false
    }

    func clearAllAlerts() async {
        let alertIds = alerts.compactMap(\.id)
        guard !alertIds.isEmpty else { return }

        isDeletingAlerts = true
        errorMessage = nil

        do {
            try await familyStore.removeAlerts(alertIds: alertIds)
            alerts = []
            successMessage = L10n.string("family.all_alerts_cleared")
        } catch {
            errorMessage = error.localizedDescription
        }

        isDeletingAlerts = false
    }

    func syncOverdueAlerts(activeUser: LocalUser?, doses: [OverdueDosePayload]) async {
        guard let activeUser, !activeUser.isGuest else { return }
        guard !doses.isEmpty else { return }

        do {
            let profile = try await resolveCurrentProfile(userId: activeUser.userId)

            currentProfile = profile
            try await familyStore.syncOverdueAlerts(patient: profile, doses: doses)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func resolveCurrentProfile(userId: String) async throws -> UserProfile {
        if let currentProfile, currentProfile.id == userId {
            return currentProfile
        }

        if let profile = await familyStore.fetchUserProfile(userId: userId) {
            return profile
        }

        guard let firebaseUser = Auth.auth().currentUser, firebaseUser.uid == userId else {
            throw FamilyStoreError.profileNotFound
        }

        return try await familyStore.ensureUserProfile(
            userId: userId,
            name: firebaseUser.displayName ?? "",
            email: firebaseUser.email ?? ""
        )
    }
}
