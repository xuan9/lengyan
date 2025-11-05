//
//  FavoritesView.swift
//  Lengyan
//
//  Favorites view for bookmarked sutras
//  <100 lines, clean SwiftUI
//

import SwiftUI

/// Favorites view for bookmarked sutras
public struct FavoritesView: View {
    @StateObject private var viewModel: FavoritesViewModel

    public init(viewModel: FavoritesViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        List {
            if viewModel.favorites.isEmpty {
                emptyState
            } else {
                ForEach(viewModel.favorites, id: \.path) { sutra in
                    favoritesRow(sutra: sutra)
                }
                .onDelete(perform: viewModel.removeFavorite)
            }
        }
        .navigationTitle("Favorites")
        .onAppear {
            viewModel.loadFavorites()
        }
        .toolbar {
            if !viewModel.favorites.isEmpty {
                Button(action: {
                    viewModel.clearAllFavorites()
                }) {
                    Text("Clear All")
                        .foregroundColor(.red)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "star")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No Favorites Yet")
                .font(.title2)
                .fontWeight(.medium)

            Text("Mark sutras as favorites while reading")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func favoritesRow(sutra: Sutra) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(sutra.name)
                .font(.headline)
                .foregroundColor(.primary)

            if let content = sutra.content {
                Text(content)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            }

            HStack {
                Text(sutra.path)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Button(action: {
                    viewModel.removeFavorite(sutra)
                }) {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.openSutra(sutra)
        }
    }
}

// MARK: - Preview

#Preview {
    let mockRepository = MockBookRepository(
        mockTree: [],
        mockSutras: [
            Sutra(path: "/A1/B1", name: "Favorite 1", type: .content, content: "Content 1"),
            Sutra(path: "/A2/B1", name: "Favorite 2", type: .content, content: "Content 2"),
        ]
    )
    let viewModel = FavoritesViewModel(
        repository: mockRepository,
        bookmarks: ["/A1/B1", "/A2/B1"]
    )
    return NavigationStack {
        FavoritesView(viewModel: viewModel)
    }
}
