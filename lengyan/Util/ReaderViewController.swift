import UIKit

final class ReaderViewController: UIViewController, UIScrollViewDelegate {

    private let contentView = UIScrollView()
    private var textViews: [UITextView] = []
    let content:NSAttributedString;
    private let chapter: Int
    private let restoreOffset: CGFloat?
    private var hasRestoredOffset = false


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

        // 恢复进度时右上角显示"第一页"按钮
        if let offset = restoreOffset, offset > 0 {
            let firstPageButton = UIBarButtonItem(
                title: "第一页",
                style: .plain,
                target: self,
                action: #selector(goToFirstPage)
            )
            firstPageButton.tintColor = secondaryColor
            if #available(iOS 26.0, *) {
                firstPageButton.hidesSharedBackground = true
            }
            self.navigationItem.rightBarButtonItem = firstPageButton
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.tabBarController?.tabBar.isHidden = true
        self.navigationController?.setNavigationBarHidden(false, animated: false)
        self.navigationController?.hidesBarsOnSwipe = false
        self.navigationController?.hidesBarsOnTap = true
        self.navigationController?.barHideOnTapGestureRecognizer.isEnabled = true
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.tabBarController?.tabBar.isHidden = false
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
        navigationItem.rightBarButtonItem = nil
    }

    // MARK: - UIScrollViewDelegate

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        saveProgress()
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
        contentView.delegate = self
        view.addSubview(contentView)

        if #available(iOS 11.0, *) {
            NSLayoutConstraint.activate([
                contentView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
                contentView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
                contentView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
                contentView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor)
            ])
        } else {
            // Fallback on earlier versions
        }
    }

    private func setupReader() {

        // 2
        let textStorage = NSTextStorage(attributedString: content)

        // 3
        let textLayout = NSLayoutManager()
        textStorage.addLayoutManager(textLayout)

        let viewSize = contentView.bounds.size
        let textInsets = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)

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
            textView.isScrollEnabled = false
            textView.bounces = false
            textView.bouncesZoom = false

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
        let toast = UILabel()
        toast.text = "已恢复阅读进度"
        toast.font = SutraTypographyManager.shared.uiFont(for: .uiSmall, weight: .regular)
        toast.textColor = SutraDesignTokens.shared.color(for: .textSecondary)
        toast.textAlignment = .center
        toast.backgroundColor = SutraDesignTokens.shared.color(for: .background).withAlphaComponent(0.9)
        toast.layer.cornerRadius = 12
        toast.clipsToBounds = true

        let toastHeight: CGFloat = 36
        let toastWidth: CGFloat = 160
        toast.frame = CGRect(
            x: (view.bounds.width - toastWidth) / 2,
            y: view.bounds.height - view.safeAreaInsets.bottom - toastHeight - 24,
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

}
