import UIKit

final class CardDetailViewController: UIViewController {

    // MARK: - Properties

    private let card: MTGCard
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

    private let cardImageView: UIImageView = {
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.contentMode = .scaleAspectFit
        iv.backgroundColor = .secondarySystemBackground
        iv.clipsToBounds = true
        return iv
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

        let button = UIButton(configuration: config)

        button.translatesAutoresizingMaskIntoConstraints = false

        button.addTarget(
            self,
            action: #selector(addToSession),
            for: .touchUpInside
        )

        return button
    }()

    // MARK: - Init

    init(card: MTGCard) {
        self.card = card
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

        setupLayout()
        populateData()
        loadImage()
        updateSessionButton()

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

        // Add arranged subviews BEFORE activating constraints
        contentStack.addArrangedSubview(cardImageView)
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

            // MTG card aspect ratio (63 × 88 mm)
            cardImageView.heightAnchor.constraint(
                equalTo: cardImageView.widthAnchor,
                multiplier: 88.0 / 63.0
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

        paddedContent.addSubview(textStack)

        NSLayoutConstraint.activate([
            textStack.topAnchor.constraint(equalTo: paddedContent.topAnchor, constant: 20),
            textStack.leadingAnchor.constraint(equalTo: paddedContent.leadingAnchor, constant: 20),
            textStack.trailingAnchor.constraint(equalTo: paddedContent.trailingAnchor, constant: -20),
            textStack.bottomAnchor.constraint(equalTo: paddedContent.bottomAnchor)
        ])
    }

    // MARK: - Data

    
    private func populateData() {

        nameLabel.text = card.name
        manaCostLabel.text = card.manaCost
        typeLabel.text = card.typeLine

        infoLabel.text =
        """
        Set: \(card.setName)

        Collector Number: \(card.collectorNumber)

        Rarity: \(card.rarity.capitalized)

        Price: \(card.prices?.usd.map { "$\($0)" } ?? "Unavailable")
        """

        oracleLabel.text =
        card.oracleText?.isEmpty == false
        ? card.oracleText
        : "No Oracle text available."

        rulingsLabel.text = "Loading rulings..."
    }

    // MARK: - Image

    private func loadImage() {

        guard let url = card.imageUris?.normal else {
            return
        }

        Task {

            guard
                let (data, _) = try? await URLSession.shared.data(from: url),
                let image = UIImage(data: data)
            else {
                return
            }

            await MainActor.run {
                self.cardImageView.image = image
            }
        }
    }

    // MARK: - Rulings

    private func loadRulings() {

        rulingsLabel.text =
        "Rulings support can be added via the Scryfall rulings endpoint."
    }

    // MARK: - Session

    private func updateSessionButton() {

        let count =
        SessionStore.shared.entries
            .first(where: { $0.card.id == card.id })?
            .count ?? 0

        var config = addToSessionButton.configuration

        config?.title =
            count > 0
            ? "Add Another"
            : "Add to Session"

        addToSessionButton.configuration = config

        sessionStatusLabel.text =
            count > 0
            ? "×\(count) currently in session"
            : nil
    }

    @objc
    private func addToSession() {

        SessionStore.shared.addOrIncrement(card: card)

        UINotificationFeedbackGenerator()
            .notificationOccurred(.success)

        updateSessionButton()
    }

    // MARK: - Actions

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
