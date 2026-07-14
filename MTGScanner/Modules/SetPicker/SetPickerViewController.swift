import UIKit

// MARK: - SetPickerViewController
// Sheet showing all printings of a matched card — user picks their set.
// Ordered newest to oldest via rowid DESC (Scryfall bulk data is chronological).

final class SetPickerViewController: UIViewController {

    // MARK: - Properties

    private let cardName: String
    private let printings: [MTGCard]
    var onSelect: ((MTGCard) -> Void)?
    var onDismiss: (() -> Void)?

    // MARK: - UI

    private lazy var tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .insetGrouped)
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.register(PrintingCell.self, forCellReuseIdentifier: PrintingCell.reuseID)
        tv.dataSource = self
        tv.delegate   = self
        tv.rowHeight  = 64
        return tv
    }()

    private lazy var artImageView: UIImageView = {
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.contentMode        = .scaleAspectFill
        iv.layer.cornerRadius = 8
        iv.clipsToBounds      = true
        iv.backgroundColor    = .secondarySystemBackground
        return iv
    }()

    private lazy var titleLabel: UILabel = {
        let lbl = UILabel()
        lbl.translatesAutoresizingMaskIntoConstraints = false
        lbl.font          = .systemFont(ofSize: 20, weight: .bold)
        lbl.numberOfLines = 2
        return lbl
    }()

    private lazy var subtitleLabel: UILabel = {
        let lbl = UILabel()
        lbl.translatesAutoresizingMaskIntoConstraints = false
        lbl.font      = .systemFont(ofSize: 13)
        lbl.textColor = .secondaryLabel
        return lbl
    }()

    // MARK: - Init

    init(cardName: String, printings: [MTGCard]) {
        self.cardName  = cardName
        self.printings = printings
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        title = "Choose Printing"

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            systemItem: .close,
            primaryAction: UIAction { [weak self] _ in
                self?.dismiss(animated: true) { self?.onDismiss?() }
            }
        )

        setupLayout()
        configure()
    }

    // MARK: - Layout

    private func setupLayout() {
        // Build header view with art + title
        let headerView = UIView()

        let textStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        textStack.axis      = .vertical
        textStack.spacing   = 4
        textStack.alignment = .leading
        textStack.translatesAutoresizingMaskIntoConstraints = false

        headerView.addSubview(artImageView)
        headerView.addSubview(textStack)

        NSLayoutConstraint.activate([
            artImageView.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 20),
            artImageView.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 16),
            artImageView.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -16),
            artImageView.widthAnchor.constraint(equalToConstant: 80),
            artImageView.heightAnchor.constraint(equalToConstant: 56),

            textStack.leadingAnchor.constraint(equalTo: artImageView.trailingAnchor, constant: 14),
            textStack.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -20),
            textStack.centerYAnchor.constraint(equalTo: artImageView.centerYAnchor),
        ])

        headerView.frame = CGRect(x: 0, y: 0, width: 0, height: 88)
        tableView.tableHeaderView = headerView

        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func configure() {
        titleLabel.text    = cardName
        subtitleLabel.text = "\(printings.count) printing\(printings.count == 1 ? "" : "s") available"

        // Load art crop from the first (most recent) printing
        let artURL = printings.first?.imageUris?.artCrop ?? printings.first?.displayImage
        if let url = artURL {
            Task {
                if let (data, _) = try? await URLSession.shared.data(from: url),
                   let image = UIImage(data: data) {
                    await MainActor.run {
                        UIView.transition(
                            with: self.artImageView,
                            duration: 0.2,
                            options: .transitionCrossDissolve
                        ) {
                            self.artImageView.image = image
                        }
                    }
                }
            }
        }
    }
}

// MARK: - UITableViewDataSource

extension SetPickerViewController: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int { 1 }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        printings.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        "Select Set — Newest First"
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: PrintingCell.reuseID,
            for: indexPath
        ) as! PrintingCell
        cell.configure(with: printings[indexPath.row])
        return cell
    }
}

// MARK: - UITableViewDelegate

extension SetPickerViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let card = printings[indexPath.row]
        dismiss(animated: true) { [weak self] in
            self?.onSelect?(card)
        }
    }
}

// MARK: - PrintingCell

final class SetPickerPrintingCell: UITableViewCell {
    static let reuseID = "SetPickerPrintingCell"

    private let cardImageView: UIImageView = {
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.contentMode        = .scaleAspectFill
        iv.clipsToBounds      = true
        iv.layer.cornerRadius = 4
        iv.backgroundColor    = .secondarySystemBackground
        return iv
    }()

    private let setNameLabel: UILabel = {
        let lbl = UILabel()
        lbl.font          = .systemFont(ofSize: 15, weight: .semibold)
        lbl.numberOfLines = 1
        return lbl
    }()

    private let setCodeLabel: UILabel = {
        let lbl = UILabel()
        lbl.font      = .systemFont(ofSize: 12)
        lbl.textColor = .secondaryLabel
        return lbl
    }()

    private let priceLabel: UILabel = {
        let lbl = UILabel()
        lbl.font          = .systemFont(ofSize: 13, weight: .medium)
        lbl.textColor     = .systemGreen
        lbl.textAlignment = .right
        lbl.numberOfLines = 2
        return lbl
    }()

    private let rarityDot: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.layer.cornerRadius = 4
        v.widthAnchor.constraint(equalToConstant: 8).isActive  = true
        v.heightAnchor.constraint(equalToConstant: 8).isActive = true
        return v
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        accessoryType = .disclosureIndicator

        let labelStack = UIStackView(arrangedSubviews: [setNameLabel, setCodeLabel])
        labelStack.axis    = .vertical
        labelStack.spacing = 2
        labelStack.translatesAutoresizingMaskIntoConstraints = false

        let leftStack = UIStackView(arrangedSubviews: [rarityDot, labelStack])
        leftStack.axis      = .horizontal
        leftStack.spacing   = 8
        leftStack.alignment = .center
        leftStack.translatesAutoresizingMaskIntoConstraints = false

        priceLabel.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(cardImageView)
        contentView.addSubview(leftStack)
        contentView.addSubview(priceLabel)

        NSLayoutConstraint.activate([
            cardImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            cardImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            cardImageView.widthAnchor.constraint(equalToConstant: 36),
            cardImageView.heightAnchor.constraint(equalToConstant: 50),

            leftStack.leadingAnchor.constraint(equalTo: cardImageView.trailingAnchor, constant: 12),
            leftStack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            leftStack.trailingAnchor.constraint(lessThanOrEqualTo: priceLabel.leadingAnchor, constant: -8),

            priceLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            priceLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            priceLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 50),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(with card: MTGCard) {
        setNameLabel.text             = card.setName
        setCodeLabel.text             = "\(card.set.uppercased()) · #\(card.collectorNumber)"
        priceLabel.attributedText     = priceSummary(for: card)
        rarityDot.backgroundColor     = rarityColour(card.rarity)
        cardImageView.image           = nil

        if let url = card.displayImage {
            Task {
                if let (data, _) = try? await URLSession.shared.data(from: url),
                   let img = UIImage(data: data) {
                    await MainActor.run {
                        self.cardImageView.image = img
                    }
                }
            }
        }
    }

    private func priceSummary(for card: MTGCard) -> NSAttributedString {
        let finishes = Set(card.availableFinishes)
        let hasNonfoil = finishes.contains(.nonfoil)
        let hasFoil = finishes.contains(.foil) || finishes.contains(.etched)
        let regularPrice = PriceFormatter.string(usd: card.prices?.usd)
        let foilPrice = PriceFormatter.string(usd: card.prices?.usdFoil)

        if hasNonfoil && hasFoil {
            let summary = NSMutableAttributedString(string: regularPrice)
            summary.append(NSAttributedString(string: " / "))
            summary.append(foilPriceAttributed(foilPrice))
            return summary
        }

        if hasFoil {
            return foilPriceAttributed(foilPrice)
        }

        return NSAttributedString(string: regularPrice)
    }

    private func foilPriceAttributed(_ price: String) -> NSAttributedString {
        let summary = NSMutableAttributedString()
        summary.append(goldStarAttachment())
        summary.append(NSAttributedString(string: " \(price)"))
        return summary
    }

    private func goldStarAttachment() -> NSAttributedString {
        let attachment = NSTextAttachment()
        let image = UIImage(systemName: "star.fill")?.withTintColor(
            UIColor(red: 0.95, green: 0.72, blue: 0.18, alpha: 1),
            renderingMode: .alwaysOriginal
        )
        attachment.image = image
        attachment.bounds = CGRect(x: 0, y: -1, width: 12, height: 12)
        return NSAttributedString(attachment: attachment)
    }

    private func rarityColour(_ rarity: String) -> UIColor {
        switch rarity.lowercased() {
        case "common":   return .secondaryLabel
        case "uncommon": return UIColor(red: 0.55, green: 0.65, blue: 0.68, alpha: 1)
        case "rare":     return UIColor(red: 0.85, green: 0.72, blue: 0.35, alpha: 1)
        case "mythic":   return UIColor(red: 0.90, green: 0.45, blue: 0.15, alpha: 1)
        default:         return .secondaryLabel
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        cardImageView.image = nil
        setNameLabel.text   = nil
        setCodeLabel.text   = nil
        priceLabel.attributedText = nil
    }
}
