//
//  gymadministratorApp.swift
//  gymadministrator
//
//  Created by Ruben Camargo on 24/07/25.
//

import SwiftUI
import Firebase
import FirebaseCore
import FirebaseMessaging
import UserNotifications
import SwiftUI

@main
struct gymadministratorApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
