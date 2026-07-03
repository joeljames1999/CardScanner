import UIKit

// MARK: - MainTabBarController

final class MainTabBarController: UITabBarController {

    override func viewDidLoad() {
        super.viewDidLoad()

        setupTabs()
        styleTabBar()
        styleNavigationBars()
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

        return nav
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
