//
//  KeeprrApp.swift
//  Keeprr
//
//  Created by Ethan Um on 2026-01-04.
//

import SwiftUI
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show the banner even if the app is open.
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        if (userInfo["deeplink"] as? String) == "camera" {
            if let dayId = userInfo["dayId"] as? String,
               let slot = userInfo["slot"] as? Int {
                NotificationManager.shared.markDailyPromptFired(dayId: dayId, slot: slot)
            }
            DispatchQueue.main.async {
                AppState.shared.selectedTab = 3
            }
        }
        completionHandler()
    }
}

@main
struct KeeprrApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @AppStorage("app_appearance_v1") private var appAppearanceRaw: Int = AppAppearance.system.rawValue

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme((AppAppearance(rawValue: appAppearanceRaw) ?? .system).colorScheme)
        }
    }
}
