//
//  HomeScreen.swift
//  gymadministrator
//
//  Created by Ruben Camargo on 9/08/25.
//

import Foundation
import SwiftUI

// MARK: - AdminDashboard
struct AdminDashboard: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var dashboardManager = DashboardManager()
    @StateObject private var miembroManager = MiembroManager()
    @State private var showingMiembros = false
    
    var body: some View {
        let isIPad = UIDevice.current.userInterfaceIdiom == .pad
        
        if isIPad {
            // Para iPad: No usar NavigationView anidado, usar NavigationStack directo
            NavigationStack {
                iPadDashboardContent
            }
        } else {
            // Para iPhone: Mantener NavigationView
            NavigationView {
                iPhoneDashboardContent
            }
            .navigationViewStyle(.stack)
        }
    }
    
    // MARK: - iPad Content
    private var iPadDashboardContent: some View {
        GeometryReader { geometry in
            let screenWidth = geometry.size.width
            let screenHeight = geometry.size.height
            let isLandscape = screenWidth > screenHeight
            
            ScrollView {
                if isLandscape {
                    // iPad Landscape - 2 columnas
                    HStack(alignment: .top, spacing: 30) {
                        // Columna izquierda
                        /*VStack(spacing: 25) {
                            HeaderCard(authManager: authManager, dashboardManager: dashboardManager, miembroManager: miembroManager)
                            MembershipInfoCard(dashboardManager: dashboardManager)
                            Spacer(minLength: 0)
                        }
                        .frame(maxWidth: screenWidth * 0.45)*/
                        
                        // Columna derecha
                        VStack(spacing: 25) {
                            CalendarNotification()
                            Spacer(minLength: 0)
                        }
                        .frame(maxWidth: screenWidth * 0.45)
                    }
                    .padding(.horizontal, 40)
                    .padding(.top, 30)
                    .frame(minHeight: screenHeight - 150)
                } else {
                    // iPad Portrait - Layout vertical optimizado
                    VStack(spacing: 30) {
                        HeaderCard(authManager: authManager, dashboardManager: dashboardManager, miembroManager: miembroManager)
                        
                        //MembershipInfoCard(dashboardManager: dashboardManager)
                        
                        CalendarNotification()
                        
                        Spacer(minLength: 30)
                    }
                    .padding(.horizontal, 50)
                    .padding(.top, 30)
                    .frame(minWidth: screenWidth)
                }
            }
            .background(Color.brandBlack)
            .navigationTitle("Gym Body Gold")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cerrar Sesión") {
                        authManager.signOut()
                    }
                    .foregroundColor(.brandGold)
                    .font(.body)
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
    
    // MARK: - iPhone Content
    private var iPhoneDashboardContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                HeaderCard(authManager: authManager, dashboardManager: dashboardManager, miembroManager: miembroManager)
                /*MembershipInfoCard(dashboardManager: dashboardManager)*/
                CalendarNotification()
                Spacer(minLength: 20)
            }
            .padding()
        }
        .background(Color.brandBlack)
        .navigationTitle("Gym Body Gold")
        .navigationBarTitleDisplayMode(.inline)
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
