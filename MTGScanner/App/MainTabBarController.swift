import UIKit
import Combine

// MARK: - MainTabBarController

final class MainTabBarController: UITabBarController {

    private let adBannerContainerView = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
    private let adBannerView = AdMobBannerView()
    private var adBannerHeightConstraint: NSLayoutConstraint?
    private var consentFlowTask: Task<Void, Never>?
    private var bannerLoadTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    private weak var initialDatabasePromptController: InitialDatabaseDownloadViewController?
    private var hasStartedConsentFlow = false
    private var hasRequestedBannerAd = false
    private var hasShownInitialDatabasePrompt = false

    override func viewDidLoad() {
        super.viewDidLoad()
        setupTabs()
        styleTabBar()
        styleNavigationBars()
        setupAdBanner()
        observeBulkDownloadState()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAdConsentDidUpdate),
            name: .adConsentDidUpdate,
            object: nil
        )
        delegate = self
    }

    deinit {
        consentFlowTask?.cancel()
        bannerLoadTask?.cancel()
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        scheduleInitialDatabasePromptIfNeeded()

        guard !hasStartedConsentFlow else {
            scheduleBannerAdRequest()
            return
        }

        hasStartedConsentFlow = true
        scheduleConsentFlow()
        scheduleBannerAdRequest()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateAdBannerLayout()
        view.bringSubviewToFront(adBannerContainerView)
        tabBar.superview?.bringSubviewToFront(tabBar)
    }

    // MARK: Setup

    private func setupTabs() {
        viewControllers = [
            makeNav(HomeViewController(),       title: "Home",       icon: "house",            tag: 0),
            makeNav(CardSearchViewController(),     title: "Search",     icon: "magnifyingglass",  tag: 1),
            makeScannerTab(),
            makeNav(CollectionViewController(), title: "Collection", icon: "rectangle.stack",  tag: 3),
            makeNav(MenuViewController(),       title: "Menu",       icon: "line.3.horizontal", tag: 4),
        ]
        // opening screen
        selectedIndex = 0
    }

    private func makeNav(_ root: UIViewController, title: String, icon: String, tag: Int) -> UINavigationController {
        root.tabBarItem = UITabBarItem(
            title: title,
            image: UIImage(systemName: icon),
            tag: tag
        )
        let nav = UINavigationController(rootViewController: root)
        nav.navigationBar.prefersLargeTitles = true
        nav.delegate = self
        return nav
    }

    private func makeScannerTab() -> UINavigationController {

        let vc = ScannerViewController()

        vc.tabBarItem = UITabBarItem(
            title: "Scan",
            image: UIImage(
                systemName: "viewfinder.circle"
            ),
            selectedImage: UIImage(
                systemName: "viewfinder.circle.fill"
            )
        )
        vc.tabBarItem.tag = 2
        
        tabBar.tintColor = UIColor.accentColor

        vc.tabBarItem.imageInsets =
            UIEdgeInsets(
                top: -2,
                left: 0,
                bottom: 2,
                right: 0
            )
        
        let nav =
            UINavigationController(
                rootViewController: vc
            )

        nav.navigationBar.prefersLargeTitles = true
        nav.delegate = self

        return nav
    }

    private func setupAdBanner() {
        adBannerContainerView.translatesAutoresizingMaskIntoConstraints = false
        adBannerContainerView.clipsToBounds = true
        view.addSubview(adBannerContainerView)

        adBannerView.translatesAutoresizingMaskIntoConstraints = false
        adBannerContainerView.contentView.addSubview(adBannerView)

        let heightConstraint = adBannerContainerView.heightAnchor.constraint(equalToConstant: AdMobBannerView.preferredHeight)
        adBannerHeightConstraint = heightConstraint

        NSLayoutConstraint.activate([
            adBannerContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            adBannerContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            adBannerContainerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            heightConstraint,

            adBannerView.centerXAnchor.constraint(equalTo: adBannerContainerView.contentView.centerXAnchor),
            adBannerView.centerYAnchor.constraint(equalTo: adBannerContainerView.contentView.centerYAnchor),
            adBannerView.widthAnchor.constraint(equalToConstant: 320),
            adBannerView.heightAnchor.constraint(equalToConstant: AdMobBannerView.preferredHeight)
        ])

        updateAdBannerLayout()
    }

    @objc private func handleAdConsentDidUpdate() {
        scheduleBannerAdRequest()
    }

    private func observeBulkDownloadState() {
        ScryfallBulkService.shared.$downloadState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.handleBulkDownloadState(state)
            }
            .store(in: &cancellables)
    }

    private func handleBulkDownloadState(_ state: ScryfallBulkService.DownloadState) {
        initialDatabasePromptController?.update(state)

        if state == .done {
            initialDatabasePromptController?.dismiss(animated: true)
            initialDatabasePromptController = nil
        }
    }

    private func scheduleInitialDatabasePromptIfNeeded() {
        guard !hasShownInitialDatabasePrompt else { return }
        guard !ScryfallBulkService.shared.isDataPresent else { return }
        guard initialDatabasePromptController == nil else { return }

        hasShownInitialDatabasePrompt = true

        let prompt = InitialDatabaseDownloadViewController(
            onDownload: {
                Task { await ScryfallBulkService.shared.forceRefresh() }
            },
            onCancel: { [weak self] in
                self?.initialDatabasePromptController = nil
            }
        )

        prompt.modalPresentationStyle = .overFullScreen
        prompt.modalTransitionStyle = .crossDissolve
        initialDatabasePromptController = prompt
        present(prompt, animated: true)
    }

    private func scheduleConsentFlow() {
        guard consentFlowTask == nil else { return }

        consentFlowTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            guard !Task.isCancelled else { return }
            consentFlowTask = nil
            AdConsentManager.shared.gatherConsent(from: self)
            scheduleBannerAdRequest()
        }
    }

    private func scheduleBannerAdRequest() {
        guard bannerLoadTask == nil, !hasRequestedBannerAd else { return }

        bannerLoadTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            bannerLoadTask = nil
            requestBannerAdIfAllowed()
        }
    }

    private func requestBannerAdIfAllowed() {
        guard !hasRequestedBannerAd else { return }
        guard !shouldHideAdBanner else {
            AppLog.debug("[AdMobBannerView] Deferring banner load while ads are hidden on this screen.")
            return
        }
        guard AdConsentManager.shared.canRequestAds else {
            AppLog.debug("[AdMobBannerView] Waiting for consent before loading banner.")
            return
        }

        hasRequestedBannerAd = true
        adBannerView.load(
            adUnitID: AdMobConfiguration.bannerAdUnitID,
            rootViewController: self
        )
    }

    private var shouldHideAdBanner: Bool {
        if selectedIndex == 2 {
            return true
        }

        guard let navigationController = selectedViewController as? UINavigationController else {
            return false
        }

        return navigationController.topViewController is LifeCounterViewController
    }

    private func updateAdBannerLayout() {
        let isHidden = shouldHideAdBanner
        setAdBannerHidden(isHidden)

        if !isHidden {
            scheduleBannerAdRequest()
        }
    }

    private func setAdBannerHidden(_ isHidden: Bool) {
        let bannerHeight = AdMobBannerView.preferredHeight
        adBannerContainerView.isHidden = isHidden
        adBannerHeightConstraint?.constant = isHidden ? 0 : bannerHeight
        tabBar.transform = isHidden ? .identity : CGAffineTransform(translationX: 0, y: -bannerHeight)
        additionalSafeAreaInsets.bottom = isHidden ? 0 : bannerHeight
        view.layoutIfNeeded()
    }

    // MARK: Style

    private func styleTabBar() {

        let appearance = UITabBarAppearance()

        appearance.configureWithDefaultBackground()

        appearance.backgroundEffect = UIBlurEffect(
            style: .systemUltraThinMaterial
        )

        appearance.backgroundColor =
            UIColor.systemBackground.withAlphaComponent(0.85)

        appearance.shadowColor =
            UIColor.separator.withAlphaComponent(0.3)

        let itemAppearance =
            appearance.stackedLayoutAppearance

        // MARK: Normal

        itemAppearance.normal.iconColor =
            .secondaryLabel

        itemAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor.secondaryLabel
        ]

        // MARK: Selected

        itemAppearance.selected.iconColor =
        UIColor.brandBlue

        itemAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor.brandBlue
        ]

        tabBar.standardAppearance = appearance
        tabBar.scrollEdgeAppearance = appearance

        tabBar.tintColor =
        UIColor.brandBlue

        tabBar.unselectedItemTintColor = UIColor.systemGray2

        tabBar.isTranslucent = true
    }
    
    private func styleNavigationBars() {

        let appearance =
            UINavigationBarAppearance()

        appearance.configureWithTransparentBackground()

        appearance.backgroundEffect =
            UIBlurEffect(
                style: .systemMaterial
            )

        appearance.shadowColor = .clear

        UINavigationBar.appearance()
            .standardAppearance = appearance

        UINavigationBar.appearance()
            .scrollEdgeAppearance = appearance

        UINavigationBar.appearance()
            .tintColor = UIColor.brandBlue
    }
}

private final class InitialDatabaseDownloadViewController: UIViewController {

    private let onDownload: () -> Void
    private let onCancel: () -> Void
    private var hasStartedDownload = false

    private let containerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .systemBackground
        view.layer.cornerRadius = 16
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.2
        view.layer.shadowRadius = 18
        view.layer.shadowOffset = CGSize(width: 0, height: 8)
        return view
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 20, weight: .semibold)
        label.textAlignment = .center
        label.text = "Download Card Database"
        return label
    }()

    private let messageLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 15)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        label.text = "No local card database was found. Download the Scryfall card database now so search and scanning can work."
        return label
    }()

    private let progressView: UIProgressView = {
        let progressView = UIProgressView(progressViewStyle: .default)
        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.isHidden = true
        progressView.progress = 0
        return progressView
    }()

    private let statusLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 2
        label.isHidden = true
        return label
    }()

    private lazy var downloadButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Download", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        button.addTarget(self, action: #selector(downloadTapped), for: .touchUpInside)
        return button
    }()

    private lazy var cancelButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Not Now", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17)
        button.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        return button
    }()

    init(onDownload: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self.onDownload = onDownload
        self.onCancel = onCancel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupLayout()
    }

    func update(_ state: ScryfallBulkService.DownloadState) {
        switch state {
        case .idle:
            break

        case .fetchingManifest:
            showProgress(title: "Checking for Updates", status: "Fetching card database manifest...", progress: nil)

        case .downloading(let progress, let totalBytes):
            let received = Int64(Double(totalBytes) * progress)
            let total = ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
            let done = ByteCountFormatter.string(fromByteCount: received, countStyle: .file)
            showProgress(
                title: "Downloading Card Database",
                status: "\(done) / \(total)  ·  \(Int(progress * 100))%",
                progress: Float(progress)
            )

        case .importing(let done, _):
            showProgress(
                title: "Importing Cards",
                status: done > 0 ? "Imported \(done.formatted()) cards..." : "Writing cards to local database...",
                progress: nil
            )

        case .done:
            showProgress(title: "Card Database Ready", status: "Import complete.", progress: 1)

        case .failed(let message):
            hasStartedDownload = false
            titleLabel.text = "Update Failed"
            messageLabel.text = message
            progressView.isHidden = true
            statusLabel.isHidden = true
            downloadButton.isHidden = false
            cancelButton.isHidden = false
            downloadButton.setTitle("Try Again", for: .normal)
            cancelButton.setTitle("OK", for: .normal)
        }
    }

    private func setupLayout() {
        view.backgroundColor = UIColor.black.withAlphaComponent(0.35)
        view.addSubview(containerView)

        let buttonStack = UIStackView(arrangedSubviews: [cancelButton, downloadButton])
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        buttonStack.axis = .horizontal
        buttonStack.distribution = .fillEqually

        let contentStack = UIStackView(arrangedSubviews: [
            titleLabel,
            messageLabel,
            progressView,
            statusLabel,
            buttonStack
        ])
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.axis = .vertical
        contentStack.spacing = 16
        containerView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            containerView.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 28),
            containerView.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -28),
            containerView.widthAnchor.constraint(lessThanOrEqualToConstant: 340),

            contentStack.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 22),
            contentStack.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            contentStack.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16),

            progressView.heightAnchor.constraint(equalToConstant: 4),
            cancelButton.heightAnchor.constraint(equalToConstant: 44),
            downloadButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    private func showProgress(title: String, status: String, progress: Float?) {
        hasStartedDownload = true
        titleLabel.text = title
        messageLabel.text = "Please keep the app open while the card database downloads."
        statusLabel.text = status
        statusLabel.isHidden = false
        progressView.isHidden = progress == nil
        progressView.setProgress(progress ?? 0, animated: true)
        downloadButton.isHidden = true
        cancelButton.isHidden = true
    }

    @objc private func downloadTapped() {
        guard !hasStartedDownload else { return }
        showProgress(title: "Checking for Updates", status: "Starting download...", progress: nil)
        onDownload()
    }

    @objc private func cancelTapped() {
        onCancel()
        dismiss(animated: true)
    }
}

extension MainTabBarController: UITabBarControllerDelegate, UINavigationControllerDelegate {

    func navigationController(
        _ navigationController: UINavigationController,
        didShow viewController: UIViewController,
        animated: Bool
    ) {
        updateAdBannerLayout()
    }

    func tabBarController(
        _ tabBarController: UITabBarController,
        shouldSelect viewController: UIViewController
    ) -> Bool {
        if viewController.tabBarItem.tag == 2 {
            setAdBannerHidden(true)
        }

        return true
    }

    func tabBarController(
        _ tabBarController: UITabBarController,
        didSelect viewController: UIViewController
    ) {
        updateAdBannerLayout()

        guard
            viewController.tabBarItem.tag == 3,
            let navigationController = viewController as? UINavigationController
        else {
            return
        }

        navigationController.popToRootViewController(animated: false)
    }
}
