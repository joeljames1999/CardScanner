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

    private var recentCards: [RecentCard] = []

    private lazy var recentCollectionView: UICollectionView = {

        let layout = UICollectionViewFlowLayout()

        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 12

        let cv = UICollectionView(
            frame: .zero,
            collectionViewLayout: layout
        )

        cv.translatesAutoresizingMaskIntoConstraints = false
        cv.backgroundColor = .clear

        cv.register(
            RecentCardCell.self,
            forCellWithReuseIdentifier: RecentCardCell.reuseID
        )

        cv.dataSource = self
        cv.delegate = self

        return cv
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Home"
        view.backgroundColor = .systemBackground

        setupLayout()
    }

    override func viewWillAppear(
        _ animated: Bool
    ) {
        super.viewWillAppear(animated)

        recentCards =
        RecentlyViewedStore.shared.cards

        recentCollectionView.reloadData()
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
            recentCollectionView
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

            recentCollectionView.topAnchor.constraint(
                equalTo: recentTitleLabel.bottomAnchor,
                constant: 12
            ),

            recentCollectionView.leadingAnchor.constraint(
                equalTo: recentTitleLabel.leadingAnchor
            ),

            recentCollectionView.trailingAnchor.constraint(
                equalTo: scanButton.trailingAnchor
            ),

            recentCollectionView.heightAnchor.constraint(
                equalToConstant: 180
            ),

            recentCollectionView.bottomAnchor.constraint(
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

extension HomeViewController:
UICollectionViewDataSource,
UICollectionViewDelegateFlowLayout {

    func collectionView(
        _ collectionView: UICollectionView,
        numberOfItemsInSection section: Int
    ) -> Int {

        recentCards.count
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {

        let cell =
            collectionView.dequeueReusableCell(
                withReuseIdentifier: RecentCardCell.reuseID,
                for: indexPath
            ) as! RecentCardCell
        
        if let card = CardDatabaseService.shared.findCard(named: recentCards[indexPath.item].name) {
            cell.configure(
                with: card
            )
        }

        return cell
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {

        CGSize(
            width: 128,
            height: 180
        )
    }

    func collectionView(
        _ collectionView: UICollectionView,
        didSelectItemAt indexPath: IndexPath
    ) {

        let recentCard = recentCards[indexPath.item]

        guard let card = CardDatabaseService.shared.findCard(named: recentCards[indexPath.item].name)
        else {
            return
        }

        let vc = CardDetailViewController(
            card: card
        )

        navigationController?.pushViewController(
            vc,
            animated: true
        )
    }
}
