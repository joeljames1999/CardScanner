import UIKit

final class HomeViewController: UIViewController {

    // MARK: - Constants

    private let accentColor = UIColor(
        red: 85 / 255,
        green: 189 / 255,
        blue: 251 / 255,
        alpha: 1
    )

    // MARK: - UI

    private let scrollView = UIScrollView()
    private let contentView = UIView()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Welcome Back"
        label.font = .systemFont(
            ofSize: 32,
            weight: .bold
        )
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "What would you like to do?"
        label.font = .systemFont(
            ofSize: 17
        )
        label.textColor = .secondaryLabel
        return label
    }()

    private lazy var scanButton = makeActionButton(
        title: "Scan Cards",
        image: "viewfinder"
    )

    private lazy var searchButton = makeActionButton(
        title: "Search Cards",
        image: "magnifyingglass"
    )

    private let recentTitleLabel: UILabel = {
        let label = UILabel()
        label.text = "Recently Viewed"
        label.font = .systemFont(
            ofSize: 22,
            weight: .bold
        )
        return label
    }()

    private let recentPlaceholderLabel: UILabel = {
        let label = UILabel()
        label.text = "Cards you view will appear here."
        label.font = .systemFont(ofSize: 16)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        return label
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Home"
        view.backgroundColor = .systemBackground

        setupLayout()
    }

    // MARK: - Layout

    private func setupLayout() {

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(scrollView)
        scrollView.addSubview(contentView)

        [
            titleLabel,
            subtitleLabel,
            scanButton,
            searchButton,
            recentTitleLabel,
            recentPlaceholderLabel
        ].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }

        NSLayoutConstraint.activate([

            scrollView.topAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.topAnchor
            ),
            scrollView.leadingAnchor.constraint(
                equalTo: view.leadingAnchor
            ),
            scrollView.trailingAnchor.constraint(
                equalTo: view.trailingAnchor
            ),
            scrollView.bottomAnchor.constraint(
                equalTo: view.bottomAnchor
            ),

            contentView.topAnchor.constraint(
                equalTo: scrollView.topAnchor
            ),
            contentView.leadingAnchor.constraint(
                equalTo: scrollView.leadingAnchor
            ),
            contentView.trailingAnchor.constraint(
                equalTo: scrollView.trailingAnchor
            ),
            contentView.bottomAnchor.constraint(
                equalTo: scrollView.bottomAnchor
            ),
            contentView.widthAnchor.constraint(
                equalTo: scrollView.widthAnchor
            ),

            titleLabel.topAnchor.constraint(
                equalTo: contentView.topAnchor,
                constant: 24
            ),
            titleLabel.leadingAnchor.constraint(
                equalTo: contentView.leadingAnchor,
                constant: 20
            ),

            subtitleLabel.topAnchor.constraint(
                equalTo: titleLabel.bottomAnchor,
                constant: 4
            ),
            subtitleLabel.leadingAnchor.constraint(
                equalTo: titleLabel.leadingAnchor
            ),

            scanButton.topAnchor.constraint(
                equalTo: subtitleLabel.bottomAnchor,
                constant: 24
            ),
            scanButton.leadingAnchor.constraint(
                equalTo: contentView.leadingAnchor,
                constant: 20
            ),
            scanButton.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor,
                constant: -20
            ),
            scanButton.heightAnchor.constraint(
                equalToConstant: 72
            ),

            searchButton.topAnchor.constraint(
                equalTo: scanButton.bottomAnchor,
                constant: 12
            ),
            searchButton.leadingAnchor.constraint(
                equalTo: scanButton.leadingAnchor
            ),
            searchButton.trailingAnchor.constraint(
                equalTo: scanButton.trailingAnchor
            ),
            searchButton.heightAnchor.constraint(
                equalToConstant: 72
            ),

            recentTitleLabel.topAnchor.constraint(
                equalTo: searchButton.bottomAnchor,
                constant: 32
            ),
            recentTitleLabel.leadingAnchor.constraint(
                equalTo: scanButton.leadingAnchor
            ),

            recentPlaceholderLabel.topAnchor.constraint(
                equalTo: recentTitleLabel.bottomAnchor,
                constant: 12
            ),
            recentPlaceholderLabel.leadingAnchor.constraint(
                equalTo: recentTitleLabel.leadingAnchor
            ),
            recentPlaceholderLabel.trailingAnchor.constraint(
                equalTo: scanButton.trailingAnchor
            ),
            recentPlaceholderLabel.bottomAnchor.constraint(
                equalTo: contentView.bottomAnchor,
                constant: -40
            )
        ])

        scanButton.addTarget(
            self,
            action: #selector(scanTapped),
            for: .touchUpInside
        )

        searchButton.addTarget(
            self,
            action: #selector(searchTapped),
            for: .touchUpInside
        )
    }

    // MARK: - Helpers

    private func makeActionButton(
        title: String,
        image: String
    ) -> UIButton {

        var config = UIButton.Configuration.filled()

        config.title = title
        config.image = UIImage(systemName: image)
        config.imagePadding = 10
        config.cornerStyle = .large

        let button = UIButton(configuration: config)

        button.tintColor = .white
        button.configuration?.baseBackgroundColor = accentColor

        return button
    }

    // MARK: - Actions

    @objc private func scanTapped() {

        tabBarController?.selectedIndex = 2
    }

    @objc private func searchTapped() {

        tabBarController?.selectedIndex = 1
    }
}
