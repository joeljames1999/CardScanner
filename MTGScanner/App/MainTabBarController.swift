import UIKit

// MARK: - MainTabBarController

final class MainTabBarController: UITabBarController {

    private let adBannerContainerView = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
    private let adBannerView = AdMobBannerView()
    private var adBannerHeightConstraint: NSLayoutConstraint?

    override func viewDidLoad() {
        super.viewDidLoad()
        print("tab")
        setupTabs()
        styleTabBar()
        styleNavigationBars()
        setupAdBanner()
        delegate = self
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

        adBannerView.load(
            adUnitID: AdMobConfiguration.bannerAdUnitID,
            rootViewController: self
        )
        updateAdBannerLayout()
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
        setAdBannerHidden(shouldHideAdBanner)
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
