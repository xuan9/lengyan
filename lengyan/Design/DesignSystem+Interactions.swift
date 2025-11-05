//
//  DesignSystem+Interactions.swift
//  lengyan
//
//  Created by Design System on 2024/10/28.
//  Copyright © 2024年 xuan. All rights reserved.
//

import UIKit

// MARK: - Interaction Types
public enum SutraInteractionType {
    case tap
    case longPress
    case swipe
    case pinch
    case scroll
    case pageTurn
    case bookmark
    case favorite
    case share
}

// MARK: - Haptic Feedback Manager
public class SutraHapticManager {
    public static let shared = SutraHapticManager()
    private init() {}

    // MARK: - Haptic Types
    public enum HapticType {
        case light        // Subtle feedback for UI interactions
        case medium       // Standard feedback for actions
        case heavy        // Strong feedback for important actions
        case success      // Success feedback
        case warning      // Warning feedback
        case error        // Error feedback
        case selection    // Selection feedback
        case impact       // Impact feedback
        case sacred       // Special sacred interactions
    }

    // MARK: - Haptic Methods
    public func haptic(_ type: HapticType) {
        guard #available(iOS 10.0, *) else { return }

        switch type {
        case .light:
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()

        case .medium:
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()

        case .heavy:
            let impact = UIImpactFeedbackGenerator(style: .heavy)
            impact.impactOccurred()

        case .success:
            let notification = UINotificationFeedbackGenerator()
            notification.notificationOccurred(.success)

        case .warning:
            let notification = UINotificationFeedbackGenerator()
            notification.notificationOccurred(.warning)

        case .error:
            let notification = UINotificationFeedbackGenerator()
            notification.notificationOccurred(.error)

        case .selection:
            let selection = UISelectionFeedbackGenerator()
            selection.selectionChanged()

        case .impact:
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()

        case .sacred:
            // Special sacred haptic pattern
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                let lightImpact = UIImpactFeedbackGenerator(style: .light)
                lightImpact.impactOccurred()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
                mediumImpact.impactOccurred()
            }
        }
    }

    // Prepare haptic engine for better responsiveness
    public func prepareHaptic() {
        guard #available(iOS 10.0, *) else { return }
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.prepare()
    }
}

// MARK: - Gesture Recognizer with Haptic Feedback
public class SutraTapGestureRecognizer: UITapGestureRecognizer {
    public let hapticType: SutraHapticManager.HapticType
    public let interactionType: SutraInteractionType

    init(hapticType: SutraHapticManager.HapticType = .light,
         interactionType: SutraInteractionType = .tap,
         target: Any?,
         action: Selector?) {
        self.hapticType = hapticType
        self.interactionType = interactionType
        super.init(target: target, action: action)

        addTarget(self, action: #selector(handleTap))
    }

    @objc private func handleTap() {
        SutraHapticManager.shared.haptic(hapticType)
    }
}

// MARK: - Sacred Button with Enhanced Interactions
public class SutraInteractiveButton: UIButton {

    public enum InteractionStyle {
        case subtle     // Gentle animation
        case standard   // Normal interaction
        case prominent  // Prominent animation
        case sacred     // Special sacred animation
    }

    public var interactionStyle: InteractionStyle = .standard {
        didSet { updateInteractionStyle() }
    }

    public var hapticType: SutraHapticManager.HapticType = .light
    public var isBookmark: Bool = false {
        didSet { updateBookmarkState() }
    }

    private let rippleLayer = CALayer()
    private let glowLayer = CALayer()
    private var originalTransform: CATransform3D = CATransform3DIdentity

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupInteractions()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupInteractions()
    }

    private func setupInteractions() {
        layer.addSublayer(rippleLayer)
        layer.addSublayer(glowLayer)
        setupRippleLayer()
        setupGlowLayer()
        updateInteractionStyle()
    }

    private func setupRippleLayer() {
        rippleLayer.backgroundColor = UIColor.white.withAlphaComponent(0.3).cgColor
        rippleLayer.opacity = 0
        rippleLayer.cornerRadius = layer.cornerRadius
    }

    private func setupGlowLayer() {
        glowLayer.backgroundColor = tintColor?.cgColor ?? UIColor.systemBlue.cgColor
        glowLayer.opacity = 0
        glowLayer.cornerRadius = layer.cornerRadius
        glowLayer.shadowColor = glowLayer.backgroundColor
        glowLayer.shadowRadius = 8
        glowLayer.shadowOpacity = 0
    }

    private func updateInteractionStyle() {
        switch interactionStyle {
        case .subtle:
            addTarget(self, action: #selector(subtleTouchDown), for: .touchDown)
            addTarget(self, action: #selector(subtleTouchUpInside), for: .touchUpInside)

        case .standard:
            addTarget(self, action: #selector(standardTouchDown), for: .touchDown)
            addTarget(self, action: #selector(standardTouchUpInside), for: .touchUpInside)

        case .prominent:
            addTarget(self, action: #selector(prominentTouchDown), for: .touchDown)
            addTarget(self, action: #selector(prominentTouchUpInside), for: .touchUpInside)

        case .sacred:
            addTarget(self, action: #selector(sacredTouchDown), for: .touchDown)
            addTarget(self, action: #selector(sacredTouchUpInside), for: .touchUpInside)
        }
    }

    // MARK: - Touch Animations

    @objc private func subtleTouchDown() {
        UIView.animate(withDuration: 0.1) {
            self.alpha = 0.8
        }
        SutraHapticManager.shared.haptic(.light)
    }

    @objc private func subtleTouchUpInside() {
        UIView.animate(withDuration: 0.1) {
            self.alpha = 1.0
        }
    }

    @objc private func standardTouchDown() {
        originalTransform = layer.transform
        UIView.animate(withDuration: 0.1) {
            self.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
            self.alpha = 0.8
        }
        SutraHapticManager.shared.haptic(.light)
    }

    @objc private func standardTouchUpInside() {
        UIView.animate(withDuration: 0.1, delay: 0, options: .curveEaseOut) {
            self.transform = CGAffineTransform.identity
            self.alpha = 1.0
        }
    }

    @objc private func prominentTouchDown() {
        originalTransform = layer.transform
        showRipple()
        UIView.animate(withDuration: 0.15) {
            self.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
            self.alpha = 0.7
        }
        SutraHapticManager.shared.haptic(.medium)
    }

    @objc private func prominentTouchUpInside() {
        hideRipple()
        UIView.animate(withDuration: 0.2, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5) {
            self.transform = CGAffineTransform.identity
            self.alpha = 1.0
        }
    }

    @objc private func sacredTouchDown() {
        originalTransform = layer.transform
        showSacredAnimation()
        UIView.animate(withDuration: 0.2) {
            self.transform = CGAffineTransform(scaleX: 0.85, y: 0.85)
            self.alpha = 0.6
        }
        SutraHapticManager.shared.haptic(.sacred)
    }

    @objc private func sacredTouchUpInside() {
        hideSacredAnimation()
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.8) {
            self.transform = CGAffineTransform.identity
            self.alpha = 1.0
        }
    }

    // MARK: - Visual Effects

    private func showRipple() {
        rippleLayer.opacity = 1
        let rippleAnimation = CABasicAnimation(keyPath: "transform.scale")
        rippleAnimation.fromValue = 0
        rippleAnimation.toValue = 1
        rippleAnimation.duration = 0.6
        rippleLayer.add(rippleAnimation, forKey: "ripple")
    }

    private func hideRipple() {
        UIView.animate(withDuration: 0.3) {
            self.rippleLayer.opacity = 0
        }
    }

    private func showSacredAnimation() {
        glowLayer.opacity = 0.3

        // Glow pulse animation
        let pulseAnimation = CABasicAnimation(keyPath: "opacity")
        pulseAnimation.fromValue = 0
        pulseAnimation.toValue = 0.3
        pulseAnimation.duration = 0.3
        glowLayer.add(pulseAnimation, forKey: "glowPulse")

        // Scale animation
        let scaleAnimation = CABasicAnimation(keyPath: "transform.scale")
        scaleAnimation.fromValue = 0.8
        scaleAnimation.toValue = 1.2
        scaleAnimation.duration = 0.4
        scaleAnimation.autoreverses = true
        glowLayer.add(scaleAnimation, forKey: "glowScale")
    }

    private func hideSacredAnimation() {
        UIView.animate(withDuration: 0.4) {
            self.glowLayer.opacity = 0
        }
    }

    private func updateBookmarkState() {
        let animation = CATransition()
        animation.type = "fade"
        animation.duration = 0.3
        layer.add(animation, forKey: "bookmarkChange")

        if isBookmark {
            tintColor = SutraColors.Light.bookmark
            hapticType = .success
        } else {
            tintColor = SutraDesignTokens.shared.color(for: SutraDesignTokens.ColorTokens.textPrimary)
            hapticType = .light
        }
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        updateLayers()
    }

    private func updateLayers() {
        rippleLayer.frame = bounds
        glowLayer.frame = bounds
        rippleLayer.cornerRadius = layer.cornerRadius
        glowLayer.cornerRadius = layer.cornerRadius
    }
}

// MARK: - Page Turn Animation Manager
public class SutraPageTurnManager {

    public enum PageTurnDirection {
        case forward
        case backward
    }

    public enum PageTurnStyle {
        case curl        // Page curl effect
        case slide       // Slide transition
        case fade        // Fade transition
        case sacred      // Special sacred transition
    }

    public static func animatePageTurn(from fromView: UIView,
                                      to toView: UIView,
                                      direction: PageTurnDirection,
                                      style: PageTurnStyle,
                                      completion: (() -> Void)? = nil) {
        switch style {
        case .curl:
            animateCurlTurn(from: fromView, to: toView, direction: direction, completion: completion)

        case .slide:
            animateSlideTurn(from: fromView, to: toView, direction: direction, completion: completion)

        case .fade:
            animateFadeTurn(from: fromView, to: toView, completion: completion)

        case .sacred:
            animateSacredTurn(from: fromView, to: toView, direction: direction, completion: completion)
        }
    }

    private static func animateCurlTurn(from fromView: UIView,
                                      to toView: UIView,
                                      direction: PageTurnDirection,
                                      completion: (() -> Void)?) {
        let options: UIView.AnimationOptions = direction == .forward ? .transitionCurlUp : .transitionCurlDown

        UIView.transition(from: fromView, to: toView, duration: 0.8, options: options) { _ in
            completion?()
        }

        SutraHapticManager.shared.haptic(.medium)
    }

    private static func animateSlideTurn(from fromView: UIView,
                                       to toView: UIView,
                                       direction: PageTurnDirection,
                                       completion: (() -> Void)?) {
        toView.frame = fromView.bounds
        let offset = direction == .forward ? fromView.bounds.width : -fromView.bounds.width
        toView.transform = CGAffineTransform(translationX: offset, y: 0)

        fromView.superview?.addSubview(toView)

        UIView.animate(withDuration: 0.4, delay: 0, options: .curveEaseInOut) {
            fromView.transform = CGAffineTransform(translationX: -offset, y: 0)
            toView.transform = .identity
        } completion: { _ in
            fromView.removeFromSuperview()
            fromView.transform = .identity
            completion?()
        }

        SutraHapticManager.shared.haptic(.light)
    }

    private static func animateFadeTurn(from fromView: UIView,
                                      to toView: UIView,
                                      completion: (() -> Void)?) {
        toView.frame = fromView.bounds
        toView.alpha = 0
        fromView.superview?.addSubview(toView)

        UIView.animate(withDuration: 0.5, animations: {
            fromView.alpha = 0
            toView.alpha = 1
        }) { _ in
            fromView.removeFromSuperview()
            fromView.alpha = 1
            completion?()
        }
    }

    private static func animateSacredTurn(from fromView: UIView,
                                        to toView: UIView,
                                        direction: PageTurnDirection,
                                        completion: (() -> Void)?) {
        toView.frame = fromView.bounds
        toView.alpha = 0
        toView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        fromView.superview?.addSubview(toView)

        // Special sacred transition with multiple phases
        UIView.animate(withDuration: 0.3, animations: {
            fromView.alpha = 0.3
            fromView.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }) { _ in
            SutraHapticManager.shared.haptic(.sacred)

            UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.6) {
                toView.alpha = 1
                toView.transform = .identity
                fromView.alpha = 0
                fromView.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
            } completion: { _ in
                fromView.removeFromSuperview()
                fromView.alpha = 1
                fromView.transform = .identity
                completion?()
            }
        }
    }
}

// MARK: - Scroll Enhancement Manager
public class SutraScrollEnhancer: NSObject {

    public enum ScrollStyle {
        case standard
        case elastic
        case sacred
    }

    private let scrollView: UIScrollView
    private var scrollStyle: ScrollStyle = .standard
    private var lastScrollOffset: CGPoint = .zero

    init(scrollView: UIScrollView) {
        self.scrollView = scrollView
        super.init()
        setupScrollEnhancement()
    }

    public func setScrollStyle(_ style: ScrollStyle) {
        scrollStyle = style
        updateScrollBehavior()
    }

    private func setupScrollEnhancement() {
        scrollView.delegate = self
        updateScrollBehavior()
    }

    private func updateScrollBehavior() {
        switch scrollStyle {
        case .standard:
            scrollView.decelerationRate = 0.998
            scrollView.showsVerticalScrollIndicator = true

        case .elastic:
            scrollView.decelerationRate = 0.99
            scrollView.showsVerticalScrollIndicator = false

        case .sacred:
            scrollView.decelerationRate = 0.998
            scrollView.showsVerticalScrollIndicator = false
        }
    }

    // MARK: - Sacred Scroll Effects
    private func applySacredScrollEffect(offset: CGPoint) {
        let scrollProgress = abs(offset.y - lastScrollOffset.y) / 100
        let clampedProgress = min(scrollProgress, 1.0)

        // Subtle alpha change for content
        scrollView.alpha = 1.0 - (clampedProgress * 0.1)

        // Haptic feedback at scroll milestones
        let currentPage = Int(offset.y / scrollView.frame.height)
        let lastPage = Int(lastScrollOffset.y / scrollView.frame.height)

        if currentPage != lastPage {
            SutraHapticManager.shared.haptic(.selection)
        }
    }
}

extension SutraScrollEnhancer: UIScrollViewDelegate {
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        switch scrollStyle {
        case .sacred:
            applySacredScrollEffect(offset: scrollView.contentOffset)
        default:
            break
        }
        lastScrollOffset = scrollView.contentOffset
    }

    public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        SutraHapticManager.shared.prepareHaptic()
    }
}

// MARK: - Gesture Configuration
public class SutraGestureConfiguration {

    public init() {}

    public static func configureTapGesture(on view: UIView,
                                          hapticType: SutraHapticManager.HapticType = .light,
                                          action: @escaping () -> Void) {
        let gesture = SutraTapGestureRecognizer(hapticType: hapticType, interactionType: .tap, target: nil, action: nil)
        gesture.addTarget(SutraGestureConfiguration.self, action: #selector(handleGesture(gesture:)))
        view.addGestureRecognizer(gesture)

        // Store action in associated object
        objc_setAssociatedObject(gesture, "action", action, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    @objc private static func handleGesture(gesture: SutraTapGestureRecognizer) {
        if let action = objc_getAssociatedObject(gesture, "action") as? () -> Void {
            action()
        }
    }

    public static func configureLongPressGesture(on view: UIView,
                                               hapticType: SutraHapticManager.HapticType = .medium,
                                               action: @escaping () -> Void) {
        let longPress = UILongPressGestureRecognizer(target: SutraGestureConfiguration.self, action: #selector(handleLongPress(_:)))
        longPress.minimumPressDuration = 0.5
        view.addGestureRecognizer(longPress)

        objc_setAssociatedObject(longPress, "action", action, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        objc_setAssociatedObject(longPress, "hapticType", hapticType, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    @objc private static func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        if gesture.state == .began {
            if let action = objc_getAssociatedObject(gesture, "action") as? () -> Void,
               let hapticType = objc_getAssociatedObject(gesture, "hapticType") as? SutraHapticManager.HapticType {
                SutraHapticManager.shared.haptic(hapticType)
                action()
            }
        }
    }
}

// MARK: - Animation Presets
public struct SutraAnimationPresets {

    public static func bookmarkToggleAnimation(on view: UIView,
                                             isBookmarked: Bool,
                                             completion: (() -> Void)? = nil) {
        UIView.animate(withDuration: 0.2, animations: {
            view.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
        }) { _ in
            SutraHapticManager.shared.haptic(isBookmarked ? .success : .selection)

            UIView.animate(withDuration: 0.2, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.8) {
                view.transform = .identity
            } completion: { _ in
                completion?()
            }
        }
    }

    public static func shareAnimation(on view: UIView, completion: (() -> Void)? = nil) {
        UIView.animate(withDuration: 0.1, animations: {
            view.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        }) { _ in
            SutraHapticManager.shared.haptic(.light)

            UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 1.0) {
                view.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
            } completion: { _ in
                UIView.animate(withDuration: 0.2) {
                    view.transform = .identity
                } completion: { _ in
                    completion?()
                }
            }
        }
    }

    public static func chapterTransitionAnimation(on view: UIView, completion: (() -> Void)? = nil) {
        view.alpha = 0
        view.transform = CGAffineTransform(translationX: 0, y: 50)

        UIView.animate(withDuration: 0.6, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5) {
            view.alpha = 1
            view.transform = .identity
        } completion: { _ in
            completion?()
        }

        SutraHapticManager.shared.haptic(.sacred)
    }
}

// Associated objects for gesture handling
import ObjectiveC

private var gestureActionKey: UInt8 = 0