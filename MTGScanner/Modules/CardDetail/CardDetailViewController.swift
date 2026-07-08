import UIKit

final class CardDetailViewController: UIViewController {

    enum ActionMode {
        case addToCollection
        case addToSession
    }

    // MARK: - Properties

    private let card: MTGCard
    private let actionMode: ActionMode
    private var currentFaceIndex = 0
    private var imageLoadTask: Task<Void, Never>?
    private weak var addedToast: UIView?
    var onDismiss: (() -> Void)?

    // MARK: - UI

    private let scrollView = UIScrollView()

    private let contentStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let cardImageContainer = UIView()

    private let cardImageView: UIImageView = {
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.contentMode = .scaleAspectFit
        iv.backgroundColor = .secondarySystemBackground
        iv.clipsToBounds = true
        return iv
    }()

    private lazy var flipFaceButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.image = UIImage(systemName: "arrow.triangle.2.circlepath")
        config.baseBackgroundColor = UIColor.black.withAlphaComponent(0.65)
        config.baseForegroundColor = .white
        config.cornerStyle = .capsule
        config.contentInsets = NSDirectionalEdgeInsets(
            top: 8,
            leading: 8,
            bottom: 8,
            trailing: 8
        )

        let button = UIButton(configuration: config)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(
            self,
            action: #selector(flipCardFace),
            for: .touchUpInside
        )
        button.accessibilityLabel = "Flip card face"
        button.isHidden = true
        return button
    }()

    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(
            ofSize: 28,
            weight: .bold
        )
        label.numberOfLines = 0
        return label
    }()

    private let manaCostLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(
            ofSize: 18,
            weight: .medium
        )
        label.textColor = .secondaryLabel
        return label
    }()

    private let typeLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(
            ofSize: 16,
            weight: .medium
        )
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        return label
    }()

    private let infoLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.font = .systemFont(ofSize: 15)
        return label
    }()

    private let oracleLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.font = .systemFont(ofSize: 16)
        return label
    }()

    private let rulingsLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.font = .systemFont(ofSize: 15)
        label.textColor = .secondaryLabel
        return label
    }()

    private let sessionStatusLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 13)
        label.textAlignment = .center
        label.textColor = .secondaryLabel
        return label
    }()

    private lazy var scryfallButton: UIButton = {

        var config = UIButton.Configuration.plain()

        config.title = "Open on Scryfall"
        config.image = UIImage(systemName: "safari")
        config.imagePadding = 8

        let button = UIButton(configuration: config)

        button.addTarget(
            self,
            action: #selector(openScryfall),
            for: .touchUpInside
        )

        return button
    }()

    private lazy var addToSessionButton: UIButton = {

        var config = UIButton.Configuration.filled()

        config.cornerStyle = .capsule
        config.image = UIImage(systemName: "plus.circle.fill")
        config.imagePadding = 8
        config.baseBackgroundColor = .brandBlue
        let button = UIButton(configuration: config)

        button.translatesAutoresizingMaskIntoConstraints = false

        button.addTarget(
            self,
            action: #selector(handlePrimaryAction),
            for: .touchUpInside
        )

        return button
    }()

    private var printings: [MTGCard] = []
    private var filteredPrintings: [MTGCard] = []

    private lazy var printingsCollectionView: UICollectionView = {

        let layout = UICollectionViewFlowLayout()

        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 12

        layout.itemSize = CGSize(
            width: 120,
            height: 170
        )

        let cv = UICollectionView(
            frame: .zero,
            collectionViewLayout: layout
        )

        cv.translatesAutoresizingMaskIntoConstraints = false
        cv.backgroundColor = .clear
        cv.showsHorizontalScrollIndicator = false

        cv.register(
            CardDetailPrintingCell.self,
            forCellWithReuseIdentifier: CardDetailPrintingCell.reuseIdentifier
        )

        cv.delegate = self
        cv.dataSource = self

        return cv
    }()
    
    private lazy var printingsSearchField: UISearchBar = {

        let searchBar = UISearchBar()

        searchBar.translatesAutoresizingMaskIntoConstraints = false
        searchBar.placeholder = "Filter by set name, code or collector number"
        searchBar.searchBarStyle = .minimal
        searchBar.delegate = self

        return searchBar
    }()
    
    // MARK: - Init

    init(
        card: MTGCard,
        actionMode: ActionMode = .addToSession
    ) {
        self.card = card
        self.actionMode = actionMode
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        title = card.name
        view.backgroundColor = .systemBackground

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            systemItem: .close,
            primaryAction: UIAction { [weak self] _ in
                self?.dismiss(animated: true)
            }
        )
        
        RecentlyViewedStore.shared.add(card: card)
        
        setupLayout()
        setupKeyboardDismissal()
        populateData()
        loadPrintings()
        updateActionButton()

        loadRulings()
    }

    // MARK: - Layout

    private func setupLayout() {

        scrollView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)

        view.addSubview(sessionStatusLabel)
        view.addSubview(addToSessionButton)
        
        let paddedContent = UIView()
        paddedContent.translatesAutoresizingMaskIntoConstraints = false

        cardImageContainer.translatesAutoresizingMaskIntoConstraints = false
        cardImageContainer.addSubview(cardImageView)
        cardImageContainer.addSubview(flipFaceButton)

        // Add arranged subviews BEFORE activating constraints
        contentStack.addArrangedSubview(cardImageContainer)
        contentStack.addArrangedSubview(paddedContent)

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
                equalTo: addToSessionButton.topAnchor,
                constant: -20
            ),

            contentStack.topAnchor.constraint(
                equalTo: scrollView.contentLayoutGuide.topAnchor
            ),

            contentStack.leadingAnchor.constraint(
                equalTo: scrollView.contentLayoutGuide.leadingAnchor
            ),

            contentStack.trailingAnchor.constraint(
                equalTo: scrollView.contentLayoutGuide.trailingAnchor
            ),

            contentStack.bottomAnchor.constraint(
                equalTo: scrollView.contentLayoutGuide.bottomAnchor
            ),

            contentStack.widthAnchor.constraint(
                equalTo: scrollView.frameLayoutGuide.widthAnchor
            ),

            cardImageView.topAnchor.constraint(equalTo: cardImageContainer.topAnchor),
            cardImageView.leadingAnchor.constraint(equalTo: cardImageContainer.leadingAnchor),
            cardImageView.trailingAnchor.constraint(equalTo: cardImageContainer.trailingAnchor),
            cardImageView.bottomAnchor.constraint(equalTo: cardImageContainer.bottomAnchor),

            flipFaceButton.trailingAnchor.constraint(
                equalTo: cardImageContainer.trailingAnchor,
                constant: -16
            ),
            flipFaceButton.bottomAnchor.constraint(
                equalTo: cardImageContainer.bottomAnchor,
                constant: -16
            ),
            flipFaceButton.widthAnchor.constraint(equalToConstant: 44),
            flipFaceButton.heightAnchor.constraint(equalToConstant: 44),

            // MTG card aspect ratio (63 × 88 mm) 66% aspect ratio
            cardImageContainer.heightAnchor.constraint(
                equalTo: cardImageContainer.widthAnchor,
                multiplier: 58.08 / 41.58
            ),

            sessionStatusLabel.bottomAnchor.constraint(
                equalTo: addToSessionButton.topAnchor,
                constant: -8
            ),

            sessionStatusLabel.centerXAnchor.constraint(
                equalTo: view.centerXAnchor
            ),

            addToSessionButton.centerXAnchor.constraint(
                equalTo: view.centerXAnchor
            ),

            addToSessionButton.bottomAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.bottomAnchor,
                constant: -16
            ),

            addToSessionButton.widthAnchor.constraint(
                equalToConstant: 220
            ),

            addToSessionButton.heightAnchor.constraint(
                equalToConstant: 50
            )
        ])

        let textStack = UIStackView(arrangedSubviews: [

            nameLabel,
            manaCostLabel,
            typeLabel,

            makeDivider(),

            makeSectionTitle("Card Information"),
            infoLabel,

            makeDivider(),

            makeSectionTitle("All Printings"),
            printingsSearchField,
            printingsCollectionView,

            makeDivider(),

            makeSectionTitle("Oracle Text"),
            oracleLabel,

            makeDivider(),

            makeSectionTitle("Rulings"),
            rulingsLabel,

            makeDivider(),

            scryfallButton
        ])

        textStack.axis = .vertical
        textStack.spacing = 12
        textStack.translatesAutoresizingMaskIntoConstraints = false
        printingsCollectionView.heightAnchor.constraint(
            equalToConstant: 170
        ).isActive = true
        printingsSearchField.heightAnchor.constraint(
            equalToConstant: 44
        ).isActive = true
        
        paddedContent.addSubview(textStack)

        NSLayoutConstraint.activate([
            textStack.topAnchor.constraint(equalTo: paddedContent.topAnchor, constant: 20),
            textStack.leadingAnchor.constraint(equalTo: paddedContent.leadingAnchor, constant: 20),
            textStack.trailingAnchor.constraint(equalTo: paddedContent.trailingAnchor, constant: -20),
            textStack.bottomAnchor.constraint(equalTo: paddedContent.bottomAnchor)
        ])
    }

    private func setupKeyboardDismissal() {
        let tapGesture = UITapGestureRecognizer(
            target: self,
            action: #selector(dismissKeyboard)
        )
        tapGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(tapGesture)
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    // MARK: - Data

    private func convertManaCost(_ manaCost: String?) -> String? {
        var newManaCost = manaCost?.replacingOccurrences(of: "{B}", with: "B ")
        newManaCost = newManaCost?.replacingOccurrences(of: "{G}", with: "G ")
        newManaCost = newManaCost?.replacingOccurrences(of: "{W}", with: "W ")
        newManaCost = newManaCost?.replacingOccurrences(of: "{U}", with: "U ")
        newManaCost = newManaCost?.replacingOccurrences(of: "{R}", with: "R ")
        return newManaCost
    }
    
    private func populateData() {
        updateDisplayedFace(animated: false)

        infoLabel.text =
        """
        Set: \(card.setName)

        Collector Number: \(card.collectorNumber)

        Rarity: \(card.rarity.capitalized)

        Price: \(card.prices?.usd.map { "$\($0)" } ?? "Unavailable")
        """

        rulingsLabel.text = "Loading rulings..."
    }

    private func updateDisplayedFace(animated: Bool) {
        let face = card.face(at: currentFaceIndex)

        nameLabel.text = face?.name ?? card.name
        manaCostLabel.text = convertManaCost(face?.manaCost ?? card.manaCost) ?? face?.manaCost ?? card.manaCost
        typeLabel.text = face?.typeLine ?? card.typeLine

        oracleLabel.text =
        face?.oracleText?.isEmpty == false
        ? face?.oracleText
        : card.oracleText?.isEmpty == false
        ? card.oracleText
        : "No Oracle text available."

        flipFaceButton.isHidden = !card.hasMultipleFaces
        loadImage(
            from: face?.imageUris?.normal ?? card.displayImage,
            animated: animated
        )
    }

    // MARK: - Image

    private func loadImage(
        from url: URL?,
        animated: Bool = false
    ) {

        imageLoadTask?.cancel()
        cardImageView.image = nil

        guard let url else {
            return
        }

        imageLoadTask = Task { [weak self] in

            guard
                let (data, _) = try? await URLSession.shared.data(from: url),
                !Task.isCancelled,
                let image = UIImage(data: data)
            else {
                return
            }

            await MainActor.run {
                guard !Task.isCancelled else {
                    return
                }

                let updateImage: () -> Void = {
                    self?.cardImageView.image = image
                }

                if animated, let imageView = self?.cardImageView {
                    UIView.transition(
                        with: imageView,
                        duration: 0.25,
                        options: .transitionFlipFromRight,
                        animations: updateImage
                    )
                } else {
                    updateImage()
                }

                self?.imageLoadTask = nil
            }
        }
    }
    
    private func loadPrintings() {

        Task.detached { [weak self] in

            guard let self else { return }
            
            let printings = (try? AppDatabase.shared.cards.allPrintings(
                named: card.name
            )) ?? []
            
            await MainActor.run {

                self.printings = printings
                self.filteredPrintings = printings

                self.printingsCollectionView.reloadData()
            }
        }
    }
    
    private func filterPrintings(
        searchText: String
    ) {

        let text = searchText
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            .lowercased()

        guard !text.isEmpty else {

            filteredPrintings = printings

            printingsCollectionView.reloadData()
            return
        }

        filteredPrintings = printings.filter {

            $0.set.lowercased().contains(text)
            ||
            $0.setName.lowercased().contains(text)
            ||
            $0.collectorNumber.lowercased().contains(text)
        }

        printingsCollectionView.reloadData()
    }
    
    // MARK: - Rulings

    private func loadRulings() {

        rulingsLabel.text =
        "Rulings support can be added via the Scryfall rulings endpoint."
    }

    // MARK: - Primary Action

    private func updateActionButton() {
        var config = addToSessionButton.configuration

        switch actionMode {
        case .addToCollection:
            let count = CollectionStore.shared.entries
                .filter { $0.cardID == card.id }
                .reduce(0) { $0 + $1.count }

            config?.title = count > 0 ? "Add Another" : "Add to collection"
            config?.image = UIImage(systemName: "rectangle.stack.badge.plus")
            sessionStatusLabel.text = count > 0 ? "×\(count) currently in collection" : nil

        case .addToSession:
            let count = SessionStore.shared.entries
                .first(where: { $0.card.id == card.id })?
                .count ?? 0

            config?.title = count > 0 ? "Add Another" : "Add to session"
            config?.image = UIImage(systemName: "plus.circle.fill")
            sessionStatusLabel.text = count > 0 ? "×\(count) currently in session" : nil
        }

        addToSessionButton.configuration = config
    }

    @objc
    private func handlePrimaryAction() {
        let subtitle: String

        switch actionMode {
        case .addToCollection:
            CollectionStore.shared.addSessionEntries([
                SessionEntry(card: card)
            ])
            subtitle = "Added to collection"

        case .addToSession:
            SessionStore.shared.addOrIncrement(card: card)
            subtitle = "Added to session"
        }

        UINotificationFeedbackGenerator()
            .notificationOccurred(.success)

        updateActionButton()
        showAddedToast(subtitle: subtitle)
    }

    private func showAddedToast(subtitle: String) {
        addedToast?.removeFromSuperview()

        let toast = UIView()
        toast.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.94)
        toast.layer.cornerRadius = 14
        toast.clipsToBounds = true
        toast.translatesAutoresizingMaskIntoConstraints = false
        toast.alpha = 0

        let icon = UIImageView(image: UIImage(systemName: "checkmark.circle.fill"))
        icon.tintColor = .white
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false

        let nameLabel = UILabel()
        nameLabel.text = card.name
        nameLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        nameLabel.textColor = .white
        nameLabel.numberOfLines = 1
        nameLabel.lineBreakMode = .byTruncatingTail

        let subLabel = UILabel()
        subLabel.text = subtitle
        subLabel.font = .systemFont(ofSize: 12)
        subLabel.textColor = UIColor.white.withAlphaComponent(0.85)

        let textStack = UIStackView(arrangedSubviews: [nameLabel, subLabel])
        textStack.axis = .vertical
        textStack.spacing = 2
        textStack.translatesAutoresizingMaskIntoConstraints = false

        let hStack = UIStackView(arrangedSubviews: [icon, textStack])
        hStack.axis = .horizontal
        hStack.spacing = 10
        hStack.alignment = .center
        hStack.translatesAutoresizingMaskIntoConstraints = false

        toast.addSubview(hStack)
        view.addSubview(toast)
        addedToast = toast

        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: 24),
            icon.heightAnchor.constraint(equalToConstant: 24),

            hStack.topAnchor.constraint(equalTo: toast.topAnchor, constant: 12),
            hStack.bottomAnchor.constraint(equalTo: toast.bottomAnchor, constant: -12),
            hStack.leadingAnchor.constraint(equalTo: toast.leadingAnchor, constant: 16),
            hStack.trailingAnchor.constraint(equalTo: toast.trailingAnchor, constant: -16),

            toast.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            toast.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 16),
            toast.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -16),
            toast.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            toast.widthAnchor.constraint(lessThanOrEqualToConstant: 360)
        ])

        UIView.animate(withDuration: 0.25) {
            toast.alpha = 1
        }

        UIView.animate(
            withDuration: 0.25,
            delay: 1.6,
            options: .curveEaseIn
        ) {
            toast.alpha = 0
        } completion: { [weak self, weak toast] _ in
            guard self?.addedToast === toast else {
                return
            }

            toast?.removeFromSuperview()
            self?.addedToast = nil
        }
    }

    // MARK: - Actions

    @objc
    private func flipCardFace() {
        guard card.hasMultipleFaces else {
            return
        }

        let faceCount = card.cardFaces?.count ?? 1
        currentFaceIndex = (currentFaceIndex + 1) % faceCount
        updateDisplayedFace(animated: true)
    }

    @objc
    private func openScryfall() {

        guard let url = card.scryfallUri else {
            return
        }

        UIApplication.shared.open(url)
    }

    // MARK: - Helpers

    private func makeSectionTitle(_ title: String) -> UILabel {

        let label = UILabel()

        label.text = title

        label.font = .systemFont(
            ofSize: 20,
            weight: .bold
        )

        return label
    }

    private func makeDivider() -> UIView {

        let divider = UIView()

        divider.backgroundColor = .separator

        divider.heightAnchor.constraint(
            equalToConstant: 0.5
        ).isActive = true

        return divider
    }
}
extension CardDetailViewController:
UICollectionViewDataSource,
UICollectionViewDelegate {

    func collectionView(
        _ collectionView: UICollectionView,
        numberOfItemsInSection section: Int
    ) -> Int {

        filteredPrintings.count
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {

        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: CardDetailPrintingCell.reuseIdentifier,
            for: indexPath
        ) as! CardDetailPrintingCell

        cell.configure(
            with: filteredPrintings[indexPath.item]
        )

        return cell
    }
    
    func collectionView(
        _ collectionView: UICollectionView,
        didSelectItemAt indexPath: IndexPath
    ) {

        let selectedCard = printings[indexPath.item]

        let vc = CardDetailViewController(
            card: selectedCard,
            actionMode: actionMode
        )

        navigationController?.pushViewController(
            vc,
            animated: true
        )
    }
}

extension CardDetailViewController: UISearchBarDelegate {

    func searchBar(
        _ searchBar: UISearchBar,
        textDidChange searchText: String
    ) {

        filterPrintings(
            searchText: searchText
        )
    }
}
