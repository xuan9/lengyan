//
//  SutraGestures.swift
//  Lengyan
//
//  SwiftUI gesture wrappers for professional reading experience
//  Replaces UIKit-based gesture manager with SwiftUI-native gestures
//

import SwiftUI

// MARK: - Gesture Actions
public struct SutraGestureActions {
    public let onTap: (() -> Void)?
    public let onDoubleTap: (() -> Void)?
    public let onLongPress: (() -> Void)?
    public let onSwipeLeft: (() -> Void)?
    public let onSwipeRight: (() -> Void)?
    public let onPinch: ((CGFloat) -> Void)?

    public init(
        onTap: (() -> Void)? = nil,
        onDoubleTap: (() -> Void)? = nil,
        onLongPress: (() -> Void)? = nil,
        onSwipeLeft: (() -> Void)? = nil,
        onSwipeRight: (() -> Void)? = nil,
        onPinch: ((CGFloat) -> Void)? = nil
    ) {
        self.onTap = onTap
        self.onDoubleTap = onDoubleTap
        self.onLongPress = onLongPress
        self.onSwipeLeft = onSwipeLeft
        self.onSwipeRight = onSwipeRight
        self.onPinch = onPinch
    }
}

// MARK: - Sutra Gestures
public struct SutraGestures: ViewModifier {
    public let edgeWidth: CGFloat
    public let longPressDuration: TimeInterval
    public let doubleTapTimeout: TimeInterval
    public let actions: SutraGestureActions

    @State private var lastTapDate: Date = Date.distantPast
    @State private var tapCount: Int = 0

    public init(
        edgeWidth: CGFloat = 80,
        longPressDuration: TimeInterval = 0.5,
        doubleTapTimeout: TimeInterval = 0.3,
        actions: SutraGestureActions
    ) {
        self.edgeWidth = edgeWidth
        self.longPressDuration = longPressDuration
        self.doubleTapTimeout = doubleTapTimeout
        self.actions = actions
    }

    public func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    ZStack {
                        // Left edge tap area
                        if actions.onSwipeLeft != nil || actions.onTap != nil {
                            Rectangle()
                                .fill(Color.clear)
                                .frame(width: edgeWidth)
                                .contentShape(Rectangle())
                                .gesture(
                                    TapGesture(count: 1)
                                        .onEnded { _ in
                                            handleTap(at: CGPoint(x: edgeWidth / 2, y: geometry.size.height / 2))
                                        }
                                )
                                .gesture(
                                    SwipeGesture(direction: .left)
                                        .onEnded { _ in
                                            actions.onSwipeLeft?()
                                        }
                                )
                        }

                        // Right edge tap area
                        if actions.onSwipeRight != nil || actions.onTap != nil {
                            Rectangle()
                                .fill(Color.clear)
                                .frame(width: edgeWidth)
                                .contentShape(Rectangle())
                                .offset(x: geometry.size.width - edgeWidth)
                                .gesture(
                                    TapGesture(count: 1)
                                        .onEnded { _ in
                                            handleTap(at: CGPoint(x: geometry.size.width - edgeWidth / 2, y: geometry.size.height / 2))
                                        }
                                )
                                .gesture(
                                    SwipeGesture(direction: .right)
                                        .onEnded { _ in
                                            actions.onSwipeRight?()
                                        }
                                )
                        }

                        // Center area for other gestures
                        Rectangle()
                            .fill(Color.clear)
                            .contentShape(Rectangle())
                            .gesture(
                                TapGesture(count: 2)
                                    .onEnded { _ in
                                        actions.onDoubleTap?()
                                    }
                            )
                            .gesture(
                                LongPressGesture(minimumDuration: longPressDuration)
                                    .onEnded { _ in
                                        actions.onLongPress?()
                                    }
                            )
                            .gesture(
                                MagnificationGesture()
                                    .onChanged { scale in
                                        actions.onPinch?(scale)
                                    }
                            )
                    }
                }
            )
    }

    private func handleTap(at location: CGPoint) {
        let now = Date()
        let timeInterval = now.timeIntervalSince(lastTapDate)

        if timeInterval < doubleTapTimeout {
            tapCount += 1
        } else {
            tapCount = 1
        }

        lastTapDate = now

        if tapCount >= 2 && timeInterval < doubleTapTimeout {
            actions.onDoubleTap?()
            tapCount = 0
        } else if actions.onTap != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + doubleTapTimeout) {
                if tapCount < 2 {
                    actions.onTap?()
                    tapCount = 0
                }
            }
        }
    }
}

// MARK: - Gesture Convenience Extensions
extension View {
    public func sutraGestures(
        edgeWidth: CGFloat = 80,
        longPressDuration: TimeInterval = 0.5,
        actions: SutraGestureActions
    ) -> some View {
        self.modifier(
            SutraGestures(
                edgeWidth: edgeWidth,
                longPressDuration: longPressDuration,
                actions: actions
            )
        )
    }

    public func sutraEdgeSwipe(
        edgeWidth: CGFloat = 80,
        onSwipeLeft: (() -> Void)? = nil,
        onSwipeRight: (() -> Void)? = nil,
        onTap: (() -> Void)? = nil
    ) -> some View {
        self.modifier(
            SutraGestures(
                edgeWidth: edgeWidth,
                actions: SutraGestureActions(
                    onTap: onTap,
                    onSwipeLeft: onSwipeLeft,
                    onSwipeRight: onSwipeRight
                )
            )
        )
    }

    public func sutraLongPress(
        minimumDuration: TimeInterval = 0.5,
        onLongPress: @escaping () -> Void
    ) -> some View {
        LongPressGesture(minimumDuration: minimumDuration)
            .onEnded { _ in
                onLongPress()
            }
    }

    public func sutraDoubleTap(
        onDoubleTap: @escaping () -> Void
    ) -> some View {
        TapGesture(count: 2)
            .onEnded { _ in
                onDoubleTap()
            }
    }

    public func sutraPinch(
        onPinch: @escaping (CGFloat) -> Void
    ) -> some View {
        MagnificationGesture()
            .onChanged { scale in
                onPinch(scale)
            }
    }
}

// MARK: - Swipe Gesture Helper
struct SwipeGesture: Gesture {
    enum Direction {
        case left
        case right
        case up
        case down
    }

    let direction: Direction
    var minimumDistance: CGFloat = 30

    typealias Value = SwipeGestureValue

    struct SwipeGestureValue {
        var translation: CGSize
        var velocity: CGFloat
        var isFinal: Bool
    }

    var body: some Gesture {
        DragGesture(minimumDistance: minimumDistance)
            .onChanged { value in
                let translation = value.translation
                var velocity = value.predictedEndTranslation.width
                var isFinal = false

                switch direction {
                case .left:
                    if translation.width < -minimumDistance {
                        isFinal = true
                    }
                    velocity = -velocity
                case .right:
                    if translation.width > minimumDistance {
                        isFinal = true
                    }
                case .up:
                    if translation.height < -minimumDistance {
                        isFinal = true
                    }
                    velocity = -value.predictedEndTranslation.height
                case .down:
                    if translation.height > minimumDistance {
                        isFinal = true
                    }
                    velocity = value.predictedEndTranslation.height
                }

                let gestureValue = SwipeGestureValue(
                    translation: translation,
                    velocity: abs(velocity),
                    isFinal: isFinal
                )

                // Trigger only on final value
                if isFinal {
                    _ = gestureValue
                }
            }
            .onEnded { value in
                let translation = value.translation
                switch direction {
                case .left:
                    if translation.width < -minimumDistance {
                        // Completed left swipe
                    }
                case .right:
                    if translation.width > minimumDistance {
                        // Completed right swipe
                    }
                case .up:
                    if translation.height < -minimumDistance {
                        // Completed up swipe
                    }
                case .down:
                    if translation.height > minimumDistance {
                        // Completed down swipe
                    }
                }
            }
    }
}

// MARK: - Gesture Combination Helpers
public struct GestureBuilder {
    public static func combine(
        _ gestures: some Gesture...
    ) -> some Gesture {
        if gestures.count == 1 {
            return gestures[0]
        } else {
            return gestures[0].combined(with: gestures[1])
        }
    }
}
