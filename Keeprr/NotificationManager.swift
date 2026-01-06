//
//  NotificationManager.swift
//  Keeprr
//
//  Created by Cursor on 2026-01-06.
//

import Foundation
import UserNotifications

final class NotificationManager {
    static let shared = NotificationManager()
    private init() {}

    private let dailyPromptsEnabledKey = "daily_prompts_enabled_v1"
    private let dailyPromptStartMinuteKey = "daily_prompt_start_minute_v1"
    private let dailyPromptEndMinuteKey = "daily_prompt_end_minute_v1"
    private let dailyPromptCountKey = "daily_prompt_count_v1"

    // Legacy repeating request id (same time every day). We remove this when upgrading.
    private let legacyDailyPromptRequestId = "daily_photo_prompt_v1"

    // Legacy: one notification per calendar day, scheduled ahead with a random time per day.
    private let legacyDailyPromptIdPrefixV2 = "daily_photo_prompt_v2_"

    // New: N notifications per calendar day, scheduled ahead with random times per day.
    private let dailyPromptIdPrefixV3 = "daily_photo_prompt_v3_"
    private let rollingDaysToSchedule = 14
    private let defaultStartMinute = 9 * 60     // 9:00am
    private let defaultEndMinute = 22 * 60      // 10:00pm
    private let defaultCountPerDay = 1
    private let maxCountPerDay = 5

    struct ScheduledNotification: Identifiable {
        let id: String
        let fireDate: Date
        let title: String
    }

    /// Call on app launch to request permissions once and ensure the daily prompt is scheduled.
    func startDailyPromptFlow() {
        guard isDailyPromptsEnabled else { return }
        requestAuthorizationIfNeeded { [weak self] granted in
            guard granted else { return }
            self?.ensureDailyPromptsScheduled()
        }
    }

    var isDailyPromptsEnabled: Bool {
        // Default ON unless the user explicitly disables it.
        if UserDefaults.standard.object(forKey: dailyPromptsEnabledKey) == nil { return true }
        return UserDefaults.standard.bool(forKey: dailyPromptsEnabledKey)
    }

    func setDailyPromptsEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: dailyPromptsEnabledKey)
        if enabled {
            rescheduleDailyPrompts()
        } else {
            cancelDailyPrompts()
        }
    }

    func getDailyPromptWindowMinutes() -> (startMinute: Int, endMinute: Int) {
        let start = UserDefaults.standard.object(forKey: dailyPromptStartMinuteKey) as? Int ?? defaultStartMinute
        let end = UserDefaults.standard.object(forKey: dailyPromptEndMinuteKey) as? Int ?? defaultEndMinute
        return sanitizeWindow(startMinute: start, endMinute: end)
    }

    func setDailyPromptWindowMinutes(startMinute: Int, endMinute: Int) {
        let sanitized = sanitizeWindow(startMinute: startMinute, endMinute: endMinute)
        UserDefaults.standard.set(sanitized.startMinute, forKey: dailyPromptStartMinuteKey)
        UserDefaults.standard.set(sanitized.endMinute, forKey: dailyPromptEndMinuteKey)
        rescheduleDailyPrompts()
    }

    func getDailyPromptCountPerDay() -> Int {
        let raw = UserDefaults.standard.object(forKey: dailyPromptCountKey) as? Int ?? defaultCountPerDay
        return sanitizeCount(raw)
    }

    func setDailyPromptCountPerDay(_ count: Int) {
        UserDefaults.standard.set(sanitizeCount(count), forKey: dailyPromptCountKey)
        rescheduleDailyPrompts()
    }

    func rescheduleDailyPrompts() {
        guard isDailyPromptsEnabled else { return }
        cancelDailyPrompts()
        startDailyPromptFlow()
    }

    func scheduleTestPrompt(inSeconds seconds: TimeInterval = 60) {
        requestAuthorizationIfNeeded { granted in
            guard granted else { return }
            self.scheduleOneOffPrompt(inSeconds: seconds)
        }
    }

    func fetchUpcomingDailySchedule(days: Int = 14, completion: @escaping ([ScheduledNotification]) -> Void) {
        let center = UNUserNotificationCenter.current()
        let calendar = Calendar.current
        let now = Date()
        let endDate = calendar.date(byAdding: .day, value: max(1, days), to: now) ?? now.addingTimeInterval(14 * 24 * 60 * 60)

        center.getPendingNotificationRequests { [weak self] requests in
            guard let self else {
                DispatchQueue.main.async { completion([]) }
                return
            }

            let scheduled: [ScheduledNotification] = requests.compactMap { req -> ScheduledNotification? in
                let id = req.identifier
                // Include both v3 and legacy v2 ids for debugging visibility.
                guard id.hasPrefix(self.dailyPromptIdPrefixV3) || id.hasPrefix(self.legacyDailyPromptIdPrefixV2) else { return nil }
                guard let trigger = req.trigger as? UNCalendarNotificationTrigger else { return nil }
                guard let nextDate = trigger.nextTriggerDate() else { return nil }
                guard nextDate >= now, nextDate <= endDate else { return nil }
                return ScheduledNotification(id: id, fireDate: nextDate, title: req.content.title)
            }
            .sorted { $0.fireDate < $1.fireDate }

            DispatchQueue.main.async {
                completion(scheduled)
            }
        }
    }

    private func requestAuthorizationIfNeeded(completion: @escaping (Bool) -> Void) {
        let center = UNUserNotificationCenter.current()

        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                completion(true)
            case .denied:
                completion(false)
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                    completion(granted)
                }
            @unknown default:
                completion(false)
            }
        }
    }

    private func ensureDailyPromptsScheduled() {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { [weak self] requests in
            guard let self else { return }

            // Cleanup legacy repeating request (if present).
            if requests.contains(where: { $0.identifier == self.legacyDailyPromptRequestId }) {
                center.removePendingNotificationRequests(withIdentifiers: [self.legacyDailyPromptRequestId])
            }

            let existingDailyIds = Set(
                requests
                    .map(\.identifier)
                    .filter { $0.hasPrefix(self.legacyDailyPromptIdPrefixV2) || $0.hasPrefix(self.dailyPromptIdPrefixV3) }
            )

            self.scheduleMissingDailyPrompts(existingIds: existingDailyIds)
        }
    }

    private func cancelDailyPrompts() {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { [weak self] requests in
            guard let self else { return }
            let idsToRemove = requests
                .map(\.identifier)
                .filter {
                    $0 == self.legacyDailyPromptRequestId
                    || $0.hasPrefix(self.legacyDailyPromptIdPrefixV2)
                    || $0.hasPrefix(self.dailyPromptIdPrefixV3)
                }

            guard !idsToRemove.isEmpty else { return }
            center.removePendingNotificationRequests(withIdentifiers: idsToRemove)
            center.removeDeliveredNotifications(withIdentifiers: idsToRemove)
        }
    }

    private func scheduleMissingDailyPrompts(existingIds: Set<String>) {
        let center = UNUserNotificationCenter.current()
        let calendar = Calendar.current
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)
        let window = getDailyPromptWindowMinutes()
        let countPerDay = getDailyPromptCountPerDay()

        for dayOffset in 0..<rollingDaysToSchedule {
            guard let dayStart = calendar.date(byAdding: .day, value: dayOffset, to: todayStart) else { continue }

            // Pick a random minute within the allowed window.
            // For "today", don't schedule in the past.
            let windowStartMinute = window.startMinute
            let windowEndMinuteInclusive = window.endMinute

            var effectiveStartMinute = windowStartMinute
            if calendar.isDate(dayStart, inSameDayAs: now) {
                let currentMinuteOfDay = (calendar.component(.hour, from: now) * 60) + calendar.component(.minute, from: now)
                effectiveStartMinute = max(windowStartMinute, currentMinuteOfDay + 1)
            }

            // If we're past today's window, skip scheduling "today".
            guard effectiveStartMinute <= windowEndMinuteInclusive else { continue }

            let windowSize = windowEndMinuteInclusive - effectiveStartMinute + 1
            let effectiveCount = min(countPerDay, max(1, min(maxCountPerDay, windowSize)))

            let minutesForDay = pickUniqueMinutes(
                count: effectiveCount,
                startInclusive: effectiveStartMinute,
                endInclusive: windowEndMinuteInclusive
            )

            for (index, minuteOfDay) in minutesForDay.enumerated() {
                let id = dailyPromptIdPrefixV3 + dayId(for: dayStart) + "_\(index)"
                guard !existingIds.contains(id) else { continue }

                let hour = minuteOfDay / 60
                let minute = minuteOfDay % 60

                var dateComponents = calendar.dateComponents([.year, .month, .day], from: dayStart)
                dateComponents.hour = hour
                dateComponents.minute = minute

                let content = UNMutableNotificationContent()
                content.title = "Take a Keeprr moment"
                content.body = "Open the camera and capture today’s moment."
                content.sound = .default
                content.userInfo = ["deeplink": "camera"]

                let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
                let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
                center.add(request, withCompletionHandler: nil)
            }
        }
    }

    private func dayId(for date: Date) -> String {
        // Stable "yyyyMMdd" day key for request identifiers.
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyyMMdd"
        return formatter.string(from: date)
    }

    private func sanitizeWindow(startMinute: Int, endMinute: Int) -> (startMinute: Int, endMinute: Int) {
        // Clamp to [0, 1439] and ensure end >= start.
        let s = min(max(startMinute, 0), 1439)
        let e = min(max(endMinute, 0), 1439)
        if e < s {
            return (startMinute: e, endMinute: s)
        }
        return (startMinute: s, endMinute: e)
    }

    private func sanitizeCount(_ count: Int) -> Int {
        // Clamp to [1, maxCountPerDay]
        min(max(count, 1), maxCountPerDay)
    }

    private func pickUniqueMinutes(count: Int, startInclusive: Int, endInclusive: Int) -> [Int] {
        let size = max(0, endInclusive - startInclusive + 1)
        guard size > 0, count > 0 else { return [] }
        if count >= size {
            return Array(startInclusive...endInclusive)
        }

        var chosen = Set<Int>()
        chosen.reserveCapacity(count)

        // Sample without replacement (simple loop is fine for small counts).
        var attempts = 0
        let maxAttempts = count * 20
        while chosen.count < count && attempts < maxAttempts {
            chosen.insert(Int.random(in: startInclusive...endInclusive))
            attempts += 1
        }

        // Fallback: fill deterministically if random sampling didn’t converge (tiny windows).
        if chosen.count < count {
            for m in startInclusive...endInclusive where chosen.count < count {
                chosen.insert(m)
            }
        }

        return chosen.sorted()
    }

    /// Legacy: previously used repeating trigger. Left here intentionally unused.
    private func scheduleDailyPromptLegacyRepeating() {
        let center = UNUserNotificationCenter.current()

        // Choose a random time between 09:00 and 21:59 (inclusive).
        let hour = Int.random(in: 9...21)
        let minute = Int.random(in: 0...59)

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let content = UNMutableNotificationContent()
        content.title = "Take a Keeprr moment"
        content.body = "Open the camera and capture today’s moment."
        content.sound = .default
        content.userInfo = ["deeplink": "camera"]

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: legacyDailyPromptRequestId, content: content, trigger: trigger)

        center.add(request, withCompletionHandler: nil)
    }

    private func scheduleOneOffPrompt(inSeconds seconds: TimeInterval) {
        let center = UNUserNotificationCenter.current()

        let content = UNMutableNotificationContent()
        content.title = "Test: Take a Keeprr moment"
        content.body = "This is a test notification. Tap to open the camera."
        content.sound = .default
        content.userInfo = ["deeplink": "camera"]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, seconds), repeats: false)
        let request = UNNotificationRequest(
            identifier: "test_photo_prompt_\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )

        center.add(request, withCompletionHandler: nil)
    }
}


