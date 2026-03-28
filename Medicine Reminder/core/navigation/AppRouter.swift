//
//  AppRouter.swift
//  Medicine Reminder
//
//  Created by Codex on 27.03.2026.
//

import SwiftUI

@MainActor
final class AppRouter: ObservableObject {
    @Published var path = NavigationPath()

    func push(_ route: AppRoute) {
        path.append(route)
    }

    func popToRoot() {
        path = NavigationPath()
    }
}
