//
//  AppNavigatorView.swift
//  Medicine Reminder
//
//  Created by Codex on 27.03.2026.
//

import SwiftUI

struct AppNavigatorView: View {
    @StateObject private var router = AppRouter()
    @StateObject private var notificationRouteStore = NotificationRouteStore.shared
    let sessionDisplayName: String

    var body: some View {
        NavigationStack(path: $router.path) {
            HomeView(sessionDisplayName: sessionDisplayName)
                .navigationDestination(for: AppRoute.self) { route in
                    switch route {
                    case .addMedication:
                        AddMedicationView()
                    case .allMedications:
                        AllMedicationsView()
                    }
                }
        }
        .environmentObject(router)
        .environmentObject(notificationRouteStore)
        .sheet(
            item: Binding(
                get: { notificationRouteStore.pendingDoseTarget },
                set: { newValue in
                    if let newValue {
                        notificationRouteStore.pendingDoseTarget = newValue
                    } else {
                        notificationRouteStore.clear()
                    }
                }
            )
        ) { target in
            DoseConfirmationSheet(logId: target.logId)
        }
    }
}

#Preview {
    AppNavigatorView(sessionDisplayName: "Guest")
}
