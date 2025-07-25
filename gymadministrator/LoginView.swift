//
//  LoginView.swift
//  gymadministrator
//
//  Created by Ruben Camargo on 24/07/25.
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var isSignUp = false
    @State private var showForgotPassword = false
    @State private var showingAlert = false
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 25) {
                    Spacer()
                    
                    // Logo y título del gym
                    VStack(spacing: 15) {
                        Image(systemName: "dumbbell.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                            .shadow(radius: 5)
                        
                        Text("Gym Administrator")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        Text(isSignUp ? "Crear cuenta de administrador" : "Panel de administración")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.bottom, 20)
                    
                    // Formulario de login
                    VStack(spacing: 20) {
                        // Campo de nombre (solo en registro)
                        if isSignUp {
                            CustomTextField(
                                title: "Nombre completo",
                                text: $displayName,
                                icon: "person.fill"
                            )
                        }
                        
                        // Campo de email
                        CustomTextField(
                            title: "Email de administrador",
                            text: $email,
                            icon: "envelope.fill"
                        )
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        
                        // Campo de contraseña
                        CustomSecureField(
                            title: "Contraseña",
                            text: $password,
                            icon: "lock.fill"
                        )
                    }
                    .padding(.horizontal, 20)
                    
                    // Mensaje de error
                    if !authManager.errorMessage.isEmpty {
                        ErrorMessageView(message: authManager.errorMessage)
                    }
                    
                    // Botón principal
                    ActionButton(
                        title: isSignUp ? "Crear Cuenta de Admin" : "Iniciar Sesión",
                        isLoading: authManager.isLoading,
                        action: {
                            Task {
                                if isSignUp {
                                    await authManager.signUp(
                                        email: email,
                                        password: password,
                                        displayName: displayName
                                    )
                                } else {
                                    await authManager.signIn(email: email, password: password)
                                }
                            }
                        }
                    )
                    .disabled(authManager.isLoading || email.isEmpty || password.isEmpty)
                    .padding(.horizontal, 20)
                    
                    // Botones secundarios
                    VStack(spacing: 15) {
                        // Toggle entre login y registro
                        Button(action: {
                            isSignUp.toggle()
                            authManager.errorMessage = ""
                            clearFields()
                        }) {
                            Text(isSignUp ? "¿Ya tienes cuenta? Inicia sesión" : "¿Primera vez? Crear cuenta de admin")
                                .font(.footnote)
                                .foregroundColor(.blue)
                        }
                        
                        // Recuperar contraseña (solo en login)
                        if !isSignUp {
                            Button("¿Olvidaste tu contraseña?") {
                                showForgotPassword = true
                            }
                            .font(.footnote)
                            .foregroundColor(.gray)
                        }
                    }
                    
                    Spacer()
                }
                .frame(minHeight: geometry.size.height)
            }
        }
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.1), Color.white]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .alert("Recuperar Contraseña", isPresented: $showForgotPassword) {
            Button("Cancelar", role: .cancel) { }
            Button("Enviar") {
                Task {
                    await authManager.resetPassword(email: email)
                }
            }
        } message: {
            Text("Se enviará un email de recuperación a: \(email)")
        }
    }
    
    private func clearFields() {
        email = ""
        password = ""
        displayName = ""
    }
}

// MARK: - Componentes personalizados

struct CustomTextField: View {
    let title: String
    @Binding var text: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.gray)
                .frame(width: 20)
            
            TextField(title, text: $text)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
    }
}

struct CustomSecureField: View {
    let title: String
    @Binding var text: String
    let icon: String
    @State private var isSecure = true
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.gray)
                .frame(width: 20)
            
            if isSecure {
                SecureField(title, text: $text)
            } else {
                TextField(title, text: $text)
            }
            
            Button(action: { isSecure.toggle() }) {
                Image(systemName: isSecure ? "eye.slash" : "eye")
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
    }
}

struct ActionButton: View {
    let title: String
    let isLoading: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Text(title)
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.8)]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundColor(.white)
            .cornerRadius(12)
            .shadow(color: Color.blue.opacity(0.3), radius: 5, x: 0, y: 2)
        }
    }
}

struct ErrorMessageView: View {
    let message: String
    
    var body: some View {
        HStack {
            Image(systemName: message.contains("📧") ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundColor(message.contains("📧") ? .green : .red)
            
            Text(message)
                .font(.caption)
                .foregroundColor(message.contains("📧") ? .green : .red)
        }
        .padding(.horizontal, 20)
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthManager())
}
