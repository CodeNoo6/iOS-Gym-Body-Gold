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
    
    static func cancelAllReminders() {
            print("🔕 Cancelando todos los recordatorios existentes")
            
            UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
                let reminderIds = requests
                    .filter { $0.identifier.hasPrefix("payment_reminder_") }
                    .map { $0.identifier }
                
                if !reminderIds.isEmpty {
                    UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: reminderIds)
                    print("🗑️ Cancelados \(reminderIds.count) recordatorios pendientes")
                } else {
                    print("ℹ️ No hay recordatorios pendientes para cancelar")
                }
            }
        }
    
    private static func formatDate(_ date: Date) -> String {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "es_ES")
            formatter.dateStyle = .short
            formatter.timeStyle = .none
            return formatter.string(from: date)
        }
    
    private static func schedulePaymentReminder(subscriptionId: String, studentName: String, endDate: Date, userId: String) {
            
            // Calcular fecha de recordatorio (1 día antes)
            let reminderDate = Calendar.current.date(byAdding: .day, value: -1, to: endDate)
            
            guard let reminderDate = reminderDate, reminderDate > Date() else {
                print("⚠️ Fecha de recordatorio inválida para \(studentName)")
                return
            }
            
            let content = UNMutableNotificationContent()
            content.title = "⚠️ Vencimiento de Suscripción"
            content.body = "La suscripción de \(studentName) vence mañana (\(formatDate(endDate)))"
            content.sound = .default
            
            // IMPORTANTE: Agregar userId a los userInfo
            content.userInfo = [
                "type": "payment_reminder",
                "subscriptionId": subscriptionId,
                "studentName": studentName,
                "endDate": endDate.timeIntervalSince1970,
                "userId": userId // Incluir userId para filtrado
            ]
            
            // Crear trigger para la fecha específica
            let calendar = Calendar.current
            let dateComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: reminderDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
            
            let identifier = "payment_reminder_\(subscriptionId)_\(userId)" // Incluir userId en identifier
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("❌ Error programando recordatorio para \(studentName): \(error)")
                } else {
                    print("✅ Recordatorio programado para \(studentName) el \(formatDate(reminderDate)) (Usuario: \(userId))")
                }
            }
        }
    
    static func initializeForUser(userId: String) {
            print("🔔 Inicializando recordatorios para usuario específico: \(userId)")
            
            // Cancelar recordatorios existentes para evitar duplicados
            cancelAllReminders()
            
            let db = Firestore.firestore()
            
            // Obtener solo las suscripciones del usuario autenticado que estén activas
            db.collection("membresias")
                .whereField("userUID", isEqualTo: userId)
                .whereField("activa", isEqualTo: "true")
                .getDocuments { snapshot, error in
                    
                    if let error = error {
                        print("❌ Error obteniendo suscripciones para usuario \(userId): \(error)")
                        return
                    }
                    
                    guard let documents = snapshot?.documents else {
                        print("📄 No se encontraron suscripciones para usuario \(userId)")
                        return
                    }
                    
                    print("📊 Encontradas \(documents.count) suscripciones activas para usuario \(userId)")
                    
                    for document in documents {
                        let data = document.data()
                        
                        guard let endDate = (data["endDate"] as? Timestamp)?.dateValue(),
                              let studentName = data["studentName"] as? String else {
                            continue
                        }
                        
                        let subscriptionId = document.documentID
                        
                        // Programar recordatorio solo si la fecha de vencimiento está en el futuro
                        if endDate > Date() {
                            schedulePaymentReminder(
                                subscriptionId: subscriptionId,
                                studentName: studentName,
                                endDate: endDate,
                                userId: userId // Pasar el userId específico
                            )
                        }
                    }
                }
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
    
    func getMembershipsExpiringToday() -> [PaymentReminder] {
        return upcomingPayments.filter { $0.diasRestantes == 0 }
    }

    func getMembershipsExpiringTomorrow() -> [PaymentReminder] {
        return upcomingPayments.filter { $0.diasRestantes == 1 }
    }

    func getTotalExpiringCount() -> Int {
        return upcomingPayments.count
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
                
                if diasRestantes == 0 || diasRestantes == 1 {
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
                        
                        // Programar notificación inmediata para ambos casos
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
        // Contar membresías que expiran hoy (0 días) o mañana (1 día)
        return upcomingPayments.filter { $0.diasRestantes <= 1 }.count
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
                
                let todayCount = reminderManager.getMembershipsExpiringToday().count
                let tomorrowCount = reminderManager.getMembershipsExpiringTomorrow().count
                let totalCount = todayCount + tomorrowCount
                
                if totalCount > 0 {
                                HStack(spacing: 8) {
                                    // Badge crítico (expiran hoy)
                                    if todayCount > 0 {
                                        Text("\(todayCount)")
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .foregroundColor(.brandWhite)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 3)
                                            .background(Color.red)
                                            .cornerRadius(8)
                                    }
                                    
                                    // Badge urgente (expiran mañana)
                                    if tomorrowCount > 0 {
                                        Text("\(tomorrowCount)")
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .foregroundColor(.brandBlack)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 3)
                                            .background(Color.orange)
                                            .cornerRadius(8)
                                    }
                                }
                            }
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
            
            // Lista de recordatorios activos
            if !reminderManager.upcomingPayments.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            // Críticos (expiran hoy)
                            let todayReminders = reminderManager.getMembershipsExpiringToday()
                            if !todayReminders.isEmpty {
                                Text("🚨 Expiran HOY (\(todayReminders.count)):")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.red)
                                
                                ForEach(todayReminders) { reminder in
                                    PaymentReminderRow(reminder: reminder)
                                }
                            }
                            
                            // Urgentes (expiran mañana)
                            let tomorrowReminders = reminderManager.getMembershipsExpiringTomorrow()
                            if !tomorrowReminders.isEmpty {
                                Text("⏰ Expiran MAÑANA (\(tomorrowReminders.count)):")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.orange)
                                
                                ForEach(tomorrowReminders) { reminder in
                                    PaymentReminderRow(reminder: reminder)
                                }
                            }
                        }
                    } else {
                        HStack {
                            Image(systemName: "checkmark.circle")
                                .foregroundColor(.green)
                            Text("No hay vencimientos urgentes")
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
    
    private var urgencyColor: Color {
            switch reminder.diasRestantes {
            case 0: return .red
            case 1: return .orange
            default: return .yellow
            }
        }
        
        private var urgencyText: String {
            switch reminder.diasRestantes {
            case 0: return "¡HOY!"
            case 1: return "Mañana"
            default: return "\(reminder.diasRestantes) días"
            }
        }
    
    private var urgencyIcon: String {
            switch reminder.diasRestantes {
            case 0: return "exclamationmark.triangle.fill"
            case 1: return "clock.badge.exclamationmark"
            default: return "clock"
            }
        }
    
    var body: some View {
            HStack(spacing: 12) {
                // Icono de urgencia
                Image(systemName: urgencyIcon)
                    .foregroundColor(urgencyColor)
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
                    
                    Text("Vence: \(reminder.fechaVencimiento)")
                        .font(.caption2)
                        .foregroundColor(.brandLight.opacity(0.6))
                }
                
                Spacer()
                
                // Badge de urgencia
                Text(urgencyText)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.brandWhite)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(urgencyColor)
                    .cornerRadius(8)
            }
            .padding(8)
            .background(Color.brandBlack.opacity(0.3))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(urgencyColor.opacity(0.3), lineWidth: 1)
            )
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
