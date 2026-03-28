//
//  AppRouter.swift
//  Medicine Reminder
//
//  Created by Codex on 27.03.2026.
//

import SwiftUI

@MainActor
final class AppRouter: ObservableObject {
    @Published var activeRoute: AppRoute?

    func push(_ route: AppRoute) {
        activeRoute = route
    }

    func popToRoot() {
        activeRoute = nil
    }
}
