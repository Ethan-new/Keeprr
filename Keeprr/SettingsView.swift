//
//  SettingsView.swift
//  Keeprr
//
//  Created by Cursor on 2026-01-06.
//

import SwiftUI
import UserNotifications

enum AppAppearance: Int, CaseIterable, Identifiable {
    case system = 0
    case light = 1
    case dark = 2
    
    var id: Int { rawValue }
    
    var title: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
    
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

struct SettingsView: View {
    // Default OFF so we only prompt for notifications after an explicit user action.
    @AppStorage("daily_prompts_enabled_v1") private var dailyPromptsEnabled: Bool = false
    @AppStorage("daily_prompt_start_minute_v1") private var dailyPromptStartMinute: Int = 9 * 60
    @AppStorage("daily_prompt_end_minute_v1") private var dailyPromptEndMinute: Int = 22 * 60
    @AppStorage("daily_prompt_count_v1") private var dailyPromptCountPerDay: Int = 1
    @AppStorage("front_camera_save_mode_v1") private var frontCameraSaveMode: Int = 0
    @AppStorage("app_appearance_v1") private var appAppearanceRaw: Int = AppAppearance.system.rawValue
    
    @State private var upcoming: [NotificationManager.ScheduledNotification] = []
    @State private var isLoadingSchedule = false
    
    // Debug
    @ObservedObject private var momentStore = MomentStore.shared
    @State private var momentsExpanded = false

    private func dateForMinuteOfDay(_ minute: Int) -> Date {
        let clamped = min(max(minute, 0), 1439)
        let hour = clamped / 60
        let minPart = clamped % 60
        return Calendar.current.date(bySettingHour: hour, minute: minPart, second: 0, of: Date()) ?? Date()
    }

    private func minuteOfDay(from date: Date) -> Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    var body: some View {
        List {
            Section("Appearance") {
                Picker("Theme", selection: $appAppearanceRaw) {
                    ForEach(AppAppearance.allCases) { option in
                        Text(option.title).tag(option.rawValue)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            Section("Notifications") {
                Toggle("Daily photo reminders", isOn: $dailyPromptsEnabled)
                    .onChange(of: dailyPromptsEnabled) { _, newValue in
                        NotificationManager.shared.setDailyPromptsEnabled(newValue)
                    }

                Stepper(value: $dailyPromptCountPerDay, in: 1...5) {
                    Text("Reminders per day: \(dailyPromptCountPerDay)")
                }
                .onChange(of: dailyPromptCountPerDay) { _, newValue in
                    NotificationManager.shared.setDailyPromptCountPerDay(newValue)
                }
                
                DatePicker(
                    "Earliest time",
                    selection: Binding(
                        get: { dateForMinuteOfDay(dailyPromptStartMinute) },
                        set: { newDate in
                            let newStart = minuteOfDay(from: newDate)
                            dailyPromptStartMinute = newStart
                            NotificationManager.shared.setDailyPromptWindowMinutes(
                                startMinute: dailyPromptStartMinute,
                                endMinute: dailyPromptEndMinute
                            )
                        }
                    ),
                    displayedComponents: .hourAndMinute
                )
                
                DatePicker(
                    "Latest time",
                    selection: Binding(
                        get: { dateForMinuteOfDay(dailyPromptEndMinute) },
                        set: { newDate in
                            let newEnd = minuteOfDay(from: newDate)
                            dailyPromptEndMinute = newEnd
                            NotificationManager.shared.setDailyPromptWindowMinutes(
                                startMinute: dailyPromptStartMinute,
                                endMinute: dailyPromptEndMinute
                            )
                        }
                    ),
                    displayedComponents: .hourAndMinute
                )

                Text("Keeprr schedules \(dailyPromptCountPerDay) reminder(s) per day at different random times inside this window.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            Section("Camera") {
                Picker("Front camera save", selection: $frontCameraSaveMode) {
                    Text("Unmirrored").tag(0)
                    Text("Mirrored (as seen)").tag(1)
                }
                .pickerStyle(.segmented)

                Text("Controls how the front photo is saved to your library. Preview is still mirrored like the system camera.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            
            Section("Upcoming schedule (debug)") {
                Button {
                    refreshSchedule()
                } label: {
                    HStack {
                        Text("Refresh")
                        Spacer()
                        if isLoadingSchedule {
                            ProgressView()
                        }
                    }
                }
                
                if upcoming.isEmpty {
                    Text("No scheduled reminders found.")
                        .foregroundColor(.secondary)
                } else {
                    let grouped = Dictionary(grouping: upcoming) { item in
                        Calendar.current.startOfDay(for: item.fireDate)
                    }
                    let days = grouped.keys.sorted()
                    
                    ForEach(days, id: \.self) { day in
                        let items = (grouped[day] ?? []).sorted { $0.fireDate < $1.fireDate }
                        VStack(alignment: .leading, spacing: 8) {
                            Text(day.formatted(date: .abbreviated, time: .omitted))
                                .font(.headline)
                            
                            ForEach(items) { item in
                                HStack(alignment: .firstTextBaseline) {
                                    Text(item.fireDate.formatted(date: .omitted, time: .shortened))
                                        .font(.system(.body, design: .monospaced))
                                    
                                    Spacer()
                                    
                                    Text(item.id)
                                        .font(.system(.footnote, design: .monospaced))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            
            Section("Moments (debug)") {
                DisclosureGroup(isExpanded: $momentsExpanded) {
                    if momentStore.moments.isEmpty {
                        Text("No moments yet.")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(momentStore.moments) { moment in
                            VStack(alignment: .leading, spacing: 6) {
                                Text("id: \(moment.id)")
                                Text("createdAt: \(moment.createdAt.formatted(date: .long, time: .standard))")
                                Text("frontAssetId: \(moment.frontAssetId)")
                                Text("backAssetId: \(moment.backAssetId)")
                            }
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                            .padding(.vertical, 6)
                        }
                    }
                } label: {
                    Text("Show moments (\(momentStore.moments.count))")
                }
            }
        }
        .navigationTitle("Settings")
        .onAppear { refreshSchedule() }
    }
    
    private func refreshSchedule() {
        isLoadingSchedule = true
        NotificationManager.shared.fetchUpcomingDailySchedule(days: 14) { items in
            upcoming = items
            isLoadingSchedule = false
        }
    }
}

#Preview {
    NavigationView {
        SettingsView()
    }
}


