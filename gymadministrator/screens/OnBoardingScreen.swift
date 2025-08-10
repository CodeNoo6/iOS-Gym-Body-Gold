//
//  OnBoardingScreen.swift
//  gymadministrator
//
//  Created by Ruben Camargo on 9/08/25.
//

import Foundation
import SwiftUI

// MARK: - OnboardingManager
@MainActor
class OnboardingManager: ObservableObject {
    @Published var showOnboarding = true
    @Published var currentPage = 0
    
    private let userDefaults = UserDefaults.standard
    private let hasSeenOnboardingKey = "hasSeenOnboarding"
    
    let onboardingPages = [
            OnboardingPage(
                title: "Bienvenido a Gym Body Gold",
                subtitle: "Entrena como nunca antes",
                icon: "bodyGoldLogo",
                description: "Clases exclusivas y todo lo que necesitas para alcanzar tus objetivos.",
                color: .brandGold
            ),
            OnboardingPage(
                   title: "Clases Grupales y Más",
                   subtitle: "Actívate con buena energía",
                   icon: "person.3.fill",
                   description: "Zumba, funcional, spinning, y muchas más.",
                   color: .brandAccent
               ),
            OnboardingPage(
                    title: "Planes a Tu Medida",
                    subtitle: "Tú decides cómo y cuándo",
                    icon: "creditcard.fill",
                    description: "Elige entre planes mensuales, semanales o por clase.",
                    color: .brandGold
                ),
            OnboardingPage(
                    title: "Entrenamiento Personalizado",
                    subtitle: "Rutinas diseñadas para ti",
                    icon: "figure.walk.circle.fill",
                    description: "Mejora con el acompañamiento de tu coach.",
                    color: .brandLight
                )
        ]
    
    init() {
        checkOnboardingStatus()
    }
    
    private func checkOnboardingStatus() {
        let hasSeenOnboarding = userDefaults.bool(forKey: hasSeenOnboardingKey)
        showOnboarding = !hasSeenOnboarding
    }
    
    func completeOnboarding() {
        withAnimation(.easeOut(duration: 0.5)) {
            showOnboarding = false
        }
        userDefaults.set(true, forKey: hasSeenOnboardingKey)
    }
    
    func nextPage() {
        if currentPage < onboardingPages.count - 1 {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentPage += 1
            }
        }
    }
    
    func previousPage() {
        if currentPage > 0 {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentPage -= 1
            }
        }
    }
    
    func goToPage(_ page: Int) {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentPage = page
        }
    }
    
    // Función para resetear (útil para testing)
    func resetOnboarding() {
        userDefaults.removeObject(forKey: hasSeenOnboardingKey)
        currentPage = 0
        showOnboarding = true
    }
}

// MARK: - OnboardingPage Model
struct OnboardingPage {
    let title: String
    let subtitle: String
    let icon: String
    let description: String
    let color: Color
}

// MARK: - OnboardingView
struct OnboardingView: View {
    @EnvironmentObject var onboardingManager: OnboardingManager
    
    var body: some View {
        ZStack {
            // Background gradient igual al login
            LinearGradient.brandDark
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.5), value: onboardingManager.currentPage)
            
            VStack(spacing: 0) {
                // Skip button con estilo mejorado
                HStack {
                    Spacer()
                    Button("Saltar") {
                        onboardingManager.completeOnboarding()
                    }
                    .foregroundColor(.brandLight)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.brandWhite.opacity(0.1))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.brandGold.opacity(0.3), lineWidth: 1)
                    )
                    .padding()
                }
                
                // Content area
                TabView(selection: $onboardingManager.currentPage) {
                    ForEach(0..<onboardingManager.onboardingPages.count, id: \.self) { index in
                        OnboardingPageView(page: onboardingManager.onboardingPages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .animation(.easeInOut, value: onboardingManager.currentPage)
                
                // Bottom controls con estilo matching login
                VStack(spacing: 30) {
                    // Page indicators mejorados
                    HStack(spacing: 12) {
                        ForEach(0..<onboardingManager.onboardingPages.count, id: \.self) { index in
                            RoundedRectangle(cornerRadius: 4)
                                .fill(index == onboardingManager.currentPage ? Color.brandGold : Color.brandLight.opacity(0.4))
                                .frame(width: index == onboardingManager.currentPage ? 24 : 8, height: 8)
                                .animation(.spring(response: 0.3), value: onboardingManager.currentPage)
                                .onTapGesture {
                                    onboardingManager.goToPage(index)
                                }
                        }
                    }
                    
                    // Navigation buttons con estilo del login
                    HStack(spacing: 16) {
                        // Previous button
                        if onboardingManager.currentPage > 0 {
                            Button(action: {
                                onboardingManager.previousPage()
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "chevron.left")
                                    Text("Anterior")
                                }
                                .foregroundColor(.brandLight)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 25)
                                        .fill(Color.brandWhite.opacity(0.1))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 25)
                                        .stroke(Color.brandGold.opacity(0.3), lineWidth: 1)
                                )
                            }
                            .transition(.opacity.combined(with: .scale))
                        }
                        
                        Spacer()
                        
                        // Next/Get Started button
                        Button(action: {
                            if onboardingManager.currentPage == onboardingManager.onboardingPages.count - 1 {
                                onboardingManager.completeOnboarding()
                            } else {
                                onboardingManager.nextPage()
                            }
                        }) {
                            HStack(spacing: 8) {
                                Text(onboardingManager.currentPage == onboardingManager.onboardingPages.count - 1 ? "Comenzar" : "Siguiente")
                                    .fontWeight(.semibold)
                                if onboardingManager.currentPage < onboardingManager.onboardingPages.count - 1 {
                                    Image(systemName: "chevron.right")
                                } else {
                                    Image(systemName: "arrow.right.circle.fill")
                                }
                            }
                            .foregroundColor(.brandBlack)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(
                                LinearGradient.brandPrimary
                                    .clipShape(RoundedRectangle(cornerRadius: 25))
                            )
                        }
                        .scaleEffect(onboardingManager.currentPage == onboardingManager.onboardingPages.count - 1 ? 1.05 : 1.0)
                        .animation(.spring(), value: onboardingManager.currentPage)
                    }
                    .padding(.horizontal, 30)
                }
                .padding(.bottom, 50)
            }
        }
        .gesture(
            DragGesture()
                .onEnded { gesture in
                    let translation = gesture.translation
                    if translation.width > 50 {
                        onboardingManager.previousPage()
                    } else if translation.width < -50 {
                        if onboardingManager.currentPage == onboardingManager.onboardingPages.count - 1 {
                            onboardingManager.completeOnboarding()
                        } else {
                            onboardingManager.nextPage()
                        }
                    }
                }
        )
    }
    
    private var currentPage: OnboardingPage {
        onboardingManager.onboardingPages[onboardingManager.currentPage]
    }
}

// MARK: - OnboardingPageView
struct OnboardingPageView: View {
    let page: OnboardingPage
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // Icon - Logo personalizado para la primera página con glow effect
            if page.icon == "bodyGoldLogo" {
                ZStack {
                    // Glow effect
                    Image("bodyGoldLogo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 120, height: 120)
                        .brandGlow()
                    
                    // Logo principal
                    Image("bodyGoldLogo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 120, height: 120)
                }
                .scaleEffect(1.05)
            } else {
                Image(systemName: page.icon)
                    .font(.system(size: 100))
                    .foregroundColor(page.color)
                    .brandGlow()
            }
            
            // Content con mejores colores
            VStack(spacing: 20) {
                Text(page.title)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.brandWhite)
                    .multilineTextAlignment(.center)
                
                Text(page.subtitle)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(page.color)
                    .multilineTextAlignment(.center)
                
                Text(page.description)
                    .font(.body)
                    .foregroundColor(.brandLight.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
                    .lineLimit(nil)
            }
            
            Spacer()
        }
        .padding()
    }
}
