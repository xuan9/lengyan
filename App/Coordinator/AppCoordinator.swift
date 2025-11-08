//
//  AppCoordinator.swift
//  Lengyan
//
//  Main app coordinator
//  Handles navigation flow and view controller creation
//

import SwiftUI
import UIKit

/// Coordinator protocol
/// All coordinators must implement start()
public protocol Coordinator {
    func start()
}

/// Main application coordinator
/// Manages the overall app navigation flow
public final class AppCoordinator: Coordinator {
    private let window: UIWindow
    private let navigationController: UINavigationController

    // Child coordinators
    private var sutraCoordinator: SutraCoordinator?
    private var audioCoordinator: AudioCoordinator?

    // MARK: - Initialization

    public init(window: UIWindow) {
        self.window = window
        self.navigationController = UINavigationController()
        setupNavigationController()
    }

    // MARK: - Coordinator Protocol

    public func start() {
        // Configure DI container
        DIContainer.shared.configure()

        // Create root view
        let sutraIndexVM = DIContainer.shared.resolve(type: SutraIndexViewModel.self)
        let sutraIndexView = SutraIndexView(viewModel: sutraIndexVM)
        let rootViewController = UIHostingController(rootView: sutraIndexView)

        // Set navigation controller as root
        window.rootViewController = navigationController
        navigationController.pushViewController(rootViewController, animated: false)

        // Configure appearance
        configureAppearance()
    }

    // MARK: - Private Methods

    private func setupNavigationController() {
        navigationController.navigationBar.prefersLargeTitles = true
        navigationController.hidesBarsOnSwipe = false
    }

    private func configureAppearance() {
        // Configure navigation bar appearance
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = SutraDesignTokens.shared.color(for: .background)
        appearance.titleTextAttributes = [.foregroundColor: SutraDesignTokens.shared.color(for: .textPrimary)]
        appearance.largeTitleTextAttributes = [.foregroundColor: SutraDesignTokens.shared.color(for: .textPrimary)]

        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
    }

    // MARK: - Navigation Methods

    /// Navigate to sutra reading view
    public func navigateToSutraReading(atPath path: String) {
        let repository = DIContainer.shared.resolve(type: BookRepository.self)
        let viewModel = SutraReadingViewModel(
            repository: repository,
            initialPath: path
        )
        let readingView = SutraReadingView(viewModel: viewModel)
        let viewController = UIHostingController(rootView: readingView)

        navigationController.pushViewController(viewController, animated: true)
    }

    /// Navigate to audio player
    public func navigateToAudioPlayer() {
        let repository = DIContainer.shared.resolve(type: AudioRepository.self)
        let viewModel = AudioPlayerViewModel(repository: repository)
        let audioView = AudioPlayerView(viewModel: viewModel)
        let viewController = UIHostingController(rootView: audioView)

        navigationController.pushViewController(viewController, animated: true)
    }

    /// Navigate back to previous screen
    public func navigateBack() {
        navigationController.popViewController(animated: true)
    }

    /// Navigate to root view
    public func navigateToRoot() {
        navigationController.popToRootViewController(animated: true)
    }
}

/// Sutra-specific coordinator
/// Manages sutra navigation flow
public final class SutraCoordinator: Coordinator {
    private let parent: AppCoordinator
    private let navigationController: UINavigationController

    public init(parent: AppCoordinator, navigationController: UINavigationController) {
        self.parent = parent
        self.navigationController = navigationController
    }

    public func start() {
        // Start with sutra index view
        let repository = DIContainer.shared.resolve(type: BookRepository.self)
        let viewModel = SutraIndexViewModel(repository: repository)
        let sutraIndexView = SutraIndexView(viewModel: viewModel)
        let viewController = UIHostingController(rootView: sutraIndexView)

        navigationController.pushViewController(viewController, animated: false)
    }

    /// Navigate to sutra reading view
    public func navigateToReading(atPath path: String) {
        let repository = DIContainer.shared.resolve(type: BookRepository.self)
        let viewModel = SutraReadingViewModel(
            repository: repository,
            initialPath: path
        )
        let readingView = SutraReadingView(viewModel: viewModel)
        let viewController = UIHostingController(rootView: readingView)

        navigationController.pushViewController(viewController, animated: true)
    }

    /// Navigate to favorites view
    public func navigateToFavorites() {
        let repository = DIContainer.shared.resolve(type: BookRepository.self)
        let preferencesRepository = DIContainer.shared.resolve(type: PreferencesRepository.self)
        let viewModel = FavoritesViewModel(
            repository: repository,
            preferencesRepository: preferencesRepository
        )
        let favoritesView = FavoritesView(viewModel: viewModel)
        let viewController = UIHostingController(rootView: favoritesView)

        navigationController.pushViewController(viewController, animated: true)
    }

    /// Navigate back in sutra flow
    public func navigateBack() {
        navigationController.popViewController(animated: true)
    }

    /// Navigate to root of sutra flow
    public func navigateToRoot() {
        navigationController.popToRootViewController(animated: true)
    }
}

/// Audio coordinator
/// Manages audio player flow
public final class AudioCoordinator: Coordinator {
    private let parent: AppCoordinator
    private let navigationController: UINavigationController

    public init(parent: AppCoordinator, navigationController: UINavigationController) {
        self.parent = parent
        self.navigationController = navigationController
    }

    public func start() {
        // Start with audio player view
        let repository = DIContainer.shared.resolve(type: AudioRepository.self)
        let viewModel = AudioPlayerViewModel(repository: repository)
        let audioView = AudioPlayerView(viewModel: viewModel)
        let viewController = UIHostingController(rootView: audioView)

        navigationController.pushViewController(viewController, animated: false)
    }

    /// Navigate to audio track list
    public func navigateToTrackList() {
        // For now, use the same audio player view
        // This can be expanded to show a list of tracks
        let repository = DIContainer.shared.resolve(type: AudioRepository.self)
        let viewModel = AudioPlayerViewModel(repository: repository)
        let audioView = AudioPlayerView(viewModel: viewModel)
        let viewController = UIHostingController(rootView: audioView)

        navigationController.pushViewController(viewController, animated: true)
    }

    /// Navigate to settings from audio flow
    public func navigateToSettings() {
        let preferencesRepository = DIContainer.shared.resolve(type: PreferencesRepository.self)
        let themeRepository = DIContainer.shared.resolve(type: ThemeRepository.self)
        let viewModel = SettingsViewModel(
            preferencesRepository: preferencesRepository,
            themeRepository: themeRepository
        )
        let settingsView = SettingsView(viewModel: viewModel)
        let viewController = UIHostingController(rootView: settingsView)

        navigationController.pushViewController(viewController, animated: true)
    }

    /// Navigate back in audio flow
    public func navigateBack() {
        navigationController.popViewController(animated: true)
    }

    /// Navigate to root of audio flow
    public func navigateToRoot() {
        navigationController.popToRootViewController(animated: true)
    }
}
