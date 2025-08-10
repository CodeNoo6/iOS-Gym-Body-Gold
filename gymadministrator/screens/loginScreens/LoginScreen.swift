//
//  LoginScreen.swift
//  gymadministrator
//
//  Created by Ruben Camargo on 9/08/25.
//

import Foundation
import SwiftUI
import FirebaseCore
import FirebaseAuth
import Firebase

// MARK: - AuthManager
@MainActor
class AuthManager: ObservableObject {
    @Published var user: User?
    @Published var isLoading = false
    @Published var errorMessage = ""
    @Published var isAuthenticated = false
    
    private var authStateHandle: AuthStateDidChangeListenerHandle?
    
    init() {
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async {
                self?.user = user
                self?.isAuthenticated = user != nil
            }
        }
    }
    
    deinit {
        if let handle = authStateHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
    
    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = ""
        
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            print("✅ Administrador logueado: \(result.user.email ?? "")")
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func signUp(email: String, password: String, displayName: String = "") async {
        isLoading = true
        errorMessage = ""
        
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            
            if !displayName.isEmpty {
                let changeRequest = result.user.createProfileChangeRequest()
                changeRequest.displayName = displayName
                try await changeRequest.commitChanges()
            }
            
            print("✅ Administrador creado: \(result.user.email ?? "")")
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func signOut() {
        do {
            try Auth.auth().signOut()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func resetPassword(email: String) async {
        isLoading = true
        errorMessage = ""
        
        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
            errorMessage = "📧 Email de recuperación enviado"
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
}

// MARK: - LoginView
struct LoginView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var isSignUp = false
    @State private var showForgotPassword = false
    @State private var showPassword = false
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient.brandDark
                .ignoresSafeArea()
            
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer(minLength: 60)
                    
                    // Logo y título principal
                    VStack(spacing: 25) {
                        // Logo con efecto glow
                        LogoWithGlow()
                        
                        // Título con gradiente
                        TitleSection(isSignUp: isSignUp)
                    }
                    .padding(.bottom, 50)
                    
                    // Tarjeta de login
                    VStack(spacing: 30) {
                        // Toggle entre Login/Signup
                        ZStack {
                            // Background
                            RoundedRectangle(cornerRadius: 25)
                                .fill(Color.brandDark)
                            
                            // Sliding indicator (behind text)
                            GeometryReader { geometry in
                                RoundedRectangle(cornerRadius: 25)
                                    .fill(Color.brandGold)
                                    .frame(width: geometry.size.width / 2)
                                    .offset(x: isSignUp ? geometry.size.width / 2 : 0)
                                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: isSignUp)
                            }
                            
                            // Buttons (on top)
                            HStack(spacing: 0) {
                                // Login tab
                                Button(action: {
                                    withAnimation(.spring()) {
                                        isSignUp = false
                                        authManager.errorMessage = ""
                                    }
                                }) {
                                    Text("Iniciar Sesión")
                                        .foregroundColor(isSignUp ? .brandLight : .brandBlack)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                }
                                
                                // Signup tab
                                Button(action: {
                                    withAnimation(.spring()) {
                                        isSignUp = true
                                        authManager.errorMessage = ""
                                    }
                                }) {
                                    Text("Crear Cuenta")
                                        .foregroundColor(isSignUp ? .brandBlack : .brandLight)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                }
                            }
                            .zIndex(1) // Asegura que los botones estén encima
                        }
                        
                        // Formulario
                        VStack(spacing: 20) {
                            if isSignUp {
                                CustomTextField(
                                    placeholder: "Nombre completo",
                                    text: $displayName,
                                    icon: "person.fill"
                                )
                                .transition(.asymmetric(
                                    insertion: .move(edge: .top).combined(with: .opacity),
                                    removal: .move(edge: .top).combined(with: .opacity)
                                ))
                            }
                            
                            CustomTextField(
                                placeholder: "Email",
                                text: $email,
                                icon: "envelope.fill",
                                keyboardType: .emailAddress
                            )
                            
                            CustomSecureField(
                                placeholder: "Contraseña",
                                text: $password,
                                showPassword: $showPassword,
                                icon: "lock.fill"
                            )
                        }
                        .animation(.spring(), value: isSignUp)
                        
                        // Error message
                        if !authManager.errorMessage.isEmpty {
                            HStack {
                                Image(systemName: authManager.errorMessage.contains("📧") ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                    .foregroundColor(authManager.errorMessage.contains("📧") ? .brandSuccess : .brandError)
                                
                                Text(authManager.errorMessage)
                                    .foregroundColor(authManager.errorMessage.contains("📧") ? .brandSuccess : .brandError)
                                    .font(.caption)
                                
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }
                        
                        // Botón principal
                        Button(action: {
                            Task {
                                if isSignUp {
                                    await authManager.signUp(email: email, password: password, displayName: displayName)
                                } else {
                                    await authManager.signIn(email: email, password: password)
                                }
                            }
                        }) {
                            HStack {
                                if authManager.isLoading {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .tint(.brandBlack)
                                        .controlSize(.small)
                                } else {
                                    Image(systemName: isSignUp ? "person.badge.plus" : "arrow.right.circle.fill")
                                    Text(isSignUp ? "Crear Cuenta" : "Iniciar Sesión")
                                        .fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient.brandPrimary
                                    .clipShape(RoundedRectangle(cornerRadius: 15))
                            )
                            .foregroundColor(.brandBlack)
                        }
                        .disabled(authManager.isLoading || email.isEmpty || password.isEmpty)
                        .opacity((email.isEmpty || password.isEmpty) ? 0.6 : 1.0)
                        .scaleEffect(authManager.isLoading ? 0.95 : 1.0)
                        .animation(.spring(), value: authManager.isLoading)
                        
                        // Botón de contraseña olvidada
                        if !isSignUp {
                            Button("¿Olvidaste tu contraseña?") {
                                showForgotPassword = true
                            }
                            .font(.footnote)
                            .foregroundColor(.brandLight)
                            .transition(.opacity)
                        }
                    }
                    .padding(.horizontal, 30)
                    .padding(.vertical, 40)
                    .background(
                        RoundedRectangle(cornerRadius: 30)
                            .fill(Color.brandWhite.opacity(0.05))
                            .backdrop(blur: 20)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 30)
                            .stroke(
                                LinearGradient(
                                    colors: [Color.brandGold.opacity(0.3), Color.clear],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .padding(.horizontal, 20)
                    
                    Spacer(minLength: 40)
                }
            }
        }
        .animation(.easeInOut, value: authManager.errorMessage)
        .alert("Recuperar Contraseña", isPresented: $showForgotPassword) {
            Button("Cancelar", role: .cancel) { }
            Button("Enviar") {
                Task {
                    await authManager.resetPassword(email: email)
                }
            }
        } message: {
            Text("Se enviará un email a: \(email)")
        }
    }
}
