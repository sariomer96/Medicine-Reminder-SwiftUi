//
//  ContentView.swift
//  Medicine Reminder
//
//  Created by Omer on 25.03.2026.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            OnboardingView()
                .tabItem {
                    Label("Welcome", systemImage: "sparkles")
                }

            HomeView()
                .tabItem {
                    Label("Home", systemImage: "pills")
                }
        }
        .toolbarBackground(AppTheme.surface, for: .tabBar)
    }
}

#Preview {
    ContentView()
}
