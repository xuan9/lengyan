//
//  SutraReadingView.swift
//  Lengyan
//
//  SwiftUI view for reading sutra content
//  Page-by-page navigation with async/await
//

import SwiftUI

/// Main reading view for sutra content
/// Clean, minimal implementation with pagination controls
public struct SutraReadingView: View {
    @StateObject private var viewModel: SutraReadingViewModel

    public init(viewModel: SutraReadingViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Content area with enhanced gestures
            ScrollView {
                Group {
                    if viewModel.currentContent.isEmpty {
                        VStack(spacing: SutraSpacing.md) {
                            ProgressView("Loading content...")
                                .progressViewStyle(CircularProgressViewStyle())
                            Text("Loading content...")
                                .font(ChineseFontManager.appropriateFont(size: GoldenRatioTypography.level1))
                                .sutraLineHeightGoldenRatio(1)
                                .sutraColor(.secondaryText)
                        }
                        .frame(maxWidth: .infinity, maxHeight: 200)
                        .sutraTransition()
                    } else {
                        Text(viewModel.currentContent)
                            .font(ChineseFontManager.appropriateFont(size: GoldenRatioTypography.level2))
                            .sutraLineHeightGoldenRatio(2)
                            .padding(.horizontal, SutraSpacing.readingMargin)
                            .padding(.vertical, SutraSpacing.sutraChapterSpacing)
                            .sutraColor(.primaryText)
                            .sutraAccessibility(
                                category: .sutraText,
                                label: viewModel.currentSutra?.name ?? "Sutra content",
                                hint: "Sutra content, swipe left or right to navigate"
                            )
                            .sutraTransition()
                    }
                }
                .sutraEaseInOutAnimation()
            }
            .scrollContentBackground(.hidden)
            .background(Color.sutraBackground)
            .sutraAccessibility(
                category: .navigation,
                label: viewModel.currentSutra?.name ?? "Sutra Reading",
                hint: "Use previous and next buttons to navigate, or swipe left/right"
            )
            .sutraEdgeSwipe(
                edgeWidth: 80,
                onSwipeLeft: {
                    if viewModel.hasNextPage {
                        viewModel.goToNextPage()
                    }
                },
                onSwipeRight: {
                    if viewModel.hasPreviousPage {
                        viewModel.goToPreviousPage()
                    }
                }
            )

            // Navigation controls with 8pt grid spacing
            HStack(spacing: SutraSpacing.xl) {
                Button {
                    viewModel.goToPreviousPage()
                } label: {
                    VStack(spacing: SutraSpacing.xs) {
                        Image(systemName: "chevron.left")
                            .font(ChineseFontManager.appropriateFont(size: GoldenRatioTypography.level1))
                        Text("Previous")
                            .font(ChineseFontManager.appropriateFont(size: GoldenRatioTypography.level0))
                    }
                    .sutraColor(.primaryText)
                    .scaleEffect(viewModel.hasPreviousPage ? 1.0 : 0.8)
                    .opacity(viewModel.hasPreviousPage ? 1.0 : 0.5)
                }
                .disabled(!viewModel.hasPreviousPage)
                .sutraPadding(.horizontal, SutraSpacing.buttonPadding)
                .sutraPadding(.vertical, SutraSpacing.buttonPadding / 2)
                .sutraHaptic(.tap)
                .sutraAccessibility(
                    category: .button,
                    label: "Previous page",
                    hint: !viewModel.hasPreviousPage ? "Already at first page" : "Go to previous page"
                )
                .sutraLongPress(minimumDuration: 0.5) {
                    // Long press for bookmark
                    viewModel.toggleBookmark()
                }

                Spacer()

                VStack(spacing: SutraSpacing.xs) {
                    Text(viewModel.pageInfo)
                        .font(ChineseFontManager.appropriateFont(size: GoldenRatioTypography.level0))
                        .sutraColor(.secondaryText)
                        .transition(.scale.combined(with: .opacity))

                    if viewModel.hasNextPage || viewModel.hasPreviousPage {
                        Text("Page navigation")
                            .font(ChineseFontManager.appropriateFont(size: GoldenRatioTypography.level0 * 0.9))
                            .sutraColor(.secondaryText)
                    }
                }
                .accessibilityHidden(true)

                Spacer()

                Button {
                    viewModel.goToNextPage()
                } label: {
                    VStack(spacing: SutraSpacing.xs) {
                        Image(systemName: "chevron.right")
                            .font(ChineseFontManager.appropriateFont(size: GoldenRatioTypography.level1))
                        Text("Next")
                            .font(ChineseFontManager.appropriateFont(size: GoldenRatioTypography.level0))
                    }
                    .sutraColor(.primaryText)
                    .scaleEffect(viewModel.hasNextPage ? 1.0 : 0.8)
                    .opacity(viewModel.hasNextPage ? 1.0 : 0.5)
                }
                .disabled(!viewModel.hasNextPage)
                .sutraPadding(.horizontal, SutraSpacing.buttonPadding)
                .sutraPadding(.vertical, SutraSpacing.buttonPadding / 2)
                .sutraHaptic(.tap)
                .sutraAccessibility(
                    category: .button,
                    label: "Next page",
                    hint: !viewModel.hasNextPage ? "Already at last page" : "Go to next page"
                )
            }
            .sutraPadding(.horizontal, SutraSpacing.marginStandard)
            .sutraPadding(.vertical, SutraSpacing.marginStandard)
            .background(Color.sutraCardBackground)
            .sutraTransition()
        }
        .sutraTheme(theme)
        .navigationTitle(viewModel.currentSutra?.name ?? "Reading")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarTitleDisplayMode(.inline)
        .background(Color.sutraBackground)
        .onAppear {
            Task {
                await viewModel.loadSutra(at: viewModel.currentPath)
            }
        }
        .alert("Error", isPresented: $viewModel.showingError) {
            Button("OK") { }
        } message: {
            Text(viewModel.errorMessage ?? "Unknown error")
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    viewModel.toggleBookmark()
                    let notificationFeedback = UINotificationFeedbackGenerator()
                    notificationFeedback.notificationOccurred(.success)
                } label: {
                    Image(systemName: "bookmark")
                        .font(ChineseFontManager.appropriateFont(size: GoldenRatioTypography.level1))
                        .sutraColor(.accent)
                }
                .sutraHaptic(.notificationSuccess)
                .sutraAccessibility(
                    category: .button,
                    label: "Toggle bookmark",
                    hint: "Long press to toggle bookmark"
                )
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let mockRepository = MockBookRepository(
        mockTree: [],
        mockSutras: []
    )
    let viewModel = SutraReadingViewModel(
        repository: mockRepository,
        initialPath: "/A1/B1/C1"
    )
    return NavigationStack {
        SutraReadingView(viewModel: viewModel)
    }
}
