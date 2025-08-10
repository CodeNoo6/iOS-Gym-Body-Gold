//
//  Components.swift
//  gymadministrator
//
//  Created by Ruben Camargo on 9/08/25.
//

import Foundation
import SwiftUI

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

struct CalendarNotification: View {
    @StateObject private var notificationManager = NotificationManager()
    @State private var selectedTab = 0
    @State private var showCalendarView = false
    @State private var showExcuseForm = false
    @State private var showClassForm = false
    
    // Tabs para el selector - COMENTADAS las de clases y excusas
    private let tabs = ["Notificaciones"] //, "Clases", "Excusas"]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerSection
            // tabSelector - COMENTADO ya que solo tenemos una tab
            contentSection
                .animation(.easeInOut(duration: 0.3), value: selectedTab)
        }
        .background(cardBackground)
        .overlay(cardBorder)
        .brandShadow()
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
                    
                    Image(systemName: "bell.badge.fill")
                        .foregroundColor(.brandGold)
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    // Badge de notificaciones no leídas
                    if notificationManager.unreadCount > 0 {
                        Circle()
                            .fill(Color.brandError)
                            .frame(width: 16, height: 16)
                            .overlay(
                                Text("\(notificationManager.unreadCount)")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            )
                            .offset(x: 12, y: -12)
                    }
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Notificaciones")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.brandWhite)
                    
                    Text(notificationManager.notifications.isEmpty ?
                         "No hay notificaciones" :
                         "\(notificationManager.notifications.count) notificaciones")
                        .font(.caption)
                        .foregroundColor(.brandLight.opacity(0.8))
                }
            }
            
            Spacer()
            
            // Menú de opciones para notificaciones
            /*Menu {
                Button("Agregar notificación de prueba") {
                    notificationManager.addTestNotification()
                }
                
                if !notificationManager.notifications.isEmpty {
                    Divider()
                    
                    Button("Marcar todas como leídas") {
                        notificationManager.markAllAsRead()
                    }
                    
                    Button("Limpiar todas", role: .destructive) {
                        notificationManager.clearAllNotifications()
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundColor(.brandLight)
                    .font(.title3)
            }*/
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 15) // Aumentado el padding ya que no hay tabs
    }
    
    // MARK: - Tab Selector - COMENTADO
    /*
    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        selectedTab = index
                    }
                }) {
                    VStack(spacing: 4) {
                        Text(tab)
                            .font(.caption)
                            .fontWeight(selectedTab == index ? .semibold : .medium)
                            .foregroundColor(selectedTab == index ? .brandGold : .brandLight.opacity(0.7))
                        
                        Rectangle()
                            .fill(selectedTab == index ? Color.brandGold : Color.clear)
                            .frame(height: 2)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 15)
    }
    */
    
    // MARK: - Content Section - SIMPLIFICADO
    private var contentSection: some View {
        VStack(spacing: 0) {
            // Solo mostrar la sección de notificaciones
            notificationsSection
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
        .frame(minHeight: 160)
    }
    
    // MARK: - Notifications Section
    private var notificationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if notificationManager.notifications.isEmpty {
                emptyNotificationsView
            } else {
                ForEach(notificationManager.notifications.prefix(5)) { notification in // Aumentado a 5 notificaciones
                    NotificationCardView(
                        notification: notification,
                        onRead: {
                            notificationManager.markAsRead(notification)
                        },
                        onDelete: {
                            withAnimation(.easeInOut) {
                                notificationManager.deleteNotification(notification)
                            }
                        }
                    )
                    .transition(.scale.combined(with: .opacity))
                }
                
                if notificationManager.notifications.count > 5 {
                    Button(action: {
                        // Mostrar vista completa de notificaciones
                        showCalendarView = true
                    }) {
                        HStack {
                            Text("Ver todas las notificaciones (\(notificationManager.notifications.count))")
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
    
    // MARK: - Upcoming Classes Section - COMENTADO
    /*
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
    */
    
    // MARK: - Excuses Section - COMENTADO
    /*
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
    */
    
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
    
    private var emptyNotificationsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "bell.slash")
                .font(.system(size: 32))
                .foregroundColor(.brandLight.opacity(0.6))
            
            Text("No hay notificaciones")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.brandLight.opacity(0.8))
            
            Text("Las notificaciones push aparecerán aquí")
                .font(.caption)
                .foregroundColor(.brandGray)
                .multilineTextAlignment(.center)
            
            /*Button("Agregar Prueba") {
                notificationManager.addTestNotification()
            }
            .font(.caption)
            .foregroundColor(.brandGold)
            .padding(.top, 8)*/
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
    
    // MARK: - Helper Views - COMENTADAS
    /*
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
    */
}
