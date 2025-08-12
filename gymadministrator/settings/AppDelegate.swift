//
//  AppDelegate.swift
//  gymadministrator
//
//  Created by Ruben Camargo on 9/08/25.
//

import Firebase
import FirebaseCore
import FirebaseMessaging
import FirebaseFirestore
import FirebaseAuth
import UserNotifications
import SwiftUI
import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {
    let gcmMessageIDKey = "gcm.message_id"
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
        print("🚀 === APPDELEGATE EJECUTÁNDOSE ===")
        
        // Configure Firebase first
        FirebaseApp.configure()
        print("✅ Firebase configurado exitosamente")
        
        PaymentReminderManager.initializeOnAppStart()
        
        // Setup auth listener
        setupAuthListener()
        
        // Request notification permissions
        if #available(iOS 10.0, *) {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                print("📱 Permisos de notificación: \(granted ? "concedidos" : "denegados")")
                
                if let error = error {
                    print("❌ Error en permisos: \(error.localizedDescription)")
                }
                
                // Registrar para notificaciones remotas
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
            
            UNUserNotificationCenter.current().delegate = self
            Messaging.messaging().delegate = self
        }
        
        // Handle any pending notifications from launch
        if let notification = launchOptions?[.remoteNotification] as? [AnyHashable: Any] {
            print("📩 App launched from notification")
            Messaging.messaging().appDidReceiveMessage(notification)
        }
        
        return true
    }
    
    // MARK: - APNS Registration
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        print("📋 ✅ APNS device token recibido exitosamente")
        
        // Convert to string for logging
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        let token = tokenParts.joined()
        print("🔑 APNS Token: \(token)")
        
        // Set the APNS token in Firebase Messaging
        Messaging.messaging().apnsToken = deviceToken
        print("✅ APNS token asignado a Firebase Messaging")
        
        // Wait a moment then get FCM token
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            Messaging.messaging().token { fcmToken, error in
                if let error = error {
                    print("❌ Error obteniendo FCM token después de APNS: \(error)")
                } else if let fcmToken = fcmToken {
                    print("🔥 ✅ FCM Token verificado después de APNS: \(fcmToken)")
                    self.sendTokenToFirestore(fcmToken: fcmToken)
                }
            }
        }
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("❌ Error registrando para notificaciones remotas: \(error.localizedDescription)")
        
        // Try to get FCM token anyway for development
        Messaging.messaging().token { fcmToken, error in
            if let fcmToken = fcmToken {
                print("⚠️ FCM Token obtenido sin APNS: \(fcmToken)")
                self.sendTokenToFirestore(fcmToken: fcmToken)
            }
        }
    }
    
    // MARK: - Notification Handling
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                               willPresent notification: UNNotification,
                               withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        
        let userInfo = notification.request.content.userInfo
        print("📱 ✅ Notificación recibida en foreground")
        
        // Tell FCM about the message
        Messaging.messaging().appDidReceiveMessage(userInfo)
        
        if let messageID = userInfo[gcmMessageIDKey] {
            print("🆔 Message ID: \(messageID)")
        }
        
        // NUEVO: Extraer información de la notificación
        let title = notification.request.content.title
        let body = notification.request.content.body
        
        // Enviar notificación al sistema interno
        sendNotificationToApp(title: title, body: body, userInfo: userInfo)
        
        // Show notification even when app is in foreground
        completionHandler([.banner, .badge, .sound])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                               didReceive response: UNNotificationResponse) async {
        
        let userInfo = response.notification.request.content.userInfo
        let title = response.notification.request.content.title
        let body = response.notification.request.content.body
        
        print("👆 ✅ Notificación tocada")
        
        // Tell FCM about the message
        Messaging.messaging().appDidReceiveMessage(userInfo)
        
        if let messageID = userInfo[gcmMessageIDKey] {
            print("🆔 Message ID: \(messageID)")
        }
        
        // NUEVO: Enviar notificación al sistema interno cuando se toca
        sendNotificationToApp(title: title, body: body, userInfo: userInfo)
        
        print("📄 Contenido: \(userInfo)")
    }
    
    // MARK: - MessagingDelegate
    @objc func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("🔄 FCM Token actualizado")
        
        guard let fcmToken = fcmToken else {
            print("❌ FCM Token es nil")
            return
        }
        
        print("🔥 Nuevo FCM Token: \(fcmToken)")
        
        // Save to Firestore
        sendTokenToFirestore(fcmToken: fcmToken)
        
        // Store locally
        UserDefaults.standard.set(fcmToken, forKey: "FCMToken")
        
        // Post notification for other parts of app
        NotificationCenter.default.post(name: Notification.Name("FCMToken"),
                                      object: nil,
                                      userInfo: ["token": fcmToken])
    }
    
    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        
        print("📩 ✅ Notificación recibida en background/foreground")
        
        // Tell FCM about the message
        Messaging.messaging().appDidReceiveMessage(userInfo)
        
        if let messageID = userInfo[gcmMessageIDKey] {
            print("🆔 Message ID: \(messageID)")
        }
        
        // CORREGIDO: Extraer información de la notificación con casting correcto
        var title = "Nueva notificación"
        var body = ""
        
        // Intentar extraer de la estructura APS (notificaciones normales)
        if let aps = userInfo["aps"] as? [String: Any] {
            if let alert = aps["alert"] as? [String: Any] {
                title = alert["title"] as? String ?? title
                body = alert["body"] as? String ?? body
            } else if let alertString = aps["alert"] as? String {
                // Algunas veces alert es solo un string
                body = alertString
            }
        }
        
        // Si no encontramos en APS, intentar en notification (estructura de FCM)
        if title == "Nueva notificación" {
            if let notification = userInfo["notification"] as? [String: Any] {
                title = notification["title"] as? String ?? title
                body = notification["body"] as? String ?? body
            }
        }
        
        // También intentar directamente en el userInfo
        if title == "Nueva notificación" {
            title = userInfo["title"] as? String ?? title
            body = userInfo["body"] as? String ?? body
        }
        
        print("📧 Título extraído: \(title)")
        print("📝 Cuerpo extraído: \(body)")
        
        // Enviar notificación al sistema interno
        sendNotificationToApp(title: title, body: body, userInfo: userInfo)
        
        print("📄 Contenido completo: \(userInfo)")
        
        completionHandler(.newData)
    }

    // TAMBIÉN CORRIGE LA FUNCIÓN sendNotificationToApp para mejor extracción de datos:
    private func sendNotificationToApp(title: String, body: String, userInfo: [AnyHashable: Any]) {
        
        // Extraer datos adicionales con mejor manejo
        var data: [String: String] = [:]
        
        // Método 1: Intentar obtener datos personalizados de FCM
        if let fcmData = userInfo["data"] as? [String: Any] {
            for (key, value) in fcmData {
                data[key] = "\(value)" // Convertir cualquier tipo a string
            }
        }
        
        // Método 2: Intentar obtener datos personalizados generales
        if let customData = userInfo["custom"] as? [String: Any] {
            for (key, value) in customData {
                data[key] = "\(value)"
            }
        }
        
        // Método 3: Extraer campos comunes directamente del userInfo
        let commonFields = ["type", "category", "action", "classId", "userId", "excuseId"]
        for field in commonFields {
            if let value = userInfo[field] {
                data[field] = "\(value)"
            }
        }
        
        // Método 4: Si no tenemos datos específicos, convertir algunos campos básicos
        if data.isEmpty {
            for (key, value) in userInfo {
                if let stringKey = key as? String {
                    // Solo agregar campos que no sean estructuras complejas
                    switch value {
                    case is String, is Int, is Double, is Bool:
                        data[stringKey] = "\(value)"
                    default:
                        break // Ignorar estructuras complejas como APS, etc.
                    }
                }
            }
        }
        
        print("🔍 Datos extraídos: \(data)")
        
        // Crear diccionario con toda la información
        let notificationInfo: [String: Any] = [
            "title": title,
            "body": body,
            "data": data,
            "timestamp": Date().timeIntervalSince1970,
            "rawUserInfo": userInfo // Incluir datos originales para debugging
        ]
        
        // Enviar notificación al sistema interno
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: Notification.Name("PushNotificationReceived"),
                object: nil,
                userInfo: notificationInfo
            )
            
            print("📤 Notificación enviada al sistema interno: \(title)")
        }
    }

    // MARK: - NUEVA FUNCIÓN: Enviar notificación al sistema interno
    
    // MARK: - Firestore Token Management
    private func sendTokenToFirestore(fcmToken: String) {
        print("📤 Guardando token FCM en Firestore: \(fcmToken)")
        
        let db = Firestore.firestore()
        
        // Get device information
        let deviceModel = UIDevice.current.model
        let systemVersion = UIDevice.current.systemVersion
        let deviceName = UIDevice.current.name
        let timestamp = Timestamp()
        
        // Create device data
        let deviceData: [String: Any] = [
            "fcmToken": fcmToken,
            "deviceModel": deviceModel,
            "systemVersion": systemVersion,
            "deviceName": deviceName,
            "platform": "iOS",
            "lastUpdated": timestamp,
            "isActive": true
        ]
        
        // Save by authenticated user if available
        if let currentUser = Auth.auth().currentUser {
            let userId = currentUser.uid
            
            let docRef = db.collection("users").document(userId)
                          .collection("devices").document(fcmToken)
            
            docRef.setData(deviceData, merge: true) { error in
                if let error = error {
                    print("❌ Error guardando token en Firestore: \(error.localizedDescription)")
                } else {
                    print("✅ Token FCM guardado exitosamente para usuario: \(userId)")
                    // Clean up inactive tokens
                    self.cleanupInactiveTokens(userId: userId)
                }
            }
            
        } else {
            // Save in general collection if no user authenticated
            print("⚠️ Usuario no autenticado, guardando token en colección general")
            
            let docRef = db.collection("device_tokens").document(fcmToken)
            
            docRef.setData(deviceData, merge: true) { error in
                if let error = error {
                    print("❌ Error guardando token en colección general: \(error.localizedDescription)")
                } else {
                    print("✅ Token FCM guardado exitosamente en colección general")
                    UserDefaults.standard.set(fcmToken, forKey: "PendingFCMToken")
                }
            }
        }
    }
    
    // MARK: - Auth Management
    private func setupAuthListener() {
        Auth.auth().addStateDidChangeListener { auth, user in
            if let user = user {
                print("👤 Usuario autenticado: \(user.uid)")
                self.moveTokenToUserCollection(userId: user.uid)
            } else {
                print("👤 Usuario no autenticado")
            }
        }
    }
    
    private func moveTokenToUserCollection(userId: String) {
        guard let fcmToken = UserDefaults.standard.string(forKey: "FCMToken") else {
            print("⚠️ No hay token FCM para mover")
            return
        }
        
        let db = Firestore.firestore()
        
        // Check if token exists in general collection
        db.collection("device_tokens").document(fcmToken).getDocument { snapshot, error in
            guard let data = snapshot?.data() else { return }
            
            // Move to user collection
            let userDeviceRef = db.collection("users").document(userId)
                                 .collection("devices").document(fcmToken)
            
            userDeviceRef.setData(data, merge: true) { error in
                if error == nil {
                    print("✅ Token movido exitosamente a colección de usuario")
                    
                    // Delete from general collection
                    db.collection("device_tokens").document(fcmToken).delete()
                    UserDefaults.standard.removeObject(forKey: "PendingFCMToken")
                    
                    // Clean up inactive tokens
                    self.cleanupInactiveTokens(userId: userId)
                }
            }
        }
    }
    
    private func cleanupInactiveTokens(userId: String) {
        let db = Firestore.firestore()
        
        db.collection("users").document(userId).collection("devices")
          .whereField("isActive", isEqualTo: true)
          .getDocuments { snapshot, error in
            
            guard let documents = snapshot?.documents else { return }
            
            let batch = db.batch()
            
            for doc in documents {
                if let currentToken = UserDefaults.standard.string(forKey: "FCMToken"),
                   doc.documentID != currentToken {
                    batch.updateData(["isActive": false, "lastUpdated": Timestamp()],
                                    forDocument: doc.reference)
                }
            }
            
            batch.commit { error in
                if error == nil {
                    print("✅ Tokens inactivos limpiados")
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    func getUserDeviceTokens(userId: String, completion: @escaping ([String]) -> Void) {
        let db = Firestore.firestore()
        
        db.collection("users").document(userId).collection("devices")
          .whereField("isActive", isEqualTo: true)
          .getDocuments { snapshot, error in
            
            guard let documents = snapshot?.documents else {
                completion([])
                return
            }
            
            let tokens = documents.compactMap { doc in
                doc.data()["fcmToken"] as? String
            }
            
            completion(tokens)
        }
    }
}
