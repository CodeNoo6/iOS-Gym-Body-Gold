//
//  AuthManager.swift
//  gymadministrator
//
//  Created by Ruben Camargo on 24/07/25.
//

import Firebase
import FirebaseAuth
import SwiftUI

@MainActor
class AuthManager: ObservableObject {
    @Published var user: User?
    @Published var isLoading = false
    @Published var errorMessage = ""
    @Published var isAuthenticated = false
    @Published var userOccupation = ""
    
    private var authStateHandle: AuthStateDidChangeListenerHandle?
    
    init() {
        // Escuchar cambios de autenticación
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async {
                self?.user = user
                self?.isAuthenticated = user != nil
                if user != nil {
                    Task {
                        await self?.fetchOccupation()
                    }
                } else {
                    self?.userOccupation = ""
                }
            }
        }
    }
    
    deinit {
        if let handle = authStateHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
    
    // MARK: - Sign In con Email/Password
    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = ""
        
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            print("✅ Administrador logueado: \(result.user.email ?? "")")
        } catch {
            errorMessage = handleAuthError(error)
            print("❌ Error de login: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    // MARK: - Crear cuenta de administrador
    func signUp(email: String, password: String, displayName: String = "") async {
        isLoading = true
        errorMessage = ""
        
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            
            // Actualizar perfil con nombre si se proporciona
            if !displayName.isEmpty {
                let changeRequest = result.user.createProfileChangeRequest()
                changeRequest.displayName = displayName
                try await changeRequest.commitChanges()
            }
            
            // Crear documento del administrador en Firestore
            await createAdminProfile(user: result.user, displayName: displayName)
            
            print("✅ Administrador creado: \(result.user.email ?? "")")
        } catch {
            errorMessage = handleAuthError(error)
            print("❌ Error creando cuenta: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    // MARK: - Sign Out
    func signOut() {
        do {
            try Auth.auth().signOut()
            print("✅ Sesión cerrada")
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Reset Password
    func resetPassword(email: String) async {
        isLoading = true
        errorMessage = ""
        
        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
            errorMessage = "📧 Email de recuperación enviado"
        } catch {
            errorMessage = handleAuthError(error)
        }
        
        isLoading = false
    }
    
    // MARK: - Eliminar cuenta (para cumplir políticas de privacidad)
    func deleteAccount() async {
        guard let user = Auth.auth().currentUser else { return }
        
        isLoading = true
        errorMessage = ""
        
        do {
            // Eliminar datos del usuario en Firestore
            try await deleteAdminProfile(userId: user.uid)
            
            // Eliminar cuenta de Authentication
            try await user.delete()
            
            print("✅ Cuenta eliminada")
        } catch {
            errorMessage = handleAuthError(error)
        }
        
        isLoading = false
    }
    
    // MARK: - Helpers privados
    private func createAdminProfile(user: User, displayName: String) async {
        let db = Firestore.firestore()
        let adminData: [String: Any] = [
            "uid": user.uid,
            "email": user.email ?? "",
            "displayName": displayName,
            "role": "admin",
            "createdAt": Timestamp(),
            "lastLogin": Timestamp()
        ]
        
        do {
            try await db.collection("administrators").document(user.uid).setData(adminData)
        } catch {
            print("❌ Error creando perfil de admin: \(error)")
        }
    }
    
    private func deleteAdminProfile(userId: String) async throws {
        let db = Firestore.firestore()
        try await db.collection("administrators").document(userId).delete()
    }
    
    private func handleAuthError(_ error: Error) -> String {
        guard let authError = error as NSError? else {
            return error.localizedDescription
        }
        
        switch AuthErrorCode(rawValue: authError.code) {
        case .invalidEmail:
            return "Email inválido"
        case .wrongPassword:
            return "Contraseña incorrecta"
        case .userNotFound:
            return "Usuario no encontrado"
        case .userDisabled:
            return "Cuenta deshabilitada"
        case .emailAlreadyInUse:
            return "Este email ya está registrado"
        case .weakPassword:
            return "La contraseña debe tener al menos 6 caracteres"
        case .networkError:
            return "Error de conexión"
        default:
            return error.localizedDescription
        }
    }
    
    // MARK: - Occupation Management
    func fetchOccupation() async {
        guard let user = user else { return }
        let db = Firestore.firestore()
        
        do {
            let document = try await db.collection("administrators").document(user.uid).getDocument()
            if let data = document.data(), let occupation = data["ocupacion"] as? String {
                self.userOccupation = occupation
            } else {
                self.userOccupation = ""
            }
        } catch {
            print("Error fetching occupation: \(error)")
        }
    }
    
    func updateOccupation(occupation: String) async -> Bool {
        guard let user = user else { return false }
        isLoading = true
        
        do {
            let db = Firestore.firestore()
            try await db.collection("administrators").document(user.uid).updateData([
                "ocupacion": occupation
            ])
            self.userOccupation = occupation
            isLoading = false
            return true
        } catch {
            print("Error updating occupation: \(error)")
            isLoading = false
            return false
        }
    }
}
