import UIKit

final class CardDetailViewController: UIViewController {

    enum ActionMode {
        case addToCollection
        case addToSession
    }

    // MARK: - Properties

    private let card: MTGCard
    private let actionMode: ActionMode
    private let scryfallService = ScryfallService()
    private var displayedCard: MTGCard
    private var selectedLanguage = CardLanguageSettings.shared.preferredLanguage
    private var availableLanguages: [CardLanguage] = [.english]
    private var currentFaceIndex = 0
    private var imageLoadTask: Task<Void, Never>?
    private var localizedCardTask: Task<Void, Never>?
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

    private let manaCostStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .trailing
        stack.spacing = 4
        return stack
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

    private let setValueLabel = UILabel()
    private let collectorValueLabel = UILabel()
    private let rarityValueLabel = UILabel()
    private let priceValueLabel = UILabel()
    private let releasedValueLabel = UILabel()
    private let artistLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.font = .systemFont(ofSize: 16)
        return label
    }()

    private let oracleLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.font = .systemFont(ofSize: 16)
        return label
    }()

    private let flavorLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.font = .italicSystemFont(ofSize: 16)
        label.textColor = .secondaryLabel
        return label
    }()

    private let rulingsLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.font = .systemFont(ofSize: 15)
        label.textColor = .secondaryLabel
        return label
    }()

    private let printingsSectionView = UIView()
    private let oracleSectionView = UIView()
    private let flavorSectionView = UIView()
    private let rulingsSectionView = UIView()

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
        config.baseForegroundColor = .brandBlue

        let button = UIButton(configuration: config)
        button.tintColor = .brandBlue

        button.addTarget(
            self,
            action: #selector(openScryfall),
            for: .touchUpInside
        )

        return button
    }()

    private lazy var languageButton: UIButton = {
        var config = UIButton.Configuration.tinted()
        config.image = UIImage(systemName: "globe")
        config.imagePadding = 8
        config.cornerStyle = .capsule
        config.baseForegroundColor = .brandBlue
        config.baseBackgroundColor = UIColor.brandBlue.withAlphaComponent(0.16)
        config.contentInsets = NSDirectionalEdgeInsets(
            top: 12,
            leading: 18,
            bottom: 12,
            trailing: 18
        )

        let button = UIButton(configuration: config)
        button.tintColor = .brandBlue
        button.addTarget(
            self,
            action: #selector(showLanguagePicker),
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
        searchBar.tintColor = .brandBlue
        searchBar.searchTextField.tintColor = .brandBlue
        searchBar.searchTextField.leftView?.tintColor = .brandBlue
        searchBar.delegate = self

        return searchBar
    }()
    
    // MARK: - Init

    init(
        card: MTGCard,
        actionMode: ActionMode = .addToSession
    ) {
        self.card = card
        self.displayedCard = card
        self.actionMode = actionMode
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    deinit {
        localizedCardTask?.cancel()
        imageLoadTask?.cancel()
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        title = nil
        navigationItem.title = nil
        navigationItem.largeTitleDisplayMode = .never
        view.backgroundColor = .systemBackground
        view.tintColor = .brandBlue

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            systemItem: .close,
            primaryAction: UIAction { [weak self] _ in
                self?.dismiss(animated: true)
            }
        )
        navigationItem.rightBarButtonItem?.tintColor = .brandBlue
        navigationController?.navigationBar.tintColor = .brandBlue
        
        RecentlyViewedStore.shared.add(card: card)
        
        loadAvailableLanguages()
        setupLayout()
        setupKeyboardDismissal()
        populateData()
        loadPrintings()
        updateActionButton()

        loadPreferredLanguageIfNeeded()
    }

    // MARK: - Layout

    private func setupLayout() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)
        view.addSubview(sessionStatusLabel)
        view.addSubview(addToSessionButton)

        cardImageContainer.translatesAutoresizingMaskIntoConstraints = false
        cardImageContainer.layer.cornerRadius = 10
        cardImageContainer.layer.shadowColor = UIColor.black.cgColor
        cardImageContainer.layer.shadowOpacity = 0.16
        cardImageContainer.layer.shadowRadius = 10
        cardImageContainer.layer.shadowOffset = CGSize(width: 0, height: 5)
        cardImageContainer.addSubview(cardImageView)
        cardImageContainer.addSubview(flipFaceButton)

        cardImageView.layer.cornerRadius = 10
        printingsSearchField.isHidden = true

        nameLabel.font = .systemFont(ofSize: 28, weight: .bold)
        nameLabel.textAlignment = .center
        nameLabel.adjustsFontSizeToFitWidth = true
        nameLabel.minimumScaleFactor = 0.82

        let detailsStack = makeHeaderDetailsStack()
        let typeManaRow = makeTypeManaRow()

        let headerBodyStack = UIStackView(arrangedSubviews: [
            cardImageContainer,
            detailsStack
        ])
        headerBodyStack.axis = .horizontal
        headerBodyStack.alignment = .center
        headerBodyStack.spacing = 16
        headerBodyStack.translatesAutoresizingMaskIntoConstraints = false

        let headerStack = UIStackView(arrangedSubviews: [
            nameLabel,
            typeManaRow,
            headerBodyStack
        ])
        headerStack.axis = .vertical
        headerStack.alignment = .fill
        headerStack.spacing = 14
        headerStack.translatesAutoresizingMaskIntoConstraints = false

        let printingsContent = UIStackView(arrangedSubviews: [
            makeSectionHeader(
                title: "Printings",
                trailingTitle: "All printings"
            ),
            printingsSearchField,
            printingsCollectionView
        ])
        printingsContent.axis = .vertical
        printingsContent.spacing = 10

        let oracleContent = makeTextCard(
            iconName: "doc.text",
            label: oracleLabel
        )

        let flavorContent = makeTextCard(
            iconName: "quote.bubble",
            label: flavorLabel
        )

        let scryfallContent = makeScryfallButtonCard()

        configureSection(
            printingsSectionView,
            title: nil,
            content: printingsContent
        )
        configureSection(
            oracleSectionView,
            title: "Oracle Text",
            content: oracleContent
        )
        configureSection(
            flavorSectionView,
            title: "Flavour Text",
            content: flavorContent
        )
        configureSection(
            rulingsSectionView,
            title: nil,
            content: scryfallContent
        )

        contentStack.addArrangedSubview(headerStack)
        contentStack.addArrangedSubview(printingsSectionView)
        contentStack.addArrangedSubview(oracleSectionView)
        contentStack.addArrangedSubview(flavorSectionView)
        contentStack.addArrangedSubview(rulingsSectionView)

        let imageMatchesDetailsHeightConstraint = cardImageContainer.heightAnchor.constraint(
            equalTo: detailsStack.heightAnchor
        )
        imageMatchesDetailsHeightConstraint.priority = .defaultHigh
        let fallbackImageWidthConstraint = cardImageContainer.widthAnchor.constraint(
            equalTo: contentStack.widthAnchor,
            multiplier: 0.38
        )
        fallbackImageWidthConstraint.priority = .defaultLow

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
                equalTo: scrollView.contentLayoutGuide.topAnchor,
                constant: 8
            ),
            contentStack.leadingAnchor.constraint(
                equalTo: scrollView.contentLayoutGuide.leadingAnchor,
                constant: 20
            ),
            contentStack.trailingAnchor.constraint(
                equalTo: scrollView.contentLayoutGuide.trailingAnchor,
                constant: -20
            ),
            contentStack.bottomAnchor.constraint(
                equalTo: scrollView.contentLayoutGuide.bottomAnchor,
                constant: -20
            ),
            contentStack.widthAnchor.constraint(
                equalTo: scrollView.frameLayoutGuide.widthAnchor,
                constant: -40
            ),
            cardImageContainer.widthAnchor.constraint(
                equalTo: cardImageContainer.heightAnchor,
                multiplier: 63.0 / 88.0
            ),
            imageMatchesDetailsHeightConstraint,
            cardImageContainer.widthAnchor.constraint(
                lessThanOrEqualTo: contentStack.widthAnchor,
                multiplier: 0.42
            ),
            fallbackImageWidthConstraint,
            cardImageView.topAnchor.constraint(equalTo: cardImageContainer.topAnchor),
            cardImageView.leadingAnchor.constraint(equalTo: cardImageContainer.leadingAnchor),
            cardImageView.trailingAnchor.constraint(equalTo: cardImageContainer.trailingAnchor),
            cardImageView.bottomAnchor.constraint(equalTo: cardImageContainer.bottomAnchor),

            flipFaceButton.trailingAnchor.constraint(
                equalTo: cardImageContainer.trailingAnchor,
                constant: -8
            ),
            flipFaceButton.bottomAnchor.constraint(
                equalTo: cardImageContainer.bottomAnchor,
                constant: -8
            ),
            flipFaceButton.widthAnchor.constraint(equalToConstant: 38),
            flipFaceButton.heightAnchor.constraint(equalToConstant: 38),

            printingsCollectionView.heightAnchor.constraint(
                equalToConstant: 170
            ),
            printingsSearchField.heightAnchor.constraint(
                equalToConstant: 44
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
            addToSessionButton.leadingAnchor.constraint(
                equalTo: view.leadingAnchor,
                constant: 28
            ),
            addToSessionButton.trailingAnchor.constraint(
                equalTo: view.trailingAnchor,
                constant: -28
            ),
            addToSessionButton.heightAnchor.constraint(
                equalToConstant: 56
            )
        ])
    }

    private func makeHeaderDetailsStack() -> UIStackView {
        let infoGrid = UIStackView(arrangedSubviews: [
            makeInfoRow([
                makeInfoTile(title: "Set", systemImage: "target", valueLabel: setValueLabel),
                makeInfoTile(title: "Number", systemImage: "number.circle", valueLabel: collectorValueLabel)
            ]),
            makeInfoRow([
                makeInfoTile(title: "Rarity", systemImage: "diamond", valueLabel: rarityValueLabel),
                makeInfoTile(title: "Artist", systemImage: "paintbrush", valueLabel: artistLabel)
            ]),
            makeInfoRow([
                makeInfoTile(title: "Price", systemImage: "tag", valueLabel: priceValueLabel),
                makeInfoTile(title: "Released", systemImage: "calendar", valueLabel: releasedValueLabel)
            ])
        ])
        infoGrid.axis = .vertical
        infoGrid.spacing = 8

        let stack = UIStackView(arrangedSubviews: [
            infoGrid,
            languageButton
        ])
        stack.axis = .vertical
        stack.spacing = 10
        stack.alignment = .fill
        return stack
    }

    private func makeTypeManaRow() -> UIStackView {
        let row = UIStackView(arrangedSubviews: [
            typeLabel,
            manaCostStack
        ])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 10
        row.distribution = .fill
        row.layoutMargins = UIEdgeInsets(
            top: 0,
            left: 4,
            bottom: 0,
            right: 4
        )
        row.isLayoutMarginsRelativeArrangement = true

        typeLabel.textAlignment = .left
        typeLabel.setContentCompressionResistancePriority(
            .defaultLow,
            for: .horizontal
        )
        manaCostStack.setContentCompressionResistancePriority(
            .required,
            for: .horizontal
        )

        return row
    }

    private func makeInfoRow(_ views: [UIView]) -> UIStackView {
        let row = UIStackView(arrangedSubviews: views)
        row.axis = .horizontal
        row.spacing = 8
        row.distribution = .fillEqually
        return row
    }

    private func makeInfoTile(
        title: String,
        systemImage: String,
        valueLabel: UILabel
    ) -> UIView {
        let container = UIView()
        container.backgroundColor = .secondarySystemBackground
        container.layer.cornerRadius = 8
        container.layer.borderColor = UIColor.separator.cgColor
        container.layer.borderWidth = 0.5

        let iconView = UIImageView(image: UIImage(systemName: systemImage))
        iconView.tintColor = .brandBlue
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 12, weight: .medium)
        titleLabel.textColor = .secondaryLabel
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.72

        valueLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        valueLabel.textColor = .label
        valueLabel.numberOfLines = 3
        valueLabel.adjustsFontSizeToFitWidth = true
        valueLabel.minimumScaleFactor = 0.68

        let titleStack = UIStackView(arrangedSubviews: [iconView, titleLabel])
        titleStack.axis = .horizontal
        titleStack.spacing = 5
        titleStack.alignment = .center

        let stack = UIStackView(arrangedSubviews: [titleStack, valueLabel])
        stack.axis = .vertical
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(stack)

        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 15),
            iconView.heightAnchor.constraint(equalToConstant: 15),
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -8)
        ])

        return container
    }

    private func makeSectionHeader(
        title: String,
        trailingTitle: String? = nil
    ) -> UIView {
        let titleLabel = UILabel()
        titleLabel.text = title.uppercased()
        titleLabel.font = .systemFont(ofSize: 13, weight: .medium)
        titleLabel.textColor = .secondaryLabel

        let stack = UIStackView(arrangedSubviews: [titleLabel])
        stack.axis = .horizontal
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false

        if let trailingTitle {
            let trailingLabel = UILabel()
            trailingLabel.text = trailingTitle
            trailingLabel.font = .systemFont(ofSize: 13, weight: .medium)
            trailingLabel.textColor = .brandBlue
            stack.addArrangedSubview(UIView())
            stack.addArrangedSubview(trailingLabel)
        }

        let container = UIView()
        container.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        return container
    }

    private func configureSection(
        _ container: UIView,
        title: String?,
        content: UIView
    ) {
        let arrangedSubviews: [UIView]
        if let title {
            arrangedSubviews = [
                makeSectionHeader(title: title),
                content
            ]
        } else {
            arrangedSubviews = [content]
        }

        let stack = UIStackView(arrangedSubviews: arrangedSubviews)
        stack.axis = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
    }

    private func makeTextCard(
        iconName: String,
        label: UILabel,
        trailingView: UIView? = nil
    ) -> UIView {
        let container = UIView()
        container.backgroundColor = .secondarySystemBackground
        container.layer.cornerRadius = 8
        container.layer.borderColor = UIColor.separator.cgColor
        container.layer.borderWidth = 0.5

        let iconContainer = UIView()
        iconContainer.backgroundColor = UIColor.brandBlue.withAlphaComponent(0.12)
        iconContainer.layer.cornerRadius = 8
        iconContainer.translatesAutoresizingMaskIntoConstraints = false

        let iconView = UIImageView(image: UIImage(systemName: iconName))
        iconView.tintColor = .brandBlue
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.addSubview(iconView)

        let stack = UIStackView(arrangedSubviews: [iconContainer, label])
        stack.axis = .horizontal
        stack.spacing = 12
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false

        if let trailingView {
            stack.addArrangedSubview(UIView())
            stack.addArrangedSubview(trailingView)
        }

        container.addSubview(stack)

        NSLayoutConstraint.activate([
            iconContainer.widthAnchor.constraint(equalToConstant: 42),
            iconContainer.heightAnchor.constraint(equalToConstant: 42),
            iconView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 22),
            iconView.heightAnchor.constraint(equalToConstant: 22),
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12)
        ])

        return container
    }

    private func makeScryfallButtonCard() -> UIView {
        let container = UIView()
        container.backgroundColor = .secondarySystemBackground
        container.layer.cornerRadius = 8
        container.layer.borderColor = UIColor.separator.cgColor
        container.layer.borderWidth = 0.5

        container.addSubview(scryfallButton)
        scryfallButton.translatesAutoresizingMaskIntoConstraints = false
        scryfallButton.setContentHuggingPriority(.required, for: .horizontal)

        NSLayoutConstraint.activate([
            scryfallButton.topAnchor.constraint(equalTo: container.topAnchor, constant: 10),
            scryfallButton.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            scryfallButton.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -10),
            scryfallButton.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor, constant: 12),
            scryfallButton.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -12)
        ])

        return container
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

    private func updateManaCost(_ manaCost: String?) {
        manaCostStack.arrangedSubviews.forEach {
            manaCostStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        let symbols = parseManaSymbols(manaCost)
        manaCostStack.isHidden = symbols.isEmpty

        for rowSymbols in symbols.chunked(into: 5) {
            let row = UIStackView()
            row.axis = .horizontal
            row.alignment = .center
            row.spacing = 4

            for symbol in rowSymbols {
                row.addArrangedSubview(makeManaSymbolView(symbol))
            }

            manaCostStack.addArrangedSubview(row)
        }
    }

    private func parseManaSymbols(_ manaCost: String?) -> [String] {
        guard let manaCost, !manaCost.isEmpty else {
            return []
        }

        var symbols: [String] = []
        var current = ""
        var isInsideBraces = false

        for character in manaCost {
            if character == "{" {
                current = ""
                isInsideBraces = true
            } else if character == "}", isInsideBraces {
                symbols.append(current)
                isInsideBraces = false
            } else if isInsideBraces {
                current.append(character)
            }
        }

        return symbols
    }

    private func makeManaSymbolView(_ symbol: String) -> UIView {
        let images = manaImages(for: symbol)

        if images.count == 1, let image = images.first {
            let imageView = UIImageView(image: image)
            imageView.contentMode = .scaleAspectFit
            imageView.translatesAutoresizingMaskIntoConstraints = false

            NSLayoutConstraint.activate([
                imageView.widthAnchor.constraint(equalToConstant: 26),
                imageView.heightAnchor.constraint(equalToConstant: 26)
            ])

            return imageView
        }

        if !images.isEmpty {
            let stack = UIStackView()
            stack.axis = .horizontal
            stack.alignment = .center
            stack.spacing = -1

            for image in images {
                let imageView = UIImageView(image: image)
                imageView.contentMode = .scaleAspectFit
                imageView.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    imageView.widthAnchor.constraint(equalToConstant: 26),
                    imageView.heightAnchor.constraint(equalToConstant: 26)
                ])
                stack.addArrangedSubview(imageView)
            }

            return stack
        }

        let label = UILabel()
        label.text = symbol
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 15, weight: .bold)
        label.textColor = .label
        label.backgroundColor = UIColor.secondarySystemFill
        label.layer.cornerRadius = 13
        label.layer.borderColor = UIColor.separator.cgColor
        label.layer.borderWidth = 0.5
        label.clipsToBounds = true
        label.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            label.widthAnchor.constraint(greaterThanOrEqualToConstant: 26),
            label.heightAnchor.constraint(equalToConstant: 26)
        ])

        return label
    }

    private func manaImages(for symbol: String) -> [UIImage] {
        let assetNames = manaAssetNames(for: symbol)
        return assetNames.compactMap(UIImage.init(named:))
    }

    private func manaAssetNames(for symbol: String) -> [String] {
        let key = normalizedManaAssetKey(for: symbol)
        let baseName = "mana-\(key)"

        if UIImage(named: baseName) != nil {
            return [baseName]
        }

        let splitNames = (1...6)
            .map { "\(baseName)-\($0)" }
            .prefix { UIImage(named: $0) != nil }

        return Array(splitNames)
    }

    private func normalizedManaAssetKey(for symbol: String) -> String {
        symbol
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "/", with: "")
            .replacingOccurrences(of: "∞", with: "infinity")
            .replacingOccurrences(of: "½", with: "half")
    }

    private func manaImage(for symbol: String) -> UIImage? {
        manaImages(for: symbol).first
    }

    private func attributedRulesText(_ text: String) -> NSAttributedString {
        let font = oracleLabel.font ?? .systemFont(ofSize: 16)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 3

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.label,
            .paragraphStyle: paragraphStyle
        ]
        let result = NSMutableAttributedString()
        var current = ""
        var isInsideBraces = false

        func appendCurrent() {
            guard !current.isEmpty else {
                return
            }

            result.append(NSAttributedString(string: current, attributes: attributes))
            current = ""
        }

        for character in text {
            if character == "{" {
                appendCurrent()
                isInsideBraces = true
            } else if character == "}", isInsideBraces {
                let symbol = current
                current = ""
                isInsideBraces = false

                let images = manaImages(for: symbol)
                if !images.isEmpty {
                    images.forEach {
                        result.append(manaSymbolAttachment(image: $0, font: font))
                    }
                } else {
                    result.append(NSAttributedString(string: symbol, attributes: attributes))
                }
            } else {
                current.append(character)
            }
        }

        if isInsideBraces {
            result.append(NSAttributedString(string: "{", attributes: attributes))
        }
        appendCurrent()

        return result
    }

    private func manaSymbolAttachment(image: UIImage, font: UIFont) -> NSAttributedString {
        let attachment = NSTextAttachment()
        attachment.image = image
        let symbolSize = font.lineHeight + 2
        attachment.bounds = CGRect(
            x: 0,
            y: (font.capHeight - symbolSize) / 2,
            width: symbolSize,
            height: symbolSize
        )

        return NSAttributedString(attachment: attachment)
    }
    
    private func populateData() {
        updateDisplayedFace(animated: false)
        updateInfoLabel()
        updateLanguageButton()

        rulingsLabel.text = nil
    }

    private func updateInfoLabel() {
        setValueLabel.text = displayedCard.set.uppercased()
        collectorValueLabel.text = "#" + displayedCard.collectorNumber
        rarityValueLabel.text = displayedCard.rarity.capitalized
        priceValueLabel.text = PriceFormatter.string(usd: displayedCard.prices?.usd)
        releasedValueLabel.text = formattedReleaseDate(displayedCard.releasedAt)
        artistLabel.text = displayedCard.artist?.isEmpty == false
            ? displayedCard.artist
            : "Unknown artist"
    }

    private func updateLanguageButton(isLoading: Bool = false) {
        var config = languageButton.configuration
        config?.title = isLoading
            ? "Loading language..."
            : "\(selectedLanguage.displayName)"
        languageButton.configuration = config
        languageButton.isEnabled = !isLoading
    }

    private func updateDisplayedFace(animated: Bool) {
        let face = displayedCard.face(at: currentFaceIndex)

        nameLabel.text = displayedName(for: displayedCard, face: face)
        updateManaCost(face?.manaCost ?? displayedCard.manaCost)
        typeLabel.text = displayedTypeLine(for: displayedCard, face: face)

        oracleLabel.attributedText = attributedRulesText(
            displayedOracleText(for: displayedCard, face: face)
        )
        let flavorText = displayedFlavorText(for: displayedCard, face: face)
        flavorLabel.text = flavorText
        flavorSectionView.isHidden = flavorText == nil

        title = nil
        navigationItem.title = nil
        flipFaceButton.isHidden = !displayedCard.hasMultipleFaces
        loadImage(
            from: face?.imageUris?.normal ?? displayedCard.displayImage,
            animated: animated
        )
    }

    private func displayedName(
        for card: MTGCard,
        face: MTGCard.CardFace?
    ) -> String {
        if let printedName = card.printedName, !printedName.isEmpty {
            return printedName
        }

        return face?.name ?? card.name
    }

    private func displayedTypeLine(
        for card: MTGCard,
        face: MTGCard.CardFace?
    ) -> String {
        if let printedTypeLine = card.printedTypeLine, !printedTypeLine.isEmpty {
            return printedTypeLine
        }

        return face?.typeLine ?? card.typeLine
    }

    private func displayedOracleText(
        for card: MTGCard,
        face: MTGCard.CardFace?
    ) -> String {
        if let printedText = card.printedText, !printedText.isEmpty {
            return printedText
        }

        if face?.oracleText?.isEmpty == false {
            return face?.oracleText ?? ""
        }

        if card.oracleText?.isEmpty == false {
            return card.oracleText ?? ""
        }

        return "No Oracle text available."
    }

    private func displayedFlavorText(
        for card: MTGCard,
        face: MTGCard.CardFace?
    ) -> String? {
        if let flavorText = face?.flavorText, !flavorText.isEmpty {
            return flavorText
        }

        if let flavorText = card.flavorText, !flavorText.isEmpty {
            return flavorText
        }

        return nil
    }

    private func formattedReleaseDate(_ value: String?) -> String {
        guard let value, !value.isEmpty else {
            return "Unknown"
        }

        let inputFormatter = DateFormatter()
        inputFormatter.locale = Locale(identifier: "en_US_POSIX")
        inputFormatter.dateFormat = "yyyy-MM-dd"

        guard let date = inputFormatter.date(from: value) else {
            return value
        }

        let outputFormatter = DateFormatter()
        outputFormatter.locale = Locale.current
        outputFormatter.dateStyle = .medium
        outputFormatter.timeStyle = .none
        return outputFormatter.string(from: date)
    }

    // MARK: - Language

    private func loadPreferredLanguageIfNeeded() {
        guard selectedLanguage != .english else {
            return
        }

        loadLanguage(selectedLanguage)
    }

    private func loadAvailableLanguages() {
        let codes = (try? AppDatabase.shared.cards.languages(
            name: card.name,
            set: card.set,
            collectorNumber: card.collectorNumber
        )) ?? [card.language ?? CardLanguage.english.rawValue]

        let languages = codes.compactMap(CardLanguage.init(rawValue:))
        availableLanguages = languages.isEmpty ? [.english] : languages

        if !availableLanguages.contains(selectedLanguage) {
            selectedLanguage = availableLanguages.first ?? .english
        }
    }

    private func loadLanguage(_ language: CardLanguage) {
        localizedCardTask?.cancel()
        selectedLanguage = language

        guard language != .english else {
            displayedCard = card
            currentFaceIndex = 0
            updateDisplayedFace(animated: true)
            updateInfoLabel()
            updateLanguageButton()
            return
        }

        updateLanguageButton(isLoading: true)

        localizedCardTask = Task { [weak self] in
            guard let self else { return }

            do {
                let localizedCard = try await scryfallService.fetchLocalizedPrinting(
                    set: card.set,
                    collectorNumber: card.collectorNumber,
                    language: language
                )

                guard !Task.isCancelled else {
                    return
                }

                await MainActor.run {
                    self.displayedCard = localizedCard
                    self.currentFaceIndex = 0
                    self.updateDisplayedFace(animated: true)
                    self.updateInfoLabel()
                    self.updateLanguageButton()
                    self.localizedCardTask = nil
                }
            } catch {
                guard !Task.isCancelled else {
                    return
                }

                await MainActor.run {
                    self.selectedLanguage = .english
                    self.displayedCard = self.card
                    self.currentFaceIndex = 0
                    self.updateDisplayedFace(animated: true)
                    self.updateInfoLabel()
                    self.updateLanguageButton()
                    self.localizedCardTask = nil
                    self.showLanguageUnavailableAlert(language: language)
                }
            }
        }
    }

    private func showLanguageUnavailableAlert(language: CardLanguage) {
        let alert = UIAlertController(
            title: "Language unavailable",
            message: "Scryfall does not have this printing in \(language.displayName).",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    @objc private func showLanguagePicker() {
        let alert = UIAlertController(
            title: "Card Language",
            message: nil,
            preferredStyle: .actionSheet
        )

        for language in availableLanguages {
            let isSelected = language == selectedLanguage
            let suffix = isSelected ? " (Current)" : ""
            let action = UIAlertAction(
                title: "\(language.displayName) - \(language.rawValue)\(suffix)",
                style: .default
            ) { [weak self] _ in
                CardLanguageSettings.shared.preferredLanguage = language
                self?.loadLanguage(language)
            }

            alert.addAction(action)
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        if let popover = alert.popoverPresentationController {
            popover.sourceView = languageButton
            popover.sourceRect = languageButton.bounds
        }

        present(alert, animated: true)
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
                self.printingsSearchField.isHidden = printings.count <= 1

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
        guard displayedCard.hasMultipleFaces else {
            return
        }

        let faceCount = displayedCard.cardFaces?.count ?? 1
        currentFaceIndex = (currentFaceIndex + 1) % faceCount
        updateDisplayedFace(animated: true)
    }

    @objc
    private func openScryfall() {

        guard let url = displayedCard.scryfallUri else {
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

        let selectedCard = filteredPrintings[indexPath.item]

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

private extension Array {

    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else {
            return [self]
        }

        return stride(
            from: 0,
            to: count,
            by: size
        ).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
