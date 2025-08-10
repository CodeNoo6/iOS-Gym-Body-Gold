// MARK: - Notification Model
import Foundation
import SwiftUI

struct PushNotification: Identifiable, Codable {
    let id = UUID()
    let title: String
    let body: String
    let data: [String: String]
    let receivedAt: Date
    var isRead: Bool = false
    let type: NotificationType
    
    enum NotificationType: String, Codable, CaseIterable {
        case classReminder = "class_reminder"
        case excuseApproved = "excuse_approved"
        case excuseDenied = "excuse_denied"
        case announcement = "announcement"
        case general = "general"
        
        var icon: String {
            switch self {
            case .classReminder: return "bell.badge"
            case .excuseApproved: return "checkmark.circle"
            case .excuseDenied: return "xmark.circle"
            case .announcement: return "megaphone"
            case .general: return "bell"
            }
        }
        
        var color: Color {
            switch self {
            case .classReminder: return .brandGold
            case .excuseApproved: return .brandSuccess
            case .excuseDenied: return .brandError
            case .announcement: return .brandError
            case .general: return .brandLight
            }
        }
    }
    
    init(title: String, body: String, data: [String: String] = [:], type: NotificationType = .general) {
        self.title = title
        self.body = body
        self.data = data
        self.receivedAt = Date()
        self.type = type
    }
}

// MARK: - Notification Manager
class NotificationManager: ObservableObject {
    @Published var notifications: [PushNotification] = []
    @Published var unreadCount: Int = 0
    
    private let userDefaults = UserDefaults.standard
    private let notificationsKey = "SavedNotifications"
    
    init() {
        loadNotifications()
        setupNotificationListener()
    }
    
    private func setupNotificationListener() {
        // Escuchar notificaciones del AppDelegate
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePushNotification),
            name: Notification.Name("PushNotificationReceived"),
            object: nil
        )
    }
    
    @objc private func handlePushNotification(_ notification: Notification) {
        guard let userInfo = notification.userInfo as? [String: Any] else { return }
        
        let title = userInfo["title"] as? String ?? "Nueva notificación"
        let body = userInfo["body"] as? String ?? ""
        let data = userInfo["data"] as? [String: String] ?? [:]
        
        // Determinar tipo de notificación
        let typeString = data["type"] ?? "general"
        let type = PushNotification.NotificationType(rawValue: typeString) ?? .general
        
        let pushNotification = PushNotification(
            title: title,
            body: body,
            data: data,
            type: type
        )
        
        addNotification(pushNotification)
    }
    
    func addNotification(_ notification: PushNotification) {
        DispatchQueue.main.async {
            self.notifications.insert(notification, at: 0)
            self.updateUnreadCount()
            self.saveNotifications()
            
            // Limitar a 50 notificaciones máximo
            if self.notifications.count > 50 {
                self.notifications = Array(self.notifications.prefix(50))
            }
        }
    }
    
    func markAsRead(_ notification: PushNotification) {
        if let index = notifications.firstIndex(where: { $0.id == notification.id }) {
            notifications[index].isRead = true
            updateUnreadCount()
            saveNotifications()
        }
    }
    
    func markAllAsRead() {
        notifications = notifications.map { notification in
            var updated = notification
            updated.isRead = true
            return updated
        }
        updateUnreadCount()
        saveNotifications()
    }
    
    func deleteNotification(_ notification: PushNotification) {
        notifications.removeAll { $0.id == notification.id }
        updateUnreadCount()
        saveNotifications()
    }
    
    func clearAllNotifications() {
        notifications.removeAll()
        updateUnreadCount()
        saveNotifications()
    }
    
    private func updateUnreadCount() {
        unreadCount = notifications.filter { !$0.isRead }.count
    }
    
    private func saveNotifications() {
        if let data = try? JSONEncoder().encode(notifications) {
            userDefaults.set(data, forKey: notificationsKey)
        }
    }
    
    private func loadNotifications() {
        if let data = userDefaults.data(forKey: notificationsKey),
           let notifications = try? JSONDecoder().decode([PushNotification].self, from: data) {
            self.notifications = notifications
            updateUnreadCount()
        }
    }
    
    // Función para agregar notificación de prueba
    func addTestNotification() {
        let testNotification = PushNotification(
            title: "🎉 Notificación de Prueba",
            body: "Esta es una notificación de prueba para verificar el funcionamiento del sistema.",
            data: ["test": "true"],
            type: .announcement
        )
        addNotification(testNotification)
    }
}

// MARK: - Notification Card View
struct NotificationCardView: View {
    let notification: PushNotification
    let onRead: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(notification.type.color.opacity(0.2))
                    .frame(width: 36, height: 36)
                
                Image(systemName: notification.type.icon)
                    .foregroundColor(notification.type.color)
                    .font(.system(size: 16, weight: .semibold))
            }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(notification.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.brandWhite)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    if !notification.isRead {
                        Circle()
                            .fill(Color.brandGold)
                            .frame(width: 8, height: 8)
                    }
                }
                
                Text(notification.body)
                    .font(.caption)
                    .foregroundColor(.brandLight.opacity(0.9))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                HStack {
                    Text(timeAgo(from: notification.receivedAt))
                        .font(.caption2)
                        .foregroundColor(.brandGray)
                    
                    Spacer()
                    
                    // Action buttons
                    HStack(spacing: 8) {
                        if !notification.isRead {
                            Button("Leer") {
                                onRead()
                            }
                            .font(.caption2)
                            .foregroundColor(.brandGold)
                        }
                        
                        Button("Eliminar") {
                            onDelete()
                        }
                        .font(.caption2)
                        .foregroundColor(.brandError.opacity(0.8))
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.brandDark.opacity(notification.isRead ? 0.3 : 0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    notification.isRead ?
                    Color.clear :
                    Color.brandGold.opacity(0.3),
                    lineWidth: 1
                )
        )
    }
    
    private func timeAgo(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.locale = Locale(identifier: "es_ES")
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
