//
//  ContentView.swift
//  gymadministrator
//
//  Created by Ruben Camargo on 24/07/25.
//

import SwiftUI
import FirebaseCore
import FirebaseAuth
import Firebase


struct ContentView: View {
    @StateObject private var authManager = AuthManager()
    @StateObject private var onboardingManager = OnboardingManager()
    
    var body: some View {
        Group {
            if onboardingManager.showOnboarding {
                // Onboarding/Splash Screens
                OnboardingView()
                    .environmentObject(onboardingManager)
            } else if authManager.isAuthenticated {
                // Panel de administración del gym
                AdminDashboard()
                    .environmentObject(authManager)
            } else {
                // Pantalla de login
                LoginView()
                    .environmentObject(authManager)
            }
        }
        .animation(.easeInOut(duration: 0.5), value: onboardingManager.showOnboarding)
        .animation(.easeInOut(duration: 0.3), value: authManager.isAuthenticated)
    }
}

#Preview {
    ContentView()
}

