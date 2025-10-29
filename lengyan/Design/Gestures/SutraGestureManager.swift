//
//  SutraGestureManager.swift
//  lengyan
//
//  Created by Design System on 2024/10/28.
//  Copyright © 2024年 xuan. All rights reserved.
//

import UIKit

// MARK: - Gesture Manager Delegate
protocol SutraGestureManagerDelegate: AnyObject {
    func gestureManager(_ manager: SutraGestureManager, didTapLeftEdge location: CGPoint)
    func gestureManager(_ manager: SutraGestureManager, didTapRightEdge location: CGPoint)
    func gestureManager(_ manager: SutraGestureManager, didTapCenter location: CGPoint)
    func gestureManager(_ manager: SutraGestureManager, didSwipeLeft direction: UISwipeGestureRecognizer.Direction)
    func gestureManager(_ manager: SutraGestureManager, didSwipeRight direction: UISwipeGestureRecognizer.Direction)
    func gestureManager(_ manager: SutraGestureManager, didSwipeUp direction: UISwipeGestureRecognizer.Direction)
    func gestureManager(_ manager: SutraGestureManager, didSwipeDown direction: UISwipeGestureRecognizer.Direction)
    func gestureManager(_ manager: SutraGestureManager, didPinch scale: CGFloat)
    func gestureManager(_ manager: SutraGestureManager, didLongPress location: CGPoint)
    func gestureManager(_ manager: SutraGestureManager, didDoubleTap location: CGPoint)
    func gestureManagerDidRequestBookmark(_ manager: SutraGestureManager)
    func gestureManagerDidRequestThemeToggle(_ manager: SutraGestureManager)
    func gestureManagerDidRequestChapterNavigator(_ manager: SutraGestureManager)
    func gestureManagerDidRequestSettings(_ manager: SutraGestureManager)
}

// MARK: - Sacred Gesture Manager
class SutraGestureManager: NSObject {

    // MARK: - Gesture Recognizers
    private var tapGesture: UITapGestureRecognizer!
    private var doubleTapGesture: UITapGestureRecognizer!
    private var longPressGesture: UILongPressGestureRecognizer!
    private var swipeLeftGesture: UISwipeGestureRecognizer!
    private var swipeRightGesture: UISwipeGestureRecognizer!
    private var swipeUpGesture: UISwipeGestureRecognizer!
    private var swipeDownGesture: UISwipeGestureRecognizer!
    private var pinchGesture: UIPinchGestureRecognizer!
    private var edgeLeftGesture: UIScreenEdgePanGestureRecognizer!
    private var edgeRightGesture: UIScreenEdgePanGestureRecognizer!

    // MARK: - Properties
    private weak var targetView: UIView?
    private var currentTheme: SutraTheme = .light
    private var isGestureEnabled: Bool = true

    weak var delegate: SutraGestureManagerDelegate?

    // MARK: - Gesture Configuration
    private let edgeTapWidth: CGFloat = 80
    private let longPressDuration: TimeInterval = 0.5
    private let doubleTapTimeout: TimeInterval = 0.3

    // MARK: - Gesture States
    private var lastTapTime: TimeInterval = 0
    private var lastTapLocation: CGPoint = .zero
    private var isPinching: Bool = false
    private var initialPinchScale: CGFloat = 1.0

    override init() {
        super.init()
        setupGestures()
    }

    private func setupGestures() {
        // Single tap gesture
        tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        tapGesture.numberOfTapsRequired = 1
        tapGesture.numberOfTouchesRequired = 1

        // Double tap gesture
        doubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap))
        doubleTapGesture.numberOfTapsRequired = 2
        doubleTapGesture.numberOfTouchesRequired = 1

        // Require double tap to fail for single tap
        tapGesture.require(toFail: doubleTapGesture)

        // Long press gesture
        longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress))
        longPressGesture.minimumPressDuration = longPressDuration
        longPressGesture.numberOfTouchesRequired = 1

        // Swipe gestures
        swipeLeftGesture = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe))
        swipeLeftGesture.direction = .left

        swipeRightGesture = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe))
        swipeRightGesture.direction = .right

        swipeUpGesture = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe))
        swipeUpGesture.direction = .up

        swipeDownGesture = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe))
        swipeDownGesture.direction = .down

        // Pinch gesture
        pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch))

        // Edge pan gestures
        edgeLeftGesture = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(handleEdgePan))
        edgeLeftGesture.edges = .left

        edgeRightGesture = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(handleEdgePan))
        edgeRightGesture.edges = .right
    }

    // MARK: - Public Configuration Methods

    public func attach(to view: UIView) {
        targetView = view

        view.addGestureRecognizer(tapGesture)
        view.addGestureRecognizer(doubleTapGesture)
        view.addGestureRecognizer(longPressGesture)
        view.addGestureRecognizer(swipeLeftGesture)
        view.addGestureRecognizer(swipeRightGesture)
        view.addGestureRecognizer(swipeUpGesture)
        view.addGestureRecognizer(swipeDownGesture)
        view.addGestureRecognizer(pinchGesture)
        view.addGestureRecognizer(edgeLeftGesture)
        view.addGestureRecognizer(edgeRightGesture)

        // Enable gesture recognition
        enableGestures()
    }

    public func detach() {
        guard let view = targetView else { return }

        view.removeGestureRecognizer(tapGesture)
        view.removeGestureRecognizer(doubleTapGesture)
        view.removeGestureRecognizer(longPressGesture)
        view.removeGestureRecognizer(swipeLeftGesture)
        view.removeGestureRecognizer(swipeRightGesture)
        view.removeGestureRecognizer(swipeUpGesture)
        view.removeGestureRecognizer(swipeDownGesture)
        view.removeGestureRecognizer(pinchGesture)
        view.removeGestureRecognizer(edgeLeftGesture)
        view.removeGestureRecognizer(edgeRightGesture)

        targetView = nil
    }

    public func enableGestures() {
        isGestureEnabled = true
        updateGestureStates()
    }

    public func disableGestures() {
        isGestureEnabled = false
        updateGestureStates()
    }

    private func updateGestureStates() {
        tapGesture.isEnabled = isGestureEnabled
        doubleTapGesture.isEnabled = isGestureEnabled
        longPressGesture.isEnabled = isGestureEnabled
        swipeLeftGesture.isEnabled = isGestureEnabled
        swipeRightGesture.isEnabled = isGestureEnabled
        swipeUpGesture.isEnabled = isGestureEnabled
        swipeDownGesture.isEnabled = isGestureEnabled
        pinchGesture.isEnabled = isGestureEnabled
        edgeLeftGesture.isEnabled = isGestureEnabled
        edgeRightGesture.isEnabled = isGestureEnabled
    }

    public func updateTheme(_ theme: SutraTheme) {
        currentTheme = theme
    }

    // MARK: - Gesture Handlers

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        guard isGestureEnabled else { return }

        let location = gesture.location(in: targetView)
        let viewBounds = targetView?.bounds ?? .zero

        SutraHapticManager.shared.haptic(.light)

        // Determine tap region
        if location.x <= edgeTapWidth {
            // Left edge tap
            delegate?.gestureManager(self, didTapLeftEdge: location)
        } else if location.x >= viewBounds.width - edgeTapWidth {
            // Right edge tap
            delegate?.gestureManager(self, didTapRightEdge: location)
        } else {
            // Center tap
            delegate?.gestureManager(self, didTapCenter: location)
        }
    }

    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        guard isGestureEnabled else { return }

        let location = gesture.location(in: targetView)
        delegate?.gestureManager(self, didDoubleTap: location)

        // Sacred haptic for double tap
        SutraHapticManager.shared.haptic(.sacred)

        // Create ripple effect at tap location
        createRippleEffect(at: location)
    }

    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard isGestureEnabled else { return }

        let location = gesture.location(in: targetView)

        switch gesture.state {
        case .began:
            SutraHapticManager.shared.haptic(.medium)
            delegate?.gestureManager(self, didLongPress: location)

            // Create pulsing effect
            createPulsingEffect(at: location)

        case .ended, .cancelled:
            // Remove pulsing effect
            removePulsingEffect()

        default:
            break
        }
    }

    @objc private func handleSwipe(_ gesture: UISwipeGestureRecognizer) {
        guard isGestureEnabled else { return }

        delegate?.gestureManager(self, didSwipe: gesture.direction)

        // Haptic feedback based on swipe direction
        switch gesture.direction {
        case .left, .right:
            SutraHapticManager.shared.haptic(.light)
        case .up, .down:
            SutraHapticManager.shared.haptic(.medium)
        default:
            break
        }

        // Create swipe animation
        createSwipeAnimation(direction: gesture.direction)
    }

    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        guard isGestureEnabled else { return }

        switch gesture.state {
        case .began:
            isPinching = true
            initialPinchScale = gesture.scale
            SutraHapticManager.shared.prepareHaptic()

        case .changed:
            if isPinching {
                let scale = gesture.scale / initialPinchScale
                delegate?.gestureManager(self, didPinch: scale)

                // Haptic feedback at scale milestones
                let milestone = Int(scale * 10)
                let previousMilestone = Int(initialPinchScale * 10)
                if milestone != previousMilestone && milestone % 2 == 0 {
                    SutraHapticManager.shared.haptic(.selection)
                }
            }

        case .ended, .cancelled:
            isPinching = false
            SutraHapticManager.shared.haptic(.light)

        default:
            break
        }
    }

    @objc private func handleEdgePan(_ gesture: UIScreenEdgePanGestureRecognizer) {
        guard isGestureEnabled else { return }

        let location = gesture.location(in: targetView)
        let translation = gesture.translation(in: targetView)

        switch gesture.state {
        case .began:
            SutraHapticManager.shared.haptic(.light)

            if gesture.edges == .left {
                // Left edge pan - show chapter navigator
                createSlideInAnimation(from: .left, progress: translation.x / 200)
            } else {
                // Right edge pan - show bookmarks or settings
                createSlideInAnimation(from: .right, progress: abs(translation.x) / 200)
            }

        case .changed:
            let progress = min(abs(translation.x) / 200, 1.0)

            if gesture.edges == .left {
                createSlideInAnimation(from: .left, progress: progress)
            } else {
                createSlideInAnimation(from: .right, progress: progress)
            }

        case .ended:
            let progress = abs(translation.x) / 200

            if progress > 0.3 {
                // Gesture completed
                SutraHapticManager.shared.haptic(.success)

                if gesture.edges == .left {
                    delegate?.gestureManagerDidRequestChapterNavigator(self)
                } else {
                    delegate?.gestureManagerDidRequestSettings(self)
                }
            } else {
                // Gesture cancelled
                SutraHapticManager.shared.haptic(.light)
            }

            // Reset animation
            createSlideInAnimation(from: gesture.edges == .left ? .left : .right, progress: 0)

        default:
            break
        }
    }

    // MARK: - Visual Effects

    private func createRippleEffect(at location: CGPoint) {
        guard let view = targetView else { return }

        let ripple = CALayer()
        ripple.backgroundColor = SutraColors.Semantic.accent(theme: currentTheme).withAlphaComponent(0.3).cgColor
        ripple.cornerRadius = 50
        ripple.frame = CGRect(x: location.x - 50, y: location.y - 50, width: 100, height: 100)
        view.layer.addSublayer(ripple)

        let scaleAnimation = CABasicAnimation(keyPath: "transform.scale")
        scaleAnimation.fromValue = 0
        scaleAnimation.toValue = 3
        scaleAnimation.duration = 0.6
        scaleAnimation.timingFunction = CAMediaTimingFunction(name: .easeOut)

        let opacityAnimation = CABasicAnimation(keyPath: "opacity")
        opacityAnimation.fromValue = 0.5
        opacityAnimation.toValue = 0
        opacityAnimation.duration = 0.6

        ripple.add(scaleAnimation, forKey: "scale")
        ripple.add(opacityAnimation, forKey: "opacity")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            ripple.removeFromSuperlayer()
        }
    }

    private func createPulsingEffect(at location: CGPoint) {
        guard let view = targetView else { return }

        let pulse = CALayer()
        pulse.backgroundColor = SutraColors.Semantic.accent(theme: currentTheme).withAlphaComponent(0.2).cgColor
        pulse.cornerRadius = 30
        pulse.frame = CGRect(x: location.x - 30, y: location.y - 30, width: 60, height: 60)
        pulse.name = "pulseLayer"
        view.layer.addSublayer(pulse)

        let pulseAnimation = CABasicAnimation(keyPath: "transform.scale")
        pulseAnimation.fromValue = 1
        pulseAnimation.toValue = 1.5
        pulseAnimation.duration = 0.8
        pulseAnimation.autoreverses = true
        pulseAnimation.repeatCount = .infinity

        pulse.add(pulseAnimation, forKey: "pulse")
    }

    private func removePulsingEffect() {
        targetView?.layer.sublayers?.forEach { layer in
            if layer.name == "pulseLayer" {
                let fadeAnimation = CABasicAnimation(keyPath: "opacity")
                fadeAnimation.fromValue = layer.opacity
                fadeAnimation.toValue = 0
                fadeAnimation.duration = 0.2

                layer.add(fadeAnimation, forKey: "fade")

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    layer.removeFromSuperlayer()
                }
            }
        }
    }

    private func createSwipeAnimation(direction: UISwipeGestureRecognizer.Direction) {
        guard let view = targetView else { return }

        let swipe = CALayer()
        swipe.backgroundColor = SutraColors.Semantic.accent(theme: currentTheme).withAlphaComponent(0.1).cgColor

        let viewBounds = view.bounds
        let swipeThickness: CGFloat = 20

        switch direction {
        case .left:
            swipe.frame = CGRect(x: viewBounds.width, y: 0, width: swipeThickness, height: viewBounds.height)
        case .right:
            swipe.frame = CGRect(x: -swipeThickness, y: 0, width: swipeThickness, height: viewBounds.height)
        case .up:
            swipe.frame = CGRect(x: 0, y: viewBounds.height, width: viewBounds.width, height: swipeThickness)
        case .down:
            swipe.frame = CGRect(x: 0, y: -swipeThickness, width: viewBounds.width, height: swipeThickness)
        default:
            return
        }

        view.layer.addSublayer(swipe)

        let duration: TimeInterval = 0.3
        let animation = CABasicAnimation(keyPath: direction == .left || direction == .right ? "transform.translation.x" : "transform.translation.y")

        if direction == .left {
            animation.fromValue = 0
            animation.toValue = -viewBounds.width
        } else if direction == .right {
            animation.fromValue = 0
            animation.toValue = viewBounds.width
        } else if direction == .up {
            animation.fromValue = 0
            animation.toValue = -viewBounds.height
        } else if direction == .down {
            animation.fromValue = 0
            animation.toValue = viewBounds.height
        }

        animation.duration = duration
        animation.timingFunction = CAMediaTimingFunction(name: .easeOut)

        swipe.add(animation, forKey: "swipe")

        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            swipe.removeFromSuperlayer()
        }
    }

    private func createSlideInAnimation(from edge: UIRectEdge, progress: CGFloat) {
        // This would create a visual feedback for edge pan gestures
        // Implementation depends on specific UI requirements
        // For now, this is a placeholder for the visual feedback system
    }

    // MARK: - Gesture Accessibility

    public func configureAccessibility() {
        guard let view = targetView else { return }

        view.isAccessibilityElement = true
        view.accessibilityLabel = NSLocalizedString("Reading content", comment: "Accessibility label for reading content")

        // Configure accessibility custom actions
        let previousAction = UIAccessibilityCustomAction(
            name: NSLocalizedString("Previous chapter", comment: "Accessibility action"),
            target: self,
            selector: #selector(accessibilityPreviousChapter)
        )

        let nextAction = UIAccessibilityCustomAction(
            name: NSLocalizedString("Next chapter", comment: "Accessibility action"),
            target: self,
            selector: #selector(accessibilityNextChapter)
        )

        let bookmarkAction = UIAccessibilityCustomAction(
            name: NSLocalizedString("Toggle bookmark", comment: "Accessibility action"),
            target: self,
            selector: #selector(accessibilityToggleBookmark)
        )

        let themeAction = UIAccessibilityCustomAction(
            name: NSLocalizedString("Toggle theme", comment: "Accessibility action"),
            target: self,
            selector: #selector(accessibilityToggleTheme)
        )

        view.accessibilityCustomActions = [previousAction, nextAction, bookmarkAction, themeAction]
    }

    @objc private func accessibilityPreviousChapter() {
        delegate?.gestureManager(self, didSwipeRight: .right)
        SutraHapticManager.shared.haptic(.light)
    }

    @objc private func accessibilityNextChapter() {
        delegate?.gestureManager(self, didSwipeLeft: .left)
        SutraHapticManager.shared.haptic(.light)
    }

    @objc private func accessibilityToggleBookmark() {
        delegate?.gestureManagerDidRequestBookmark(self)
        SutraHapticManager.shared.haptic(.success)
    }

    @objc private func accessibilityToggleTheme() {
        delegate?.gestureManagerDidRequestThemeToggle(self)
        SutraHapticManager.shared.haptic(.light)
    }

    deinit {
        detach()
    }
}

// MARK: - Gesture Constants
extension SutraGestureManager {
    public struct Constants {
        public static let defaultEdgeTapWidth: CGFloat = 80
        public static let defaultLongPressDuration: TimeInterval = 0.5
        public static let defaultDoubleTapTimeout: TimeInterval = 0.3
        public static let defaultSwipeThreshold: CGFloat = 50
        public static let defaultPinchThreshold: CGFloat = 0.1
        public static let defaultEdgePanThreshold: CGFloat = 100
    }
}