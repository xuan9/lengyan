import UIKit

final class ReaderViewController: UIViewController {
    
    private let contentView = UIScrollView()
    private var textViews: [UITextView] = []
    let content:NSAttributedString;
    
    
    init(title:String, content:NSAttributedString) {
        self.content = content
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
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.tabBarController?.tabBar.isHidden = true
        // 每次出现时先显示导航栏（让用户看到返回按钮）
        self.navigationController?.setNavigationBarHidden(false, animated: false)
        // 水平翻页阅读器没有垂直滚动，hidesBarsOnSwipe 无法触发，
        // 改用 hidesBarsOnTap 实现点击切换导航栏
        self.navigationController?.hidesBarsOnSwipe = false
        self.navigationController?.hidesBarsOnTap = true
        // 显式重新启用手势识别器（防止被其他页面禁用）
        self.navigationController?.barHideOnTapGestureRecognizer.isEnabled = true
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // 进入阅读 2 秒后自动隐藏导航栏，沉浸阅读
        // 用户随时可点击屏幕重新呼出
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self = self,
                  self.navigationController?.isNavigationBarHidden == false else { return }
            self.navigationController?.setNavigationBarHidden(true, animated: true)
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.tabBarController?.tabBar.isHidden = false
        // 离开时重置，避免影响其他页面
        self.navigationController?.hidesBarsOnTap = false
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        setupReader()
    }
    
    @objc func close(){
        self.navigationController?.popViewController(animated: true)
    }
    
    //  private func fullContent() -> String {
    //    let url = Bundle.main.url(forResource: "Diamond Sutra", withExtension: "txt")!
    //    return try! String(contentsOf: url, encoding: .utf8)
    //  }
    //
    private func setupContentView() {
        contentView.backgroundColor = SutraDesignTokens.shared.color(for: .background)
        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.showsVerticalScrollIndicator = false
        contentView.showsHorizontalScrollIndicator = false
        contentView.isPagingEnabled = true
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
            textView.isSelectable = false
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
    
}
