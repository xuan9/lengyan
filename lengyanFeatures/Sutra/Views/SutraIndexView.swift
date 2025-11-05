//
//  SutraIndexView.swift
//  Lengyan
//
//  SwiftUI view for sutra index navigation
//  <100 lines, declarative, testable
//

import SwiftUI

/// Main view for browsing sutra hierarchy
/// Clean, minimal SwiftUI implementation with design system
public struct SutraIndexView: View {
    @StateObject private var viewModel: SutraIndexViewModel
    @State private var searchText: String = ""
    @State private var showingSearch: Bool = false

    public init(viewModel: SutraIndexViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        NavigationStack(path: $viewModel.navigationPath) {
            Group {
                if viewModel.sutraTree.isEmpty && !viewModel.showingError {
                    VStack(spacing: SutraSpacing.md) {
                        ProgressView("Loading sutras...")
                            .progressViewStyle(CircularProgressViewStyle())
                        Text("Loading sutras...")
                            .font(ChineseFontManager.appropriateFont(size: GoldenRatioTypography.level1))
                            .sutraLineHeightGoldenRatio(1)
                            .sutraColor(.secondaryText)
                    }
                    .sutraColor(.primaryText)
                } else if viewModel.isSearching {
                    searchResultsView
                } else {
                    List {
                        ForEach(viewModel.sutraTree) { node in
                            SutraRowView(
                                sutra: node.sutra,
                                depth: 0,
                                onTap: {
                                    viewModel.selectSutra(node.sutra)
                                }
                            )
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                        }
                    }
                    .listStyle(.sidebar)
                    .scrollContentBackground(.hidden)
                    .background(Color.sutraBackground)
                }
            }
            .navigationTitle("楞严经")
            .navigationBarTitleDisplayMode(.large)
            .toolbarTitleDisplayMode(.large)
            .sutraTheme(theme)
            .sutraAccessibility(
                category: .navigation,
                label: "Sutra Index",
                hint: "Browse and select sutras to read"
            )
            .searchable(
                text: $searchText,
                isPresented: $showingSearch,
                prompt: "Search sutras..."
            )
            .onChange(of: searchText) { _, newValue in
                Task {
                    if !newValue.isEmpty {
                        await viewModel.searchSutras(query: newValue)
                    } else {
                        viewModel.clearSearch()
                    }
                }
            }
            .onSubmit(of: .search) {
                Task {
                    if !searchText.isEmpty {
                        await viewModel.searchSutras(query: searchText)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingSearch = true
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .font(ChineseFontManager.appropriateFont(size: GoldenRatioTypography.level1))
                    }
                    .sutraHaptic(.tap)
                    .sutraAccessibility(
                        category: .button,
                        label: "Search",
                        hint: "Search for sutras"
                    )
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Light Theme") {
                            viewModel.setTheme(.light)
                        }
                        Button("Sepia Theme") {
                            viewModel.setTheme(.sepia)
                        }
                        Button("Dark Theme") {
                            viewModel.setTheme(.dark)
                        }
                    } label: {
                        Image(systemName: "paintbrush")
                            .font(ChineseFontManager.appropriateFont(size: GoldenRatioTypography.level1))
                    }
                    .sutraHaptic(.tap)
                    .sutraAccessibility(
                        category: .navigation,
                        label: "Theme Settings",
                        hint: "Change app theme"
                    )
                }
            }
            .onAppear {
                Task {
                    await viewModel.loadSutraTree()
                }
            }
            .alert("Error", isPresented: $viewModel.showingError) {
                Button("OK") { }
            } message: {
                Text(viewModel.errorMessage ?? "Unknown error")
            }
            .background(Color.sutraBackground)
        }
    }

    private var searchResultsView: some View {
        List {
            if viewModel.searchResults.isEmpty {
                emptySearchState
            } else {
                ForEach(viewModel.searchResults, id: \.path) { sutra in
                    SutraRowView(
                        sutra: sutra,
                        depth: 0,
                        onTap: {
                            viewModel.selectSutra(sutra)
                        }
                    )
                }
            }
        }
        .listStyle(.plain)
    }

    private var emptySearchState: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No Results Found")
                .font(.title2)
                .fontWeight(.medium)

            Text("Try a different search term")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Sutra Row View

struct SutraRowView: View {
    let sutra: Sutra
    let depth: Int
    let onTap: () -> Void

    @State private var isPressed = false

    var body: some View {
        HStack(spacing: SutraSpacing.md) {
            if depth > 0 {
                Spacer()
                    .frame(width: CGFloat(depth) * SutraSpacing.componentSm)
            }

            VStack(alignment: .leading, spacing: SutraSpacing.xs) {
                Text(sutra.name)
                    .font(ChineseFontManager.appropriateFont(size: GoldenRatioTypography.level2))
                    .sutraLineHeightGoldenRatio(2)
                    .sutraColor(.primaryText)

                if sutra.hasChildren {
                    Text("展开")
                        .font(ChineseFontManager.appropriateFont(size: GoldenRatioTypography.level0))
                        .sutraLineHeightGoldenRatio(0)
                        .sutraColor(.secondaryText)
                }
            }
            .sutraPadding(.vertical, SutraSpacing.buttonPadding / 2)

            Spacer()

            if sutra.hasContent {
                Image(systemName: "chevron.right")
                    .font(ChineseFontManager.appropriateFont(size: GoldenRatioTypography.level0))
                    .sutraColor(.secondaryText)
            }
        }
        .sutraPadding(.horizontal, SutraSpacing.marginStandard)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.clear)
                .opacity(isPressed ? 0.1 : 0)
        )
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .sutraEaseInOutAnimation()
        .contentShape(Rectangle())
        .onTapGesture {
            isPressed = true
            onTap()

            // Provide haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()

            // Release after brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isPressed = false
            }
        }
        .sutraLongPress(minimumDuration: 0.5) {
            isPressed = true
            let hapticFeedback = UISelectionFeedbackGenerator()
            hapticFeedback.selectionChanged()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isPressed = false
            }
        }
        .sutraAccessibility(
            category: sutra.hasContent ? .sutraText : .navigation,
            label: sutra.name,
            hint: sutra.hasContent ? "Tap to read" : "Tap to expand"
        )
        .accessibilityAction(named: Text("Read")) {
            onTap()
        }
    }
}

// MARK: - Preview

#Preview {
    let mockRepository = MockBookRepository(
        mockTree: [],
        mockSutras: []
    )
    let viewModel = SutraIndexViewModel(repository: mockRepository)
    return SutraIndexView(viewModel: viewModel)
}
