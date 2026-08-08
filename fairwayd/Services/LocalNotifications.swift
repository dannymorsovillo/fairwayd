//
//  LocalNotifications.swift
//  fairwayd
//
//  Created by Danny Morsovillo on 8/7/26.
//

import SwiftUI
import UserNotifications

class NotificationManager {
    static let instance = NotificationManager()
    
    func requestAuth() {
        let options: UNAuthorizationOptions = [.alert, .sound, .badge]
        UNUserNotificationCenter.current().requestAuthorization(options: options) { success, error in
            if let error = error {
                print("Error: \(error)")
            } else {
                print("Success")
          }
        }
    }
    
    func scheduleNotfication() {
        let content = UNMutableNotificationContent()
        content.title = "first noti"
        content.subtitle = "sup"
        content.sound = .default
        content.badge = 1
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request)
    }
    
    
}

struct LocalNotifications: View {
    @Environment(\.scenePhase) var scenePhase
    
    var body: some View {
        VStack(spacing: 40) {
            Button("Request Permission") {
                NotificationManager.instance.requestAuth()
            }
            
            Button("Schedule noti") {
                NotificationManager.instance.scheduleNotfication()
            }
            
        }
        .onChange(of: scenePhase) {_, newPhase in
            if newPhase == .active {
                UNUserNotificationCenter.current().setBadgeCount(0)
            }
        }
    }
}

#Preview {
    LocalNotifications()
}
