//
//  AppTheme.swift
//  Medicine Reminder
//
//  Created by Codex on 25.03.2026.
//

import SwiftUI

enum AppTheme {
    static let backgroundTop = Color(red: 0.94, green: 0.98, blue: 0.97)
    static let backgroundBottom = Color(red: 0.87, green: 0.95, blue: 0.93)

    static let primary = Color(red: 0.08, green: 0.48, blue: 0.46)
    static let primarySoft = Color(red: 0.62, green: 0.84, blue: 0.80)
    static let accent = Color(red: 0.98, green: 0.73, blue: 0.35)

    static let surface = Color.white
    static let surfaceMuted = Color(red: 0.93, green: 0.97, blue: 0.96)

    static let textPrimary = Color(red: 0.11, green: 0.17, blue: 0.18)
    static let textSecondary = Color(red: 0.36, green: 0.46, blue: 0.47)
    static let border = Color(red: 0.80, green: 0.89, blue: 0.87)
    static let success = Color(red: 0.22, green: 0.65, blue: 0.44)
    static let danger = Color(red: 0.83, green: 0.37, blue: 0.34)

    static let appBackground = LinearGradient(
        colors: [backgroundTop, backgroundBottom],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let heroGradient = LinearGradient(
        colors: [primary, primarySoft],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
