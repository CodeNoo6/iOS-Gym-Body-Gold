//
//  ProductionPasswordResetManager.swift
//  gymadministrator
//
//  Password Reset with real APIs - Production Ready
//

import Foundation
import SwiftUI
import FirebaseAuth
import FirebaseFirestore

// MARK: - API Models (same as before)
struct LoginRequest: Codable {
    let email: String
    let password: String
}

struct LoginResponse: Codable {
    let success: Bool
    let token: String
    let expires_in: Int
    let user: APIUser
}

struct APIUser: Codable {
    let id: Int
    let name: String
    let email: String
    let email_verified_at: String?
    let created_at: String
    let updated_at: String
}

struct EmailRequest: Codable {
    let app: String
    let template_type: String
    let recipient_email: String
    let template_data: TemplateData
}

struct TemplateData: Codable {
    let verificationCode: String
    let expirationMinutes: Int
    let maxAttempts: Int
}

// MARK: - Verification Code Model for Firestore
struct VerificationCode {
    let code: String
    let email: String
    let expiresAt: Date
    let attempts: Int
    let maxAttempts: Int
    let isUsed: Bool
    let createdAt: Date
    
    var dictionary: [String: Any] {
        return [
            "code": code,
            "email": email,
            "expiresAt": Timestamp(date: expiresAt),
            "attempts": attempts,
            "maxAttempts": maxAttempts,
            "isUsed": isUsed,
            "createdAt": Timestamp(date: createdAt)
        ]
    }
    
    init(from dict: [String: Any]) {
        self.code = dict["code"] as? String ?? ""
        self.email = dict["email"] as? String ?? ""
        self.expiresAt = (dict["expiresAt"] as? Timestamp)?.dateValue() ?? Date()
        self.attempts = dict["attempts"] as? Int ?? 0
        self.maxAttempts = dict["maxAttempts"] as? Int ?? 3
        self.isUsed = dict["isUsed"] as? Bool ?? false
        self.createdAt = (dict["createdAt"] as? Timestamp)?.dateValue() ?? Date()
    }
    
    init(code: String, email: String, expirationMinutes: Int = 10, maxAttempts: Int = 3) {
        self.code = code
        self.email = email
        self.expiresAt = Date().addingTimeInterval(TimeInterval(expirationMinutes * 60))
        self.attempts = 0
        self.maxAttempts = maxAttempts
        self.isUsed = false
        self.createdAt = Date()
    }
}

enum PasswordResetStep {
    case enterEmail      // Paso 1: Ingresar email
    case verifyCode      // Paso 2: Verificar código
    case newPassword     // Paso 3: Nueva contraseña
    case success         // Paso 4: Éxito
}

// MARK: - Production Password Reset Manager
@MainActor
class ProductionPasswordResetManager: ObservableObject {
    @Published var currentStep: PasswordResetStep = .enterEmail
    @Published var email = ""
    @Published var verificationCode = ""
    @Published var newPassword = ""
    @Published var confirmPassword = ""
    @Published var isLoading = false
    @Published var errorMessage = ""
    @Published var isShowingPasswordReset = false
    
    private let baseURL = "https://laravel-multi-serv-app-production.up.railway.app/api"
    private let adminEmail = "developer@gimomagic.com.co"
    private let adminPassword = "Tomate123##"
    private var authToken: String?
    private let db = Firestore.firestore()
    
    // MARK: - API Methods
    
    private func authenticateAdmin() async throws -> String {
        let url = URL(string: "\(baseURL)/login")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 30.0
        
        let loginRequest = LoginRequest(email: adminEmail, password: adminPassword)
        request.httpBody = try JSONEncoder().encode(loginRequest)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "NetworkError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Respuesta inválida del servidor"])
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Sin información adicional"
            throw NSError(domain: "NetworkError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Error de autenticación (\(httpResponse.statusCode)): \(errorBody)"])
        }
        
        let loginResponse = try JSONDecoder().decode(LoginResponse.self, from: data)
        
        if !loginResponse.success {
            throw NSError(domain: "AuthError", code: 401, userInfo: [NSLocalizedDescriptionKey: "Credenciales de administrador inválidas"])
        }
        
        print("✅ Admin autenticado exitosamente")
        return loginResponse.token
    }
    
    private func sendVerificationEmail(token: String, recipientEmail: String, verificationCode: String) async throws {
        let url = URL(string: "\(baseURL)/email/send")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30.0
        
        let templateData = TemplateData(
            verificationCode: verificationCode,
            expirationMinutes: 10,
            maxAttempts: 3
        )
        
        let emailRequest = EmailRequest(
            app: "gymbodygold",
            template_type: "verification",
            recipient_email: recipientEmail,
            template_data: templateData
        )
        
        request.httpBody = try JSONEncoder().encode(emailRequest)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "NetworkError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Respuesta inválida del servidor"])
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Sin información adicional"
            throw NSError(domain: "NetworkError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Error enviando email (\(httpResponse.statusCode)): \(errorBody)"])
        }
        
        print("✅ Email enviado exitosamente a \(recipientEmail)")
    }
    
    // MARK: - Firestore Methods
    
    private func checkUserExists(email: String) async throws -> Bool {
        let query = db.collection("usuarios").whereField("email", isEqualTo: email)
        let snapshot = try await query.getDocuments()
        let exists = !snapshot.documents.isEmpty
        
        print("👤 Usuario \(email) \(exists ? "encontrado" : "no encontrado")")
        return exists
    }
    
    private func saveVerificationCodeToFirestore(verificationCode: VerificationCode) async throws {
        let documentId = "\(verificationCode.email)_\(Int(verificationCode.createdAt.timeIntervalSince1970))"
        try await db.collection("verification_codes").document(documentId).setData(verificationCode.dictionary)
        print("✅ Código guardado en Firestore: \(verificationCode.code)")
    }
    
    private func getValidVerificationCode(email: String, code: String) async throws -> VerificationCode? {
        let query = db.collection("verification_codes")
            .whereField("email", isEqualTo: email)
            .whereField("code", isEqualTo: code)
            .whereField("isUsed", isEqualTo: false)
            .order(by: "createdAt", descending: true)
            .limit(to: 1)
        
        let snapshot = try await query.getDocuments()
        
        guard let document = snapshot.documents.first else {
            return nil
        }
        
        let verificationCode = VerificationCode(from: document.data())
        
        // Verificar si no ha expirado
        if verificationCode.expiresAt < Date() {
            return nil
        }
        
        // Verificar intentos
        if verificationCode.attempts >= verificationCode.maxAttempts {
            return nil
        }
        
        return verificationCode
    }
    
    private func incrementVerificationAttempts(email: String, code: String) async throws {
        let query = db.collection("verification_codes")
            .whereField("email", isEqualTo: email)
            .whereField("code", isEqualTo: code)
            .order(by: "createdAt", descending: true)
            .limit(to: 1)
        
        let snapshot = try await query.getDocuments()
        
        if let document = snapshot.documents.first {
            let currentAttempts = document.data()["attempts"] as? Int ?? 0
            try await document.reference.updateData(["attempts": currentAttempts + 1])
        }
    }
    
    // MARK: - Password Reset Request Model
       struct PasswordResetRequest: Codable {
           let email: String
           let newPassword: String
           let verificationToken: String
       }
    
    private func resetPasswordWithAPI(token: String, email: String, newPassword: String) async throws {
        let url = URL(string: "\(baseURL)/firebase-admin/gymbodygold/reset-password")!

        var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue("application/json", forHTTPHeaderField: "Accept")
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                request.timeoutInterval = 30.0
                
        let resetRequest = PasswordResetRequest(
                    email: email,
                    newPassword: newPassword,
                    verificationToken: "cat-token"
                )
        request.httpBody = try JSONEncoder().encode(resetRequest)
        print("🔒 Enviando request de reset de contraseña:")
                print("   📧 Email: \(email)")
                print("   🔑 Nueva contraseña: \(newPassword)")
                print("   🎫 Token: cat-token")
                
                let (data, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NSError(domain: "NetworkError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Respuesta inválida del servidor"])
                }
        print("📊 Reset Password Status Code: \(httpResponse.statusCode)")
               print("📄 Response: \(String(data: data, encoding: .utf8) ?? "No data")")
               
               guard httpResponse.statusCode == 200 || httpResponse.statusCode == 201 else {
                   let errorBody = String(data: data, encoding: .utf8) ?? "Sin información adicional"
                   throw NSError(domain: "NetworkError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Error actualizando contraseña (\(httpResponse.statusCode)): \(errorBody)"])
               }
               
               print("✅ Contraseña actualizada exitosamente en Firebase Auth")
           
    }
    
    
    private func markVerificationCodeAsUsed(email: String, code: String) async throws {
        let query = db.collection("verification_codes")
            .whereField("email", isEqualTo: email)
            .whereField("code", isEqualTo: code)
            .order(by: "createdAt", descending: true)
            .limit(to: 1)
        
        let snapshot = try await query.getDocuments()
        
        if let document = snapshot.documents.first {
            try await document.reference.updateData(["isUsed": true])
        }
    }
    
    // MARK: - Public Methods
    
    func sendPasswordResetEmail() async {
        print("🚀 Iniciando proceso de reset para: \(email)")
        isLoading = true
        errorMessage = ""
        
        do {
            // 1️⃣ Verificar que el usuario existe en Firestore
            let userExists = try await checkUserExists(email: email)
            
            if !userExists {
                errorMessage = "❌ No se encontró una cuenta asociada a este correo electrónico"
                isLoading = false
                return
            }
            
            // 2️⃣ Autenticar admin con Laravel API
            print("🔐 Autenticando administrador...")
            let token = try await authenticateAdmin()
            authToken = token
            
            // 3️⃣ Generar código de verificación
            let code = String(format: "%06d", Int.random(in: 100000...999999))
            print("🔑 Código generado: \(code)")
            
            // 4️⃣ Guardar código en Firestore
            let verificationCodeObj = VerificationCode(code: code, email: email)
            try await saveVerificationCodeToFirestore(verificationCode: verificationCodeObj)
            
            // 5️⃣ Enviar email a través de Laravel API
            print("📧 Enviando email de verificación...")
            try await sendVerificationEmail(token: token, recipientEmail: email, verificationCode: code)
            
            // 6️⃣ Avanzar al siguiente paso
            currentStep = .verifyCode
            
            print("✅ Proceso completado exitosamente")
            
        } catch {
            print("❌ Error: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func verifyCode() async {
        print("🔍 Verificando código: \(verificationCode)")
        isLoading = true
        errorMessage = ""
        
        do {
            // 1️⃣ Verificar código en Firestore
            guard let validCode = try await getValidVerificationCode(email: email, code: verificationCode) else {
                // Incrementar intentos fallidos
                try await incrementVerificationAttempts(email: email, code: verificationCode)
                errorMessage = "❌ Código de verificación incorrecto o expirado"
                isLoading = false
                return
            }
            
            // 2️⃣ Marcar código como usado
            try await markVerificationCodeAsUsed(email: email, code: verificationCode)
            
            // 3️⃣ Avanzar al siguiente paso
            currentStep = .newPassword
            
            print("✅ Código verificado correctamente")
            
        } catch {
            print("❌ Error verificando código: \(error.localizedDescription)")
            errorMessage = "Error verificando el código: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func updatePassword() async {
        print("🔒 Iniciando actualización de contraseña con API real")
        isLoading = true
        errorMessage = ""
        
        guard newPassword == confirmPassword else {
            errorMessage = "❌ Las contraseñas no coinciden"
            isLoading = false
            return
        }
        
        guard newPassword.count >= 6 else {
            errorMessage = "❌ La contraseña debe tener al menos 6 caracteres"
            isLoading = false
            return
        }
        
        // 🔧 VERIFICAR QUE TENEMOS EL TOKEN DE AUTENTICACIÓN
        guard let token = authToken else {
            errorMessage = "❌ Error de autenticación. Intenta de nuevo desde el inicio."
            isLoading = false
            return
        }
        
        do {
            // 1️⃣ Actualizar contraseña usando el endpoint real CON TOKEN
            print("🔒 Llamando al endpoint de reset de contraseña con token...")
            try await resetPasswordWithAPI(token: token, email: email, newPassword: newPassword)
            
            // 2️⃣ Limpiar códigos de verificación usados
            print("🧹 Limpiando códigos de verificación...")
            let codesQuery = db.collection("verification_codes")
                .whereField("email", isEqualTo: email)
            let codesSnapshot = try await codesQuery.getDocuments()
            
            for document in codesSnapshot.documents {
                try await document.reference.delete()
            }
            print("🧹 Códigos de verificación limpiados")
            
            // 3️⃣ Avanzar al éxito
            currentStep = .success
            print("🎉 Proceso de actualización completado exitosamente")
            
        } catch {
            print("❌ Error actualizando contraseña: \(error.localizedDescription)")
            errorMessage = "Error actualizando la contraseña: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func resetFlow() {
        currentStep = .enterEmail
        email = ""
        verificationCode = ""
        newPassword = ""
        confirmPassword = ""
        errorMessage = ""
        authToken = nil
        isShowingPasswordReset = false
    }
}

// MARK: - Production Password Reset View
struct ProductionPasswordResetView: View {
    @StateObject private var resetManager = ProductionPasswordResetManager()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            LinearGradient.brandDark
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.brandLight.opacity(0.7))
                    }
                    
                    Spacer()
                    
                    Text("Recuperar Contraseña")
                        .font(.headline)
                        .foregroundColor(.brandLight)
                    
                    Spacer()
                    
                    Color.clear
                        .frame(width: 30, height: 30)
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                
                Spacer()
                
                // Contenido principal
                VStack(spacing: 30) {
                    switch resetManager.currentStep {
                    case .enterEmail:
                        ProductionEnterEmailView()
                    case .verifyCode:
                        ProductionVerifyCodeView()
                    case .newPassword:
                        ProductionNewPasswordView()
                    case .success:
                        ProductionSuccessView()
                    }
                }
                .environmentObject(resetManager)
                
                Spacer()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: resetManager.currentStep)
    }
}

// MARK: - Production Step Views

struct ProductionEnterEmailView: View {
    @EnvironmentObject var resetManager: ProductionPasswordResetManager
    @FocusState private var isEmailFocused: Bool
    
    var body: some View {
        VStack(spacing: 30) {
            VStack(spacing: 15) {
                ZStack {
                    Circle()
                        .fill(Color.brandGold.opacity(0.1))
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: "envelope.fill")
                        .font(.system(size: 35))
                        .foregroundColor(.brandGold)
                }
                
                Text("Ingresa tu email")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.brandLight)
                
                Text("Verificaremos que tengas una cuenta registrada y te enviaremos un código de verificación por email")
                    .font(.subheadline)
                    .foregroundColor(.brandLight.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            
            VStack(spacing: 20) {
                CustomTextField(
                    placeholder: "Correo electrónico",
                    text: $resetManager.email,
                    icon: "envelope.fill",
                    keyboardType: .emailAddress
                )
                .focused($isEmailFocused)
                
                if !resetManager.errorMessage.isEmpty {
                    ErrorMessageView(message: resetManager.errorMessage)
                }
                
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.brandGold.opacity(0.7))
                        .font(.caption)
                    
                    Text("Solo se pueden recuperar cuentas registradas en el sistema")
                        .font(.caption)
                        .foregroundColor(.brandLight.opacity(0.6))
                    
                    Spacer()
                }
                .padding(.horizontal, 5)
                
                Button(action: {
                    Task {
                        await resetManager.sendPasswordResetEmail()
                    }
                }) {
                    HStack {
                        if resetManager.isLoading {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(.brandBlack)
                                .controlSize(.small)
                        } else {
                            Image(systemName: "paperplane.fill")
                            Text("Verificar y enviar código")
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
                .disabled(resetManager.isLoading || resetManager.email.isEmpty || !resetManager.email.contains("@"))
                .opacity((resetManager.email.isEmpty || !resetManager.email.contains("@")) ? 0.6 : 1.0)
            }
            .padding(.horizontal, 30)
        }
        .onAppear {
            isEmailFocused = true
        }
    }
}

struct ProductionVerifyCodeView: View {
    @EnvironmentObject var resetManager: ProductionPasswordResetManager
    @FocusState private var isCodeFocused: Bool
    
    var body: some View {
        VStack(spacing: 30) {
            VStack(spacing: 15) {
                ZStack {
                    Circle()
                        .fill(Color.brandGold.opacity(0.1))
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: "key.fill")
                        .font(.system(size: 35))
                        .foregroundColor(.brandGold)
                }
                
                Text("Código enviado")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.brandLight)
                
                Text("Hemos enviado un código de 6 dígitos a:")
                    .font(.subheadline)
                    .foregroundColor(.brandLight.opacity(0.7))
                    .multilineTextAlignment(.center)
                
                Text(resetManager.email)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.brandGold)
                    .multilineTextAlignment(.center)
                
                HStack {
                    Image(systemName: "clock.fill")
                        .foregroundColor(.brandLight.opacity(0.6))
                        .font(.caption)
                    Text("El código expira en 10 minutos")
                        .font(.caption)
                        .foregroundColor(.brandLight.opacity(0.6))
                }
            }
            
            VStack(spacing: 20) {
                // Campo de código
                VStack(spacing: 10) {
                    HStack(spacing: 8) {
                        ForEach(0..<6, id: \.self) { index in
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.brandDark.opacity(0.3))
                                    .frame(width: 45, height: 55)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(
                                                resetManager.verificationCode.count > index ?
                                                Color.brandGold : Color.brandGold.opacity(0.2),
                                                lineWidth: resetManager.verificationCode.count == index ? 2 : 1
                                            )
                                    )
                                
                                if resetManager.verificationCode.count > index {
                                    Text(String(resetManager.verificationCode[resetManager.verificationCode.index(resetManager.verificationCode.startIndex, offsetBy: index)]))
                                        .font(.title2)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.brandLight)
                                }
                            }
                        }
                    }
                    
                    TextField("", text: $resetManager.verificationCode)
                        .keyboardType(.numberPad)
                        .focused($isCodeFocused)
                        .opacity(0)
                        .onChange(of: resetManager.verificationCode) { _, newValue in
                            if newValue.count > 6 {
                                resetManager.verificationCode = String(newValue.prefix(6))
                            }
                        }
                }
                .onTapGesture {
                    isCodeFocused = true
                }
                
                if !resetManager.errorMessage.isEmpty {
                    ErrorMessageView(message: resetManager.errorMessage)
                }
                
                Button(action: {
                    Task {
                        await resetManager.verifyCode()
                    }
                }) {
                    HStack {
                        if resetManager.isLoading {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(.brandBlack)
                                .controlSize(.small)
                        } else {
                            Image(systemName: "checkmark.shield.fill")
                            Text("Verificar código")
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
                .disabled(resetManager.isLoading || resetManager.verificationCode.count != 6)
                .opacity(resetManager.verificationCode.count != 6 ? 0.6 : 1.0)
                
                Button(action: {
                    Task {
                        resetManager.errorMessage = ""
                        resetManager.verificationCode = ""
                        await resetManager.sendPasswordResetEmail()
                    }
                }) {
                    Text("¿No recibiste el código? Reenviar")
                        .font(.footnote)
                        .foregroundColor(.brandLight.opacity(0.7))
                        .underline()
                }
            }
            .padding(.horizontal, 30)
        }
        .onAppear {
            isCodeFocused = true
        }
    }
}

struct ProductionNewPasswordView: View {
    @EnvironmentObject var resetManager: ProductionPasswordResetManager
    @State private var showNewPassword = false
    @State private var showConfirmPassword = false
    @FocusState private var focusedField: Field?
    
    enum Field {
        case newPassword, confirmPassword
    }
    
    var body: some View {
        VStack(spacing: 30) {
            VStack(spacing: 15) {
                ZStack {
                    Circle()
                        .fill(Color.brandGold.opacity(0.1))
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: "lock.rotation")
                        .font(.system(size: 35))
                        .foregroundColor(.brandGold)
                }
                
                Text("Nueva contraseña")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.brandLight)
                
                Text("Ingresa tu nueva contraseña. Debe tener al menos 6 caracteres.")
                    .font(.subheadline)
                    .foregroundColor(.brandLight.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            
            VStack(spacing: 20) {
                
                CustomSecureField(
                    placeholder: "Nueva contraseña",
                    text: $resetManager.newPassword,
                    showPassword: $showNewPassword,
                    icon: "lock.fill"
                )
                .focused($focusedField, equals: .newPassword)
                .onChange(of: resetManager.newPassword) { _, newValue in
                    if newValue.count > 6 {
                        resetManager.newPassword = String(newValue.prefix(6))
                    }
                }

                CustomSecureField(
                    placeholder: "Repetir contraseña",
                    text: $resetManager.confirmPassword,
                    showPassword: $showConfirmPassword,
                    icon: "lock.fill"
                )
                .focused($focusedField, equals: .confirmPassword)
                .onChange(of: resetManager.confirmPassword) { _, newValue in
                    if newValue.count > 6 {
                        resetManager.confirmPassword = String(newValue.prefix(6))
                    }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    PasswordValidationRow(
                        text: "Al menos 6 caracteres",
                        isValid: resetManager.newPassword.count >= 6
                    )
                    
                    PasswordValidationRow(
                        text: "Las contraseñas coinciden",
                        isValid: !resetManager.confirmPassword.isEmpty && resetManager.newPassword == resetManager.confirmPassword
                    )
                }
                .padding(.horizontal, 20)
                
                if !resetManager.errorMessage.isEmpty {
                    ErrorMessageView(message: resetManager.errorMessage)
                }
                
                Button(action: {
                    Task {
                        await resetManager.updatePassword()
                    }
                }) {
                    HStack {
                        if resetManager.isLoading {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(.brandBlack)
                                .controlSize(.small)
                        } else {
                            Image(systemName: "arrow.clockwise.circle.fill")
                            Text("Actualizar contraseña")
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
                .disabled(resetManager.isLoading || resetManager.newPassword.count < 6 || resetManager.newPassword != resetManager.confirmPassword)
                .opacity((resetManager.newPassword.count < 6 || resetManager.newPassword != resetManager.confirmPassword) ? 0.6 : 1.0)
            }
            .padding(.horizontal, 30)
        }
        .onAppear {
            focusedField = .newPassword
        }
    }
}

struct ProductionSuccessView: View {
    @EnvironmentObject var resetManager: ProductionPasswordResetManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            VStack(spacing: 25) {
                ZStack {
                    Circle()
                        .fill(Color.brandSuccess.opacity(0.1))
                        .frame(width: 120, height: 120)
                    
                    Circle()
                        .fill(Color.brandSuccess.opacity(0.2))
                        .frame(width: 90, height: 90)
                    
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.brandSuccess)
                }
                .scaleEffect(1.0)
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: true)
                
                VStack(spacing: 10) {
                    Text("¡Contraseña actualizada!")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.brandLight)
                    
                    Text("Tu contraseña ha sido cambiada exitosamente. Ya puedes iniciar sesión con tu nueva contraseña.")
                        .font(.body)
                        .foregroundColor(.brandLight.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                }
            }
            
            Spacer()
            
            VStack(spacing: 15) {
                Button(action: {
                    resetManager.resetFlow()
                    dismiss()
                }) {
                    HStack {
                        Image(systemName: "arrow.right.circle.fill")
                        Text("Continuar al inicio de sesión")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient.brandPrimary
                            .clipShape(RoundedRectangle(cornerRadius: 15))
                    )
                    .foregroundColor(.brandBlack)
                }
                .padding(.horizontal, 30)
                
                Text("Recuerda guardar tu nueva contraseña en un lugar seguro")
                    .font(.caption)
                    .foregroundColor(.brandLight.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
    }
}

// MARK: - Helper Views
struct ErrorMessageView: View {
    let message: String
    
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.brandError)
            
            Text(message)
                .foregroundColor(.brandError)
                .font(.caption)
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.brandError.opacity(0.1))
        )
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

struct PasswordValidationRow: View {
    let text: String
    let isValid: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isValid ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isValid ? .brandSuccess : .brandLight.opacity(0.4))
                .font(.caption)
            
            Text(text)
                .font(.caption)
                .foregroundColor(isValid ? .brandLight : .brandLight.opacity(0.6))
            
            Spacer()
        }
    }
}
