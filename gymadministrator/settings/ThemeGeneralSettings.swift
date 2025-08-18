//
//  colorSettings.swift
//  gymadministrator
//
//  Created by Ruben Camargo on 9/08/25.
//

import Foundation
import SwiftUI

extension Color {
    // Colores principales de Gym Body Gold
    static let brandGold = Color(red: 1.0, green: 0.75, blue: 0.2)      // #FFBF33 - Dorado principal
    static let brandDark = Color(red: 0.15, green: 0.15, blue: 0.15)    // #262626 - Gris oscuro
    static let brandAccent = Color(red: 1.0, green: 0.65, blue: 0.1)    // #FFA619 - Naranja intenso
    static let brandLight = Color(red: 1.0, green: 0.85, blue: 0.4)     // #FFD966 - Dorado claro
    
    // Colores de apoyo
    static let brandBlack = Color(red: 0.05, green: 0.05, blue: 0.05)   // #0D0D0D - Negro profundo
    static let brandGray = Color(red: 0.25, green: 0.25, blue: 0.25)    // #404040 - Gris medio
    static let brandWhite = Color.white                                  // #FFFFFF - Blanco puro
    
    // Colores de estado
    static let brandSuccess = Color(red: 0.2, green: 0.8, blue: 0.3)    // Verde éxito
    static let brandError = Color(red: 1.0, green: 0.3, blue: 0.3)      // Rojo error
    static let brandWarning = Color(red: 1.0, green: 0.6, blue: 0.0)    // Naranja advertencia
    static let brandInfo = Color(red: 0.2, green: 0.6, blue: 1.0)       // Azul información
}

// MARK: - Brand Color Scheme
struct BrandColorScheme {
    // Esquema de colores para diferentes temas
    static let light = ColorScheme.light
    static let dark = ColorScheme.dark
    
    // Colores adaptativos según el tema
    static func primaryBackground(for colorScheme: ColorScheme) -> Color {
        return colorScheme == .dark ? .brandBlack : .brandWhite
    }
    
    static func secondaryBackground(for colorScheme: ColorScheme) -> Color {
        return colorScheme == .dark ? .brandDark : Color(red: 0.95, green: 0.95, blue: 0.95)
    }
    
    static func primaryText(for colorScheme: ColorScheme) -> Color {
        return colorScheme == .dark ? .brandWhite : .brandBlack
    }
    
    static func secondaryText(for colorScheme: ColorScheme) -> Color {
        return colorScheme == .dark ? .brandLight : .brandGray
    }
}

// MARK: - Gradient Presets
extension LinearGradient {
    // Gradientes predefinidos con colores corporativos
    static let brandPrimary = LinearGradient(
        gradient: Gradient(colors: [.brandGold, .brandAccent]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let brandDark = LinearGradient(
        gradient: Gradient(colors: [.brandBlack, .brandDark]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let brandSoft = LinearGradient(
        gradient: Gradient(colors: [.brandGold.opacity(0.8), .brandLight.opacity(0.6)]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let onboardingBackground = LinearGradient(
        gradient: Gradient(colors: [.brandDark, .brandBlack, .brandDark]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

extension Text {
    func brandTitle() -> some View {
        self
            .font(.largeTitle)
            .fontWeight(.bold)
            .foregroundColor(.brandGold)
    }
    
    func brandSubtitle() -> some View {
        self
            .font(.title2)
            .fontWeight(.semibold)
            .foregroundColor(.brandLight)
    }
    
    func brandBody() -> some View {
        self
            .font(.body)
            .foregroundColor(.brandWhite)
    }
    
    func brandCaption() -> some View {
        self
            .font(.caption)
            .foregroundColor(.brandGray)
    }
}

extension View {
    func brandShadow() -> some View {
        self.shadow(
            color: .brandBlack.opacity(0.3),
            radius: 8,
            x: 0,
            y: 4
        )
    }
    
    func brandGlow() -> some View {
        self.shadow(
            color: .brandGold.opacity(0.6),
            radius: 10,
            x: 0,
            y: 0
        )
    }
}

// MARK: - Custom TextField
struct CustomTextField: View {
    let placeholder: String
    @Binding var text: String
    let icon: String
    var keyboardType: UIKeyboardType = .default
    var inputFilter: InputFilter = .none
    var maxLength: Int? = nil
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .foregroundColor(.brandGold)
                .frame(width: 20)
            
            TextField(placeholder, text: $text)
                .keyboardType(keyboardType)
                .foregroundColor(.brandWhite)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .placeholder(when: text.isEmpty) {
                    Text(placeholder)
                        .foregroundColor(.brandLight.opacity(0.7))
                }
                .onChange(of: text) { newValue in
                    text = filtered(newValue)
                }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.brandWhite.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(Color.brandGold.opacity(0.3), lineWidth: 1)
        )
    }
    
    private func filtered(_ value: String) -> String {
        var s = value
        switch inputFilter {
        case .numbersOnly:
            s = s.filter(\.isNumber)
        case .decimal:
            var seenDot = false
            s = s.filter { ch in
                if ch.isNumber { return true }
                if ch == "." && !seenDot { seenDot = true; return true }
                return false
            }
        case .lettersAndSpaces:
            s = s.filter { $0.isLetter || $0.isWhitespace }
        case .none:
            break
        }
        if let max = maxLength, s.count > max {
            s = String(s.prefix(max))
        }
        return s
    }
}

enum InputFilter {
    case numbersOnly
    case decimal
    case lettersAndSpaces
    case none
}

// MARK: - Custom Secure Field
struct CustomSecureField: View {
    let placeholder: String
    @Binding var text: String
    @Binding var showPassword: Bool
    let icon: String
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .foregroundColor(.brandGold)
                .frame(width: 20)
            
            if showPassword {
                TextField(placeholder, text: $text)
                    .foregroundColor(.brandWhite)
                    .placeholder(when: text.isEmpty) {
                        Text(placeholder)
                            .foregroundColor(.brandLight.opacity(0.7))
                    }
            } else {
                SecureField(placeholder, text: $text)
                    .foregroundColor(.brandWhite)
                    .placeholder(when: text.isEmpty) {
                        Text(placeholder)
                            .foregroundColor(.brandLight.opacity(0.7))
                    }
            }
            
            Button(action: {
                showPassword.toggle()
            }) {
                Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                    .foregroundColor(.brandLight.opacity(0.8))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.brandWhite.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(Color.brandGold.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - View Extension for Placeholder
extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content) -> some View {
        
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
    
    func backdrop(blur radius: CGFloat) -> some View {
        self.background(Color.brandBlack.opacity(0.3))
    }
}

struct LogoWithGlow: View {
    var body: some View {
        ZStack {
            // Glow effect
            Image("bodyGoldLogo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 100, height: 100)
                .brandGlow()
            
            // Logo principal
            Image("bodyGoldLogo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 100, height: 100)
        }
        .scaleEffect(1.05)
    }
}

struct TitleSection: View {
    let isSignUp: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            Text("Gym Body Gold")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.brandGold)
            
            Text(isSignUp ? "Crea una cuenta" : "Bienvenido de vuelta")
                .font(.subheadline)
                .foregroundColor(.brandLight.opacity(0.8))
        }
    }
}
