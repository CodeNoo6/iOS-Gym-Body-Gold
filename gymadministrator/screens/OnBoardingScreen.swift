//
//  OnBoardingScreen.swift
//  gymadministrator
//
//  Created by Ruben Camargo on 9/08/25.
//

import Foundation
import SwiftUI

struct FeatureRowOptimized: View {
    let icon: String
    let text: String
    
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    var body: some View {
        HStack(spacing: iconSpacing) {
            Image(systemName: icon)
                .foregroundColor(.brandGold)
                .font(.system(size: iconSize))
                .frame(width: iconFrameWidth)
            
            Text(text)
                .font(.system(size: fontSize, weight: .medium))
                .foregroundColor(.brandLight.opacity(0.9))
                .multilineTextAlignment(.leading)
                .lineLimit(2)
            
            Spacer()
        }
        .frame(minHeight: rowHeight)
    }
    
    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }
    
    private var iconSpacing: CGFloat {
        isIPad ? 16 : 12
    }
    
    private var iconSize: CGFloat {
        isIPad ? 20 : 16
    }
    
    private var iconFrameWidth: CGFloat {
        isIPad ? 26 : 20
    }
    
    private var fontSize: CGFloat {
        isIPad ? 18 : 14
    }
    
    private var rowHeight: CGFloat {
        isIPad ? 32 : 24
    }
}

// MARK: - OnboardingManager
// MARK: - OnboardingManager
@MainActor
class OnboardingManager: ObservableObject {
    @Published var showOnboarding = true
    @Published var currentPage = 0
    
    private let userDefaults = UserDefaults.standard
    private let hasSeenOnboardingKey = "hasSeenOnboarding"
    
    let onboardingPages = [
        OnboardingPage(
            title: "Bienvenido a The Brother's Gym",
            subtitle: "Entrena como nunca antes",
            icon: "bodyGoldLogo",
            description: "Clases exclusivas y todo lo que necesitas para alcanzar tus objetivos.",
            color: .brandGold,
            isSpecial: true
        ),
        OnboardingPage(
            title: "Conoce a Gymius",
            subtitle: "Tu asistente personal con IA",
            icon: "brain.head.profile",
            description: "",
            color: .brandAccent,
            isAI: true
        ),
        OnboardingPage(
            title: "Clases Grupales y Más",
            subtitle: "Actívate con buena energía",
            icon: "person.3.fill",
            description: "Zumba, funcional, spinning, y muchas más actividades grupales.",
            color: .brandLight
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
            description: "Mejora con el acompañamiento de tu coach y la guía de Gymius.",
            color: .brandAccent
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
    var isSpecial: Bool = false
    var isAI: Bool = false
}

struct FeatureRowUniform: View {
    let icon: String
    let text: String
    
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    var body: some View {
        HStack(spacing: iconSpacing) {
            Image(systemName: icon)
                .foregroundColor(.brandGold)
                .font(.system(size: iconSize))
                .frame(width: iconFrameWidth)
            
            Text(text)
                .font(.system(size: fontSize, weight: .medium))
                .foregroundColor(.brandLight.opacity(0.9))
                .multilineTextAlignment(.leading)
                .lineLimit(1) // Una sola línea para uniformidad
            
            Spacer()
        }
        .frame(height: rowHeight) // ALTURA FIJA
    }
    
    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }
    
    private var iconSpacing: CGFloat {
        isIPad ? 14 : 12
    }
    
    private var iconSize: CGFloat {
        isIPad ? 18 : 16
    }
    
    private var iconFrameWidth: CGFloat {
        isIPad ? 22 : 20
    }
    
    private var fontSize: CGFloat {
        isIPad ? 16 : 14
    }
    
    private var rowHeight: CGFloat {
        28 // MISMO PARA TODOS
    }
}

// MARK: - OnboardingPageView Mejorado con Diseños Especiales
struct OnboardingPageView: View {
    let page: OnboardingPage
    @State private var isAnimating = false
    @State private var showCTA = false
    @State private var particleAnimation = false
    @State private var ringRotation: Double = 0
    
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    var body: some View {
        VStack(spacing: spacing) {
            Spacer()
            
            // Icon con efectos especiales - MISMO TAMAÑO PARA TODOS
            ZStack {
                if page.isAI {
                    AIGymiusIcon()
                        .scaleEffect(uniformIconScale)
                } else if page.icon == "bodyGoldLogo" {
                    WelcomeLogoDesign(isAnimating: $isAnimating)
                        .scaleEffect(uniformIconScale)
                } else if page.icon == "person.3.fill" {
                    GroupClassesDesign(isAnimating: $isAnimating, particleAnimation: $particleAnimation)
                        .scaleEffect(uniformIconScale)
                } else if page.icon == "creditcard.fill" {
                    PlansDesign(isAnimating: $isAnimating, ringRotation: $ringRotation)
                        .scaleEffect(uniformIconScale)
                } else if page.icon == "figure.walk.circle.fill" {
                    PersonalTrainingDesign(isAnimating: $isAnimating, particleAnimation: $particleAnimation)
                        .scaleEffect(uniformIconScale)
                } else {
                    Image(systemName: page.icon)
                        .font(.system(size: fallbackIconSize))
                        .foregroundColor(page.color)
                        .brandGlow()
                        .scaleEffect(isAnimating ? 1.05 : 1.0)
                        .animation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true), value: isAnimating)
                }
            }
            .frame(height: iconContainerHeight) // ALTURA FIJA PARA TODOS
            
            // Content - MISMO LAYOUT PARA TODOS
            VStack(spacing: textSpacing) {
                Text(page.title)
                    .font(.system(size: titleFontSize, weight: .bold, design: .rounded))
                    .foregroundColor(.brandWhite)
                    .multilineTextAlignment(.center)
                
                if page.isAI {
                    Text(page.subtitle)
                        .font(.system(size: subtitleFontSize, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.brandAccent, .brandGold, .brandAccent],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .multilineTextAlignment(.center)
                } else {
                    Text(page.subtitle)
                        .font(.system(size: subtitleFontSize, weight: .semibold))
                        .foregroundColor(page.color)
                        .multilineTextAlignment(.center)
                }
                
                // Descripción - SIEMPRE LA MISMA ESTRUCTURA
                VStack(spacing: featureSpacing) {
                    if !page.description.isEmpty {
                        Text(page.description)
                            .font(.system(size: descriptionFontSize))
                            .foregroundColor(.brandLight.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, descriptionPadding)
                            .lineLimit(3) // Límite uniforme
                    }
                    
                    // Features - CENTRADAS Y UNIFORMES
                    HStack {
                        if isIPad {
                            Spacer()
                        }
                        
                        VStack(spacing: featureRowSpacing) {
                            if let features = getFeaturesForPage(page) {
                                ForEach(Array(features.enumerated()), id: \.offset) { index, feature in
                                    FeatureRowUniform(icon: feature.icon, text: feature.text)
                                        .opacity(showCTA ? 1.0 : 0.0)
                                        .offset(x: showCTA ? 0 : -30)
                                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3 + Double(index) * 0.15), value: showCTA)
                                }
                            }
                        }
                        .frame(maxWidth: featuresMaxWidth)
                        .frame(minHeight: featuresContainerHeight) // ALTURA MÍNIMA UNIFORME
                        
                        if isIPad {
                            Spacer()
                        }
                    }
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, horizontalPadding)
        .onAppear {
            isAnimating = true
            particleAnimation = true
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showCTA = true
            }
            
            withAnimation(.linear(duration: 15.0).repeatForever(autoreverses: false)) {
                ringRotation = 360
            }
        }
    }
    
    // MARK: - Propiedades UNIFORMES
    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }
    
    // MISMO SCALE PARA TODOS LOS ICONOS
    private var uniformIconScale: CGFloat {
        isIPad ? 1.0 : 1.0 // Sin escala diferente
    }
    
    // ALTURA FIJA PARA CONTENEDOR DE ICONOS
    private var iconContainerHeight: CGFloat {
        isIPad ? 180 : 160
    }
    
    // ALTURA MÍNIMA PARA CONTENEDOR DE FEATURES
    private var featuresContainerHeight: CGFloat {
        isIPad ? 120 : 100
    }
    
    private var titleFontSize: CGFloat {
        isIPad ? 32 : 28
    }
    
    private var subtitleFontSize: CGFloat {
        isIPad ? 20 : 18
    }
    
    private var descriptionFontSize: CGFloat {
        isIPad ? 17 : 16
    }
    
    private var spacing: CGFloat {
        isIPad ? 30 : 40
    }
    
    private var textSpacing: CGFloat {
        isIPad ? 20 : 20
    }
    
    private var featureSpacing: CGFloat {
        isIPad ? 15 : 15
    }
    
    private var featureRowSpacing: CGFloat {
        isIPad ? 10 : 10
    }
    
    private var horizontalPadding: CGFloat {
        isIPad ? 60 : 20
    }
    
    private var descriptionPadding: CGFloat {
        isIPad ? 80 : 30
    }
    
    private var featuresMaxWidth: CGFloat {
        isIPad ? 500 : .infinity
    }
    
    private var fallbackIconSize: CGFloat {
        isIPad ? 100 : 100
    }
    
    // Función para obtener características - INCLUYE GYMIUS
    private func getFeaturesForPage(_ page: OnboardingPage) -> [(icon: String, text: String)]? {
        switch page.title {
        case "Bienvenido a The Brother's Gym":
            return [
                (icon: "star.fill", text: "Equipos de última generación"),
                (icon: "heart.fill", text: "Ambiente motivador"),
                (icon: "trophy.fill", text: "Alcanza tus metas")
            ]
        case "Conoce a Gymius":
            return [
                (icon: "brain.head.profile", text: "Rutinas inteligentes"),
                (icon: "headphones", text: "Soporte 24/7 para tus dudas"),
                (icon: "heart.text.square", text: "Motivación personalizada")
            ]
        case "Clases Grupales y Más":
            return [
                (icon: "music.note", text: "Zumba y bailes"),
                (icon: "dumbbell.fill", text: "Entrenamiento funcional"),
                (icon: "bicycle", text: "Spinning energético")
            ]
        case "Planes a Tu Medida":
            return [
                (icon: "calendar.circle", text: "Planes mensuales"),
                (icon: "clock.circle", text: "Sesiones por hora"),
                (icon: "star.circle", text: "Clases individuales")
            ]
        case "Entrenamiento Personalizado":
            return [
                (icon: "person.crop.circle.badge.checkmark", text: "Coach dedicado"),
                (icon: "chart.line.uptrend.xyaxis", text: "Seguimiento de progreso"),
                (icon: "target", text: "Objetivos personalizados")
            ]
        default:
            return nil
        }
    }
}



// MARK: - Diseño Especial para Logo de Bienvenida
struct WelcomeLogoDesign: View {
    @Binding var isAnimating: Bool
    @State private var glowIntensity: Double = 0.5
    @State private var particleOffset: Double = 0
    
    var body: some View {
        ZStack {
            // Partículas de bienvenida flotantes
            ForEach(0..<8, id: \.self) { index in
                Circle()
                    .fill(Color.brandGold.opacity(0.6))
                    .frame(width: 4, height: 4)
                    .offset(
                        x: cos(particleOffset + Double(index) * .pi / 4) * 120,
                        y: sin(particleOffset + Double(index) * .pi / 4) * 120
                    )
                    .opacity(0.8)
            }
            
            // Anillos de energía
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [.brandGold.opacity(glowIntensity), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
                    .frame(width: CGFloat(185 + index * 15), height: CGFloat(185 + index * 15))
                    .scaleEffect(isAnimating ? 1.05 : 1.0)
                    .opacity(0.6)
            }

            // Logo principal
            ZStack {
                Circle()
                    .fill(Color.black)
                    .frame(width: 170, height: 170)

                Image("bodyGoldLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 170, height: 170)
                    .clipShape(Circle())
                    .brandGlow()

                Image("bodyGoldLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 170, height: 170)
                    .clipShape(Circle())
            }
            .scaleEffect(isAnimating ? 1.05 : 1.0)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                glowIntensity = 1.0
            }
            withAnimation(.linear(duration: 10.0).repeatForever(autoreverses: false)) {
                particleOffset = .pi * 2
            }
        }
    }
}

// MARK: - Diseño para Clases Grupales
struct GroupClassesDesign: View {
    @Binding var isAnimating: Bool
    @Binding var particleAnimation: Bool
    @State private var danceRotation: Double = 0
    @State private var energyPulse: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            // Círculos de energía danzante
            ForEach(0..<6, id: \.self) { index in
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.brandLight.opacity(0.6), .clear],
                            center: .center,
                            startRadius: 5,
                            endRadius: 25
                        )
                    )
                    .frame(width: 30, height: 30)
                    .scaleEffect(energyPulse)
                    .offset(
                        x: cos(danceRotation + Double(index) * .pi / 3) * 80,
                        y: sin(danceRotation + Double(index) * .pi / 3) * 80
                    )
                    .opacity(0.7)
            }
            
            // Marco dinámico
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [.brandLight.opacity(0.4), .brandLight.opacity(0.8), .brandLight.opacity(0.4)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 3
                )
                .frame(width: 140, height: 140)
                .rotationEffect(.degrees(danceRotation * 2))
            
            // Icono principal
            ZStack {
                Image(systemName: "person.3.fill")
                    .font(.system(size: 90))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.brandLight, .brandWhite],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .blur(radius: 8)
                    .scaleEffect(energyPulse)
                
                Image(systemName: "person.3.fill")
                    .font(.system(size: 90))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.brandLight, .brandWhite],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            // Notas musicales flotantes
            ForEach(0..<4, id: \.self) { index in
                Image(systemName: "music.note")
                    .font(.system(size: 16))
                    .foregroundColor(.brandGold)
                    .offset(
                        x: cos(danceRotation * 3 + Double(index) * .pi / 2) * 110,
                        y: sin(danceRotation * 3 + Double(index) * .pi / 2) * 110
                    )
                    .opacity(0.8)
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 8.0).repeatForever(autoreverses: false)) {
                danceRotation = .pi * 2
            }
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                energyPulse = 1.2
            }
        }
    }
}

// MARK: - Diseño para Planes
struct PlansDesign: View {
    @Binding var isAnimating: Bool
    @Binding var ringRotation: Double
    @State private var cardFloat: Double = 0
    @State private var priceGlow: Double = 0.3
    
    var body: some View {
        ZStack {
            // Anillos de valor
            ForEach(0..<3, id: \.self) { index in
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        LinearGradient(
                            colors: [.brandGold.opacity(0.6), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
                    .frame(width: CGFloat(130 + index * 20), height: CGFloat(100 + index * 15))
                    .rotationEffect(.degrees(ringRotation + Double(index * 45)))
                    .opacity(0.6)
            }
            
            // Tarjetas flotantes
            ForEach(0..<3, id: \.self) { index in
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.brandGold.opacity(priceGlow))
                    .frame(width: 20, height: 28)
                    .offset(
                        x: cos(cardFloat + Double(index) * .pi * 2 / 3) * 90,
                        y: sin(cardFloat + Double(index) * .pi * 2 / 3) * 90
                    )
                    .rotationEffect(.degrees(cardFloat * 180 / .pi))
            }
            
            // Icono principal
            ZStack {
                Image(systemName: "creditcard.fill")
                    .font(.system(size: 85))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.brandGold, .brandAccent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .blur(radius: 10)
                    .scaleEffect(isAnimating ? 1.1 : 1.0)
                
                Image(systemName: "creditcard.fill")
                    .font(.system(size: 85))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.brandGold, .brandAccent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            // Símbolos de moneda
            ForEach(0..<4, id: \.self) { index in
                Text("$")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.brandGold.opacity(priceGlow + 0.3))
                    .offset(
                        x: cos(Double(index) * .pi / 2) * 120,
                        y: sin(Double(index) * .pi / 2) * 120
                    )
                    .scaleEffect(0.8 + sin(cardFloat + Double(index)) * 0.2)
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 6.0).repeatForever(autoreverses: false)) {
                cardFloat = .pi * 2
            }
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                priceGlow = 0.8
            }
        }
    }
}

// MARK: - Diseño para Entrenamiento Personalizado (Simplificado)
struct PersonalTrainingDesign: View {
    @Binding var isAnimating: Bool
    @Binding var particleAnimation: Bool
    @State private var targetRotation: Double = 0
    @State private var progressGlow: Double = 0.4
    @State private var coachPulse: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            // Círculo de progreso
            ProgressCircle(rotation: targetRotation, glow: progressGlow)
            
            // Objetivos flotantes
            TargetElements(rotation: targetRotation, glow: progressGlow)
            
            // Puntos de datos
            DataPoints(rotation: targetRotation)
            
            // Icono principal
            MainTrainingIcon(pulse: coachPulse)
        }
        .onAppear {
            withAnimation(.linear(duration: 10.0).repeatForever(autoreverses: false)) {
                targetRotation = 360
            }
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                progressGlow = 0.9
                coachPulse = 1.15
            }
        }
    }
}

// MARK: - Componentes auxiliares para PersonalTrainingDesign
struct ProgressCircle: View {
    let rotation: Double
    let glow: Double
    
    var body: some View {
        Circle()
            .trim(from: 0, to: 0.75)
            .stroke(
                LinearGradient(
                    colors: [.brandAccent, .brandGold],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                style: StrokeStyle(lineWidth: 4, lineCap: .round)
            )
            .frame(width: 130, height: 130)
            .rotationEffect(.degrees(rotation))
            .opacity(glow)
    }
}

struct TargetElements: View {
    let rotation: Double
    let glow: Double
    
    var body: some View {
        ForEach(0..<5, id: \.self) { index in
            let angle = rotation * .pi / 180 + Double(index) * .pi * 2 / 5
            let xOffset = cos(angle) * 100
            let yOffset = sin(angle) * 100
            let scale = 0.8 + sin(rotation * .pi / 180 + Double(index)) * 0.2
            
            Image(systemName: "target")
                .font(.system(size: 16))
                .foregroundColor(.brandAccent.opacity(glow + 0.3))
                .offset(x: xOffset, y: yOffset)
                .scaleEffect(scale)
        }
    }
}

struct DataPoints: View {
    let rotation: Double
    
    var body: some View {
        ForEach(0..<8, id: \.self) { index in
            let angle = Double(index) * .pi / 4
            let xOffset = cos(angle) * 85
            let yOffset = sin(angle) * 85
            let scale = 1.0 + sin(rotation * .pi / 90 + Double(index)) * 0.5
            
            Circle()
                .fill(Color.brandGold.opacity(0.7))
                .frame(width: 3, height: 3)
                .offset(x: xOffset, y: yOffset)
                .scaleEffect(scale)
        }
    }
}

struct MainTrainingIcon: View {
    let pulse: CGFloat
    
    var body: some View {
        ZStack {
            Image(systemName: "figure.walk.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.brandAccent, .brandGold],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .blur(radius: 8)
                .scaleEffect(pulse)
            
            Image(systemName: "figure.walk.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.brandAccent, .brandGold],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .scaleEffect(pulse * 0.95)
        }
    }
}

// MARK: - OnboardingView Simplificado
struct OnboardingView: View {
    @EnvironmentObject var onboardingManager: OnboardingManager
    
    var body: some View {
        ZStack {
            // ✅ FONDO UNIFORME PARA TODAS LAS PÁGINAS
            LinearGradient.brandDark
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Skip button
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
                ZStack {
                    ForEach(0..<onboardingManager.onboardingPages.count, id: \.self) { index in
                        OnboardingPageView(page: onboardingManager.onboardingPages[index])
                            .opacity(index == onboardingManager.currentPage ? 1.0 : 0.0)
                            .scaleEffect(index == onboardingManager.currentPage ? 1.0 : 0.9)
                            .animation(.easeInOut(duration: 0.4), value: onboardingManager.currentPage)
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
                
                // Bottom controls
                VStack(spacing: 30) {
                    // Page indicators
                    HStack(spacing: 12) {
                        ForEach(0..<onboardingManager.onboardingPages.count, id: \.self) { index in
                            Button(action: {
                                onboardingManager.goToPage(index)
                            }) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(index == onboardingManager.currentPage ? Color.brandGold : Color.brandLight.opacity(0.4))
                                    .frame(
                                        width: index == onboardingManager.currentPage ? 24 : 8,
                                        height: 8
                                    )
                            }
                            .animation(.spring(response: 0.3), value: onboardingManager.currentPage)
                        }
                    }
                    
                    // Navigation buttons
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
                        
                        // ✅ BOTÓN SIMPLE - MISMO PARA TODAS LAS PÁGINAS
                        Button(action: {
                            if onboardingManager.currentPage == onboardingManager.onboardingPages.count - 1 {
                                onboardingManager.completeOnboarding()
                            } else {
                                onboardingManager.nextPage()
                            }
                        }) {
                            HStack(spacing: 8) {
                                Text(buttonText)
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
                            .shadow(
                                color: .brandGold.opacity(0.2),
                                radius: 4,
                                x: 0,
                                y: 4
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
    }
    
    // ✅ TEXTO DE BOTÓN SIMPLE
    private var buttonText: String {
        onboardingManager.currentPage == onboardingManager.onboardingPages.count - 1 ? "¡Comenzar!" : "Siguiente"
    }
}

// MARK: - FeatureRow Component
struct FeatureRow: View {
    let icon: String
    let text: String
    
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    var body: some View {
        HStack(spacing: 0) {
            // Spacer izquierdo para centrar en iPad grande
            if shouldCenter {
                Spacer()
            }
            
            // Contenido principal
            HStack(spacing: iconSpacing) {
                Image(systemName: icon)
                    .foregroundColor(.brandGold)
                    .font(.system(size: iconSize))
                    .frame(width: iconFrameWidth)
                
                Text(text)
                    .font(.system(size: fontSize, weight: .medium))
                    .foregroundColor(.brandLight.opacity(0.9))
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                
                Spacer()
            }
            .frame(maxWidth: maxContentWidth)
            
            // Spacer derecho para centrar en iPad grande
            if shouldCenter {
                Spacer()
            }
        }
        .padding(.horizontal, horizontalPadding)
        .frame(minHeight: rowHeight)
    }
    
    // MARK: - Propiedades adaptativas
    private var shouldCenter: Bool {
        // Centrar solo en iPad grande (12.9")
        horizontalSizeClass == .regular && UIScreen.main.bounds.width > 1000
    }
    
    private var maxContentWidth: CGFloat {
        if horizontalSizeClass == .regular {
            // En iPad, limitar el ancho del contenido
            return UIScreen.main.bounds.width > 1000 ? 600 : .infinity
        } else {
            // En iPhone, usar todo el ancho disponible
            return .infinity
        }
    }
    
    private var horizontalPadding: CGFloat {
        if horizontalSizeClass == .regular {
            return UIScreen.main.bounds.width > 1000 ? 40 : 60
        } else {
            return 20
        }
    }
    
    private var iconSpacing: CGFloat {
        horizontalSizeClass == .regular ? 16 : 12
    }
    
    private var iconSize: CGFloat {
        horizontalSizeClass == .regular ? 18 : 16
    }
    
    private var iconFrameWidth: CGFloat {
        horizontalSizeClass == .regular ? 24 : 20
    }
    
    private var fontSize: CGFloat {
        horizontalSizeClass == .regular ? 16 : 14
    }
    
    private var rowHeight: CGFloat {
        horizontalSizeClass == .regular ? 28 : 24
    }
}


// MARK: - Componentes Especiales para Gymius
struct AIGymiusIcon: View {
    @State private var pulseScale: CGFloat = 1.0
    @State private var neuralFlow: Double = 0
    @State private var synapseGlow: Double = 0.3
    @State private var brainRotation: Double = 0
    
    var body: some View {
        ZStack {
            // Red neuronal de fondo
            ForEach(0..<12, id: \.self) { index in
                let angle = Double(index) * .pi / 6
                let radius = 70.0
                let endRadius = 95.0
                
                Path { path in
                    let startPoint = CGPoint(
                        x: cos(angle) * radius,
                        y: sin(angle) * radius
                    )
                    let endPoint = CGPoint(
                        x: cos(angle) * endRadius,
                        y: sin(angle) * endRadius
                    )
                    
                    path.move(to: startPoint)
                    path.addLine(to: endPoint)
                }
                .stroke(
                    LinearGradient(
                        colors: [
                            .brandAccent.opacity(synapseGlow),
                            .brandGold.opacity(1.0 - synapseGlow),
                            .clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 1.5
                )
                .opacity(0.7)
            }
            
            // Conexiones neuronales cruzadas
            ForEach(0..<8, id: \.self) { index in
                let startAngle = Double(index) * .pi / 4
                let endAngle = Double(index + 2) * .pi / 4
                let radius = 75.0
                
                Path { path in
                    let startPoint = CGPoint(
                        x: cos(startAngle) * radius,
                        y: sin(startAngle) * radius
                    )
                    let endPoint = CGPoint(
                        x: cos(endAngle) * radius,
                        y: sin(endAngle) * radius
                    )
                    
                    // Crear curva bezier para simular sinapsis
                    let controlPoint = CGPoint(x: 0, y: 0)
                    
                    path.move(to: startPoint)
                    path.addQuadCurve(to: endPoint, control: controlPoint)
                }
                .stroke(
                    Color.brandAccent.opacity(synapseGlow * 0.6),
                    lineWidth: 1
                )
                .opacity(0.4)
            }
            
            // Neuronas (nodos) exteriores
            ForEach(0..<12, id: \.self) { index in
                let angle = Double(index) * .pi / 6
                let radius = 95.0
                
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                .brandGold.opacity(synapseGlow + 0.3),
                                .brandAccent.opacity(0.6),
                                .clear
                            ],
                            center: .center,
                            startRadius: 2,
                            endRadius: 8
                        )
                    )
                    .frame(width: 8, height: 8)
                    .scaleEffect(1.0 + sin(neuralFlow + Double(index) * 0.3) * 0.3)
                    .offset(
                        x: cos(angle) * radius,
                        y: sin(angle) * radius
                    )
            }
            
            // Pulsos de información viajando
            ForEach(0..<6, id: \.self) { index in
                let angle = neuralFlow + Double(index) * .pi / 3
                
                Circle()
                    .fill(Color.brandGold.opacity(0.9))
                    .frame(width: 4, height: 4)
                    .offset(
                        x: cos(angle) * (60 + sin(neuralFlow * 2) * 15),
                        y: sin(angle) * (60 + sin(neuralFlow * 2) * 15)
                    )
                    .opacity(0.8)
            }
            
            // Marco cerebral sutil
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            .brandAccent.opacity(0.2),
                            .brandGold.opacity(0.4),
                            .brandAccent.opacity(0.2)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
                .frame(width: 130, height: 130)
                .rotationEffect(.degrees(brainRotation))
                .opacity(0.6)
            
            // Cerebro central
            ZStack {
                // Glow effect del cerebro
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 85))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.brandAccent, .brandGold],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .blur(radius: 12)
                    .scaleEffect(pulseScale)
                
                // Cerebro principal
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 85))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.brandAccent, .brandGold],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(pulseScale * 0.95)
                
                // Detalles neurales internos
                VStack(spacing: 3) {
                    HStack(spacing: 3) {
                        ForEach(0..<3, id: \.self) { _ in
                            Circle()
                                .fill(Color.brandLight.opacity(synapseGlow))
                                .frame(width: 2, height: 2)
                        }
                    }
                    HStack(spacing: 3) {
                        ForEach(0..<2, id: \.self) { _ in
                            Circle()
                                .fill(Color.brandLight.opacity(synapseGlow * 0.7))
                                .frame(width: 1.5, height: 1.5)
                        }
                    }
                }
                .offset(x: 10, y: -5)
                .opacity(0.8)
            }
        }
        .onAppear {
            // Animación del pulso del cerebro
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                pulseScale = 1.15
            }
            
            // Flujo neural continuo
            withAnimation(.linear(duration: 4.0).repeatForever(autoreverses: false)) {
                neuralFlow = .pi * 2
            }
            
            // Variación del brillo sináptico
            withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
                synapseGlow = 0.9
            }
            
            // Rotación sutil del marco
            withAnimation(.linear(duration: 20.0).repeatForever(autoreverses: false)) {
                brainRotation = 360
            }
        }
    }
}

struct GymiusFeatureCardCompact: View {
    let feature: GymiusFeature
    let isVisible: Bool
    let delay: Double
    
    @State private var cardOffset: CGFloat = 50
    @State private var cardOpacity: Double = 0
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon más pequeño
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [feature.color.opacity(0.3), feature.color.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)
                
                Image(systemName: feature.icon)
                    .font(.system(size: 20))
                    .foregroundColor(feature.color)
            }
            
            // Content más compacto
            VStack(alignment: .leading, spacing: 6) {
                Text(feature.title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.brandWhite)
                
                Text(feature.description)
                    .font(.system(size: 15))
                    .foregroundColor(.brandLight.opacity(0.8))
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.brandWhite.opacity(0.05))
                .backdrop(blur: 10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(feature.color.opacity(0.3), lineWidth: 1)
        )
        .offset(x: cardOffset)
        .opacity(cardOpacity)
        .onChange(of: isVisible) { newValue in
            if newValue {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(delay)) {
                    cardOffset = 0
                    cardOpacity = 1
                }
            }
        }
    }
}

struct GymiusIntroView: View {
    @State private var showFeatures = false
    @State private var currentFeature = 0
    @Binding var isPresented: Bool
    
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    let features = [
        GymiusFeature(
            icon: "brain.head.profile",
            title: "Inteligencia Artificial",
            description: "Gymius utiliza IA avanzada para crear rutinas personalizadas basadas en tus objetivos y progreso.",
            color: .brandAccent
        ),
        GymiusFeature(
            icon: "chart.line.uptrend.xyaxis",
            title: "Seguimiento Inteligente",
            description: "Monitorea tu progreso en tiempo real y ajusta automáticamente tu plan de entrenamiento.",
            color: .brandGold
        ),
        GymiusFeature(
            icon: "heart.text.square",
            title: "Motivación Personalizada",
            description: "Recibe mensajes de motivación y consejos personalizados para mantenerte enfocado.",
            color: .brandLight
        ),
        GymiusFeature(
            icon: "person.fill.checkmark",
            title: "Coach Virtual 24/7",
            description: "Gymius está disponible las 24 horas para responder preguntas y guiarte en tu journey fitness.",
            color: .brandAccent
        )
    ]
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [
                    Color.brandDark,
                    Color.brandAccent.opacity(0.2),
                    Color.brandDark
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            if isIPad {
                iPadLayout
            } else {
                iPhoneLayout
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).delay(0.3)) {
                showFeatures = true
            }
        }
    }
    
    // MARK: - Layout para iPad
    private var iPadLayout: some View {
        VStack(spacing: 0) {
            // Header compacto
            headerSection
                .padding(.top, 30)
                .padding(.horizontal, 60)
            
            // Contenido principal en dos columnas
            HStack(spacing: 60) {
                // Columna izquierda - Avatar y descripción
                VStack(spacing: 25) {
                    AIGymiusIcon()
                        .scaleEffect(1.1)
                    
                    VStack(spacing: 15) {
                        Text("Tu Asistente Personal con IA")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundColor(.brandGold)
                            .multilineTextAlignment(.center)
                        
                        Text("Gymius es la primera IA especializada en fitness que te acompañará en cada paso de tu transformación.")
                            .font(.system(size: 18))
                            .foregroundColor(.brandLight.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .lineLimit(4)
                    }
                }
                .frame(maxWidth: 400)
                
                // Columna derecha - Features
                VStack(spacing: 15) {
                    ForEach(Array(features.enumerated()), id: \.offset) { index, feature in
                        GymiusFeatureCardCompact(
                            feature: feature,
                            isVisible: showFeatures,
                            delay: Double(index) * 0.15
                        )
                    }
                }
                .frame(maxWidth: 400)
            }
            .padding(.horizontal, 60)
            .padding(.vertical, 40)
            
            // CTA Button
            ctaSection
                .padding(.horizontal, 60)
                .padding(.bottom, 50)
        }
    }
    
    // MARK: - Layout para iPhone
    private var iPhoneLayout: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 40) {
                // Header
                headerSection
                    .padding(.horizontal, 30)
                    .padding(.top, 20)
                
                // Gymius Avatar
                AIGymiusIcon()
                    .scaleEffect(0.8)
                
                // Descripción principal
                VStack(spacing: 20) {
                    Text("Tu Asistente Personal con IA")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.brandGold)
                        .multilineTextAlignment(.center)
                    
                    Text("Gymius es la primera IA especializada en fitness que te acompañará en cada paso de tu transformación. Diseñada específicamente para The Brother's Gym.")
                        .font(.body)
                        .foregroundColor(.brandLight.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                }
                
                // Features Cards
                LazyVStack(spacing: 20) {
                    ForEach(Array(features.enumerated()), id: \.offset) { index, feature in
                        GymiusFeatureCard(
                            feature: feature,
                            isVisible: showFeatures,
                            delay: Double(index) * 0.2
                        )
                    }
                }
                .padding(.horizontal, 30)
                
                // CTA
                ctaSection
                    .padding(.bottom, 40)
            }
        }
    }
    
    // MARK: - Componentes reutilizables
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text("Conoce a")
                    .font(.system(size: isIPad ? 22 : 18))
                    .foregroundColor(.brandLight)
                
                Text("Gymius")
                    .font(.system(size: isIPad ? 42 : 36, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.brandAccent, .brandGold],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }
            
            Spacer()
            
            Button(action: {
                isPresented = false
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: isIPad ? 26 : 22))
                    .foregroundColor(.brandLight.opacity(0.7))
            }
        }
    }
    
    private var ctaSection: some View {
        VStack(spacing: 20) {
            Text("¿Listo para entrenar con Gymius?")
                .font(.system(size: isIPad ? 20 : 17, weight: .semibold))
                .foregroundColor(.brandWhite)
                .multilineTextAlignment(.center)
            
            Button(action: {
                isPresented = false
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "brain.head.profile")
                    Text("¡Comenzar con Gymius!")
                        .fontWeight(.semibold)
                    Image(systemName: "arrow.right.circle.fill")
                }
                .font(.system(size: isIPad ? 18 : 16))
                .foregroundColor(.brandBlack)
                .padding(.horizontal, isIPad ? 40 : 30)
                .padding(.vertical, isIPad ? 18 : 16)
                .background(
                    LinearGradient.brandPrimary
                        .clipShape(RoundedRectangle(cornerRadius: 25))
                )
                .shadow(color: .brandGold.opacity(0.3), radius: 10, x: 0, y: 5)
            }
            .scaleEffect(showFeatures ? 1.0 : 0.8)
            .opacity(showFeatures ? 1.0 : 0.0)
            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(1.0), value: showFeatures)
        }
    }
    
    // MARK: - Computed Properties
    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }
}


struct GymiusFeature {
    let icon: String
    let title: String
    let description: String
    let color: Color
}

struct GymiusFeatureCard: View {
    let feature: GymiusFeature
    let isVisible: Bool
    let delay: Double
    
    @State private var cardOffset: CGFloat = 100
    @State private var cardOpacity: Double = 0
    
    var body: some View {
        HStack(spacing: 20) {
            // Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [feature.color.opacity(0.3), feature.color.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)
                
                Image(systemName: feature.icon)
                    .font(.system(size: 24))
                    .foregroundColor(feature.color)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 8) {
                Text(feature.title)
                    .font(.headline)
                    .foregroundColor(.brandWhite)
                
                Text(feature.description)
                    .font(.subheadline)
                    .foregroundColor(.brandLight.opacity(0.8))
                    .multilineTextAlignment(.leading)
            }
            
            Spacer()
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.brandWhite.opacity(0.05))
                .backdrop(blur: 10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(feature.color.opacity(0.3), lineWidth: 1)
        )
        .offset(x: cardOffset)
        .opacity(cardOpacity)
        .onChange(of: isVisible) { newValue in
            if newValue {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(delay)) {
                    cardOffset = 0
                    cardOpacity = 1
                }
            }
        }
    }
}

// MARK: - Preview
struct GymiusIntroView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            GymiusIntroView(isPresented: .constant(true))
                .previewDevice("iPad Pro (12.9-inch) (6th generation)")
                .previewDisplayName("iPad")
            
            GymiusIntroView(isPresented: .constant(true))
                .previewDevice("iPhone 14")
                .previewDisplayName("iPhone")
        }
    }
}
