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

@MainActor
class ClassesExcusesManager: ObservableObject {
    @Published var upcomingClasses: [GymClass] = []
    @Published var pendingExcuses: [ExcuseRequest] = []
    @Published var isLoading = false
    @Published var errorMessage = ""
    
    // Manager de clases diarias
    @Published var dailyClassManager = DailyClassManager()
    
    private let db = Firestore.firestore()
    private var classesListener: ListenerRegistration?
    private var excusesListener: ListenerRegistration?
    
    init() {
        print("🏁 Inicializando ClassesExcusesManager con clases diarias...")
        
        // Primero generar clases diarias, luego cargar
        Task {
            await dailyClassManager.generateDailyClasses()
            loadClasses()
            loadExcuses()
        }
    }
    
    deinit {
        classesListener?.remove()
        excusesListener?.remove()
        print("🧹 ClassesExcusesManager limpiado")
    }
    
    // MARK: - Carga de Clases (Incluyendo Diarias)
    func loadClasses() {
        print("🔄 Cargando todas las clases...")
        isLoading = true
        
        classesListener?.remove()
        
        classesListener = db.collection("gymClasses")
            .whereField("isActive", isEqualTo: true)
            .addSnapshotListener { [weak self] snapshot, error in
                DispatchQueue.main.async {
                    self?.isLoading = false
                    
                    if let error = error {
                        print("❌ Error cargando clases: \(error.localizedDescription)")
                        self?.errorMessage = "Error cargando clases: \(error.localizedDescription)"
                        return
                    }
                    
                    guard let documents = snapshot?.documents else {
                        print("📭 No hay clases en Firestore")
                        self?.upcomingClasses = []
                        return
                    }
                    
                    let allClasses = documents.compactMap { doc -> GymClass? in
                        do {
                            var gymClass = try doc.data(as: GymClass.self)
                            gymClass.id = doc.documentID
                            return gymClass
                        } catch {
                            print("⚠️ Error parseando clase \(doc.documentID): \(error)")
                            return nil
                        }
                    }
                    
                    // Filtrar y ordenar clases futuras
                    let now = Date()
                    let futureClasses = allClasses
                        .filter { $0.date > now }
                        .sorted { $0.date < $1.date }
                    
                    self?.upcomingClasses = futureClasses
                    print("✅ Clases cargadas: \(futureClasses.count)")
                    
                    // Separar clases obligatorias y opcionales para debug
                    let obligatoryClasses = futureClasses.filter { $0.name == "Entrenamiento General" }
                    let optionalClasses = futureClasses.filter { $0.name != "Entrenamiento General" }
                    
                    print("📊 Desglose de clases:")
                    print("   - Obligatorias (diarias): \(obligatoryClasses.count)")
                    print("   - Opcionales: \(optionalClasses.count)")
                }
            }
    }
    
    // MARK: - Carga de Excusas (Sin cambios)
    func loadExcuses() {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("⚠️ Usuario no autenticado")
            return
        }
        
        print("🔄 Cargando excusas para usuario: \(userId)")
        
        excusesListener?.remove()
        
        excusesListener = db.collection("excuses")
            .whereField("userId", isEqualTo: userId)
            .addSnapshotListener { [weak self] snapshot, error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("❌ Error cargando excusas: \(error.localizedDescription)")
                        self?.errorMessage = "Error cargando excusas: \(error.localizedDescription)"
                        return
                    }
                    
                    guard let documents = snapshot?.documents else {
                        print("📭 No hay excusas")
                        self?.pendingExcuses = []
                        return
                    }
                    
                    let allExcuses = documents.compactMap { doc -> ExcuseRequest? in
                        do {
                            return try doc.data(as: ExcuseRequest.self)
                        } catch {
                            print("⚠️ Error parseando excusa \(doc.documentID): \(error)")
                            return nil
                        }
                    }
                    
                    let sortedExcuses = allExcuses.sorted { $0.createdAt > $1.createdAt }
                    self?.pendingExcuses = sortedExcuses
                    print("✅ Excusas cargadas: \(sortedExcuses.count)")
                }
            }
    }
    
    // MARK: - Funciones para Clases (Sin cambios)
    func addClass(_ gymClass: GymClass) async {
        print("➕ Agregando clase manual: \(gymClass.name)")
        
        do {
            try db.collection("gymClasses").document(gymClass.id).setData(from: gymClass)
            print("✅ Clase agregada: \(gymClass.name)")
            
            DispatchQueue.main.async {
                self.errorMessage = ""
            }
        } catch {
            let errorMsg = "Error agregando clase: \(error.localizedDescription)"
            print("❌ \(errorMsg)")
            
            DispatchQueue.main.async {
                self.errorMessage = errorMsg
            }
        }
    }
    
    func updateClass(_ gymClass: GymClass) async {
        print("📝 Actualizando clase: \(gymClass.name)")
        
        do {
            try db.collection("gymClasses").document(gymClass.id).setData(from: gymClass, merge: true)
            print("✅ Clase actualizada: \(gymClass.name)")
            
            DispatchQueue.main.async {
                self.errorMessage = ""
            }
        } catch {
            let errorMsg = "Error actualizando clase: \(error.localizedDescription)"
            print("❌ \(errorMsg)")
            
            DispatchQueue.main.async {
                self.errorMessage = errorMsg
            }
        }
    }
    
    func deleteClass(_ classId: String) async {
        print("🗑️ Eliminando clase: \(classId)")
        
        do {
            try await db.collection("gymClasses").document(classId).updateData([
                "isActive": false,
                "updatedAt": FieldValue.serverTimestamp()
            ])
            print("✅ Clase marcada como inactiva: \(classId)")
            
            DispatchQueue.main.async {
                self.errorMessage = ""
            }
        } catch {
            let errorMsg = "Error eliminando clase: \(error.localizedDescription)"
            print("❌ \(errorMsg)")
            
            DispatchQueue.main.async {
                self.errorMessage = errorMsg
            }
        }
    }
    
    // MARK: - Funciones para Excusas (Sin cambios)
    func requestExcuse(for gymClass: GymClass, reason: String) async {
        guard let userId = Auth.auth().currentUser?.uid else {
            DispatchQueue.main.async {
                self.errorMessage = "Usuario no autenticado"
            }
            return
        }
        
        print("📝 Solicitando excusa para clase: \(gymClass.name)")
        
        let excuse = ExcuseRequest(
            classId: gymClass.id,
            className: gymClass.name,
            date: gymClass.date,
            reason: reason,
            status: .pending,
            userId: userId,
            createdAt: Date()
        )
        
        do {
            try db.collection("excuses").document(excuse.id).setData(from: excuse)
            print("✅ Excusa solicitada para: \(gymClass.name)")
            
            DispatchQueue.main.async {
                self.errorMessage = ""
            }
        } catch {
            let errorMsg = "Error solicitando excusa: \(error.localizedDescription)"
            print("❌ \(errorMsg)")
            
            DispatchQueue.main.async {
                self.errorMessage = errorMsg
            }
        }
    }
    
    func updateExcuseStatus(_ excuseId: String, status: ExcuseStatus) async {
        print("📝 Actualizando estado de excusa: \(excuseId) a \(status.text)")
        
        do {
            try await db.collection("excuses").document(excuseId).updateData([
                "status": status.rawValue,
                "updatedAt": FieldValue.serverTimestamp()
            ])
            print("✅ Estado de excusa actualizado: \(status.text)")
            
            DispatchQueue.main.async {
                self.errorMessage = ""
            }
        } catch {
            let errorMsg = "Error actualizando excusa: \(error.localizedDescription)"
            print("❌ \(errorMsg)")
            
            DispatchQueue.main.async {
                self.errorMessage = errorMsg
            }
        }
    }
    
    // MARK: - Funciones para Gestión de Clases Diarias
    func regenerateDailyClasses() {
        print("🔄 Regenerando clases diarias...")
        dailyClassManager.forceRegenerateClasses()
    }
    
    func generateNextWeekClasses() {
        print("📅 Generando clases para la próxima semana...")
        Task {
            await dailyClassManager.generateClassesForNextWeek()
        }
    }
}

struct DailyClassesConfigView: View {
    @ObservedObject var classesManager: ClassesExcusesManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Estado actual
                VStack(alignment: .leading, spacing: 12) {
                    Text("Estado de Clases Diarias")
                        .font(.headline)
                        .foregroundColor(.brandGold)
                    
                    if let lastGeneration = classesManager.dailyClassManager.lastGenerationDate {
                        Text("Última generación: \(lastGeneration, format: .dateTime.day().month().year())")
                            .font(.subheadline)
                            .foregroundColor(.brandLight)
                    } else {
                        Text("Clases diarias no generadas")
                            .font(.subheadline)
                            .foregroundColor(.brandError)
                    }
                    
                    Text("Clases próximas: \(classesManager.upcomingClasses.count)")
                        .font(.subheadline)
                        .foregroundColor(.brandWhite)
                }
                .padding()
                .background(Color.brandDark)
                .cornerRadius(12)
                
                // Acciones
                VStack(spacing: 16) {
                    Button("Regenerar Clases Diarias") {
                        classesManager.regenerateDailyClasses()
                    }
                    .buttonStyle(BrandButtonStyle(style: .primary))
                    
                    Button("Generar Próxima Semana") {
                        classesManager.generateNextWeekClasses()
                    }
                    .buttonStyle(BrandButtonStyle(style: .secondary))
                    
                    if classesManager.dailyClassManager.isGeneratingClasses {
                        HStack {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .brandGold))
                                .controlSize(.small)
                            
                            Text("Generando clases...")
                                .foregroundColor(.brandLight)
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
            .background(Color.brandBlack)
            .navigationTitle("Clases Diarias")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cerrar") {
                        dismiss()
                    }
                    .foregroundColor(.brandGold)
                }
            }
        }
    }
}

// MARK: - Button Styles
struct BrandButtonStyle: ButtonStyle {
    let style: BrandButtonType
    
    enum BrandButtonType {
        case primary
        case secondary
        case outline
        case ghost
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 12)
            .padding(.horizontal, 24)
            .background(backgroundColor)
            .foregroundColor(foregroundColor)
            .cornerRadius(25)
            .overlay(
                RoundedRectangle(cornerRadius: 25)
                    .stroke(borderColor, lineWidth: borderWidth)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
    
    private var backgroundColor: Color {
        switch style {
        case .primary:
            return .brandGold
        case .secondary:
            return .brandDark
        case .outline:
            return .clear
        case .ghost:
            return .clear
        }
    }
    
    private var foregroundColor: Color {
        switch style {
        case .primary:
            return .brandBlack
        case .secondary:
            return .brandGold
        case .outline:
            return .brandGold
        case .ghost:
            return .brandGold
        }
    }
    
    private var borderColor: Color {
        switch style {
        case .primary, .secondary, .ghost:
            return .clear
        case .outline:
            return .brandGold
        }
    }
    
    private var borderWidth: CGFloat {
        switch style {
        case .outline:
            return 2
        default:
            return 0
        }
    }
}

// MARK: - Text Styles
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

// MARK: - Shadow Presets
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

// MARK: - Preview Helper
struct BrandColorsPreview: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Colores principales
                VStack(alignment: .leading, spacing: 10) {
                    Text("Colores Principales")
                        .brandTitle()
                    
                    HStack(spacing: 15) {
                        ColorSwatch(color: .brandGold, name: "Gold")
                        ColorSwatch(color: .brandDark, name: "Dark")
                        ColorSwatch(color: .brandAccent, name: "Accent")
                        ColorSwatch(color: .brandLight, name: "Light")
                    }
                }
                
                // Botones de ejemplo
                VStack(alignment: .leading, spacing: 15) {
                    Text("Estilos de Botones")
                        .brandSubtitle()
                    
                    Button("Botón Primario") { }
                        .buttonStyle(BrandButtonStyle(style: .primary))
                    
                    Button("Botón Secundario") { }
                        .buttonStyle(BrandButtonStyle(style: .secondary))
                    
                    Button("Botón Outline") { }
                        .buttonStyle(BrandButtonStyle(style: .outline))
                    
                    Button("Botón Ghost") { }
                        .buttonStyle(BrandButtonStyle(style: .ghost))
                }
                
                // Gradientes
                VStack(alignment: .leading, spacing: 15) {
                    Text("Gradientes")
                        .brandSubtitle()
                    
                    Rectangle()
                        .fill(LinearGradient.brandPrimary)
                        .frame(height: 60)
                        .cornerRadius(10)
                    
                    Rectangle()
                        .fill(LinearGradient.brandDark)
                        .frame(height: 60)
                        .cornerRadius(10)
                }
                
                Spacer()
            }
            .padding()
        }
        .background(Color.brandBlack)
    }
}

struct ColorSwatch: View {
    let color: Color
    let name: String
    
    var body: some View {
        VStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(color)
                .frame(width: 60, height: 60)
                .brandShadow()
            
            Text(name)
                .brandCaption()
        }
    }
}

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

// MARK: - Custom TextField
struct CustomTextField: View {
    let placeholder: String
    @Binding var text: String
    let icon: String
    var keyboardType: UIKeyboardType = .default
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .foregroundColor(.brandGold)
                .frame(width: 20)
            
            TextField(placeholder, text: $text)
                .keyboardType(keyboardType)
                .autocapitalization(keyboardType == .emailAddress ? .none : .words)
                .disableAutocorrection(keyboardType == .emailAddress)
                .foregroundColor(.brandWhite)
                .placeholder(when: text.isEmpty) {
                    Text(placeholder)
                        .foregroundColor(.brandLight)
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
            
            Text(isSignUp ? "Crear cuenta de administrador" : "Bienvenido de vuelta")
                .font(.subheadline)
                .foregroundColor(.brandLight.opacity(0.8))
        }
    }
}

// MARK: - AdminDashboard
struct AdminDashboard: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var dashboardManager = DashboardManager()
    @StateObject private var miembroManager = MiembroManager()
    @State private var showingMiembros = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header con información del usuario
                    HeaderCard(authManager: authManager, dashboardManager: dashboardManager, miembroManager: miembroManager)
                    
                    // Información de membresía
                    MembershipInfoCard(dashboardManager: dashboardManager)
                    
                    CalendarNotification()
                    
                    // Calendario y excusas - ACTUALIZADO
                    //CalendarExcusesCard()
                    
                    Spacer(minLength: 20)
                }
                .padding()
            }
            .navigationTitle("Gym Body Gold")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cerrar Sesión") {
                        authManager.signOut()
                    }
                    .foregroundColor(.brandGold)
                }
            }
            .onAppear {
                dashboardManager.loadDashboardData()
            }
            .sheet(isPresented: $showingMiembros) {
                MiembrosListView()
            }
        }
    }
}

// MARK: - Dashboard Manager
@MainActor
class DashboardManager: ObservableObject {
    @Published var membershipType: String = "Premium Gold"
    @Published var daysUntilPayment: Int = 7
    @Published var paymentAmount: Double = 120000
    @Published var membershipExpiryDate: Date = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    
    // Stats
    @Published var membersCount: Int = 145
    @Published var activeMemberships: Int = 132
    @Published var equipmentCount: Int = 45
    
    // Ya no necesitamos estos aquí porque los maneja ClassesExcusesManager
    // @Published var pendingExcuses: [ExcuseRequest] = []
    // @Published var upcomingClasses: [GymClass] = []
    // @Published var showExcuseForm = false
    
    init() {
        loadMockData()
    }
    
    func loadDashboardData() {
        // Simular carga de datos
        calculatePaymentDays()
        // Ya no cargamos excusas y clases aquí
    }
    
    private func calculatePaymentDays() {
        let calendar = Calendar.current
        let today = Date()
        let components = calendar.dateComponents([.day], from: today, to: membershipExpiryDate)
        daysUntilPayment = components.day ?? 0
    }
    
    private func loadMockData() {
        // Datos de ejemplo
        membershipType = "Premium Gold"
        paymentAmount = 120000
        daysUntilPayment = 7
    }
}

struct GymClass: Identifiable, Codable {
    var id: String = UUID().uuidString
    let name: String
    let date: Date
    let instructor: String
    let description: String
    let maxCapacity: Int
    var currentEnrollment: Int = 0
    var isActive: Bool = true
    
    enum CodingKeys: String, CodingKey {
        case id, name, date, instructor, description, maxCapacity, currentEnrollment, isActive
    }
}


struct ExcuseRequest: Identifiable, Codable {
    var id: String = UUID().uuidString
    let classId: String
    let className: String
    let date: Date
    let reason: String
    var status: ExcuseStatus
    let userId: String
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id, classId, className, date, reason, status, userId, createdAt
    }
}

enum ExcuseStatus: String, CaseIterable, Codable {
    case pending = "pending"
    case approved = "approved"
    case rejected = "rejected"
    
    var color: Color {
        switch self {
        case .pending: return .brandWarning
        case .approved: return .brandSuccess
        case .rejected: return .brandError
        }
    }
    
    var text: String {
        switch self {
        case .pending: return "Pendiente"
        case .approved: return "Aprobada"
        case .rejected: return "Rechazada"
        }
    }
    
    var icon: String {
        switch self {
        case .pending: return "clock.fill"
        case .approved: return "checkmark.circle.fill"
        case .rejected: return "xmark.circle.fill"
        }
    }
}

// MARK: - Header Card
struct HeaderCard: View {
    let authManager: AuthManager
    @ObservedObject var dashboardManager: DashboardManager
    @ObservedObject var miembroManager: MiembroManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("¡Bienvenido!")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.brandDark)
                    
                    Text(authManager.user?.displayName ?? authManager.user?.email ?? "Administrador")
                        .font(.subheadline)
                        .foregroundColor(.brandDark)
                }
                
                Spacer()
                
                Image("bodyGoldLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 60, height: 60)
            }
        }
        .padding()
        .background(LinearGradient.brandSoft)
        .cornerRadius(15)
        .brandShadow()
    }
}

// MARK: - Membership Info Card
struct MembershipInfoCard: View {
    @ObservedObject var dashboardManager: DashboardManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Image(systemName: "creditcard.fill")
                    .foregroundColor(.brandGold)
                    .font(.title2)
                
                Text("Mi Membresía")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.brandGold)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Tipo:")
                        .foregroundColor(.brandLight)
                    Spacer()
                    Text(dashboardManager.membershipType)
                        .fontWeight(.semibold)
                        .foregroundColor(.brandWhite)
                }
                
                HStack {
                    Text("Próximo pago:")
                        .foregroundColor(.brandLight)
                    Spacer()
                    Text("$\(Int(dashboardManager.paymentAmount).formatted())")
                        .fontWeight(.semibold)
                        .foregroundColor(.brandGold)
                }
                
                HStack {
                    Text("Días restantes:")
                        .foregroundColor(.brandLight)
                    Spacer()
                    HStack {
                        Text("\(dashboardManager.daysUntilPayment)")
                            .fontWeight(.bold)
                            .foregroundColor(dashboardManager.daysUntilPayment <= 3 ? .brandError : .brandSuccess)
                        Text("días")
                            .foregroundColor(.brandLight)
                    }
                }
                
                if dashboardManager.daysUntilPayment <= 5 {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.brandWarning)
                        Text("¡Renovación próxima!")
                            .font(.caption)
                            .foregroundColor(.brandWarning)
                        Spacer()
                    }
                    .padding(.top, 5)
                }
            }
            
            Button(action: {
                // Acción para renovar membresía
            }) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Renovar Membresía")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(LinearGradient.brandPrimary)
                .foregroundColor(.brandBlack)
                .cornerRadius(10)
            }
        }
        .padding()
        .background(Color.brandDark)
        .cornerRadius(15)
        .brandShadow()
    }
}

struct ExcuseFormView: View {
    @ObservedObject var classesManager: ClassesExcusesManager
    let availableClasses: [GymClass]
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedClassId = ""
    @State private var reason = ""
    @State private var isSubmitting = false
    
    var selectedClass: GymClass? {
        availableClasses.first { $0.id == selectedClassId }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Seleccionar Clase") {
                    if availableClasses.isEmpty {
                        Text("No hay clases disponibles")
                            .foregroundColor(.secondary)
                    } else {
                        Picker("Clase", selection: $selectedClassId) {
                            Text("Seleccionar clase...")
                                .tag("")
                            
                            ForEach(availableClasses) { gymClass in
                                VStack(alignment: .leading) {
                                    Text(gymClass.name)
                                        .font(.headline)
                                    Text("\(gymClass.date, format: .dateTime.day().month()) - \(gymClass.instructor)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .tag(gymClass.id)
                            }
                        }
                        .pickerStyle(.navigationLink)
                    }
                }
                
                if selectedClass != nil {
                    Section("Detalles de la Clase") {
                        HStack {
                            Text("Fecha:")
                            Spacer()
                            Text(selectedClass!.date, format: .dateTime.weekday().day().month().hour().minute())
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("Instructor:")
                            Spacer()
                            Text(selectedClass!.instructor)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section("Motivo de la Excusa") {
                    TextField("Describe el motivo de tu excusa", text: $reason, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                if !classesManager.errorMessage.isEmpty {
                    Section {
                        Text(classesManager.errorMessage)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Solicitar Excusa")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Enviar") {
                        submitExcuse()
                    }
                    .disabled(selectedClassId.isEmpty || reason.isEmpty || isSubmitting)
                }
            }
        }
    }
    
    private func submitExcuse() {
        guard let selectedClass = selectedClass else { return }
        
        isSubmitting = true
        
        Task {
            await classesManager.requestExcuse(for: selectedClass, reason: reason)
            
            DispatchQueue.main.async {
                self.isSubmitting = false
                self.dismiss()
            }
        }
    }
}

struct ClassFormView: View {
    @ObservedObject var classesManager: ClassesExcusesManager
    let classToEdit: GymClass?
    
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var instructor = ""
    @State private var description = ""
    @State private var selectedDate = Date()
    @State private var maxCapacity = 20
    @State private var currentEnrollment = 0
    @State private var isSubmitting = false
    
    private var isEditing: Bool {
        classToEdit != nil
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Información de la Clase") {
                    TextField("Nombre de la clase", text: $name)
                    TextField("Instructor", text: $instructor)
                    TextField("Descripción", text: $description, axis: .vertical)
                        .lineLimit(2...4)
                }
                
                Section("Programación") {
                    DatePicker("Fecha y Hora", selection: $selectedDate, displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.compact)
                }
                
                Section("Capacidad") {
                    HStack {
                        Text("Capacidad máxima:")
                        Spacer()
                        Stepper("\(maxCapacity)", value: $maxCapacity, in: 1...50)
                    }
                    
                    if isEditing {
                        HStack {
                            Text("Inscritos actuales:")
                            Spacer()
                            Stepper("\(currentEnrollment)", value: $currentEnrollment, in: 0...maxCapacity)
                        }
                    }
                }
                
                if !classesManager.errorMessage.isEmpty {
                    Section {
                        Text(classesManager.errorMessage)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle(isEditing ? "Editar Clase" : "Nueva Clase")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isEditing ? "Actualizar" : "Crear") {
                        saveClass()
                    }
                    .disabled(name.isEmpty || instructor.isEmpty || isSubmitting)
                }
            }
            .onAppear {
                loadClassData()
            }
        }
    }
    
    private func loadClassData() {
        if let classToEdit = classToEdit {
            name = classToEdit.name
            instructor = classToEdit.instructor
            description = classToEdit.description
            selectedDate = classToEdit.date
            maxCapacity = classToEdit.maxCapacity
            currentEnrollment = classToEdit.currentEnrollment
        }
    }
    
    private func saveClass() {
        isSubmitting = true
        
        let gymClass = GymClass(
            id: classToEdit?.id ?? UUID().uuidString,
            name: name,
            date: selectedDate,
            instructor: instructor,
            description: description,
            maxCapacity: maxCapacity,
            currentEnrollment: currentEnrollment,
            isActive: true
        )
        
        Task {
            if isEditing {
                await classesManager.updateClass(gymClass)
            } else {
                await classesManager.addClass(gymClass)
            }
            
            DispatchQueue.main.async {
                self.isSubmitting = false
                self.dismiss()
            }
        }
    }
}

struct CalendarNotification: View {
    @StateObject private var classesManager = ClassesExcusesManager()
    @State private var selectedTab = 0
    @State private var showCalendarView = false
    @State private var showExcuseForm = false
    @State private var showClassForm = false
    @State private var selectedClass: GymClass?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerSection
            contentSection
                .animation(.easeInOut(duration: 0.3), value: selectedTab)
        }
        .background(cardBackground)
        .overlay(cardBorder)
        .brandShadow()
        .sheet(isPresented: $showCalendarView) {
            CalendarDetailView(classesManager: classesManager)
        }
        .sheet(isPresented: $showExcuseForm) {
            ExcuseFormView(
                classesManager: classesManager,
                availableClasses: classesManager.upcomingClasses
            )
        }
        .sheet(isPresented: $showClassForm) {
            ClassFormView(
                classesManager: classesManager,
                classToEdit: selectedClass
            )
        }
        .onAppear {
            classesManager.loadClasses()
            classesManager.loadExcuses()
        }
    }
    
    // MARK: - Computed Properties
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(
                LinearGradient(
                    colors: [Color.brandDark, Color.brandBlack.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }
    
    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 20)
            .stroke(
                LinearGradient(
                    colors: [Color.brandGold.opacity(0.3), Color.clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        HStack {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.brandGold.opacity(0.2))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: "bell.badge")
                        .foregroundColor(.brandGold)
                        .font(.title3)
                        .fontWeight(.semibold)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Notificaciones")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.brandWhite)
                    
                    if classesManager.isLoading {
                        Text("Cargando...")
                            .font(.caption)
                            .foregroundColor(.brandLight.opacity(0.8))
                    } else {
                        Text("¡Eventos y mucho más!")
                            .font(.caption)
                            .foregroundColor(.brandLight.opacity(0.8))
                    }
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 15)
    }
    
    // MARK: - Content Section
    private var contentSection: some View {
        VStack(spacing: 0) {
            if selectedTab == 0 {
                upcomingClassesSection
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
            } else {
                excusesSection
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
        .frame(minHeight: 160)
    }
    
    // MARK: - Upcoming Classes Section
    private var upcomingClassesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if classesManager.isLoading {
                loadingView
            } else if classesManager.upcomingClasses.isEmpty {
                emptyClassesView
            } else {
                ForEach(classesManager.upcomingClasses.prefix(3)) { gymClass in
                    ClassCardView(
                        gymClass: gymClass,
                        onEdit: {
                            selectedClass = gymClass
                            showClassForm = true
                        },
                        onDelete: {
                            Task {
                                await classesManager.deleteClass(gymClass.id)
                            }
                        }
                    )
                    .transition(.scale.combined(with: .opacity))
                }
                
                if classesManager.upcomingClasses.count > 3 {
                    Button(action: {
                        showCalendarView = true
                    }) {
                        HStack {
                            Text("Ver todas las notificaciones (\(classesManager.upcomingClasses.count))")
                                .font(.caption)
                                .fontWeight(.medium)
                            Image(systemName: "arrow.right")
                                .font(.caption2)
                        }
                        .foregroundColor(.brandLight)
                        .padding(.top, 8)
                    }
                }
            }
        }
    }
    
    // MARK: - Excuses Section
    private var excusesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if classesManager.pendingExcuses.isEmpty {
                emptyExcusesView
            } else {
                ForEach(classesManager.pendingExcuses.prefix(3)) { excuse in
                    ExcuseCardView(excuse: excuse)
                        .transition(.scale.combined(with: .opacity))
                }
                
                if classesManager.pendingExcuses.count > 3 {
                    Button(action: {
                        showCalendarView = true
                    }) {
                        HStack {
                            Text("Ver historial completo (\(classesManager.pendingExcuses.count))")
                                .font(.caption)
                                .fontWeight(.medium)
                            Image(systemName: "arrow.right")
                                .font(.caption2)
                        }
                        .foregroundColor(.brandLight)
                        .padding(.top, 8)
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Views
    private var loadingView: some View {
        HStack {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .brandGold))
                .controlSize(.small)
            
            Text("Cargando clases...")
                .font(.caption)
                .foregroundColor(.brandLight)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
    
    private var emptyClassesView: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 32))
                .foregroundColor(.brandLight.opacity(0.6))
            
            Text("No hay clases programadas")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.brandLight.opacity(0.8))
            
            Text("Agrega nuevas clases para comenzar")
                .font(.caption)
                .foregroundColor(.brandGray)
                .multilineTextAlignment(.center)
            
            Button("Agregar Primera Clase") {
                selectedClass = nil
                showClassForm = true
            }
            .font(.caption)
            .foregroundColor(.brandGold)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
    
    private var emptyExcusesView: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 32))
                .foregroundColor(.brandSuccess.opacity(0.8))
            
            Text("¡Todo al día!")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.brandSuccess)
            
            Text("No tienes excusas pendientes")
                .font(.caption)
                .foregroundColor(.brandGray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
}

// MARK: - Calendar and Excuses Card
struct CalendarExcusesCard: View {
    @StateObject private var classesManager = ClassesExcusesManager()
    @State private var selectedTab = 0
    @State private var showCalendarView = false
    @State private var showExcuseForm = false
    @State private var showClassForm = false
    @State private var selectedClass: GymClass?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerSection
            tabPicker
            contentSection
                .animation(.easeInOut(duration: 0.3), value: selectedTab)
        }
        .background(cardBackground)
        .overlay(cardBorder)
        .brandShadow()
        .sheet(isPresented: $showCalendarView) {
            CalendarDetailView(classesManager: classesManager)
        }
        .sheet(isPresented: $showExcuseForm) {
            ExcuseFormView(
                classesManager: classesManager,
                availableClasses: classesManager.upcomingClasses
            )
        }
        .sheet(isPresented: $showClassForm) {
            ClassFormView(
                classesManager: classesManager,
                classToEdit: selectedClass
            )
        }
        .onAppear {
            classesManager.loadClasses()
            classesManager.loadExcuses()
        }
    }
    
    // MARK: - Computed Properties
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(
                LinearGradient(
                    colors: [Color.brandDark, Color.brandBlack.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }
    
    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 20)
            .stroke(
                LinearGradient(
                    colors: [Color.brandGold.opacity(0.3), Color.clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        HStack {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.brandGold.opacity(0.2))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: "calendar.badge.exclamationmark")
                        .foregroundColor(.brandGold)
                        .font(.title3)
                        .fontWeight(.semibold)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Calendario & Excusas")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.brandWhite)
                    
                    if classesManager.isLoading {
                        Text("Cargando...")
                            .font(.caption)
                            .foregroundColor(.brandLight.opacity(0.8))
                    } else {
                        Text("Gestiona tu tiempo")
                            .font(.caption)
                            .foregroundColor(.brandLight.opacity(0.8))
                    }
                }
            }
            
            Spacer()
            
            // Botones de acción
            HStack(spacing: 12) {
                // Botón para ver calendario completo
                Button(action: {
                    showCalendarView = true
                }) {
                    Image(systemName: "calendar")
                        .foregroundColor(.brandLight)
                        .font(.title3)
                        .frame(width: 32, height: 32)
                        .background(Color.brandWhite.opacity(0.1))
                        .clipShape(Circle())
                }
                
                // Botón para nueva clase (solo admins)
                Button(action: {
                    selectedClass = nil
                    showClassForm = true
                }) {
                    Image(systemName: "plus.square")
                        .foregroundColor(.brandLight)
                        .font(.title3)
                        .frame(width: 32, height: 32)
                        .background(Color.brandAccent.opacity(0.2))
                        .clipShape(Circle())
                }
                
                // Botón para nueva excusa
                Button(action: {
                    showExcuseForm = true
                }) {
                    Image(systemName: "plus")
                        .foregroundColor(.brandBlack)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .frame(width: 32, height: 32)
                        .background(
                            LinearGradient.brandPrimary
                                .clipShape(Circle())
                        )
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 15)
    }
    
    // MARK: - Tab Picker
    private var tabPicker: some View {
        HStack(spacing: 0) {
            // Tab Próximas Clases
            Button(action: {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    selectedTab = 0
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "calendar.day.timeline.leading")
                        .font(.caption)
                    Text("Próximas Clases")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    if !classesManager.upcomingClasses.isEmpty {
                        Text("\(classesManager.upcomingClasses.count)")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(selectedTab == 0 ? .brandBlack : .brandLight)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(selectedTab == 0 ? Color.brandBlack.opacity(0.2) : Color.brandGold.opacity(0.3))
                            .clipShape(Capsule())
                    }
                }
                .foregroundColor(selectedTab == 0 ? .brandBlack : .brandLight)
                .padding(.vertical, 10)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(selectedTab == 0 ? Color.brandGold : Color.clear)
                )
            }
            
            // Tab Excusas
            Button(action: {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    selectedTab = 1
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.bubble")
                        .font(.caption)
                    Text("Excusas")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    // Badge de excusas pendientes
                    if !classesManager.pendingExcuses.isEmpty {
                        Text("\(classesManager.pendingExcuses.count)")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(selectedTab == 1 ? .brandBlack : .brandLight)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(selectedTab == 1 ? Color.brandBlack.opacity(0.2) : Color.brandWarning.opacity(0.8))
                            .clipShape(Capsule())
                    }
                }
                .foregroundColor(selectedTab == 1 ? .brandBlack : .brandLight)
                .padding(.vertical, 10)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(selectedTab == 1 ? Color.brandGold : Color.clear)
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 15)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.brandWhite.opacity(0.05))
                .padding(.horizontal, 16)
        )
    }
    
    // MARK: - Content Section
    private var contentSection: some View {
        VStack(spacing: 0) {
            if selectedTab == 0 {
                upcomingClassesSection
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
            } else {
                excusesSection
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
        .frame(minHeight: 160)
    }
    
    // MARK: - Upcoming Classes Section
    private var upcomingClassesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if classesManager.isLoading {
                loadingView
            } else if classesManager.upcomingClasses.isEmpty {
                emptyClassesView
            } else {
                ForEach(classesManager.upcomingClasses.prefix(3)) { gymClass in
                    ClassCardView(
                        gymClass: gymClass,
                        onEdit: {
                            selectedClass = gymClass
                            showClassForm = true
                        },
                        onDelete: {
                            Task {
                                await classesManager.deleteClass(gymClass.id)
                            }
                        }
                    )
                    .transition(.scale.combined(with: .opacity))
                }
                
                if classesManager.upcomingClasses.count > 3 {
                    Button(action: {
                        showCalendarView = true
                    }) {
                        HStack {
                            Text("Ver todas las clases (\(classesManager.upcomingClasses.count))")
                                .font(.caption)
                                .fontWeight(.medium)
                            Image(systemName: "arrow.right")
                                .font(.caption2)
                        }
                        .foregroundColor(.brandLight)
                        .padding(.top, 8)
                    }
                }
            }
        }
    }
    
    // MARK: - Excuses Section
    private var excusesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if classesManager.pendingExcuses.isEmpty {
                emptyExcusesView
            } else {
                ForEach(classesManager.pendingExcuses.prefix(3)) { excuse in
                    ExcuseCardView(excuse: excuse)
                        .transition(.scale.combined(with: .opacity))
                }
                
                if classesManager.pendingExcuses.count > 3 {
                    Button(action: {
                        showCalendarView = true
                    }) {
                        HStack {
                            Text("Ver historial completo (\(classesManager.pendingExcuses.count))")
                                .font(.caption)
                                .fontWeight(.medium)
                            Image(systemName: "arrow.right")
                                .font(.caption2)
                        }
                        .foregroundColor(.brandLight)
                        .padding(.top, 8)
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Views
    private var loadingView: some View {
        HStack {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .brandGold))
                .controlSize(.small)
            
            Text("Cargando clases...")
                .font(.caption)
                .foregroundColor(.brandLight)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
    
    private var emptyClassesView: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 32))
                .foregroundColor(.brandLight.opacity(0.6))
            
            Text("No hay clases programadas")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.brandLight.opacity(0.8))
            
            Text("Agrega nuevas clases para comenzar")
                .font(.caption)
                .foregroundColor(.brandGray)
                .multilineTextAlignment(.center)
            
            Button("Agregar Primera Clase") {
                selectedClass = nil
                showClassForm = true
            }
            .font(.caption)
            .foregroundColor(.brandGold)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
    
    private var emptyExcusesView: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 32))
                .foregroundColor(.brandSuccess.opacity(0.8))
            
            Text("¡Todo al día!")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.brandSuccess)
            
            Text("No tienes excusas pendientes")
                .font(.caption)
                .foregroundColor(.brandGray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
}

// MARK: - Class Card View
struct ClassCardView: View {
    let gymClass: GymClass
    let onEdit: () -> Void
    let onDelete: () -> Void
    @State private var showingOptions = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Icono de la clase con color de fondo
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.brandAccent.opacity(0.2))
                    .frame(width: 40, height: 40)
                
                Image(systemName: classIcon(for: gymClass.name))
                    .foregroundColor(.brandAccent)
                    .font(.title3)
            }
            
            // Información de la clase
            VStack(alignment: .leading, spacing: 4) {
                Text(gymClass.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.brandWhite)
                
                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: "person.fill")
                            .foregroundColor(.brandLight.opacity(0.7))
                            .font(.caption2)
                        
                        Text(gymClass.instructor)
                            .font(.caption)
                            .foregroundColor(.brandLight.opacity(0.9))
                    }
                }
            }
            
            Spacer()
            
            // Fecha y opciones
            VStack(alignment: .trailing, spacing: 4) {
                Text(gymClass.date, format: .dateTime.day().month())
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.brandGold)
                
                Text(gymClass.date, format: .dateTime.hour().minute())
                    .font(.caption2)
                    .foregroundColor(.brandWhite)
                
                // Botón de opciones
                Button(action: {
                    showingOptions = true
                }) {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.brandLight.opacity(0.7))
                        .font(.caption)
                }
                .padding(.top, 4)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.brandWhite.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.brandAccent.opacity(0.2), lineWidth: 1)
        )
        .confirmationDialog("Opciones de Clase", isPresented: $showingOptions, titleVisibility: .visible) {
            Button("Editar Clase") {
                onEdit()
            }
            
            Button("Eliminar Clase", role: .destructive) {
                onDelete()
            }
            
            Button("Cancelar", role: .cancel) { }
        } message: {
            Text("¿Qué deseas hacer con \(gymClass.name)?")
        }
    }
    
    private func classIcon(for className: String) -> String {
        switch className.lowercased() {
        case "crossfit": return "figure.strengthtraining.traditional"
        case "yoga": return "figure.mind.and.body"
        case "spinning": return "figure.indoor.cycle"
        case "pilates": return "figure.pilates"
        case "cardio": return "heart.fill"
        case "funcional": return "figure.functional.training"
        case "zumba": return "figure.dance"
        case "aqua": return "figure.pool.swim"
        default: return "figure.walk"
        }
    }
}

// MARK: - Excuse Card View
struct ExcuseCardView: View {
    let excuse: ExcuseRequest
    
    var body: some View {
        HStack(spacing: 12) {
            // Indicador de estado
            VStack {
                Circle()
                    .fill(excuse.status.color)
                    .frame(width: 12, height: 12)
                
                Rectangle()
                    .fill(excuse.status.color.opacity(0.3))
                    .frame(width: 2, height: 20)
            }
            
            // Contenido de la excusa
            VStack(alignment: .leading, spacing: 6) {
                Text(excuse.className)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.brandWhite)
                
                Text(excuse.reason)
                    .font(.caption)
                    .foregroundColor(.brandLight.opacity(0.9))
                    .lineLimit(2)
                
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .foregroundColor(.brandLight.opacity(0.7))
                            .font(.caption2)
                        
                        Text(excuse.date, format: .dateTime.day().month())
                            .font(.caption)
                            .foregroundColor(.brandLight.opacity(0.9))
                    }
                    
                    // Estado con badge mejorado
                    HStack(spacing: 4) {
                        Image(systemName: excuse.status.icon)
                            .font(.caption2)
                        
                        Text(excuse.status.text)
                            .font(.caption2)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(excuse.status.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(excuse.status.color.opacity(0.15))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(excuse.status.color.opacity(0.3), lineWidth: 1)
                    )
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.brandWhite.opacity(0.05))
        )
    }
}

struct ClassDetailRow: View {
    let gymClass: GymClass
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(gymClass.name)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.brandWhite)
                
                Spacer()
                
                Text(gymClass.date, format: .dateTime.hour().minute())
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.brandGold)
            }
            
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Image(systemName: "person.fill")
                        .foregroundColor(.brandLight.opacity(0.7))
                        .font(.caption)
                    
                    Text(gymClass.instructor)
                        .font(.subheadline)
                        .foregroundColor(.brandLight)
                }
                
                HStack(spacing: 4) {
                    Image(systemName: "person.3.fill")
                        .foregroundColor(.brandAccent.opacity(0.7))
                        .font(.caption)
                    
                    Text("\(gymClass.currentEnrollment)/\(gymClass.maxCapacity)")
                        .font(.subheadline)
                        .foregroundColor(.brandAccent)
                }
                
                Spacer()
            }
            
            if !gymClass.description.isEmpty {
                Text(gymClass.description)
                    .font(.caption)
                    .foregroundColor(.brandGray)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 8)
    }
}

struct ExcuseDetailRow: View {
    let excuse: ExcuseRequest
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(excuse.className)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.brandWhite)
                
                Spacer()
                
                Text(excuse.date, format: .dateTime.day().month())
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.brandGold)
            }
            
            Text(excuse.reason)
                .font(.subheadline)
                .foregroundColor(.brandLight)
                .lineLimit(3)
            
            HStack {
                Text("Solicitada: \(excuse.createdAt, format: .dateTime.day().month().hour().minute())")
                    .font(.caption)
                    .foregroundColor(.brandGray)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: excuse.status.icon)
                        .font(.caption2)
                    
                    Text(excuse.status.text)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundColor(excuse.status.color)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(excuse.status.color.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Calendar Detail View
struct CalendarDetailView: View {
    @ObservedObject var classesManager: ClassesExcusesManager
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0 // 0: Clases, 1: Excusas
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Picker de pestañas
                Picker("Vista", selection: $selectedTab) {
                    Text("Clases (\(classesManager.upcomingClasses.count))").tag(0)
                    Text("Excusas (\(classesManager.pendingExcuses.count))").tag(1)
                }
                .pickerStyle(.segmented)
                .padding()
                
                // Contenido según la pestaña seleccionada
                if selectedTab == 0 {
                    classesListView
                } else {
                    excusesListView
                }
            }
            .background(Color.brandBlack)
            .navigationTitle("Calendario Completo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cerrar") {
                        dismiss()
                    }
                    .foregroundColor(.brandGold)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Actualizar") {
                        classesManager.loadClasses()
                        classesManager.loadExcuses()
                    }
                    .foregroundColor(.brandGold)
                }
            }
        }
    }
    
    // MARK: - Lista de Clases
    private var classesListView: some View {
        Group {
            if classesManager.isLoading {
                VStack {
                    ProgressView("Cargando clases...")
                        .progressViewStyle(CircularProgressViewStyle(tint: .brandGold))
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if classesManager.upcomingClasses.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 60))
                        .foregroundColor(.brandLight.opacity(0.6))
                    
                    Text("No hay clases programadas")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.brandWhite)
                    
                    Text("Las clases aparecerán aquí cuando sean creadas")
                        .font(.subheadline)
                        .foregroundColor(.brandGray)
                        .multilineTextAlignment(.center)
                    
                    Spacer()
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(groupedClasses.keys.sorted(), id: \.self) { date in
                        Section(header: sectionHeader(for: date)) {
                            ForEach(groupedClasses[date] ?? []) { gymClass in
                                ClassDetailRow(gymClass: gymClass)
                                    .listRowBackground(Color.brandDark.opacity(0.5))
                                    .listRowSeparator(.hidden)
                            }
                        }
                    }
                }
                .listStyle(PlainListStyle())
                .background(Color.brandBlack)
                .scrollContentBackground(.hidden)
            }
        }
    }
    
    // MARK: - Lista de Excusas
    private var excusesListView: some View {
        Group {
            if classesManager.pendingExcuses.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 60))
                        .foregroundColor(.brandSuccess.opacity(0.8))
                    
                    Text("¡Todo al día!")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.brandSuccess)
                    
                    Text("No tienes excusas registradas")
                        .font(.subheadline)
                        .foregroundColor(.brandGray)
                    
                    Spacer()
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(ExcuseStatus.allCases, id: \.self) { status in
                        let excusesForStatus = classesManager.pendingExcuses.filter { $0.status == status }
                        
                        if !excusesForStatus.isEmpty {
                            Section(header: excuseStatusHeader(for: status, count: excusesForStatus.count)) {
                                ForEach(excusesForStatus) { excuse in
                                    ExcuseDetailRow(excuse: excuse)
                                        .listRowBackground(Color.brandDark.opacity(0.5))
                                        .listRowSeparator(.hidden)
                                }
                            }
                        }
                    }
                }
                .listStyle(PlainListStyle())
                .background(Color.brandBlack)
                .scrollContentBackground(.hidden)
            }
        }
    }
    
    // MARK: - Computed Properties
    private var groupedClasses: [String: [GymClass]] {
        Dictionary(grouping: classesManager.upcomingClasses) { gymClass in
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.string(from: gymClass.date)
        }
    }
    
    // MARK: - Helper Views
    private func sectionHeader(for dateString: String) -> some View {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let date = formatter.date(from: dateString) ?? Date()
        
        return HStack {
            Text(date, format: .dateTime.weekday(.wide).day().month(.wide))
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.brandGold)
            
            Spacer()
            
            Text("\(groupedClasses[dateString]?.count ?? 0) clases")
                .font(.caption)
                .foregroundColor(.brandLight.opacity(0.8))
        }
        .padding(.vertical, 8)
    }
    
    private func excuseStatusHeader(for status: ExcuseStatus, count: Int) -> some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: status.icon)
                    .foregroundColor(status.color)
                
                Text(status.text)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.brandWhite)
            }
            
            Spacer()
            
            Text("\(count)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(status.color)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(status.color.opacity(0.2))
                .clipShape(Capsule())
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Quick Stat Component
struct QuickStat: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.brandDark)
                .font(.title3)
            
            VStack(alignment: .leading) {
                Text(value)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.brandDark)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.brandDark)
            }
        }
    }
}

// MARK: - AdminCard (Updated)
struct AdminCard: View {
    let title: String
    let icon: String
    let color: Color
    let count: Int?
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(color)
                
                Spacer()
                
                if let count = count {
                    Text("\(count)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(color)
                }
            }
            
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.brandDark)
                Spacer()
            }
        }
        .padding()
        .frame(height: 100)
        .background(Color.brandWhite)
        .cornerRadius(12)
        .brandShadow()
    }
}

@MainActor
class DailyClassManager: ObservableObject {
    @Published var isGeneratingClasses = false
    @Published var lastGenerationDate: Date?
    @Published var errorMessage = ""
    
    private let db = Firestore.firestore()
    private let userDefaults = UserDefaults.standard
    private let lastGenerationKey = "lastClassGeneration"
    
    init() {
        loadLastGenerationDate()
        checkAndGenerateClasses()
    }
    
    // MARK: - Verificar y Generar Clases
    func checkAndGenerateClasses() {
        let today = Calendar.current.startOfDay(for: Date())
        
        // Verificar si ya se generaron clases hoy
        if let lastGeneration = lastGenerationDate,
           Calendar.current.isDate(lastGeneration, inSameDayAs: today) {
            print("✅ Las clases de hoy ya fueron generadas")
            return
        }
        
        print("🔄 Generando clases diarias...")
        Task {
            await generateDailyClasses()
        }
    }
    
    // MARK: - Generar Clases para los Próximos 30 Días
    func generateDailyClasses() async {
        isGeneratingClasses = true
        errorMessage = ""
        
        let calendar = Calendar.current
        let today = Date()
        let endDate = calendar.date(byAdding: .day, value: 30, to: today) ?? today
        
        var currentDate = today
        var classesCreated = 0
        
        while currentDate <= endDate {
            await generateClassesForDate(currentDate)
            classesCreated += 1
            
            // Avanzar al siguiente día
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? endDate
        }
        
        // Actualizar fecha de última generación
        lastGenerationDate = today
        userDefaults.set(today, forKey: lastGenerationKey)
        
        isGeneratingClasses = false
        print("✅ Generadas clases para \(classesCreated) días")
    }
    
    // MARK: - Generar Clases para una Fecha Específica
    private func generateClassesForDate(_ date: Date) async {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date) // 1=Domingo, 2=Lunes, etc.
        let adjustedWeekday = weekday == 1 ? 7 : weekday - 1 // Convertir a 1=Lunes, 7=Domingo
        
        // Obtener todas las clases default (incluyendo la obligatoria)
        var defaultClasses = DefaultClass.additionalDefaults
        //defaultClasses.append(DefaultClass.gymDefault)
        
        for defaultClass in defaultClasses {
            // Verificar si esta clase aplica para este día
            let shouldCreateClass = defaultClass.weekDays.contains(0) || // Todos los días
                                  defaultClass.weekDays.contains(adjustedWeekday)
            
            guard shouldCreateClass else { continue }
            
            // Crear la clase para esta fecha
            let gymClass = createGymClassFromDefault(defaultClass, for: date)
            
            // Verificar si ya existe esta clase
            let exists = await checkIfClassExists(gymClass)
            if !exists {
                await saveClass(gymClass)
            }
        }
    }
    
    // MARK: - Crear GymClass desde DefaultClass
    private func createGymClassFromDefault(_ defaultClass: DefaultClass, for date: Date) -> GymClass {
        let calendar = Calendar.current
        
        // Parsear la hora de inicio
        let timeComponents = defaultClass.startTime.split(separator: ":")
        let hour = Int(timeComponents[0]) ?? 7
        let minute = Int(timeComponents[1]) ?? 0
        
        // Crear la fecha y hora completa
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = hour
        components.minute = minute
        
        let classDate = calendar.date(from: components) ?? date
        
        // Generar ID único para esta clase específica
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: date)
        let classId = "\(defaultClass.id)-\(dateString)"
        
        return GymClass(
            id: classId,
            name: defaultClass.name,
            date: classDate,
            instructor: defaultClass.instructor,
            description: defaultClass.description,
            maxCapacity: defaultClass.maxCapacity,
            currentEnrollment: 0,
            isActive: true
        )
    }
    
    // MARK: - Verificar si una Clase ya Existe
    private func checkIfClassExists(_ gymClass: GymClass) async -> Bool {
        do {
            let document = try await db.collection("gymClasses").document(gymClass.id).getDocument()
            return document.exists
        } catch {
            print("⚠️ Error verificando clase existente: \(error)")
            return false
        }
    }
    
    // MARK: - Guardar Clase en Firestore
    private func saveClass(_ gymClass: GymClass) async {
        do {
            try db.collection("gymClasses").document(gymClass.id).setData(from: gymClass)
            print("✅ Clase creada: \(gymClass.name) - \(gymClass.date)")
        } catch {
            print("❌ Error creando clase: \(error)")
            DispatchQueue.main.async {
                self.errorMessage = "Error creando clase: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Funciones de Configuración
    private func loadLastGenerationDate() {
        lastGenerationDate = userDefaults.object(forKey: lastGenerationKey) as? Date
    }
    
    // MARK: - Funciones Públicas para UI
    func forceRegenerateClasses() {
        print("🔄 Regeneración forzada de clases...")
        lastGenerationDate = nil
        userDefaults.removeObject(forKey: lastGenerationKey)
        Task {
            await generateDailyClasses()
        }
    }
    
    func generateClassesForNextWeek() async {
        isGeneratingClasses = true
        
        let calendar = Calendar.current
        let today = Date()
        let nextWeekStart = calendar.date(byAdding: .weekOfYear, value: 1, to: today) ?? today
        let nextWeekEnd = calendar.date(byAdding: .day, value: 6, to: nextWeekStart) ?? nextWeekStart
        
        var currentDate = nextWeekStart
        while currentDate <= nextWeekEnd {
            await generateClassesForDate(currentDate)
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? nextWeekEnd
        }
        
        isGeneratingClasses = false
        print("✅ Clases generadas para la próxima semana")
    }
    
    // MARK: - Configurar Nuevas Clases Default
    func addCustomDefaultClass(_ defaultClass: DefaultClass) async {
        // Generar esta nueva clase para los próximos 30 días
        let calendar = Calendar.current
        let today = Date()
        let endDate = calendar.date(byAdding: .day, value: 30, to: today) ?? today
        
        var currentDate = today
        
        while currentDate <= endDate {
            let weekday = calendar.component(.weekday, from: currentDate)
            let adjustedWeekday = weekday == 1 ? 7 : weekday - 1
            
            let shouldCreateClass = defaultClass.weekDays.contains(0) ||
                                  defaultClass.weekDays.contains(adjustedWeekday)
            
            if shouldCreateClass {
                let gymClass = createGymClassFromDefault(defaultClass, for: currentDate)
                let exists = await checkIfClassExists(gymClass)
                if !exists {
                    await saveClass(gymClass)
                }
            }
            
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? endDate
        }
    }
}


struct DefaultClass: Codable {
    let id: String
    let name: String
    let startTime: String // "HH:mm" format
    let duration: Int // en minutos
    let instructor: String
    let description: String
    let maxCapacity: Int
    let isObligatory: Bool
    let weekDays: [Int] // 1=Lunes, 2=Martes, etc. (0 = todos los días)
    
    static let gymDefault = DefaultClass(
        id: "default-gym-class",
        name: "Funcional de Fin de Semana",
        startTime: "07:00",
        duration: 60,
        instructor: "Instructor del Día",
        description: "Clase diaria obligatoria de entrenamiento general para todos los miembros",
        maxCapacity: 50,
        isObligatory: true,
        weekDays: [0] // Todos los días
    )
    
    static let additionalDefaults = [
        DefaultClass(
            id: "morning-cardio",
            name: "Zumba",
            startTime: "06:00",
            duration: 45,
            instructor: "Instructor del Día",
            description: "Sesión de cardio para empezar el día con energía",
            maxCapacity: 30,
            isObligatory: false,
            weekDays: [1, 3, 5] // Lunes, Miércoles, Viernes
        ),
        DefaultClass(
            id: "morning-cardio",
            name: "Zumba",
            startTime: "06:00",
            duration: 45,
            instructor: "Entrenador Oscar",
            description: "Sesión de cardio para empezar el día con energía",
            maxCapacity: 30,
            isObligatory: false,
            weekDays: [1, 3, 5] // Lunes, Miércoles, Viernes
        ),
        DefaultClass(
            id: "weekend-functional",
            name: "Spinning",
            startTime: "10:00",
            duration: 75,
            instructor: "Entrenador Oscar",
            description: "Entrenamiento funcional completo para el fin de semana",
            maxCapacity: 40,
            isObligatory: false,
            weekDays: [7] // Domingo
        )
    ]
}

struct DefaultNotification: Codable {
    let id: String
    let name: String
    let startTime: String // "HH:mm" format
    let duration: Int // en minutos
    let instructor: String
    let description: String
    let maxCapacity: Int
    let isObligatory: Bool
    let weekDays: [Int] // 1=Lunes, 2=Martes, etc. (0 = todos los días)
    
    static let gymDefault = DefaultClass(
        id: "default-gym-class",
        name: "Entrenamiento General",
        startTime: "07:00",
        duration: 60,
        instructor: "Instructor del Día",
        description: "Clase diaria obligatoria de entrenamiento general para todos los miembros",
        maxCapacity: 50,
        isObligatory: true,
        weekDays: [0] // Todos los días
    )
    
    static let additionalDefaults = [
        DefaultClass(
            id: "morning-cardio",
            name: "Cardio Matutino",
            startTime: "06:00",
            duration: 45,
            instructor: "Entrenador Cardio",
            description: "Sesión de cardio para empezar el día con energía",
            maxCapacity: 30,
            isObligatory: false,
            weekDays: [1, 3, 5]
        ),
        DefaultClass(
            id: "weekend-functional",
            name: "Funcional de Fin de Semana",
            startTime: "10:00",
            duration: 75,
            instructor: "Entrenador Especialista",
            description: "Entrenamiento funcional completo para el fin de semana",
            maxCapacity: 40,
            isObligatory: false,
            weekDays: [7] // Domingo
        )
    ]
}

#Preview {
    ContentView()
}

