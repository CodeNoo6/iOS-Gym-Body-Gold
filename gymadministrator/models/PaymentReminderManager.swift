//
//  PaymentReminderManager.swift
//  gymadministrator
//
//  Sistema de recordatorios de pago usando notificaciones locales
//

import Foundation
import UserNotifications
import FirebaseFirestore
import SwiftUI

// MARK: - Payment Reminder Manager
@MainActor
class PaymentReminderManager: NSObject, ObservableObject {
    static let shared = PaymentReminderManager()
    
    @Published var isMonitoring = false
    @Published var upcomingPayments: [PaymentReminder] = []
    
    private let db = Firestore.firestore()
    private var membershipListener: ListenerRegistration?
    
    // Identificadores únicos para notificaciones
    private let notificationIdentifierPrefix = "gym_payment_reminder_"
    
    private override init() {
        super.init()
        requestNotificationPermissions()
    }
    
    // MARK: - Configuración inicial
    func startMonitoring() {
        print("🔔 Iniciando monitoreo de pagos...")
        isMonitoring = true
        
        // Limpiar notificaciones pendientes anteriores
        clearAllPaymentNotifications()
        
        // Configurar listener para cambios en membresías
        setupMembershipListener()
    }
    
    func stopMonitoring() {
        print("🔕 Deteniendo monitoreo de pagos...")
        isMonitoring = false
        membershipListener?.remove()
        clearAllPaymentNotifications()
    }
    
    // MARK: - Permisos de notificación
    private func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                if granted {
                    print("✅ Permisos de notificación concedidos para recordatorios")
                } else {
                    print("❌ Permisos de notificación denegados")
                }
                
                if let error = error {
                    print("❌ Error en permisos: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Listener de membresías
    private func setupMembershipListener() {
        membershipListener = db.collection("membresias")
            .whereField("activa", isEqualTo: true)
            .addSnapshotListener { [weak self] snapshot, error in
                
                if let error = error {
                    print("❌ Error en listener de membresías: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("⚠️ No se encontraron membresías activas")
                    return
                }
                
                Task {
                    await self?.processActiveMemberships(documents: documents)
                }
            }
    }
    
    // MARK: - Procesamiento de membresías activas
    private func processActiveMemberships(documents: [QueryDocumentSnapshot]) async {
        print("🔍 Procesando \(documents.count) membresías activas...")
        
        var reminders: [PaymentReminder] = []
        
        for doc in documents {
            let data = doc.data()
            
            guard let email = data["email"] as? String,
                  let fechaVencimiento = data["fechaVencimiento"] as? String,
                  let tipoMembresia = data["tipoMembresia"] as? String,
                  let precio = data["precio"] as? Double,
                  let userUID = data["userUID"] as? String else {
                continue
            }
            
            // Calcular días restantes
            if let diasRestantes = calculateDaysRemaining(from: fechaVencimiento) {
                
                // Crear recordatorio si falta 1 día
                if diasRestantes == 1 {
                    let reminder = PaymentReminder(
                        id: doc.documentID,
                        userUID: userUID,
                        email: email,
                        tipoMembresia: tipoMembresia,
                        precio: precio,
                        fechaVencimiento: fechaVencimiento,
                        diasRestantes: diasRestantes
                    )
                    
                    reminders.append(reminder)
                    
                    // Programar notificación
                    await schedulePaymentNotification(for: reminder)
                }
                
                // También programar para mañana si faltan 2 días
                else if diasRestantes == 2 {
                    let reminder = PaymentReminder(
                        id: doc.documentID,
                        userUID: userUID,
                        email: email,
                        tipoMembresia: tipoMembresia,
                        precio: precio,
                        fechaVencimiento: fechaVencimiento,
                        diasRestantes: diasRestantes
                    )
                    
                    // Programar para mañana (cuando falte 1 día)
                    await scheduleAdvancedPaymentNotification(for: reminder)
                }
            }
        }
        
        await MainActor.run {
            self.upcomingPayments = reminders
            print("📋 Recordatorios actualizados: \(reminders.count)")
        }
    }
    
    // MARK: - Cálculo de días restantes
    private func calculateDaysRemaining(from dateString: String) -> Int? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        guard let expiryDate = formatter.date(from: dateString) else {
            return nil
        }
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let expiry = calendar.startOfDay(for: expiryDate)
        
        let components = calendar.dateComponents([.day], from: today, to: expiry)
        return components.day ?? 0
    }
    
    // MARK: - Programar notificación inmediata (1 día restante)
    private func schedulePaymentNotification(for reminder: PaymentReminder) async {
        let identifier = "\(notificationIdentifierPrefix)\(reminder.id)"
        
        // Crear contenido de la notificación
        let content = UNMutableNotificationContent()
        content.title = "💳 ¡Pago Pendiente - Gym Body Gold!"
        content.body = "Tu membresía \(reminder.tipoMembresia) vence mañana. Renueva por $\(Int(reminder.precio).formatted()) para continuar entrenando."
        content.sound = .default
        content.badge = 1
        
        // Datos adicionales
        content.userInfo = [
            "type": "payment_reminder",
            "membershipId": reminder.id,
            "userUID": reminder.userUID,
            "amount": reminder.precio,
            "daysRemaining": reminder.diasRestantes
        ]
        
        // Programar para mostrar inmediatamente
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            print("✅ Notificación programada para: \(reminder.email) - Faltan \(reminder.diasRestantes) días")
        } catch {
            print("❌ Error programando notificación: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Programar notificación avanzada (para mañana cuando falte 1 día)
    private func scheduleAdvancedPaymentNotification(for reminder: PaymentReminder) async {
        let identifier = "\(notificationIdentifierPrefix)\(reminder.id)_tomorrow"
        
        // Crear contenido de la notificación
        let content = UNMutableNotificationContent()
        content.title = "⚠️ ¡Último Día - Gym Body Gold!"
        content.body = "Tu membresía \(reminder.tipoMembresia) vence HOY. Renueva urgentemente por $\(Int(reminder.precio).formatted())."
        content.sound = .default
        content.badge = 1
        
        // Datos adicionales
        content.userInfo = [
            "type": "payment_reminder_urgent",
            "membershipId": reminder.id,
            "userUID": reminder.userUID,
            "amount": reminder.precio,
            "daysRemaining": 1
        ]
        
        // Programar para mañana a las 9:00 AM
        var dateComponents = DateComponents()
        dateComponents.hour = 9
        dateComponents.minute = 0
        
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        let tomorrowAt9AM = calendar.nextDate(after: tomorrow, matching: dateComponents, matchingPolicy: .nextTime)
        
        if let notificationDate = tomorrowAt9AM {
            let trigger = UNCalendarNotificationTrigger(
                dateMatching: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: notificationDate),
                repeats: false
            )
            
            let request = UNNotificationRequest(
                identifier: identifier,
                content: content,
                trigger: trigger
            )
            
            do {
                try await UNUserNotificationCenter.current().add(request)
                print("✅ Notificación avanzada programada para: \(reminder.email) - Mañana a las 9:00 AM")
            } catch {
                print("❌ Error programando notificación avanzada: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Limpiar notificaciones
    private func clearAllPaymentNotifications() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let paymentNotificationIds = requests
                .filter { $0.identifier.hasPrefix(self.notificationIdentifierPrefix) }
                .map { $0.identifier }
            
            if !paymentNotificationIds.isEmpty {
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: paymentNotificationIds)
                print("🗑️ Limpiadas \(paymentNotificationIds.count) notificaciones de pago pendientes")
            }
        }
    }
    
    // MARK: - Funciones de utilidad
    func getUpcomingPaymentsCount() -> Int {
        return upcomingPayments.count
    }
    
    func getPaymentsDueTomorrow() -> [PaymentReminder] {
        return upcomingPayments.filter { $0.diasRestantes == 1 }
    }
    
    // MARK: - Función manual para testing
    func testPaymentNotification() async {
        let testContent = UNMutableNotificationContent()
        testContent.title = "🧪 Test - Gym Body Gold"
        testContent.body = "Esta es una notificación de prueba del sistema de recordatorios de pago."
        testContent.sound = .default
        testContent.badge = 1
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        let request = UNNotificationRequest(
            identifier: "test_payment_notification",
            content: testContent,
            trigger: trigger
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            print("✅ Notificación de prueba programada")
        } catch {
            print("❌ Error en notificación de prueba: \(error.localizedDescription)")
        }
    }
}

// MARK: - Vista de monitoreo para administradores
struct PaymentReminderDashboard: View {
    @StateObject private var reminderManager = PaymentReminderManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("💳 Recordatorios de Pago")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.brandGold)
                    
                    Text(reminderManager.isMonitoring ? "Sistema activo" : "Sistema inactivo")
                        .font(.caption)
                        .foregroundColor(reminderManager.isMonitoring ? .green : .orange)
                }
                
                Spacer()
                
                // Badge con cantidad de pagos pendientes
                if reminderManager.getUpcomingPaymentsCount() > 0 {
                    Text("\(reminderManager.getUpcomingPaymentsCount())")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.brandBlack)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange)
                        .cornerRadius(12)
                }
            }
            
            // Control del sistema
            HStack {
                Button(action: {
                    if reminderManager.isMonitoring {
                        reminderManager.stopMonitoring()
                    } else {
                        reminderManager.startMonitoring()
                    }
                }) {
                    HStack {
                        Image(systemName: reminderManager.isMonitoring ? "pause.circle.fill" : "play.circle.fill")
                        Text(reminderManager.isMonitoring ? "Detener" : "Iniciar")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.brandWhite)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(reminderManager.isMonitoring ? Color.red.opacity(0.8) : Color.green.opacity(0.8))
                    .cornerRadius(8)
                }
                
                Spacer()
                
                // Botón de prueba
                Button(action: {
                    Task {
                        await reminderManager.testPaymentNotification()
                    }
                }) {
                    HStack {
                        Image(systemName: "bell.badge")
                        Text("Test")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.brandBlack)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.brandGold.opacity(0.8))
                    .cornerRadius(8)
                }
            }
            
            // Lista de recordatorios activos
            if !reminderManager.upcomingPayments.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Pagos con vencimiento mañana:")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.brandLight)
                    
                    ForEach(reminderManager.upcomingPayments) { reminder in
                        PaymentReminderRow(reminder: reminder)
                    }
                }
            } else {
                HStack {
                    Image(systemName: "checkmark.circle")
                        .foregroundColor(.green)
                    Text("No hay pagos pendientes para mañana")
                        .font(.subheadline)
                        .foregroundColor(.brandLight.opacity(0.7))
                }
                .padding(.vertical, 8)
            }
        }
        .padding(20)
        .background(Color.brandDark)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.brandGold.opacity(0.2), lineWidth: 1)
        )
        .onAppear {
            // Auto-iniciar el sistema cuando aparece la vista
            if !reminderManager.isMonitoring {
                reminderManager.startMonitoring()
            }
        }
    }
}

// MARK: - Fila individual de recordatorio
struct PaymentReminderRow: View {
    let reminder: PaymentReminder
    
    var body: some View {
        HStack(spacing: 12) {
            // Icono de urgencia
            Image(systemName: reminder.isUrgent ? "exclamationmark.triangle.fill" : "clock.fill")
                .foregroundColor(reminder.isUrgent ? .red : .orange)
                .font(.title3)
            
            // Información
            VStack(alignment: .leading, spacing: 2) {
                Text(reminder.email)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.brandLight)
                
                Text("\(reminder.tipoMembresia) - \(reminder.formattedPrice)")
                    .font(.caption)
                    .foregroundColor(.brandGold)
            }
            
            Spacer()
            
            // Badge de días restantes
            Text("\(reminder.diasRestantes) día\(reminder.diasRestantes == 1 ? "" : "s")")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(.brandWhite)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(reminder.isUrgent ? Color.red : Color.orange)
                .cornerRadius(8)
        }
        .padding(8)
        .background(Color.brandBlack.opacity(0.3))
        .cornerRadius(8)
    }
}

// MARK: - Extensión para integrar en el Dashboard
extension AdminDashboard {
    // Agregar esta vista al dashboard administrativo
    var paymentReminderSection: some View {
        PaymentReminderDashboard()
    }
}

// MARK: - Auto-inicio del sistema
extension PaymentReminderManager {
    // Función para auto-inicializar cuando se abre la app
    static func initializeOnAppStart() {
        Task {
            await MainActor.run {
                PaymentReminderManager.shared.startMonitoring()
            }
        }
    }
}
