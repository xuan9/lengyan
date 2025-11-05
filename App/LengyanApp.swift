//
//  LengyanApp.swift
//  lengyan
//
//  Main app entry point
//  Uses coordinator pattern for navigation
//  <50 lines, clean, modern
//

import SwiftUI
import UIKit

@main
struct LengyanApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    // Configure app on launch
                    configureApp()
                }
        }
    }

    private func configureApp() {
        // Configure DI container
        DIContainer.shared.configure()

        // Load theme
        SutraThemeManager.shared.loadSavedTheme()
    }
}

// MARK: - Content View

struct ContentView: View {
    var body: some View {
        TabView {
            ReadingView()
                .tabItem {
                    Image(systemName: "book")
                    Text("阅读")
                }

            AudioView()
                .tabItem {
                    Image(systemName: "music.note.list")
                    Text("听经")
                }

            FavoritesView()
                .tabItem {
                    Image(systemName: "star")
                    Text("收藏")
                }
        }
        .tint(SutraThemeManager.shared.accentColor())
    }
}

// MARK: - View Models

struct ReadingView: View {
    var body: some View {
        let repository = DIContainer.shared.resolve(type: BookRepository.self)
        let viewModel = SutraIndexViewModel(repository: repository)

        return NavigationStack {
            SutraIndexView(viewModel: viewModel)
        }
    }
}

struct AudioView: View {
    var body: some View {
        let repository = DIContainer.shared.resolve(type: AudioRepository.self)
        let viewModel = AudioPlayerViewModel(repository: repository)

        return NavigationStack {
            AudioPlayerView(viewModel: viewModel)
        }
    }
}

struct FavoritesView: View {
    var body: some View {
        Text("Favorites (Coming Soon)")
            .font(.title)
            .navigationTitle("收藏")
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
