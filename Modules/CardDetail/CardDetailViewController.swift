import UIKit

// MARK: - CardDetailViewController

final class CardDetailViewController: UIViewController {

    // MARK: Properties

    private let card: MTGCard
    var onDismiss: (() -> Void)?

    // MARK: UI

    private lazy var scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private lazy var contentStack: UIStackView = {
        let sv = UIStackView()
        sv.translatesAutoresizingMaskIntoConstraints = false
        sv.axis      = .vertical
        sv.spacing   = 16
        sv.alignment = .fill
        return sv
    }()

    private lazy var cardImageView: UIImageView = {
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.contentMode        = .scaleAspectFit
        iv.layer.cornerRadius = 12
        iv.clipsToBounds      = true
        iv.backgroundColor    = .secondarySystemBackground
        return iv
    }()

    private lazy var nameLabel: UILabel = {
        let lbl = UILabel()
        lbl.font          = .systemFont(ofSize: 22, weight: .bold)
        lbl.numberOfLines = 0
        return lbl
    }()

    private lazy var manaCostLabel: UILabel = {
        let lbl = UILabel()
        lbl.font      = .systemFont(ofSize: 16, weight: .medium)
        lbl.textColor = .secondaryLabel
        return lbl
    }()

    private lazy var typeLabel: UILabel = {
        let lbl = UILabel()
        lbl.font      = .systemFont(ofSize: 14)
        lbl.textColor = .secondaryLabel
        return lbl
    }()

    private lazy var oracleTextView: UITextView = {
        let tv = UITextView()
        tv.isEditable          = false
        tv.isScrollEnabled     = false
        tv.font                = .systemFont(ofSize: 14)
        tv.backgroundColor     = .clear
        tv.textContainerInset  = .zero
        tv.textContainer.lineFragmentPadding = 0
        return tv
    }()

    private lazy var priceLabel: UILabel = {
        let lbl = UILabel()
        lbl.font      = .systemFont(ofSize: 16, weight: .semibold)
        lbl.textColor = .systemGreen
        return lbl
    }()

    private lazy var setLabel: UILabel = {
        let lbl = UILabel()
        lbl.font      = .systemFont(ofSize: 13)
        lbl.textColor = .tertiaryLabel
        return lbl
    }()

    private lazy var addToCollectionButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.title       = "Add to Collection"
        config.image       = UIImage(systemName: "plus.circle.fill")
        config.imagePadding = 8
        config.cornerStyle  = .capsule
        let btn = UIButton(configuration: config)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.addTarget(self, action: #selector(addToCollection), for: .touchUpInside)
        return btn
    }()

    // MARK: Init

    init(card: MTGCard) {
        self.card = card
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = card.name
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            systemItem: .close,
            primaryAction: UIAction { [weak self] _ in
                self?.dismiss(animated: true) { self?.onDismiss?() }
            }
        )
        setupLayout()
        populateData()
        loadImage()
        updateCollectionButton()
    }

    // MARK: Layout

    private func setupLayout() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)
        view.addSubview(addToCollectionButton)

        let padding: CGFloat = 20

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: addToCollectionButton.topAnchor, constant: -8),

            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: padding),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: padding),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -padding),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -padding),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -padding * 2),

            cardImageView.heightAnchor.constraint(equalTo: cardImageView.widthAnchor, multiplier: 88.0 / 63.0),

            addToCollectionButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            addToCollectionButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: padding),
            addToCollectionButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -padding),
            addToCollectionButton.heightAnchor.constraint(equalToConstant: 50),
        ])

        contentStack.addArrangedSubview(cardImageView)
        contentStack.addArrangedSubview(nameLabel)
        contentStack.addArrangedSubview(manaCostLabel)
        contentStack.addArrangedSubview(typeLabel)
        contentStack.addArrangedSubview(makeDivider())
        contentStack.addArrangedSubview(oracleTextView)
        contentStack.addArrangedSubview(makeDivider())
        contentStack.addArrangedSubview(priceLabel)
        contentStack.addArrangedSubview(setLabel)
    }

    // MARK: Data

    private func populateData() {
        nameLabel.text      = card.name
        manaCostLabel.text  = card.manaCost ?? "—"
        typeLabel.text      = card.typeLine
        oracleTextView.text = card.oracleText ?? ""

        if let usd = card.prices?.usd {
            priceLabel.text = "$\(usd)"
        } else {
            priceLabel.text = "Price unavailable"
            priceLabel.textColor = .secondaryLabel
        }

        setLabel.text = "\(card.setName) · #\(card.collectorNumber) · \(card.rarity.capitalized)"
    }

    private func loadImage() {
        guard let url = card.imageUris?.normal else { return }
        Task {
            if let (data, _) = try? await URLSession.shared.data(from: url),
               let image = UIImage(data: data) {
                await MainActor.run {
                    UIView.transition(with: self.cardImageView, duration: 0.25, options: .transitionCrossDissolve) {
                        self.cardImageView.image = image
                    }
                }
            }
        }
    }

    // MARK: Collection

    private func updateCollectionButton() {
        let alreadyAdded = CollectionStore.shared.contains(cardID: card.id)
        var config = addToCollectionButton.configuration
        config?.title = alreadyAdded ? "In Collection" : "Add to Collection"
        config?.image = UIImage(systemName: alreadyAdded ? "checkmark.circle.fill" : "plus.circle.fill")
        config?.baseBackgroundColor = alreadyAdded ? .systemGray : .systemBlue
        addToCollectionButton.configuration = config
        addToCollectionButton.isEnabled = !alreadyAdded
    }

    @objc private func addToCollection() {
        let entry = ScannedCard(from: card)
        CollectionStore.shared.add(entry)
        updateCollectionButton()

        // Haptic feedback
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    // MARK: Helpers

    private func makeDivider() -> UIView {
        let v = UIView()
        v.backgroundColor = .separator
        v.heightAnchor.constraint(equalToConstant: 0.5).isActive = true
        return v
    }
}
