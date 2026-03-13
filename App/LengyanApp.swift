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
                    VStack(spacing: 2) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 20))
                        Text(NSLocalizedString("reading_tab_title", comment: ""))
                            .font(.caption)
                    }
                }

            AudioView()
                .tabItem {
                    VStack(spacing: 2) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 20))
                        Text(NSLocalizedString("media_tab_title", comment: ""))
                            .font(.caption)
                    }
                }

            FavoritesView()
                .tabItem {
                    VStack(spacing: 2) {
                        Image(systemName: "star")
                            .font(.system(size: 20))
                        Text(NSLocalizedString("star_tab_title", comment: ""))
                            .font(.caption)
                    }
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
            .navigationTitle(NSLocalizedString("star_tab_title", comment: ""))
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
