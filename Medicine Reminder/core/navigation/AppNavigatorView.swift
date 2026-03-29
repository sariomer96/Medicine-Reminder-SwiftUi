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
    let onSessionEnded: () -> Void

    var body: some View {
        NavigationView {
            ZStack {
                HomeView(
                    sessionDisplayName: sessionDisplayName,
                    onSessionEnded: onSessionEnded
                )

                NavigationLink(
                    destination: AddMedicationView(),
                    tag: .addMedication,
                    selection: $router.activeRoute
                ) {
                    EmptyView()
                }
                .hidden()

                NavigationLink(
                    destination: AllMedicationsView(),
                    tag: .allMedications,
                    selection: $router.activeRoute
                ) {
                    EmptyView()
                }
                .hidden()

                NavigationLink(
                    destination: FamilyView(),
                    tag: .familyHub,
                    selection: $router.activeRoute
                ) {
                    EmptyView()
                }
                .hidden()
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
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
    AppNavigatorView(sessionDisplayName: "Guest", onSessionEnded: {})
}
