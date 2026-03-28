//
//  View+Compatibility.swift
//  Medicine Reminder
//
//  Created by Codex on 28.03.2026.
//

import SwiftUI

extension View {
    @ViewBuilder
    func appSheetPresentation() -> some View {
        if #available(iOS 16.4, *) {
            self
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
        } else if #available(iOS 16.0, *) {
            self
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        } else {
            self
        }
    }

    @ViewBuilder
    func hiddenNavigationBarCompat() -> some View {
        if #available(iOS 16.0, *) {
            self.toolbar(.hidden, for: .navigationBar)
        } else {
            self.navigationBarHidden(true)
        }
    }
}
