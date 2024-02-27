//
//  IceTimeApp.swift
//  IceTime
//
//  Created by Lemine Mo El Agheb on 27.02.24.
//

import SwiftUI

@main
struct IBMApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        // Request notification permission
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("Notification permission granted")
            } else {
                print("Notification permission denied")
            }
        }

        // Other setup code...

        return true
    }
}
