import UIKit

// MARK: - CollectionViewController

final class CollectionViewController: UIViewController {

    // MARK: Data

    private var cards: [ScannedCard] = []

    // MARK: UI

    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 12
        layout.minimumLineSpacing      = 12
        layout.sectionInset            = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.translatesAutoresizingMaskIntoConstraints = false
        cv.backgroundColor = .systemBackground
        cv.register(CardCollectionCell.self, forCellWithReuseIdentifier: CardCollectionCell.reuseID)
        cv.dataSource = self
        cv.delegate   = self
        return cv
    }()

    private lazy var emptyStateLabel: UILabel = {
        let lbl = UILabel()
        lbl.translatesAutoresizingMaskIntoConstraints = false
        lbl.text          = "No cards yet.\nScan a card to start your collection!"
        lbl.textColor     = .secondaryLabel
        lbl.textAlignment = .center
        lbl.font          = .systemFont(ofSize: 16)
        lbl.numberOfLines = 0
        lbl.isHidden      = true
        return lbl
    }()

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "My Collection"
        navigationItem.largeTitleDisplayMode = .automatic
        view.backgroundColor = .systemBackground
        setupLayout()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reload()
    }

    // MARK: Layout

    private func setupLayout() {
        view.addSubview(collectionView)
        view.addSubview(emptyStateLabel)

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            emptyStateLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyStateLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            emptyStateLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
        ])
    }

    // MARK: Data

    private func reload() {
        cards = CollectionStore.shared.cards
        emptyStateLabel.isHidden = !cards.isEmpty
        collectionView.reloadData()
    }
}

// MARK: - UICollectionViewDataSource

extension CollectionViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        cards.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CardCollectionCell.reuseID, for: indexPath) as! CardCollectionCell
        cell.configure(with: cards[indexPath.item])
        return cell
    }
}

// MARK: - UICollectionViewDelegateFlowLayout

extension CollectionViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        let padding: CGFloat = 16 * 2 + 12  // insets + spacing
        let itemWidth = (collectionView.bounds.width - padding) / 2
        let itemHeight = itemWidth * (88.0 / 63.0) + 44  // card aspect + label
        return CGSize(width: itemWidth, height: itemHeight)
    }
}

// MARK: - CardCollectionCell

final class CardCollectionCell: UICollectionViewCell {
    static let reuseID = "CardCollectionCell"

    private let imageView: UIImageView = {
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.contentMode        = .scaleAspectFill
        iv.clipsToBounds      = true
        iv.layer.cornerRadius = 8
        iv.backgroundColor    = .secondarySystemBackground
        return iv
    }()

    private let nameLabel: UILabel = {
        let lbl = UILabel()
        lbl.translatesAutoresizingMaskIntoConstraints = false
        lbl.font          = .systemFont(ofSize: 12, weight: .semibold)
        lbl.numberOfLines = 2
        lbl.textAlignment = .center
        return lbl
    }()

    private let priceLabel: UILabel = {
        let lbl = UILabel()
        lbl.translatesAutoresizingMaskIntoConstraints = false
        lbl.font      = .systemFont(ofSize: 11)
        lbl.textColor = .systemGreen
        lbl.textAlignment = .center
        return lbl
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(imageView)
        contentView.addSubview(nameLabel)
        contentView.addSubview(priceLabel)

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.heightAnchor.constraint(equalTo: imageView.widthAnchor, multiplier: 88.0 / 63.0),

            nameLabel.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 4),
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),

            priceLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),
            priceLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            priceLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(with card: ScannedCard) {
        nameLabel.text  = card.name
        priceLabel.text = card.usdPrice.map { "$\($0)" } ?? "—"
        imageView.image = nil

        guard let url = card.imageURL else { return }
        Task {
            if let (data, _) = try? await URLSession.shared.data(from: url),
               let image = UIImage(data: data) {
                await MainActor.run {
                    self.imageView.image = image
                }
            }
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.image = nil
        nameLabel.text  = nil
        priceLabel.text = nil
    }
}
