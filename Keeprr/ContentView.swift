//
//  ContentView.swift
//  Keeprr
//
//  Created by Ethan Um on 2026-01-04.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject private var appState = AppState.shared
    
    var body: some View {
        TabView(selection: $appState.selectedTab) {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)
            
            AllPhotosView()
                .tabItem {
                    Label("All Photos", systemImage: "photo.stack.fill")
                }
                .tag(1)
            
            KeeprrMomentsView()
                .tabItem {
                    Label("Keeprr Moments", systemImage: "sparkles")
                }
                .tag(2)
            
            CameraView(selectedTab: $appState.selectedTab)
                .tabItem {
                    Label("Camera", systemImage: "camera.fill")
                }
                .tag(3)
        }
        .accentColor(.blue)
    }
}

// MARK: - Tab Views

struct HomeView: View {
    @ObservedObject private var momentStore = MomentStore.shared
    
    private var todayStart: Date {
        Calendar.current.startOfDay(for: Date())
    }
    
    private var daySet: Set<Date> {
        let cal = Calendar.current
        return Set(momentStore.moments.map { cal.startOfDay(for: $0.createdAt) })
    }
    
    /// Current streak counts consecutive days with at least one moment.
    /// If there is a moment today, streak is inclusive of today.
    /// Otherwise, if there is a moment yesterday, streak is inclusive of yesterday (and grows once you take one today).
    private var currentStreakDays: Int {
        let cal = Calendar.current
        let today = todayStart
        let yesterday = cal.date(byAdding: .day, value: -1, to: today)!
        
        let startDay: Date?
        if daySet.contains(today) {
            startDay = today
        } else if daySet.contains(yesterday) {
            startDay = yesterday
        } else {
            startDay = nil
        }
        
        guard var day = startDay else { return 0 }
        
        var count = 0
        while daySet.contains(day) {
            count += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return count
    }
    
    private var hasMomentToday: Bool {
        daySet.contains(todayStart)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    streakCard
                    totalMomentsCard
                    
                    Spacer(minLength: 12)
                }
                .padding()
            }
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                            .accessibilityLabel("Settings")
                    }
                }
            }
        }
    }
    
    private var streakCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.18))
                        .frame(width: 44, height: 44)
                    Image(systemName: "flame.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 20, weight: .semibold))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Photo streak")
                        .font(.headline)
                    Text("\(currentStreakDays) day\(currentStreakDays == 1 ? "" : "s")")
                        .font(.system(size: 28, weight: .bold))
                }
                
                Spacer()
            }
            
            if currentStreakDays == 0 {
                Text("Take a Keeprr moment today to start a streak.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else if hasMomentToday {
                Text("Nice — you’ve logged a moment today.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                Text("Take a moment today to extend your streak to \(currentStreakDays + 1).")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    private var totalMomentsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.18))
                        .frame(width: 44, height: 44)
                    Image(systemName: "sparkles")
                        .foregroundColor(.blue)
                        .font(.system(size: 20, weight: .semibold))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Total moments kept")
                        .font(.headline)
                    Text("\(momentStore.moments.count)")
                        .font(.system(size: 28, weight: .bold))
                }
                
                Spacer()
            }
            
            Text("Moments are created when you take both front and back photos.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

#Preview {
    ContentView()
}
