//
//  FamilyStore.swift
//  Medicine Reminder
//
//  Created by Codex on 28.03.2026.
//

import Foundation
import FirebaseFirestore
import FirebaseFunctions



enum FamilyStoreError: LocalizedError {
    case profileNotFound
    case inviteCodeNotFound
    case cannotLinkToSelf
    case invalidUser

    var errorDescription: String? {
        switch self {
        case .profileNotFound:
            return L10n.string("family.error_profile_not_found")
        case .inviteCodeNotFound:
            return L10n.string("family.error_invite_code_not_found")
        case .cannotLinkToSelf:
            return L10n.string("family.error_cannot_link_to_self")
        case .invalidUser:
            return L10n.string("family.error_invalid_user")
        }
    }
}

struct FamilyConnection: Identifiable {
    enum Direction: Equatable {
        case caregiverForCurrentUser
        case patientForCurrentUser
    }

    let relationship: Relationship
    let counterpart: UserProfile
    let direction: Direction

    var id: String {
        relationship.id ?? "\(relationship.caregiverId)-\(relationship.patientId)"
    }
}

struct OverdueDosePayload: Identifiable {
    let logId: String
    let medicationName: String
    let dosage: String
    let scheduledTime: Date

    var id: String {
        logId
    }
}

final class FamilyStore {
    private let db = Firestore.firestore()
    private let functions = Functions.functions(region: "europe-west1")
    private let userStore: UserStore

    private let inviteCollection = "familyInviteCodes"
    private let relationshipCollection = "relationships"
    private let alertCollection = "careAlerts"

    init(userStore: UserStore = UserStore()) {
        self.userStore = userStore
    }

    func fetchUserProfile(userId: String) async -> UserProfile? {
        await userStore.fetchUser(userId: userId)
    }

    func ensureUserProfile(userId: String, name: String, email: String) async throws -> UserProfile {
        try await userStore.upsertUser(userId: userId, name: name, email: email)
    }

    func fetchActiveInviteCode(ownerId: String) async throws -> FamilyInviteCode? {
        let snapshot = try await db.collection(inviteCollection)
            .document(ownerId)
            .getDocument()

        guard snapshot.exists else {
            return nil
        }

        let invite = try snapshot.data(as: FamilyInviteCode.self)
        return invite.isActive ? invite : nil
    }

    func generateInviteCode(for owner: UserProfile) async throws -> FamilyInviteCode {
        guard let ownerId = owner.id else {
            throw FamilyStoreError.invalidUser
        }

        let now = Date()
        let invite = FamilyInviteCode(
            id: ownerId,
            ownerId: ownerId,
            ownerName: owner.name,
            code: Self.makeInviteCode(),
            createdAt: now,
            updatedAt: now,
            isActive: true
        )

        try db.collection(inviteCollection)
            .document(ownerId)
            .setData(from: invite)

        return invite
    }

    func redeemInviteCode(_ rawCode: String, caregiver: UserProfile) async throws -> UserProfile {
        guard let caregiverId = caregiver.id else {
            throw FamilyStoreError.invalidUser
        }

        let normalizedCode = Self.normalizeInviteCode(rawCode)
        let snapshot = try await db.collection(inviteCollection)
            .whereField("code", isEqualTo: normalizedCode)
            .limit(to: 1)
            .getDocuments()

        guard let inviteDocument = snapshot.documents.first else {
            throw FamilyStoreError.inviteCodeNotFound
        }

        let invite = try inviteDocument.data(as: FamilyInviteCode.self)
        guard invite.isActive else {
            throw FamilyStoreError.inviteCodeNotFound
        }
        guard invite.ownerId != caregiverId else {
            throw FamilyStoreError.cannotLinkToSelf
        }

        let patientProfile = await userStore.fetchUser(userId: invite.ownerId) ?? UserProfile(
            id: invite.ownerId,
            name: invite.ownerName,
            email: ""
        )

        let documentId = relationshipDocumentId(patientId: invite.ownerId, caregiverId: caregiverId)
        let reference = db.collection(relationshipCollection).document(documentId)
        let relationship = Relationship(
            id: documentId,
            caregiverId: caregiverId,
            patientId: invite.ownerId,
            status: .accepted,
            createdAt: Date(),
            updatedAt: Date(),
            version: 1,
            lastActionBy: caregiverId
        )
        try reference.setData(from: relationship, merge: true)

        return patientProfile
    }

    func fetchConnections(for userId: String) async throws -> [FamilyConnection] {
        async let caregiverQuery = db.collection(relationshipCollection)
            .whereField("caregiverId", isEqualTo: userId)
            .getDocuments()

        async let patientQuery = db.collection(relationshipCollection)
            .whereField("patientId", isEqualTo: userId)
            .getDocuments()

        let (caregiverSnapshot, patientSnapshot) = try await (caregiverQuery, patientQuery)

        var connections: [FamilyConnection] = []

        for document in caregiverSnapshot.documents {
            let relationship = try document.data(as: Relationship.self)
            guard relationship.status == .accepted else {
                continue
            }

            let profile: UserProfile?
            if let fetchedProfile = await userStore.fetchUser(userId: relationship.patientId) {
                profile = fetchedProfile
            } else {
                profile = await fallbackInviteProfile(ownerId: relationship.patientId)
            }
            guard let profile else { continue }

            connections.append(
                FamilyConnection(
                    relationship: relationship,
                    counterpart: profile,
                    direction: .patientForCurrentUser
                )
            )
        }

        for document in patientSnapshot.documents {
            let relationship = try document.data(as: Relationship.self)
            guard relationship.status == .accepted else {
                continue
            }

            let profile: UserProfile?
            if let fetchedProfile = await userStore.fetchUser(userId: relationship.caregiverId) {
                profile = fetchedProfile
            } else {
                profile = await fallbackInviteProfile(ownerId: relationship.caregiverId)
            }
            guard let profile else { continue }

            connections.append(
                FamilyConnection(
                    relationship: relationship,
                    counterpart: profile,
                    direction: .caregiverForCurrentUser
                )
            )
        }

        return connections.sorted {
            $0.counterpart.name.localizedCaseInsensitiveCompare($1.counterpart.name) == .orderedAscending
        }
    }

    func fetchRecentAlerts(for caregiverId: String) async throws -> [CareAlert] {
        let snapshot = try await db.collection(alertCollection)
            .whereField("caregiverId", isEqualTo: caregiverId)
            .limit(to: 30)
            .getDocuments()

        return try snapshot.documents.compactMap { document in
            try document.data(as: CareAlert.self)
        }
        .sorted { $0.createdAt > $1.createdAt }
    }

    func syncOverdueAlerts(patient: UserProfile, doses: [OverdueDosePayload]) async throws {
        guard let patientId = patient.id else {
            throw FamilyStoreError.invalidUser
        }

        let caregivers = try await fetchAcceptedCaregivers(for: patientId)
        guard !caregivers.isEmpty, !doses.isEmpty else {
            return
        }

        let batch = db.batch()

        for caregiver in caregivers {
            guard let caregiverId = caregiver.id else { continue }

            for dose in doses {
                let documentId = alertDocumentId(caregiverId: caregiverId, logId: dose.logId)
                let reference = db.collection(alertCollection).document(documentId)
                let alert = CareAlert(
                    id: documentId,
                    caregiverId: caregiverId,
                    patientId: patientId,
                    patientName: patient.name,
                    medicationName: dose.medicationName,
                    dosage: dose.dosage,
                    logId: dose.logId,
                    scheduledTime: dose.scheduledTime
                )

                try batch.setData(from: alert, forDocument: reference, merge: true)
            }
        }

        try await batch.commit()
    }

    func markAlertsDelivered(_ alertIds: [String]) async throws {
        guard !alertIds.isEmpty else { return }

        let batch = db.batch()
        let now = Date()

        for alertId in alertIds {
            let reference = db.collection(alertCollection).document(alertId)
            batch.updateData(["deliveredAt": Timestamp(date: now)], forDocument: reference)
        }

        try await batch.commit()
    }

    func resolveAlerts(for logId: String) async throws {
        let snapshot = try await db.collection(alertCollection)
            .whereField("logId", isEqualTo: logId)
            .getDocuments()

        guard !snapshot.documents.isEmpty else { return }

        let batch = db.batch()
        let now = Date()

        for document in snapshot.documents {
            batch.updateData(["resolvedAt": Timestamp(date: now)], forDocument: document.reference)
        }

        try await batch.commit()
    }

    func removeAlert(alertId: String) async throws {
        try await deleteCareAlerts(alertIds: [alertId])
    }

    func removeAlerts(alertIds: [String]) async throws {
        try await deleteCareAlerts(alertIds: alertIds)
    }

    private func fetchAcceptedCaregivers(for patientId: String) async throws -> [UserProfile] {
        let snapshot = try await db.collection(relationshipCollection)
            .whereField("patientId", isEqualTo: patientId)
            .getDocuments()

        var caregivers: [UserProfile] = []

        for document in snapshot.documents {
            let relationship = try document.data(as: Relationship.self)
            guard relationship.status == .accepted,
                  let profile = await userStore.fetchUser(userId: relationship.caregiverId) else {
                continue
            }
            caregivers.append(profile)
        }

        return caregivers
    }

    private func fallbackInviteProfile(ownerId: String) async -> UserProfile? {
        guard let invite = try? await fetchActiveInviteCode(ownerId: ownerId) else {
            return nil
        }

        return UserProfile(
            id: ownerId,
            name: invite.ownerName,
            email: ""
        )
    }

    private func relationshipDocumentId(patientId: String, caregiverId: String) -> String {
        "\(patientId)_\(caregiverId)"
    }

    private func alertDocumentId(caregiverId: String, logId: String) -> String {
        "\(caregiverId)_\(logId)"
    }

    private func deleteCareAlerts(alertIds: [String]) async throws {
        let normalizedAlertIds = Array(
            Set(
                alertIds
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            )
        )

        guard !normalizedAlertIds.isEmpty else { return }

        _ = try await functions
            .httpsCallable("deleteCareAlerts")
            .call(["alertIds": normalizedAlertIds])
    }

    private static func makeInviteCode() -> String {
        let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        let raw = String((0..<8).compactMap { _ in alphabet.randomElement() })
        let prefix = raw.prefix(4)
        let suffix = raw.suffix(4)
        return "\(prefix)-\(suffix)"
    }

    static func normalizeInviteCode(_ value: String) -> String {
        let uppercased = value.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let compact = uppercased.replacingOccurrences(of: "-", with: "")

        guard compact.count == 8 else {
            return uppercased
        }

        let prefix = compact.prefix(4)
        let suffix = compact.suffix(4)
        return "\(prefix)-\(suffix)"
    }
}
