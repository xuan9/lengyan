//
//  SutraIndexViewController+Enhanced.swift
//  lengyan
//
//  Enhanced version with new design system integration
//  Maintains all existing functionality while adding improved hierarchy and visual design
//

import UIKit

class EnhancedSutraIndexViewController: UIViewController, RATreeViewDataSource, RATreeViewDelegate {

    // MARK: - Properties
    var onDismiss: (() -> Void)?
    var isShowSutraButton = true
    var tree: [String: Any]?
    var path: String?
    var defaultExpandLevel: Int = 2
    var isRootIndex = false

    // MARK: - UI Components
    private var treeView: RATreeView!
    private var headerView: UIView?
    private var searchController: UISearchController!
    private var loadingIndicator: UIActivityIndicatorView!
    private var emptyStateView: UIView?

    // Design System
    private let themeManager = SutraThemeManager.shared
    private var currentTheme: SutraTheme = .light

    // Enhanced Features
    private var isSearchActive = false
    private var filteredItems: [[String: Any]] = []
    private var expansionStates: [String: Bool] = [:]

    // Animation
    private var hasAppeared = false

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupDesignSystem()
        setupSearchController()
        setupLoadingIndicator()
        setupTreeView()
        setupData()
        setupGestures()
        setupAccessibility()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: true)
        navigationController?.hidesBarsOnSwipe = false
        updateTheme()
        setupNavigationBar()
        expandVisibleItems()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !hasAppeared {
            animateEntrance()
            autoExpand()
            hasAppeared = true
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        saveExpansionStates()
    }

    // MARK: - Setup Methods
    private func setupDesignSystem() {
        currentTheme = themeManager.currentTheme
        view.backgroundColor = SutraColors.Semantic.background(theme: currentTheme)
    }

    private func setupSearchController() {
        searchController = UISearchController(searchResultsController: nil)
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = NSLocalizedString("search_sutra_index", comment: "Search sutra index")
        searchController.searchBar.tintColor = SutraColors.Semantic.accent(theme: currentTheme)

        // Customize search bar appearance
        let searchBarAppearance = UISearchBarAppearance()
        searchBarAppearance.backgroundColor = SutraColors.Semantic.surface(theme: currentTheme)
        searchBarAppearance.tintColor = SutraColors.Semantic.accent(theme: currentTheme)

        if let textFieldAppearance = searchBarAppearance.textFieldAppearance {
            textFieldAppearance.backgroundColor = SutraColors.Semantic.card(theme: currentTheme)
            textFieldAppearance.textColor = SutraColors.Semantic.primary(theme: currentTheme)
        }

        searchController.searchBar.standardAppearance = searchBarAppearance
        searchController.searchBar.compactAppearance = searchBarAppearance

        definesPresentationContext = true
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

    private func setupTreeView() {
        let bounds = view.bounds
        treeView = RATreeView(frame: CGRect(
            x: SutraSpacing.small,
            y: 0,
            width: bounds.width - (SutraSpacing.small * 2),
            height: bounds.height
        ))

        treeView.delegate = self
        treeView.dataSource = self
        treeView.backgroundColor = .clear
        treeView.separatorStyle = .none
        treeView.rowHeight = UITableView.automaticDimension
        treeView.estimatedRowHeight = 52
        treeView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        // Enhanced appearance
        treeView.clipsToBounds = false
        treeView.showsVerticalScrollIndicator = false
        treeView.contentInset = UIEdgeInsets(top: SutraSpacing.medium, left: 0, bottom: SutraSpacing.large, right: 0)

        view.addSubview(treeView)
    }

    private func setupData() {
        if tree == nil {
            isRootIndex = true
            loadRootTree()

            NotificationCenter.default.addObserver(
                self,
                selector: #selector(onApplicationWillTerminate),
                name: UIApplication.willTerminateNotification,
                object: nil
            )
        } else {
            path = tree!["path"] as? String
            treeView.reloadData()
        }

        updateHeader()
    }

    private func setupGestures() {
        let longPressRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(longPress(_:)))
        treeView.addGestureRecognizer(longPressRecognizer)

        // Add refresh gesture
        let refreshControl = UIRefreshControl()
        refreshControl.tintColor = SutraColors.Semantic.accent(theme: currentTheme)
        refreshControl.addTarget(self, action: #selector(refreshData), for: .valueChanged)
        treeView.refreshControl = refreshControl
    }

    private func setupAccessibility() {
        isAccessibilityElement = false
        accessibilityLabel = NSLocalizedString("sutra_index", comment: "Sutra index")
        accessibilityHint = NSLocalizedString("navigate_through_sutra_sections", comment: "Navigate through sutra sections and chapters")

        // Configure search for accessibility
        searchController.searchBar.accessibilityLabel = NSLocalizedString("search", comment: "Search")
        searchController.searchBar.accessibilityHint = NSLocalizedString("search_sutra_content", comment: "Search through sutra content")
    }

    private func setupNavigationBar() {
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationController?.navigationBar.backgroundColor = SutraColors.Semantic.surface(theme: currentTheme)
        navigationController?.navigationBar.barTintColor = SutraColors.Semantic.surface(theme: currentTheme)

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

        setupNavigationItems()
    }

    private func setupNavigationItems() {
        // Enhanced back button
        let backButton = UIBarButtonItem(
            image: UIImage(systemName: "chevron.left"),
            style: .plain,
            target: self,
            action: #selector(close)
        )
        backButton.tintColor = SutraColors.Semantic.primary(theme: currentTheme)
        navigationItem.leftBarButtonItem = backButton

        // Right buttons
        var rightButtons: [UIBarButtonItem] = []

        // List view button
        let listButton = UIBarButtonItem(
            image: UIImage(systemName: "list.bullet"),
            style: .plain,
            target: self,
            action: #selector(openAsPage)
        )
        listButton.tintColor = SutraColors.Semantic.primary(theme: currentTheme)
        listButton.accessibilityLabel = NSLocalizedString("view_as_pages", comment: "View as pages")
        rightButtons.append(listButton)

        // Sutra button (if enabled)
        if isShowSutraButton {
            let sutraButton = UIBarButtonItem(
                image: UIImage(systemName: "book"),
                style: .plain,
                target: self,
                action: #selector(openSutra)
            )
            sutraButton.tintColor = SutraColors.Semantic.primary(theme: currentTheme)
            sutraButton.accessibilityLabel = NSLocalizedString("open_sutra", comment: "Open sutra")
            rightButtons.append(sutraButton)
        }

        // Search button
        let searchButton = UIBarButtonItem(
            image: UIImage(systemName: "magnifyingglass"),
            style: .plain,
            target: self,
            action: #selector(showSearch)
        )
        searchButton.tintColor = SutraColors.Semantic.primary(theme: currentTheme)
        searchButton.accessibilityLabel = NSLocalizedString("search", comment: "Search")
        rightButtons.append(searchButton)

        navigationItem.rightBarButtonItems = rightButtons
    }

    // MARK: - Data Loading
    private func loadRootTree() {
        loadingIndicator.startAnimating()
        showEmptyState(false)

        Book.shared.loadDataWithCompletionHandler {
            self.tree = Book.shared.tree
            self.path = self.tree?["path"] as? String

            DispatchQueue.main.async {
                self.loadingIndicator.stopAnimating()
                self.treeView.reloadData()
                self.updateHeader()

                if let tree = self.tree, tree.isEmpty {
                    self.showEmptyState(true)
                }
            }
        }
    }

    @objc private func refreshData() {
        loadRootTree()
        treeView.refreshControl?.endRefreshing()
    }

    private func showEmptyState(_ show: Bool) {
        if show && emptyStateView == nil {
            createEmptyStateView()
        }

        emptyStateView?.isHidden = !show
        treeView?.isHidden = show
    }

    private func createEmptyStateView() {
        emptyStateView = UIView()
        emptyStateView?.translatesAutoresizingMaskIntoConstraints = false
        emptyStateView?.backgroundColor = SutraColors.Semantic.background(theme: currentTheme)
        view.addSubview(emptyStateView!)

        let imageView = UIImageView(image: UIImage(systemName: "book.closed"))
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.tintColor = SutraColors.Semantic.textTertiary(theme: currentTheme)
        imageView.contentMode = .scaleAspectFit
        emptyStateView?.addSubview(imageView)

        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = NSLocalizedString("no_sutra_data", comment: "No sutra data available")
        titleLabel.font = SutraTypography.Typography.headline
        titleLabel.textColor = SutraColors.Semantic.textSecondary(theme: currentTheme)
        titleLabel.textAlignment = .center
        emptyStateView?.addSubview(titleLabel)

        let messageLabel = UILabel()
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.text = NSLocalizedString("check_internet_connection", comment: "Please check your internet connection")
        messageLabel.font = SutraTypography.Typography.body
        messageLabel.textColor = SutraColors.Semantic.textTertiary(theme: currentTheme)
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0
        emptyStateView?.addSubview(messageLabel)

        let retryButton = SutraComponents.createPrimaryButton(
            title: NSLocalizedString("retry", comment: "Retry"),
            frame: .zero
        )
        retryButton.addTarget(self, action: #selector(refreshData), for: .touchUpInside)
        emptyStateView?.addSubview(retryButton)

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
            messageLabel.trailingAnchor.constraint(equalTo: emptyStateView!.trailingAnchor, constant: -SutraSpacing.large),

            retryButton.centerXAnchor.constraint(equalTo: emptyStateView!.centerXAnchor),
            retryButton.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: SutraSpacing.large),
            retryButton.heightAnchor.constraint(equalToConstant: SutraSpacing.componentHeight),
            retryButton.widthAnchor.constraint(equalToConstant: 120)
        ])
    }

    // MARK: - Header Updates
    private func updateHeader() {
        if let tree = tree {
            title = tree["name"] as? String ?? NSLocalizedString("sutra_index", comment: "Sutra Index")
        }
    }

    // MARK: - Expansion Management
    private func autoExpand() {
        guard let tree = tree else { return }

        var rows = treeView.numberOfRows()
        let targetRows = Int(view.frame.height * 1.5 / 52)

        repeat {
            print("Expanding to level: \(defaultExpandLevel)")

            if let children = tree["children"] as? NSArray {
                children.forEach { item in
                    autoExpandNode(item as! [String: Any])
                }
            }

            defaultExpandLevel += 1
            let newRows = treeView.numberOfRows()
            if rows == newRows {
                break
            }
            rows = newRows
        } while rows < targetRows
    }

    private func autoExpandNode(_ node: [String: Any]) {
        let currentLevel = treeView.levelForCell(forItem: node)
        guard currentLevel < defaultExpandLevel else { return }

        if let nodePath = node["path"] as? String, nodePath != path {
            treeView.expandRow(forItem: node, with: .none)
            expansionStates[nodePath] = true
        }

        guard currentLevel + 1 <= defaultExpandLevel else { return }

        if let children = node["children"] as? NSArray {
            children.forEach { item in
                autoExpandNode(item as! [String: Any])
            }
        }
    }

    private func expandVisibleItems() {
        treeView.visibleCells()?.forEach { cell in
            if let item = treeView.item(for: cell) {
                treeView.expandRow(forItem: item, expandChildren: false, with: .none)
            }
        }
    }

    private func saveExpansionStates() {
        // Save expansion states for restoration
        // This could be persisted to UserDefaults if needed
    }

    // MARK: - Theme Updates
    private func updateTheme() {
        currentTheme = themeManager.currentTheme
        view.backgroundColor = SutraColors.Semantic.background(theme: currentTheme)
        treeView?.backgroundColor = .clear
        setupNavigationBar()
        updateSearchAppearance()
    }

    private func updateSearchAppearance() {
        let searchBarAppearance = UISearchBarAppearance()
        searchBarAppearance.backgroundColor = SutraColors.Semantic.surface(theme: currentTheme)
        searchBarAppearance.tintColor = SutraColors.Semantic.accent(theme: currentTheme)

        if let textFieldAppearance = searchBarAppearance.textFieldAppearance {
            textFieldAppearance.backgroundColor = SutraColors.Semantic.card(theme: currentTheme)
            textFieldAppearance.textColor = SutraColors.Semantic.primary(theme: currentTheme)
        }

        searchController.searchBar.standardAppearance = searchBarAppearance
        searchController.searchBar.compactAppearance = searchBarAppearance
    }

    // MARK: - Animations
    private func animateEntrance() {
        treeView?.alpha = 0
        treeView?.transform = CGAffineTransform(translationX: 0, y: 50)

        UIView.animate(withDuration: 0.6, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0, options: [.curveEaseOut]) {
            self.treeView?.alpha = 1
            self.treeView?.transform = .identity
        }
    }

    // MARK: - Button Actions
    @objc private func close() {
        HapticFeedback.lightImpact()
        onDismiss?()
        navigationController?.popViewController(animated: true)
    }

    @objc private func openSutra() {
        HapticFeedback.lightImpact()
        let sutraVC = SutraPurePageViewController(
            transitionStyle: .pageCurl,
            navigationOrientation: .horizontal,
            options: nil
        )
        sutraVC.path = tree?["path"] as? String
        navigationController?.pushViewController(sutraVC, animated: true)
    }

    @objc private func openAsPage() {
        HapticFeedback.lightImpact()
        if let tree = tree {
            openItem(tree)
        }
    }

    @objc private func showSearch() {
        HapticFeedback.lightImpact()
        present(searchController, animated: true)
    }

    @objc private func onApplicationWillTerminate() {
        // Cleanup if needed
    }

    // MARK: - Gesture Handling
    @objc private func longPress(_ longPressGestureRecognizer: UILongPressGestureRecognizer) {
        guard longPressGestureRecognizer.state == .began else { return }

        let touchPoint = longPressGestureRecognizer.location(in: treeView.scrollView)
        if let item = treeView.itemForRow(at: touchPoint) as? [String: Any] {
            HapticFeedback.mediumImpact()
            if item["children"] == nil {
                openItem(item)
            } else {
                openIndex(item)
            }
        }
    }

    @objc private func openAsPageFromCellButton(_ sender: UIButton) {
        guard let cell = sender.superview as? UITableViewCell,
              let item = treeView.item(for: cell) else { return }

        HapticFeedback.lightImpact()
        openItem(item as! [String: Any])
    }

    // MARK: - Navigation Methods
    private func openItem(_ item: [String: Any]) {
        let pageVC = SutraPageViewController(
            transitionStyle: .pageCurl,
            navigationOrientation: .horizontal,
            options: nil
        )

        guard let path = item["path"] as? String,
              let index = Book.shared.index?.firstIndex(where: { $0["path"] == path }) else {
            return
        }

        pageVC.page = index
        pageVC.onDismiss = { [weak self] in
            guard let page = pageVC.page,
                  let indexPath = Book.shared.index?[page] as? NSDictionary else { return }
            self?.openPath(indexPath["path"] as! String)
        }

        navigationController?.pushViewController(pageVC, animated: true)
    }

    private func openIndex(_ item: [String: Any]) {
        let indexVC = EnhancedSutraIndexViewController()
        indexVC.tree = item
        indexVC.defaultExpandLevel = 2
        indexVC.isShowSutraButton = isShowSutraButton

        indexVC.onDismiss = { [weak self] in
            guard let path = indexVC.tree?["path"] as? String else { return }
            self?.openPath(path)
        }

        navigationController?.pushViewController(indexVC, animated: true)
    }

    private func openPath(_ path: String) {
        guard path != "", path != "/" else { return }
        guard let treePath = tree?["path"] as? String else { return }

        if treePath.count > path.count { return }

        let subPath = path[pathPath.index(pathPath.startIndex, offsetBy: treePath.count)...]
        var node = tree
        var isExpanded = false

        for id in subPath.components(separatedBy: "/") {
            guard id != "" else { continue }
            guard let children = node?["children"] as? NSArray else { return }

            node = children.first { ($0 as? [String: Any])?["id"] as? String == id } as? [String: Any]
            guard let currentNode = node else { return }

            if !treeView.isCell(forItemExpanded: currentNode) {
                treeView.expandRow(forItem: currentNode, with: .none)
                isExpanded = true
            }
        }

        if isExpanded, let finalNode = node {
            treeView.selectRow(forItem: finalNode, animated: true, scrollPosition: .middle)
        }
    }

    // MARK: - RATreeView DataSource & Delegate
    func treeView(_ treeView: RATreeView, numberOfChildrenOfItem item: Any?) -> Int {
        if isSearchActive {
            return filteredItems.count
        }

        if item == nil {
            return (tree?["children"] as? NSArray)?.count ?? 0
        } else {
            return ((item as! [String: Any])["children"] as? NSArray)?.count ?? 0
        }
    }

    func treeView(_ treeView: RATreeView, cellForItem item: Any?) -> UITableViewCell {
        let item = item as! [String: Any]
        let isLeaf = item["children"] == nil
        let identifier = isLeaf ? "leafCell" : "indexCell"

        var cell = treeView.dequeueReusableCell(withIdentifier: identifier) as? EnhancedIndexCell

        if cell == nil {
            cell = EnhancedIndexCell(style: .subtitle, reuseIdentifier: identifier, isLeaf: isLeaf)
            cell?.configure(with: currentTheme)
        }

        cell?.configure(with: item, theme: currentTheme, level: treeView.levelForCell(forItem: item))

        if !isLeaf {
            cell?.accessoryButton.addTarget(self, action: #selector(openAsPageFromCellButton(_:)), for: .touchUpInside)
        }

        return cell!
    }

    func treeView(_ treeView: RATreeView, child index: Int, ofItem item: Any?) -> Any {
        if isSearchActive {
            return filteredItems[index]
        }

        if let parentItem = item as? [String: Any],
           let children = parentItem["children"] as? NSArray {
            return children[index] as! [String: Any]
        } else if let children = tree?["children"] as? NSArray {
            return children[index] as! [String: Any]
        }

        return [:]
    }

    func treeView(_ treeView: RATreeView, indentationLevelForRowForItem item: Any) -> Int {
        return treeView.levelForCell(forItem: item) * 2
    }

    func treeView(_ treeView: RATreeView, didSelectRowForItem item: Any) {
        treeView.deselectRow(forItem: item, animated: true)
        let item = item as! [String: Any]

        HapticFeedback.selectionChanged()

        if item["children"] == nil {
            openItem(item)
        } else {
            // Toggle expansion
            if treeView.isCell(forItemExpanded: item) {
                treeView.collapseRow(forItem: item, with: .automatic)
            } else {
                treeView.expandRow(forItem: item, expandChildren: false, with: .automatic)
            }
        }
    }

    func treeView(_ treeView: RATreeView, accessoryButtonTappedForRowForItem item: Any) {
        let item = item as! [String: Any]
        HapticFeedback.lightImpact()
        openItem(item)
    }

    func treeView(_ treeView: RATreeView, editActionsForItem item: Any) -> [Any]? {
        return []
    }

    func treeView(_ treeView: RATreeView, didExpandRowForItem item: Any) {
        // Handle expansion if needed
    }

    func treeView(_ treeView: RATreeView, didCollapseRowForItem item: Any) {
        // Handle collapse if needed
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
}

// MARK: - UISearchResultsUpdating
extension EnhancedSutraIndexViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        guard let searchText = searchController.searchBar.text else { return }

        isSearchActive = !searchText.isEmpty

        if isSearchActive {
            filterItems(with: searchText)
        } else {
            filteredItems.removeAll()
        }

        treeView.reloadData()
    }

    private func filterItems(with searchText: String) {
        filteredItems.removeAll()
        guard let tree = tree else { return }

        filterItemsRecursive(in: tree, searchText: searchText.lowercased())
    }

    private func filterItemsRecursive(in item: [String: Any], searchText: String) {
        if let name = item["name"] as? String,
           name.lowercased().contains(searchText) {
            filteredItems.append(item)
        }

        if let children = item["children"] as? NSArray {
            for child in children {
                if let childItem = child as? [String: Any] {
                    filterItemsRecursive(in: childItem, searchText: searchText)
                }
            }
        }
    }
}

// MARK: - Enhanced Index Cell
private class EnhancedIndexCell: UITableViewCell {

    // MARK: - UI Components
    private let containerView = UIView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let iconImageView = UIImageView()
    private let separatorView = UIView()

    var accessoryButton: UIButton!

    // MARK: - Properties
    private var currentTheme: SutraTheme = .light
    private var isLeaf: Bool = false

    // MARK: - Initialization
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    init(style: UITableViewCell.CellStyle, reuseIdentifier: String?, isLeaf: Bool) {
        self.isLeaf = isLeaf
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    // MARK: - Setup
    private func setupUI() {
        selectionStyle = .none
        backgroundColor = .clear

        setupContainerView()
        setupIconImageView()
        setupLabels()
        setupSeparator()
        setupAccessoryButton()
        setupConstraints()
    }

    private func setupContainerView() {
        contentView.addSubview(containerView)
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.layer.cornerRadius = SutraSpacing.smallCornerRadius
        containerView.layer.masksToBounds = true
    }

    private func setupIconImageView() {
        containerView.addSubview(iconImageView)
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.tintColor = SutraColors.Semantic.textTertiary(theme: .light)
    }

    private func setupLabels() {
        containerView.addSubview(titleLabel)
        containerView.addSubview(subtitleLabel)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = SutraTypography.Typography.body
        titleLabel.textColor = SutraColors.Semantic.primary(theme: .light)
        titleLabel.numberOfLines = 0

        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.font = SutraTypography.Typography.caption
        subtitleLabel.textColor = SutraColors.Semantic.textSecondary(theme: .light)
        subtitleLabel.numberOfLines = 0
    }

    private func setupSeparator() {
        containerView.addSubview(separatorView)
        separatorView.translatesAutoresizingMaskIntoConstraints = false
        separatorView.backgroundColor = SutraColors.Semantic.divider(theme: .light)
    }

    private func setupAccessoryButton() {
        if !isLeaf {
            accessoryButton = UIButton(type: .custom)
            accessoryButton.translatesAutoresizingMaskIntoConstraints = false
            accessoryButton.setImage(UIImage(systemName: "chevron.right"), for: .normal)
            accessoryButton.tintColor = SutraColors.Semantic.textTertiary(theme: .light)
            accessoryButton.backgroundColor = SutraColors.Semantic.surface(theme: .light)
            accessoryButton.layer.cornerRadius = SutraSpacing.xsCornerRadius
            accessoryButton.layer.masksToBounds = true
            containerView.addSubview(accessoryButton)
        }
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: SutraSpacing.xs),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: SutraSpacing.small),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -SutraSpacing.small),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -SutraSpacing.xs),

            iconImageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: SutraSpacing.medium),
            iconImageView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 20),
            iconImageView.heightAnchor.constraint(equalToConstant: 20),

            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: SutraSpacing.small),
            titleLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: SutraSpacing.medium),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: containerView.trailingAnchor, constant: -SutraSpacing.medium),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: SutraSpacing.xs),
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: containerView.trailingAnchor, constant: -SutraSpacing.medium),
            subtitleLabel.bottomAnchor.constraint(lessThanOrEqualTo: containerView.bottomAnchor, constant: -SutraSpacing.small),

            separatorView.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            separatorView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -SutraSpacing.medium),
            separatorView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            separatorView.heightAnchor.constraint(equalToConstant: 1)
        ])

        if let accessoryButton = accessoryButton {
            NSLayoutConstraint.activate([
                accessoryButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -SutraSpacing.medium),
                accessoryButton.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
                accessoryButton.widthAnchor.constraint(equalToConstant: 32),
                accessoryButton.heightAnchor.constraint(equalToConstant: 32)
            ])

            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: accessoryButton.leadingAnchor, constant: -SutraSpacing.small).isActive = true
            subtitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: accessoryButton.leadingAnchor, constant: -SutraSpacing.small).isActive = true
        }
    }

    // MARK: - Configuration
    func configure(with item: [String: Any], theme: SutraTheme, level: Int) {
        currentTheme = theme

        // Update colors
        containerView.backgroundColor = SutraColors.Semantic.card(theme: theme)
        titleLabel.textColor = isLeaf ? SutraColors.Semantic.accent(theme: theme) : SutraColors.Semantic.primary(theme: theme)
        subtitleLabel.textColor = SutraColors.Semantic.textSecondary(theme: theme)
        iconImageView.tintColor = SutraColors.Semantic.textTertiary(theme: theme)
        separatorView.backgroundColor = SutraColors.Semantic.divider(theme: theme)
        accessoryButton?.tintColor = SutraColors.Semantic.textTertiary(theme: theme)

        // Update content
        titleLabel.text = item["name"] as? String

        // Configure icon based on level and type
        if isLeaf {
            iconImageView.image = UIImage(systemName: "doc.text")
            accessoryType = .none
        } else {
            iconImageView.image = UIImage(systemName: "folder.fill")
            accessoryType = .disclosureIndicator
        }

        // Update indentation
        let indentInset = CGFloat(level) * 20 + 16
        containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: indentInset).isActive = true

        // Accessibility
        accessibilityLabel = item["name"] as? String
        accessibilityHint = isLeaf ?
            NSLocalizedString("tap_to_open_content", comment: "Tap to open content") :
            NSLocalizedString("tap_to_expand_section", comment: "Tap to expand this section")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        titleLabel.text = nil
        subtitleLabel.text = nil
        iconImageView.image = nil
        accessoryButton?.removeTarget(nil, action: nil, for: .touchUpInside)
    }

    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)

        UIView.animate(withDuration: 0.1) {
            self.containerView.backgroundColor = highlighted ?
                SutraColors.Semantic.primary(theme: self.currentTheme).withAlphaComponent(0.1) :
                SutraColors.Semantic.card(theme: self.currentTheme)
        }
    }
}