//
//  AppState.swift
//  Keeprr
//
//  Created by Cursor on 2026-01-06.
//

import Foundation
import SwiftUI

/// Shared app-wide state (used for deep-linking from notifications).
final class AppState: ObservableObject {
    static let shared = AppState()
    private init() {}

    /// Mirrors the `TabView` selection in `ContentView`.
    @Published var selectedTab: Int = 0
}


