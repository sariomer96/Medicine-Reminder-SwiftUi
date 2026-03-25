//
//  Color+Hex.swift
//  Medicine Reminder
//
//  Created by Codex on 25.03.2026.
//

import SwiftUI

extension Color {
    init(hex: String) {
        let sanitizedHex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: sanitizedHex).scanHexInt64(&int)

        let red, green, blue, alpha: UInt64

        switch sanitizedHex.count {
        case 6:
            red = (int >> 16) & 0xFF
            green = (int >> 8) & 0xFF
            blue = int & 0xFF
            alpha = 0xFF
        case 8:
            red = (int >> 24) & 0xFF
            green = (int >> 16) & 0xFF
            blue = (int >> 8) & 0xFF
            alpha = int & 0xFF
        default:
            red = 0
            green = 0
            blue = 0
            alpha = 0xFF
        }

        self.init(
            .sRGB,
            red: Double(red) / 255,
            green: Double(green) / 255,
            blue: Double(blue) / 255,
            opacity: Double(alpha) / 255
        )
    }
}
