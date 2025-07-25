//
//  AdminDashboard.swift
//  gymadministrator
//
//  Created by Ruben Camargo on 24/07/25.
//

import SwiftUI
import FirebaseAuth

struct AdminDashboard: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var showingProfile = false
    @State private var showingDeleteAlert = false
    
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
                VStack(alignment: .leading) {
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
        Button(action: {
            // Aquí navegarías a la vista específica
            print("Navegando a: \(function.destination)")
        }) {
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
}

struct AdminProfileView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
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
                
                Spacer()
                
                // Información adicional
                VStack(alignment: .leading, spacing: 15) {
                    ProfileInfoRow(title: "Usuario ID", value: authManager.user?.uid ?? "")
                    ProfileInfoRow(title: "Email verificado", value: authManager.user?.isEmailVerified == true ? "Sí" : "No")
                    ProfileInfoRow(title: "Última conexión", value: "Ahora")
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Perfil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cerrar") {
                        dismiss()
                    }
                }
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

#Preview {
    AdminDashboard()
        .environmentObject(AuthManager())
}
