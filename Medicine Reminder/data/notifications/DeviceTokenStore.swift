//
//  DeviceTokenStore.swift
//  Medicine Reminder
//
//  Created by Codex on 29.03.2026.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

import FirebaseMessaging
import UIKit

final class DeviceTokenStore {
    static let shared = DeviceTokenStore()

    private let db = Firestore.firestore()
    private let collectionName = "deviceTokens"

    private init() {}

    func syncCurrentDeviceTokenIfPossible() async {
        guard let user = Auth.auth().currentUser else {
            return
        }

        do {
            let token = try await Messaging.messaging().token()
            try await upsertToken(
                userId: user.uid,
                fcmToken: token
            )
        } catch {
            print("DeviceTokenStore.syncCurrentDeviceTokenIfPossible failed: \(error.localizedDescription)")
        }
    }

    func handleTokenRefresh(_ token: String) async {
        guard let user = Auth.auth().currentUser else {
            return
        }

        do {
            try await upsertToken(userId: user.uid, fcmToken: token)
        } catch {
            print("DeviceTokenStore.handleTokenRefresh failed: \(error.localizedDescription)")
        }
    }

    func removeCurrentDeviceToken(for userId: String) async {
        let documentId = makeDocumentId(userId: userId)

        do {
            try await db.collection(collectionName)
                .document(documentId)
                .delete()
        } catch {
            print("DeviceTokenStore.removeCurrentDeviceToken failed: \(error.localizedDescription)")
        }
    }

    private func upsertToken(userId: String, fcmToken: String) async throws {
        let payload = DeviceTokenPayload(
            userId: userId,
            deviceId: currentDeviceId,
            fcmToken: fcmToken,
            platform: "ios",
            updatedAt: Date()
        )

        try db.collection(collectionName)
            .document(makeDocumentId(userId: userId))
            .setData(from: payload, merge: true)
    }

    private var currentDeviceId: String {
        UIDevice.current.identifierForVendor?.uuidString ?? "unknown-device"
    }

    private func makeDocumentId(userId: String) -> String {
        "\(userId)_\(currentDeviceId)"
    }
}

private struct DeviceTokenPayload: Encodable {
    let userId: String
    let deviceId: String
    let fcmToken: String
    let platform: String
    let updatedAt: Date
}
