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
        
        view.backgroundColor = SutraDesignTokens.shared.color(for: .navigationBar)
        
        self.navigationController?.hidesBarsOnSwipe = true;
        self.navigationController?.hidesBarsWhenVerticallyCompact = true;
        
        // 返回按钮
        let secondaryColor = SutraDesignTokens.shared.color(for: .textSecondary)
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "chevron.left"), style: .plain, target: self, action: #selector(close))
        self.navigationItem.leftBarButtonItem?.tintColor = secondaryColor
        
        // 导航栏外观 — 与内容同色，按钮无背景色块
        let navColor = SutraDesignTokens.shared.color(for: .navigationBar)
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = navColor
        appearance.shadowColor = .clear
        let btnAppearance = UIBarButtonItemAppearance(style: .plain)
        btnAppearance.normal.titleTextAttributes = [.foregroundColor: secondaryColor]
        appearance.buttonAppearance = btnAppearance
        appearance.doneButtonAppearance = btnAppearance
        self.navigationController?.navigationBar.standardAppearance = appearance
        self.navigationController?.navigationBar.compactAppearance = appearance
        self.navigationController?.navigationBar.scrollEdgeAppearance = appearance
        self.navigationController?.navigationBar.isTranslucent = false

        setupContentView()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.tabBarController?.tabBar.isHidden = true
        // 每次出现时重新启用滑动隐藏，因为首页 viewWillAppear 会将其重置为 false
        self.navigationController?.setNavigationBarHidden(false, animated: false)
        self.navigationController?.hidesBarsOnSwipe = true
        self.navigationController?.hidesBarsWhenVerticallyCompact = true
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.tabBarController?.tabBar.isHidden = false
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
        contentView.backgroundColor = SutraDesignTokens.shared.color(for: .navigationBar)
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
            textView.backgroundColor = SutraDesignTokens.shared.color(for: .navigationBar)
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
