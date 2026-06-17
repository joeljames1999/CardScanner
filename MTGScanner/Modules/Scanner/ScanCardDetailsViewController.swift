import UIKit

final class ScanCardDetailsViewController: UIViewController {

    // MARK: - Properties

    private let card: MTGCard

    var onAdd: ((SessionEntry) -> Void)?

    private var quantity = 1
    private var selectedCondition: CardCondition = .nearMint
    private var selectedLanguage = "English"

    private let languages = [
        "English",
        "Japanese",
        "German",
        "French",
        "Italian",
        "Spanish",
        "Portuguese",
        "Russian",
        "Chinese",
        "Korean"
    ]

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
        iv.layer.cornerRadius = 12
        iv.clipsToBounds = true
        iv.backgroundColor = .secondarySystemBackground
        return iv
    }()

    private let cardNameLabel: UILabel = {
        let label = UILabel()
        label.font = .boldSystemFont(ofSize: 24)
        label.numberOfLines = 0
        return label
    }()

    private let setLabel: UILabel = {
        let label = UILabel()
        label.textColor = .secondaryLabel
        return label
    }()

    private let quantityLabel: UILabel = {
        let label = UILabel()
        label.text = "1"
        label.font = .boldSystemFont(ofSize: 20)
        label.textAlignment = .center
        label.widthAnchor.constraint(equalToConstant: 60).isActive = true
        return label
    }()

    private lazy var minusButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(
            UIImage(systemName: "minus.circle.fill"),
            for: .normal
        )
        button.addTarget(
            self,
            action: #selector(decreaseQuantity),
            for: .touchUpInside
        )
        return button
    }()

    private lazy var plusButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(
            UIImage(systemName: "plus.circle.fill"),
            for: .normal
        )
        button.addTarget(
            self,
            action: #selector(increaseQuantity),
            for: .touchUpInside
        )
        return button
    }()

    private let conditionSegmented: UISegmentedControl = {
        UISegmentedControl(
            items: [
                "Mint",
                "NM",
                "Good",
                "LP",
                "Poor"
            ]
        )
    }()

    private let languageButton: UIButton = {
        var config = UIButton.Configuration.gray()
        config.title = "English"
        config.image = UIImage(systemName: "chevron.down")
        config.imagePlacement = .trailing

        let button = UIButton(configuration: config)
        return button
    }()

    private let foilSwitch = UISwitch()
    private let alteredSwitch = UISwitch()

    private lazy var addButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Add To Session", for: .normal)
        button.titleLabel?.font = .boldSystemFont(ofSize: 18)
        button.backgroundColor = .systemBlue
        button.tintColor = .white
        button.layer.cornerRadius = 12
        button.heightAnchor.constraint(equalToConstant: 50).isActive = true

        button.addTarget(
            self,
            action: #selector(addTapped),
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

        title = "Card Details"

        view.backgroundColor = .systemGroupedBackground

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            systemItem: .cancel,
            primaryAction: UIAction { [weak self] _ in
                self?.dismiss(animated: true)
            }
        )

        setupLanguageMenu()
        setupLayout()
        populateCard()
    }

    // MARK: - Layout

    private func setupLayout() {

        view.addSubview(scrollView)

        scrollView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 20),
            contentStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -20)
        ])

        cardImageView.heightAnchor.constraint(equalToConstant: 300).isActive = true

        contentStack.addArrangedSubview(cardImageView)
        contentStack.addArrangedSubview(cardNameLabel)
        contentStack.addArrangedSubview(setLabel)

        contentStack.addArrangedSubview(makeSectionTitle("Quantity"))

        let quantityStack = UIStackView(
            arrangedSubviews: [
                minusButton,
                quantityLabel,
                plusButton
            ]
        )

        quantityStack.axis = .horizontal
        quantityStack.alignment = .center
        quantityStack.distribution = .equalCentering

        contentStack.addArrangedSubview(quantityStack)

        contentStack.addArrangedSubview(makeSectionTitle("Condition"))
        contentStack.addArrangedSubview(conditionSegmented)

        contentStack.addArrangedSubview(makeSectionTitle("Language"))
        contentStack.addArrangedSubview(languageButton)

        contentStack.addArrangedSubview(makeToggleRow(
            title: "Foil",
            toggle: foilSwitch
        ))

        contentStack.addArrangedSubview(makeToggleRow(
            title: "Altered",
            toggle: alteredSwitch
        ))

        contentStack.addArrangedSubview(addButton)
    }

    private func makeSectionTitle(_ title: String) -> UILabel {

        let label = UILabel()
        label.text = title
        label.font = .preferredFont(forTextStyle: .headline)
        return label
    }

    private func makeToggleRow(
        title: String,
        toggle: UISwitch
    ) -> UIView {

        let label = UILabel()
        label.text = title

        let stack = UIStackView(
            arrangedSubviews: [
                label,
                UIView(),
                toggle
            ]
        )

        stack.axis = .horizontal

        return stack
    }

    // MARK: - Populate

    private func populateCard() {

        cardNameLabel.text = card.name
        setLabel.text = card.setName

        conditionSegmented.selectedSegmentIndex = 1

        guard let imageURL = card.imageUris?.normal else {
            return
        }

        Task {

            do {

                let (data, _) = try await URLSession.shared.data(
                    from: imageURL
                )

                guard let image = UIImage(data: data) else {
                    return
                }

                await MainActor.run {
                    self.cardImageView.image = image
                }

            } catch {
                print(error)
            }
        }
    }

    // MARK: - Language Menu

    private func setupLanguageMenu() {

        languageButton.menu = UIMenu(
            children: languages.map { language in

                UIAction(
                    title: language
                ) { [weak self] _ in

                    self?.selectedLanguage = language

                    self?.languageButton.configuration?.title =
                        language
                }
            }
        )

        languageButton.showsMenuAsPrimaryAction = true
    }

    // MARK: - Actions

    @objc
    private func decreaseQuantity() {

        quantity = max(1, quantity - 1)
        quantityLabel.text = "\(quantity)"
    }

    @objc
    private func increaseQuantity() {

        quantity += 1
        quantityLabel.text = "\(quantity)"
    }

    @objc
    private func addTapped() {

        let condition: CardCondition

        switch conditionSegmented.selectedSegmentIndex {

        case 0:
            condition = .mint

        case 1:
            condition = .nearMint

        case 2:
            condition = .good

        case 3:
            condition = .lightlyPlayed

        default:
            condition = .poor
        }

        let entry = SessionEntry(
            card: card,
            count: quantity,
            condition: condition,
            isFoil: foilSwitch.isOn,
            isAltered: alteredSwitch.isOn,
            language: selectedLanguage
        )

        onAdd?(entry)

        dismiss(animated: true)
    }
}
