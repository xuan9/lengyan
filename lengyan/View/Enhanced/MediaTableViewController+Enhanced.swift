//
//  MediaTableViewController+Enhanced.swift
//  lengyan
//
//  Enhanced version with new design system integration
//  Maintains all existing functionality while adding modern audio listening interface
//

import Foundation
import UIKit
import AVFoundation
import MediaPlayer

class EnhancedMediaTableViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    // MARK: - UI Components
    private var tableView: UITableView!
    private var playerFooterView: UIView!
    private var playerContainerView: UIView!
    private var playerTitleLabel: UILabel!
    private var playerProgressSlider: UISlider!
    private var playerProgressLabel: UILabel!
    private var playerDurationLabel: UILabel!
    private var playerPlayButton: UIButton!
    private var playerModeButton: UIButton!
    private var playerContainerHeightConstraint: NSLayoutConstraint!

    // Enhanced Components
    private var refreshControl: UIRefreshControl!
    private var emptyStateView: UIView!
    private var loadingIndicator: UIActivityIndicatorView!
    private var miniPlayerView: UIView?
    private var visualizerView: UIView?

    // Data & Playback
    internal var initialRow = 0
    var media: [[String: Any]] = []
    private var queuePlayer: AVQueuePlayer?
    private var tagStatus: [String: Int8] = [:]
    private var wantedTags: [String: Int8] = [:]
    var timer: Timer?
    private var playMode = -1
    private var rReq: [String: NSBundleResourceRequest] = [:]
    private var lastPlayFile: [String]?
    private var isPlayingOnSlideBegan = false

    // Design System
    private let themeManager = SutraThemeManager.shared
    private var currentTheme: SutraTheme = .light

    // Animation & Interaction
    private var hasAppeared = false
    private var isPlayerExpanded = false

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupDesignSystem()
        setupEnhancedUI()
        setupData()
        setupAudioSession()
        setupGestures()
        setupAccessibility()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateTheme()
        setupNavigationBar()
        checkMediaStatus()
        restorePlayerState()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !hasAppeared {
            animateEntrance()
            hasAppeared = true
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        savePlayerState()
    }

    // MARK: - Setup Methods
    private func setupDesignSystem() {
        currentTheme = themeManager.currentTheme
        view.backgroundColor = SutraColors.Semantic.background(theme: currentTheme)
    }

    private func setupEnhancedUI() {
        setupTableView()
        setupPlayerFooterView()
        setupRefreshControl()
        setupLoadingIndicator()
        setupEmptyStateView()
    }

    private func setupTableView() {
        tableView = UITableView(frame: .zero, style: .grouped)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = .clear
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorStyle = .none
        tableView.showsVerticalScrollIndicator = false
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 100, right: 0)

        // Register cells
        tableView.register(EnhancedMediaHeaderCell.self, forHeaderFooterViewReuseIdentifier: "MediaHeaderCell")
        tableView.register(EnhancedMediaCell.self, forCellReuseIdentifier: "MediaCell")
        tableView.register(EnhancedMediaDownloadCell.self, forCellReuseIdentifier: "MediaDownloadCell")

        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func setupPlayerFooterView() {
        playerFooterView = UIView()
        playerFooterView.translatesAutoresizingMaskIntoConstraints = false
        playerFooterView.backgroundColor = SutraColors.Semantic.surface(theme: currentTheme)
        playerFooterView.layer.cornerRadius = SutraSpacing.cornerRadius
        playerFooterView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        playerFooterView.layer.shadowColor = SutraColors.Light.shadow.cgColor
        playerFooterView.layer.shadowOffset = CGSize(width: 0, height: -4)
        playerFooterView.layer.shadowRadius = 16
        playerFooterView.layer.shadowOpacity = 0.2

        view.addSubview(playerFooterView)

        playerContainerHeightConstraint = playerFooterView.heightAnchor.constraint(equalToConstant: 0)
        playerContainerHeightConstraint.isActive = true

        NSLayoutConstraint.activate([
            playerFooterView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            playerFooterView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            playerFooterView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        setupPlayerContent()
    }

    private func setupPlayerContent() {
        // Main container
        playerContainerView = UIView()
        playerContainerView.translatesAutoresizingMaskIntoConstraints = false
        playerContainerView.backgroundColor = .clear
        playerFooterView.addSubview(playerContainerView)

        // Title label
        playerTitleLabel = UILabel()
        playerTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        playerTitleLabel.font = SutraTypography.Typography.headline
        playerTitleLabel.textColor = SutraColors.Semantic.primary(theme: currentTheme)
        playerTitleLabel.textAlignment = .center
        playerTitleLabel.numberOfLines = 2
        playerContainerView.addSubview(playerTitleLabel)

        // Progress container
        let progressContainer = UIView()
        progressContainer.translatesAutoresizingMaskIntoConstraints = false
        playerContainerView.addSubview(progressContainer)

        // Progress slider
        playerProgressSlider = UISlider()
        playerProgressSlider.translatesAutoresizingMaskIntoConstraints = false
        playerProgressSlider.minimumTrackTintColor = SutraColors.Semantic.accent(theme: currentTheme)
        playerProgressSlider.maximumTrackTintColor = SutraColors.Semantic.divider(theme: currentTheme)
        playerProgressSlider.addTarget(self, action: #selector(progressBarChanged(slider:event:)), for: .valueChanged)
        progressContainer.addSubview(playerProgressSlider)

        // Time labels
        playerProgressLabel = UILabel()
        playerProgressLabel.translatesAutoresizingMaskIntoConstraints = false
        playerProgressLabel.font = SutraTypography.Typography.caption
        playerProgressLabel.textColor = SutraColors.Semantic.textSecondary(theme: currentTheme)
        playerProgressLabel.text = "00:00"
        progressContainer.addSubview(playerProgressLabel)

        playerDurationLabel = UILabel()
        playerDurationLabel.translatesAutoresizingMaskIntoConstraints = false
        playerDurationLabel.font = SutraTypography.Typography.caption
        playerDurationLabel.textColor = SutraColors.Semantic.textSecondary(theme: currentTheme)
        playerDurationLabel.text = "00:00"
        progressContainer.addSubview(playerDurationLabel)

        // Control buttons container
        let controlsContainer = UIView()
        controlsContainer.translatesAutoresizingMaskIntoConstraints = false
        playerContainerView.addSubview(controlsContainer)

        // Play button
        playerPlayButton = UIButton(type: .custom)
        playerPlayButton.translatesAutoresizingMaskIntoConstraints = false
        playerPlayButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
        playerPlayButton.setImage(UIImage(systemName: "pause.fill"), for: .selected)
        playerPlayButton.tintColor = SutraColors.Semantic.accent(theme: currentTheme)
        playerPlayButton.backgroundColor = SutraColors.Semantic.accent(theme: currentTheme).withAlphaComponent(0.1)
        playerPlayButton.layer.cornerRadius = 25
        playerPlayButton.addTarget(self, action: #selector(pressPlayButton(button:)), for: .touchUpInside)
        controlsContainer.addSubview(playerPlayButton)

        // Mode button
        playerModeButton = UIButton(type: .custom)
        playerModeButton.translatesAutoresizingMaskIntoConstraints = false
        playerModeButton.setImage(UIImage(systemName: "repeat"), for: .normal)
        playerModeButton.tintColor = SutraColors.Semantic.textSecondary(theme: currentTheme)
        playerModeButton.backgroundColor = SutraColors.Semantic.surface(theme: currentTheme)
        playerModeButton.layer.cornerRadius = 20
        playerModeButton.layer.borderWidth = 1
        playerModeButton.layer.borderColor = SutraColors.Semantic.border(theme: currentTheme).cgColor
        playerModeButton.addTarget(self, action: #selector(pressModeButton(button:)), for: .touchUpInside)
        controlsContainer.addSubview(playerModeButton)

        // Visualizer (optional enhancement)
        visualizerView = UIView()
        visualizerView?.translatesAutoresizingMaskIntoConstraints = false
        visualizerView?.backgroundColor = SutraColors.Semantic.accent(theme: currentTheme).withAlphaComponent(0.1)
        visualizerView?.layer.cornerRadius = 4
        playerContainerView.addSubview(visualizerView!)

        NSLayoutConstraint.activate([
            playerContainerView.topAnchor.constraint(equalTo: playerFooterView.topAnchor, constant: SutraSpacing.medium),
            playerContainerView.leadingAnchor.constraint(equalTo: playerFooterView.leadingAnchor, constant: SutraSpacing.medium),
            playerContainerView.trailingAnchor.constraint(equalTo: playerFooterView.trailingAnchor, constant: -SutraSpacing.medium),
            playerContainerView.bottomAnchor.constraint(equalTo: playerFooterView.bottomAnchor, constant: -SutraSpacing.medium),

            playerTitleLabel.topAnchor.constraint(equalTo: playerContainerView.topAnchor),
            playerTitleLabel.leadingAnchor.constraint(equalTo: playerContainerView.leadingAnchor),
            playerTitleLabel.trailingAnchor.constraint(equalTo: playerContainerView.trailingAnchor),

            progressContainer.topAnchor.constraint(equalTo: playerTitleLabel.bottomAnchor, constant: SutraSpacing.medium),
            progressContainer.leadingAnchor.constraint(equalTo: playerContainerView.leadingAnchor),
            progressContainer.trailingAnchor.constraint(equalTo: playerContainerView.trailingAnchor),

            playerProgressLabel.leadingAnchor.constraint(equalTo: progressContainer.leadingAnchor),
            playerProgressLabel.centerYAnchor.constraint(equalTo: progressContainer.centerYAnchor),

            playerProgressSlider.leadingAnchor.constraint(equalTo: playerProgressLabel.trailingAnchor, constant: SutraSpacing.small),
            playerProgressSlider.centerYAnchor.constraint(equalTo: progressContainer.centerYAxis),

            playerDurationLabel.leadingAnchor.constraint(equalTo: playerProgressSlider.trailingAnchor, constant: SutraSpacing.small),
            playerDurationLabel.trailingAnchor.constraint(equalTo: progressContainer.trailingAnchor),
            playerDurationLabel.centerYAnchor.constraint(equalTo: progressContainer.centerYAxis),

            controlsContainer.topAnchor.constraint(equalTo: progressContainer.bottomAnchor, constant: SutraSpacing.medium),
            controlsContainer.centerXAnchor.constraint(equalTo: playerContainerView.centerXAnchor),
            controlsContainer.bottomAnchor.constraint(equalTo: playerContainerView.bottomAnchor),

            playerPlayButton.widthAnchor.constraint(equalToConstant: 50),
            playerPlayButton.heightAnchor.constraint(equalToConstant: 50),

            playerModeButton.widthAnchor.constraint(equalToConstant: 40),
            playerModeButton.heightAnchor.constraint(equalToConstant: 40),
            playerModeButton.leadingAnchor.constraint(equalTo: playerPlayButton.trailingAnchor, constant: SutraSpacing.large),

            visualizerView!.leadingAnchor.constraint(equalTo: controlsContainer.trailingAnchor, constant: SutraSpacing.medium),
            visualizerView!.centerYAnchor.constraint(equalTo: controlsContainer.centerYAnchor),
            visualizerView!.widthAnchor.constraint(equalToConstant: 60),
            visualizerView!.heightAnchor.constraint(equalToConstant: 4)
        ])
    }

    private func setupRefreshControl() {
        refreshControl = UIRefreshControl()
        refreshControl.tintColor = SutraColors.Semantic.accent(theme: currentTheme)
        refreshControl.addTarget(self, action: #selector(refreshData), for: .valueChanged)
        tableView.refreshControl = refreshControl
    }

    private func setupLoadingIndicator() {
        loadingIndicator = UIActivityIndicatorView(style: .large)
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicator.color = SutraColors.Semantic.accent(theme: currentTheme)
        loadingIndicator.hidesWhenStopped = true
        view.addSubview(loadingIndicator)

        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    private func setupEmptyStateView() {
        emptyStateView = UIView()
        emptyStateView?.translatesAutoresizingMaskIntoConstraints = false
        emptyStateView?.backgroundColor = SutraColors.Semantic.background(theme: currentTheme)
        emptyStateView?.isHidden = true
        view.addSubview(emptyStateView!)

        let imageView = UIImageView(image: UIImage(systemName: "headphones"))
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.tintColor = SutraColors.Semantic.textTertiary(theme: currentTheme)
        imageView.contentMode = .scaleAspectFit
        emptyStateView?.addSubview(imageView)

        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = NSLocalizedString("no_media_available", comment: "No media content available")
        titleLabel.font = SutraTypography.Typography.headline
        titleLabel.textColor = SutraColors.Semantic.textSecondary(theme: currentTheme)
        titleLabel.textAlignment = .center
        emptyStateView?.addSubview(titleLabel)

        let messageLabel = UILabel()
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.text = NSLocalizedString("check_internet_for_media", comment: "Please check your internet connection")
        messageLabel.font = SutraTypography.Typography.body
        messageLabel.textColor = SutraColors.Semantic.textTertiary(theme: currentTheme)
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0
        emptyStateView?.addSubview(messageLabel)

        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: emptyStateView!.centerXAnchor),
            imageView.topAnchor.constraint(equalTo: emptyStateView!.topAnchor, constant: 80),
            imageView.widthAnchor.constraint(equalToConstant: 60),
            imageView.heightAnchor.constraint(equalToConstant: 60),

            titleLabel.centerXAnchor.constraint(equalTo: emptyStateView!.centerXAnchor),
            titleLabel.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: SutraSpacing.medium),
            titleLabel.leadingAnchor.constraint(equalTo: emptyStateView!.leadingAnchor, constant: SutraSpacing.large),
            titleLabel.trailingAnchor.constraint(equalTo: emptyStateView!.trailingAnchor, constant: -SutraSpacing.large),

            messageLabel.centerXAnchor.constraint(equalTo: emptyStateView!.centerXAnchor),
            messageLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: SutraSpacing.small),
            messageLabel.leadingAnchor.constraint(equalTo: emptyStateView!.leadingAnchor, constant: SutraSpacing.large),
            messageLabel.trailingAnchor.constraint(equalTo: emptyStateView!.trailingAnchor, constant: -SutraSpacing.large)
        ])
    }

    private func setupData() {
        playMode = Prefers.shared.lastPlayMode ?? -1
        media = Book.shared.media ?? []
        tableView.reloadData()
        checkMediaStatus()
        updatePlayModeIcon()

        if lastPlayFile == nil {
            playerContainerHeightConstraint.constant = 0
            view.layoutIfNeeded()
        }

        initAudio()
    }

    private func setupAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            NSLog("Audio session error: \(error)")
        }
    }

    private func setupGestures() {
        // Tap gesture to expand/collapse player
        let playerTapGesture = UITapGestureRecognizer(target: self, action: #selector(togglePlayerExpansion))
        playerFooterView.addGestureRecognizer(playerTapGesture)

        // Swipe gestures
        let swipeUpGesture = UISwipeGestureRecognizer(target: self, action: #selector(expandPlayer))
        swipeUpGesture.direction = .up
        playerFooterView.addGestureRecognizer(swipeUpGesture)

        let swipeDownGesture = UISwipeGestureRecognizer(target: self, action: #selector(collapsePlayer))
        swipeDownGesture.direction = .down
        playerFooterView.addGestureRecognizer(swipeDownGesture)
    }

    private func setupAccessibility() {
        isAccessibilityElement = false
        accessibilityLabel = NSLocalizedString("media_player", comment: "Media player")
        accessibilityHint = NSLocalizedString("listen_to_sutra_recitations", comment: "Listen to sutra recitations")

        playerPlayButton?.accessibilityLabel = NSLocalizedString("play_pause", comment: "Play or pause")
        playerPlayButton?.accessibilityHint = NSLocalizedString("play_or_pause_audio", comment: "Play or pause the current audio")

        playerModeButton?.accessibilityLabel = NSLocalizedString("playback_mode", comment: "Playback mode")
        playerModeButton?.accessibilityHint = NSLocalizedString("change_playback_mode", comment: "Change the playback mode")

        playerProgressSlider?.accessibilityLabel = NSLocalizedString("audio_progress", comment: "Audio progress")
        playerProgressSlider?.accessibilityHint = NSLocalizedString("seek_audio_position", comment: "Seek to a specific position in the audio")
    }

    private func setupNavigationBar() {
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationController?.navigationBar.backgroundColor = SutraColors.Semantic.surface(theme: currentTheme)

        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = SutraColors.Semantic.surface(theme: currentTheme)
        appearance.titleTextAttributes = [
            .foregroundColor: SutraColors.Semantic.primary(theme: currentTheme),
            .font: SutraTypography.Typography.title2
        ]
        appearance.largeTitleTextAttributes = [
            .foregroundColor: SutraColors.Semantic.primary(theme: currentTheme),
            .font: SutraTypography.Typography.largeTitle
        ]

        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
        navigationController?.navigationBar.compactAppearance = appearance

        title = NSLocalizedString("media_tab_title", comment: "Listen to Sutras")
    }

    // MARK: - Theme Updates
    private func updateTheme() {
        currentTheme = themeManager.currentTheme
        view.backgroundColor = SutraColors.Semantic.background(theme: currentTheme)
        tableView.backgroundColor = .clear
        playerFooterView?.backgroundColor = SutraColors.Semantic.surface(theme: currentTheme)
        setupNavigationBar()
        updatePlayerAppearance()
    }

    private func updatePlayerAppearance() {
        playerTitleLabel?.textColor = SutraColors.Semantic.primary(theme: currentTheme)
        playerProgressSlider?.minimumTrackTintColor = SutraColors.Semantic.accent(theme: currentTheme)
        playerProgressSlider?.maximumTrackTintColor = SutraColors.Semantic.divider(theme: currentTheme)
        playerProgressLabel?.textColor = SutraColors.Semantic.textSecondary(theme: currentTheme)
        playerDurationLabel?.textColor = SutraColors.Semantic.textSecondary(theme: currentTheme)
        playerPlayButton?.tintColor = SutraColors.Semantic.accent(theme: currentTheme)
        playerModeButton?.tintColor = SutraColors.Semantic.textSecondary(theme: currentTheme)
    }

    // MARK: - Data Management
    @objc private func refreshData() {
        checkMediaStatus()
        refreshControl.endRefreshing()
    }

    private func checkMediaStatus() {
        guard !media.isEmpty else {
            showEmptyState(true)
            return
        }

        showEmptyState(false)

        for group in media {
            guard let files = group["files"] as? [String],
                  let ext = group["extension"] as? String else { continue }

            for file in files {
                if tagStatus[file] != 2 {
                    getFileStatus(file: file, ext: ext) { available in
                        if available {
                            DispatchQueue.main.async {
                                self.tableView.reloadData()
                            }
                        }
                    }
                }
            }
        }
    }

    private func showEmptyState(_ show: Bool) {
        emptyStateView?.isHidden = !show
        tableView.isHidden = show
    }

    // MARK: - Player Management
    private func savePlayerState() {
        // Save current playback state if needed
    }

    private func restorePlayerState() {
        // Restore saved playback state if needed
        if let lastFile = Prefers.shared.lastPlayFile,
           tagStatus[lastFile[1]] == 2 {
            lastPlayFile = lastFile
            // Optionally restore last playing position
        }
    }

    @objc private func togglePlayerExpansion() {
        HapticFeedback.lightImpact()
        if isPlayerExpanded {
            collapsePlayer()
        } else {
            expandPlayer()
        }
    }

    @objc private func expandPlayer() {
        guard !isPlayerExpanded else { return }
        isPlayerExpanded = true

        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0, options: [.curveEaseOut]) {
            self.playerContainerHeightConstraint.constant = 160
            self.view.layoutIfNeeded()
        }

        // Start visualizer animation
        startVisualizerAnimation()
    }

    @objc private func collapsePlayer() {
        guard isPlayerExpanded else { return }
        isPlayerExpanded = false

        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0, options: [.curveEaseOut]) {
            self.playerContainerHeightConstraint.constant = 90
            self.view.layoutIfNeeded()
        }

        // Stop visualizer animation
        stopVisualizerAnimation()
    }

    private func startVisualizerAnimation() {
        guard let visualizerView = visualizerView else { return }

        // Create simple animation effect
        UIView.animate(withDuration: 0.5, delay: 0, options: [.repeat, .autoreverse], animations: {
            visualizerView.transform = CGAffineTransform(scaleX: 1.2, y: 1.0)
        }) { _ in
            visualizerView.transform = .identity
        }
    }

    private func stopVisualizerAnimation() {
        visualizerView?.layer.removeAllAnimations()
        visualizerView?.transform = .identity
    }

    private func showPlayer() {
        guard playerContainerHeightConstraint.constant == 0 else { return }

        UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0, options: [.curveEaseOut]) {
            self.playerContainerHeightConstraint.constant = 90
            self.view.layoutIfNeeded()
        }
    }

    private func hidePlayer() {
        guard playerContainerHeightConstraint.constant > 0 else { return }

        UIView.animate(withDuration: 0.3, animations: {
            self.playerContainerHeightConstraint.constant = 0
            self.view.layoutIfNeeded()
        })
    }

    // MARK: - Animations
    private func animateEntrance() {
        tableView?.alpha = 0
        tableView?.transform = CGAffineTransform(translationX: 0, y: 50)

        UIView.animate(withDuration: 0.6, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0, options: [.curveEaseOut]) {
            self.tableView?.alpha = 1
            self.tableView?.transform = .identity
        }

        if lastPlayFile != nil {
            playerFooterView?.alpha = 0
            playerFooterView?.transform = CGAffineTransform(translationX: 0, y: 100)

            UIView.animate(withDuration: 0.6, delay: 0.3, usingSpringWithDamping: 0.8, initialSpringVelocity: 0, options: [.curveEaseOut]) {
                self.playerFooterView?.alpha = 1
                self.playerFooterView?.transform = .identity
            }
        }
    }

    // MARK: - Button Actions
    @objc private func pressPlayButton(button: UIButton) {
        HapticFeedback.lightImpact()
        if !button.isSelected {
            button.isSelected = true
            if queuePlayer?.currentItem != nil {
                play()
            } else if let lastFile = lastPlayFile {
                play(name: lastFile[0], file: lastFile[1], ext: lastFile[2])
            }
        } else {
            button.isSelected = false
            pause()
        }
    }

    @objc private func pressModeButton(button: UIButton) {
        HapticFeedback.lightImpact()
        showPlayModeMenu()
    }

    private func showPlayModeMenu() {
        let optionMenu = UIAlertController(title: NSLocalizedString("playback_mode", comment: "Playback Mode"), message: nil, preferredStyle: .actionSheet)

        if let presenter = optionMenu.popoverPresentationController {
            presenter.sourceView = playerModeButton
            presenter.sourceRect = playerModeButton.bounds
        }

        // Repeat all
        let repeatAction = UIAlertAction(title: NSLocalizedString("play_mode_repeat", comment: "Repeat All"), style: .default) { _ in
            self.selectMode(mode: -1)
        }
        repeatAction.setValue(UIImage(systemName: "repeat"), forKey: "image")
        optionMenu.addAction(repeatAction)

        // Repeat one
        let repeatOneAction = UIAlertAction(title: NSLocalizedString("play_mode_repeat_one", comment: "Repeat One"), style: .default) { _ in
            self.selectMode(mode: Int.max)
        }
        repeatOneAction.setValue(UIImage(systemName: "repeat.1"), forKey: "image")
        optionMenu.addAction(repeatOneAction)

        // Single play options
        let singlePlayText = NSLocalizedString("play_mode_play_count", comment: "Play %d time(s)")
        for i in 1...6 {
            let action = UIAlertAction(title: String(format: singlePlayText, i), style: .default) { _ in
                self.selectMode(mode: i)
            }
            action.setValue(UIImage(systemName: "\(i).circle"), forKey: "image")
            optionMenu.addAction(action)
        }

        let cancelAction = UIAlertAction(title: NSLocalizedString("cancel", comment: "Cancel"), style: .cancel)
        optionMenu.addAction(cancelAction)

        present(optionMenu, animated: true)
    }

    // MARK: - Audio Control Methods (simplified versions of original)
    private func initAudio() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(audioSessionInterrupted(notification:)),
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance()
        )

        setupNowPlayingInfoCenter()
    }

    @objc private func audioSessionInterrupted(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

        switch type {
        case .began:
            pause()
        case .ended:
            NSLog("Audio interruption ended")
        @unknown default:
            break
        }
    }

    private func play() {
        startAudioSession()
        queuePlayer?.play()
        startPlayerTimer()

        DispatchQueue.main.async {
            self.playerPlayButton.isSelected = true
            self.startVisualizerAnimation()
        }
    }

    private func pause() {
        stopPlayerTimer()
        queuePlayer?.pause()
        stopVisualizerAnimation()

        DispatchQueue.main.async {
            self.playerPlayButton.isSelected = false
        }
    }

    private func isPlaying() -> Bool {
        return queuePlayer != nil && queuePlayer!.rate != 0
    }

    private func startPlayerTimer() {
        stopPlayerTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.updateProgress()
        }
    }

    private func stopPlayerTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func updateProgress() {
        guard let currentItem = queuePlayer?.currentItem else { return }

        let duration = currentItem.duration
        if duration.isNumeric {
            let durationSeconds = Int(duration.seconds)
            let currentTimeSeconds = Int(queuePlayer!.currentTime().seconds)
            let progress = Float(currentTimeSeconds) / Float(durationSeconds)

            DispatchQueue.main.async {
                self.playerProgressLabel.text = self.getMediaDisplayTime(seconds: currentTimeSeconds)
                self.playerDurationLabel.text = self.getMediaDisplayTime(seconds: durationSeconds)
                self.playerProgressSlider.value = progress
            }
        }
    }

    @objc private func progressBarChanged(slider: UISlider, event: UIEvent) {
        guard let currentItem = queuePlayer?.currentItem else { return }
        let duration = currentItem.duration

        guard duration.isNumeric else { return }

        let phase = event.allTouches?.first?.phase
        let seekTime = CMTime(seconds: Double(slider.value) * duration.seconds, preferredTimescale: duration.timescale)

        playerProgressLabel.text = getMediaDisplayTime(seconds: Int(seekTime.seconds))

        if phase == .began {
            isPlayingOnSlideBegan = isPlaying()
            if isPlayingOnSlideBegan {
                pause()
            }
        } else if phase == .ended || phase == .cancelled {
            DispatchQueue.global(qos: .background).async {
                self.queuePlayer?.seek(to: seekTime, toleranceBefore: .zero, toleranceAfter: .zero)
                if self.isPlayingOnSlideBegan {
                    self.play()
                }
            }
        }
    }

    // MARK: - Helper Methods
    private func getMediaDisplayTime(seconds: Int) -> String {
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    private func getFileStatus(file: String, ext: String, completionHandler: @escaping (Bool) -> Void) {
        let req = NSBundleResourceRequest(tags: [file])
        req.loadingPriority = .urgent

        req.conditionallyBeginAccessingResources { available in
            if available {
                if let url = req.bundle.url(forResource: file, withExtension: ext) {
                    self.tagStatus[file] = 2
                    self.rReq[file] = req
                    completionHandler(true)
                } else {
                    self.downloadTagSilently(file, ext: ext)
                    completionHandler(false)
                }
            } else {
                completionHandler(false)
            }
        }
    }

    private func downloadTagSilently(_ tag: String, ext: String) {
        let req = NSBundleResourceRequest(tags: [tag])
        rReq[tag] = req
        req.loadingPriority = .urgent

        req.beginAccessingResources { error in
            if let error = error {
                self.tagStatus[tag] = 0
                self.rReq[tag]?.endAccessingResources()
                self.rReq[tag] = nil
                self.handleDownloadingError(error as NSError)
            } else {
                if let url = req.bundle.url(forResource: tag, withExtension: ext) {
                    self.tagStatus[tag] = 2
                    DispatchQueue.main.async {
                        self.tableView.reloadData()
                    }
                } else {
                    self.tagStatus[tag] = 0
                    self.rReq[tag]?.endAccessingResources()
                    self.rReq[tag] = nil
                }
            }
        }
    }

    private func handleDownloadingError(_ error: NSError) {
        var message: String

        switch error.code {
        case NSBundleResourceRequest.errorCodeOutOfSpace:
            message = NSLocalizedString("download_error_out_of_space", comment: "Storage space insufficient")
        case NSBundleResourceRequest.errorCode.exceededMaximumSize:
            message = NSLocalizedString("download_error_too_big", comment: "File too large")
        case NSBundleResourceRequest.errorCode.invalidTag:
            message = NSLocalizedString("download_error_invalid_tag", comment: "File not found")
        default:
            message = error.localizedDescription
        }

        DispatchQueue.main.async {
            self.showMessage(message)
        }
    }

    private func showMessage(_ message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("ok", comment: "OK"), style: .default))
        present(alert, animated: true)
    }

    private func play(name: String, file: String, ext: String) {
        DispatchQueue.main.async {
            self.playerTitleLabel.text = name
            self.tableView.reloadData()
            self.showPlayer()
        }

        DispatchQueue.global().async {
            guard let req = self.rReq[file],
                  let url = req.bundle.url(forResource: file, withExtension: ext) else {
                DispatchQueue.main.async {
                    self.tagStatus[file] = 0
                    self.rReq[file] = nil
                    self.tableView.reloadData()
                }
                return
            }

            let playItem = AVPlayerItem(url: url)

            if self.queuePlayer == nil {
                self.queuePlayer = AVQueuePlayer()
                self.queuePlayer?.addObserver(self, forKeyPath: "currentItem", options: [.initial, .new], context: nil)
            }

            self.schedulePlayItems(newItem: playItem)
        }
    }

    private func updatePlayModeIcon() {
        let imageName: String
        switch playMode {
        case -1:
            imageName = "repeat"
        case Int.max:
            imageName = "repeat.1"
        case 1...6:
            imageName = "\(playMode).circle"
        default:
            imageName = "repeat"
        }

        DispatchQueue.main.async {
            self.playerModeButton.setImage(UIImage(systemName: imageName), for: .normal)
        }
    }

    private func selectMode(mode: Int) {
        playMode = mode
        updatePlayModeIcon()
        schedulePlayItems()
        Prefers.shared.lastPlayMode = mode
    }

    private func schedulePlayItems(newItem: AVPlayerItem? = nil) {
        DispatchQueue.global().async {
            guard let currentItem = self.queuePlayer?.currentItem else { return }

            self.queuePlayer?.removeAllItems()

            if let newItem = newItem {
                let playItem = AVPlayerItem(asset: currentItem.asset)
                self.queuePlayer?.insert(playItem, after: nil)
                self.lastPlayFile = self.getFileNameAndExtension(item: newItem)
            }

            if !self.isPlaying() && newItem != nil {
                self.play()
            }
        }
    }

    private func getFileNameAndExtension(item: AVPlayerItem?) -> [String]? {
        guard let url = (item?.asset as? AVURLAsset)?.url else { return nil }

        let fileName = url.deletingPathExtension().lastPathComponent
        let fileExtension = url.pathExtension

        for group in media {
            if let files = group["files"] as? [String],
               let names = group["names"] as? [String],
               let index = files.firstIndex(of: fileName) {
                return [names[index], fileName, fileExtension]
            }
        }

        return nil
    }

    private func setupNowPlayingInfoCenter() {
        UIApplication.shared.beginReceivingRemoteControlEvents()

        MPRemoteCommandCenter.shared().playCommand.addTarget { _ in
            self.play()
            self.updateNowPlayingInfoCenter()
            return .success
        }

        MPRemoteCommandCenter.shared().pauseCommand.addTarget { _ in
            self.pause()
            self.updateNowPlayingInfoCenter()
            return .success
        }

        MPRemoteCommandCenter.shared().nextTrackCommand.addTarget { _ in
            self.queuePlayer?.advanceToNextItem()
            self.play()
            self.updateNowPlayingInfoCenter()
            return .success
        }

        MPRemoteCommandCenter.shared().previousTrackCommand.addTarget { _ in
            self.queuePlayer?.seek(to: CMTime.zero)
            self.play()
            self.updateNowPlayingInfoCenter()
            return .success
        }
    }

    private func updateNowPlayingInfoCenter() {
        guard let currentItem = queuePlayer?.currentItem else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = [:]
            return
        }

        let fileInfo = getFileNameAndExtension(item: currentItem)
        let title = fileInfo?[0] ?? ""

        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyPlaybackDuration: currentItem.duration.seconds,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: queuePlayer?.currentTime().seconds ?? 0
        ]
    }

    // MARK: - KVO
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "currentItem" {
            let item = queuePlayer?.currentItem
            let fileInfo = getFileNameAndExtension(item: item)

            if let fileInfo = fileInfo {
                lastPlayFile = fileInfo
                Prefers.shared.lastPlayFile = fileInfo
            }

            DispatchQueue.main.async {
                if let fileInfo = fileInfo {
                    self.playerTitleLabel.text = fileInfo[0]
                    self.showPlayer()
                    self.updatePlayModeIcon()
                } else {
                    self.playerProgressLabel.text = ""
                    self.playerDurationLabel.text = ""
                    self.hidePlayer()
                }

                self.playerPlayButton.isSelected = item != nil && self.isPlaying()
            }
        }
    }

    // MARK: - Table View Data Source
    func numberOfSections(in tableView: UITableView) -> Int {
        return media.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard !media.isEmpty,
              let files = media[section]["files"] as? [String] else { return 0 }
        return files.count
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 60
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let headerCell = tableView.dequeueReusableHeaderFooterView(withIdentifier: "MediaHeaderCell") as? EnhancedMediaHeaderCell,
              let group = media[section] as? [String: Any],
              let name = group["name"] as? String else { return nil }

        headerCell.configure(with: name, theme: currentTheme)
        return headerCell
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let group = media[indexPath.section]
        let files = group["files"] as! [String]
        let names = group["names"] as! [String]
        let tag = files[indexPath.row]
        var name = names[indexPath.row]

        let isDownloaded = tagStatus[tag] == 2
        let identifier = isDownloaded ? "MediaCell" : "MediaDownloadCell"

        guard let cell = tableView.dequeueReusableCell(withIdentifier: identifier, for: indexPath) as? EnhancedMediaCell else {
            return UITableViewCell()
        }

        if isDownloaded {
            cell.configure(with: name, status: .downloaded, theme: currentTheme)
        } else if tagStatus[tag] == 1 {
            let downloadingText = NSLocalizedString("downloading_text", comment: "Downloading...")
            name = name + " - " + downloadingText
            cell.configure(with: name, status: .downloading, theme: currentTheme)
        } else {
            cell.configure(with: name, status: .notDownloaded, theme: currentTheme)
        }

        return cell
    }

    // MARK: - Table View Delegate
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        HapticFeedback.selectionChanged()

        let group = media[indexPath.section]
        let files = group["files"] as! [String]
        let names = group["names"] as! [String]
        let tag = files[indexPath.row]
        let name = names[indexPath.row]
        let ext = group["extension"] as! String

        if tagStatus[tag] == 2 && rReq[tag] != nil {
            play(name: name, file: tag, ext: ext)
            return
        }

        if rReq[tag] != nil {
            NSLog("Ignore, already downloading: \(tag)")
            return
        }

        startDownload(for: tag, name: name, ext: ext, indexPath: indexPath)
    }

    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Can edit downloaded items
        let group = media[indexPath.section]
        let files = group["files"] as! [String]
        let tag = files[indexPath.row]
        return tagStatus[tag] == 2
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let group = media[indexPath.section]
            let files = group["files"] as! [String]
            let tag = files[indexPath.row]

            if rReq[tag] != nil {
                if let lastFile = lastPlayFile, lastFile[1] == tag {
                    pause()
                    lastPlayFile = nil
                    schedulePlayItems()
                    hidePlayer()
                } else if playMode <= 0 {
                    pause()
                    schedulePlayItems()
                }

                rReq[tag]?.endAccessingResources()
                rReq[tag] = nil
                tagStatus[tag] = 0
                tableView.reloadData()
            }
        }
    }

    private func startDownload(for tag: String, name: String, ext: String, indexPath: IndexPath) {
        let req = NSBundleResourceRequest(tags: [tag])
        rReq[tag] = req
        req.loadingPriority = .urgent

        var progressView: UIProgressView?
        if tagStatus[tag] == 0 || tagStatus[tag] == nil {
            tagStatus[tag] = 1

            DispatchQueue.main.async {
                if let cell = self.tableView.cellForRow(at: indexPath) as? EnhancedMediaCell {
                    let downloadingText = NSLocalizedString("downloading_text", comment: "Downloading...")
                    cell.configure(with: name + " - " + downloadingText, status: .downloading, theme: self.currentTheme)

                    progressView = UIProgressView()
                    progressView?.trackTintColor = SutraColors.Semantic.divider(theme: currentTheme)
                    progressView?.progressTintColor = SutraColors.Semantic.accent(theme: currentTheme)
                    progressView?.observedProgress = req.progress
                    cell.addProgressView(progressView!)
                }
            }
        }

        req.beginAccessingResources { error in
            DispatchQueue.main.async {
                progressView?.removeFromSuperview()

                if let error = error {
                    self.tagStatus[tag] = 0
                    self.rReq[tag]?.endAccessingResources()
                    self.rReq[tag] = nil
                    self.handleDownloadingError(error as NSError)

                    if let cell = self.tableView.cellForRow(at: indexPath) as? EnhancedMediaCell {
                        let downloadFailedText = NSLocalizedString("download_failed", comment: "Download failed")
                        cell.configure(with: name + " - " + downloadFailedText, status: .error, theme: self.currentTheme)
                    }
                } else {
                    guard let url = req.bundle.url(forResource: tag, withExtension: ext) else {
                        if let cell = self.tableView.cellForRow(at: indexPath) as? EnhancedMediaCell {
                            let downloadFailedText = NSLocalizedString("download_failed", comment: "Download failed")
                            cell.configure(with: name + " -- " + downloadFailedText, status: .error, theme: self.currentTheme)
                        }
                        return
                    }

                    self.tagStatus[tag] = 2
                    self.tableView.reloadData()
                    self.play(name: name, file: tag, ext: ext)
                }
            }
        }
    }

    deinit {
        queuePlayer?.removeObserver(self, forKeyPath: "currentItem")
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Enhanced Media Cells
private class EnhancedMediaHeaderCell: UITableViewHeaderFooterView {
    private let titleLabel = UILabel()
    private let containerView = UIView()
    private var currentTheme: SutraTheme = .light

    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    private func setupUI() {
        contentView.addSubview(containerView)
        containerView.addSubview(titleLabel)

        containerView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.font = SutraTypography.Typography.headline
        titleLabel.textColor = SutraColors.Semantic.primary(theme: .light)
        titleLabel.numberOfLines = 0

        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: SutraSpacing.small),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: SutraSpacing.medium),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -SutraSpacing.medium),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -SutraSpacing.xs),

            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            titleLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
    }

    func configure(with title: String, theme: SutraTheme) {
        currentTheme = theme
        titleLabel.text = title
        titleLabel.textColor = SutraColors.Semantic.primary(theme: theme)
        containerView.backgroundColor = SutraColors.Semantic.surface(theme: theme)
    }
}

private class EnhancedMediaCell: UITableViewCell {
    enum DownloadStatus {
        case notDownloaded
        case downloading
        case downloaded
        case error
    }

    private let containerView = UIView()
    private let titleLabel = UILabel()
    private let statusImageView = UIImageView()
    private let progressContainerView = UIView()

    var currentTheme: SutraTheme = .light

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    private func setupUI() {
        selectionStyle = .none
        backgroundColor = .clear

        contentView.addSubview(containerView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(statusImageView)
        containerView.addSubview(progressContainerView)

        containerView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        statusImageView.translatesAutoresizingMaskIntoConstraints = false
        progressContainerView.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.font = SutraTypography.Typography.body
        titleLabel.numberOfLines = 0

        statusImageView.contentMode = .scaleAspectFit
        statusImageView.tintColor = SutraColors.Semantic.textTertiary(theme: .light)

        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: SutraSpacing.xs),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: SutraSpacing.medium),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -SutraSpacing.medium),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -SutraSpacing.xs),

            statusImageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            statusImageView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            statusImageView.widthAnchor.constraint(equalToConstant: 24),
            statusImageView.heightAnchor.constraint(equalToConstant: 24),

            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: SutraSpacing.small),
            titleLabel.leadingAnchor.constraint(equalTo: statusImageView.trailingAnchor, constant: SutraSpacing.medium),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -SutraSpacing.small),
            titleLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -SutraSpacing.small),

            progressContainerView.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            progressContainerView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            progressContainerView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            progressContainerView.heightAnchor.constraint(equalToConstant: 2)
        ])
    }

    func configure(with title: String, status: DownloadStatus, theme: SutraTheme) {
        currentTheme = theme
        titleLabel.text = title

        containerView.backgroundColor = SutraColors.Semantic.card(theme: theme)
        containerView.layer.cornerRadius = SutraSpacing.smallCornerRadius

        switch status {
        case .downloaded:
            titleLabel.textColor = SutraColors.Semantic.primary(theme: theme)
            statusImageView.image = UIImage(systemName: "play.circle.fill")
            statusImageView.tintColor = SutraColors.Semantic.accent(theme: theme)
        case .downloading:
            titleLabel.textColor = SutraColors.Semantic.textSecondary(theme: theme)
            statusImageView.image = UIImage(systemName: "arrow.down.circle")
            statusImageView.tintColor = SutraColors.Semantic.textSecondary(theme: theme)
        case .notDownloaded:
            titleLabel.textColor = SutraColors.Semantic.textTertiary(theme: theme)
            statusImageView.image = UIImage(systemName: "icloud.and.arrow.down")
            statusImageView.tintColor = SutraColors.Semantic.textTertiary(theme: theme)
        case .error:
            titleLabel.textColor = SutraColors.Light.favorite
            statusImageView.image = UIImage(systemName: "exclamationmark.triangle")
            statusImageView.tintColor = SutraColors.Light.favorite
        }
    }

    func addProgressView(_ progressView: UIProgressView) {
        progressContainerView.subviews.forEach { $0.removeFromSuperview() }
        progressContainerView.addSubview(progressView)

        progressView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            progressView.leadingAnchor.constraint(equalTo: progressContainerView.leadingAnchor),
            progressView.trailingAnchor.constraint(equalTo: progressContainerView.trailingAnchor),
            progressView.topAnchor.constraint(equalTo: progressContainerView.topAnchor),
            progressView.bottomAnchor.constraint(equalTo: progressContainerView.bottomAnchor)
        ])
    }

    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)

        UIView.animate(withDuration: 0.1) {
            self.containerView.backgroundColor = highlighted ?
                SutraColors.Semantic.primary(theme: self.currentTheme).withAlphaComponent(0.1) :
                SutraColors.Semantic.card(theme: self.currentTheme)
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        titleLabel.text = nil
        statusImageView.image = nil
        progressContainerView.subviews.forEach { $0.removeFromSuperview() }
    }
}

private class EnhancedMediaDownloadCell: EnhancedMediaCell {
    // Inherits all functionality from EnhancedMediaCell
    // Can add download-specific UI elements here if needed
}