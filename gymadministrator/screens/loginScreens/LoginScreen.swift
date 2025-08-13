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
import FirebaseFirestore
import FirebaseMessaging
import UserNotifications

// MARK: - User Data Model
// MARK: - User Data Model con FCM Token
struct UserData {
    var uid: String
    var email: String
    var displayName: String
    var idTipoDocumento: Int
    var numeroDocumento: String
    var nombre: String
    var apellido: String
    var telefono: String
    var fechaNacimiento: Date
    var direccion: String
    var activo: Bool
    var idGenero: Int
    var edad: String?
    var peso: String?
    var estatura: String?
    var fechaCreacion: Date
    var rol: String
    var fcmToken: String? // Nuevo campo para FCM token
    var lastTokenUpdate: Date? // Última actualización del token

    var dictionary: [String: Any] {
        var dict: [String: Any] = [
            "uid": uid,
            "email": email,
            "displayName": displayName,
            "idTipoDocumento": idTipoDocumento,
            "numeroDocumento": numeroDocumento,
            "nombre": nombre,
            "apellido": apellido,
            "telefono": telefono,
            "fechaNacimiento": Timestamp(date: fechaNacimiento),
            "direccion": direccion,
            "activo": activo,
            "idGenero": idGenero,
            "fechaCreacion": Timestamp(date: fechaCreacion),
            "rol": rol
        ]

        if let edad = edad, !edad.isEmpty { dict["edad"] = edad }
        if let peso = peso, !peso.isEmpty { dict["peso"] = peso }
        if let estatura = estatura, !estatura.isEmpty { dict["estatura"] = estatura }
        if let fcmToken = fcmToken, !fcmToken.isEmpty { dict["fcmToken"] = fcmToken }
        if let lastTokenUpdate = lastTokenUpdate { dict["lastTokenUpdate"] = Timestamp(date: lastTokenUpdate) }

        return dict
    }
    
    // Inicializador desde Firestore data
    init(from firestoreData: [String: Any], uid: String) {
        self.uid = uid
        self.email = firestoreData["email"] as? String ?? ""
        self.displayName = firestoreData["displayName"] as? String ?? ""
        self.idTipoDocumento = firestoreData["idTipoDocumento"] as? Int ?? 1
        self.numeroDocumento = firestoreData["numeroDocumento"] as? String ?? ""
        self.nombre = firestoreData["nombre"] as? String ?? ""
        self.apellido = firestoreData["apellido"] as? String ?? ""
        self.telefono = firestoreData["telefono"] as? String ?? ""
        self.fechaNacimiento = (firestoreData["fechaNacimiento"] as? Timestamp)?.dateValue() ?? Date()
        self.direccion = firestoreData["direccion"] as? String ?? ""
        self.activo = firestoreData["activo"] as? Bool ?? true
        self.idGenero = firestoreData["idGenero"] as? Int ?? 1
        self.edad = firestoreData["edad"] as? String
        self.peso = firestoreData["peso"] as? String
        self.estatura = firestoreData["estatura"] as? String
        self.fechaCreacion = (firestoreData["fechaCreacion"] as? Timestamp)?.dateValue() ?? Date()
        self.rol = firestoreData["rol"] as? String ?? "usuario"
        self.fcmToken = firestoreData["fcmToken"] as? String
        self.lastTokenUpdate = (firestoreData["lastTokenUpdate"] as? Timestamp)?.dateValue()
    }
    
    // Inicializador manual (para registro)
    init(
        uid: String,
        email: String,
        displayName: String,
        idTipoDocumento: Int,
        numeroDocumento: String,
        nombre: String,
        apellido: String,
        telefono: String,
        fechaNacimiento: Date,
        direccion: String,
        activo: Bool,
        idGenero: Int,
        edad: String? = nil,
        peso: String? = nil,
        estatura: String? = nil,
        fechaCreacion: Date,
        rol: String,
        fcmToken: String? = nil
    ) {
        self.uid = uid
        self.email = email
        self.displayName = displayName
        self.idTipoDocumento = idTipoDocumento
        self.numeroDocumento = numeroDocumento
        self.nombre = nombre
        self.apellido = apellido
        self.telefono = telefono
        self.fechaNacimiento = fechaNacimiento
        self.direccion = direccion
        self.activo = activo
        self.idGenero = idGenero
        self.edad = edad
        self.peso = peso
        self.estatura = estatura
        self.fechaCreacion = fechaCreacion
        self.rol = rol
        self.fcmToken = fcmToken
        self.lastTokenUpdate = fcmToken != nil ? Date() : nil
    }
}

// MARK: - Extensión para calcular edad
extension Date {
    func calculateAge() -> Int {
        let calendar = Calendar.current
        let now = Date()
        let ageComponents = calendar.dateComponents([.year], from: self, to: now)
        return ageComponents.year ?? 0
    }
    
    func calculateAgeString() -> String {
        return "\(calculateAge())"
    }
}

struct CustomDatePicker: View {
    let placeholder: String
    let icon: String
    @Binding var date: Date
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .foregroundColor(.brandGold)
                .frame(width: 20, height: 20)
            
            HStack {
                Text(placeholder)
                    .foregroundColor(.brandGold)
                    .font(.system(size: 16))
                
                Spacer()
                
                DatePicker(
                    "",
                    selection: $date,
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
                .labelsHidden()
                .accentColor(.brandGold)
                .colorScheme(.dark) // Forzar esquema oscuro
                .environment(\.colorScheme, .dark) // Asegurar tema oscuro
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.brandDark.opacity(0.3))
                .backdrop(blur: 10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(Color.brandGold.opacity(0.2), lineWidth: 1)
        )
    }
}

struct CustomPicker<T: Hashable>: View {
    let placeholder: String
    let icon: String
    @Binding var selection: T
    let options: [(T, String)]
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .foregroundColor(.brandGold)
                .frame(width: 20, height: 20)
            
            Text(placeholder)
                .foregroundColor(.brandGold)
                .font(.system(size: 16))
            
            Spacer()
            
            Picker(placeholder, selection: $selection) {
                ForEach(options, id: \.0) { option in
                    Text(option.1)
                        .foregroundColor(.brandGold)
                        .tag(option.0)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .accentColor(.brandGold)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.brandDark.opacity(0.3))
                .backdrop(blur: 10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(Color.brandGold.opacity(0.2), lineWidth: 1)
        )
    }
}

struct CustomSegmentedPicker<T: Hashable>: View {
    let placeholder: String
    let icon: String
    @Binding var selection: T
    let options: [(T, String)]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 15) {
                Image(systemName: icon)
                    .foregroundColor(.brandGold)
                    .frame(width: 20, height: 20)
                
                Text(placeholder)
                    .foregroundColor(.brandGold)
                    .font(.system(size: 16))
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            
            Picker(placeholder, selection: $selection) {
                ForEach(options, id: \.0) { option in
                    Text(option.1)
                        .foregroundColor(.brandGold)
                        .tag(option.0)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .accentColor(.brandGold)
            .colorScheme(.dark)
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.brandDark.opacity(0.3))
                .backdrop(blur: 10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(Color.brandGold.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Nuevo componente para mostrar edad calculada
struct CalculatedAgeDisplay: View {
    let birthDate: Date
    
    var calculatedAge: Int {
        birthDate.calculateAge()
    }
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: "calendar.badge.clock")
                .foregroundColor(.brandGold)
                .frame(width: 20, height: 20)
            
            HStack {
                Text("Edad Calculada")
                    .foregroundColor(.brandGold)
                    .font(.system(size: 16))
                
                Spacer()
                
                Text("\(calculatedAge) años")
                    .foregroundColor(.brandLight)
                    .font(.system(size: 16, weight: .semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.brandGold.opacity(0.2))
                    )
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.brandSuccess.opacity(0.1))
                .backdrop(blur: 10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(Color.brandSuccess.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Custom Components for Consistent Design
@MainActor
class AuthManager: ObservableObject {
    @Published var user: User?
    @Published var isLoading = true
    @Published var errorMessage = ""
    @Published var isAuthenticated = false
    @Published var currentUserData: UserData?
    
    private var authStateHandle: AuthStateDidChangeListenerHandle?
    private let fcmManager = FCMNotificationManager.shared
    
    init() {
        print("🔐 AuthManager: Inicializando...")
        
        // Inicializar FCM Manager
        fcmManager.setupNotifications()
        
        // Verificar estado inicial inmediatamente
        if let currentUser = Auth.auth().currentUser {
            print("🔐 AuthManager: Usuario ya autenticado encontrado: \(currentUser.email ?? "sin email")")
            self.user = currentUser
            self.isAuthenticated = true
            
            // Cargar datos del usuario
            Task {
                await self.loadUserData(uid: currentUser.uid)
                await MainActor.run {
                    self.isLoading = false
                }
            }
        } else {
            print("🔐 AuthManager: No hay usuario autenticado")
            self.isLoading = false
        }
        
        // Configurar listener para cambios futuros
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                print("🔐 AuthManager: Estado de auth cambió - Usuario: \(user?.email ?? "nil")")
                
                self?.user = user
                self?.isAuthenticated = user != nil
                
                if let uid = user?.uid {
                    await self?.loadUserData(uid: uid)
                } else {
                    self?.currentUserData = nil
                    print("🔐 AuthManager: Usuario desconectado - limpiando datos")
                }
                
                // Solo cambiar isLoading si estaba en true
                if self?.isLoading == true {
                    self?.isLoading = false
                }
            }
        }
    }
    
    deinit {
        if let handle = authStateHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
    
    func createUserWithFirestoreAndMembership(email: String, password: String, userData: UserData) async {
           await MainActor.run {
               self.isLoading = true
               self.errorMessage = ""
           }
           
           // Validaciones básicas
           guard !email.isEmpty else {
               await MainActor.run {
                   self.errorMessage = "❌ Por favor, ingresa tu correo electrónico"
                   self.isLoading = false
               }
               return
           }
           
           guard !password.isEmpty else {
               await MainActor.run {
                   self.errorMessage = "❌ Por favor, ingresa tu contraseña"
                   self.isLoading = false
               }
               return
           }
           
           guard password.count >= 6 else {
               await MainActor.run {
                   self.errorMessage = "❌ La contraseña debe tener al menos 6 caracteres"
                   self.isLoading = false
               }
               return
           }

           do {
               // 1️⃣ Crear usuario en Firebase Auth
               let result = try await Auth.auth().createUser(withEmail: email, password: password)
               let uid = result.user.uid
               print("✅ Usuario creado en Firebase Auth con UID: \(uid)")

               // 2️⃣ Actualizar displayName en el perfil
               if !userData.displayName.isEmpty {
                   let changeRequest = result.user.createProfileChangeRequest()
                   changeRequest.displayName = userData.displayName
                   try await changeRequest.commitChanges()
                   print("✅ DisplayName actualizado en Firebase Auth")
               }

               // 3️⃣ Obtener FCM token
               print("📱 Obteniendo FCM token para el nuevo usuario...")
               let fcmToken = await getFCMTokenForNewUser()
               
               // 4️⃣ Crear UserData actualizado con FCM token y edad calculada
               var userDataWithFCM = UserData(
                   uid: uid,
                   email: userData.email,
                   displayName: userData.displayName,
                   idTipoDocumento: userData.idTipoDocumento,
                   numeroDocumento: userData.numeroDocumento,
                   nombre: userData.nombre,
                   apellido: userData.apellido,
                   telefono: userData.telefono,
                   fechaNacimiento: userData.fechaNacimiento,
                   direccion: userData.direccion,
                   activo: userData.activo,
                   idGenero: userData.idGenero,
                   edad: userData.fechaNacimiento.calculateAgeString(), // ✅ EDAD CALCULADA AUTOMÁTICAMENTE
                   peso: userData.peso,
                   estatura: userData.estatura,
                   fechaCreacion: userData.fechaCreacion,
                   rol: userData.rol,
                   fcmToken: fcmToken
               )

               // 5️⃣ Guardar en colección "usuarios"
               let db = Firestore.firestore()
               try await db.collection("usuarios").document(uid).setData(userDataWithFCM.dictionary)
               print("✅ Usuario guardado en Firestore con edad calculada: \(userDataWithFCM.edad ?? "N/A")")
               
               // 6️⃣ ✨ NUEVO: Crear membresía inactiva automáticamente
               await createDefaultMembership(for: userDataWithFCM, in: db)
               
               // 7️⃣ Enviar notificación de bienvenida
               if let token = fcmToken {
                   await sendWelcomeNotification(to: token, userName: userData.nombre)
               }
               
               await MainActor.run {
                   self.errorMessage = ""
               }
           } catch {
               await MainActor.run {
                   self.errorMessage = self.translateFirebaseError(error)
                   print("❌ Error creando usuario: \(error.localizedDescription)")
               }
           }

           await MainActor.run {
               self.isLoading = false
           }
       }
        
        // ✨ NUEVA FUNCIÓN: Crear membresía por defecto
    private func createDefaultMembership(for userData: UserData, in db: Firestore) async {
            do {
                // ✅ CORRECCIÓN 1: Crear diccionario sin valores nil
                var defaultMembership: [String: Any] = [
                    "userUID": userData.uid,
                    "email": userData.email,
                    "tipoMembresia": "Básica",
                    "precio": 70000.0,
                    "fechaInicio": "",
                    "fechaVencimiento": "",
                    "activa": false,
                    "estadoDescripcion": "Pendiente de Activación",
                    "fechaCreacion": Timestamp(),
                    "requiereActivacion": true
                ]
                
                // ✅ CORRECCIÓN 2: Solo agregamos diasRestantes si tiene valor
                // En este caso, para membresías inactivas, simplemente no lo incluimos
                
                // Generar ID único para la membresía
                let membershipRef = db.collection("membresias").document()
                try await membershipRef.setData(defaultMembership)
                
                print("✅ Membresía inactiva creada para usuario: \(userData.nombre)")
                
            } catch {
                print("❌ Error creando membresía por defecto: \(error.localizedDescription)")
            }
        }
    
    // ✅ FUNCIÓN PARA TRADUCIR ERRORES DE FIREBASE
    private func translateFirebaseError(_ error: Error) -> String {
        guard let errorCode = AuthErrorCode(rawValue: (error as NSError).code) else {
            return "Ha ocurrido un error inesperado. Por favor, intenta de nuevo."
        }
        
        switch errorCode {
        // Errores de inicio de sesión
        case .userNotFound:
            return "❌ No existe una cuenta con este correo electrónico"
        case .wrongPassword:
            return "❌ La contraseña es incorrecta"
        case .invalidEmail:
            return "❌ El formato del correo electrónico no es válido"
        case .userDisabled:
            return "❌ Esta cuenta ha sido deshabilitada"
        case .tooManyRequests:
            return "❌ Demasiados intentos fallidos. Intenta más tarde"
        case .invalidCredential:
            return "❌ Las credenciales proporcionadas no son válidas"
        
        // Errores de registro
        case .emailAlreadyInUse:
            return "❌ Ya existe una cuenta con este correo electrónico"
        case .weakPassword:
            return "❌ La contraseña es muy débil. Debe tener al menos 6 caracteres"
        case .operationNotAllowed:
            return "❌ El registro con correo y contraseña no está habilitado"
        
        // Errores de red
        case .networkError:
            return "❌ Error de conexión. Verifica tu internet e intenta de nuevo"
        case .internalError:
            return "❌ Error interno del servidor. Intenta más tarde"
        
        case .invalidUserToken:
            return "❌ Tu sesión ha expirado. Inicia sesión nuevamente"
        case .userTokenExpired:
            return "❌ Tu sesión ha expirado. Inicia sesión nuevamente"
        
        // Errores de recuperación de contraseña
        case .missingEmail:
            return "❌ Por favor, ingresa tu correo electrónico"
        case .invalidRecipientEmail:
            return "❌ El correo electrónico no es válido"
        case .invalidSender:
            return "❌ Error en el envío del correo. Intenta más tarde"
        case .invalidMessagePayload:
            return "❌ Error en el formato del mensaje"
        
        // Error genérico
        default:
            return "❌ Ha ocurrido un error. Por favor, intenta de nuevo"
        }
    }
    
    func loadUserData(uid: String) async {
        print("🔐 AuthManager: Cargando datos del usuario: \(uid)")
        
        do {
            let doc = try await Firestore.firestore().collection("usuarios").document(uid).getDocument()
            if let data = doc.data() {
                let fetched = UserData(from: data, uid: uid)
                
                await MainActor.run {
                    self.currentUserData = fetched
                    print("✅ AuthManager: Datos de usuario cargados exitosamente con rol: \(fetched.rol)")
                }
            } else {
                print("⚠️ AuthManager: No se encontraron datos del usuario en Firestore")
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "❌ Error al cargar los datos del usuario"
                print("❌ AuthManager: Error cargando datos: \(error.localizedDescription)")
            }
        }
    }
    
    func updateUserData(_ userData: UserData) async {
        guard let uid = user?.uid else { return }
        
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = ""
        }

        do {
            try await Firestore.firestore().collection("usuarios")
                .document(uid)
                .setData(userData.dictionary, merge: true)

            // actualizar displayName en Firebase Auth si cambió
            if let authUser = self.user, authUser.displayName != userData.displayName {
                let changeRequest = authUser.createProfileChangeRequest()
                changeRequest.displayName = userData.displayName
                try await changeRequest.commitChanges()
                
                // Actualizar la propiedad para refrescar vistas
                await MainActor.run {
                    self.user = Auth.auth().currentUser
                }
            }

            // actualizar copia local
            await MainActor.run {
                self.currentUserData = userData
                print("✅ Datos de usuario actualizados")
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "❌ Error al actualizar los datos del usuario"
                print("❌ Error actualizando usuario: \(error.localizedDescription)")
            }
        }
        
        await MainActor.run {
            self.isLoading = false
        }
    }
    
    func signIn(email: String, password: String) async {
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = ""
        }
        
        // Validaciones básicas
        guard !email.isEmpty else {
            await MainActor.run {
                self.errorMessage = "❌ Por favor, ingresa tu correo electrónico"
                self.isLoading = false
            }
            return
        }
        
        guard !password.isEmpty else {
            await MainActor.run {
                self.errorMessage = "❌ Por favor, ingresa tu contraseña"
                self.isLoading = false
            }
            return
        }
        
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            print("✅ Usuario logueado: \(result.user.email ?? "")")
            
            // Actualizar FCM token después del login
            await updateFCMTokenForCurrentUser()
            
            await MainActor.run {
                self.errorMessage = ""
            }
        } catch {
            await MainActor.run {
                self.errorMessage = self.translateFirebaseError(error)
                print("❌ Error en login: \(error.localizedDescription)")
            }
        }
        
        await MainActor.run {
            self.isLoading = false
        }
    }
    
    func createUserWithFirestore(email: String, password: String, userData: UserData) async {
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = ""
        }
        
        // Validaciones básicas
        guard !email.isEmpty else {
            await MainActor.run {
                self.errorMessage = "❌ Por favor, ingresa tu correo electrónico"
                self.isLoading = false
            }
            return
        }
        
        guard !password.isEmpty else {
            await MainActor.run {
                self.errorMessage = "❌ Por favor, ingresa tu contraseña"
                self.isLoading = false
            }
            return
        }
        
        guard password.count >= 6 else {
            await MainActor.run {
                self.errorMessage = "❌ La contraseña debe tener al menos 6 caracteres"
                self.isLoading = false
            }
            return
        }

        do {
            // 1️⃣ Crear usuario en Firebase Auth
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            let uid = result.user.uid
            print("✅ Usuario creado en Firebase Auth con UID: \(uid)")

            // 2️⃣ Actualizar displayName en el perfil
            if !userData.displayName.isEmpty {
                let changeRequest = result.user.createProfileChangeRequest()
                changeRequest.displayName = userData.displayName
                try await changeRequest.commitChanges()
                print("✅ DisplayName actualizado en Firebase Auth")
            }

            // 3️⃣ Obtener FCM token antes de guardar en Firestore
            print("📱 Obteniendo FCM token para el nuevo usuario...")
            let fcmToken = await getFCMTokenForNewUser()
            
            // 4️⃣ Crear UserData actualizado con FCM token y edad calculada
            var userDataWithFCM = UserData(
                uid: uid,
                email: userData.email,
                displayName: userData.displayName,
                idTipoDocumento: userData.idTipoDocumento,
                numeroDocumento: userData.numeroDocumento,
                nombre: userData.nombre,
                apellido: userData.apellido,
                telefono: userData.telefono,
                fechaNacimiento: userData.fechaNacimiento,
                direccion: userData.direccion,
                activo: userData.activo,
                idGenero: userData.idGenero,
                edad: userData.fechaNacimiento.calculateAgeString(), // ✅ EDAD CALCULADA AUTOMÁTICAMENTE
                peso: userData.peso,
                estatura: userData.estatura,
                fechaCreacion: userData.fechaCreacion,
                rol: userData.rol,
                fcmToken: fcmToken
            )

            // 5️⃣ Guardar en colección "usuarios" con FCM token
            let db = Firestore.firestore()
            try await db.collection("usuarios").document(uid).setData(userDataWithFCM.dictionary)

            print("✅ Usuario guardado en Firestore con FCM token: \(fcmToken?.prefix(20) ?? "nil")... y edad: \(userDataWithFCM.edad ?? "N/A")")
            
            // 6️⃣ Enviar notificación de bienvenida
            if let token = fcmToken {
                await sendWelcomeNotification(to: token, userName: userData.nombre)
            }
            
            await MainActor.run {
                self.errorMessage = ""
            }
        } catch {
            await MainActor.run {
                self.errorMessage = self.translateFirebaseError(error)
                print("❌ Error creando usuario: \(error.localizedDescription)")
            }
        }

        await MainActor.run {
            self.isLoading = false
        }
    }
    
    // MARK: - Funciones auxiliares para FCM
    
    private func getFCMTokenForNewUser() async -> String? {
        return await withCheckedContinuation { continuation in
            Messaging.messaging().token { token, error in
                if let error = error {
                    print("❌ Error obteniendo FCM token para nuevo usuario: \(error.localizedDescription)")
                    continuation.resume(returning: nil)
                } else if let token = token {
                    print("✅ FCM token obtenido para nuevo usuario: \(String(token.prefix(20)))...")
                    continuation.resume(returning: token)
                } else {
                    print("⚠️ No se pudo obtener FCM token para nuevo usuario")
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    private func updateFCMTokenForCurrentUser() async {
        guard let uid = user?.uid else { return }
        
        if let fcmToken = await getFCMTokenForNewUser() {
            do {
                try await Firestore.firestore().collection("usuarios").document(uid).updateData([
                    "fcmToken": fcmToken,
                    "lastTokenUpdate": Timestamp()
                ])
                print("✅ FCM token actualizado para usuario existente")
            } catch {
                print("❌ Error actualizando FCM token: \(error.localizedDescription)")
            }
        }
    }
    
    private func sendWelcomeNotification(to token: String, userName: String) async {
        let payload: [String: Any] = [
            "to": token,
            "notification": [
                "title": "🏋️‍♂️ ¡Bienvenido a Gym Body Gold!",
                "body": "¡Hola \(userName)! Tu cuenta ha sido creada exitosamente. ¡Estamos emocionados de tenerte en nuestra familia fitness!",
                "sound": "default",
                "badge": 1
            ],
            "data": [
                "type": "welcome",
                "action": "account_created",
                "timestamp": "\(Date().timeIntervalSince1970)"
            ],
            "priority": "high"
        ]
        
        guard let url = URL(string: "https://fcm.googleapis.com/fcm/send") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // IMPORTANTE: Reemplaza con tu Server Key real
        let serverKey = "AAAA8gZ9pQY:APA91bHsample-server-key-here"
        request.setValue("key=\(serverKey)", forHTTPHeaderField: "Authorization")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    print("✅ Notificación de bienvenida enviada exitosamente")
                } else {
                    print("❌ Error enviando notificación de bienvenida. Status: \(httpResponse.statusCode)")
                }
            }
            
        } catch {
            print("❌ Error en request de notificación de bienvenida: \(error.localizedDescription)")
        }
    }
    
    func signOut() {
        print("🔐 AuthManager: Cerrando sesión...")
        
        do {
            try Auth.auth().signOut()
            
            // Limpiar datos locales inmediatamente
            Task { @MainActor in
                self.currentUserData = nil
                self.user = nil
                self.isAuthenticated = false
                self.errorMessage = ""
                print("✅ AuthManager: Sesión cerrada y datos limpiados")
            }
        } catch {
            Task { @MainActor in
                self.errorMessage = "❌ Error al cerrar sesión. Intenta de nuevo"
                print("❌ AuthManager: Error cerrando sesión: \(error.localizedDescription)")
            }
        }
    }
    
    func resetPassword(email: String) async {
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = ""
        }
        
        guard !email.isEmpty else {
            await MainActor.run {
                self.errorMessage = "❌ Por favor, ingresa tu correo electrónico"
                self.isLoading = false
            }
            return
        }
        
        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
            await MainActor.run {
                self.errorMessage = "✅ Correo de recuperación enviado exitosamente"
            }
        } catch {
            await MainActor.run {
                self.errorMessage = self.translateFirebaseError(error)
            }
        }
        
        await MainActor.run {
            self.isLoading = false
        }
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
    
    // Campos para registro - Información Personal
    @State private var idTipoDocumento = 1
    @State private var numeroDocumento = ""
    @State private var nombre = ""
    @State private var apellido = ""
    @State private var telefono = ""
    @State private var fechaNacimiento = Date()
    @State private var direccion = ""
    @State private var activo = true
    @State private var idGenero = 1
    
    // Campos para registro - Información Física (edad se calculará automáticamente)
    @State private var peso = ""
    @State private var estatura = ""
    
    // Listas para picker
    let tiposDocumento = [
        (1, "CC"),
        (2, "CE"),
        (3, "TI"),
        (4, "PA"),
        (5, "NIT"),
        (6, "RC")
    ]
    
    let generos = [
        (1, "Masculino"),
        (2, "Femenino")
    ]
    
    // ✅ COMPUTED PROPERTY para edad calculada
    private var calculatedAge: Int {
        fechaNacimiento.calculateAge()
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: email)
    }
    
    private func validateRegistrationFields() -> (isValid: Bool, errorMessage: String) {
        // Validar documento
        if numeroDocumento.isEmpty {
            return (false, "❌ El número de documento es requerido")
        }
        
        if numeroDocumento.count < 6 {
            return (false, "❌ El número de documento debe tener al menos 6 dígitos")
        }
        
        // Validar nombres
        if nombre.isEmpty {
            return (false, "❌ El nombre es requerido")
        }
        
        if nombre.count < 2 {
            return (false, "❌ El nombre debe tener al menos 2 caracteres")
        }
        
        if apellido.isEmpty {
            return (false, "❌ El apellido es requerido")
        }
        
        if apellido.count < 2 {
            return (false, "❌ El apellido debe tener al menos 2 caracteres")
        }
        
        // Validar teléfono
        if telefono.isEmpty {
            return (false, "❌ El teléfono es requerido")
        }
        
        if telefono.count < 7 {
            return (false, "❌ El teléfono debe tener al menos 7 dígitos")
        }
        
        // ✅ VALIDACIÓN DE EDAD CALCULADA
        if calculatedAge < 10 {
            return (false, "❌ Debes tener al menos 10 años para registrarte")
        }
        
        if calculatedAge > 100 {
            return (false, "❌ Por favor, verifica tu fecha de nacimiento")
        }
        
        // Validar campos opcionales si están llenos
        if !peso.isEmpty {
            if let pesoNum = Double(peso) {
                if pesoNum < 20 || pesoNum > 300 {
                    return (false, "❌ El peso debe estar entre 20 y 300 kg")
                }
            } else {
                return (false, "❌ El peso debe ser un número válido")
            }
        }
        
        if !estatura.isEmpty {
            if let estaturaNum = Int(estatura) {
                if estaturaNum < 100 || estaturaNum > 250 {
                    return (false, "❌ La estatura debe estar entre 100 y 250 cm")
                }
            } else {
                return (false, "❌ La estatura debe ser un número válido")
            }
        }
        
        // Validar email
        if !isValidEmail(email) {
            return (false, "❌ El formato del email no es válido")
        }
        
        // Validar contraseña
        if password.count < 6 {
            return (false, "❌ La contraseña debe tener al menos 6 caracteres")
        }
        
        return (true, "")
    }
    
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
                        LogoWithGlow()
                        TitleSection(isSignUp: isSignUp)
                    }
                    .padding(.bottom, 50)
                    
                    // Tarjeta de login
                    VStack(spacing: 30) {
                        // Toggle entre Login/Signup
                        ZStack {
                            RoundedRectangle(cornerRadius: 25)
                                .fill(Color.brandDark)
                            
                            GeometryReader { geometry in
                                RoundedRectangle(cornerRadius: 25)
                                    .fill(Color.brandGold)
                                    .frame(width: geometry.size.width / 2)
                                    .offset(x: isSignUp ? geometry.size.width / 2 : 0)
                                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: isSignUp)
                            }
                            
                            HStack(spacing: 0) {
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
                            .zIndex(1)
                        }
                        
                        // Formulario
                        VStack(spacing: 20) {
                            if isSignUp {
                                // Sección: Información de Documento
                                VStack(alignment: .leading, spacing: 15) {
                                    HStack {
                                        Image(systemName: "doc.text.fill")
                                            .foregroundColor(.brandGold)
                                            .font(.caption)
                                        Text("Información de Documento")
                                            .foregroundColor(.brandLight)
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 5)
                                    
                                    CustomPicker(
                                        placeholder: "Tipo de Documento",
                                        icon: "doc.text.fill",
                                        selection: $idTipoDocumento,
                                        options: tiposDocumento
                                    )
                                    
                                    CustomTextField(
                                        placeholder: "Número de Documento",
                                        text: $numeroDocumento,
                                        icon: "number.circle.fill",
                                        keyboardType: .numberPad,
                                        inputFilter: .numbersOnly,
                                        maxLength: 15
                                    )

                                }
                                .padding(.bottom, 10)
                                
                                // Sección: Información Personal
                                VStack(alignment: .leading, spacing: 15) {
                                    HStack {
                                        Image(systemName: "person.fill")
                                            .foregroundColor(.brandGold)
                                            .font(.caption)
                                        Text("Información Personal")
                                            .foregroundColor(.brandLight)
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 5)
                                    
                                    CustomTextField(
                                        placeholder: "Nombre",
                                        text: $nombre,
                                        icon: "person.fill",
                                        keyboardType: .default,
                                        inputFilter: .lettersAndSpaces,
                                        maxLength: 30
                                    )
                                    
                                    CustomTextField(
                                        placeholder: "Apellido",
                                        text: $apellido,
                                        icon: "person.fill",
                                        keyboardType: .default,
                                        inputFilter: .lettersAndSpaces,
                                        maxLength: 30
                                    )
                                    
                                    CustomTextField(
                                        placeholder: "Nombre de Usuario",
                                        text: $displayName,
                                        icon: "at.circle.fill"
                                    )
                                    
                                    CustomDatePicker(
                                        placeholder: "Fecha de Nacimiento",
                                        icon: "calendar.circle.fill",
                                        date: $fechaNacimiento
                                    )
                                    
                                    // ✅ NUEVO: Mostrar edad calculada automáticamente
                                    CalculatedAgeDisplay(birthDate: fechaNacimiento)
                                        .animation(.easeInOut(duration: 0.3), value: fechaNacimiento)
                                    
                                    CustomSegmentedPicker(
                                        placeholder: "Género",
                                        icon: "person.2.fill",
                                        selection: $idGenero,
                                        options: generos
                                    )
                                }
                                .padding(.bottom, 10)
                                
                                // Sección: Información de Contacto
                                VStack(alignment: .leading, spacing: 15) {
                                    HStack {
                                        Image(systemName: "phone.fill")
                                            .foregroundColor(.brandGold)
                                            .font(.caption)
                                        Text("Información de Contacto")
                                            .foregroundColor(.brandLight)
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 5)
                                    
                                    CustomTextField(
                                        placeholder: "Teléfono",
                                        text: $telefono,
                                        icon: "phone.fill",
                                        keyboardType: .phonePad,
                                        inputFilter: .numbersOnly,
                                        maxLength: 12
                                    )
                                    
                                    CustomTextField(
                                        placeholder: "Dirección",
                                        text: $direccion,
                                        icon: "house.fill"
                                    )
                                }
                                .padding(.bottom, 10)
                                
                                // Sección: Información Física (SIN campo de edad manual)
                                VStack(alignment: .leading, spacing: 15) {
                                    HStack {
                                        Image(systemName: "figure.walk")
                                            .foregroundColor(.brandGold)
                                            .font(.caption)
                                        Text("Información Física (Opcional)")
                                            .foregroundColor(.brandLight)
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 5)
                                    
                                    // ✅ REMOVIDO: Campo manual de edad - ahora es automático
                                    
                                    CustomTextField(
                                        placeholder: "Peso (kg)",
                                        text: $peso,
                                        icon: "scalemass",
                                        keyboardType: .decimalPad,
                                        inputFilter: .decimal,
                                        maxLength: 6
                                    )
                                    
                                    CustomTextField(
                                        placeholder: "Estatura (cm)",
                                        text: $estatura,
                                        icon: "ruler",
                                        keyboardType: .numberPad,
                                        inputFilter: .numbersOnly,
                                        maxLength: 3
                                    )
                                }
                                .padding(.bottom, 10)
                                
                                // Separador visual
                                Rectangle()
                                    .fill(Color.brandGold.opacity(0.3))
                                    .frame(height: 1)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                            }
                            
                            // Sección: Credenciales de Acceso
                            VStack(alignment: .leading, spacing: 15) {
                                if isSignUp {
                                    HStack {
                                        Image(systemName: "key.fill")
                                            .foregroundColor(.brandGold)
                                            .font(.caption)
                                        Text("Credenciales de Acceso")
                                            .foregroundColor(.brandLight)
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 5)
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
                                .onChange(of: password) { _, newValue in
                                    if newValue.count > 6 {
                                        password = String(newValue.prefix(6))
                                    }
                                }
                            }
                        }
                        .animation(.spring(), value: isSignUp)
                        
                        // Mensaje de error/éxito
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
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill((authManager.errorMessage.contains("📧") ? Color.brandSuccess : Color.brandError).opacity(0.1))
                            )
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }
                        
                        // Botón principal
                        Button(action: {
                            Task {
                                if isSignUp {
                                    let validation = validateRegistrationFields()
                                                if !validation.isValid {
                                                    authManager.errorMessage = validation.errorMessage
                                                    return
                                                }
                                                
                                                // Limpiar mensaje de error si todo está bien
                                                authManager.errorMessage = ""
                                    
                                            print("🎯 INICIANDO REGISTRO DESDE BUTTON")
                                            
                                            // ✅ CREAR OBJETO UserData SIN EDAD MANUAL - se calculará automáticamente
                                            let userData = UserData(
                                                uid: "", // Se asignará automáticamente en signUp
                                                email: email,
                                                displayName: displayName,
                                                idTipoDocumento: idTipoDocumento,
                                                numeroDocumento: numeroDocumento,
                                                nombre: nombre,
                                                apellido: apellido,
                                                telefono: telefono,
                                                fechaNacimiento: fechaNacimiento,
                                                direccion: direccion,
                                                activo: activo,
                                                idGenero: idGenero,
                                                edad: nil, // ✅ SE CALCULARÁ AUTOMÁTICAMENTE EN AuthManager
                                                peso: peso.isEmpty ? nil : peso,
                                                estatura: estatura.isEmpty ? nil : estatura,
                                                fechaCreacion: Date(),
                                                rol: "usuario"
                                            )
                                            
                                            print("🎯 DATOS PREPARADOS, LLAMANDO A createUserWithFirestoreAndMembership")
                                            print("🎯 Edad que se calculará: \(fechaNacimiento.calculateAge()) años")
                                            
                                            // ✅ NUEVA FUNCIÓN QUE CREA USUARIO + MEMBRESÍA INACTIVA
                                            await authManager.createUserWithFirestoreAndMembership(email: email, password: password, userData: userData)
                                            print("🎯 createUserWithFirestoreAndMembership COMPLETADO")
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
                        .disabled(authManager.isLoading || email.isEmpty || password.isEmpty || (isSignUp && (nombre.isEmpty || apellido.isEmpty || numeroDocumento.isEmpty)))
                        .opacity((email.isEmpty || password.isEmpty || (isSignUp && (nombre.isEmpty || apellido.isEmpty || numeroDocumento.isEmpty))) ? 0.6 : 1.0)
                        .scaleEffect(authManager.isLoading ? 0.95 : 1.0)
                        .animation(.spring(), value: authManager.isLoading)
                        
                        // Link de recuperación de contraseña
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
        .sheet(isPresented: $showForgotPassword) {
            ProductionPasswordResetView() // En lugar de PasswordResetView()
                }
    }
}
