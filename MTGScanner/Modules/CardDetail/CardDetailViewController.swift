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
        sv.spacing   = 14
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
        lbl.font      = .systemFont(ofSize: 15, weight: .medium)
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
        tv.isEditable         = false
        tv.isScrollEnabled    = false
        tv.font               = .systemFont(ofSize: 14)
        tv.backgroundColor    = .clear
        tv.textContainerInset = .zero
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

    private lazy var sessionStatusLabel: UILabel = {
        let lbl = UILabel()
        lbl.font          = .systemFont(ofSize: 13)
        lbl.textColor     = .secondaryLabel
        lbl.textAlignment = .center
        return lbl
    }()

    private lazy var addToSessionButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.image       = UIImage(systemName: "plus.circle.fill")
        config.imagePadding = 8
        config.cornerStyle  = .capsule
        let btn = UIButton(configuration: config)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.addTarget(self, action: #selector(addToSession), for: .touchUpInside)
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
        updateSessionButton()
    }

    // MARK: Layout

    private func setupLayout() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)
        view.addSubview(sessionStatusLabel)
        view.addSubview(addToSessionButton)

        let padding: CGFloat = 20

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: sessionStatusLabel.topAnchor, constant: -8),

            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: padding),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: padding),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -padding),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -padding),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -padding * 2),

            cardImageView.heightAnchor.constraint(equalTo: cardImageView.widthAnchor, multiplier: 88.0 / 63.0),

            sessionStatusLabel.bottomAnchor.constraint(equalTo: addToSessionButton.topAnchor, constant: -6),
            sessionStatusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            addToSessionButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            addToSessionButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: padding),
            addToSessionButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -padding),
            addToSessionButton.heightAnchor.constraint(equalToConstant: 50),
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
        manaCostLabel.text  = card.manaCost ?? ""
        typeLabel.text      = card.typeLine
        oracleTextView.text = card.oracleText ?? ""

        if let usd = card.prices?.usd {
            priceLabel.text  = "$\(usd)"
            priceLabel.textColor = .systemGreen
        } else {
            priceLabel.text  = "Price unavailable"
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

    // MARK: Session

    private func updateSessionButton() {
        let inSession   = SessionStore.shared.contains(cardID: card.id)
        let inCollection = CollectionStore.shared.entry(for: card.id) != nil
        let sessionCount = SessionStore.shared.entries.first(where: { $0.card.id == card.id })?.count ?? 0

        var config = addToSessionButton.configuration
        config?.title      = inSession ? "Add Another" : "Add to Session"
        config?.image      = UIImage(systemName: "plus.circle.fill")
        config?.baseBackgroundColor = .systemBlue

        addToSessionButton.configuration = config

        if inSession {
            sessionStatusLabel.text = "×\(sessionCount) in session"
        } else if inCollection {
            let count = CollectionStore.shared.entry(for: card.id)?.count ?? 0
            sessionStatusLabel.text = "Already own ×\(count) in collection"
        } else {
            sessionStatusLabel.text = nil
        }
    }

    @objc private func addToSession() {
        SessionStore.shared.addOrIncrement(card: card)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        updateSessionButton()
    }

    // MARK: Helpers

    private func makeDivider() -> UIView {
        let v = UIView()
        v.backgroundColor = .separator
        v.heightAnchor.constraint(equalToConstant: 0.5).isActive = true
        return v
    }
}
