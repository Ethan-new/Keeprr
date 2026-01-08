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
    var body: some View {
        NavigationView {
            VStack(spacing: 12) {
                Image(systemName: "house.fill")
                    .imageScale(.large)
                    .foregroundStyle(.tint)
                Text("Home")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Open Settings to view debug info.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
}

#Preview {
    ContentView()
}
