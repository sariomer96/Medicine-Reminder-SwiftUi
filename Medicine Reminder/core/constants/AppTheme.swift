//
//  AppTheme.swift
//  Medicine Reminder
//
//  Created by Codex on 25.03.2026.
//

import SwiftUI

enum AppTheme {
    static let backgroundTop = Color(hex: "#F0FAF7")
    static let backgroundBottom = Color(hex: "#DEF2ED")

    static let primary = Color(hex: "#147A75")
    static let primarySoft = Color(hex: "#9ED6CC")
    static let accent = Color(hex: "#FABA59")

    static let surface = Color(hex: "#FFFFFF")
    static let surfaceMuted = Color(hex: "#EDF7F58A")

    static let textPrimary = Color(hex: "#1C2B2E")
    static let textSecondary = Color(hex: "#5C7578")
    static let border = Color(hex: "#CCE3DE")
    static let success = Color(hex: "#38A670")
    static let danger = Color(hex: "#D45E57")

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
