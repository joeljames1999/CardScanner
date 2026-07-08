import UIKit

final class HomeViewController: UIViewController {

    // MARK: - Constants

    private let headerGlow = UIView()
    
    

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

    private lazy var scanCard = ActionCardView(
        title: "Scan Cards",
        subtitle: "Identify cards instantly",
        symbol: "viewfinder",
        accentColor: UIColor.accentColor
    )

    private lazy var searchCard = ActionCardView(
        title: "Search Database",
        subtitle: "Browse every MTG card",
        symbol: "magnifyingglass",
        accentColor: UIColor.accentColor
    )

    private lazy var lifeCounterCard = ActionCardView(
        title: "Life Counter",
        subtitle: "Track multiplayer games",
        symbol: "heart.text.square",
        accentColor: UIColor.systemRed
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

        headerGlow.translatesAutoresizingMaskIntoConstraints = false
        headerGlow.isUserInteractionEnabled = false

        view.insertSubview(
            headerGlow,
            at: 0
        )

        headerGlow.backgroundColor =
        UIColor.accentColor.withAlphaComponent(0.15)
        
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
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        if headerGlow.layer.sublayers?.isEmpty ?? true {

            let gradient = CAGradientLayer()

            gradient.frame = headerGlow.bounds

            gradient.colors = [
                UIColor.accentColor.withAlphaComponent(0.35).cgColor,
                UIColor.clear.cgColor
            ]

            gradient.startPoint = CGPoint(x: 0.5, y: 0)
            gradient.endPoint = CGPoint(x: 0.5, y: 1)

            headerGlow.layer.addSublayer(
                gradient
            )
        }
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
            scanCard,
            searchCard,
            lifeCounterCard,
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

            // Header

            titleLabel.topAnchor.constraint(
                equalTo: contentView.topAnchor,
                constant: 16
            ),

            titleLabel.leadingAnchor.constraint(
                equalTo: contentView.leadingAnchor,
                constant: 24
            ),

            titleLabel.trailingAnchor.constraint(
                lessThanOrEqualTo: contentView.trailingAnchor,
                constant: -24
            ),

            subtitleLabel.topAnchor.constraint(
                equalTo: titleLabel.bottomAnchor,
                constant: 8
            ),

            subtitleLabel.leadingAnchor.constraint(
                equalTo: titleLabel.leadingAnchor
            ),

            // Primary Actions

            scanCard.topAnchor.constraint(
                equalTo: subtitleLabel.bottomAnchor,
                constant: 32
            ),

            scanCard.leadingAnchor.constraint(
                equalTo: contentView.leadingAnchor,
                constant: 24
            ),

            scanCard.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor,
                constant: -24
            ),

            scanCard.heightAnchor.constraint(
                equalToConstant: 150
            ),

            searchCard.topAnchor.constraint(
                equalTo: scanCard.bottomAnchor,
                constant: 16
            ),

            searchCard.leadingAnchor.constraint(
                equalTo: scanCard.leadingAnchor
            ),

            searchCard.trailingAnchor.constraint(
                equalTo: scanCard.trailingAnchor
            ),

            searchCard.heightAnchor.constraint(
                equalToConstant: 150
            ),

            lifeCounterCard.topAnchor.constraint(
                equalTo: searchCard.bottomAnchor,
                constant: 16
            ),

            lifeCounterCard.leadingAnchor.constraint(
                equalTo: searchCard.leadingAnchor
            ),

            lifeCounterCard.trailingAnchor.constraint(
                equalTo: searchCard.trailingAnchor
            ),

            lifeCounterCard.heightAnchor.constraint(
                equalToConstant: 150
            ),
            
            recentTitleLabel.topAnchor.constraint(
                equalTo: lifeCounterCard.bottomAnchor,
                constant: 44
            ),

            recentCollectionView.topAnchor.constraint(
                equalTo: recentTitleLabel.bottomAnchor,
                constant: 16
            ),

            recentCollectionView.leadingAnchor.constraint(
                equalTo: contentView.leadingAnchor
            ),

            recentCollectionView.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor
            ),

            recentCollectionView.heightAnchor.constraint(
                equalToConstant: 200
            ),

            recentCollectionView.bottomAnchor.constraint(
                equalTo: contentView.bottomAnchor,
                constant: -40
            ),

            // Glow

            headerGlow.topAnchor.constraint(
                equalTo: view.topAnchor
            ),

            headerGlow.leadingAnchor.constraint(
                equalTo: view.leadingAnchor
            ),

            headerGlow.trailingAnchor.constraint(
                equalTo: view.trailingAnchor
            ),

            headerGlow.heightAnchor.constraint(
                equalToConstant: 260
            )
        ])

        recentCollectionView.contentInset =
            UIEdgeInsets(
                top: 0,
                left: 4,
                bottom: 0,
                right: 20
            )
        
        titleLabel.font = .systemFont(
            ofSize: 38,
            weight: .bold
        )
        
        recentTitleLabel.font = .systemFont(
            ofSize: 28,
            weight: .bold
        )
        
        scanCard.addTarget(
            self,
            action: #selector(scanTapped),
            for: .touchUpInside
        )

        searchCard.addTarget(
            self,
            action: #selector(searchTapped),
            for: .touchUpInside
        )

        lifeCounterCard.addTarget(
            self,
            action: #selector(lifeCounterTapped),
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

        config.image =
            UIImage(systemName: image)

        config.imagePadding = 12

        config.cornerStyle = .fixed

        config.baseBackgroundColor =
        UIColor.accentColor

        config.baseForegroundColor =
            .white

        let button =
            UIButton(configuration: config)

        button.layer.cornerRadius = 24

        button.layer.shadowColor =
        UIColor.accentColor.cgColor

        button.layer.shadowOpacity = 0.25

        button.layer.shadowRadius = 18

        button.layer.shadowOffset =
            CGSize(width: 0, height: 8)

        return button
    }

    // MARK: - Actions

    @objc private func scanTapped() {

        tabBarController?.selectedIndex = 2
    }

    @objc private func searchTapped() {

        tabBarController?.selectedIndex = 1
    }

    @objc private func lifeCounterTapped() {
        navigationController?.pushViewController(
            LifeCounterViewController(),
            animated: true
        )
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
        
        let recentCard = recentCards[indexPath.item]
        cell.configure(with: recentCard)

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

        guard let card = findRecentCard(named: recentCards[indexPath.item].name) else {
            return
        }

        let vc = CardDetailViewController(
            card: card,
            actionMode: .addToCollection
        )

        navigationController?.pushViewController(
            vc,
            animated: true
        )
    }
    
    private func findRecentCard(named name: String) -> MTGCard? {
        let filter = SearchFilter()

        let results = try? AppDatabase.shared.cards.search(
            query: name,
            filter: filter
        )

        return results?.first {
            $0.name.caseInsensitiveCompare(name) == .orderedSame
        } ?? results?.first
    }
}
