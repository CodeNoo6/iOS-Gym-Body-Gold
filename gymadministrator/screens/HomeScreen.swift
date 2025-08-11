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
    @StateObject private var userManager = AdminUserManager()
    @State private var isSendingTestNotification = false
    @State private var showingBroadcastSheet = false // ✅ Agregar esta variable
    
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
                    
                    Text("Gestiona usuarios y configuraciones del sistema")
                        .font(.subheadline)
                        .foregroundColor(.brandLight.opacity(0.7))
                }
                
                Spacer()
                
                // ✅ AGREGAR: Botón para mensaje masivo
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
                            colors: [Color.orange, Color.orange.opacity(0.8)],
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
        // ✅ AGREGAR: Sheet para mensaje masivo
        .sheet(isPresented: $showingBroadcastSheet) {
            BroadcastMessageSheet(userManager: userManager)
        }
    }
    
    private func sendTestNotification() async {
        isSendingTestNotification = true
        
        await userManager.sendTestNotificationToSpecificToken()
        
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        isSendingTestNotification = false
        
        print("📱 Notificación de prueba enviada al token específico")
    }
}

// MARK: - Admin Users List Card
struct AdminUsersListCard: View {
    @StateObject private var userManager = AdminUserManager()
    @State private var showingBroadcastSheet = false // ✅ Agregar esta variable
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("👥 Clientes")
                    .font(.headline)
                    .foregroundColor(.brandLight)
                
                Spacer()
            }
            
            if userManager.adminUsers.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "person.3.sequence.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.brandGold.opacity(0.5))
                    
                    Text("No hay clientes registrados")
                        .font(.subheadline)
                        .foregroundColor(.brandLight.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(userManager.adminUsers, id: \.uid) { user in
                        AdminUserRow(user: user)
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
            userManager.loadAdminUsers()
        }
        // ✅ AGREGAR: Sheet para mensaje masivo
        .sheet(isPresented: $showingBroadcastSheet) {
            BroadcastMessageSheet(userManager: userManager)
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
        
        // MARK: - Función de prueba con el token que proporcionaste
        func sendTestNotificationToSpecificToken() async {
            let testToken = "er6VssDxFU2pnu6YPaxuI1:APA91bFtO8-uOlawnrKp6MTPzVarysK_MeOvlvgoOmtxK2_uOjI1CIuhjatt9l7K5O6Vr5gl2-0VSUFb71d7qgscauTDqcjygqlu5CchGx6uiCxCporujRQ"
            
            // Crear payload de notificación
            let payload: [String: Any] = [
                "to": testToken,
                "notification": [
                    "title": "🏋️‍♂️ Gym Body Gold - Cuenta Desactivada",
                    "body": "Tu cuenta ha sido desactivada por el administrador. Contacta al gym para más información.",
                    "sound": "default",
                    "badge": 1
                ],
                "data": [
                    "type": "account_status",
                    "action": "deactivated",
                    "timestamp": "\(Date().timeIntervalSince1970)"
                ],
                "priority": "high"
            ]
            
            guard let url = URL(string: "https://fcm.googleapis.com/fcm/send") else { return }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            // IMPORTANTE: Reemplaza con tu Server Key de Firebase
            let serverKey = "AAAA8gZ9pQY:APA91bHsample-server-key-here" // Tu server key real
            request.setValue("key=\(serverKey)", forHTTPHeaderField: "Authorization")
            
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: payload)
                
                let (data, response) = try await URLSession.shared.data(for: request)
                
                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 200 {
                        print("✅ Notificación de prueba enviada exitosamente")
                        if let responseData = String(data: data, encoding: .utf8) {
                            print("📱 Respuesta FCM: \(responseData)")
                        }
                    } else {
                        print("❌ Error enviando notificación de prueba. Status: \(httpResponse.statusCode)")
                    }
                }
                
            } catch {
                print("❌ Error en request FCM de prueba: \(error.localizedDescription)")
            }
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


// MARK: - AdminDashboard con roles
struct AdminDashboard: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var dashboardManager = DashboardManager()
    @StateObject private var miembroManager = MiembroManager()
    @State private var showingMiembros = false
    @State private var showingProfileSheet = false
    
    var body: some View {
        let isIPad = UIDevice.current.userInterfaceIdiom == .pad
        
        // Verificar el rol del usuario
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
    
    // MARK: - iPad Admin Content
    private var iPadAdminContent: some View {
        GeometryReader { geometry in
            ZStack {
                Color.brandBlack.ignoresSafeArea(.all)
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Header para admin
                        AdminHeaderCard(authManager: authManager, dashboardManager: dashboardManager)
                        
                        // Lista de usuarios con rol administrador
                        AdminUsersListCard()
                        
                        // Chat IA (también disponible para admin)
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
            }
            .preferredColorScheme(.dark)
        }
    }
    
    // MARK: - iPhone Admin Content
    private var iPhoneAdminContent: some View {
        ZStack {
            Color.brandBlack.ignoresSafeArea(.all)
            
            ScrollView {
                VStack(spacing: 20) {
                    // Header para admin
                    AdminHeaderCard(authManager: authManager, dashboardManager: dashboardManager)
                    
                    // Lista de usuarios con rol administrador
                    AdminUsersListCard()
                    
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
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - iPad User Content (interfaz normal)
    private var iPadUserContent: some View {
        GeometryReader { geometry in
            ZStack {
                Color.brandBlack.ignoresSafeArea(.all)
                
                ScrollView {
                    VStack(spacing: 20) {
                        HeaderCard(authManager: authManager, dashboardManager: dashboardManager, miembroManager: miembroManager)
                        IAChatCard()
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
    
    // MARK: - iPhone User Content (interfaz normal)
    private var iPhoneUserContent: some View {
        ZStack {
            Color.brandBlack.ignoresSafeArea(.all)
            
            ScrollView {
                VStack(spacing: 20) {
                    HeaderCard(authManager: authManager, dashboardManager: dashboardManager, miembroManager: miembroManager)
                    IAChatCard()
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
    @State private var editableUser: UserData? // Copia para edición
    @State private var isEditing = false

    var body: some View {
        NavigationView {
            ZStack {
                Color.brandBlack.ignoresSafeArea()

                if let userData = editableUser {
                    ScrollView {
                        VStack(spacing: 20) {
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .frame(width: 100, height: 100)
                                .foregroundColor(.brandGold)

                            // Campos deshabilitados si no está en edición
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
                        .padding()
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
