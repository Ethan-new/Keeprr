//
//  SettingsView.swift
//  Keeprr
//
//  Created by Cursor on 2026-01-06.
//

import SwiftUI
import UserNotifications

struct SettingsView: View {
    @AppStorage("daily_prompts_enabled_v1") private var dailyPromptsEnabled: Bool = true
    @AppStorage("daily_prompt_start_minute_v1") private var dailyPromptStartMinute: Int = 9 * 60
    @AppStorage("daily_prompt_end_minute_v1") private var dailyPromptEndMinute: Int = 22 * 60
    @AppStorage("daily_prompt_count_v1") private var dailyPromptCountPerDay: Int = 1
    
    @State private var upcoming: [NotificationManager.ScheduledNotification] = []
    @State private var isLoadingSchedule = false

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


