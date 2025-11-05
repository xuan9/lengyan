//
//  SettingsView.swift
//  Lengyan
//
//  Settings view for app configuration
//  <100 lines, clean SwiftUI
//

import SwiftUI

/// Settings view for app configuration
/// Theme, language, preferences
public struct SettingsView: View {
    @StateObject private var viewModel: SettingsViewModel

    public init(viewModel: SettingsViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        List {
            // Theme Settings
            Section("Appearance") {
                ForEach(Theme.allCases, id: \.self) { theme in
                    HStack {
                        Text(theme.displayName)
                        Spacer()
                        if viewModel.currentTheme == theme {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        viewModel.setTheme(theme)
                    }
                }
            }

            // Language Settings
            Section("Language") {
                HStack {
                    Text("Simplified Chinese")
                    Spacer()
                    Toggle("", isOn: $viewModel.isSimplifiedChinese)
                        .labelsHidden()
                }
            }

            // About
            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text(viewModel.appVersion)
                        .foregroundColor(.secondary)
                }

                Link("Privacy Policy", destination: URL(string: "https://example.com/privacy")!)
                    .foregroundColor(.accentColor)

                Link("Terms of Service", destination: URL(string: "https://example.com/terms")!)
                    .foregroundColor(.accentColor)
            }

            // Actions
            Section("Actions") {
                Button(action: {
                    viewModel.resetSettings()
                }) {
                    Text("Reset Settings")
                        .foregroundColor(.red)
                }
            }
        }
        .navigationTitle("Settings")
        .onAppear {
            viewModel.loadSettings()
        }
    }
}

// MARK: - Preview

#Preview {
    let viewModel = SettingsViewModel(
        preferencesRepository: PreferencesRepositoryImpl(),
        themeRepository: ThemeRepositoryImpl()
    )
    return NavigationStack {
        SettingsView(viewModel: viewModel)
    }
}
