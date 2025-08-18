//
//  HomeScreen.swift
//  gymadministrator
//
//  Created by Ruben Camargo on 9/08/25.
//

import Foundation
import SwiftUI
import Firebase
import FirebaseCore
import FirebaseMessaging
import FirebaseFirestore
import FirebaseAuth
import UserNotifications
import SwiftUI
import UIKit

final class OllamaStreamer: NSObject, ObservableObject, URLSessionDataDelegate {
    /// Callback que entrega fragmentos (chunk, done)
    var onChunk: ((String, Bool) -> Void)?

    private var session: URLSession?
    private var task: URLSessionDataTask?
    private var buffer = ""

    func send(prompt: String, model: String = "llama3", baseURL: URL) {
        // Crear request
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let json: [String: Any] = ["model": model, "prompt": prompt, "stream": true]
        request.httpBody = try? JSONSerialization.data(withJSONObject: json, options: [])

        // Reset buffer y crear session con delegado
        buffer = ""
        let config = URLSessionConfiguration.default
        session = URLSession(configuration: config, delegate: self, delegateQueue: nil)

        task = session?.dataTask(with: request)
        task?.resume()
    }

    // Recibe datos parciales conforme llegan
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard let part = String(data: data, encoding: .utf8) else { return }
        buffer += part

        // Procesar línea por línea (cada línea debe ser un JSON del stream)
        while let range = buffer.range(of: "\n") {
            let line = String(buffer[..<range.lowerBound])
            buffer = String(buffer[range.upperBound...])

            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }

            if let jsonData = trimmed.data(using: .utf8),
               let obj = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                if let resp = obj["response"] as? String {
                    let done = (obj["done"] as? Bool) ?? false
                    DispatchQueue.main.async {
                        self.onChunk?(resp, done)
                    }
                } else if let err = obj["error"] as? String {
                    DispatchQueue.main.async {
                        self.onChunk?("❌ \(err)", true)
                    }
                }
            } else {
                // Si no es JSON válido, devolver la línea tal cual
                DispatchQueue.main.async {
                    self.onChunk?(trimmed, false)
                }
            }
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let err = error {
            DispatchQueue.main.async { self.onChunk?("❌ \(err.localizedDescription)", true) }
        } else {
            DispatchQueue.main.async { self.onChunk?("", true) } // done
        }
        session.invalidateAndCancel()
        self.session = nil
        self.task = nil
        buffer = ""
    }

    func cancel() {
        task?.cancel()
        session?.invalidateAndCancel()
        session = nil
        task = nil
        buffer = ""
    }
}


// MARK: - IA Chat Card Component
struct IAChatCard: View {
    @State private var inputText = ""
    @State private var messages: [(text: String, isUser: Bool)] = [
        (text: "💛 ¡Hola! Soy Gymius, tu asistente en \n\n ✨🏋️‍♂️ Gym Body Gold 🏋️‍♀️✨.", isUser: false),
        (text: "💬 Recuerda: las decisiones finales siempre son de tus entrenadores 💪🌟.", isUser: false)
    ]
    @State private var isLoading = false
    @State private var isExpanded = true
    @StateObject private var streamer = OllamaStreamer()
    
    let apiURL = URL(string: "http://154.38.164.193:11434/api/generate")!
    
    var body: some View {
        VStack(spacing: 0) {
            // Header del chat
            HStack {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(
                                colors: [Color.brandGold, Color.brandGold.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: 40, height: 40)
                        
                        Image(systemName: "brain")
                            .foregroundColor(.brandBlack)
                            .font(.system(size: 20, weight: .bold))
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Gymius IA")
                            .font(.headline)
                            .foregroundColor(.brandWhite)
                        
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 8, height: 8)
                            Text("En línea")
                                .font(.caption)
                                .foregroundColor(.brandLight)
                        }
                    }
                }
                
                Spacer()
                
                Button(action: { withAnimation(.spring()) { isExpanded.toggle() } }) {
                    Image(systemName: isExpanded ? "chevron.down.circle.fill" : "chevron.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(.brandGold)
                }
            }
            .padding()
            .background(Color.brandDark)
            
            if isExpanded {
                // Área de mensajes
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(Array(messages.enumerated()), id: \.offset) { index, message in
                                MessageBubble(
                                    text: message.text,
                                    isUser: message.isUser
                                )
                                .id(index)
                            }
                            
                            if isLoading {
                                HStack(spacing: 8) {
                                    ForEach(0..<3) { index in
                                        Circle()
                                            .fill(Color.brandGold)
                                            .frame(width: 8, height: 8)
                                            .opacity(0.6)
                                            .animation(
                                                Animation.easeInOut(duration: 0.6)
                                                    .repeatForever()
                                                    .delay(Double(index) * 0.2),
                                                value: isLoading
                                            )
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 8)
                            }
                        }
                        .padding()
                    }
                    .frame(height: 300)
                    .background(Color.brandBlack.opacity(0.3))
                    .onChange(of: messages.count) { _ in
                        if let last = messages.indices.last {
                            withAnimation { proxy.scrollTo(last, anchor: .bottom) }
                        }
                    }
                }
                
                // Input area
                HStack(spacing: 12) {
                    TextField("Escribe tu pregunta...", text: $inputText)
                        .padding(12)
                        .background(Color.brandDark)
                        .foregroundColor(.brandWhite)
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.brandGold.opacity(0.3), lineWidth: 1)
                        )
                    
                    Button(action: sendMessage) {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(
                                    colors: isLoading ? [Color.gray, Color.gray.opacity(0.7)] : [Color.brandGold, Color.brandGold.opacity(0.7)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                                .frame(width: 44, height: 44)
                            
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .brandWhite))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "paperplane.fill")
                                    .foregroundColor(.brandBlack)
                                    .rotationEffect(.degrees(45))
                            }
                        }
                    }
                    .disabled(inputText.isEmpty || isLoading)
                }
                .padding()
                .background(Color.brandDark)
            }
        }
        .background(Color.brandDark)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.brandGold.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)
        .onAppear(perform: setupStreamer)
    }
    
    private func setupStreamer() {
        streamer.onChunk = { chunk, done in
            if chunk.hasPrefix("❌") {
                messages.append((text: chunk, isUser: false))
                isLoading = false
                return
            }
            
            DispatchQueue.main.async {
                if !chunk.isEmpty {
                    if let lastIndex = messages.indices.last,
                       !messages[lastIndex].isUser,
                       messages[lastIndex].text != "¡Hola! Me llamo Gymius y te ayudaré en lo que necesites para tus entrenamientos en el gym" {
                        messages[lastIndex].text += chunk
                    } else {
                        messages.append((text: chunk, isUser: false))
                    }
                }
                
                if done {
                    isLoading = false
                }
            }
        }
    }
    
    private func sendMessage() {
        let userMessage = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !userMessage.isEmpty else { return }
        
        messages.append((text: userMessage, isUser: true))
        inputText = ""
        isLoading = true
        
        // Contexto del gimnasio para mejores respuestas
        let gymContext = """
        Eres un asistente virtual para Gym Body Gold. Ayudas con:
        - Solo responder temas de nutrición y ejercicios de pesas
        - No responder con entrenador certificado sino con Óscar de Gym Body Gold
        - Respuestas cortas
        - No te presentes
        - Te llamas Gymius
        - Rutinas de ejercicio y nutrición
        - Dudas sobre el gimnasio
        - Da respuestas cortas y concretas
        - Responde de una manera cordial y amigable
        - Y no coloques si es un chiste o es una respuesta con ":"
        - No conoces ningun otro tema que no sea de gimnasio y ejercicios de lo contrario responder con un chiste estrictamente
        
        Pregunta del usuario: \(userMessage)
        """
        
        streamer.send(prompt: gymContext, model: "mistral", baseURL: apiURL)
    }
}

// MARK: - Message Bubble Component
struct MessageBubble: View {
    let text: String
    let isUser: Bool
    
    var body: some View {
        HStack {
            if isUser { Spacer() }
            
            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                Text(text)
                    .padding(12)
                    .background(
                        isUser ?
                        LinearGradient(
                            colors: [Color.brandGold, Color.brandGold.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ) :
                        LinearGradient(
                            colors: [Color.brandDark, Color.brandDark.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .foregroundColor(isUser ? .brandBlack : .brandWhite)
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isUser ? Color.clear : Color.brandGold.opacity(0.2), lineWidth: 1)
                    )
            }
            .frame(maxWidth: UIScreen.main.bounds.width * 0.7, alignment: isUser ? .trailing : .leading)
            
            if !isUser { Spacer() }
        }
    }
}

enum BroadcastMessageType: String, CaseIterable {
    case general = "general"
    case promotion = "promotion"
    case maintenance = "maintenance"
    case event = "event"
    case motivation = "motivation"
    case health = "health"
    
    var icon: String {
        switch self {
        case .general:
            return "info.circle.fill"
        case .promotion:
            return "tag.fill"
        case .maintenance:
            return "wrench.and.screwdriver.fill"
        case .event:
            return "calendar.badge.plus"
        case .motivation:
            return "flame.fill"
        case .health:
            return "heart.fill"
        }
    }
    
    var title: String {
        switch self {
        case .general:
            return "General"
        case .promotion:
            return "Promoción"
        case .maintenance:
            return "Mantenimiento"
        case .event:
            return "Evento"
        case .motivation:
            return "Motivación"
        case .health:
            return "Salud"
        }
    }
    
    var color: Color {
        switch self {
        case .general:
            return .blue
        case .promotion:
            return .orange
        case .maintenance:
            return .yellow
        case .event:
            return .purple
        case .motivation:
            return .red
        case .health:
            return .green
        }
    }
    
    var defaultTitle: String {
        switch self {
        case .general:
            return "📢 Información Importante - Gym Body Gold"
        case .promotion:
            return "🏷️ ¡Oferta Especial en Gym Body Gold!"
        case .maintenance:
            return "🔧 Mantenimiento Programado"
        case .event:
            return "🎉 Nuevo Evento en Gym Body Gold"
        case .motivation:
            return "💪 ¡Mantente Motivado!"
        case .health:
            return "❤️ Consejo de Salud"
        }
    }
    
    var defaultBody: String {
        switch self {
        case .general:
            return "Tenemos información importante que compartir contigo. Revisa los detalles en la app."
        case .promotion:
            return "¡No te pierdas nuestras ofertas especiales! Aprovecha descuentos exclusivos para miembros."
        case .maintenance:
            return "Informamos que habrá mantenimiento programado. Consulta los horarios disponibles."
        case .event:
            return "¡Tenemos un nuevo evento emocionante! Únete y vive la experiencia Gym Body Gold."
        case .motivation:
            return "¡Sigue adelante! Cada día es una oportunidad para ser mejor. ¡Tú puedes!"
        case .health:
            return "Recuerda mantener una rutina saludable. Tu bienestar es nuestra prioridad."
        }
    }
}

// MARK: - Card de tipo de mensaje
struct BroadcastTypeCard: View {
    let type: BroadcastMessageType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: type.icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .brandBlack : type.color)
                
                Text(type.title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(isSelected ? .brandBlack : .brandLight)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                isSelected ?
                LinearGradient(
                    colors: [Color.brandGold, Color.brandGold.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ) :
                LinearGradient(
                    colors: [Color.brandDark, Color.brandDark.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isSelected ? Color.brandGold : type.color.opacity(0.3),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .animation(.spring(response: 0.3), value: isSelected)
        }
    }
}

// MARK: - Admin Quick Action Button
struct AdminQuickActionButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.brandGold)
                
                VStack(spacing: 2) {
                    Text(title)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.brandLight)
                    
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundColor(.brandLight.opacity(0.7))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.brandBlack.opacity(0.3))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.brandGold.opacity(0.2), lineWidth: 1)
            )
        }
    }
}

// MARK: - Broadcast Message Sheet
struct BroadcastMessageSheet: View {
    @ObservedObject var userManager: AdminUserManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var messageTitle = ""
    @State private var messageBody = ""
    @State private var selectedMessageType: BroadcastMessageType = .general
    @State private var isSending = false
    @State private var sendingProgress = 0.0
    @State private var showingConfirmation = false
    @State private var activeUsersCount = 0
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.brandBlack.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header Info
                        VStack(spacing: 12) {
                            Image(systemName: "megaphone.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.brandGold)
                            
                            Text("Mensaje Masivo")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.brandGold)
                            
                            Text("Envía un mensaje personalizado a todos los clientes activos")
                                .font(.subheadline)
                                .foregroundColor(.brandLight.opacity(0.7))
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal)
                        
                        // Message Type Selector
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Tipo de Mensaje")
                                .font(.headline)
                                .foregroundColor(.brandGold)
                            
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                                ForEach(BroadcastMessageType.allCases, id: \.self) { type in
                                    BroadcastTypeCard(
                                        type: type,
                                        isSelected: selectedMessageType == type
                                    ) {
                                        selectedMessageType = type
                                        updateMessageContent()
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        // Custom Message Fields
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Personalizar Mensaje")
                                .font(.headline)
                                .foregroundColor(.brandGold)
                            
                            // Title Field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Título")
                                    .font(.subheadline)
                                    .foregroundColor(.brandLight)
                                
                                TextField("Escribe el título de la notificación", text: $messageTitle)
                                    .padding(12)
                                    .background(Color.brandDark)
                                    .foregroundColor(.brandWhite)
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.brandGold.opacity(0.3), lineWidth: 1)
                                    )
                            }
                            
                            // Body Field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Mensaje")
                                    .font(.subheadline)
                                    .foregroundColor(.brandLight)
                                
                                TextField("Escribe el contenido del mensaje", text: $messageBody, axis: .vertical)
                                    .lineLimit(3...6)
                                    .padding(12)
                                    .background(Color.brandDark)
                                    .foregroundColor(.brandWhite)
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.brandGold.opacity(0.3), lineWidth: 1)
                                    )
                            }
                            
                            // Preview
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Vista Previa")
                                    .font(.subheadline)
                                    .foregroundColor(.brandLight)
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Image(systemName: "bell.fill")
                                            .foregroundColor(.brandGold)
                                        Text("Gym Body Gold")
                                            .font(.caption)
                                            .foregroundColor(.brandLight.opacity(0.7))
                                        Spacer()
                                        Text("ahora")
                                            .font(.caption)
                                            .foregroundColor(.brandLight.opacity(0.5))
                                    }
                                    
                                    Text(messageTitle.isEmpty ? "Título del mensaje" : messageTitle)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.brandWhite)
                                    
                                    Text(messageBody.isEmpty ? "Contenido del mensaje aparecerá aquí" : messageBody)
                                        .font(.caption)
                                        .foregroundColor(.brandLight.opacity(0.8))
                                }
                                .padding(12)
                                .background(Color.brandDark.opacity(0.3))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.brandGold.opacity(0.2), lineWidth: 1)
                                )
                            }
                        }
                        .padding(.horizontal)
                        
                        // Send Progress
                        if isSending {
                            VStack(spacing: 12) {
                                Text("Enviando mensajes...")
                                    .font(.headline)
                                    .foregroundColor(.brandGold)
                                
                                ProgressView(value: sendingProgress, total: 1.0)
                                    .progressViewStyle(LinearProgressViewStyle(tint: .brandGold))
                                    .background(Color.brandDark)
                                    .cornerRadius(4)
                                
                                Text("\(Int(sendingProgress * Double(activeUsersCount))) de \(activeUsersCount) enviados")
                                    .font(.caption)
                                    .foregroundColor(.brandLight.opacity(0.7))
                            }
                            .padding()
                            .background(Color.brandDark.opacity(0.5))
                            .cornerRadius(12)
                            .padding(.horizontal)
                        }
                    }
                }
            }
            .navigationTitle("Mensaje Masivo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancelar") {
                        dismiss()
                    }
                    .foregroundColor(.brandLight)
                    .disabled(isSending)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Enviar") {
                        showingConfirmation = true
                    }
                    .foregroundColor(.brandGold)
                    .fontWeight(.semibold)
                    .disabled(messageTitle.isEmpty || messageBody.isEmpty || isSending)
                }
            }
            .alert("Confirmar Envío", isPresented: $showingConfirmation) {
                Button("Enviar", role: .cancel) {
                    Task {
                        await sendBroadcastMessage()
                    }
                }
                Button("Cancelar", role: .destructive) { }
            } message: {
                Text("¿Estás seguro de que quieres enviar este mensaje a todos los clientes activos?")
            }
            .onAppear {
                updateActiveUsersCount()
                updateMessageContent()
            }
            .preferredColorScheme(.dark)
        }
    }
    
    private func updateActiveUsersCount() {
        activeUsersCount = userManager.adminUsers.filter { $0.activo }.count
    }
    
    private func updateMessageContent() {
        messageTitle = selectedMessageType.defaultTitle
        messageBody = selectedMessageType.defaultBody
    }
    
    private func sendBroadcastMessage() async {
        isSending = true
        sendingProgress = 0.0
        
        // ✅ FORZAR RECARGA antes de enviar
        print("🔄 Recargando usuarios antes del envío masivo...")
        await userManager.forceReloadUsers()
        
        // Esperar un momento para que se complete la recarga
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 segundos
        
        // Resto del código igual...
        print("🔍 DEBUG MENSAJE MASIVO:")
        print("====================================")
        print("📊 Total usuarios cargados: \(userManager.adminUsers.count)")
        
        for user in userManager.adminUsers {
            print("👤 \(user.nombre) \(user.apellido) - Activo: \(user.activo) - Email: \(user.email)")
        }
        
        let activeUsers = userManager.adminUsers.filter { $0.activo }
        let totalUsers = activeUsers.count
        
        print("✅ Usuarios activos encontrados: \(totalUsers)")
        print("====================================")
        
        if totalUsers == 0 {
            print("❌ No hay usuarios activos para enviar mensajes")
            await MainActor.run {
                isSending = false
                // Mostrar alerta al usuario
            }
            return
        }
        
        // Resto del código de envío...
        for (index, user) in activeUsers.enumerated() {
            print("📤 Enviando mensaje \(index + 1)/\(totalUsers) a: \(user.nombre)")
            
            await userManager.sendCustomNotificationToUser(
                userId: user.uid,
                userName: user.nombre,
                title: messageTitle,
                body: messageBody,
                messageType: selectedMessageType
            )
            
            await MainActor.run {
                sendingProgress = Double(index + 1) / Double(totalUsers)
            }
            
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
        
        await MainActor.run {
            isSending = false
            dismiss()
        }
        
        print("✅ Mensaje masivo enviado a \(totalUsers) usuarios activos")
    }
}

// MARK: - Admin Header Card

struct AdminHeaderCard: View {
    let authManager: AuthManager
    let dashboardManager: DashboardManager
    @StateObject private var membershipManager = AdminMembershipManager()
    @StateObject private var reminderManager = PaymentReminderManager.shared // ✅ NUEVO
    @State private var showingBroadcastSheet = false
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Panel de Administrador")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.brandGold)
                    
                    Text("Bienvenido, \(authManager.currentUserData?.nombre ?? "Admin")")
                        .font(.headline)
                        .foregroundColor(.brandLight)
                    
                    Text("Gestiona membresías y configuraciones del sistema")
                        .font(.subheadline)
                        .foregroundColor(.brandLight.opacity(0.7))
                }
            }
            HStack(spacing: 12) {
                // Estadísticas rápidas
                VStack(spacing: 4) {
                    let activeCount = membershipManager.memberships.filter { $0.activa }.count
                    Text("\(activeCount)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                    
                    Text("Activas")
                        .font(.caption2)
                        .foregroundColor(.brandLight.opacity(0.7))
                }
                .padding(8)
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
                
                // ✅ NUEVO: Recordatorios de pago
                VStack(spacing: 4) {
                    let paymentReminders = reminderManager.getUpcomingPaymentsCount()
                    Text("\(paymentReminders)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                    
                    Text("Por vencer")
                        .font(.caption2)
                        .foregroundColor(.brandLight.opacity(0.7))
                }
                .padding(8)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
                
                VStack(spacing: 4) {
                    let inactiveCount = membershipManager.memberships.filter { !$0.activa }.count
                    Text("\(inactiveCount)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                    
                    Text("Pendientes")
                        .font(.caption2)
                        .foregroundColor(.brandLight.opacity(0.7))
                }
                .padding(8)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
                
                // Botón de mensaje masivo
                Button(action: {
                    showingBroadcastSheet = true
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: "megaphone.fill")
                            .font(.title2)
                            .foregroundColor(.brandBlack)
                        
                        Text("Mensaje\nMasivo")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.brandBlack)
                            .multilineTextAlignment(.center)
                    }
                    .padding(12)
                    .background(
                        LinearGradient(
                            colors: [Color.brandGold, Color.brandGold.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(10)
                }
            }
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color.brandDark, Color.brandDark.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.brandGold.opacity(0.3), lineWidth: 1)
        )
        .onAppear {
            membershipManager.loadAllMemberships()
            reminderManager.startMonitoring() // ✅ NUEVO: Auto-iniciar recordatorios
        }
        .sheet(isPresented: $showingBroadcastSheet) {
            BroadcastMessageSheet(userManager: AdminUserManager())
        }
    }
}

enum GymNotificationType {
    case accountDeactivated
    case accountActivated
    case membershipExpiring
    case paymentReminder
    case welcomeMessage
    
    var title: String {
        switch self {
        case .accountDeactivated:
            return "🚫 Cuenta Desactivada"
        case .accountActivated:
            return "✅ Cuenta Activada"
        case .membershipExpiring:
            return "⏰ Membresía por Vencer"
        case .paymentReminder:
            return "💳 Recordatorio de Pago"
        case .welcomeMessage:
            return "🏋️‍♂️ ¡Bienvenido a Gym Body Gold!"
        }
    }
    
    func body(for userName: String) -> String {
        switch self {
        case .accountDeactivated:
            return "Hola \(userName), tu cuenta ha sido desactivada. Contacta al administrador para más información."
        case .accountActivated:
            return "¡Hola \(userName)! Tu cuenta ha sido reactivada. ¡Ya puedes volver a entrenar!"
        case .membershipExpiring:
            return "Hola \(userName), tu membresía vence pronto. Renueva para seguir entrenando."
        case .paymentReminder:
            return "Hola \(userName), tienes un pago pendiente. Mantén tu membresía activa."
        case .welcomeMessage:
            return "¡Bienvenido \(userName)! Estamos emocionados de tenerte en nuestra familia fitness."
        }
    }
}

// MARK: - Errores personalizados para FCM
enum FCMError: Error {
    case invalidURL
    case authenticationFailed
    case tokenGenerationFailed
    case noUserAuthenticated
}


// MARK: - Admin User Row
struct AdminUserRow: View {
    let user: UserData
    @StateObject private var userManager = AdminUserManager()
    @State private var isToggling = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            ZStack {
                Circle()
                    .fill(Color.brandGold.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Text(String(user.nombre.prefix(1)).uppercased())
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.brandGold)
            }
            
            // Info del usuario
            VStack(alignment: .leading, spacing: 4) {
                Text("\(user.nombre) \(user.apellido)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.brandLight)
                
                Text(user.email)
                    .font(.caption)
                    .foregroundColor(.brandLight.opacity(0.7))
                
                HStack(spacing: 4) {
                    Circle()
                        .fill(user.activo ? Color.green : Color.red)
                        .frame(width: 6, height: 6)
                    
                    Text(user.activo ? "Activo" : "Inactivo")
                        .font(.caption2)
                        .foregroundColor(.brandLight.opacity(0.6))
                }
            }
            
            Spacer()
            
            // Controles de admin
            VStack(spacing: 8) {
                // Badge de rol
                Text("Cliente")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.brandGold.opacity(0.2))
                    .foregroundColor(.brandGold)
                    .cornerRadius(8)
                
                // Botón de activar/desactivar
                Button(action: {
                    Task {
                        await toggleUserStatus()
                    }
                }) {
                    HStack(spacing: 4) {
                        if isToggling {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .brandWhite))
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: user.activo ? "pause.circle.fill" : "play.circle.fill")
                                .font(.caption)
                            
                            Text(user.activo ? "Desactivar" : "Activar")
                                .font(.caption2)
                                .fontWeight(.semibold)
                        }
                    }
                    .foregroundColor(.brandWhite)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(user.activo ? Color.red.opacity(0.8) : Color.green.opacity(0.8))
                    .cornerRadius(6)
                }
                .disabled(isToggling)
                .scaleEffect(isToggling ? 0.95 : 1.0)
                .animation(.spring(response: 0.3), value: isToggling)
            }
        }
        .padding(12)
        .background(Color.brandBlack.opacity(0.3))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(user.activo ? Color.green.opacity(0.3) : Color.red.opacity(0.3), lineWidth: 1)
        )
    }
    
    private func toggleUserStatus() async {
        isToggling = true
        
        // Usar la nueva función que conecta con Laravel
        await userManager.toggleUserStatusViaLaravel(
            userId: user.uid,
            userName: user.nombre,
            currentStatus: user.activo
        )
        
        // Pequeño delay para mejor UX
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 segundos
        
        isToggling = false
    }
}

// MARK: - Stat Item
struct StatItem: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.brandLight)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.brandLight.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.brandBlack.opacity(0.3))
        .cornerRadius(12)
    }
}


struct UserAccountStatusCard: View {
    @ObservedObject var statusManager: AccountStatusManager
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: statusManager.isUserActive ? "checkmark.shield.fill" : "xmark.shield.fill")
                    .font(.title2)
                    .foregroundColor(statusManager.isUserActive ? .green : .red)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Estado de Cuenta")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.brandLight)
                    
                    Text(statusManager.isUserActive ? "Activa" : "Desactivada")
                        .font(.caption)
                        .foregroundColor(statusManager.isUserActive ? .green : .red)
                }
                
                Spacer()
                
                if !statusManager.isUserActive {
                    VStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                        
                        Text("Acceso\nLimitado")
                            .font(.caption2)
                            .foregroundColor(.orange)
                            .multilineTextAlignment(.center)
                    }
                }
            }
            
            if !statusManager.isUserActive {
                VStack(spacing: 8) {
                    Text("Tu cuenta ha sido desactivada temporalmente")
                        .font(.caption)
                        .foregroundColor(.brandLight.opacity(0.8))
                        .multilineTextAlignment(.center)
                    
                    Button(action: {
                        makePhoneCall()
                    }) {
                        HStack {
                            Image(systemName: "phone.fill")
                            Text("Contactar Gimnasio")
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.brandWhite)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(Color.orange.opacity(0.8))
                        .cornerRadius(8)
                    }
                }
            }
        }
        .padding(16)
        .background(
            statusManager.isUserActive ?
            Color.green.opacity(0.1) : Color.red.opacity(0.1)
        )
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    statusManager.isUserActive ?
                    Color.green.opacity(0.3) : Color.red.opacity(0.3),
                    lineWidth: 1
                )
        )
        .animation(.spring(response: 0.5), value: statusManager.isUserActive)
    }
    
    private func makePhoneCall() {
        let phoneNumber = "3022973150"
        
        if let phoneURL = URL(string: "tel://\(phoneNumber)") {
            if UIApplication.shared.canOpenURL(phoneURL) {
                UIApplication.shared.open(phoneURL, options: [:])
            }
        }
    }
}

@MainActor
class AccountStatusManager: ObservableObject {
    @Published var isUserActive: Bool = true
    @Published var userRole: String = "usuario"
    @Published var isLoading: Bool = true
    
    private var userListener: ListenerRegistration?
    private let db = Firestore.firestore()
    
    // MARK: - Configurar listener para el estado del usuario
    func setupUserStatusListener(userUID: String) {
        print("🔄 Configurando listener de estado para userUID: \(userUID)")
        
        // ✅ IMPORTANTE: Limpiar listener anterior si existe
        cleanup()
        
        // Configurar nuevo listener
        userListener = db.collection("usuarios").document(userUID)
            .addSnapshotListener { [weak self] snapshot, error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("❌ Error en listener de estado de usuario: \(error.localizedDescription)")
                        return
                    }
                    
                    guard let snapshot = snapshot,
                          let data = snapshot.data() else {
                        print("⚠️ No se encontraron datos del usuario")
                        return
                    }
                    
                    let newActiveStatus = data["activo"] as? Bool ?? true
                    let newRole = data["rol"] as? String ?? "usuario"
                    
                    print("📋 Estado de usuario actualizado:")
                    print("- UID: \(userUID)")
                    print("- Activo: \(newActiveStatus)")
                    print("- Rol: \(newRole)")
                    
                    // Detectar cambio de estado
                    let previousStatus = self?.isUserActive
                    
                    // ✅ ACTUALIZAR CON ANIMACIÓN
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        self?.isUserActive = newActiveStatus
                        self?.userRole = newRole
                        self?.isLoading = false
                    }
                    
                    // Mostrar notificación local si el estado cambió
                    if let previous = previousStatus, previous != newActiveStatus {
                        self?.showStatusChangeNotification(isActive: newActiveStatus)
                    }
                }
            }
    }
    
    // MARK: - Mostrar notificación local de cambio de estado
    private func showStatusChangeNotification(isActive: Bool) {
        let content = UNMutableNotificationContent()
        content.title = isActive ? "✅ Cuenta Activada" : "🚫 Cuenta Desactivada"
        content.body = isActive ?
            "Tu cuenta ha sido reactivada. ¡Ya puedes usar todas las funciones!" :
            "Tu cuenta ha sido desactivada. Contacta al administrador para más información."
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "account_status_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Error mostrando notificación local: \(error.localizedDescription)")
            } else {
                print("✅ Notificación local mostrada para cambio de estado")
            }
        }
    }
    
    // MARK: - ✅ CORREGIDO: Limpiar listener
    func cleanup() {
        print("🧹 Limpiando listener de estado de usuario...")
        userListener?.remove()
        userListener = nil
    }
}



@MainActor
class AdminUserManager: ObservableObject {
    @Published var adminUsers: [UserData] = []
    @Published var isLoading = false
    @Published var errorMessage = ""
    
    private let db = Firestore.firestore()
    private let notificationManager = FCMNotificationManager.shared
    
    // En AdminUserManager, agregar función para forzar recarga
    func forceReloadUsers() async {
        print("🔄 Forzando recarga de usuarios...")
        
        do {
            let snapshot = try await db.collection("usuarios")
                .whereField("rol", isEqualTo: "usuario")
                .getDocuments()
            
            await MainActor.run {
                self.adminUsers = snapshot.documents.compactMap { doc in
                    let data = doc.data()
                    let userData = UserData(
                        uid: doc.documentID,
                        email: data["email"] as? String ?? "",
                        displayName: data["displayName"] as? String ?? "",
                        idTipoDocumento: data["idTipoDocumento"] as? Int ?? 1,
                        numeroDocumento: data["numeroDocumento"] as? String ?? "",
                        nombre: data["nombre"] as? String ?? "",
                        apellido: data["apellido"] as? String ?? "",
                        telefono: data["telefono"] as? String ?? "",
                        fechaNacimiento: (data["fechaNacimiento"] as? Timestamp)?.dateValue() ?? Date(),
                        direccion: data["direccion"] as? String ?? "",
                        activo: data["activo"] as? Bool ?? true,
                        idGenero: data["idGenero"] as? Int ?? 1,
                        edad: data["edad"] as? String,
                        peso: data["peso"] as? String,
                        estatura: data["estatura"] as? String,
                        fechaCreacion: (data["fechaCreacion"] as? Timestamp)?.dateValue() ?? Date(),
                        rol: data["rol"] as? String ?? "usuario"
                    )
                    
                    print("👤 Usuario cargado: \(userData.nombre) - Activo: \(userData.activo)")
                    return userData
                }
                
                let activeCount = self.adminUsers.filter { $0.activo }.count
                print("✅ Recarga completada. Total: \(self.adminUsers.count), Activos: \(activeCount)")
            }
            
        } catch {
            print("❌ Error forzando recarga: \(error.localizedDescription)")
        }
    }
    
    func loadAdminUsers() {
        isLoading = true
        errorMessage = ""
        
        // Consulta a Firestore para obtener usuarios con rol "usuario"
        db.collection("usuarios")
            .whereField("rol", isEqualTo: "usuario")
            .addSnapshotListener { [weak self] snapshot, error in
                DispatchQueue.main.async {
                    self?.isLoading = false
                    
                    if let error = error {
                        self?.errorMessage = "Error al cargar usuarios: \(error.localizedDescription)"
                        print("❌ Error cargando usuarios: \(error.localizedDescription)")
                        return
                    }
                    
                    guard let documents = snapshot?.documents else {
                        self?.errorMessage = "No se encontraron documentos"
                        return
                    }
                    
                    self?.adminUsers = documents.compactMap { doc in
                        let data = doc.data()
                        return UserData(
                            uid: doc.documentID,
                            email: data["email"] as? String ?? "",
                            displayName: data["displayName"] as? String ?? "",
                            idTipoDocumento: data["idTipoDocumento"] as? Int ?? 1,
                            numeroDocumento: data["numeroDocumento"] as? String ?? "",
                            nombre: data["nombre"] as? String ?? "",
                            apellido: data["apellido"] as? String ?? "",
                            telefono: data["telefono"] as? String ?? "",
                            fechaNacimiento: (data["fechaNacimiento"] as? Timestamp)?.dateValue() ?? Date(),
                            direccion: data["direccion"] as? String ?? "",
                            activo: data["activo"] as? Bool ?? true,
                            idGenero: data["idGenero"] as? Int ?? 1,
                            edad: data["edad"] as? String,
                            peso: data["peso"] as? String,
                            estatura: data["estatura"] as? String,
                            fechaCreacion: (data["fechaCreacion"] as? Timestamp)?.dateValue() ?? Date(),
                            rol: data["rol"] as? String ?? "usuario"
                        )
                    }
                    
                    print("✅ Cargados \(self?.adminUsers.count ?? 0) usuarios")
                }
            }
    }
    
    func toggleUserActiveStatus(userId: String, currentStatus: Bool) async {
        do {
            let newStatus = !currentStatus
            
            // Actualizar en Firestore
            try await db.collection("usuarios").document(userId).updateData([
                "activo": newStatus
            ])
            
            print("✅ Estado de usuario \(userId) cambiado a: \(newStatus ? "Activo" : "Inactivo")")
            
            // Mostrar notificación de éxito
            await MainActor.run {
                // Aquí podrías mostrar un toast o notificación
                print("🔄 Usuario \(newStatus ? "activado" : "desactivado") exitosamente")
            }
            
        } catch {
            await MainActor.run {
                errorMessage = "Error al cambiar estado del usuario: \(error.localizedDescription)"
                print("❌ Error cambiando estado de usuario: \(error.localizedDescription)")
            }
        }
    }
    
    // En AdminUserManager, agregar esta función:

    func sendCustomNotificationToUser(
        userId: String,
        userName: String,
        title: String,
        body: String,
        messageType: BroadcastMessageType
    ) async {
        // Obtener FCM token del usuario desde Firestore
        let fcmToken = await getFCMTokenFromFirestore(userId: userId)
        
        // ✅ CORREGIR: Usar claves sin guiones bajos
        await FCMNotificationManager.shared.sendNotificationToUser(
            userId: userId,
            title: title,
            body: body,
            data: [
                "type": "broadcast",  // ✅ Sin guión bajo
                "messagetype": messageType.rawValue,  // ✅ Sin guión bajo
                "userid": userId,  // ✅ Sin guión bajo
                "timestamp": "\(Date().timeIntervalSince1970)",
                "source": "admin"
            ],
            directToken: fcmToken
        )
        
        print("📱 Mensaje personalizado enviado a: \(userName)")
    }
    
    func toggleUserStatusViaLaravel(userId: String, userName: String, currentStatus: Bool) async {
        print("🔄 TOGGLE USER STATUS VIA LARAVEL")
        print("====================================")
        print("👤 User ID: \(userId)")
        print("👤 User Name: \(userName)")
        print("📊 Current Status: \(currentStatus)")
        print("📊 New Status: \(!currentStatus)")
        
        // 1. Cambiar estado en Firestore
        await toggleUserActiveStatus(userId: userId, currentStatus: currentStatus)
        
        // 2. Obtener FCM token del usuario desde Firestore
        let fcmToken = await getFCMTokenFromFirestore(userId: userId)
        
        // 3. Enviar notificación via Laravel
        let newStatus = !currentStatus
        let notificationType: GymNotificationType = newStatus ? .accountActivated : .accountDeactivated
        
        print("📱 Enviando notificación de tipo: \(notificationType)")
        
        await FCMNotificationManager.shared.sendNotificationToUser(
            userId: userId,
            title: notificationType.title,
            body: notificationType.body(for: userName),
            data: [
                "type": "account_status",
                "action": newStatus ? "activated" : "deactivated",
                "userId": userId,
                "timestamp": "\(Date().timeIntervalSince1970)"
            ],
            directToken: fcmToken // ✅ Pasar el token directo
        )
        
        print("📱 Notificación enviada via Laravel")
        print("====================================")
    }

    private func getFCMTokenFromFirestore(userId: String) async -> String? {
        do {
            let document = try await db.collection("usuarios").document(userId).getDocument()
            
            if let data = document.data(),
               let token = data["fcmToken"] as? String {
                print("✅ FCM token encontrado para userId: \(userId)")
                return token
            } else {
                print("❌ No se encontró FCM token para userId: \(userId)")
                return nil
            }
        } catch {
            print("❌ Error obteniendo FCM token: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func sendDeactivationNotification(userId: String, userName: String) async {
            let notification = GymNotificationType.accountDeactivated
            
            await notificationManager.sendNotificationToUser(
                userId: userId,
                title: notification.title,
                body: notification.body(for: userName),
                data: [
                    "type": "account_status",
                    "action": "deactivated",
                    "userId": userId,
                    "timestamp": "\(Date().timeIntervalSince1970)",
                    "requiresAction": true
                ]
            )
            
            print("📱 Notificación de desactivación enviada a: \(userName)")
        }
        
        // MARK: - Enviar notificación de activación
        private func sendActivationNotification(userId: String, userName: String) async {
            let notification = GymNotificationType.accountActivated
            
            await notificationManager.sendNotificationToUser(
                userId: userId,
                title: notification.title,
                body: notification.body(for: userName),
                data: [
                    "type": "account_status",
                    "action": "activated",
                    "userId": userId,
                    "timestamp": "\(Date().timeIntervalSince1970)",
                    "requiresAction": false
                ]
            )
            
            print("📱 Notificación de activación enviada a: \(userName)")
        }
    
    func loadAllUsers() {
        isLoading = true
        errorMessage = ""
        
        // Consulta para obtener todos los usuarios (para vista completa de admin)
        db.collection("usuarios")
            .getDocuments { [weak self] snapshot, error in
                DispatchQueue.main.async {
                    self?.isLoading = false
                    
                    if let error = error {
                        self?.errorMessage = "Error al cargar usuarios: \(error.localizedDescription)"
                        return
                    }
                    
                    guard let documents = snapshot?.documents else {
                        self?.errorMessage = "No se encontraron usuarios"
                        return
                    }
                    
                    print("✅ Total de usuarios en sistema: \(documents.count)")
                }
            }
    }
    
    func changeUserRole(userId: String, newRole: String) async {
        do {
            try await db.collection("usuarios").document(userId).updateData([
                "rol": newRole
            ])
            
            print("✅ Rol actualizado para usuario \(userId) a \(newRole)")
        } catch {
            await MainActor.run {
                errorMessage = "Error al cambiar rol: \(error.localizedDescription)"
            }
            print("❌ Error cambiando rol: \(error.localizedDescription)")
        }
    }
    
    func deleteUser(userId: String) async {
        do {
            try await db.collection("usuarios").document(userId).delete()
            print("✅ Usuario \(userId) eliminado del sistema")
        } catch {
            await MainActor.run {
                errorMessage = "Error al eliminar usuario: \(error.localizedDescription)"
            }
            print("❌ Error eliminando usuario: \(error.localizedDescription)")
        }
    }
    
    func getUserStats() -> (active: Int, inactive: Int, total: Int) {
        let activeUsers = adminUsers.filter { $0.activo }.count
        let inactiveUsers = adminUsers.filter { !$0.activo }.count
        let totalUsers = adminUsers.count
        
        return (active: activeUsers, inactive: inactiveUsers, total: totalUsers)
    }
}

// MARK: - Card de método de pago
struct PaymentMethodCard: View {
    let method: String
    let isSelected: Bool
    let action: () -> Void
    
    private var methodIcon: String {
        switch method {
        case "efectivo": return "banknote"
        case "transferencia": return "creditcard"
        case "tarjeta": return "creditcard.fill"
        case "nequi": return "smartphone"
        case "daviplata": return "smartphone.and.arrow.forward"
        default: return "questionmark.circle"
        }
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: methodIcon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .brandBlack : .brandGold)
                
                Text(method.capitalized)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(isSelected ? .brandBlack : .brandLight)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                isSelected ?
                LinearGradient(
                    colors: [Color.brandGold, Color.brandGold.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ) :
                LinearGradient(
                    colors: [Color.brandDark, Color.brandDark.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        isSelected ? Color.brandGold : Color.brandGold.opacity(0.3),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .animation(.spring(response: 0.3), value: isSelected)
        }
    }
}

// MARK: - Fila de transacción
struct TransactionRow: View {
    let transaction: TransactionData
    
    var body: some View {
        HStack(spacing: 12) {
            // Icono del tipo de transacción
            Image(systemName: transaction.transactionType == "activation" ? "play.circle.fill" : "arrow.clockwise.circle.fill")
                .font(.title3)
                .foregroundColor(transaction.transactionType == "activation" ? .green : .blue)
            
            // Información
            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.userName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.brandLight)
                
                HStack {
                    Text(transaction.membershipType)
                        .font(.caption)
                        .foregroundColor(.brandGold)
                    
                    Text("•")
                        .foregroundColor(.brandLight.opacity(0.5))
                    
                    Text("\(transaction.duration) días")
                        .font(.caption)
                        .foregroundColor(.brandLight.opacity(0.7))
                    
                    Text("•")
                        .foregroundColor(.brandLight.opacity(0.5))
                    
                    Text(transaction.paymentMethod.capitalized)
                        .font(.caption)
                        .foregroundColor(.brandLight.opacity(0.7))
                }
            }
            
            Spacer()
            
            // Monto y fecha
            VStack(alignment: .trailing, spacing: 2) {
                Text("$\(Int(transaction.amount).formatted())")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
                
                Text(DateFormatter.shortDate.string(from: transaction.createdDate))
                    .font(.caption2)
                    .foregroundColor(.brandLight.opacity(0.6))
            }
        }
        .padding(12)
        .background(Color.brandBlack.opacity(0.2))
        .cornerRadius(8)
    }
}

// MARK: - Card de estadística
struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.brandLight)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.brandLight.opacity(0.7))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(Color.brandBlack.opacity(0.3))
        .cornerRadius(12)
    }
}

// MARK: - Mini tarjeta de estadística
struct MiniStatCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.brandLight.opacity(0.7))
        }
        .padding(8)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Nuevo AdminMembershipManager para gestionar membresías
@MainActor
class AdminMembershipManager: ObservableObject {
    @Published var memberships: [MembershipData] = []
    @Published var isLoading = false
    @Published var errorMessage = ""
    
    private let db = Firestore.firestore()
    
    private func getDurationText(days: Int) -> String {
            switch days {
            case 1: return "1 día"
            case 7: return "1 semana"
            case 15: return "15 días"
            case 30: return "1 mes"
            case 60: return "2 meses"
            case 90: return "3 meses"
            case 180: return "6 meses"
            case 365: return "1 año"
            default: return "\(days) días"
            }
        }
    
    func activateMembershipWithCustomPriceAndHistory(
            membershipId: String,
            userEmail: String,
            days: Int,
            customPrice: Double? = nil,
            paymentMethod: String = "efectivo",
            notes: String? = nil,
            adminUserId: String,
            adminUserName: String
        ) async {
            do {
                let startDate = Date()
                let endDate = Calendar.current.date(byAdding: .day, value: days, to: startDate) ?? Date()
                
                // Buscar la membresía para obtener el precio original
                let originalPrice = self.memberships.first(where: { $0.id == membershipId })?.precio ?? 0.0
                let finalPrice = customPrice ?? originalPrice
                
                // 1. Actualizar membresía con precio personalizado
                var updateData: [String: Any] = [
                    "activa": true,
                    "estadoDescripcion": "Activa",
                    "fechaInicio": DateFormatter.membershipFormatter.string(from: startDate),
                    "fechaVencimiento": DateFormatter.membershipFormatter.string(from: endDate),
                    "diasRestantes": days,
                    "requiereActivacion": false,
                    "fechaActivacion": Timestamp(),
                    "duracionDias": days,
                    "precioFinal": finalPrice,
                    "fechaUltimaModificacion": Timestamp(),
                    "adminActivador": adminUserName
                ]
                
                // Agregar campos de precio personalizado si aplica
                if let customPrice = customPrice {
                    updateData["precioPersonalizado"] = customPrice
                    updateData["precioOriginal"] = originalPrice
                    updateData["tieneDescuento"] = customPrice < originalPrice
                }
                
                // Agregar método de pago y notas
                updateData["metodoPago"] = paymentMethod
                if let notes = notes, !notes.isEmpty {
                    updateData["notasActivacion"] = notes
                }
                
                try await db.collection("membresias").document(membershipId).updateData(updateData)
                
                print("✅ Membresía activada:")
                print("- ID: \(membershipId)")
                print("- Email: \(userEmail)")
                print("- Duración: \(days) días")
                print("- Precio original: $\(originalPrice)")
                print("- Precio final: $\(finalPrice)")
                print("- Método de pago: \(paymentMethod)")
                
                // 2. Registrar transacción en historial de ganancias
                let userName = userEmail.components(separatedBy: "@").first ?? "Usuario"
                
                let success = await RevenueManager.shared.recordTransaction(
                    userEmail: userEmail,
                    userName: userName,
                    membershipType: "Básica", // Podrías obtener el tipo real desde la membresía
                    originalPrice: originalPrice,
                    customPrice: customPrice,
                    duration: days,
                    transactionType: "activation",
                    paymentMethod: paymentMethod,
                    membershipStartDate: startDate,
                    membershipEndDate: endDate,
                    adminUserId: adminUserId,
                    adminUserName: adminUserName,
                    notes: notes
                )
                
                if success {
                    print("✅ Transacción registrada en historial de ganancias")
                } else {
                    print("❌ Error registrando transacción en historial")
                }
                
                // 3. Enviar notificación personalizada con precio
                await sendCustomActivationNotificationWithPrice(
                    userEmail: userEmail,
                    days: days,
                    endDate: endDate,
                    finalPrice: finalPrice,
                    paymentMethod: paymentMethod
                )
                
            } catch {
                await MainActor.run {
                    errorMessage = "Error al activar membresía: \(error.localizedDescription)"
                    print("❌ Error activando membresía: \(error.localizedDescription)")
                }
            }
        }
        
        // ✅ FUNCIÓN AUXILIAR: Notificación con información de precio
        private func sendCustomActivationNotificationWithPrice(
            userEmail: String,
            days: Int,
            endDate: Date,
            finalPrice: Double,
            paymentMethod: String
        ) async {
            do {
                let snapshot = try await db.collection("usuarios")
                    .whereField("email", isEqualTo: userEmail)
                    .getDocuments()
                
                guard let userDoc = snapshot.documents.first,
                      let fcmToken = userDoc.data()["fcmToken"] as? String,
                      let userName = userDoc.data()["nombre"] as? String else {
                    print("❌ No se encontró FCM token para el usuario: \(userEmail)")
                    return
                }
                
                let formattedDate = DateFormatter.membershipFormatter.string(from: endDate)
                let durationText = getDurationText(days: days)
                
                let title = "🎉 ¡Membresía Activada!"
                let body = """
                ¡Hola \(userName)! Tu membresía ha sido activada:
                
                📅 Duración: \(durationText) (\(days) días)
                💰 Monto: $\(Int(finalPrice).formatted())
                💳 Pago: \(paymentMethod.capitalized)
                ⏰ Vence: \(formattedDate)
                
                ¡Ya puedes entrenar! 💪
                """
                
                await FCMNotificationManager.shared.sendNotificationToUser(
                    userId: userDoc.documentID,
                    title: title,
                    body: body,
                    data: [
                        "type": "membership_activated",
                        "duration_days": "\(days)",
                        "end_date": formattedDate,
                        "final_price": "\(finalPrice)",
                        "payment_method": paymentMethod,
                        "timestamp": "\(Date().timeIntervalSince1970)"
                    ],
                    directToken: fcmToken
                )
                
                print("📱 Notificación de activación con precio enviada")
                
            } catch {
                print("❌ Error enviando notificación: \(error.localizedDescription)")
            }
        }
    
    private func sendCustomActivationNotification(
            userEmail: String,
            days: Int,
            endDate: Date
        ) async {
            // Buscar FCM token del usuario
            do {
                let snapshot = try await db.collection("usuarios")
                    .whereField("email", isEqualTo: userEmail)
                    .getDocuments()
                
                guard let userDoc = snapshot.documents.first,
                      let fcmToken = userDoc.data()["fcmToken"] as? String,
                      let userName = userDoc.data()["nombre"] as? String else {
                    print("❌ No se encontró FCM token para el usuario: \(userEmail)")
                    return
                }
                
                let formattedDate = DateFormatter.membershipFormatter.string(from: endDate)
                let durationText = getDurationText(days: days)
                
                let title = "🎉 ¡Membresía Activada!"
                let body = "¡Hola \(userName)! Tu membresía ha sido activada por \(durationText). Vence el \(formattedDate). ¡Ya puedes entrenar!"
                
                await FCMNotificationManager.shared.sendNotificationToUser(
                    userId: userDoc.documentID,
                    title: title,
                    body: body,
                    data: [
                        "type": "membership_activated",
                        "duration_days": "\(days)",
                        "end_date": formattedDate,
                        "timestamp": "\(Date().timeIntervalSince1970)"
                    ],
                    directToken: fcmToken
                )
                
                print("📱 Notificación de activación personalizada enviada")
                
            } catch {
                print("❌ Error enviando notificación: \(error.localizedDescription)")
            }
        }
        
    
    func activateMembershipWithCustomDays(
           membershipId: String,
           userEmail: String,
           days: Int
       ) async {
           do {
               let startDate = Date()
               let endDate = Calendar.current.date(byAdding: .day, value: days, to: startDate) ?? Date()
               
               // ✅ Actualizar membresía con días personalizados
               try await db.collection("membresias").document(membershipId).updateData([
                   "activa": true,
                   "estadoDescripcion": "Activa",
                   "fechaInicio": DateFormatter.membershipFormatter.string(from: startDate),
                   "fechaVencimiento": DateFormatter.membershipFormatter.string(from: endDate),
                   "diasRestantes": days,
                   "requiereActivacion": false,
                   "fechaActivacion": Timestamp(),
                   "duracionDias": days // ✅ Nuevo campo para guardar la duración original
               ])
               
               print("✅ Membresía activada por \(days) días para: \(userEmail)")
               print("📅 Fecha inicio: \(DateFormatter.membershipFormatter.string(from: startDate))")
               print("📅 Fecha vencimiento: \(DateFormatter.membershipFormatter.string(from: endDate))")
               
               // Enviar notificación personalizada
               await sendCustomActivationNotification(
                   userEmail: userEmail,
                   days: days,
                   endDate: endDate
               )
               
           } catch {
               await MainActor.run {
                   errorMessage = "Error al activar membresía: \(error.localizedDescription)"
                   print("❌ Error activando membresía: \(error.localizedDescription)")
               }
           }
       }
    
    func loadAllMemberships() {
        isLoading = true
        errorMessage = ""
        
        db.collection("membresias")
            .addSnapshotListener { [weak self] snapshot, error in
                DispatchQueue.main.async {
                    self?.isLoading = false
                    
                    if let error = error {
                        self?.errorMessage = "Error al cargar membresías: \(error.localizedDescription)"
                        print("❌ Error cargando membresías: \(error.localizedDescription)")
                        return
                    }
                    
                    guard let documents = snapshot?.documents else {
                        self?.errorMessage = "No se encontraron membresías"
                        return
                    }
                    
                    self?.memberships = documents.compactMap { doc in
                        return MembershipData(from: doc)
                    }
                    
                    print("✅ Cargadas \(self?.memberships.count ?? 0) membresías")
                }
            }
    }
    
    func toggleMembershipStatus(membershipId: String, userEmail: String, currentStatus: Bool) async {
        do {
            let newStatus = !currentStatus
            
            if newStatus {
                // Activar membresía - establecer fechas
                let startDate = Date()
                let endDate = Calendar.current.date(byAdding: .month, value: 1, to: startDate) ?? Date()
                let daysRemaining = Calendar.current.dateComponents([.day], from: Date(), to: endDate).day ?? 0
                
                try await db.collection("membresias").document(membershipId).updateData([
                    "activa": true,
                    "estadoDescripcion": "Activa",
                    "fechaInicio": DateFormatter.membershipFormatter.string(from: startDate),
                    "fechaVencimiento": DateFormatter.membershipFormatter.string(from: endDate),
                    "diasRestantes": daysRemaining,
                    "requiereActivacion": false,
                    "fechaActivacion": Timestamp()
                ])
                
                print("✅ Membresía activada para: \(userEmail)")
                
                // Enviar notificación de activación
                await sendMembershipNotification(
                    userEmail: userEmail,
                    isActivation: true,
                    membershipType: "Básica"
                )
                
            } else {
                // Desactivar membresía
                try await db.collection("membresias").document(membershipId).updateData([
                    "activa": false,
                    "estadoDescripcion": "Suspendida",
                    "fechaDesactivacion": Timestamp()
                ])
                
                print("✅ Membresía desactivada para: \(userEmail)")
                
                // Enviar notificación de suspensión
                await sendMembershipNotification(
                    userEmail: userEmail,
                    isActivation: false,
                    membershipType: "Básica"
                )
            }
            
        } catch {
            await MainActor.run {
                errorMessage = "Error al cambiar estado de membresía: \(error.localizedDescription)"
                print("❌ Error cambiando estado de membresía: \(error.localizedDescription)")
            }
        }
    }
    
    private func sendMembershipNotification(userEmail: String, isActivation: Bool, membershipType: String) async {
        // Buscar FCM token del usuario
        do {
            let snapshot = try await db.collection("usuarios")
                .whereField("email", isEqualTo: userEmail)
                .getDocuments()
            
            guard let userDoc = snapshot.documents.first,
                  let fcmToken = userDoc.data()["fcmToken"] as? String,
                  let userName = userDoc.data()["nombre"] as? String else {
                print("❌ No se encontró FCM token para el usuario: \(userEmail)")
                return
            }
            
            let title = isActivation ?
                "🎉 ¡Membresía Activada!" :
                "⚠️ Membresía Suspendida"
            
            let body = isActivation ?
                "¡Hola \(userName)! Tu membresía \(membershipType) ha sido activada. ¡Ya puedes entrenar!" :
                "Hola \(userName), tu membresía \(membershipType) ha sido suspendida. Contacta al gimnasio para más información."
            
            await FCMNotificationManager.shared.sendNotificationToUser(
                userId: userDoc.documentID,
                title: title,
                body: body,
                data: [
                    "type": "membership_status",
                    "action": isActivation ? "activated" : "suspended",
                    "membershipType": membershipType,
                    "timestamp": "\(Date().timeIntervalSince1970)"
                ],
                directToken: fcmToken
            )
            
        } catch {
            print("❌ Error enviando notificación de membresía: \(error.localizedDescription)")
        }
    }
}

@MainActor
class MembershipDayTracker: ObservableObject {
    static let shared = MembershipDayTracker()
    
    @Published var needsUpdate: [String] = []
    private let db = Firestore.firestore()
    private var updateTimer: Timer?
    
    private init() {
        startDailyUpdates()
    }
    
    func startDailyUpdates() {
        // Actualizar cada 6 horas
        updateTimer = Timer.scheduledTimer(withTimeInterval: 21600, repeats: true) { _ in
            Task {
                await self.updateAllMembershipDays()
            }
        }
        
        // Actualizar al iniciar
        Task {
            await updateAllMembershipDays()
        }
    }
    
    func updateAllMembershipDays() async {
        print("🔄 Actualizando días restantes de todas las membresías...")
        
        do {
            let snapshot = try await db.collection("membresias")
                .whereField("activa", isEqualTo: true)
                .getDocuments()
            
            for document in snapshot.documents {
                let data = document.data()
                
                guard let fechaVencimientoString = data["fechaVencimiento"] as? String,
                      let fechaVencimiento = DateFormatter.membershipFormatter.date(from: fechaVencimientoString) else {
                    continue
                }
                
                let today = Date()
                let daysRemaining = Calendar.current.dateComponents([.day], from: today, to: fechaVencimiento).day ?? 0
                
                // Actualizar solo si cambió
                let currentDays = data["diasRestantes"] as? Int
                if currentDays != daysRemaining {
                    
                    var updateData: [String: Any] = ["diasRestantes": daysRemaining]
                    
                    // Si la membresía expiró, desactivarla
                    if daysRemaining <= 0 {
                        updateData["activa"] = false
                        updateData["estadoDescripcion"] = "Expirada"
                        
                        print("⏰ Membresía expirada: \(data["email"] as? String ?? "unknown")")
                        
                        // Enviar notificación de expiración
                        if let email = data["email"] as? String,
                           let userUID = data["userUID"] as? String {
                            await sendExpirationNotification(userUID: userUID, email: email)
                        }
                    }
                    
                    try await document.reference.updateData(updateData)
                    print("📅 Actualizado \(data["email"] as? String ?? "unknown"): \(daysRemaining) días")
                }
            }
            
        } catch {
            print("❌ Error actualizando días restantes: \(error.localizedDescription)")
        }
    }
    
    private func sendExpirationNotification(userUID: String, email: String) async {
        // Buscar datos del usuario
        do {
            let userDoc = try await db.collection("usuarios").document(userUID).getDocument()
            
            guard let userData = userDoc.data(),
                  let fcmToken = userData["fcmToken"] as? String,
                  let userName = userData["nombre"] as? String else {
                print("❌ No se encontró FCM token para usuario expirado: \(email)")
                return
            }
            
            let title = "⏰ Membresía Expirada"
            let body = "Hola \(userName), tu membresía ha expirado. Renueva para seguir entrenando en Gym Body Gold."
            
            await FCMNotificationManager.shared.sendNotificationToUser(
                userId: userUID,
                title: title,
                body: body,
                data: [
                    "type": "membership_expired",
                    "action": "renew_required",
                    "timestamp": "\(Date().timeIntervalSince1970)"
                ],
                directToken: fcmToken
            )
            
        } catch {
            print("❌ Error enviando notificación de expiración: \(error.localizedDescription)")
        }
    }
    
    deinit {
        updateTimer?.invalidate()
    }
}

// MARK: - Modelo de datos para membresías en admin panel

// MARK: - MembershipData ACTUALIZADO con soporte para días personalizados
struct MembershipData: Identifiable, Codable {
    let id: String
    let userUID: String
    let email: String
    let tipoMembresia: String
    let precio: Double
    let activa: Bool
    let estadoDescripcion: String
    let fechaInicio: String
    let fechaVencimiento: String
    let diasRestantes: Int?
    let requiereActivacion: Bool
    let fechaCreacion: Date
    let duracionDias: Int?
    let fechaActivacion: Date?
    
    // ✅ NUEVOS CAMPOS PARA PRECIOS PERSONALIZADOS
    let precioPersonalizado: Double?
    let precioOriginal: Double?
    let metodoPago: String?
    let tieneDescuento: Bool?
    let precioFinal: Double?
    let notasActivacion: String?
    let adminActivador: String?
    let fechaUltimaModificacion: Date?
    
    init(from document: QueryDocumentSnapshot) {
        let data = document.data()
        
        // Campos originales
        self.id = document.documentID
        self.userUID = data["userUID"] as? String ?? ""
        self.email = data["email"] as? String ?? ""
        self.tipoMembresia = data["tipoMembresia"] as? String ?? "Básica"
        self.precio = data["precio"] as? Double ?? 0.0
        self.activa = data["activa"] as? Bool ?? false
        self.estadoDescripcion = data["estadoDescripcion"] as? String ?? "Pendiente"
        self.fechaInicio = data["fechaInicio"] as? String ?? ""
        self.fechaVencimiento = data["fechaVencimiento"] as? String ?? ""
        self.diasRestantes = data["diasRestantes"] as? Int
        self.requiereActivacion = data["requiereActivacion"] as? Bool ?? true
        self.fechaCreacion = (data["fechaCreacion"] as? Timestamp)?.dateValue() ?? Date()
        self.duracionDias = data["duracionDias"] as? Int
        self.fechaActivacion = (data["fechaActivacion"] as? Timestamp)?.dateValue()
        
        // ✅ NUEVOS CAMPOS
        self.precioPersonalizado = data["precioPersonalizado"] as? Double
        self.precioOriginal = data["precioOriginal"] as? Double
        self.metodoPago = data["metodoPago"] as? String
        self.tieneDescuento = data["tieneDescuento"] as? Bool
        self.precioFinal = data["precioFinal"] as? Double
        self.notasActivacion = data["notasActivacion"] as? String
        self.adminActivador = data["adminActivador"] as? String
        self.fechaUltimaModificacion = (data["fechaUltimaModificacion"] as? Timestamp)?.dateValue()
    }
}

extension MembershipData {
    var durationText: String {
        guard let duracion = duracionDias else { return "N/A" }
        
        switch duracion {
        case 1: return "1 día"
        case 7: return "1 semana"
        case 15: return "15 días"
        case 30: return "1 mes"
        case 60: return "2 meses"
        case 90: return "3 meses"
        case 180: return "6 meses"
        case 365: return "1 año"
        default: return "\(duracion) días"
        }
    }
    
    var isExpiringSoon: Bool {
        guard let dias = diasRestantes else { return false }
        return dias <= 7 && dias > 0
    }
    
    var isExpiredToday: Bool {
        guard let dias = diasRestantes else { return false }
        return dias <= 0
    }
    
    var hasCustomPrice: Bool {
        return precioPersonalizado != nil
    }
    
    var discountAmount: Double {
        guard let personalizado = precioPersonalizado else { return 0 }
        return precio - personalizado
    }
    
    var finalDisplayPrice: Double {
        return precioFinal ?? precioPersonalizado ?? precio
    }
}

// MARK: - DateFormatter para membresías
extension DateFormatter {
    static let membershipFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

// MARK: - AdminMembershipsListCard (Nueva tarjeta para el panel admin)
struct AdminMembershipsListCard: View {
    @StateObject private var membershipManager = AdminMembershipManager()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("💳 Membresías")
                    .font(.headline)
                    .foregroundColor(.brandLight)
                
                Spacer()
                
                // Badge con cantidad pendientes
                let pendingCount = membershipManager.memberships.filter { $0.requiereActivacion }.count
                if pendingCount > 0 {
                    Text("\(pendingCount)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.brandBlack)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange)
                        .cornerRadius(12)
                }
            }
            
            if membershipManager.memberships.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "creditcard.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.brandGold.opacity(0.5))
                    
                    Text("No hay membresías registradas")
                        .font(.subheadline)
                        .foregroundColor(.brandLight.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(membershipManager.memberships) { membership in
                        // ✅ USAR LA NUEVA VERSIÓN CON DÍAS PERSONALIZADOS
                        AdminMembershipRowWithCustomDays(membership: membership, manager: membershipManager)
                    }
                }
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
            membershipManager.loadAllMemberships()
        }
    }
}

// MARK: - AdminMembershipRowWithCustomDays - Nueva versión completa
struct AdminMembershipRowWithCustomDays: View {
    let membership: MembershipData
    @ObservedObject var manager: AdminMembershipManager
    @State private var isToggling = false
    @State private var showingActivationSheet = false
    
    // MARK: - Computed UI Helpers
    private var statusColor: Color {
        membership.activa ? .green : .orange
    }
    
    private var statusIcon: String {
        membership.activa ? "checkmark.circle.fill" : "clock.circle.fill"
    }
    
    private var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.brandBlack.opacity(0.5),
                Color.brandBlack.opacity(0.25)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Avatar
            membershipAvatar
            
            // Información
            membershipInfo
            
            Spacer(minLength: 12)
            
            // Controles
            controlPanel
        }
        .padding(16)
        .background(backgroundGradient)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(statusColor.opacity(0.3), lineWidth: 1)
        )
        .cornerRadius(16)
        .shadow(
            color: statusColor.opacity(0.15),
            radius: 8, x: 0, y: 4
        )
        .scaleEffect(isToggling ? 0.97 : 1)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isToggling)
        .sheet(isPresented: $showingActivationSheet) {
            MembershipActivationSheet(membership: membership, manager: manager)
        }
    }
    
    // MARK: - Avatar
    private var membershipAvatar: some View {
        ZStack {
            Image(systemName: membership.activa ? "creditcard.fill" : "creditcard.trianglebadge.exclamationmark")
                .font(.title3)
                .foregroundColor(membership.activa ? .green : .orange)
        }
    }
    
    // MARK: - Información
    private var membershipInfo: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(membership.email)
                .font(.system(.subheadline, design: .rounded))
                .fontWeight(.semibold)
                .foregroundColor(.brandLight)
                .lineLimit(1)
            
            Text(membership.tipoMembresia)
                .font(.system(.caption, design: .rounded))
                .fontWeight(.medium)
                .foregroundColor(.brandGold)
            
            statusPill
            daysInfo
        }
    }
    
    private var statusPill: some View {
        HStack(spacing: 4) {
            Image(systemName: statusIcon)
                .font(.system(size: 10, weight: .bold))
            Text(membership.estadoDescripcion)
        }
        .font(.system(.caption2, design: .rounded))
        .fontWeight(.semibold)
        .foregroundColor(membership.activa ? .white : .brandBlack)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            Capsule().fill(membership.activa ? statusColor : statusColor.opacity(0.3))
        )
    }
    
    private var daysInfo: some View {
        HStack(spacing: 8) {
            if membership.activa, let dias = membership.diasRestantes {
                infoLabel(icon: "clock", text: "\(dias) días restantes", color: .brandLight.opacity(0.8))
            }
            if let duracion = membership.duracionDias {
                infoLabel(icon: "calendar", text: "\(duracion)d total", color: .brandGold.opacity(0.7))
            }
        }
    }
    
    private func infoLabel(icon: String, text: String, color: Color) -> some View {
        Label {
            Text(text)
                .font(.system(.caption2, design: .monospaced))
                .fontWeight(.medium)
        } icon: {
            Image(systemName: icon).font(.caption2)
        }
        .foregroundColor(color)
    }
    
    // MARK: - Controles
    private var controlPanel: some View {
        VStack(spacing: 12) {
            priceDisplay
            actionButton
        }
    }
    
    private var priceDisplay: some View {
        VStack(spacing: 2) {
            Text("PRECIO")
                .font(.system(.caption2, design: .rounded))
                .foregroundColor(.brandGold.opacity(0.6))
            Text("$\(Int(membership.precio).formatted())")
                .font(.system(.headline, design: .rounded))
                .fontWeight(.bold)
                .foregroundColor(.brandGold)
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.brandGold.opacity(0.1)))
    }
    
    private var actionButton: some View {
        Group {
            if membership.activa {
                suspendButton
            } else {
                activateButton
            }
        }
    }
    
    private var suspendButton: some View {
        actionStyledButton(
            text: "Suspender",
            icon: "pause.circle.fill",
            bgColors: [.red, .red.opacity(0.85)],
            loading: isToggling
        ) {
            Task { await suspendMembership() }
        }
    }
    
    private var activateButton: some View {
        actionStyledButton(
            text: "Activar",
            icon: "calendar.badge.plus",
            bgColors: [.green, .green.opacity(0.85)],
            loading: false
        ) {
            showingActivationSheet = true
        }
    }
    
    private func actionStyledButton(
        text: String,
        icon: String,
        bgColors: [Color],
        loading: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if loading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: icon)
                        .font(.system(.caption, weight: .semibold))
                    Text(text)
                        .font(.system(.caption, design: .rounded))
                        .fontWeight(.semibold)
                }
            }
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                LinearGradient(colors: bgColors, startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .cornerRadius(8)
            .shadow(color: bgColors.first!.opacity(0.3), radius: 4, x: 0, y: 2)
        }
        .disabled(loading)
        .scaleEffect(loading ? 0.95 : 1.0)
    }
    
    // MARK: - Actions
    private func suspendMembership() async {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { isToggling = true }
        await manager.toggleMembershipStatus(
            membershipId: membership.id,
            userEmail: membership.email,
            currentStatus: membership.activa
        )
        try? await Task.sleep(nanoseconds: 500_000_000)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { isToggling = false }
    }
}

// MARK: - Fila individual de membresía para admin
struct AdminMembershipRow: View {
    let membership: MembershipData
    @ObservedObject var manager: AdminMembershipManager
    @State private var isToggling = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Icono de membresía
            ZStack {
                Circle()
                    .fill(membership.activa ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Image(systemName: membership.activa ? "creditcard.fill" : "creditcard.trianglebadge.exclamationmark")
                    .font(.title3)
                    .foregroundColor(membership.activa ? .green : .orange)
            }
            
            // Info de la membresía
            VStack(alignment: .leading, spacing: 4) {
                Text(membership.email)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.brandLight)
                
                Text(membership.tipoMembresia)
                    .font(.caption)
                    .foregroundColor(.brandGold)
                
                HStack(spacing: 8) {
                    Text(membership.estadoDescripcion)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            membership.activa ? Color.green.opacity(0.2) : Color.orange.opacity(0.2)
                        )
                        .foregroundColor(membership.activa ? .green : .orange)
                        .cornerRadius(6)
                    
                    if membership.activa, let dias = membership.diasRestantes {
                        Text("\(dias) días")
                            .font(.caption2)
                            .foregroundColor(.brandLight.opacity(0.7))
                    }
                }
            }
            
            Spacer()
            
            // Controles
            VStack(spacing: 8) {
                // Precio
                Text("$\(Int(membership.precio).formatted())")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.brandGold)
                
                // Botón de activar/desactivar
                Button(action: {
                    Task {
                        await toggleMembershipStatus()
                    }
                }) {
                    HStack(spacing: 4) {
                        if isToggling {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .brandWhite))
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: membership.activa ? "pause.circle.fill" : "play.circle.fill")
                                .font(.caption)
                            
                            Text(membership.activa ? "Suspender" : "Activar")
                                .font(.caption2)
                                .fontWeight(.semibold)
                        }
                    }
                    .foregroundColor(.brandWhite)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(membership.activa ? Color.red.opacity(0.8) : Color.green.opacity(0.8))
                    .cornerRadius(6)
                }
                .disabled(isToggling)
                .scaleEffect(isToggling ? 0.95 : 1.0)
                .animation(.spring(response: 0.3), value: isToggling)
            }
        }
        .padding(12)
        .background(Color.brandBlack.opacity(0.3))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(membership.activa ? Color.green.opacity(0.3) : Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
    
    private func toggleMembershipStatus() async {
        isToggling = true
        
        await manager.toggleMembershipStatus(
            membershipId: membership.id,
            userEmail: membership.email,
            currentStatus: membership.activa
        )
        
        // Pequeño delay para mejor UX
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        isToggling = false
    }
}

struct RevenueDashboard: View {
    @StateObject private var revenueManager = RevenueManager.shared
    @State private var selectedPeriod: String = "month"
    
    private let periods = ["day": "Hoy", "week": "Semana", "month": "Mes", "year": "Año"]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("💰 Ganancias")
                    .font(.headline)
                    .foregroundColor(.brandLight)
                
                Spacer()
                
                // Selector de período
                Picker("Período", selection: $selectedPeriod) {
                    ForEach(periods.keys.sorted(), id: \.self) { key in
                        Text(periods[key] ?? key).tag(key)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(width: 200)
            }
            
            // Estadísticas principales
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                StatCard(
                    title: "Total General",
                    value: "$\(Int(revenueManager.totalRevenue).formatted())",
                    icon: "dollarsign.circle.fill",
                    color: .green
                )
                
                StatCard(
                    title: "Este Mes",
                    value: "$\(Int(revenueManager.monthlyRevenue).formatted())",
                    icon: "calendar.circle.fill",
                    color: .brandGold
                )
            }
            
            // Lista de transacciones recientes
            if !revenueManager.transactions.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Transacciones Recientes")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.brandGold)
                    
                    LazyVStack(spacing: 8) {
                        ForEach(Array(revenueManager.transactions.prefix(5))) { transaction in
                            TransactionRow(transaction: transaction)
                        }
                    }
                }
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
            Task {
                await revenueManager.loadTransactions()
            }
        }
    }
}

struct EnhancedMembershipActivationSheet: View {
    let membership: MembershipData
    let manager: AdminMembershipManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedDays: Int = 30
    @State private var customDays: String = "30"
    @State private var customPrice: String = ""
    @State private var useCustomPrice: Bool = false
    @State private var selectedPaymentMethod: String = "efectivo"
    @State private var notes: String = ""
    @State private var isActivating = false
    @State private var showingConfirmation = false
    
    @StateObject private var revenueManager = RevenueManager.shared
    
    // Opciones predefinidas de días
    private let dayOptions = [7, 15, 30, 60, 90, 180, 365]
    
    // Métodos de pago
    private let paymentMethods = ["efectivo", "transferencia", "tarjeta", "nequi", "daviplata"]
    
    var calculatedEndDate: Date {
        Calendar.current.date(byAdding: .day, value: selectedDays, to: Date()) ?? Date()
    }
    
    var finalPrice: Double {
        if useCustomPrice, let price = Double(customPrice), price > 0 {
            return price
        }
        return membership.precio
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.brandBlack.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 12) {
                            Image(systemName: "calendar.badge.plus")
                                .font(.system(size: 50))
                                .foregroundColor(.brandGold)
                            
                            Text("Activar Membresía")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.brandGold)
                            
                            Text("Configura duración, precio y método de pago")
                                .font(.subheadline)
                                .foregroundColor(.brandLight.opacity(0.7))
                                .multilineTextAlignment(.center)
                        }
                        
                        // Información de la membresía
                        membershipInfoSection
                        
                        // Selección de duración
                        durationSelectionSection
                        
                        // Configuración de precio
                        pricingSection
                        
                        // Método de pago
                        paymentMethodSection
                        
                        // Notas adicionales
                        notesSection
                        
                        // Previsualización
                        previewSection
                        
                        // Botón de activación
                        activationButton
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("Activar Membresía")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancelar") {
                        dismiss()
                    }
                    .foregroundColor(.brandLight)
                    .disabled(isActivating)
                }
            }
            .alert("Confirmar Activación", isPresented: $showingConfirmation) {
                Button("Activar", role: .cancel) {
                    Task {
                        await activateMembership()
                    }
                }
                Button("Cancelar", role: .destructive) { }
            } message: {
                Text("¿Activar membresía por \(selectedDays) días por $\(Int(finalPrice).formatted())?\n\nMétodo: \(selectedPaymentMethod.capitalized)")
            }
            .onAppear {
                customPrice = "\(Int(membership.precio))"
            }
            .preferredColorScheme(.dark)
        }
    }
    
    // MARK: - Sección de información de membresía
    private var membershipInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Información de la Membresía")
                .font(.headline)
                .foregroundColor(.brandGold)
            
            VStack(spacing: 8) {
                HStack {
                    Text("Usuario:")
                        .foregroundColor(.brandLight.opacity(0.7))
                    Spacer()
                    Text(membership.email)
                        .fontWeight(.semibold)
                        .foregroundColor(.brandLight)
                }
                
                HStack {
                    Text("Tipo:")
                        .foregroundColor(.brandLight.opacity(0.7))
                    Spacer()
                    Text(membership.tipoMembresia)
                        .fontWeight(.semibold)
                        .foregroundColor(.brandGold)
                }
                
                HStack {
                    Text("Precio Base:")
                        .foregroundColor(.brandLight.opacity(0.7))
                    Spacer()
                    Text("$\(Int(membership.precio).formatted())")
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
            }
            .padding(16)
            .background(Color.brandDark.opacity(0.5))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Sección de selección de duración
    private var durationSelectionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Duración de la Membresía")
                .font(.headline)
                .foregroundColor(.brandGold)
            
            Text("Opciones rápidas:")
                .font(.subheadline)
                .foregroundColor(.brandLight.opacity(0.8))
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                ForEach(dayOptions, id: \.self) { days in
                    DayOptionCard(
                        days: days,
                        isSelected: selectedDays == days,
                        action: {
                            selectedDays = days
                            customDays = "\(days)"
                        }
                    )
                }
            }
            
            // Campo personalizado
            VStack(alignment: .leading, spacing: 8) {
                Text("O ingresa días personalizados:")
                    .font(.subheadline)
                    .foregroundColor(.brandLight.opacity(0.8))
                
                TextField("Número de días", text: $customDays)
                    .keyboardType(.numberPad)
                    .padding(12)
                    .background(Color.brandDark)
                    .foregroundColor(.brandWhite)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.brandGold.opacity(0.3), lineWidth: 1)
                    )
                    .onChange(of: customDays) { newValue in
                        if let days = Int(newValue), days > 0 {
                            selectedDays = days
                        }
                    }
            }
        }
    }
    
    // MARK: - Sección de configuración de precio
    private var pricingSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Configuración de Precio")
                .font(.headline)
                .foregroundColor(.brandGold)
            
            // Toggle para precio personalizado
            Toggle("Usar precio personalizado", isOn: $useCustomPrice)
                .toggleStyle(SwitchToggleStyle(tint: .brandGold))
                .foregroundColor(.brandLight)
            
            if useCustomPrice {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Precio personalizado:")
                        .font(.subheadline)
                        .foregroundColor(.brandLight.opacity(0.8))
                    
                    HStack {
                        Text("$")
                            .font(.title2)
                            .foregroundColor(.brandGold)
                        
                        TextField("0", text: $customPrice)
                            .keyboardType(.numberPad)
                            .font(.title2)
                            .fontWeight(.semibold)
                    }
                    .padding(12)
                    .background(Color.brandDark)
                    .foregroundColor(.brandWhite)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.brandGold.opacity(0.3), lineWidth: 1)
                    )
                }
            }
            
            // Mostrar cálculos
            VStack(spacing: 8) {
                HStack {
                    Text("Precio total:")
                        .foregroundColor(.brandLight.opacity(0.7))
                    Spacer()
                    Text("$\(Int(finalPrice).formatted())")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.brandGold)
                }
                
                if useCustomPrice {
                    let discount = membership.precio - finalPrice
                    if discount > 0 {
                        HStack {
                            Text("Descuento:")
                                .foregroundColor(.green.opacity(0.8))
                            Spacer()
                            Text("-$\(Int(discount).formatted())")
                                .fontWeight(.semibold)
                                .foregroundColor(.green)
                        }
                    } else if discount < 0 {
                        HStack {
                            Text("Recargo:")
                                .foregroundColor(.orange.opacity(0.8))
                            Spacer()
                            Text("+$\(Int(abs(discount)).formatted())")
                                .fontWeight(.semibold)
                                .foregroundColor(.orange)
                        }
                    }
                }
            }
            .padding(12)
            .background(Color.brandDark.opacity(0.3))
            .cornerRadius(8)
        }
    }
    
    // MARK: - Sección de método de pago
    private var paymentMethodSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Método de Pago")
                .font(.headline)
                .foregroundColor(.brandGold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                ForEach(paymentMethods, id: \.self) { method in
                    PaymentMethodCard(
                        method: method,
                        isSelected: selectedPaymentMethod == method,
                        action: {
                            selectedPaymentMethod = method
                        }
                    )
                }
            }
        }
    }
    
    // MARK: - Sección de notas
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notas adicionales (opcional)")
                .font(.subheadline)
                .foregroundColor(.brandLight.opacity(0.8))
            
            TextField("Agregar comentarios sobre esta activación...", text: $notes, axis: .vertical)
                .lineLimit(2...4)
                .padding(12)
                .background(Color.brandDark)
                .foregroundColor(.brandWhite)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.brandGold.opacity(0.3), lineWidth: 1)
                )
        }
    }
    
    // MARK: - Sección de previsualización
    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Resumen de Activación")
                .font(.headline)
                .foregroundColor(.brandGold)
            
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Fecha de Inicio")
                            .font(.caption)
                            .foregroundColor(.brandLight.opacity(0.7))
                        Text(DateFormatter.membershipFormatter.string(from: Date()))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.brandLight)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Fecha de Vencimiento")
                            .font(.caption)
                            .foregroundColor(.brandLight.opacity(0.7))
                        Text(DateFormatter.membershipFormatter.string(from: calculatedEndDate))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.brandLight)
                    }
                }
                
                Divider().background(Color.brandGold.opacity(0.3))
                
                VStack(spacing: 8) {
                    HStack {
                        Text("Duración:")
                        Spacer()
                        Text("\(selectedDays) días")
                            .fontWeight(.semibold)
                    }
                    
                    HStack {
                        Text("Método de pago:")
                        Spacer()
                        Text(selectedPaymentMethod.capitalized)
                            .fontWeight(.semibold)
                    }
                    
                    HStack {
                        Text("Total a cobrar:")
                        Spacer()
                        Text("$\(Int(finalPrice).formatted())")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.brandGold)
                    }
                }
                .font(.subheadline)
                .foregroundColor(.brandLight)
            }
            .padding(16)
            .background(Color.brandDark.opacity(0.3))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.brandGold.opacity(0.2), lineWidth: 1)
            )
        }
    }
    
    // MARK: - Botón de activación
    private var activationButton: some View {
        Button(action: {
            showingConfirmation = true
        }) {
            HStack {
                if isActivating {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .brandBlack))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                }
                
                Text(isActivating ? "Procesando..." : "Activar Membresía")
                    .fontWeight(.semibold)
            }
            .foregroundColor(.brandBlack)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    colors: [Color.brandGold, Color.brandGold.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(12)
            .disabled(isActivating || selectedDays <= 0 || (useCustomPrice && Double(customPrice) == nil))
        }
        .scaleEffect(isActivating ? 0.98 : 1.0)
        .animation(.spring(response: 0.3), value: isActivating)
    }
    
    // MARK: - Función de activación con registro de ingresos
    private func activateMembership() async {
        isActivating = true
        
        // ✅ OBTENER DATOS DEL ADMIN ACTUAL - IMPORTANTE: Aquí debes usar datos reales
        let adminUserId = Auth.auth().currentUser?.uid ?? "unknown_admin"
        let adminUserName = "Admin Usuario" // Aquí podrías obtener el nombre real del admin logueado
        
        // Usar la nueva función con precios personalizados
        await manager.activateMembershipWithCustomPriceAndHistory(
            membershipId: membership.id,
            userEmail: membership.email,
            days: selectedDays,
            customPrice: useCustomPrice ? Double(customPrice) : nil,
            paymentMethod: selectedPaymentMethod,
            notes: notes.isEmpty ? nil : notes,
            adminUserId: adminUserId,
            adminUserName: adminUserName
        )
        
        // Delay para mejor UX
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        isActivating = false
        dismiss()
    }
}

struct EnhancedMembershipRow: View {
    let membership: MembershipData
    @ObservedObject var manager: AdminMembershipManager
    @State private var isToggling = false
    @State private var showingActivationSheet = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Avatar con indicador de estado
            ZStack {
                Circle()
                    .fill(membership.activa ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Image(systemName: membership.activa ? "creditcard.fill" : "creditcard.trianglebadge.exclamationmark")
                    .font(.title3)
                    .foregroundColor(membership.activa ? .green : .orange)
                
                // Indicador de precio personalizado
                if membership.hasCustomPrice {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Circle()
                                .fill(Color.brandGold)
                                .frame(width: 12, height: 12)
                                .overlay(
                                    Text("$")
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.brandBlack)
                                )
                        }
                    }
                    .frame(width: 50, height: 50)
                }
            }
            
            // Información
            VStack(alignment: .leading, spacing: 6) {
                Text(membership.email)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.brandLight)
                    .lineLimit(1)
                
                Text(membership.tipoMembresia)
                    .font(.caption)
                    .foregroundColor(.brandGold)
                
                // Estado con información adicional
                HStack(spacing: 8) {
                    Text(membership.estadoDescripcion)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            membership.activa ? Color.green.opacity(0.2) : Color.orange.opacity(0.2)
                        )
                        .foregroundColor(membership.activa ? .green : .orange)
                        .cornerRadius(6)
                    
                    if membership.activa, let dias = membership.diasRestantes {
                        Text("\(dias)d")
                            .font(.caption2)
                            .foregroundColor(.brandLight.opacity(0.7))
                    }
                    
                    if let metodoPago = membership.metodoPago {
                        Text(metodoPago.capitalized)
                            .font(.caption2)
                            .foregroundColor(.brandLight.opacity(0.6))
                    }
                }
            }
            
            Spacer()
            
            // Controles
            VStack(spacing: 8) {
                // Precio (con indicador de personalización)
                VStack(spacing: 2) {
                    if let precioPersonalizado = membership.precioPersonalizado {
                        Text("$\(Int(precioPersonalizado).formatted())")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.brandGold)
                        
                        Text("(Era $\(Int(membership.precio).formatted()))")
                            .font(.caption2)
                            .foregroundColor(.brandLight.opacity(0.6))
                            .strikethrough()
                    } else {
                        Text("$\(Int(membership.finalDisplayPrice).formatted())")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.brandGold)
                    }
                }
                
                // Botón de acción
                if membership.activa {
                    Button(action: {
                        Task {
                            await suspendMembership()
                        }
                    }) {
                        HStack(spacing: 4) {
                            if isToggling {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .brandWhite))
                                    .scaleEffect(0.7)
                            } else {
                                Image(systemName: "pause.circle.fill")
                                    .font(.caption)
                                Text("Suspender")
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                            }
                        }
                        .foregroundColor(.brandWhite)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red.opacity(0.8))
                        .cornerRadius(6)
                    }
                    .disabled(isToggling)
                } else {
                    Button(action: {
                        showingActivationSheet = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "play.circle.fill")
                                .font(.caption)
                            Text("Activar")
                                .font(.caption2)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.brandWhite)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.8))
                        .cornerRadius(6)
                    }
                }
            }
        }
        .padding(12)
        .background(Color.brandBlack.opacity(0.3))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(membership.activa ? Color.green.opacity(0.3) : Color.orange.opacity(0.3), lineWidth: 1)
        )
        .scaleEffect(isToggling ? 0.97 : 1.0)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isToggling)
        .sheet(isPresented: $showingActivationSheet) {
            EnhancedMembershipActivationSheet(membership: membership, manager: manager)
        }
    }
    
    private func suspendMembership() async {
        isToggling = true
        
        await manager.toggleMembershipStatus(
            membershipId: membership.id,
            userEmail: membership.email,
            currentStatus: membership.activa
        )
        
        try? await Task.sleep(nanoseconds: 500_000_000)
        isToggling = false
    }
}

struct DetailedTransactionRow: View {
    let transaction: TransactionData
    @State private var isExpanded = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Fila principal
            HStack(spacing: 12) {
                // Icono del tipo de transacción
                ZStack {
                    Circle()
                        .fill(transaction.transactionType == "activation" ? Color.green.opacity(0.2) : Color.blue.opacity(0.2))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: transaction.transactionType == "activation" ? "play.circle.fill" : "arrow.clockwise.circle.fill")
                        .font(.title3)
                        .foregroundColor(transaction.transactionType == "activation" ? .green : .blue)
                }
                
                // Información principal
                VStack(alignment: .leading, spacing: 4) {
                    Text(transaction.userName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.brandLight)
                    
                    Text(transaction.userEmail)
                        .font(.caption2)
                        .foregroundColor(.brandLight.opacity(0.6))
                    
                    HStack {
                        Text(transaction.membershipType)
                            .font(.caption)
                            .foregroundColor(.brandGold)
                        
                        Text("•")
                            .foregroundColor(.brandLight.opacity(0.5))
                        
                        Text("\(transaction.duration) días")
                            .font(.caption)
                            .foregroundColor(.brandLight.opacity(0.7))
                        
                        Text("•")
                            .foregroundColor(.brandLight.opacity(0.5))
                        
                        Text(transaction.paymentMethod.capitalized)
                            .font(.caption)
                            .foregroundColor(.brandLight.opacity(0.7))
                    }
                }
                
                Spacer()
                
                // Monto y fecha
                VStack(alignment: .trailing, spacing: 4) {
                    Text("$\(Int(transaction.amount).formatted())")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                    
                    Text(DateFormatter.shortDate.string(from: transaction.createdDate))
                        .font(.caption2)
                        .foregroundColor(.brandLight.opacity(0.6))
                    
                    // Indicador de precio personalizado
                    if transaction.customPrice != nil {
                        HStack(spacing: 2) {
                            Image(systemName: "tag.fill")
                                .font(.caption2)
                                .foregroundColor(.brandGold)
                            Text("Personalizado")
                                .font(.caption2)
                                .foregroundColor(.brandGold)
                        }
                    }
                }
                
                // Botón para expandir
                Button(action: {
                    withAnimation(.spring(response: 0.4)) {
                        isExpanded.toggle()
                    }
                }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.brandGold)
                }
            }
            .padding(12)
            .background(Color.brandBlack.opacity(0.2))
            .cornerRadius(8)
            
            // Detalles expandidos
            if isExpanded {
                VStack(spacing: 8) {
                    Divider()
                        .background(Color.brandGold.opacity(0.3))
                    
                    VStack(spacing: 6) {
                        // Detalles de precio
                        if let customPrice = transaction.customPrice {
                            HStack {
                                Text("Precio original:")
                                    .font(.caption)
                                    .foregroundColor(.brandLight.opacity(0.7))
                                Spacer()
                                Text("$\(Int(transaction.originalPrice).formatted())")
                                    .font(.caption)
                                    .foregroundColor(.brandLight.opacity(0.7))
                                    .strikethrough()
                            }
                            
                            HStack {
                                Text("Precio aplicado:")
                                    .font(.caption)
                                    .foregroundColor(.brandLight.opacity(0.7))
                                Spacer()
                                Text("$\(Int(customPrice).formatted())")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.brandGold)
                            }
                            
                            let discount = transaction.originalPrice - customPrice
                            if discount > 0 {
                                HStack {
                                    Text("Descuento:")
                                        .font(.caption)
                                        .foregroundColor(.green.opacity(0.8))
                                    Spacer()
                                    Text("-$\(Int(discount).formatted())")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.green)
                                }
                            } else if discount < 0 {
                                HStack {
                                    Text("Recargo:")
                                        .font(.caption)
                                        .foregroundColor(.orange.opacity(0.8))
                                    Spacer()
                                    Text("+$\(Int(abs(discount)).formatted())")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.orange)
                                }
                            }
                        }
                        
                        // Fechas de membresía
                        HStack {
                            Text("Inicio membresía:")
                                .font(.caption)
                                .foregroundColor(.brandLight.opacity(0.7))
                            Spacer()
                            Text(DateFormatter.membershipFormatter.string(from: transaction.membershipStartDate))
                                .font(.caption)
                                .foregroundColor(.brandLight)
                        }
                        
                        HStack {
                            Text("Vencimiento:")
                                .font(.caption)
                                .foregroundColor(.brandLight.opacity(0.7))
                            Spacer()
                            Text(DateFormatter.membershipFormatter.string(from: transaction.membershipEndDate))
                                .font(.caption)
                                .foregroundColor(.brandLight)
                        }
                        
                        // Admin que procesó
                        HStack {
                            Text("Procesado por:")
                                .font(.caption)
                                .foregroundColor(.brandLight.opacity(0.7))
                            Spacer()
                            Text(transaction.adminUserName)
                                .font(.caption)
                                .foregroundColor(.brandGold)
                        }
                        
                        // Notas si existen
                        if let notes = transaction.notes, !notes.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Notas:")
                                    .font(.caption)
                                    .foregroundColor(.brandLight.opacity(0.7))
                                
                                Text(notes)
                                    .font(.caption)
                                    .foregroundColor(.brandLight)
                                    .padding(8)
                                    .background(Color.brandDark.opacity(0.5))
                                    .cornerRadius(6)
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
                .background(Color.brandBlack.opacity(0.1))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color.brandBlack.opacity(0.2))
        .cornerRadius(8)
    }
}

struct RevenueDetailsSheet: View {
    @StateObject private var revenueManager = RevenueManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPeriod: String = "all"
    
    private let periods = [
        "day": "Hoy",
        "week": "Esta Semana",
        "month": "Este Mes",
        "year": "Este Año",
        "all": "Todo el Tiempo"
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.brandBlack.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Estadísticas principales
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                            StatCard(
                                title: "Total General",
                                value: "$\(Int(revenueManager.totalRevenue).formatted())",
                                icon: "dollarsign.circle.fill",
                                color: .green
                            )
                            
                            StatCard(
                                title: "Este Mes",
                                value: "$\(Int(revenueManager.monthlyRevenue).formatted())",
                                icon: "calendar.circle.fill",
                                color: .brandGold
                            )
                            
                            StatCard(
                                title: "Transacciones",
                                value: "\(revenueManager.transactions.count)",
                                icon: "list.number",
                                color: .blue
                            )
                            
                            StatCard(
                                title: "Promedio",
                                value: "$\(Int(averageTransaction).formatted())",
                                icon: "chart.line.uptrend.xyaxis",
                                color: .purple
                            )
                        }
                        
                        // Gráfico por métodos de pago
                        paymentMethodsChart
                        
                        // Lista completa de transacciones
                        transactionsList
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("Historial de Ingresos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cerrar") {
                        dismiss()
                    }
                    .foregroundColor(.brandGold)
                }
            }
            .preferredColorScheme(.dark)
        }
    }
    
    private var averageTransaction: Double {
        guard !revenueManager.transactions.isEmpty else { return 0 }
        return revenueManager.totalRevenue / Double(revenueManager.transactions.count)
    }
    
    private var paymentMethodsChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ingresos por Método de Pago")
                .font(.headline)
                .foregroundColor(.brandGold)
            
            let paymentData = revenueManager.getTransactionsByPaymentMethod()
            
            ForEach(Array(paymentData.keys.sorted()), id: \.self) { method in
                let amount = paymentData[method] ?? 0
                let percentage = revenueManager.totalRevenue > 0 ? (amount / revenueManager.totalRevenue) : 0
                
                VStack(spacing: 4) {
                    HStack {
                        Text(method.capitalized)
                            .font(.subheadline)
                            .foregroundColor(.brandLight)
                        
                        Spacer()
                        
                        Text("$\(Int(amount).formatted())")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.brandGold)
                    }
                    
                    ProgressView(value: percentage)
                        .progressViewStyle(LinearProgressViewStyle(tint: .brandGold))
                        .background(Color.brandDark)
                        .cornerRadius(4)
                }
            }
        }
        .padding(16)
        .background(Color.brandDark)
        .cornerRadius(12)
    }
    
    private var transactionsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Todas las Transacciones")
                .font(.headline)
                .foregroundColor(.brandGold)
            
            LazyVStack(spacing: 8) {
                ForEach(revenueManager.transactions) { transaction in
                    DetailedTransactionRow(transaction: transaction)
                }
            }
        }
        .padding(16)
        .background(Color.brandDark)
        .cornerRadius(12)
    }
}

struct EnhancedAdminMembershipsCard: View {
    @StateObject private var membershipManager = AdminMembershipManager()
    @StateObject private var revenueManager = RevenueManager.shared
    @State private var showingRevenueDetails = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header con estadísticas de ingresos
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("💳 Gestión de Membresías")
                        .font(.headline)
                        .foregroundColor(.brandLight)
                    
                    Text("Total ingresos: $\(Int(revenueManager.totalRevenue).formatted())")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                
                Spacer()
                
                // Botón para ver detalles de ingresos
                Button(action: {
                    showingRevenueDetails = true
                }) {
                    HStack {
                        Image(systemName: "chart.bar.fill")
                        Text("Ingresos")
                    }
                    .font(.caption)
                    .foregroundColor(.brandBlack)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.green.opacity(0.8))
                    .cornerRadius(8)
                }
                
                // Badge con cantidad pendientes
                let pendingCount = membershipManager.memberships.filter { $0.requiereActivacion }.count
                if pendingCount > 0 {
                    Text("\(pendingCount)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.brandBlack)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange)
                        .cornerRadius(12)
                }
            }
            
            if membershipManager.memberships.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "creditcard.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.brandGold.opacity(0.5))
                    
                    Text("No hay membresías registradas")
                        .font(.subheadline)
                        .foregroundColor(.brandLight.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(membershipManager.memberships) { membership in
                        // Usar la nueva versión con precios personalizados
                        EnhancedMembershipRow(membership: membership, manager: membershipManager)
                    }
                }
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
            membershipManager.loadAllMemberships()
            Task {
                await revenueManager.loadTransactions()
            }
        }
        .sheet(isPresented: $showingRevenueDetails) {
            RevenueDetailsSheet()
        }
    }
}


// MARK: - Membresía Card para Usuarios
struct MembresiaCard: View {
    @ObservedObject var miembroManager: MiembroManager
    let authManager: AuthManager
    @State private var currentMembresia: Membresia?
    @State private var isLoading = true
    @StateObject private var membresiaManager = MembresiaManager()
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("💳 Mi Membresía")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.brandGold)
                    
                    if isLoading {
                        Text("Cargando...")
                            .font(.subheadline)
                            .foregroundColor(.brandLight.opacity(0.7))
                    } else if let membresia = currentMembresia {
                        Text(membresia.tipoMembresia)
                            .font(.subheadline)
                            .foregroundColor(.brandLight)
                    } else {
                        Text("Sin membresía activa")
                            .font(.subheadline)
                            .foregroundColor(.brandLight.opacity(0.7))
                    }
                }
                
                Spacer()
                
                if let membresia = currentMembresia {
                    VStack(spacing: 4) {
                        Text("Estado")
                            .font(.caption2)
                            .foregroundColor(.brandLight.opacity(0.7))
                        
                        Text(membresia.estadoDescripcion)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                membresia.estadoDescripcion == "Activa" ?
                                Color.green.opacity(0.2) : Color.orange.opacity(0.2)
                            )
                            .foregroundColor(
                                membresia.estadoDescripcion == "Activa" ?
                                .green : .orange
                            )
                            .cornerRadius(8)
                    }
                }
            }
            
            if !isLoading {
                if let membresia = currentMembresia {
                    // Información de la membresía
                    VStack(spacing: 12) {
                        // Fechas
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Fecha de Inicio")
                                    .font(.caption)
                                    .foregroundColor(.brandLight.opacity(0.7))
                                Text(membresia.fechaInicio)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.brandLight)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Vencimiento")
                                    .font(.caption)
                                    .foregroundColor(.brandLight.opacity(0.7))
                                Text(membresia.fechaVencimiento)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.brandLight)
                            }
                        }
                        
                        // Precio y días restantes
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Precio Mensual")
                                    .font(.caption)
                                    .foregroundColor(.brandLight.opacity(0.7))
                                Text("$\(Int(membresia.precio).formatted())")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(.brandGold)
                            }
                            
                            Spacer()
                            
                            if let diasRestantes = membresia.diasRestantes {
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("Días Restantes")
                                        .font(.caption)
                                        .foregroundColor(.brandLight.opacity(0.7))
                                    
                                    HStack(spacing: 4) {
                                        if diasRestantes <= 7 {
                                            Image(systemName: "exclamationmark.triangle.fill")
                                                .foregroundColor(.orange)
                                                .font(.caption)
                                        }
                                        
                                        Text("\(diasRestantes)")
                                            .font(.title3)
                                            .fontWeight(.bold)
                                            .foregroundColor(
                                                diasRestantes <= 7 ? .orange :
                                                diasRestantes <= 3 ? .red : .brandGold
                                            )
                                    }
                                }
                            }
                        }
                        
                        // Barra de progreso si hay días restantes
                        if let diasRestantes = membresia.diasRestantes {
                            let totalDias = calculateTotalDays(membresia: membresia)
                            let progreso = max(0, min(1, Double(totalDias - diasRestantes) / Double(totalDias)))
                            
                            VStack(spacing: 8) {
                                HStack {
                                    Text("Progreso de Membresía")
                                        .font(.caption)
                                        .foregroundColor(.brandLight.opacity(0.7))
                                    Spacer()
                                    Text("\(Int(progreso * 100))%")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.brandGold)
                                }
                                
                                ProgressView(value: progreso)
                                    .progressViewStyle(LinearProgressViewStyle(tint: .brandGold))
                                    .background(Color.brandLight.opacity(0.2))
                                    .cornerRadius(4)
                            }
                        }
                        
                        // Botón de renovación si está por vencer
                        if let diasRestantes = membresia.diasRestantes, diasRestantes <= 15 {
                            Button(action: {
                                // ✅ MEJORADO: Llamar al gimnasio para renovar
                                makePhoneCall()
                            }) {
                                HStack {
                                    Image(systemName: "phone.fill")
                                    Text("Contactar Gimnasio")
                                        .fontWeight(.semibold)
                                }
                                .foregroundColor(.brandBlack)
                                .padding(.vertical, 12)
                                .frame(maxWidth: .infinity)
                                .background(
                                    LinearGradient(
                                        colors: [Color.orange, Color.orange.opacity(0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .cornerRadius(10)
                            }
                        }
                    }
                } else {
                    // Sin membresía activa
                    VStack(spacing: 16) {
                        Image(systemName: "creditcard.trianglebadge.exclamationmark")
                            .font(.system(size: 40))
                            .foregroundColor(.brandGold.opacity(0.5))
                        
                        Text("No tienes una membresía activa")
                            .font(.subheadline)
                            .foregroundColor(.brandLight.opacity(0.7))
                            .multilineTextAlignment(.center)
                        
                        Button(action: {
                            // ✅ MEJORADO: Llamar al gimnasio para obtener membresía
                            makePhoneCall()
                        }) {
                            HStack {
                                Image(systemName: "phone.fill")
                                Text("Solicitar Membresía")
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.brandBlack)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                            .background(
                                LinearGradient(
                                    colors: [Color.brandGold, Color.brandGold.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .cornerRadius(10)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color.brandDark, Color.brandDark.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.brandGold.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)
        .onAppear {
            loadUserMembresia()
        }
    }
    
    // ✅ FUNCIÓN PARA LLAMAR AL GIMNASIO
    private func makePhoneCall() {
        let phoneNumber = "3022973150"
        
        if let phoneURL = URL(string: "tel://\(phoneNumber)") {
            if UIApplication.shared.canOpenURL(phoneURL) {
                UIApplication.shared.open(phoneURL, options: [:]) { success in
                    if success {
                        print("✅ Abriendo app de teléfono para llamar a: \(phoneNumber)")
                    } else {
                        print("❌ Error abriendo app de teléfono")
                    }
                }
            } else {
                print("⚠️ Este dispositivo no puede hacer llamadas")
            }
        } else {
            print("❌ URL de teléfono inválida")
        }
    }
    
    // ✅ FUNCIÓN CORREGIDA para Main Actor
    private func loadUserMembresia() {
        Task {
            // ✅ Acceder a currentUserData de forma segura
            let userData = await MainActor.run { authManager.currentUserData }
            
            guard let userData = userData else {
                await MainActor.run {
                    isLoading = false
                }
                return
            }
            
            // Cargar miembros y membresías en paralelo
            await miembroManager.loadMiembros()
            await membresiaManager.loadMembresias()
            
            // Buscar el miembro por email del usuario autenticado
            if let miembro = miembroManager.miembros.first(where: { $0.email == userData.email }) {
                // Buscar la membresía activa para este miembro
                currentMembresia = membresiaManager.getMembresiaForMiembro(idMiembro: miembro.idMiembro)
            }
            
            await MainActor.run {
                isLoading = false
            }
        }
    }
    
    // ✅ CORREGIDO: Usar 'membresia' en lugar de 'membership'
    private func calculateTotalDays(membresia: Membresia) -> Int {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        guard let startDate = formatter.date(from: membresia.fechaInicio),
              let endDate = formatter.date(from: membresia.fechaVencimiento) else {
            return 30 // Default a 30 días si no se puede calcular
        }
        
        return Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 30
    }
}

struct MembershipActivationSheet: View {
    let membership: MembershipData
        let manager: AdminMembershipManager
        @Environment(\.dismiss) private var dismiss
        
        @State private var selectedDays: Int = 30
        @State private var customDays: String = "30"
        @State private var customPrice: String = ""
        @State private var useCustomPrice: Bool = false
        @State private var selectedPaymentMethod: String = "efectivo"
        @State private var notes: String = ""
        @State private var isActivating = false
        @State private var showingConfirmation = false
        
        @StateObject private var revenueManager = RevenueManager.shared
        
        // Opciones predefinidas de días
        private let dayOptions = [7, 15, 30, 60, 90, 180, 365]
        
        // Métodos de pago
        private let paymentMethods = ["efectivo", "transferencia", "tarjeta", "nequi", "daviplata"]
        
        var calculatedEndDate: Date {
            Calendar.current.date(byAdding: .day, value: selectedDays, to: Date()) ?? Date()
        }
        
        var finalPrice: Double {
            if useCustomPrice, let price = Double(customPrice), price > 0 {
                return price
            }
            return membership.precio
        }
        
        var body: some View {
            NavigationView {
                ZStack {
                    Color.brandBlack.ignoresSafeArea()
                    
                    ScrollView {
                        VStack(spacing: 24) {
                            // Header
                            VStack(spacing: 12) {
                                Image(systemName: "calendar.badge.plus")
                                    .font(.system(size: 50))
                                    .foregroundColor(.brandGold)
                                
                                Text("Activar Membresía")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.brandGold)
                                
                                Text("Configura duración, precio y método de pago")
                                    .font(.subheadline)
                                    .foregroundColor(.brandLight.opacity(0.7))
                                    .multilineTextAlignment(.center)
                            }
                            
                            // Información de la membresía
                            membershipInfoSection
                            
                            // Selección de duración
                            durationSelectionSection
                            
                            // Configuración de precio
                            pricingSection
                            
                            // Método de pago
                            paymentMethodSection
                            
                            // Notas adicionales
                            notesSection
                            
                            // Previsualización
                            previewSection
                            
                            // Botón de activación
                            activationButton
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                    }
                }
                .navigationTitle("Activar Membresía")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancelar") {
                            dismiss()
                        }
                        .foregroundColor(.brandLight)
                        .disabled(isActivating)
                    }
                }
                .alert("Confirmar Activación", isPresented: $showingConfirmation) {
                    Button("Activar", role: .cancel) {
                        Task {
                            await activateMembership()
                        }
                    }
                    Button("Cancelar", role: .destructive) { }
                } message: {
                    Text("¿Activar membresía por \(selectedDays) días por $\(Int(finalPrice).formatted())?\n\nMétodo: \(selectedPaymentMethod.capitalized)")
                }
                .onAppear {
                    customPrice = "\(Int(membership.precio))"
                }
                .preferredColorScheme(.dark)
            }
        }
        
        // MARK: - Sección de información de membresía
        private var membershipInfoSection: some View {
            VStack(alignment: .leading, spacing: 12) {
                Text("Información de la Membresía")
                    .font(.headline)
                    .foregroundColor(.brandGold)
                
                VStack(spacing: 8) {
                    HStack {
                        Text("Usuario:")
                            .foregroundColor(.brandLight.opacity(0.7))
                        Spacer()
                        Text(membership.email)
                            .fontWeight(.semibold)
                            .foregroundColor(.brandLight)
                    }
                    
                    HStack {
                        Text("Tipo:")
                            .foregroundColor(.brandLight.opacity(0.7))
                        Spacer()
                        Text(membership.tipoMembresia)
                            .fontWeight(.semibold)
                            .foregroundColor(.brandGold)
                    }
                    
                    HStack {
                        Text("Precio Base:")
                            .foregroundColor(.brandLight.opacity(0.7))
                        Spacer()
                        Text("$\(Int(membership.precio).formatted())")
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                    }
                }
                .padding(16)
                .background(Color.brandDark.opacity(0.5))
                .cornerRadius(12)
            }
        }
        
        // MARK: - Sección de selección de duración
        private var durationSelectionSection: some View {
            VStack(alignment: .leading, spacing: 16) {
                Text("Duración de la Membresía")
                    .font(.headline)
                    .foregroundColor(.brandGold)
                
                Text("Opciones rápidas:")
                    .font(.subheadline)
                    .foregroundColor(.brandLight.opacity(0.8))
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                    ForEach(dayOptions, id: \.self) { days in
                        DayOptionCard(
                            days: days,
                            isSelected: selectedDays == days,
                            action: {
                                selectedDays = days
                                customDays = "\(days)"
                            }
                        )
                    }
                }
                
                // Campo personalizado
                VStack(alignment: .leading, spacing: 8) {
                    Text("O ingresa días personalizados:")
                        .font(.subheadline)
                        .foregroundColor(.brandLight.opacity(0.8))
                    
                    TextField("Número de días", text: $customDays)
                        .keyboardType(.numberPad)
                        .padding(12)
                        .background(Color.brandDark)
                        .foregroundColor(.brandWhite)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.brandGold.opacity(0.3), lineWidth: 1)
                        )
                        .onChange(of: customDays) { newValue in
                            if let days = Int(newValue), days > 0 {
                                selectedDays = days
                            }
                        }
                }
            }
        }
        
        // MARK: - Sección de configuración de precio
        private var pricingSection: some View {
            VStack(alignment: .leading, spacing: 16) {
                Text("Configuración de Precio")
                    .font(.headline)
                    .foregroundColor(.brandGold)
                
                // Toggle para precio personalizado
                Toggle("Usar precio personalizado", isOn: $useCustomPrice)
                    .toggleStyle(SwitchToggleStyle(tint: .brandGold))
                    .foregroundColor(.brandLight)
                
                if useCustomPrice {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Precio personalizado:")
                            .font(.subheadline)
                            .foregroundColor(.brandLight.opacity(0.8))
                        
                        HStack {
                            Text("$")
                                .font(.title2)
                                .foregroundColor(.brandGold)
                            
                            TextField("0", text: $customPrice)
                                .keyboardType(.numberPad)
                                .font(.title2)
                                .fontWeight(.semibold)
                        }
                        .padding(12)
                        .background(Color.brandDark)
                        .foregroundColor(.brandWhite)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.brandGold.opacity(0.3), lineWidth: 1)
                        )
                    }
                }
                
                // Mostrar cálculos
                VStack(spacing: 8) {
                    HStack {
                        Text("Precio total:")
                            .foregroundColor(.brandLight.opacity(0.7))
                        Spacer()
                        Text("$\(Int(finalPrice).formatted())")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.brandGold)
                    }
                    
                    if useCustomPrice {
                        let discount = membership.precio - finalPrice
                        if discount > 0 {
                            HStack {
                                Text("Descuento:")
                                    .foregroundColor(.green.opacity(0.8))
                                Spacer()
                                Text("-$\(Int(discount).formatted())")
                                    .fontWeight(.semibold)
                                    .foregroundColor(.green)
                            }
                        } else if discount < 0 {
                            HStack {
                                Text("Recargo:")
                                    .foregroundColor(.orange.opacity(0.8))
                                Spacer()
                                Text("+$\(Int(abs(discount)).formatted())")
                                    .fontWeight(.semibold)
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                }
                .padding(12)
                .background(Color.brandDark.opacity(0.3))
                .cornerRadius(8)
            }
        }
        
        // MARK: - Sección de método de pago
        private var paymentMethodSection: some View {
            VStack(alignment: .leading, spacing: 16) {
                Text("Método de Pago")
                    .font(.headline)
                    .foregroundColor(.brandGold)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                    ForEach(paymentMethods, id: \.self) { method in
                        PaymentMethodCard(
                            method: method,
                            isSelected: selectedPaymentMethod == method,
                            action: {
                                selectedPaymentMethod = method
                            }
                        )
                    }
                }
            }
        }
        
        // MARK: - Sección de notas
        private var notesSection: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text("Notas adicionales (opcional)")
                    .font(.subheadline)
                    .foregroundColor(.brandLight.opacity(0.8))
                
                TextField("Agregar comentarios sobre esta activación...", text: $notes, axis: .vertical)
                    .lineLimit(2...4)
                    .padding(12)
                    .background(Color.brandDark)
                    .foregroundColor(.brandWhite)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.brandGold.opacity(0.3), lineWidth: 1)
                    )
            }
        }
        
        // MARK: - Sección de previsualización
        private var previewSection: some View {
            VStack(alignment: .leading, spacing: 12) {
                Text("Resumen de Activación")
                    .font(.headline)
                    .foregroundColor(.brandGold)
                
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Fecha de Inicio")
                                .font(.caption)
                                .foregroundColor(.brandLight.opacity(0.7))
                            Text(DateFormatter.membershipFormatter.string(from: Date()))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.brandLight)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Fecha de Vencimiento")
                                .font(.caption)
                                .foregroundColor(.brandLight.opacity(0.7))
                            Text(DateFormatter.membershipFormatter.string(from: calculatedEndDate))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.brandLight)
                        }
                    }
                    
                    Divider().background(Color.brandGold.opacity(0.3))
                    
                    VStack(spacing: 8) {
                        HStack {
                            Text("Duración:")
                            Spacer()
                            Text("\(selectedDays) días")
                                .fontWeight(.semibold)
                        }
                        
                        HStack {
                            Text("Método de pago:")
                            Spacer()
                            Text(selectedPaymentMethod.capitalized)
                                .fontWeight(.semibold)
                        }
                        
                        HStack {
                            Text("Total a cobrar:")
                            Spacer()
                            Text("$\(Int(finalPrice).formatted())")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.brandGold)
                        }
                    }
                    .font(.subheadline)
                    .foregroundColor(.brandLight)
                }
                .padding(16)
                .background(Color.brandDark.opacity(0.3))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.brandGold.opacity(0.2), lineWidth: 1)
                )
            }
        }
        
        // MARK: - Botón de activación
        private var activationButton: some View {
            Button(action: {
                showingConfirmation = true
            }) {
                HStack {
                    if isActivating {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .brandBlack))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                    }
                    
                    Text(isActivating ? "Procesando..." : "Activar Membresía")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.brandBlack)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity)
                .background(
                    LinearGradient(
                        colors: [Color.brandGold, Color.brandGold.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(12)
                .disabled(isActivating || selectedDays <= 0 || (useCustomPrice && Double(customPrice) == nil))
            }
            .scaleEffect(isActivating ? 0.98 : 1.0)
            .animation(.spring(response: 0.3), value: isActivating)
        }
        
        // MARK: - Función de activación con registro de ingresos
        private func activateMembership() async {
            isActivating = true
            
            // ✅ OBTENER DATOS DEL ADMIN ACTUAL - IMPORTANTE: Aquí debes usar datos reales
            let adminUserId = Auth.auth().currentUser?.uid ?? "unknown_admin"
            let adminUserName = "Admin Usuario" // Aquí podrías obtener el nombre real del admin logueado
            
            // Usar la nueva función con precios personalizados
            await manager.activateMembershipWithCustomPriceAndHistory(
                membershipId: membership.id,
                userEmail: membership.email,
                days: selectedDays,
                customPrice: useCustomPrice ? Double(customPrice) : nil,
                paymentMethod: selectedPaymentMethod,
                notes: notes.isEmpty ? nil : notes,
                adminUserId: adminUserId,
                adminUserName: adminUserName
            )
            
            // Delay para mejor UX
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            
            isActivating = false
            dismiss()
        }
}

struct DayOptionCard: View {
    let days: Int
    let isSelected: Bool
    let action: () -> Void
    
    private var displayText: String {
        switch days {
        case 7: return "1 Semana"
        case 15: return "15 Días"
        case 30: return "1 Mes"
        case 60: return "2 Meses"
        case 90: return "3 Meses"
        case 180: return "6 Meses"
        case 365: return "1 Año"
        default: return "\(days) días"
        }
    }
    
    private var subtitle: String {
        "\(days) días"
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(displayText)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(isSelected ? .brandBlack : .brandLight)
                
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(isSelected ? .brandBlack.opacity(0.7) : .brandLight.opacity(0.6))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                isSelected ?
                LinearGradient(
                    colors: [Color.brandGold, Color.brandGold.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ) :
                LinearGradient(
                    colors: [Color.brandDark, Color.brandDark.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        isSelected ? Color.brandGold : Color.brandGold.opacity(0.3),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .animation(.spring(response: 0.3), value: isSelected)
        }
    }
}
// MARK: - UserMembershipCard COMPLETO Y CORREGIDO

// MARK: - UserMembershipCard COMPLETO Y CORREGIDO

struct UserMembershipCard: View {
    let authManager: AuthManager
    @State private var userMembership: MembershipData?
    @State private var isLoading = true
    @State private var membershipListener: ListenerRegistration?
    @State private var showingPaymentAlert = false
    @State private var debugInfo: String = "" // Para debugging
    
    private var isPaymentDue: Bool {
        guard let membership = userMembership,
              let days = membership.diasRestantes else { return false }
        return days <= 1 && membership.activa
    }
    
    // ✅ VERIFICACIÓN: Verificar si el usuario es administrador
    // Removemos esta propiedad por ahora ya que no la estamos usando en el código actual
    // private var isUserAdmin: Bool { ... }
    
    private let db = Firestore.firestore()
    
    var body: some View {
        VStack(spacing: 16) {
            paymentDueAlert
            headerSection
            contentSection
        }
        .padding(20)
        .background(backgroundGradient)
        .cornerRadius(16)
        .overlay(borderOverlay)
        .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)
        .onAppear {
            setupRealtimeMembershipListener()
        }
        .onDisappear {
            cleanup()
        }
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: userMembership?.activa)
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: userMembership?.estadoDescripcion)
    }
    
    // MARK: - Computed Properties
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [Color.brandDark, Color.brandDark.opacity(0.8)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var borderOverlay: some View {
        RoundedRectangle(cornerRadius: 16)
            .stroke(Color.brandGold.opacity(0.2), lineWidth: 1)
    }
    
    // MARK: - Debug Section
    @ViewBuilder
    private var debugSection: some View {
        if !debugInfo.isEmpty {
            Text(debugInfo)
                .font(.caption2)
                .foregroundColor(.yellow)
                .padding(4)
                .background(Color.black.opacity(0.7))
                .cornerRadius(4)
        }
        
        VStack(spacing: 8) {
            Button("🔍 DEBUG MEMBERSHIP DATA") {
                Task {
                    await debugMembershipData()
                }
            }
            .foregroundColor(.yellow)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.7))
            .cornerRadius(8)
            .font(.caption)
            
            Button("🔄 FORCE REFRESH LISTENER") {
                Task { @MainActor in
                    cleanup()
                    setupRealtimeMembershipListener()
                }
            }
            .foregroundColor(.orange)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.7))
            .cornerRadius(8)
            .font(.caption)
        }
    }
    
    // MARK: - Payment Due Alert
    @ViewBuilder
    private var paymentDueAlert: some View {
        if isPaymentDue {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("¡Pago Pendiente!")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                    
                    Text("Tu membresía vence pronto. Renueva para continuar.")
                        .font(.caption)
                        .foregroundColor(.brandLight.opacity(0.8))
                }
            }
            .padding(12)
            .background(Color.orange.opacity(0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
            )
            .animation(.spring(response: 0.5), value: isPaymentDue)
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("💳 Mi Membresía")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.brandGold)
                
                headerSubtitle
            }
            
            Spacer()
            
            if let membership = userMembership {
                membershipStatusBadge(membership)
            }
        }
    }
    
    @ViewBuilder
    private var headerSubtitle: some View {
        if isLoading {
            Text("Cargando...")
                .font(.subheadline)
                .foregroundColor(.brandLight.opacity(0.7))
        } else if let membership = userMembership {
            Text(membership.tipoMembresia)
                .font(.subheadline)
                .foregroundColor(.brandLight)
        } else {
            Text("Sin membresía registrada")
                .font(.subheadline)
                .foregroundColor(.brandLight.opacity(0.7))
        }
    }
    
    private func membershipStatusBadge(_ membership: MembershipData) -> some View {
        VStack(spacing: 4) {
            Text("Estado")
                .font(.caption2)
                .foregroundColor(.brandLight.opacity(0.7))
            
            Text(membership.estadoDescripcion)
                .font(.caption)
                .fontWeight(.semibold)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    membership.activa ?
                    Color.green.opacity(0.2) : Color.orange.opacity(0.2)
                )
                .foregroundColor(
                    membership.activa ?
                    .green : .orange
                )
                .cornerRadius(8)
                .animation(.spring(response: 0.5), value: membership.activa)
                .animation(.spring(response: 0.5), value: membership.estadoDescripcion)
        }
    }
    
    // MARK: - Content Section
    @ViewBuilder
    private var contentSection: some View {
        if !isLoading {
            let _ = print("🎨 RENDERIZANDO UI - isLoading = false")
            let _ = print("🎨 userMembership existe: \(userMembership != nil)")
            
            if let membership = userMembership {
                let _ = print("🎨 userMembership.activa: \(membership.activa)")
                let _ = print("🎨 userMembership.estadoDescripcion: \(membership.estadoDescripcion)")
                
                membershipContentView(membership)
            } else {
                let _ = print("🎨 ❌ MOSTRANDO VISTA SIN MEMBRESÍA")
                noMembershipView()
                    .transition(.opacity)
            }
        } else {
            let _ = print("🎨 ⏳ MOSTRANDO LOADING - isLoading = true")
            ProgressView("Cargando membresía...")
                .foregroundColor(.brandGold)
        }
    }
    
    @ViewBuilder
    private func membershipContentView(_ membership: MembershipData) -> some View {
        if membership.activa {
            let _ = print("🎨 ✅ MOSTRANDO VISTA DE MEMBRESÍA ACTIVA")
            activeMembershipView(membership: membership)
                .transition(.asymmetric(
                    insertion: .move(edge: .leading).combined(with: .opacity),
                    removal: .move(edge: .trailing).combined(with: .opacity)
                ))
        } else {
            let _ = print("🎨 ⚠️ MOSTRANDO VISTA DE MEMBRESÍA INACTIVA")
            inactiveMembershipView(membership: membership)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
        }
    }
    
    private func makePhoneCall() {
        let phoneNumber = "3022973150"
        
        if let phoneURL = URL(string: "tel://\(phoneNumber)") {
            if UIApplication.shared.canOpenURL(phoneURL) {
                UIApplication.shared.open(phoneURL, options: [:]) { success in
                    if success {
                        print("✅ Abriendo app de teléfono para llamar a: \(phoneNumber)")
                    } else {
                        print("❌ Error abriendo app de teléfono")
                    }
                }
            } else {
                print("⚠️ Este dispositivo no puede hacer llamadas")
            }
        } else {
            print("❌ URL de teléfono inválida")
        }
    }

    // MARK: - Vista para membresía activa
    @ViewBuilder
    private func activeMembershipView(membership: MembershipData) -> some View {
        VStack(spacing: 12) {
            // Información de duración y activación (si está disponible)
            if let duracion = membership.duracionDias,
               let fechaActivacion = membership.fechaActivacion {
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Duración Original")
                            .font(.caption)
                            .foregroundColor(.brandLight.opacity(0.7))
                        Text(membership.durationText)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.brandGold)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Activada el")
                            .font(.caption)
                            .foregroundColor(.brandLight.opacity(0.7))
                        Text(DateFormatter.membershipFormatter.string(from: fechaActivacion))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.brandLight)
                    }
                }
                .padding(12)
                .background(Color.brandGold.opacity(0.1))
                .cornerRadius(8)
            }
            
            // Fechas
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Fecha de Inicio")
                        .font(.caption)
                        .foregroundColor(.brandLight.opacity(0.7))
                    Text(membership.fechaInicio)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.brandLight)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Vencimiento")
                        .font(.caption)
                        .foregroundColor(.brandLight.opacity(0.7))
                    Text(membership.fechaVencimiento)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.brandLight)
                }
            }
            
            // Precio y días restantes
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Precio Final")
                        .font(.caption)
                        .foregroundColor(.brandLight.opacity(0.7))
                    
                    if let precioFinal = membership.precioFinal {
                        Text("$\(Int(precioFinal).formatted())")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.brandGold)
                    } else {
                        Text("$\(Int(membership.precio).formatted())")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.brandGold)
                    }
                }
                
                Spacer()
                
                if let diasRestantes = membership.diasRestantes {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Días Restantes")
                            .font(.caption)
                            .foregroundColor(.brandLight.opacity(0.7))
                        
                        HStack(spacing: 4) {
                            if diasRestantes <= 0 {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                                    .font(.caption)
                            } else if diasRestantes <= 7 {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                    .font(.caption)
                            }
                            
                            Text("\(max(0, diasRestantes))")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(
                                    diasRestantes <= 0 ? .red :
                                    diasRestantes <= 3 ? .orange :
                                    diasRestantes <= 7 ? .yellow : .brandGold
                                )
                        }
                    }
                }
            }
            
            // Barra de progreso mejorada
            if let diasRestantes = membership.diasRestantes,
               let duracionOriginal = membership.duracionDias {
                
                let diasTranscurridos = max(0, duracionOriginal - diasRestantes)
                let progreso = max(0, min(1, Double(diasTranscurridos) / Double(duracionOriginal)))
                
                VStack(spacing: 8) {
                    HStack {
                        Text("Progreso de Membresía")
                            .font(.caption)
                            .foregroundColor(.brandLight.opacity(0.7))
                        Spacer()
                        Text("\(Int(progreso * 100))% completado")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.brandGold)
                    }
                    
                    ProgressView(value: progreso)
                        .progressViewStyle(LinearProgressViewStyle(
                            tint: diasRestantes <= 7 ? .orange : .brandGold
                        ))
                        .background(Color.brandLight.opacity(0.2))
                        .cornerRadius(4)
                    
                    HStack {
                        Text("Día \(diasTranscurridos) de \(duracionOriginal)")
                            .font(.caption2)
                            .foregroundColor(.brandLight.opacity(0.6))
                        Spacer()
                        if diasRestantes > 0 {
                            Text("\(diasRestantes) días restantes")
                                .font(.caption2)
                                .foregroundColor(.brandLight.opacity(0.6))
                        } else {
                            Text("Expirada")
                                .font(.caption2)
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            
            // Botones de acción
            if let diasRestantes = membership.diasRestantes {
                if diasRestantes <= 0 {
                    // Membresía expirada
                    Button(action: { makePhoneCall() }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Renovar Membresía")
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.brandWhite)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(Color.red.opacity(0.8))
                        .cornerRadius(8)
                    }
                } else if diasRestantes <= 15 {
                    // Por vencer pronto
                    Button(action: { makePhoneCall() }) {
                        HStack {
                            Image(systemName: "phone.fill")
                            Text("Contactar para Renovar")
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.brandBlack)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(Color.orange.opacity(0.8))
                        .cornerRadius(8)
                    }
                }
            }
        }
    }
    
    // MARK: - Vista para membresía inactiva
    @ViewBuilder
    private func inactiveMembershipView(membership: MembershipData) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.badge.exclamationmark")
                .font(.system(size: 40))
                .foregroundColor(.orange)
                .symbolEffect(.pulse, options: .repeating)
            
            VStack(spacing: 8) {
                Text("Membresía Pendiente de Activación")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.brandLight)
                    .multilineTextAlignment(.center)
                
                Text("Tu membresía \(membership.tipoMembresia) está registrada pero aún no ha sido activada por el administrador.")
                    .font(.caption)
                    .foregroundColor(.brandLight.opacity(0.7))
                    .multilineTextAlignment(.center)
                
                Text("Precio: $\(Int(membership.precio).formatted())/mes")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.brandGold)
            }
            
            // Información de contacto
            VStack(spacing: 8) {
                Text("Contacta al gimnasio para activar tu membresía")
                    .font(.caption2)
                    .foregroundColor(.brandLight.opacity(0.6))
                    .multilineTextAlignment(.center)
                
                Button(action: {
                    makePhoneCall()
                }) {
                    HStack {
                        Image(systemName: "phone.fill")
                        Text("Contactar Gimnasio")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.brandBlack)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(Color.orange.opacity(0.8))
                    .cornerRadius(8)
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Vista para sin membresía
    @ViewBuilder
    private func noMembershipView() -> some View {
        VStack(spacing: 16) {
            Image(systemName: "creditcard.trianglebadge.exclamationmark")
                .font(.system(size: 40))
                .foregroundColor(.brandGold.opacity(0.5))
            
            Text("No tienes una membresía registrada")
                .font(.subheadline)
                .foregroundColor(.brandLight.opacity(0.7))
                .multilineTextAlignment(.center)
            
            Button(action: {
                makePhoneCall()
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Solicitar Membresía")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.brandBlack)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(
                    LinearGradient(
                        colors: [Color.brandGold, Color.brandGold.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(10)
            }
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - ✅ SOLUCIÓN AL PROBLEMA DE TIMING

    // 1. AGREGAR ESTA FUNCIÓN AL UserMembershipCard

    private func setupRealtimeMembershipListener() {
        Task { @MainActor in
            print("🚀 INICIANDO CONFIGURACIÓN DE LISTENER")
            
            // Limpiar listener anterior si existe
            cleanup()
            
            // ✅ ESTRATEGIA DE RETRY CON DELAY
            var retryCount = 0
            let maxRetries = 5
            var finalUserData: UserData? = nil // ✅ Declarar variable aquí
            
            while retryCount < maxRetries {
                print("🔄 Intento \(retryCount + 1) de \(maxRetries)")
                
                // Verificar estado de autenticación
                guard let firebaseUser = Auth.auth().currentUser else {
                    print("❌ No hay usuario autenticado")
                    debugInfo = "❌ Usuario no autenticado"
                    isLoading = false
                    return
                }
                
                print("✅ Firebase User: \(firebaseUser.email ?? "sin email")")
                
                // Intentar obtener userData del AuthManager
                var currentUserData = authManager.currentUserData
                
                // Si no hay userData, intentar cargar desde Firestore
                if currentUserData == nil {
                    print("🔄 Cargando datos desde Firestore...")
                    
                    do {
                        let document = try await db.collection("usuarios").document(firebaseUser.uid).getDocument()
                        
                        if document.exists, let data = document.data() {
                            print("✅ Documento encontrado en Firestore")
                            
                            currentUserData = UserData(
                                uid: firebaseUser.uid,
                                email: data["email"] as? String ?? firebaseUser.email ?? "",
                                displayName: data["displayName"] as? String ?? "",
                                idTipoDocumento: data["idTipoDocumento"] as? Int ?? 1,
                                numeroDocumento: data["numeroDocumento"] as? String ?? "",
                                nombre: data["nombre"] as? String ?? "",
                                apellido: data["apellido"] as? String ?? "",
                                telefono: data["telefono"] as? String ?? "",
                                fechaNacimiento: (data["fechaNacimiento"] as? Timestamp)?.dateValue() ?? Date(),
                                direccion: data["direccion"] as? String ?? "",
                                activo: data["activo"] as? Bool ?? true,
                                idGenero: data["idGenero"] as? Int ?? 1,
                                edad: data["edad"] as? String,
                                peso: data["peso"] as? String,
                                estatura: data["estatura"] as? String,
                                fechaCreacion: (data["fechaCreacion"] as? Timestamp)?.dateValue() ?? Date(),
                                rol: data["rol"] as? String ?? "usuario"
                            )
                            
                            // Actualizar AuthManager
                            authManager.currentUserData = currentUserData
                            finalUserData = currentUserData // ✅ Asignar a la variable final
                            print("✅ Datos asignados al AuthManager")
                            break // Salir del loop de retry
                            
                        } else {
                            print("⚠️ Documento no existe todavía, esperando...")
                            retryCount += 1
                            
                            if retryCount < maxRetries {
                                debugInfo = "⏳ Esperando creación de usuario... (\(retryCount)/\(maxRetries))"
                                // Esperar 2 segundos antes del siguiente intento
                                try await Task.sleep(nanoseconds: 2_000_000_000)
                            } else {
                                print("❌ Máximo número de reintentos alcanzado")
                                debugInfo = "❌ Error: Usuario no encontrado después de \(maxRetries) intentos"
                                isLoading = false
                                return
                            }
                        }
                        
                    } catch {
                        print("❌ Error cargando desde Firestore: \(error.localizedDescription)")
                        retryCount += 1
                        
                        if retryCount < maxRetries {
                            debugInfo = "⚠️ Error, reintentando... (\(retryCount)/\(maxRetries))"
                            try await Task.sleep(nanoseconds: 2_000_000_000)
                        } else {
                            debugInfo = "❌ Error persistente: \(error.localizedDescription)"
                            isLoading = false
                            return
                        }
                    }
                } else {
                    print("✅ UserData obtenido del AuthManager")
                    finalUserData = currentUserData // ✅ Asignar a la variable final
                    break // Salir del loop de retry
                }
            }
            
            // ✅ VERIFICAR QUE TENEMOS userData VÁLIDO
            guard let userData = finalUserData else { // ✅ Usar la variable final
                print("❌ No se pudo obtener userData después de todos los intentos")
                debugInfo = "❌ No se pudieron cargar datos del usuario"
                isLoading = false
                return
            }

            // ✅ MOSTRAR DATOS OBTENIDOS
            print("🔄 CONFIGURANDO LISTENER PARA MEMBRESÍA:")
            print("====================================")
            print("👤 Usuario: \(userData.nombre) \(userData.apellido)")
            print("📧 Email: \(userData.email)")
            print("🆔 UID: \(userData.uid)")
            print("🏷️ Rol: \(userData.rol)")
            print("✅ Activo: \(userData.activo)")
            print("====================================")
            
            debugInfo = "✅ Usuario: \(userData.email)"

            // ✅ CONFIGURAR LISTENER
            setupListenerByUserUID(userData: userData)
        }
    }

    // 2. AGREGAR ESTA FUNCIÓN AUXILIAR PARA RETRY DE MEMBRESÍAS

    private func setupListenerByUserUID(userData: UserData) {
        print("🔄 Configurando listener por userUID: \(userData.uid)")
        
        membershipListener = db.collection("membresias")
            .whereField("userUID", isEqualTo: userData.uid)
            .addSnapshotListener { [self] snapshot, error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("❌ Error en listener por userUID: \(error.localizedDescription)")
                        debugInfo = "❌ Error UID: \(error.localizedDescription)"
                        
                        // Si hay error, intentar por email como fallback
                        setupListenerByEmail(userData: userData)
                        return
                    }

                    guard let snapshot = snapshot else {
                        print("⚠️ Snapshot vacío por userUID")
                        setupListenerByEmail(userData: userData)
                        return
                    }

                    print("📥 LISTENER POR userUID - Docs: \(snapshot.documents.count)")
                    
                    if snapshot.documents.isEmpty {
                        print("⚠️ No se encontraron membresías por userUID")
                        print("🔄 Esperando a que se cree la membresía...")
                        debugInfo = "⏳ Esperando creación de membresía..."
                        
                        // Intentar por email como fallback
                        setupListenerByEmail(userData: userData)
                        return
                    }
                    
                    // ✅ Procesar membresía encontrada
                    processMembershipSnapshot(snapshot: snapshot, searchMethod: "userUID")
                }
            }
    }
    
    private func setupListenerByEmail(userData: UserData) {
        print("🔄 Configurando listener por email: \(userData.email)")
        
        // Limpiar listener anterior si existe
        membershipListener?.remove()
        
        membershipListener = db.collection("membresias")
            .whereField("email", isEqualTo: userData.email)
            .addSnapshotListener { [self] snapshot, error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("❌ Error en listener por email: \(error.localizedDescription)")
                        debugInfo = "❌ Error email: \(error.localizedDescription)"
                        isLoading = false
                        return
                    }
                    
                    guard let snapshot = snapshot else {
                        print("⚠️ Snapshot vacío por email")
                        debugInfo = "⚠️ Sin membresías"
                        userMembership = nil
                        isLoading = false
                        return
                    }
                    
                    print("📥 LISTENER POR EMAIL - Docs: \(snapshot.documents.count)")
                    
                    if snapshot.documents.isEmpty {
                        print("⚠️ No se encontraron membresías por email")
                        debugInfo = "⏳ Sin membresía registrada"
                        userMembership = nil
                        isLoading = false
                        return
                    }
                    
                    // ✅ Procesar membresía encontrada
                    processMembershipSnapshot(snapshot: snapshot, searchMethod: "email")
                    
                    // ✅ Corregir userUID si es necesario
                    if let doc = snapshot.documents.first {
                        let data = doc.data()
                        let currentUserUID = data["userUID"] as? String ?? ""
                        
                        if currentUserUID != userData.uid {
                            print("🔧 CORRIGIENDO userUID automáticamente")
                            Task {
                                do {
                                    try await doc.reference.updateData([
                                        "userUID": userData.uid,
                                        "fechaCorreccionUID": Timestamp(date: Date())
                                    ])
                                    print("✅ UserUID corregido automáticamente")
                                } catch {
                                    print("❌ Error corrigiendo userUID: \(error.localizedDescription)")
                                }
                            }
                        }
                    }
                }
            }
    }
    
    private func processMembershipSnapshot(snapshot: QuerySnapshot, searchMethod: String) {
        print("🔄 PROCESANDO SNAPSHOT (método: \(searchMethod)):")
        print("====================================")
        print("📊 Documentos: \(snapshot.documents.count)")
        print("🔄 Cambios: \(snapshot.documentChanges.count)")
        
        // ✅ DEBUGGING: Mostrar todos los cambios
        for change in snapshot.documentChanges {
            let data = change.document.data()
            print("📄 Cambio detectado (\(change.type.rawValue)):")
            print("  Doc ID: \(change.document.documentID)")
            print("  Email: \(data["email"] as? String ?? "nil")")
            print("  UserUID: \(data["userUID"] as? String ?? "nil")")
            print("  Activa: \(data["activa"] as? Bool ?? false)")
            print("  Estado: \(data["estadoDescripcion"] as? String ?? "nil")")
        }
        print("====================================")
        
        debugInfo = "📥 \(searchMethod): \(snapshot.documents.count) docs, \(snapshot.documentChanges.count) cambios"

        if let doc = snapshot.documents.first {
            let docData = doc.data()
            let previousMembership = userMembership
            let newMembership = MembershipData(from: doc)

            print("✅ MEMBRESÍA PROCESADA:")
            print("====================================")
            print("🆔 ID: \(doc.documentID)")
            print("📧 Email: \(docData["email"] as? String ?? "nil")")
            print("👤 UserUID: \(docData["userUID"] as? String ?? "nil")")
            print("✅ Activa: \(docData["activa"] ?? "nil") -> \(newMembership.activa)")
            print("📋 Estado: \(docData["estadoDescripcion"] as? String ?? "nil")")
            print("🔍 Método búsqueda: \(searchMethod)")
            print("====================================")

            let wasInactive = previousMembership?.activa == false
            let isNowActive = newMembership.activa == true
            
            print("🔄 CAMBIO DE ESTADO:")
            print("- Estado anterior: \(previousMembership?.activa ?? false)")
            print("- Estado nuevo: \(newMembership.activa)")
            print("- ¿Cambió de inactiva a activa?: \(wasInactive && isNowActive)")
            
            // ✅ LOGS CRÍTICOS PARA LA UI
            print("🎨 ACTUALIZANDO INTERFAZ DE USUARIO:")
            print("- userMembership anterior: \(previousMembership != nil ? "existe" : "nil")")
            print("- userMembership nuevo: existe con activa=\(newMembership.activa)")
            print("- isLoading actual: \(isLoading)")
            print("- debugInfo que se mostrará: \(searchMethod) Activa: \(newMembership.activa)")
            
            debugInfo = "✅ (\(searchMethod)) Activa: \(newMembership.activa) - Estado: \(newMembership.estadoDescripcion)"

            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                userMembership = newMembership
                print("🎨 ✅ userMembership ASIGNADA CON ANIMACIÓN")
                print("🎨 ✅ Ahora userMembership.activa = \(newMembership.activa)")
            }

            if wasInactive && isNowActive {
                print("🎉 Membresía activada - mostrando celebración")
                showActivationCelebration()
            }
            
            // ✅ LOG FINAL DE VERIFICACIÓN
            print("🎨 ESTADO FINAL DE LA UI:")
            print("- userMembership.activa: \(userMembership?.activa ?? false)")
            print("- isLoading: \(isLoading)")
            print("- debugInfo: \(debugInfo)")
            
        } else {
            print("⚠️ No hay documentos en el snapshot")
            debugInfo = "⚠️ Sin documentos en snapshot"
            
            print("🎨 LIMPIANDO INTERFAZ - No hay membresías")
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                userMembership = nil
                print("🎨 ✅ userMembership ESTABLECIDA A NIL")
            }
        }

        isLoading = false
        print("🎨 ✅ isLoading establecido a FALSE - UI debería mostrar contenido")
        print("====================================")
    }
    
    // MARK: - Celebración de activación
    private func showActivationCelebration() {
        DispatchQueue.main.async {
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            
            print("🎉 ¡Membresía activada! Mostrando celebración")
        }
    }
    
    // MARK: - ✅ FUNCIÓN DE LIMPIEZA
    private func cleanup() {
        print("🧹 Limpiando listener de membresía...")
        membershipListener?.remove()
        membershipListener = nil
    }
    
    // MARK: - ✅ FUNCIÓN DE DEBUGGING TEMPORAL
    private func debugMembershipData() async {
        // ✅ CORREGIR: Acceder a userData desde MainActor
        let userData = await MainActor.run { authManager.currentUserData }
        
        guard let userData = userData else {
            print("❌ No hay userData para debugging")
            await MainActor.run {
                debugInfo = "❌ No hay userData"
            }
            return
        }
        
        do {
            // 1. Verificar datos del usuario
            print("🔍 DEBUGGING DATOS DEL USUARIO:")
            print("====================================")
            print("UID: \(userData.uid)")
            print("Email: \(userData.email)")
            print("Nombre: \(userData.nombre)")
            print("====================================")
            
            // 2. Buscar membresías por userUID
            let membershipsByUID = try await db.collection("membresias")
                .whereField("userUID", isEqualTo: userData.uid)
                .getDocuments()
            
            print("🔍 MEMBRESÍAS POR userUID:")
            print("====================================")
            print("Encontradas: \(membershipsByUID.documents.count)")
            
            for (index, doc) in membershipsByUID.documents.enumerated() {
                let data = doc.data()
                print("\n📄 MEMBRESÍA \(index + 1):")
                print("🆔 ID: \(doc.documentID)")
                print("📧 Email: \(data["email"] as? String ?? "nil")")
                print("👤 UserUID: \(data["userUID"] as? String ?? "nil")")
                print("✅ Activa: \(data["activa"] as? Bool ?? false)")
                print("📋 Estado: \(data["estadoDescripcion"] as? String ?? "nil")")
                print("🏷️ Tipo: \(data["tipoMembresia"] as? String ?? "nil")")
                print("📅 Inicio: \(data["fechaInicio"] as? String ?? "nil")")
                print("📅 Venc: \(data["fechaVencimiento"] as? String ?? "nil")")
                print("⏰ Días: \(data["diasRestantes"] as? Int ?? 0)")
                print("🔄 Req.Act: \(data["requiereActivacion"] as? Bool ?? true)")
                
                // Mostrar TODOS los campos
                print("📋 TODOS LOS CAMPOS:")
                for (key, value) in data.sorted(by: { $0.key < $1.key }) {
                    print("  \(key): \(value)")
                }
            }
            
            // 3. Buscar también por email para comparar
            let membershipsByEmail = try await db.collection("membresias")
                .whereField("email", isEqualTo: userData.email)
                .getDocuments()
            
            print("\n🔍 MEMBRESÍAS POR EMAIL:")
            print("====================================")
            print("Encontradas: \(membershipsByEmail.documents.count)")
            
            for (index, doc) in membershipsByEmail.documents.enumerated() {
                let data = doc.data()
                print("\n📄 MEMBRESÍA \(index + 1) (por email):")
                print("🆔 ID: \(doc.documentID)")
                print("📧 Email: \(data["email"] as? String ?? "nil")")
                print("👤 UserUID: \(data["userUID"] as? String ?? "nil")")
                print("✅ Activa: \(data["activa"] as? Bool ?? false)")
                print("📋 Estado: \(data["estadoDescripcion"] as? String ?? "nil")")
            }
            
            print("====================================")
            
            // 4. Verificar estado actual del listener
            print("🔍 ESTADO ACTUAL DE LA VISTA:")
            print("====================================")
            
            // ✅ ACCEDER A PROPIEDADES DE LA UI DESDE MainActor
            await MainActor.run {
                print("Loading: \(isLoading)")
                print("UserMembership existe: \(userMembership != nil)")
                if let membership = userMembership {
                    print("Membership activa: \(membership.activa)")
                    print("Membership estado: \(membership.estadoDescripcion)")
                    print("Membership ID: \(membership.id)")
                    print("Membership userUID: \(membership.userUID)")
                }
                print("DebugInfo: \(debugInfo)")
            }
            print("====================================")
            
            // 5. Actualizar debugInfo en la UI
            await MainActor.run {
                debugInfo = "✅ Debug completo - ver consola para detalles"
            }
            
        } catch {
            print("❌ Error en debugging: \(error.localizedDescription)")
            await MainActor.run {
                debugInfo = "❌ Error: \(error.localizedDescription)"
            }
        }
    }
}


// MARK: - AdminDashboard con roles
struct AdminDashboard: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var dashboardManager = DashboardManager()
    @StateObject private var miembroManager = MiembroManager()
    @State private var showingMiembros = false
    @State private var showingProfileSheet = false
    
    private func initializeMembershipTracking() {
            MembershipDayTracker.shared.startDailyUpdates()
            
            print("✅ Sistema de tracking de membresías inicializado")
        }
    
    var body: some View {
        let isIPad = UIDevice.current.userInterfaceIdiom == .pad
        let userRole = authManager.currentUserData?.rol ?? "usuario"
        
        if isIPad {
            NavigationStack {
                if userRole == "administrador" {
                    iPadAdminContent
                } else {
                    iPadUserContent
                }
            }
        } else {
            NavigationView {
                if userRole == "administrador" {
                    iPhoneAdminContent
                } else {
                    iPhoneUserContent
                }
            }
            .navigationViewStyle(.stack)
        }
    }
    
    // MARK: - iPad Admin Content (CON SISTEMA DE RECORDATORIOS)
    private var iPadAdminContent: some View {
        GeometryReader { geometry in
            ZStack {
                Color.brandBlack.ignoresSafeArea(.all)
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Header administrativo
                        AdminHeaderCard(authManager: authManager, dashboardManager: dashboardManager)
                        
                        // Gestión de membresías
                        //AdminMembershipsListCard()
                        
                        EnhancedAdminMembershipsCard()
                                            
                        RevenueDashboard()
                                            
                        PaymentReminderDashboard()
                        
                        // Chat IA
                        IAChatCard()
                        
                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                }
                .safeAreaInset(edge: .bottom) {
                    Color.clear.frame(height: 20)
                }
            }
            .navigationTitle("Panel de Administrador")
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
                // ✅ IMPORTANTE: Inicializar sistema de recordatorios
                PaymentReminderManager.shared.startMonitoring()
            }
            .preferredColorScheme(.dark)
        }
    }
    
    // MARK: - iPhone Admin Content (CON SISTEMA DE RECORDATORIOS)
    private var iPhoneAdminContent: some View {
        ZStack {
            Color.brandBlack.ignoresSafeArea(.all)
            
            ScrollView {
                VStack(spacing: 20) {
                    // Header administrativo
                    AdminHeaderCard(authManager: authManager, dashboardManager: dashboardManager)
                    
                    // Gestión de membresías
                    //AdminMembershipsListCard()
                    
                    EnhancedAdminMembershipsCard()
                                        
                    RevenueDashboard()
                                        
                    PaymentReminderDashboard()
                    
                    // Chat IA
                    IAChatCard()
                    
                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
            }
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 20)
            }
        }
        .navigationTitle("Panel de Administrador")
        .navigationBarTitleDisplayMode(.inline)
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
            // ✅ IMPORTANTE: Inicializar sistema de recordatorios
            PaymentReminderManager.shared.startMonitoring()
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - iPad User Content (CON MONITOREO PERSONAL)
    private var iPadUserContent: some View {
        GeometryReader { geometry in
            ZStack {
                Color.brandBlack.ignoresSafeArea(.all)
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Header con información personal
                        HeaderCard(authManager: authManager, dashboardManager: dashboardManager, miembroManager: miembroManager)
                        
                        // Tarjeta de membresía personal (ya tiene el sistema de tiempo real)
                        UserMembershipCard(authManager: authManager)
                        
                        // Chat IA
                        IAChatCard()
                        
                        // Calendario de notificaciones
                        CalendarNotification()
                        
                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                }
                .safeAreaInset(edge: .bottom) {
                    Color.clear.frame(height: 20)
                }
            }
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
            .preferredColorScheme(.dark)
        }
    }
    
    // MARK: - iPhone User Content (CON MONITOREO PERSONAL)
    private var iPhoneUserContent: some View {
        ZStack {
            Color.brandBlack.ignoresSafeArea(.all)
            
            ScrollView {
                VStack(spacing: 20) {
                    // Header con información personal
                    HeaderCard(authManager: authManager, dashboardManager: dashboardManager, miembroManager: miembroManager)
                    
                    // Tarjeta de membresía personal (ya tiene el sistema de tiempo real)
                    UserMembershipCard(authManager: authManager)
                    
                    // Chat IA
                    IAChatCard()
                    
                    // Calendario de notificaciones
                    CalendarNotification()
                    
                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
            }
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 20)
            }
        }
        .navigationTitle("Gym Body Gold")
        .navigationBarTitleDisplayMode(.inline)
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
        .preferredColorScheme(.dark)
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
    
    init() {
        loadMockData()
    }
    
    func loadDashboardData() {
        // Simular carga de datos
        calculatePaymentDays()
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

struct UserProfileView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var editableUser: UserData?
    @State private var isEditing = false

    var body: some View {
        NavigationView {
            ZStack {
                Color.brandBlack.ignoresSafeArea()

                if let userData = editableUser {
                    ScrollView {
                        VStack(spacing: 25) {
                            
                            // Avatar
                            VStack {
                                Image(systemName: "person.circle.fill")
                                    .resizable()
                                    .frame(width: 120, height: 120)
                                    .foregroundColor(.brandGold)
                                    .shadow(color: .brandGold.opacity(0.5), radius: 10)
                                
                                Text(userData.displayName)
                                    .font(.title3.bold())
                                    .foregroundColor(.brandWhite)
                                    .padding(.top, 4)
                            }
                            .padding(.top)

                            // Sección Información Personal
                            profileSection(title: "Información Personal") {
                                CustomTextField(
                                    placeholder: "Nombre",
                                    text: Binding(
                                        get: { userData.nombre },
                                        set: { editableUser?.nombre = $0 }
                                    ),
                                    icon: "person.fill"
                                )
                                .disabled(!isEditing)

                                CustomTextField(
                                    placeholder: "Apellido",
                                    text: Binding(
                                        get: { userData.apellido },
                                        set: { editableUser?.apellido = $0 }
                                    ),
                                    icon: "person.fill"
                                )
                                .disabled(!isEditing)

                                CustomTextField(
                                    placeholder: "Nombre de Usuario",
                                    text: Binding(
                                        get: { userData.displayName },
                                        set: { editableUser?.displayName = $0 }
                                    ),
                                    icon: "at.circle.fill"
                                )
                                .disabled(!isEditing)
                            }

                            // Sección Contacto
                            profileSection(title: "Contacto") {
                                CustomTextField(
                                    placeholder: "Teléfono",
                                    text: Binding(
                                        get: { userData.telefono },
                                        set: { editableUser?.telefono = $0 }
                                    ),
                                    icon: "phone.fill",
                                    keyboardType: .phonePad
                                )
                                .disabled(!isEditing)

                                CustomTextField(
                                    placeholder: "Dirección",
                                    text: Binding(
                                        get: { userData.direccion },
                                        set: { editableUser?.direccion = $0 }
                                    ),
                                    icon: "house.fill"
                                )
                                .disabled(!isEditing)
                            }

                            // Sección Datos Físicos
                            profileSection(title: "Datos Físicos") {
                                CustomTextField(
                                    placeholder: "Edad",
                                    text: Binding(
                                        get: { userData.edad ?? "" },
                                        set: { editableUser?.edad = $0 }
                                    ),
                                    icon: "calendar",
                                    keyboardType: .numberPad
                                )
                                .disabled(!isEditing)

                                CustomTextField(
                                    placeholder: "Peso (kg)",
                                    text: Binding(
                                        get: { userData.peso ?? "" },
                                        set: { editableUser?.peso = $0 }
                                    ),
                                    icon: "scalemass",
                                    keyboardType: .decimalPad
                                )
                                .disabled(!isEditing)

                                CustomTextField(
                                    placeholder: "Estatura (cm)",
                                    text: Binding(
                                        get: { userData.estatura ?? "" },
                                        set: { editableUser?.estatura = $0 }
                                    ),
                                    icon: "ruler",
                                    keyboardType: .decimalPad
                                )
                                .disabled(!isEditing)
                            }
                        }
                        .padding(.horizontal)
                        .animation(.easeInOut, value: isEditing)
                    }
                } else {
                    ProgressView("Cargando perfil...")
                        .progressViewStyle(CircularProgressViewStyle(tint: .brandGold))
                }
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Perfil del Usuario")
                        .font(.headline)
                        .foregroundColor(.brandGold)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    if isEditing {
                        Button("Guardar") {
                            Task {
                                if let updated = editableUser {
                                    await authManager.updateUserData(updated)
                                    isEditing = false
                                }
                            }
                        }
                        .disabled(authManager.isLoading)
                    } else {
                        Button("Editar") {
                            isEditing = true
                        }
                    }
                }
            }
            .onAppear {
                if editableUser == nil, let current = authManager.currentUserData {
                    editableUser = current
                }
            }
            .preferredColorScheme(.dark)
        }
    }

    // MARK: - Subview para secciones
    @ViewBuilder
    private func profileSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            Text(title)
                .font(.headline)
                .foregroundColor(.brandGold)
            
            VStack(spacing: 12) {
                content()
            }
            .padding()
            .background(Color.brandWhite.opacity(0.05))
            .cornerRadius(15)
            .overlay(
                RoundedRectangle(cornerRadius: 15)
                    .stroke(Color.brandGold.opacity(0.2), lineWidth: 1)
            )
        }
    }
}


@MainActor
class FCMNotificationManager: NSObject, ObservableObject {
    static let shared = FCMNotificationManager()
    
    @Published var fcmToken: String = ""
    @Published var isNotificationPermissionGranted = false
    
    // URLs de tu backend
    private let baseURL = "https://laravel-multi-serv-app-production.up.railway.app/api"
    private let loginEndpoint = "/login"
    private let fcmEndpoint = "/fcm/gymbodygold/send"
    
    private override init() {
        super.init()
    }
    
    // MARK: - Setup inicial de notificaciones
    func setupNotifications() {
        print("📱 FCMNotificationManager: Configurando notificaciones...")
        
        // Solicitar permisos de notificación
        requestNotificationPermissions()
        
        // Configurar delegado de FCM
        Messaging.messaging().delegate = self
        
        // Obtener token FCM
        getFCMToken()
    }
    
    // MARK: - Solicitar permisos de notificación
    private func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                self.isNotificationPermissionGranted = granted
                print(granted ? "✅ Permisos de notificación concedidos" : "❌ Permisos de notificación denegados")
                
                if let error = error {
                    print("❌ Error solicitando permisos: \(error.localizedDescription)")
                }
            }
            
            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
    }
    
    // MARK: - Obtener token FCM
    private func getFCMToken() {
        Messaging.messaging().token { token, error in
            if let error = error {
                print("❌ Error obteniendo FCM token: \(error.localizedDescription)")
                return
            }
            
            guard let token = token else {
                print("❌ No se pudo obtener el FCM token")
                return
            }
            
            DispatchQueue.main.async {
                self.fcmToken = token
                print("✅ FCM Token obtenido:")
                print("====================================")
                print(token)
                print("====================================")
                print("📋 Copia este token para usar en Postman")
                
                // Guardar token en Firestore para el usuario actual (si está autenticado)
                if Auth.auth().currentUser != nil {
                    self.saveFCMTokenToFirestore(token: token)
                }
            }
        }
    }
    
    // MARK: - Guardar token FCM en Firestore
    private func saveFCMTokenToFirestore(token: String) {
        guard let uid = Auth.auth().currentUser?.uid else {
            print("❌ No hay usuario autenticado para guardar FCM token")
            return
        }
        
        let db = Firestore.firestore()
        db.collection("usuarios").document(uid).updateData([
            "fcmToken": token,
            "lastTokenUpdate": Timestamp()
        ]) { error in
            if let error = error {
                print("❌ Error guardando FCM token: \(error.localizedDescription)")
            } else {
                print("✅ FCM token guardado en Firestore para usuario: \(uid)")
            }
        }
    }
    
    // MARK: - Obtener JWT Token del backend Laravel
    private func getJWTToken() async throws -> String {
        guard let url = URL(string: "\(baseURL)\(loginEndpoint)") else {
            throw FCMError.invalidURL
        }
        
        let loginData: [String: String] = [
            "email": "developer@gimomagic.com.co",
            "password": "Tomate123##"
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: loginData)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw FCMError.authenticationFailed
        }
        
        struct LoginResponse: Codable {
            let success: Bool
            let token: String
            let expires_in: Int
            let user: User
            
            struct User: Codable {
                let id: Int
                let name: String
                let email: String
            }
        }
        
        let loginResponse = try JSONDecoder().decode(LoginResponse.self, from: data)
        
        if !loginResponse.success {
            throw FCMError.authenticationFailed
        }
        
        print("✅ JWT Token obtenido del backend Laravel")
        return loginResponse.token
    }
    
    private func getFCMTokenForUser(userId: String) async -> String? {
        // Si el userId es el mismo que el usuario actual, usar el token local
        if let currentUser = Auth.auth().currentUser, currentUser.uid == userId {
            if !fcmToken.isEmpty {
                print("✅ Usando FCM token local para usuario actual")
                return fcmToken
            }
        }
        
        // Si es otro usuario, buscar en Firestore
        do {
            let db = Firestore.firestore()
            let document = try await db.collection("usuarios").document(userId).getDocument()
            
            if let data = document.data(),
               let token = data["fcmToken"] as? String {
                print("✅ FCM token encontrado en Firestore para userId: \(userId)")
                return token
            } else {
                print("❌ No se encontró FCM token en Firestore para userId: \(userId)")
                return nil
            }
        } catch {
            print("❌ Error buscando FCM token en Firestore: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - Enviar notificación usando Laravel backend
    func sendNotificationToUser(
        userId: String,
        title: String,
        body: String,
        data: [String: Any] = [:],
        directToken: String? = nil // ✅ Parámetro opcional para token directo
    ) async {
        do {
            // 1. Obtener JWT token del backend
            let jwtToken = try await getJWTToken()
            
            // 2. Construir URL del endpoint FCM
            guard let url = URL(string: "\(baseURL)\(fcmEndpoint)") else {
                print("❌ URL inválida para FCM endpoint")
                return
            }
            
            // 3. Determinar qué FCM token usar
            var fcmTokenToUse: String? = directToken
            
            if fcmTokenToUse == nil {
                // Si no se proporciona token directo, intentar obtener desde Firestore o usar el local
                fcmTokenToUse = await getFCMTokenForUser(userId: userId)
            }
            
            // 4. Construir payload para Laravel
            var payload: [String: Any] = [
                "user_id": userId,
                "title": title,
                "body": body,
                "data": data
            ]
            
            // ✅ AGREGAR FCM TOKEN AL PAYLOAD
            if let token = fcmTokenToUse {
                payload["fcm_token"] = token
                print("✅ Usando FCM token: \(String(token.prefix(20)))...")
            } else {
                print("⚠️ No se encontró FCM token - Laravel buscará en Firestore")
            }
            
            // 5. Imprimir el body del JSON que se envía
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: payload, options: .prettyPrinted)
                if let jsonString = String(data: jsonData, encoding: .utf8) {
                    print("📤 BODY JSON ENVIADO:")
                    print("====================================")
                    print(jsonString)
                    print("====================================")
                }
            } catch {
                print("❌ Error al serializar JSON para debug: \(error.localizedDescription)")
            }
            
            // 6. Crear request
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("Bearer \(jwtToken)", forHTTPHeaderField: "Authorization")
            
            print("📤 HEADERS ENVIADOS:")
            print("Content-Type: application/json")
            print("Accept: application/json")
            print("Authorization: Bearer \(String(jwtToken.prefix(20)))...")
            print("URL: \(url.absoluteString)")
            print("====================================")
            
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            
            // 7. Enviar request
            let (responseData, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📥 RESPUESTA RECIBIDA:")
                print("Status Code: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 200 {
                    print("✅ Notificación enviada exitosamente via Laravel")
                    
                    if let responseString = String(data: responseData, encoding: .utf8) {
                        print("📱 Respuesta del servidor:")
                        print("====================================")
                        print(responseString)
                        print("====================================")
                    }
                } else {
                    print("❌ Error enviando notificación. Status: \(httpResponse.statusCode)")
                    if let errorString = String(data: responseData, encoding: .utf8) {
                        print("📱 Error del servidor:")
                        print("====================================")
                        print(errorString)
                        print("====================================")
                    }
                }
            }
            
        } catch {
            print("❌ Error enviando notificación via Laravel: \(error.localizedDescription)")
        }
    }
}

// MARK: - Extensión para MessagingDelegate
extension FCMNotificationManager: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("📱 Nuevo FCM token recibido: \(fcmToken?.prefix(20) ?? "nil")...")
        
        if let token = fcmToken {
            DispatchQueue.main.async {
                self.fcmToken = token
                
                // Imprimir token completo para debugging
                print("🔥 FCM TOKEN COMPLETO ACTUALIZADO:")
                print("====================================")
                print(token)
                print("====================================")
                
                // Guardar token si hay usuario autenticado
                if Auth.auth().currentUser != nil {
                    self.saveFCMTokenToFirestore(token: token)
                }
            }
        }
    }
}
struct TransactionData: Identifiable, Codable {
    let id: String
    let userEmail: String
    let userName: String
    let membershipType: String
    let amount: Double
    let customPrice: Double?
    let originalPrice: Double
    let duration: Int // días
    let transactionType: String // "activation", "renewal"
    let paymentMethod: String // "efectivo", "transferencia", "tarjeta"
    let createdDate: Date
    let membershipStartDate: Date
    let membershipEndDate: Date
    let adminUserId: String
    let adminUserName: String
    let notes: String?
    
    init(from document: QueryDocumentSnapshot) {
        let data = document.data()
        self.id = document.documentID
        self.userEmail = data["userEmail"] as? String ?? ""
        self.userName = data["userName"] as? String ?? ""
        self.membershipType = data["membershipType"] as? String ?? ""
        self.amount = data["amount"] as? Double ?? 0.0
        self.customPrice = data["customPrice"] as? Double
        self.originalPrice = data["originalPrice"] as? Double ?? 0.0
        self.duration = data["duration"] as? Int ?? 30
        self.transactionType = data["transactionType"] as? String ?? "activation"
        self.paymentMethod = data["paymentMethod"] as? String ?? "efectivo"
        self.createdDate = (data["createdDate"] as? Timestamp)?.dateValue() ?? Date()
        self.membershipStartDate = (data["membershipStartDate"] as? Timestamp)?.dateValue() ?? Date()
        self.membershipEndDate = (data["membershipEndDate"] as? Timestamp)?.dateValue() ?? Date()
        self.adminUserId = data["adminUserId"] as? String ?? ""
        self.adminUserName = data["adminUserName"] as? String ?? ""
        self.notes = data["notes"] as? String
    }
}

// MARK: - Manager de Ganancias
@MainActor
class RevenueManager: ObservableObject {
    static let shared = RevenueManager()
    
    @Published var transactions: [TransactionData] = []
    @Published var totalRevenue: Double = 0.0
    @Published var monthlyRevenue: Double = 0.0
    @Published var isLoading = false
    
    private let db = Firestore.firestore()
    
    private init() {}
    
    // MARK: - Registrar nueva transacción
    func recordTransaction(
        userEmail: String,
        userName: String,
        membershipType: String,
        originalPrice: Double,
        customPrice: Double?,
        duration: Int,
        transactionType: String,
        paymentMethod: String,
        membershipStartDate: Date,
        membershipEndDate: Date,
        adminUserId: String,
        adminUserName: String,
        notes: String? = nil
    ) async -> Bool {
        
        let finalAmount = customPrice ?? originalPrice
        
        let transactionData: [String: Any] = [
            "userEmail": userEmail,
            "userName": userName,
            "membershipType": membershipType,
            "amount": finalAmount,
            "customPrice": customPrice as Any,
            "originalPrice": originalPrice,
            "duration": duration,
            "transactionType": transactionType,
            "paymentMethod": paymentMethod,
            "createdDate": Timestamp(date: Date()),
            "membershipStartDate": Timestamp(date: membershipStartDate),
            "membershipEndDate": Timestamp(date: membershipEndDate),
            "adminUserId": adminUserId,
            "adminUserName": adminUserName,
            "notes": notes as Any
        ]
        
        do {
            let documentRef = try await db.collection("revenue_transactions").addDocument(data: transactionData)
            
            print("✅ Transacción registrada con ID: \(documentRef.documentID)")
            print("💰 Monto: $\(finalAmount)")
            print("👤 Usuario: \(userName) (\(userEmail))")
            print("🎯 Tipo: \(transactionType)")
            
            // Actualizar totales
            await updateRevenueTotals()
            
            return true
        } catch {
            print("❌ Error registrando transacción: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Cargar transacciones
    func loadTransactions() async {
        isLoading = true
        
        do {
            let snapshot = try await db.collection("revenue_transactions")
                .order(by: "createdDate", descending: true)
                .getDocuments()
            
            transactions = snapshot.documents.compactMap { TransactionData(from: $0) }
            
            await updateRevenueTotals()
            
        } catch {
            print("❌ Error cargando transacciones: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    // MARK: - Actualizar totales de ingresos
    private func updateRevenueTotals() async {
        totalRevenue = transactions.reduce(0) { $0 + $1.amount }
        
        // Calcular ingresos del mes actual
        let calendar = Calendar.current
        let now = Date()
        let thisMonth = calendar.dateInterval(of: .month, for: now)
        
        monthlyRevenue = transactions.filter { transaction in
            guard let monthInterval = thisMonth else { return false }
            return monthInterval.contains(transaction.createdDate)
        }.reduce(0) { $0 + $1.amount }
        
        print("💰 Total ingresos: $\(totalRevenue)")
        print("📅 Ingresos del mes: $\(monthlyRevenue)")
    }
    
    // MARK: - Obtener estadísticas por período
    func getRevenueBetween(startDate: Date, endDate: Date) -> Double {
        return transactions.filter { transaction in
            transaction.createdDate >= startDate && transaction.createdDate <= endDate
        }.reduce(0) { $0 + $1.amount }
    }
    
    // MARK: - Obtener transacciones por método de pago
    func getTransactionsByPaymentMethod() -> [String: Double] {
        var result: [String: Double] = [:]
        
        for transaction in transactions {
            result[transaction.paymentMethod, default: 0] += transaction.amount
        }
        
        return result
    }
}

// MARK: - Extensión de DateFormatter
extension DateFormatter {
    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM"
        return formatter
    }()
    
    static let fullDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy HH:mm"
        return formatter
    }()
}
