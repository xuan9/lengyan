//
//  DIContainer.swift
//  Lengyan
//
//  Dependency Injection Container
//  Replaces singletons for testability and modularity
//

import Foundation

/// Dependency Injection Container
/// Provides dependency management for the entire app
public final class DIContainer {
    // MARK: - Shared Instance

    public static let shared = DIContainer()

    // MARK: - Private Storage

    private var factories: [String: Any] = [:]
    private var singletons: [String: Any] = [:]

    // MARK: - Registration

    /// Register a factory for a dependency
    /// - Parameters:
    ///   - type: The protocol type to register
    ///   - factory: Closure that creates the dependency
    public func register<T>(type: T.Type, factory: @escaping () -> T) {
        let key = String(describing: type)
        factories[key] = factory
    }

    /// Register a singleton
    /// - Parameters:
    ///   - type: The protocol type to register
    ///   - factory: Closure that creates the singleton
    public func registerSingleton<T>(type: T.Type, factory: @escaping () -> T) {
        let key = String(describing: type)
        singletons[key] = factory
    }

    // MARK: - Resolution

    /// Resolve a dependency
    /// - Parameter type: The type to resolve
    /// - Returns: Instance of the requested type
    public func resolve<T>(type: T.Type) -> T {
        let key = String(describing: type)

        // Check for singleton first
        if let singleton = singletons[key] as? () -> T {
            return singleton()
        }

        // Check for factory
        if let factory = factories[key] as? () -> T {
            return factory()
        }

        fatalError("Dependency not registered: \(type)")
    }

    /// Resolve an optional dependency
    /// - Parameter type: The type to resolve
    /// - Returns: Optional instance
    public func resolveOptional<T>(type: T.Type) -> T? {
        let key = String(describing: type)

        // Check for singleton first
        if let singleton = singletons[key] as? () -> T {
            return singleton()
        }

        // Check for factory
        if let factory = factories[key] as? () -> T {
            return factory()
        }

        return nil
    }

    // MARK: - Configuration

    /// Configure all app dependencies
    public func configure() {
        configureRepositories()
        configureServices()
        configureViewModels()
    }

    private func configureRepositories() {
        // Book Repository
        registerSingleton(type: BookRepository.self) {
            let cache = BookCache()
            let loader = BookLoader()
            return BookRepositoryImpl(loader: loader, cache: cache)
        }

        // Audio Repository
        registerSingleton(type: AudioRepository.self) {
            AudioRepositoryImpl()
        }

        // Preferences Repository
        registerSingleton(type: PreferencesRepository.self) {
            PreferencesRepositoryImpl()
        }

        // Theme Repository
        registerSingleton(type: ThemeRepository.self) {
            ThemeRepositoryImpl()
        }
    }

    private func configureServices() {
        // Pagination Service
        register(type: PaginationService.self) {
            // Will be provided with sutras when needed
            fatalError("PaginationService requires sutras parameter")
        }
    }

    private func configureViewModels() {
        // SutraIndexViewModel
        register(type: SutraIndexViewModel.self) {
            let repository = self.resolve(type: BookRepository.self)
            return SutraIndexViewModel(repository: repository)
        }

        // SutraReadingViewModel
        register(type: SutraReadingViewModel.self) { () -> SutraReadingViewModel in
            let repository = self.resolve(type: BookRepository.self)
            let initialPath = UserDefaults.standard.string(forKey: "LastReadPath") ?? "/A1/B1/C1"
            return SutraReadingViewModel(
                repository: repository,
                initialPath: initialPath
            )
        }

        // AudioPlayerViewModel
        register(type: AudioPlayerViewModel.self) {
            let repository = self.resolve(type: AudioRepository.self)
            return AudioPlayerViewModel(repository: repository)
        }
    }

    // MARK: - Reset

    /// Reset the container (for testing)
    public func reset() {
        factories.removeAll()
        singletons.removeAll()
        configure()
    }
}

// MARK: - Protocol Definitions

/// Audio Repository Protocol
public protocol AudioRepository {
    func playTrack(named: String)
    func pause()
    func resume()
    func stop()
    func getCurrentTrack() -> String?
    var isPlaying: Bool { get }
}

/// Preferences Repository Protocol
public protocol PreferencesRepository {
    var isSimplifiedChinese: Bool { get set }
    var readingProgress: [String: Double] { get set }
    var bookmarks: [String] { get set }
    func save()
}

/// Theme Repository Protocol
public protocol ThemeRepository {
    var currentTheme: String { get set }
    func toggleTheme()
}

// MARK: - Implementations

public final class AudioRepositoryImpl: AudioRepository {
    private var _isPlaying = false
    private var _currentTrack: String?

    public init() {}

    public func playTrack(named: String) {
        _currentTrack = named
        _isPlaying = true
    }

    public func pause() {
        _isPlaying = false
    }

    public func resume() {
        _isPlaying = true
    }

    public func stop() {
        _isPlaying = false
        _currentTrack = nil
    }

    public func getCurrentTrack() -> String? {
        return _currentTrack
    }

    public var isPlaying: Bool {
        return _isPlaying
    }
}

public final class PreferencesRepositoryImpl: PreferencesRepository {
    private let defaults = UserDefaults.standard

    public init() {}

    public var isSimplifiedChinese: Bool {
        get { defaults.bool(forKey: "isSimplifiedChinese") }
        set { defaults.set(newValue, forKey: "isSimplifiedChinese") }
    }

    public var readingProgress: [String: Double] {
        get {
            guard let data = defaults.data(forKey: "readingProgress"),
                  let dict = try? JSONDecoder().decode([String: Double].self, from: data) else {
                return [:]
            }
            return dict
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: "readingProgress")
            }
        }
    }

    public var bookmarks: [String] {
        get {
            guard let data = defaults.data(forKey: "bookmarks"),
                  let array = try? JSONDecoder().decode([String].self, from: data) else {
                return []
            }
            return array
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: "bookmarks")
            }
        }
    }

    public func save() {
        defaults.synchronize()
    }
}

public final class ThemeRepositoryImpl: ThemeRepository {
    private let defaults = UserDefaults.standard

    public init() {}

    public var currentTheme: String {
        get { defaults.string(forKey: "currentTheme") ?? "light" }
        set { defaults.set(newValue, forKey: "currentTheme") }
    }

    public func toggleTheme() {
        currentTheme = currentTheme == "light" ? "dark" : "light"
    }
}
