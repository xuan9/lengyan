//
//  SutraFrontViewController+Enhanced.swift
//  lengyan
//
//  Created by Claude on 2025/10/28.
//  Copyright © 2025年 xuan. All rights reserved.
//

import UIKit

// MARK: - Enhanced Extension for SutraFrontViewController
extension SutraFrontViewController {

    func applyEnhancedDesign() {
        setupEnhancedHeaderView()
        setupEnhancedTheme()
        applyEnhancedStyling()
    }

    private func setupEnhancedTheme() {
        let colors = SutraColors.currentColors
        view.backgroundColor = colors.background
        treeView.backgroundColor = colors.background
        treeView.separatorColor = colors.separator

        // Enhanced navigation bar styling
        navigationController?.navigationBar.backgroundColor = colors.navigationBar
        navigationController?.navigationBar.barTintColor = colors.navigationBar
        navigationController?.navigationBar.isTranslucent = false

        // Enhanced navigation title
        let titleView = createEnhancedTitleView()
        navigationItem.titleView = titleView

        SutraAccessibility.configureNavigationItem(navigationItem, title: "大佛頂如來密因修證了義諸菩薩萬行首楞嚴經")
    }

    private func createEnhancedTitleView() -> UIView {
        let container = UIView()
        let titleLabel = UILabel()
        let subtitleLabel = UILabel()

        titleLabel.text = "大佛頂如來密因修證了義諸菩薩萬行首楞嚴經"
        titleLabel.font = SutraTypography.navigationFont(size: 16, weight: .medium)
        titleLabel.textColor = SutraColors.currentColors.primaryText
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 2

        let subtitleText = NSLocalizedString("kai_jing_ji", comment: "無上甚深微妙法 百千萬劫難遭遇 我今見聞得受持 願解如來真實義")
        subtitleLabel.text = subtitleText
        subtitleLabel.font = SutraTypography.primaryFont(size: 10)
        subtitleLabel.textColor = SutraColors.currentColors.secondaryText
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 1

        container.addSubview(titleLabel)
        container.addSubview(subtitleLabel)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            subtitleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            subtitleLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        container.translatesAutoresizingMaskIntoConstraints = false
        container.widthAnchor.constraint(equalToConstant: 300).isActive = true
        container.heightAnchor.constraint(equalToConstant: 40).isActive = true

        // Make it interactive
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(openRootIndex))
        container.addGestureRecognizer(tapGesture)
        container.isUserInteractionEnabled = true

        return container
    }

    private func setupEnhancedHeaderView() {
        let colors = SutraColors.currentColors
        let width = view.bounds.width

        let header = UIView(frame: CGRect(x: 0, y: 0, width: width, height: 18 + 90 + 10))
        header.backgroundColor = colors.background

        // Enhanced subtitle with better styling
        let subTitle = UIButton(type: .custom)
        subTitle.frame = CGRect(x: 12, y: 5, width: width - 10, height: 15)
        let subTitleText = NSLocalizedString("kai_jing_ji", comment: "無上甚深微妙法 百千萬劫難遭遇 我今見聞得受持 願解如來真實義")
        subTitle.setTitle(subTitleText, for: .normal)
        subTitle.titleLabel?.font = SutraTypography.primaryFont(size: 12, weight: .regular)
        subTitle.titleLabel?.adjustsFontSizeToFitWidth = true
        subTitle.setTitleColor(colors.secondaryText, for: .normal)
        subTitle.addTarget(self, action: #selector(openRootIndex), for: .touchUpInside)
        header.addSubview(subTitle)

        // Enhanced chapter grid
        let indexes = UIView(frame: CGRect(x: 0, y: 20, width: width, height: 88))
        let chapterButtonWidth = (width - 20) / 5

        for i in 1...10 {
            let btn = createEnhancedChapterButton(
                chapter: i,
                frame: CGRect(
                    x: 10 + CGFloat(chapterButtonWidth) * CGFloat((i > 5 ? i - 5 : i) - 1),
                    y: i < 6 ? 0 : 44,
                    width: Int(chapterButtonWidth),
                    height: 44
                )
            )
            indexes.addSubview(btn)
        }

        header.addSubview(indexes)

        // Enhanced separator
        let px = 1 / UIScreen.main.scale
        let lineFrame = CGRect(x: 0, y: header.frame.height - px, width: treeView.frame.size.width, height: px)
        let line = UIView(frame: lineFrame)
        line.backgroundColor = colors.separator
        header.addSubview(line)

        treeView.treeHeaderView = header
    }

    private func createEnhancedChapterButton(chapter: Int, frame: CGRect) -> UIButton {
        let btn = SutraEnhancedButton(style: .chapter)
        btn.frame = frame
        btn.setTitle(NSLocalizedString("chapter_\(chapter)", comment: "chapter_name"), for: .normal)
        btn.tag = chapter - 1
        btn.addTarget(self, action: #selector(onSutraChapterButtonTouchUp(_:)), for: .touchUpInside)

        // Configure accessibility
        let chapterTitle = NSLocalizedString("chapter_\(chapter)", comment: "chapter_name")
        SutraAccessibility.configureButton(btn, title: chapterTitle, hint: "Double tap to open \(chapterTitle)")

        return btn
    }

    private func applyEnhancedStyling() {
        // Enhanced tree view styling
        if let tree = self.tree {
            treeView.reloadData()
        }

        // Enhanced footer styling
        setupEnhancedFooterView()
    }

    private func setupEnhancedFooterView() {
        let colors = SutraColors.currentColors
        let width = view.bounds.width

        // Remove old footer if exists
        treeView.treeFooterView = nil

        let footer = UIView(frame: CGRect(x: 5, y: 2, width: width - 20, height: 140))
        footer.backgroundColor = colors.background

        // Enhanced separator
        let footerSeparator = UIView(frame: CGRect(x: 0, y: 2, width: width - 10, height: 1))
        footerSeparator.backgroundColor = colors.separator
        footer.addSubview(footerSeparator)

        // Enhanced footer text
        let footerText1 = NSLocalizedString("footer_txt_1", comment: "南無楞嚴會上佛菩薩\n南無楞嚴會上佛菩薩\n南無楞嚴會上佛菩薩")
        let footerLabel = UILabel(frame: CGRect(x: 20, y: 10, width: width - 20, height: 60))
        footerLabel.text = footerText1
        footerLabel.numberOfLines = 3
        footerLabel.textAlignment = .center
        footerLabel.font = SutraTypography.primaryFont(size: 14, weight: .medium)
        footerLabel.textColor = colors.primaryText
        footerLabel.adjustsFontSizeToFitWidth = true
        footer.addSubview(footerLabel)

        // Enhanced link button
        let footerText2 = NSLocalizedString("footer_txt_2", comment: "經文和科判均選自法界佛教總會《大佛頂首楞嚴經》淺釋網站")
        let linkButton = UIButton(frame: CGRect(x: 10, y: 70, width: width - 30, height: 20))
        linkButton.setTitle(footerText2, for: .normal)
        linkButton.contentHorizontalAlignment = .center
        linkButton.setImage(UIImage(named: "ic_link")?.withRenderingMode(.alwaysTemplate), for: .normal)
        linkButton.addTarget(self, action: #selector(openDrbaLink(_:)), for: .touchUpInside)
        linkButton.semanticContentAttribute = .forceRightToLeft
        linkButton.titleLabel?.font = SutraTypography.primaryFont(size: 10)
        linkButton.titleLabel?.adjustsFontSizeToFitWidth = true
        linkButton.setTitleColor(colors.accent, for: .normal)
        linkButton.tintColor = colors.accent
        footer.addSubview(linkButton)

        // Enhanced description
        let footerText3 = NSLocalizedString("footer_txt_3", comment: "感恩法界佛教總會！本屏中列出部分關鍵科判以方便檢索，可點擊經名打開完整科判。")
        let footerLabel2 = UILabel(frame: CGRect(x: 10, y: 85, width: width - 20, height: 40))
        footerLabel2.text = footerText3
        footerLabel2.textAlignment = .center
        footerLabel2.numberOfLines = 3
        footerLabel2.font = SutraTypography.primaryFont(size: 10)
        footerLabel2.textColor = colors.secondaryText
        footerLabel2.adjustsFontSizeToFitWidth = true
        footer.addSubview(footerLabel2)

        treeView.treeFooterView = footer
    }

    // MARK: - Enhanced Theme Toggle
    @objc func toggleTheme() {
        SutraThemeManager.shared.cycleTheme()
        applyEnhancedDesign()
    }
}

// MARK: - Enhanced Tree View Data Source and Delegate
extension SutraFrontViewController {

    override func treeView(_ treeView: RATreeView, cellForItem item: Any?) -> UITableViewCell {
        let cell = super.treeView(treeView, cellForItem: item) as! UITableViewCell
        let colors = SutraColors.currentColors

        // Enhanced cell styling
        cell.backgroundColor = colors.background
        cell.textLabel?.textColor = colors.primaryText
        cell.textLabel?.font = SutraTypography.primaryFont(size: 16, weight: .regular)
        cell.tintColor = colors.accent
        cell.selectedBackgroundView = UIView()
        cell.selectedBackgroundView?.backgroundColor = colors.chapterButton

        return cell
    }
}