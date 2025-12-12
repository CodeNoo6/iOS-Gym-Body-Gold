//
//  AdminDashboard.swift
//  gymadministrator
//
//  Created by Ruben Camargo on 24/07/25.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct AdminDashboard: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var showingProfile = false
    @State private var showingDeleteAlert = false
    @StateObject private var adminListManager = AdminListManager()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header de bienvenida
                    WelcomeHeader()
                    
                    // Estadísticas rápidas
                    QuickStatsView()
                    
                    // Grid de funciones principales
                    AdminFunctionsGrid()

                    // Tabla de administradores con ocupaciones
                    AdminOccupationsTable()
                        .environmentObject(adminListManager)

                    Spacer(minLength: 20)
                }
                .padding()
            }
            .navigationTitle("Gym Admin")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { showingProfile = true }) {
                            Label("Perfil", systemImage: "person.circle")
                        }
                        
                        Button(action: { authManager.signOut() }) {
                            Label("Cerrar Sesión", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                        
                        Divider()
                        
                        Button(role: .destructive, action: { showingDeleteAlert = true }) {
                            Label("Eliminar Cuenta", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title2)
                    }
                }
            }
        }
        .onAppear {
            Task {
                await adminListManager.loadAdministrators()
            }
        }
        .sheet(isPresented: $showingProfile) {
            AdminProfileView()
                .environmentObject(authManager)
        }
        .alert("Eliminar Cuenta", isPresented: $showingDeleteAlert) {
            Button("Cancelar", role: .cancel) { }
            Button("Eliminar", role: .destructive) {
                Task {
                    await authManager.deleteAccount()
                }
            }
        } message: {
            Text("Esta acción eliminará permanentemente tu cuenta y todos los datos asociados. ¿Estás seguro?")
        }
    }
}

struct WelcomeHeader: View {
    @EnvironmentObject var authManager: AuthManager

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("¡Bienvenido!")
                        .font(.title2)
                        .fontWeight(.bold)

                    if let displayName = authManager.user?.displayName, !displayName.isEmpty {
                        Text(displayName)
                            .font(.title3)
                            .foregroundColor(.blue)
                    } else {
                        Text(authManager.user?.email ?? "Administrador")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    // Mostrar ocupación debajo del nombre
                    if !authManager.userOccupation.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "briefcase.fill")
                                .font(.caption)
                            Text(authManager.userOccupation)
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.blue)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color.blue.opacity(0.1))
            )
        }
    }
}

struct QuickStatsView: View {
    // Estos datos serían obtenidos de Firebase en una implementación real
    @State private var totalMembers = 247
    @State private var activeMembers = 189
    @State private var monthlyRevenue = 15420
    
    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 15) {
            StatCard(title: "Miembros", value: "\(totalMembers)", icon: "person.3.fill", color: .blue)
            StatCard(title: "Activos", value: "\(activeMembers)", icon: "figure.strengthtraining.traditional", color: .green)
            StatCard(title: "Ingresos", value: "$\(monthlyRevenue)", icon: "dollarsign.circle.fill", color: .orange)
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 25))
                .foregroundColor(color)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(height: 80)
        .frame(maxWidth: .infinity)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}

struct AdminFunctionsGrid: View {
    let functions = [
        AdminFunction(title: "Miembros", icon: "person.3.fill", color: .blue, destination: "members"),
        AdminFunction(title: "Membresías", icon: "creditcard.fill", color: .green, destination: "memberships"),
        AdminFunction(title: "Equipos", icon: "dumbbell.fill", color: .orange, destination: "equipment"),
        AdminFunction(title: "Horarios", icon: "calendar", color: .purple, destination: "schedules"),
        AdminFunction(title: "Entrenadores", icon: "person.badge.key.fill", color: .red, destination: "trainers"),
        AdminFunction(title: "Reportes", icon: "chart.bar.fill", color: .indigo, destination: "reports"),
        AdminFunction(title: "Pagos", icon: "banknote.fill", color: .mint, destination: "payments"),
        AdminFunction(title: "Configuración", icon: "gear", color: .gray, destination: "settings")
    ]
    
    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 15) {
            ForEach(functions) { function in
                AdminFunctionCard(function: function)
            }
        }
    }
}

struct AdminFunction: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let color: Color
    let destination: String
}

struct AdminFunctionCard: View {
    let function: AdminFunction
    
    var body: some View {

        NavigationLink(destination: destinationView) {
            VStack(spacing: 12) {
                Image(systemName: function.icon)
                    .font(.system(size: 30))
                    .foregroundColor(function.color)
                
                Text(function.title)
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            .frame(height: 100)
            .frame(maxWidth: .infinity)
            .background(Color.gray.opacity(0.05))
            .cornerRadius(15)
            .overlay(
                RoundedRectangle(cornerRadius: 15)
                    .stroke(function.color.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    @ViewBuilder
    private var destinationView: some View {
        switch function.destination {
        case "members":
            MiembrosListView()
        default:
            Text("Función \(function.title) en construcción")
                .font(.title)
                .foregroundColor(.gray)
        }
    }
    }
}

struct AdminProfileView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss
    @State private var isEditingOccupation = false
    @State private var newOccupation = ""
    @State private var showingSaveAlert = false

    let occupations = [
        "Administrador",
        "Gerente",
        "Entrenador Personal",
        "Recepcionista",
        "Nutricionista",
        "Fisioterapeuta",
        "Instructor",
        "Otro"
    ]

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Avatar
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)

                    // Información del usuario
                    VStack(spacing: 10) {
                        if let displayName = authManager.user?.displayName, !displayName.isEmpty {
                            Text(displayName)
                                .font(.title2)
                                .fontWeight(.bold)
                        }

                        Text(authManager.user?.email ?? "")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Text("Administrador")
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(8)
                    }

                    // Editar ocupación
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Ocupación")
                                .font(.headline)
                            Spacer()
                            Button(action: {
                                newOccupation = authManager.userOccupation
                                isEditingOccupation.toggle()
                            }) {
                                Text(isEditingOccupation ? "Cancelar" : "Editar")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }

                        if isEditingOccupation {
                            VStack(spacing: 10) {
                                Menu {
                                    ForEach(occupations, id: \.self) { occ in
                                        Button(occ) {
                                            newOccupation = occ
                                        }
                                    }
                                } label: {
                                    HStack {
                                        Text(newOccupation.isEmpty ? "Selecciona tu ocupación" : newOccupation)
                                            .foregroundColor(newOccupation.isEmpty ? .gray : .primary)
                                            .frame(maxWidth: .infinity, alignment: .leading)

                                        Image(systemName: "chevron.down")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                    .padding()
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(12)
                                }

                                Button(action: {
                                    Task {
                                        let success = await authManager.updateOccupation(occupation: newOccupation)
                                        if success {
                                            isEditingOccupation = false
                                            showingSaveAlert = true
                                        }
                                    }
                                }) {
                                    HStack {
                                        if authManager.isLoading {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                                .scaleEffect(0.8)
                                        } else {
                                            Text("Guardar")
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                                }
                                .disabled(authManager.isLoading || newOccupation.isEmpty)
                            }
                        } else {
                            HStack {
                                Image(systemName: "briefcase.fill")
                                    .foregroundColor(.gray)
                                Text(authManager.userOccupation.isEmpty ? "No especificada" : authManager.userOccupation)
                                    .foregroundColor(authManager.userOccupation.isEmpty ? .secondary : .primary)
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(12)
                        }
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)

                    // Información adicional
                    VStack(alignment: .leading, spacing: 15) {
                        ProfileInfoRow(title: "Usuario ID", value: authManager.user?.uid ?? "")
                        ProfileInfoRow(title: "Email verificado", value: authManager.user?.isEmailVerified == true ? "Sí" : "No")
                        ProfileInfoRow(title: "Última conexión", value: "Ahora")
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)

                    Spacer(minLength: 20)
                }
                .padding()
            }
            .navigationTitle("Perfil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cerrar") {
                        dismiss()
                    }
                }
            }
            .alert("Ocupación actualizada", isPresented: $showingSaveAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Tu ocupación ha sido actualizada exitosamente")
            }
        }
    }
}

struct ProfileInfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Admin Data Model
struct AdminData: Identifiable {
    let id: String
    let email: String
    let displayName: String
    let ocupacion: String
    let createdAt: Date
}

// MARK: - Admin List Manager
@MainActor
class AdminListManager: ObservableObject {
    @Published var administrators: [AdminData] = []
    @Published var isLoading = false
    @Published var errorMessage = ""

    private let db = Firestore.firestore()

    func loadAdministrators() async {
        isLoading = true
        errorMessage = ""

        do {
            let snapshot = try await db.collection("administrators")
                .order(by: "createdAt", descending: true)
                .getDocuments()

            administrators = snapshot.documents.compactMap { doc in
                let data = doc.data()
                return AdminData(
                    id: doc.documentID,
                    email: data["email"] as? String ?? "",
                    displayName: data["displayName"] as? String ?? "",
                    ocupacion: data["ocupacion"] as? String ?? "No especificada",
                    createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                )
            }

            print("✅ Cargados \(administrators.count) administradores")
        } catch {
            errorMessage = "Error al cargar administradores: \(error.localizedDescription)"
            print("❌ Error: \(errorMessage)")
        }

        isLoading = false
    }
}

// MARK: - Admin Occupations Table
struct AdminOccupationsTable: View {
    @EnvironmentObject var adminListManager: AdminListManager

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            // Header
            HStack {
                Image(systemName: "person.3.fill")
                    .foregroundColor(.blue)
                Text("Administradores y Ocupaciones")
                    .font(.headline)
                    .fontWeight(.bold)

                Spacer()

                if adminListManager.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }

            // Tabla
            if adminListManager.administrators.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 10) {
                        Image(systemName: "person.crop.circle.badge.questionmark")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                        Text("No hay administradores registrados")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 40)
                    Spacer()
                }
            } else {
                VStack(spacing: 0) {
                    // Header de la tabla
                    HStack {
                        Text("Nombre")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text("Email")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text("Ocupación")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))

                    Divider()

                    // Filas de la tabla
                    ForEach(adminListManager.administrators) { admin in
                        VStack(spacing: 0) {
                            HStack(alignment: .top, spacing: 12) {
                                // Nombre
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(admin.displayName.isEmpty ? "Sin nombre" : admin.displayName)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .lineLimit(2)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)

                                // Email
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(admin.email)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)

                                // Ocupación
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "briefcase.fill")
                                            .font(.caption2)
                                            .foregroundColor(.blue)
                                        Text(admin.ocupacion)
                                            .font(.caption)
                                            .foregroundColor(.primary)
                                            .lineLimit(2)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding()

                            if admin.id != adminListManager.administrators.last?.id {
                                Divider()
                            }
                        }
                    }
                }
                .background(Color.white)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
            }

            // Error message
            if !adminListManager.errorMessage.isEmpty {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text(adminListManager.errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .padding(.top, 5)
            }
        }
        .padding(.vertical, 10)
    }
}

#Preview {
    AdminDashboard()
        .environmentObject(AuthManager())
}
