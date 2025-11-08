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
        
        self.navigationController?.hidesBarsOnSwipe = true;
        self.navigationController?.hidesBarsWhenVerticallyCompact = true;
        
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: " ❬   ", style: .plain, target: self, action: #selector(close))
        self.navigationItem.leftBarButtonItem?.tintColor = SutraDesignTokens.shared.color(for: .textPrimary)
        self.navigationItem.leftBarButtonItem?.setBackButtonBackgroundImage(UIImage.init(named: "ic_chevron_left_18pt"), for: .normal, barMetrics: .default)
        

        setupContentView()
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
