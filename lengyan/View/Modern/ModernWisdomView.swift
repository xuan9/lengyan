import SwiftUI

// MARK: - Page Model
enum WisdomPage: Identifiable {
    case verse(DailyVerse)
    case lessonComplete
    
    var id: String {
        switch self {
        case .verse(let v): return v.path + v.date.description
        case .lessonComplete: return "lesson_complete"
        }
    }
}

// MARK: - Main View
struct ModernWisdomView: View {
    @State private var pages: [WisdomPage] = []
    @State private var currentIndex: Int = 0
    @State private var isLoaded: Bool = false
    
    var body: some View {
        ZStack {
            Color(uiColor: SutraDesignTokens.shared.color(for: .background)).ignoresSafeArea()
            
            if isLoaded {
                VerticalPageView(
                    pageCount: pages.count,
                    currentIndex: $currentIndex
                ) { index in
                    let page = pages[index]
                    switch page {
                    case .verse(let verse):
                        WisdomVerseCard(verse: verse)
                    case .lessonComplete:
                        WisdomLessonCompleteView()
                    }
                }
                .ignoresSafeArea()
            }
        }
        .onAppear {
            loadPages()
        }
    }
    
    private func loadPages() {
        // recentVerses returns [Today, Yesterday, ... 7 Days Ago]
        // We want to reverse it so the oldest is at index 0, and today is at the end.
        // This way, you scroll "down" through history, and hit the end after today.
        let recent = DailyVerseProvider.shared.recentVerses().reversed()
        var newPages: [WisdomPage] = recent.map { .verse($0) }
        newPages.append(.lessonComplete) // The final view
        
        self.pages = newPages
        
        // Start at today's verse (which is the second to last item)
        if newPages.count > 1 {
            self.currentIndex = newPages.count - 2
        } else {
            self.currentIndex = 0
        }
        
        self.isLoaded = true
    }
}

// MARK: - Verse Card View
struct WisdomVerseCard: View {
    let verse: DailyVerse
    
    var body: some View {
        ZStack {
            // Background
            Color(uiColor: SutraDesignTokens.shared.color(for: .background))
                .ignoresSafeArea()
            
            VStack(spacing: 40) {
                // Header (Date)
                Text(formattedDate(verse.date))
                    .font(.system(size: 14, weight: .light, design: .serif))
                    .foregroundColor(Color(uiColor: SutraDesignTokens.shared.color(for: .textSecondary)).opacity(0.6))
                    .tracking(2)
                
                Spacer()
                
                // Verse Text
                Text(verse.text)
                    .font(.custom("STKaiti", size: 28))
                    .foregroundColor(Color(uiColor: SutraDesignTokens.shared.color(for: .textPrimary)))
                    .lineSpacing(16)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
                
                // Source
                Text("── \(verse.source) ──")
                    .font(.custom("STKaiti", size: 16))
                    .foregroundColor(Color(uiColor: SutraDesignTokens.shared.color(for: .textSecondary)))
                    .padding(.top, 20)
                
                Spacer()
                
                // Footer (Action)
                Button(action: {
                    openSutra()
                }) {
                    Text("进入经文深读")
                        .font(.custom("STKaiti", size: 16))
                        .foregroundColor(Color(uiColor: SutraDesignTokens.shared.color(for: .accent)))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(uiColor: SutraDesignTokens.shared.color(for: .decorativeGold)).opacity(0.3), lineWidth: 1)
                        )
                }
                .padding(.bottom, 60)
            }
            .padding(.top, 60)
        }
    }
    
    private func openSutra() {
        if let url = URL(string: "lengyan://verse?path=\(verse.path)") {
            UIApplication.shared.open(url)
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy / MM / dd"
        return formatter.string(from: date)
    }
}

// MARK: - Lesson Complete View
struct WisdomLessonCompleteView: View {
    @State private var isReminderOn: Bool = Prefers.shared.isDailyReminderOn
    @State private var showingAlert = false

    var body: some View {
        ZStack {
            Color(uiColor: SutraDesignTokens.shared.color(for: .background))
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                Spacer()
                
                Text("今日功课已毕")
                    .font(.custom("STKaiti", size: 24))
                    .foregroundColor(Color(uiColor: SutraDesignTokens.shared.color(for: .textPrimary)))
                    .tracking(4)
                
                Text("请安心生活，明日再来")
                    .font(.custom("STKaiti", size: 16))
                    .foregroundColor(Color(uiColor: SutraDesignTokens.shared.color(for: .textSecondary)))
                    .tracking(2)
                
                Spacer()
                
                if !isReminderOn {
                    Button(action: {
                        ReminderManager.shared.requestPermissionAndSchedule { granted in
                            isReminderOn = granted
                            if !granted {
                                showingAlert = true
                            }
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "bell")
                                .font(.system(size: 14))
                            Text("开启每日提醒，每日晨钟，回归宁静")
                                .font(.system(size: 14, weight: .light, design: .serif))
                        }
                        .foregroundColor(Color(uiColor: SutraDesignTokens.shared.color(for: .accent)))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .stroke(Color(uiColor: SutraDesignTokens.shared.color(for: .decorativeGold)).opacity(0.4), lineWidth: 1)
                        )
                    }
                    .padding(.bottom, 60)
                    .transition(.opacity)
                }
            }
            .alert("通知未开启", isPresented: $showingAlert) {
                Button("去设置") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("知道了", role: .cancel) {}
            } message: {
                Text("每日读经提醒需要通知权限。请前往「设置」开启本应用的通知。")
            }
            .onAppear {
                isReminderOn = Prefers.shared.isDailyReminderOn
            }
        }
    }
}

// MARK: - Vertical Page View Wrapper
struct VerticalPageView<Content: View>: UIViewControllerRepresentable {
    var pageCount: Int
    @Binding var currentIndex: Int
    @ViewBuilder var content: (Int) -> Content

    func makeUIViewController(context: Context) -> UIPageViewController {
        let pageViewController = UIPageViewController(
            transitionStyle: .scroll,
            navigationOrientation: .vertical,
            options: nil)
        pageViewController.dataSource = context.coordinator
        pageViewController.delegate = context.coordinator
        return pageViewController
    }

    func updateUIViewController(_ uiViewController: UIPageViewController, context: Context) {
        if let currentVC = uiViewController.viewControllers?.first {
            if currentVC.view.tag != currentIndex {
                let direction: UIPageViewController.NavigationDirection = currentIndex > currentVC.view.tag ? .forward : .reverse
                uiViewController.setViewControllers([context.coordinator.viewController(for: currentIndex)], direction: direction, animated: true)
            }
        } else {
            uiViewController.setViewControllers([context.coordinator.viewController(for: currentIndex)], direction: .forward, animated: false)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
        var parent: VerticalPageView

        init(_ parent: VerticalPageView) {
            self.parent = parent
        }

        func viewController(for index: Int) -> UIViewController {
            let vc = UIHostingController(rootView: parent.content(index))
            vc.view.tag = index
            vc.view.backgroundColor = .clear
            return vc
        }

        func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
            let index = viewController.view.tag
            if index == 0 { return nil }
            return self.viewController(for: index - 1)
        }

        func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
            let index = viewController.view.tag
            if index + 1 == parent.pageCount { return nil }
            return self.viewController(for: index + 1)
        }

        func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
            if completed, let visibleViewController = pageViewController.viewControllers?.first {
                parent.currentIndex = visibleViewController.view.tag
                HapticManager.shared.bookmarkToggle()
            }
        }
    }
}
