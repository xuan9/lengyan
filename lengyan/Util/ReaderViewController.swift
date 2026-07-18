import UIKit
import Combine

final class ReaderViewController: UIViewController, UIScrollViewDelegate {

    private let contentView = UIScrollView()
    private var textViews: [UITextView] = []
    private var content: NSAttributedString
    private let chapter: Int
    private let restoreOffset: CGFloat?
    private let restoreCharacterIndex: Int?
    private var hasRestoredOffset = false
    private let readingCheckpoint = ReadingCheckpointGate()
    private var isReaderVisible = false
    private var needsPreferenceRebuild = false
    private var paginatedSize = CGSize.zero
    private var pendingLayoutCharacterIndex: Int?
    private var isRepaginating = false
    private var currentCharacterAnchor: Int?
    private var layoutRepaginationGeneration = 0
    /// A programmatic paging animation can be between two physical pages when
    /// the app backgrounds. Keep its destination separate from the persisted
    /// anchor until UIScrollView confirms that the animation finished.
    private var pendingScrollingAnimationCharacterAnchor: Int?
    
    // 导航栏双行标题：卷名（醒目）+ 页码（极淡，始终可见）
    private let titleLabel = UILabel()
    private let pageLabel = UILabel()

    // 🔊 听经一体化播放器观察与按钮
    private var playButton: UIBarButtonItem?
    private var playCancellable: AnyCancellable?
    private var downloadStatusCancellable: AnyCancellable?
    private var downloadProgressCancellable: AnyCancellable?
    // 下载等待圆环（复刻 mini-player 的 ZenProgressRing 视觉语言）
    private var progressTrackLayer: CAShapeLayer?
    private var progressRingLayer: CAShapeLayer?


    init(
        title: String,
        content: NSAttributedString,
        chapter: Int,
        restoreOffset: CGFloat? = nil,
        restoreCharacterIndex: Int? = nil
    ) {
        self.content = content
        self.chapter = chapter
        self.restoreOffset = restoreOffset
        self.restoreCharacterIndex = restoreCharacterIndex
        super.init(nibName: nil, bundle: nil)
        self.title = title
      }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.accessibilityIdentifier = "reader.chapter"
        view.backgroundColor = SutraDesignTokens.shared.color(for: .background)

        self.navigationController?.hidesBarsOnTap = true;

        // 返回按钮
        let secondaryColor = SutraDesignTokens.shared.color(for: .textSecondary)
        let backButton = UIBarButtonItem(image: UIImage(systemName: "chevron.left"), style: .plain, target: self, action: #selector(close))
        backButton.tintColor = secondaryColor
        if #available(iOS 26.0, *) {
            backButton.hidesSharedBackground = true  // 移除 iOS 26 Liquid Glass 按钮背景
        }
        self.navigationItem.leftBarButtonItem = backButton

        // 导航栏外观 — 与内容同色，按钮完全无背景色块
        let navColor = SutraDesignTokens.shared.color(for: .background)
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = navColor
        appearance.shadowColor = .clear
        appearance.shadowImage = UIImage()
        
        // 设置标题为 24pt
        appearance.titleTextAttributes = [
            .foregroundColor: SutraDesignTokens.shared.color(for: .textPrimary),
            .font: SutraTypographyManager.shared.uiFont(for: .navigationTitle, weight: .regular).withSize(24)
        ]
        let btnAppearance = UIBarButtonItemAppearance(style: .plain)
        btnAppearance.normal.backgroundImage = UIImage()
        btnAppearance.normal.titleTextAttributes = [.foregroundColor: secondaryColor]
        btnAppearance.highlighted.backgroundImage = UIImage()
        btnAppearance.highlighted.titleTextAttributes = [.foregroundColor: secondaryColor.withAlphaComponent(0.5)]
        btnAppearance.disabled.backgroundImage = UIImage()
        btnAppearance.focused.backgroundImage = UIImage()
        appearance.buttonAppearance = btnAppearance
        appearance.doneButtonAppearance = btnAppearance
        appearance.setBackIndicatorImage(UIImage(), transitionMaskImage: UIImage())

        if let navBar = self.navigationController?.navigationBar {
            navBar.standardAppearance = appearance
            navBar.compactAppearance = appearance
            navBar.scrollEdgeAppearance = appearance
            navBar.isTranslucent = false
            navBar.tintColor = secondaryColor
            navBar.setBackgroundImage(UIImage(), for: .default)
            navBar.shadowImage = UIImage()
            navBar.barTintColor = navColor
            navBar.backgroundColor = navColor
        }

        setupTitleView()
        setupContentView()
        setupPlayButton()
        setupThemeObserver()
        setupFontSizeObserver()
        setupApplicationLifecycleObservers()
    }

    // MARK: - 导航栏双行标题（卷名 + 页码）

    private func setupTitleView() {
        titleLabel.text = self.title
        titleLabel.font = SutraTypographyManager.shared.uiFont(for: .navigationTitle, weight: .regular).withSize(24)
        titleLabel.textColor = SutraDesignTokens.shared.color(for: .textPrimary)
        titleLabel.textAlignment = .center
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.8

        pageLabel.font = SutraTypographyManager.shared.uiFont(for: .uiSmall, weight: .light).withSize(11)
        pageLabel.textColor = SutraDesignTokens.shared.color(for: .textSecondary).withAlphaComponent(0.7)
        pageLabel.textAlignment = .center
        pageLabel.accessibilityIdentifier = "reader.pageLabel"
        // 用一个空格占位：保证 titleView 安装时就预留好页码行的高度，
        // 否则导航栏会按「无页码行」缓存尺寸，后续填入文字也不重新布局、页码被裁掉
        pageLabel.text = " "

        let stack = UIStackView(arrangedSubviews: [titleLabel, pageLabel])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 1
        stack.isUserInteractionEnabled = false
        self.navigationItem.titleView = stack

        updatePageLabel()
    }

    /// 计算当前页 / 总页数（页码从 1 起，按 contentOffset 物理分页）
    private func currentPageInfo() -> (page: Int, total: Int)? {
        let total = textViews.count
        let pageWidth = paginatedSize.width
        guard total > 0, pageWidth > 0 else { return nil }
        let page = Int(round(contentView.contentOffset.x / pageWidth)) + 1
        let clamped = min(max(page, 1), total)
        return (clamped, total)
    }

    private func updatePageLabel() {
        let info = currentPageInfo()
        if let info = info {
            pageLabel.text = "\(info.page) / \(info.total)"
        } else {
            pageLabel.text = " " // 始终保留页码行高度，避免导航栏缓存错误尺寸
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.tabBarController?.tabBar.isHidden = true
        if #available(iOS 18.0, *) {
            self.tabBarController?.setTabBarHidden(true, animated: false)
        }
        self.navigationController?.setNavigationBarHidden(false, animated: false)
        self.navigationController?.hidesBarsOnSwipe = false
        self.navigationController?.hidesBarsOnTap = true
        self.navigationController?.barHideOnTapGestureRecognizer.isEnabled = true
        // 核心修复1：防止点击隐藏标题栏的手势吞噬长按事件
        self.navigationController?.barHideOnTapGestureRecognizer.cancelsTouchesInView = false
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        isReaderVisible = true

        if needsPreferenceRebuild,
           rebuildReaderContentPreservingPosition() {
            needsPreferenceRebuild = false
            applyThemeAppearance(animated: false)
        }

        showSwipeGuideIfNeeded()
        // 布局全部就绪后再刷新一次页码，确保首次进入即显示
        updatePageLabel()
        resumeReadingCheckpointIfNeeded()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Capture against the still-stable reader geometry before restoring
        // surrounding navigation chrome changes the available page size.
        pauseReadingCheckpointIfNeeded()
        self.tabBarController?.tabBar.isHidden = false
        if #available(iOS 18.0, *) {
            self.tabBarController?.setTabBarHidden(false, animated: false)
        }
        self.navigationController?.hidesBarsOnTap = false
        isReaderVisible = false
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let layoutSize = contentView.bounds.size
        guard hasUsablePaginationSize(layoutSize) else { return }

        if !textViews.isEmpty {
            guard paginationSizeChanged(to: layoutSize) else { return }
            if pendingLayoutCharacterIndex == nil {
                pendingLayoutCharacterIndex = preferredCharacterAnchorForRepagination()
            }
            scheduleLayoutRepagination()
            return
        }

        setupReader()

        // Prefer a character anchor because it survives width/font changes;
        // keep the legacy pixel offset only as an upgrade fallback.
        if !hasRestoredOffset {
            let restoredOffset: CGFloat
            if let characterIndex = restoreCharacterIndex, characterIndex > 0 {
                let safeCharacterIndex = clampedCharacterLocation(characterIndex)
                currentCharacterAnchor = safeCharacterIndex
                let page = pageIndex(containingCharacterAt: safeCharacterIndex)
                restoredOffset = normalizedProgressOffset(
                    CGFloat(page) * contentView.bounds.width
                )
            } else if let offset = restoreOffset, offset > 0 {
                restoredOffset = normalizedProgressOffset(offset)
            } else {
                restoredOffset = 0
            }
            contentView.setContentOffset(CGPoint(x: restoredOffset, y: 0), animated: false)
            if currentCharacterAnchor == nil {
                currentCharacterAnchor = currentVisibleCharacterLocation()
            }
            hasRestoredOffset = true
            if restoredOffset > 0 {
                showResumeToast()
            }
        }

        // 分页布局完成后，填入初始页码
        updatePageLabel()
    }

    override func viewWillTransition(
        to size: CGSize,
        with coordinator: UIViewControllerTransitionCoordinator
    ) {
        if !textViews.isEmpty {
            // Capture against the old pagination before Auto Layout changes the
            // scroll-view width. The new page number may differ after reflow,
            // but the visible scripture character remains stable. If the user
            // has already asked to return to page one, preserve that intent
            // across a rotation instead of restoring the page being left.
            pendingLayoutCharacterIndex = preferredCharacterAnchorForRepagination()
        }
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: nil) { [weak self] context in
            guard let self else { return }
            // A cancelled/no-op transition does not reach the size-change path
            // in viewDidLayoutSubviews, so do not leave an old anchor pending.
            if context.isCancelled
                || !self.paginationSizeChanged(to: self.contentView.bounds.size) {
                self.pendingLayoutCharacterIndex = nil
            }
        }
    }

    @objc func close(){
        self.navigationController?.popViewController(animated: true)
    }

    @objc private func goToFirstPage() {
        if abs(contentView.contentOffset.x) <= 0.5 {
            pendingScrollingAnimationCharacterAnchor = nil
            currentCharacterAnchor = 0
            contentView.setContentOffset(.zero, animated: false)
            confirmReadingAndSaveProgress()
        } else {
            pendingScrollingAnimationCharacterAnchor = 0
            contentView.setContentOffset(.zero, animated: true)
        }
        hasRestoredOffset = true
        updateRightBarButtonItems()
    }

    // MARK: - UIScrollViewDelegate

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        // A direct gesture cancels/replaces any programmatic destination. The
        // drag/deceleration callbacks below will establish the actual anchor.
        pendingScrollingAnimationCharacterAnchor = nil
        // Confirm at gesture start so an immediate back/background while the
        // scroll view is still decelerating cannot discard explicit intent.
        confirmReadingAndSaveProgress()
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        pendingLayoutCharacterIndex = nil
        currentCharacterAnchor = currentVisibleCharacterLocation()
        confirmReadingAndSaveProgress()
    }

    func scrollViewDidEndDragging(
        _ scrollView: UIScrollView,
        willDecelerate decelerate: Bool
    ) {
        guard !decelerate else { return }
        pendingLayoutCharacterIndex = nil
        currentCharacterAnchor = currentVisibleCharacterLocation()
        confirmReadingAndSaveProgress()
    }

    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        pendingLayoutCharacterIndex = nil
        currentCharacterAnchor = pendingScrollingAnimationCharacterAnchor
            ?? currentVisibleCharacterLocation()
        pendingScrollingAnimationCharacterAnchor = nil
        confirmReadingAndSaveProgress()
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if let guide = self.view.viewWithTag(9988) {
            UIView.animate(withDuration: 0.3, animations: {
                guide.alpha = 0
            }) { _ in
                guide.removeFromSuperview()
            }
            Prefers.shared.hasSeenSwipeGuide = true
        }

        // 翻页时实时刷新导航栏页码
        updatePageLabel()
    }

    // MARK: - Progress

    private func confirmReadingAndSaveProgress() {
        readingCheckpoint.commit { [weak self] in
            self?.saveProgress()
        }
    }

    private func saveProgress() {
        guard
            readingCheckpoint.isConfirmed,
            isReaderVisible,
            !isRepaginating,
            !paginationSizeChanged(to: contentView.bounds.size)
        else { return }
        let characterIndex: Int
        if pendingScrollingAnimationCharacterAnchor != nil
            || contentView.isTracking
            || contentView.isDragging
            || contentView.isDecelerating {
            // Lifecycle callbacks can arrive before scrollViewDidEnd…; keep the
            // character anchor aligned with the physical page/offset being
            // persisted. A pending programmatic destination is not current
            // until scrollViewDidEndScrollingAnimation fires.
            characterIndex = currentVisibleCharacterLocation()
            currentCharacterAnchor = characterIndex
            pendingLayoutCharacterIndex = nil
        } else {
            characterIndex = currentCharacterAnchor
                ?? currentVisibleCharacterLocation()
        }
        Prefers.shared.recordChapterReading(
            chapter: chapter,
            offset: normalizedProgressOffset(contentView.contentOffset.x),
            characterIndex: characterIndex,
            pageIndex: currentPageInfo().map { $0.page - 1 }
        )
    }

    private func normalizedProgressOffset(_ offset: CGFloat) -> CGFloat {
        let pageWidth = paginatedSize.width
        let maximumOffset = max(
            contentView.contentSize.width - pageWidth,
            0
        )
        return ReadingResumeResolver.snappedChapterOffset(
            offset,
            pageWidth: pageWidth,
            maximumOffset: maximumOffset
        )
    }

    private func setupApplicationLifecycleObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    @objc private func applicationWillResignActive() {
        guard isReaderVisible else { return }
        pauseReadingCheckpointIfNeeded()
    }

    @objc private func applicationDidEnterBackground() {
        guard isReaderVisible else { return }
        pauseReadingCheckpointIfNeeded()
    }

    @objc private func applicationDidBecomeActive() {
        resumeReadingCheckpointIfNeeded()
    }

    private func resumeReadingCheckpointIfNeeded() {
        guard
            isReaderVisible,
            UIApplication.shared.applicationState == .active
        else { return }
        // Only foreground time counts toward passive-reading confirmation.
        readingCheckpoint.resume { [weak self] in
            guard let self, self.isReaderVisible else { return }
            self.saveProgress()
        }
    }

    private func pauseReadingCheckpointIfNeeded() {
        readingCheckpoint.pause { [weak self] in
            self?.saveProgress()
        }
    }

    private func setupContentView() {
        contentView.backgroundColor = SutraDesignTokens.shared.color(for: .background)
        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.showsVerticalScrollIndicator = false
        contentView.showsHorizontalScrollIndicator = false
        contentView.isPagingEnabled = true
        contentView.alwaysBounceHorizontal = true
        contentView.alwaysBounceVertical = false
        contentView.bounces = true
        // 核心修复2：取消 ScrollView 对触摸事件的延迟拦截，让长按能瞬间传递到 UITextView
        contentView.delaysContentTouches = false
        contentView.delegate = self
        view.addSubview(contentView)

        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            contentView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            contentView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor)
        ])
    }

    private func setupReader() {

        // 2
        let textStorage = NSTextStorage(attributedString: content)

        // 3
        let textLayout = NSLayoutManager()
        textStorage.addLayoutManager(textLayout)

        let viewSize = contentView.bounds.size
        // 自适应 margins：iPad 上留出更宽的呼吸空间
        let margin = SutraAdaptiveLayout.readingHorizontalInsets(
            containerWidth: viewSize.width,
            containerHeight: viewSize.height
        )
        // 🌿 核心改造：将上下 margins (32pt) 从 textContainerInset 中剥离，改在 UITextView 的 Frame 层面进行约束偏移。这使得 UITextView 的 contentSize.height 严格等于 bounds.height，从物理底层彻底消灭垂直滚动，同时不破坏原生文本选择的 hit-test coordinate space
        let textInsets = UIEdgeInsets(top: 0, left: margin, bottom: 0, right: margin)
        
        // 1
        var index: Int = 0
        var glyphRange: Int = 0
        var numberOfGlyphs: Int = 0
 
        repeat {
            // 2: textContainer 尺寸与 UITextView 的物理 bounds 完全一致，确保 Touch coordinate 完美对齐，原生选择引擎畅行无阻
            let containerSize = CGSize(
                width: viewSize.width,
                height: viewSize.height - 64
            )
            let textContainer = NSTextContainer(size: containerSize)
            textLayout.addTextContainer(textContainer)

            // 3: UITextView 的 Frame 向上收缩 32pt，高度减少 64pt。视觉效果与 Inset 方式完全一致，但完美杜绝了滑动空间
            let textViewFrame = CGRect(
                x: CGFloat(index) * viewSize.width,
                y: 32,
                width: viewSize.width,
                height: viewSize.height - 64
            )
 
            // 4
            let textView = UITextView(
                frame: textViewFrame,
                textContainer: textContainer
            )

            // 5
            textView.backgroundColor = SutraDesignTokens.shared.color(for: .background)
            textView.isEditable = false
            textView.isSelectable = true
            textView.textContainerInset = textInsets
            textView.showsVerticalScrollIndicator = false
            textView.showsHorizontalScrollIndicator = false
            // 核心修复3：必须开启 isScrollEnabled！这是击败外部手势拦截、激活原生文本选择引擎的唯一钥匙
            textView.isScrollEnabled = true
            textView.bounces = false
            textView.bouncesZoom = false
            textView.isUserInteractionEnabled = true

            // 6
            textViews.append(textView)
            contentView.addSubview(textView)

            // 7
            index += 1
            glyphRange = NSMaxRange(textLayout.glyphRange(for: textContainer))
            numberOfGlyphs = textLayout.numberOfGlyphs
        } while glyphRange < numberOfGlyphs - 1 // 8

        contentView.contentSize = CGSize(
            width: viewSize.width * CGFloat(textViews.count),
            height: viewSize.height
        )
        paginatedSize = viewSize
    }

    // MARK: - Font Size Updates

    private func setupFontSizeObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(fontSizeDidChange),
            name: .fontSizeDidChange,
            object: nil
        )
    }

    /// Re-paginate the open volume immediately while keeping the first visible
    /// character on screen. A page number alone is not stable when font metrics
    /// change, so the character location is used as the restore anchor.
    @objc private func fontSizeDidChange() {
        guard isReaderVisible else {
            needsPreferenceRebuild = true
            return
        }

        if rebuildReaderContentPreservingPosition() {
            confirmReadingAndSaveProgress()
        } else {
            needsPreferenceRebuild = true
        }
    }

    @discardableResult
    private func rebuildReaderContentPreservingPosition() -> Bool {
        let characterLocation = preferredCharacterAnchorForRepagination()
        return rebuildReaderContent(
            preservingCharacterAt: characterLocation,
            refreshAttributedContent: true
        )
    }

    @discardableResult
    private func rebuildReaderContent(
        preservingCharacterAt characterLocation: Int,
        refreshAttributedContent: Bool
    ) -> Bool {
        guard
            isViewLoaded,
            hasUsablePaginationSize(contentView.bounds.size),
            !isRepaginating
        else {
            return false
        }

        isRepaginating = true
        defer { isRepaginating = false }

        let safeCharacterLocation = clampedCharacterLocation(characterLocation)
        if refreshAttributedContent {
            content = Book.shared.getSutraAttributeString(text: content.string)
        }

        textViews.forEach { $0.removeFromSuperview() }
        textViews.removeAll()
        pendingScrollingAnimationCharacterAnchor = nil
        contentView.contentOffset = .zero
        contentView.contentSize = .zero
        setupReader()

        let targetPage = pageIndex(containingCharacterAt: safeCharacterLocation)
        let targetOffset = normalizedProgressOffset(
            CGFloat(targetPage) * contentView.bounds.width
        )
        contentView.setContentOffset(CGPoint(x: targetOffset, y: 0), animated: false)
        currentCharacterAnchor = safeCharacterLocation
        hasRestoredOffset = true
        updatePageLabel()
        return true
    }

    private func currentVisibleCharacterLocation() -> Int {
        let pageWidth = paginatedSize.width
        guard !textViews.isEmpty, pageWidth > 0 else { return 0 }
        let page = min(
            max(Int(round(contentView.contentOffset.x / pageWidth)), 0),
            textViews.count - 1
        )
        return characterRange(for: textViews[page]).location
    }

    private func clampedCharacterLocation(_ location: Int) -> Int {
        min(max(location, 0), max(content.length - 1, 0))
    }

    private func hasUsablePaginationSize(_ size: CGSize) -> Bool {
        size.width.isFinite && size.width > 0
            && size.height.isFinite && size.height > 64
    }

    /// Coalesces the many intermediate bounds emitted while an iPad split-view
    /// divider or rotation animation is moving. Progress remains protected by
    /// the stale-geometry guard until the final pagination is ready.
    private func scheduleLayoutRepagination() {
        layoutRepaginationGeneration &+= 1
        let generation = layoutRepaginationGeneration
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self, generation == self.layoutRepaginationGeneration else {
                return
            }
            self.repaginateForCurrentLayoutIfNeeded()
        }
    }

    private func repaginateForCurrentLayoutIfNeeded() {
        let layoutSize = contentView.bounds.size
        guard hasUsablePaginationSize(layoutSize) else { return }
        guard paginationSizeChanged(to: layoutSize) else {
            pendingLayoutCharacterIndex = nil
            return
        }

        let characterIndex = pendingLayoutCharacterIndex
            ?? preferredCharacterAnchorForRepagination()
        pendingLayoutCharacterIndex = nil
        if rebuildReaderContent(
            preservingCharacterAt: characterIndex,
            refreshAttributedContent: false
        ) {
            saveProgress()
        }
    }

    private func paginationSizeChanged(to size: CGSize) -> Bool {
        guard hasUsablePaginationSize(size), hasUsablePaginationSize(paginatedSize) else {
            return true
        }
        return abs(size.width - paginatedSize.width) > 0.5
            || abs(size.height - paginatedSize.height) > 0.5
    }

    /// A pending programmatic destination represents the user's latest intent.
    /// Repagination is instantaneous, so complete that intent rather than
    /// restoring the physical page sampled midway through its animation.
    private func preferredCharacterAnchorForRepagination() -> Int {
        if contentView.isTracking
            || contentView.isDragging
            || contentView.isDecelerating {
            return currentVisibleCharacterLocation()
        }
        return pendingScrollingAnimationCharacterAnchor
            ?? currentCharacterAnchor
            ?? currentVisibleCharacterLocation()
    }

    private func pageIndex(containingCharacterAt location: Int) -> Int {
        guard !textViews.isEmpty else { return 0 }
        for (index, textView) in textViews.enumerated() {
            let range = characterRange(for: textView)
            if NSLocationInRange(location, range) {
                return index
            }
        }
        return textViews.count - 1
    }

    private func characterRange(for textView: UITextView) -> NSRange {
        let glyphRange = textView.layoutManager.glyphRange(for: textView.textContainer)
        return textView.layoutManager.characterRange(
            forGlyphRange: glyphRange,
            actualGlyphRange: nil
        )
    }

    // MARK: - Toast

    private func showResumeToast() {
        let total = textViews.count
        var pageText = ""
        if total > 0, paginatedSize.width > 0 {
            let page = Int(round(contentView.contentOffset.x / paginatedSize.width)) + 1
            pageText = " [\(page)/\(total)]"
        }
        
        let toast = UILabel()
        toast.text = L10n.str("reader_resume_progress") + pageText
        toast.font = SutraTypographyManager.shared.uiFont(for: .uiSmall, weight: .regular)
        toast.textColor = SutraDesignTokens.shared.color(for: .textSecondary)
        toast.textAlignment = .center
        toast.backgroundColor = SutraDesignTokens.shared.color(for: .background).withAlphaComponent(0.9)
        toast.layer.cornerRadius = 12
        toast.clipsToBounds = true

        let toastHeight: CGFloat = 36
        // 稍微加宽一点以容纳页码文字
        let toastWidth: CGFloat = 180
        
        // 沉入底部安全区：如果是全面屏，放入 34pt 的安全区内；非全面屏则距离底部 24pt
        let bottomPadding: CGFloat = view.safeAreaInsets.bottom > 0 ? 12 : 24
        toast.frame = CGRect(
            x: (view.bounds.width - toastWidth) / 2,
            y: view.bounds.height - toastHeight - bottomPadding,
            width: toastWidth,
            height: toastHeight
        )
        toast.alpha = 0
        view.addSubview(toast)

        UIView.animate(withDuration: 0.3, animations: {
            toast.alpha = 1
        }) { _ in
            UIView.animate(withDuration: 0.5, delay: 1.5, options: [], animations: {
                toast.alpha = 0
            }) { _ in
                toast.removeFromSuperview()
            }
        }
    }

    private func showSwipeGuideIfNeeded() {
        guard !Prefers.shared.hasSeenSwipeGuide else { return }
        // 快照/UITest 模式跳过翻页引导，保证截图干净（不出现「左右滑动翻页」遮罩）
        let args = ProcessInfo.processInfo.arguments
        if args.contains("--snapshot-mode") || args.contains("--uitesting") {
            Prefers.shared.hasSeenSwipeGuide = true
            return
        }

        let guideView = UIView(frame: view.bounds)
        guideView.tag = 9988
        guideView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        guideView.backgroundColor = SutraDesignTokens.shared.color(for: .overlay).withAlphaComponent(0.4)
        guideView.alpha = 0
        
        let card = UIView()
        card.backgroundColor = SutraDesignTokens.shared.color(for: .background).withAlphaComponent(0.95)
        card.layer.cornerRadius = 16
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.08
        card.layer.shadowOffset = CGSize(width: 0, height: 4)
        card.layer.shadowRadius = 12
        card.translatesAutoresizingMaskIntoConstraints = false
        guideView.addSubview(card)
        
        let textLabel = UILabel()
        let isSimplified = Book.shared.isSimplifiedChinese
        textLabel.text = isSimplified ? "←  左右滑动翻页  →" : "←  左右滑動翻頁  →"
        textLabel.textColor = SutraDesignTokens.shared.color(for: .textPrimary)
        textLabel.font = SutraTypographyManager.shared.uiFont(for: .uiHeading, weight: .regular).withSize(18)
        textLabel.textAlignment = .center
        textLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(textLabel)
        
        let dismissLabel = UILabel()
        dismissLabel.text = isSimplified ? "轻触进入阅读" : "輕觸進入閱讀"
        dismissLabel.textColor = SutraDesignTokens.shared.color(for: .textSecondary)
        dismissLabel.font = SutraTypographyManager.shared.uiFont(for: .uiCaption, weight: .light).withSize(13)
        dismissLabel.textAlignment = .center
        dismissLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(dismissLabel)
        
        view.addSubview(guideView)
        
        NSLayoutConstraint.activate([
            card.centerXAnchor.constraint(equalTo: guideView.centerXAnchor),
            card.centerYAnchor.constraint(equalTo: guideView.centerYAnchor),
            card.widthAnchor.constraint(equalToConstant: 240),
            card.heightAnchor.constraint(equalToConstant: 120),
            
            textLabel.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            textLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 32),
            textLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            textLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            
            dismissLabel.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            dismissLabel.topAnchor.constraint(equalTo: textLabel.bottomAnchor, constant: 16),
            dismissLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            dismissLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16)
        ])
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissSwipeGuide(_:)))
        guideView.addGestureRecognizer(tap)
        
        let pan = UIPanGestureRecognizer(target: self, action: #selector(dismissSwipeGuide(_:)))
        guideView.addGestureRecognizer(pan)
        
        UIView.animate(withDuration: 0.4) {
            guideView.alpha = 1
        }
    }
    
    @objc private func dismissSwipeGuide(_ gesture: UIGestureRecognizer) {
        guard let guideView = gesture.view else { return }
        Prefers.shared.hasSeenSwipeGuide = true
        
        UIView.animate(withDuration: 0.3, animations: {
            guideView.alpha = 0
        }) { _ in
            guideView.removeFromSuperview()
        }
    }

    // MARK: - 听经一体化控制

    private func setupPlayButton() {
        let btn = UIButton(type: .custom)
        // 用 Auto Layout 固定 32×32，防止两行 titleView 挤占空间时被导航栏压扁成椭圆
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.widthAnchor.constraint(equalToConstant: 32).isActive = true
        btn.heightAnchor.constraint(equalToConstant: 32).isActive = true
        btn.backgroundColor = SutraDesignTokens.shared.color(for: .primary)
        btn.layer.cornerRadius = 16
        btn.layer.cornerCurve = .continuous
        btn.clipsToBounds = true

        let config = UIImage.SymbolConfiguration(pointSize: 12, weight: .bold)
        let playImg = UIImage(systemName: "play.fill", withConfiguration: config)
        btn.setImage(playImg, for: .normal)
        btn.tintColor = SutraDesignTokens.shared.color(for: .background)
        btn.addTarget(self, action: #selector(playButtonTapped), for: .touchUpInside)

        // 播放图标视觉微调（光学居中）
        btn.imageEdgeInsets = UIEdgeInsets(top: 0, left: 1.5, bottom: 0, right: 0)

        // 下载等待圆环：复刻 mini-player 的 ZenProgressRing（背景色细环随进度推进）
        setupProgressRing(on: btn)

        self.playButton = UIBarButtonItem(customView: btn)
        // iOS 26：移除 UIBarButtonItem 默认的 Liquid Glass 背景（那圈白色细环），让按钮干净地贴在导航栏上
        if #available(iOS 26.0, *) {
            self.playButton?.hidesSharedBackground = true
        }
        updateRightBarButtonItems()

        // 播放状态：播放中/暂停图标同步
        playCancellable = Publishers.CombineLatest(
            AudioPlayerObserver.shared.$isPlaying,
            AudioPlayerObserver.shared.$currentTrack
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] _, _ in self?.refreshPlayButton() }

        // 下载状态与进度：驱动圆环，让用户知道「正在准备，请稍候」
        downloadStatusCancellable = AudioManager.shared.$downloadStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refreshPlayButton() }
        downloadProgressCancellable = AudioManager.shared.$downloadProgress
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refreshPlayButton() }

        refreshPlayButton()
    }

    /// 在圆形按钮内侧叠加一层进度圆环（轨道 + 进度弧）
    private func setupProgressRing(on btn: UIButton) {
        // 路径以原点为圆心，再用 position 定位到按钮中心，
        // 这样 layer 的旋转锚点（默认中心）正好落在圆心，进度弧可绕中心顺时针推进
        let radius: CGFloat = 13
        let path = UIBezierPath(arcCenter: .zero, radius: radius,
                                startAngle: 0, endAngle: .pi * 2, clockwise: true).cgPath
        let ringColor = SutraDesignTokens.shared.color(for: .background)

        let track = CAShapeLayer()
        track.path = path
        track.fillColor = UIColor.clear.cgColor
        track.lineWidth = 1.5
        track.strokeColor = ringColor.withAlphaComponent(0.2).cgColor
        track.position = CGPoint(x: 16, y: 16)
        track.opacity = 0
        btn.layer.addSublayer(track)
        progressTrackLayer = track

        let ring = CAShapeLayer()
        ring.path = path
        ring.fillColor = UIColor.clear.cgColor
        ring.lineWidth = 1.5
        ring.lineCap = .round
        ring.strokeColor = ringColor.cgColor
        ring.strokeStart = 0
        ring.strokeEnd = 0
        ring.position = CGPoint(x: 16, y: 16)
        ring.opacity = 0
        // 从正上方起笔、顺时针推进，与 ZenProgressRing 视觉一致
        ring.transform = CATransform3DMakeRotation(-.pi / 2, 0, 0, 1)
        btn.layer.addSublayer(ring)
        progressRingLayer = ring
    }

    /// 统一刷新播放按钮：下载中显示进度圆环，否则显示播放/暂停图标
    private func refreshPlayButton() {
        guard let btn = self.playButton?.customView as? UIButton else { return }

        // 下载状态走 AudioManager 统一入口，与听经小播放器同源同逻辑
        let state = AudioManager.shared.downloadState(forTrackName: getTrackName())
        let isDownloading = state.isDownloading
        let progress = state.progress

        let ringColor = SutraDesignTokens.shared.color(for: .background)
        progressTrackLayer?.strokeColor = ringColor.withAlphaComponent(0.2).cgColor
        progressRingLayer?.strokeColor = ringColor.cgColor

        UIView.performWithoutAnimation {
            btn.backgroundColor = SutraDesignTokens.shared.color(for: .primary)
            btn.tintColor = SutraDesignTokens.shared.color(for: .background)

            if isDownloading {
                // 下载等待：图标淡出，圆环随进度推进，按钮禁用防误触
                btn.setImage(nil, for: .normal)
                progressTrackLayer?.opacity = 1
                progressRingLayer?.opacity = 1
                let p = max(0.05, min(progress, 1.0))
                CATransaction.begin()
                CATransaction.setAnimationDuration(0.15)
                progressRingLayer?.strokeEnd = CGFloat(p)
                CATransaction.commit()
                btn.isEnabled = false
            } else {
                let trackName = getTrackName()
                let isCurrentPlaying = AudioPlayerObserver.shared.isPlaying
                    && (AudioPlayerObserver.shared.currentTrack == trackName)
                let iconName = isCurrentPlaying ? "pause.fill" : "play.fill"
                let config = UIImage.SymbolConfiguration(pointSize: 12, weight: .bold)
                btn.setImage(UIImage(systemName: iconName, withConfiguration: config), for: .normal)
                // 播放三角形光学居中，暂停键居中
                btn.imageEdgeInsets = iconName == "play.fill"
                    ? UIEdgeInsets(top: 0, left: 1.5, bottom: 0, right: 0)
                    : .zero
                progressTrackLayer?.opacity = 0
                progressRingLayer?.opacity = 0
                progressRingLayer?.strokeEnd = 0
                btn.isEnabled = true
            }
            btn.layoutIfNeeded()
        }
    }

    private func updateRightBarButtonItems() {
        var items: [UIBarButtonItem] = []
        
        if let playBtn = self.playButton {
            items.append(playBtn)
        }
        
        // 只有在需要恢复进度且未点过“第一页”时，才在右上角叠展“第一页”按钮
        if let offset = restoreOffset, offset > 0, !hasRestoredOffset {
            let firstPageButton = UIBarButtonItem(
                title: L10n.str("reader_first_page"),
                style: .plain,
                target: self,
                action: #selector(goToFirstPage)
            )
            firstPageButton.tintColor = SutraDesignTokens.shared.color(for: .textSecondary)
            if #available(iOS 26.0, *) {
                firstPageButton.hidesSharedBackground = true
            }
            items.append(firstPageButton)
        }
        
        self.navigationItem.rightBarButtonItems = items
    }

    @objc private func playButtonTapped() {
        if AudioManager.shared.mediaGroups.isEmpty {
            AudioManager.shared.loadMediaData()
        }
        
        guard let group = AudioManager.shared.mediaGroups.first,
              chapter >= 0 && chapter < group.files.count else { return }
        
        let file = group.files[chapter]
        let name = group.names[chapter]
        let ext = group.fileExtension
        
        let isCurrent = AudioPlayerObserver.shared.currentTrack == name
        
        if isCurrent {
            AudioManager.shared.togglePlayPause()
        } else {
            // Switching from another volume starts this volume from the beginning,
            // not from an older saved listening position.
            Prefers.shared.lastPlayTime = 0
            AudioManager.shared.handleMediaItemTap(name: name, file: file, fileExtension: ext)
        }
    }

    private func getTrackName() -> String? {
        if AudioManager.shared.mediaGroups.isEmpty {
            AudioManager.shared.loadMediaData()
        }
        guard let group = AudioManager.shared.mediaGroups.first,
              chapter >= 0 && chapter < group.files.count else { return nil }
        return group.names[chapter]
    }

    private func setupThemeObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(themeDidChange),
            name: .themeDidChange,
            object: nil
        )
    }

    @objc private func themeDidChange() {
        guard isReaderVisible else {
            needsPreferenceRebuild = true
            return
        }

        // The text storage owns explicit foreground-color attributes, so simply
        // changing UITextView.textColor is insufficient for dark mode.
        if !rebuildReaderContentPreservingPosition() {
            needsPreferenceRebuild = true
        }
        applyThemeAppearance(animated: true)
    }

    private func applyThemeAppearance(animated: Bool) {
        let updates = {
            self.view.backgroundColor = SutraDesignTokens.shared.color(for: .background)
            
            // 刷新导航栏外观
            let secondaryColor = SutraDesignTokens.shared.color(for: .textSecondary)
            let navColor = SutraDesignTokens.shared.color(for: .background)
            let appearance = UINavigationBarAppearance()
            appearance.configureWithTransparentBackground()
            appearance.backgroundColor = navColor
            appearance.shadowColor = .clear
            appearance.shadowImage = UIImage()
            appearance.titleTextAttributes = [
                .foregroundColor: SutraDesignTokens.shared.color(for: .textPrimary),
                .font: SutraTypographyManager.shared.uiFont(for: .navigationTitle, weight: .regular).withSize(24)
            ]
            let btnAppearance = UIBarButtonItemAppearance(style: .plain)
            btnAppearance.normal.backgroundImage = UIImage()
            btnAppearance.normal.titleTextAttributes = [.foregroundColor: secondaryColor]
            btnAppearance.highlighted.backgroundImage = UIImage()
            btnAppearance.highlighted.titleTextAttributes = [.foregroundColor: secondaryColor.withAlphaComponent(0.5)]
            appearance.buttonAppearance = btnAppearance
            appearance.doneButtonAppearance = btnAppearance
            
            if let navBar = self.navigationController?.navigationBar {
                navBar.standardAppearance = appearance
                navBar.compactAppearance = appearance
                navBar.scrollEdgeAppearance = appearance
                navBar.tintColor = secondaryColor
                navBar.barTintColor = navColor
                navBar.backgroundColor = navColor
            }
            
            // 刷新左侧返回按钮颜色
            self.navigationItem.leftBarButtonItem?.tintColor = secondaryColor

            // 刷新双行标题颜色（卷名 + 页码）
            self.titleLabel.textColor = SutraDesignTokens.shared.color(for: .textPrimary)
            self.pageLabel.textColor = SutraDesignTokens.shared.color(for: .textSecondary).withAlphaComponent(0.7)

            // 刷新正文文本视图颜色
            for tv in self.textViews {
                tv.backgroundColor = .clear
                tv.textColor = SutraDesignTokens.shared.color(for: .textPrimary)
            }

            // 重新同步播放按钮状态（图标 / 下载圆环）与色调
            self.refreshPlayButton()
        }

        if animated {
            UIView.transition(
                with: self.view,
                duration: 0.4,
                options: [.transitionCrossDissolve, .curveEaseInOut],
                animations: updates,
                completion: nil
            )
        } else {
            updates()
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
