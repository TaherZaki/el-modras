//
//  ContentView.swift
//  EL-Modras
//
//  Created by Taher on 04/09/1447 AH.
//

import SwiftUI
import Combine

struct ContentView: View {
    @StateObject private var dependencies = DependencyContainer.shared
    @StateObject private var appState = AppState()
    
    var body: some View {
        ZStack {
            if appState.isLoading {
                // Show splash screen while loading
                SplashScreenView()
                    .transition(.opacity)
            } else {
                // Main app content
                KidsHomeView(viewModel: dependencies.makeHomeViewModel())
                    .environment(\.dependencies, dependencies)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.5), value: appState.isLoading)
        .task {
            await appState.loadInitialData(using: dependencies)
        }
    }
}

// MARK: - App State
@MainActor
class AppState: ObservableObject {
    @Published var isLoading = true
    
    func loadInitialData(using dependencies: DependencyContainer) async {
        // Minimum splash duration for nice animation (2.5 seconds)
        let startTime = Date()
        let minimumDuration: TimeInterval = 2.5
        
        // Load data
        let homeViewModel = dependencies.makeHomeViewModel()
        await homeViewModel.loadData()
        
        // Calculate remaining wait time
        let elapsed = Date().timeIntervalSince(startTime)
        if elapsed < minimumDuration {
            let remaining = minimumDuration - elapsed
            try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
        }
        
        withAnimation {
            isLoading = false
        }
    }
}

#Preview {
    ContentView()
}
