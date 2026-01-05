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
            
            CameraView()
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
            VStack {
                Image(systemName: "house.fill")
                    .imageScale(.large)
                    .foregroundStyle(.tint)
                Text("Home")
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            .navigationTitle("Home")
        }
    }
}

#Preview {
    ContentView()
}
