import UIKit

final class HomeViewController: UIViewController {

    // MARK: - UI

    private let scrollView = UIScrollView()
    private let contentView = UIView()

    private let bannerView: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 28
        view.layer.cornerCurve = .continuous
        view.layer.masksToBounds = true
        return view
    }()

    private let bannerGradientLayer = CAGradientLayer()

    private let bannerIconContainer: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.white.withAlphaComponent(0.18)
        view.layer.cornerRadius = 22
        view.layer.cornerCurve = .continuous
        return view
    }()

    private let bannerIconView: UIImageView = {
        let imageView = UIImageView(image: UIImage(systemName: "viewfinder.circle.fill"))
        imageView.tintColor = .white
        imageView.contentMode = .scaleAspectFit
        imageView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(
            pointSize: 30,
            weight: .semibold
        )
        return imageView
    }()

    private let bannerTitleLabel: UILabel = {
        let label = UILabel()
        label.text = "Scan your next card"
        label.font = .systemFont(ofSize: 30, weight: .bold)
        label.textColor = .white
        label.numberOfLines = 2
        return label
    }()

    private let bannerSubtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "Identify printings, track your collection, and keep values close."
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.textColor = UIColor.white.withAlphaComponent(0.82)
        label.numberOfLines = 0
        return label
    }()

    private lazy var bannerScanButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.title = "Scan"
        config.image = UIImage(systemName: "camera.viewfinder")
        config.imagePadding = 8
        config.cornerStyle = .capsule
        config.baseBackgroundColor = .white
        config.baseForegroundColor = .brandBlue
        config.contentInsets = NSDirectionalEdgeInsets(
            top: 10,
            leading: 18,
            bottom: 10,
            trailing: 18
        )

        let button = UIButton(configuration: config)
        button.addTarget(
            self,
            action: #selector(scanTapped),
            for: .touchUpInside
        )
        return button
    }()

    private let collectionCountStat = HomeStatView(
        title: "Cards",
        symbol: "rectangle.stack"
    )

    private let collectionValueStat = HomeStatView(
        title: "Value",
        symbol: "chart.line.uptrend.xyaxis"
    )

    private lazy var searchCard = ActionCardView(
        title: "Search Database",
        subtitle: "Browse every MTG card",
        symbol: "magnifyingglass",
        accentColor: UIColor.brandBlue
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
        label.font = .systemFont(ofSize: 28, weight: .bold)
        return label
    }()

    private lazy var randomCard = ActionCardView(
        title: "Random Card",
        subtitle: "Discover any Magic card",
        symbol: "shuffle",
        accentColor: UIColor.systemPurple
    )

    private lazy var randomCommanderCard = ActionCardView(
        title: "Random Commander",
        subtitle: "Find a legal commander option",
        symbol: "crown.fill",
        accentColor: UIColor.systemOrange
    )

    private let scryfallService = ScryfallService()
    private var randomCardTask: Task<Void, Never>?
    private var recentCards: [RecentCard] = []

    private enum RandomAction {
        case card
        case commander

        var query: String {
            switch self {
            case .card:
                return "-is:digital"
            case .commander:
                return "is:commander -is:digital"
            }
        }
    }

    private lazy var recentCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 12

        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.translatesAutoresizingMaskIntoConstraints = false
        cv.backgroundColor = .clear
        cv.showsHorizontalScrollIndicator = false
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
        configureBannerGradient()
        observePriceChanges()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        recentCards = RecentlyViewedStore.shared.cards
        recentCollectionView.reloadData()
        updateBannerStats()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        bannerGradientLayer.frame = bannerView.bounds
    }

    deinit {
        randomCardTask?.cancel()
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Layout

    private func setupLayout() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        bannerView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(bannerView)

        setupBannerContent()

        [
            searchCard,
            randomCard,
            randomCommanderCard,
            lifeCounterCard,
            recentTitleLabel,
            recentCollectionView
        ].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),

            bannerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            bannerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            bannerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            searchCard.topAnchor.constraint(equalTo: bannerView.bottomAnchor, constant: 24),
            searchCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            searchCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            searchCard.heightAnchor.constraint(equalToConstant: 112),

            randomCard.topAnchor.constraint(equalTo: searchCard.bottomAnchor, constant: 16),
            randomCard.leadingAnchor.constraint(equalTo: searchCard.leadingAnchor),
            randomCard.trailingAnchor.constraint(equalTo: searchCard.trailingAnchor),
            randomCard.heightAnchor.constraint(equalToConstant: 112),

            randomCommanderCard.topAnchor.constraint(equalTo: randomCard.bottomAnchor, constant: 16),
            randomCommanderCard.leadingAnchor.constraint(equalTo: searchCard.leadingAnchor),
            randomCommanderCard.trailingAnchor.constraint(equalTo: searchCard.trailingAnchor),
            randomCommanderCard.heightAnchor.constraint(equalToConstant: 112),

            lifeCounterCard.topAnchor.constraint(equalTo: randomCommanderCard.bottomAnchor, constant: 16),
            lifeCounterCard.leadingAnchor.constraint(equalTo: searchCard.leadingAnchor),
            lifeCounterCard.trailingAnchor.constraint(equalTo: searchCard.trailingAnchor),
            lifeCounterCard.heightAnchor.constraint(equalToConstant: 112),

            recentTitleLabel.topAnchor.constraint(equalTo: lifeCounterCard.bottomAnchor, constant: 44),
            recentTitleLabel.leadingAnchor.constraint(equalTo: searchCard.leadingAnchor),
            recentTitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: searchCard.trailingAnchor),

            recentCollectionView.topAnchor.constraint(equalTo: recentTitleLabel.bottomAnchor, constant: 16),
            recentCollectionView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            recentCollectionView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            recentCollectionView.heightAnchor.constraint(equalToConstant: 200),
            recentCollectionView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -40)
            
        ])

        recentCollectionView.contentInset = UIEdgeInsets(
            top: 0,
            left: 20,
            bottom: 0,
            right: 20
        )

        searchCard.addTarget(self, action: #selector(searchTapped), for: .touchUpInside)
        randomCard.addTarget(self, action: #selector(randomCardTapped), for: .touchUpInside)
        randomCommanderCard.addTarget(self, action: #selector(randomCommanderTapped), for: .touchUpInside)
        lifeCounterCard.addTarget(self, action: #selector(lifeCounterTapped), for: .touchUpInside)
        collectionCountStat.addTarget(self, action: #selector(collectionTapped), for: .touchUpInside)
        collectionValueStat.addTarget(self, action: #selector(collectionTapped), for: .touchUpInside)
    }

    private func setupBannerContent() {
        let textStack = UIStackView(arrangedSubviews: [
            bannerTitleLabel,
            bannerSubtitleLabel
        ])
        textStack.axis = .vertical
        textStack.spacing = 8

        let topRow = UIStackView(arrangedSubviews: [
            bannerIconContainer,
            UIView(),
            bannerScanButton
        ])
        topRow.axis = .horizontal
        topRow.alignment = .center
        topRow.spacing = 12

        let statStack = UIStackView(arrangedSubviews: [
            collectionCountStat,
            collectionValueStat
        ])
        statStack.axis = .horizontal
        statStack.spacing = 10
        statStack.distribution = .fillEqually

        let contentStack = UIStackView(arrangedSubviews: [
            topRow,
            textStack,
            statStack
        ])
        contentStack.axis = .vertical
        contentStack.spacing = 20
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        bannerIconContainer.translatesAutoresizingMaskIntoConstraints = false
        bannerIconView.translatesAutoresizingMaskIntoConstraints = false
        bannerIconContainer.addSubview(bannerIconView)
        bannerView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            bannerIconContainer.widthAnchor.constraint(equalToConstant: 52),
            bannerIconContainer.heightAnchor.constraint(equalToConstant: 52),

            bannerIconView.centerXAnchor.constraint(equalTo: bannerIconContainer.centerXAnchor),
            bannerIconView.centerYAnchor.constraint(equalTo: bannerIconContainer.centerYAnchor),
            bannerIconView.widthAnchor.constraint(equalToConstant: 34),
            bannerIconView.heightAnchor.constraint(equalToConstant: 34),

            contentStack.topAnchor.constraint(equalTo: bannerView.topAnchor, constant: 18),
            contentStack.leadingAnchor.constraint(equalTo: bannerView.leadingAnchor, constant: 18),
            contentStack.trailingAnchor.constraint(equalTo: bannerView.trailingAnchor, constant: -18),
            contentStack.bottomAnchor.constraint(equalTo: bannerView.bottomAnchor, constant: -18)
        ])
    }

    private func configureBannerGradient() {
        bannerGradientLayer.colors = [
            UIColor.brandBlue.cgColor,
            UIColor.accentColor.cgColor,
            UIColor.systemIndigo.cgColor
        ]
        bannerGradientLayer.startPoint = CGPoint(x: 0, y: 0)
        bannerGradientLayer.endPoint = CGPoint(x: 1, y: 1)
        bannerView.layer.insertSublayer(bannerGradientLayer, at: 0)
    }

    private func observePriceChanges() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateBannerStats),
            name: CollectionStore.didChangeNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateBannerStats),
            name: CurrencySettings.didChangeNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateBannerStats),
            name: ExchangeRateService.didRefreshNotification,
            object: nil
        )
    }

    @objc private func updateBannerStats() {
        collectionCountStat.setValue("\(CollectionStore.shared.totalCards)")
        collectionValueStat.setValue(
            PriceFormatter.string(usd: CollectionStore.shared.estimatedValue)
        )
    }

    // MARK: - Actions

    @objc private func scanTapped() {
        tabBarController?.selectedIndex = 2
    }

    @objc private func searchTapped() {
        tabBarController?.selectedIndex = 1
    }

    @objc private func collectionTapped() {
        tabBarController?.selectedIndex = 3
    }

    @objc private func randomCardTapped() {
        fetchRandomCard(.card)
    }

    @objc private func randomCommanderTapped() {
        fetchRandomCard(.commander)
    }

    private func fetchRandomCard(_ action: RandomAction) {
        guard randomCardTask == nil else {
            return
        }

        setRandomButtonsLoading(action, isLoading: true)

        randomCardTask = Task { [weak self] in
            guard let self else { return }

            do {
                let card = try await scryfallService.fetchRandomCard(query: action.query)

                guard !Task.isCancelled else {
                    return
                }

                await MainActor.run {
                    self.showRandomCard(card)
                    self.setRandomButtonsLoading(action, isLoading: false)
                    self.randomCardTask = nil
                }
            } catch {
                guard !Task.isCancelled else {
                    return
                }

                await MainActor.run {
                    self.showRandomCardError(error)
                    self.setRandomButtonsLoading(action, isLoading: false)
                    self.randomCardTask = nil
                }
            }
        }
    }

    private func showRandomCard(_ card: MTGCard) {
        RecentlyViewedStore.shared.add(card: card)

        let viewController = CardDetailViewController(
            card: card,
            actionMode: .addToCollection
        )

        navigationController?.pushViewController(
            viewController,
            animated: true
        )
    }

    private func showRandomCardError(_ error: Error) {
        let alert = UIAlertController(
            title: "Random card unavailable",
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func setRandomButtonsLoading(_ action: RandomAction, isLoading: Bool) {
        randomCard.isEnabled = !isLoading
        randomCommanderCard.isEnabled = !isLoading

        randomCard.alpha = action == .card && isLoading ? 0.65 : 1
        randomCommanderCard.alpha = action == .commander && isLoading ? 0.65 : 1
    }

    @objc private func lifeCounterTapped() {
        navigationController?.pushViewController(
            LifeCounterViewController(),
            animated: true
        )
    }
}

extension HomeViewController: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

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

        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: RecentCardCell.reuseID,
            for: indexPath
        ) as! RecentCardCell

        cell.configure(with: recentCards[indexPath.item])
        return cell
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        CGSize(width: 128, height: 180)
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

        navigationController?.pushViewController(vc, animated: true)
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

private final class HomeStatView: UIControl {

    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let valueLabel = UILabel()

    init(title: String, symbol: String) {
        super.init(frame: .zero)

        backgroundColor = UIColor.white.withAlphaComponent(0.16)
        layer.cornerRadius = 16
        layer.cornerCurve = .continuous
        isAccessibilityElement = true
        accessibilityTraits = .button
        accessibilityLabel = title

        iconView.image = UIImage(systemName: symbol)
        iconView.tintColor = .white
        iconView.contentMode = .scaleAspectFit
        iconView.isUserInteractionEnabled = false
        iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(
            pointSize: 15,
            weight: .semibold
        )

        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 12, weight: .medium)
        titleLabel.textColor = UIColor.white.withAlphaComponent(0.76)
        titleLabel.isUserInteractionEnabled = false

        valueLabel.text = "--"
        valueLabel.font = .systemFont(ofSize: 18, weight: .bold)
        valueLabel.textColor = .white
        valueLabel.adjustsFontSizeToFitWidth = true
        valueLabel.minimumScaleFactor = 0.75
        valueLabel.isUserInteractionEnabled = false

        let labelStack = UIStackView(arrangedSubviews: [titleLabel, valueLabel])
        labelStack.axis = .vertical
        labelStack.spacing = 2
        labelStack.isUserInteractionEnabled = false

        let stack = UIStackView(arrangedSubviews: [iconView, labelStack])
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.isUserInteractionEnabled = false

        addSubview(stack)

        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 22),
            iconView.heightAnchor.constraint(equalToConstant: 22),

            stack.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.15) {
                self.alpha = self.isHighlighted ? 0.72 : 1
            }
        }
    }

    func setValue(_ value: String) {
        valueLabel.text = value
        accessibilityValue = value
    }
}
