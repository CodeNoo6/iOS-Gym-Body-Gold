//
//  ContentView.swift
//  gymadministrator
//
//  Created by Ruben Camargo on 24/07/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var authManager = AuthManager()
    @StateObject private var onboardingManager = OnboardingManager()
    
    var body: some View {
        Group {
            if authManager.isLoading {
                LoadingView()
            } else if onboardingManager.showOnboarding {
                // Onboarding/Splash Screens
                OnboardingView()
                    .environmentObject(onboardingManager)
            } else if authManager.isAuthenticated {
                MainTabView()
                    .environmentObject(authManager)
            } else {
                // Pantalla de login
                LoginView()
                    .environmentObject(authManager)
            }
        }
        .animation(.easeInOut(duration: 0.5), value: authManager.isLoading)
        .animation(.easeInOut(duration: 0.5), value: onboardingManager.showOnboarding)
        .animation(.easeInOut(duration: 0.3), value: authManager.isAuthenticated)
    }
}

struct LoadingView: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            LinearGradient.brandDark
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                // Logo con animación
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.brandGold)
                    .scaleEffect(isAnimating ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isAnimating)
                
                Text("Gym Body Gold")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.brandLight)
                
                // Indicador de carga personalizado
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .brandGold))
                    .scaleEffect(1.2)
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}

#Preview {
    ContentView()
}
