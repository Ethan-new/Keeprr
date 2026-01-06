//
//  ContentView.swift
//  Keeprr
//
//  Created by Ethan Um on 2026-01-04.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
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
            
            CameraView(selectedTab: $selectedTab)
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
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Moments (\(momentStore.moments.count))")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .padding(.bottom, 4)
                    
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
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.secondary.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                    
                    Spacer(minLength: 24)
                }
                .padding()
            }
            .navigationTitle("Home")
        }
    }
}

#Preview {
    ContentView()
}
