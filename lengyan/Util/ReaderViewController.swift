import UIKit
import Combine

final class ReaderViewController: UIViewController, UIScrollViewDelegate {

    private let contentView = UIScrollView()
    private var textViews: [UITextView] = []
    let content:NSAttributedString;
    private let chapter: Int
    private let restoreOffset: CGFloat?
    private var hasRestoredOffset = false
    
    // 极简页码指示器
    private let pageIndicator = UILabel()
    private var hidePageIndicatorTimer: Timer?

    // 🔊 听经一体化播放器观察与按钮
    private var playButton: UIBarButtonItem?
    private var playCancellable: AnyCancellable?


    init(title:String, content:NSAttributedString, chapter: Int, restoreOffset: CGFloat? = nil) {
        self.content = content
        self.chapter = chapter
        self.restoreOffset = restoreOffset
        super.init(nibName: nil, bundle: nil)
        self.title = title
      }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

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

        setupContentView()
        setupPlayButton()
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
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.tabBarController?.tabBar.isHidden = false
        if #available(iOS 18.0, *) {
            self.tabBarController?.setTabBarHidden(false, animated: false)
        }
        self.navigationController?.hidesBarsOnTap = false
        saveProgress()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard textViews.isEmpty else { return }
        setupReader()

        // 恢复上次阅读位置（只执行一次）
        if !hasRestoredOffset, let offset = restoreOffset, offset > 0 {
            contentView.setContentOffset(CGPoint(x: offset, y: 0), animated: false)
            hasRestoredOffset = true
            showResumeToast()
        }
    }

    @objc func close(){
        self.navigationController?.popViewController(animated: true)
    }

    @objc private func goToFirstPage() {
        contentView.setContentOffset(.zero, animated: true)
        hasRestoredOffset = true
        updateRightBarButtonItems()
    }

    // MARK: - UIScrollViewDelegate

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        saveProgress()
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let total = textViews.count
        guard total > 0, scrollView.bounds.width > 0 else { return }
        
        let page = Int(round(scrollView.contentOffset.x / scrollView.bounds.width)) + 1
        pageIndicator.text = "\(page) / \(total)"
        
        // 滑动时淡入显示
        if pageIndicator.alpha < 1 {
            UIView.animate(withDuration: 0.2) {
                self.pageIndicator.alpha = 1
            }
        }
        
        // 停止滑动 1.5 秒后自动淡出消失（极简沉浸）
        hidePageIndicatorTimer?.invalidate()
        hidePageIndicatorTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { [weak self] _ in
            UIView.animate(withDuration: 0.5) {
                self?.pageIndicator.alpha = 0
            }
        }
    }

    // MARK: - Progress

    private func saveProgress() {
        Prefers.shared.lastReadChapter = chapter
        Prefers.shared.lastReadChapterOffset = contentView.contentOffset.x
    }

    private func setupContentView() {
        contentView.backgroundColor = SutraDesignTokens.shared.color(for: .background)
        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.showsVerticalScrollIndicator = false
        contentView.showsHorizontalScrollIndicator = false
        contentView.isPagingEnabled = true
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
        
        // 配置极简页码指示器
        pageIndicator.font = SutraTypographyManager.shared.uiFont(for: .uiSmall, weight: .light).withSize(10)
        pageIndicator.textColor = SutraDesignTokens.shared.color(for: .textSecondary).withAlphaComponent(0.6)
        pageIndicator.textAlignment = .center
        pageIndicator.alpha = 0 // 初始状态隐藏
        pageIndicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(pageIndicator)
        
        NSLayoutConstraint.activate([
            pageIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            // 将指示器放入底部安全区（Home Bar 区域）内，距离物理屏幕底部 12pt，彻底脱离文本区域
            pageIndicator.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -12)
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
        let margin = SutraAdaptiveLayout.readingHorizontalInsets(containerWidth: viewSize.width)
        // 核心修复：顶部和底部不要使用水平宽 margin，否则在 iPad 上顶部会出现几百像素的巨大留白！
        let textInsets = UIEdgeInsets(top: 32, left: margin, bottom: 32, right: margin)
        
        // 1
        var index: Int = 0
        var glyphRange: Int = 0
        var numberOfGlyphs: Int = 0

        repeat {
            // 2
            let textContainer = NSTextContainer(size: viewSize)
            textLayout.addTextContainer(textContainer)

            // 3
            let textViewFrame = CGRect(
                x: CGFloat(index) * viewSize.width,
                y: 0,
                width: viewSize.width,
                height: viewSize.height
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
    }

    // MARK: - Toast

    private func showResumeToast() {
        let total = textViews.count
        var pageText = ""
        if total > 0, contentView.bounds.width > 0 {
            let page = Int(round(contentView.contentOffset.x / contentView.bounds.width)) + 1
            pageText = " [\(page)/\(total)]"
        }
        
        let toast = UILabel()
        toast.text = "已恢复进度" + pageText
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

    // MARK: - 听经一体化控制

    private func setupPlayButton() {
        let btn = UIButton(type: .system)
        // 初始设为播放图标
        btn.setImage(UIImage(systemName: "play.fill"), for: .normal)
        btn.tintColor = SutraDesignTokens.shared.color(for: .textSecondary)
        btn.addTarget(self, action: #selector(playButtonTapped), for: .touchUpInside)
        btn.frame = CGRect(x: 0, y: 0, width: 44, height: 44)
        
        let barBtn = UIBarButtonItem(customView: btn)
        self.playButton = barBtn
        
        updateRightBarButtonItems()

        // 绑定音频播放器状态，实现播放中/暂停状态的自动同步
        playCancellable = Publishers.CombineLatest(
            AudioPlayerObserver.shared.$isPlaying,
            AudioPlayerObserver.shared.$currentTrack
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] isPlaying, currentTrack in
            self?.updatePlayButtonState(isPlaying: isPlaying, currentTrack: currentTrack)
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
                title: "第一页",
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
            AudioManager.shared.handleMediaItemTap(name: name, file: file, fileExtension: ext)
        }
    }

    private func updatePlayButtonState(isPlaying: Bool, currentTrack: String?) {
        let trackName = getTrackName()
        let isCurrentPlaying = isPlaying && (currentTrack == trackName)
        let iconName = isCurrentPlaying ? "pause.fill" : "play.fill"
        
        if let btn = self.playButton?.customView as? UIButton {
            UIView.performWithoutAnimation {
                btn.setImage(UIImage(systemName: iconName), for: .normal)
                btn.layoutIfNeeded()
            }
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

}
