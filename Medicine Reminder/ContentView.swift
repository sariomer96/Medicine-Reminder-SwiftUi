//
//  ContentView.swift
//  Medicine Reminder
//
//  Created by Omer on 25.03.2026.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        if #available(iOS 16.0, *) {
            TabView {
                OnboardingView()
                    .tabItem {
                        Label("Welcome", systemImage: "sparkles")
                    }
                
            }
            .toolbarBackground(AppTheme.surface, for: .tabBar)
        } else {
            // Fallback on earlier versions
        }
    }
}

#Preview {
    ContentView()
}
