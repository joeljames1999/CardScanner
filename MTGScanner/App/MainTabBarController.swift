import UIKit

// MARK: - MainTabBarController

final class MainTabBarController: UITabBarController {

    override func viewDidLoad() {
        super.viewDidLoad()
        setupTabs()
        styleTabBar()
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
        selectedIndex = 1
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
            image: UIImage(systemName: "viewfinder"),
            tag: 2
        )
        // Use a filled viewfinder for the selected state
        vc.tabBarItem.selectedImage = UIImage(systemName: "viewfinder.circle.fill")
        let nav = UINavigationController(rootViewController: vc)
        nav.navigationBar.prefersLargeTitles = true
        return nav
    }

    // MARK: Style

    private func styleTabBar() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .systemBackground

        // Normal item
        appearance.stackedLayoutAppearance.normal.iconColor        = .secondaryLabel
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor.secondaryLabel,
            .font: UIFont.systemFont(ofSize: 10, weight: .medium)
        ]

        // Selected item
        appearance.stackedLayoutAppearance.selected.iconColor        = .systemBlue
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor.systemBlue,
            .font: UIFont.systemFont(ofSize: 10, weight: .semibold)
        ]

        tabBar.standardAppearance    = appearance
        tabBar.scrollEdgeAppearance  = appearance
    }
}
