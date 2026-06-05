import UIKit

final class CardSearchCell: UICollectionViewCell {

    static let reuseIdentifier = "CardSearchCell"

    private let imageView: UIImageView = {

        let iv = UIImageView()

        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.contentMode = .scaleAspectFit
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 12

        return iv
    }()

    private let nameLabel: UILabel = {

        let lbl = UILabel()

        lbl.translatesAutoresizingMaskIntoConstraints = false
        lbl.font = .systemFont(
            ofSize: 13,
            weight: .medium
        )

        lbl.numberOfLines = 2
        lbl.textAlignment = .center

        return lbl
    }()

    private var imageTask: URLSessionDataTask?

    override init(frame: CGRect) {
        super.init(frame: frame)

        contentView.addSubview(imageView)
        contentView.addSubview(nameLabel)

        NSLayoutConstraint.activate([

            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),

            imageView.heightAnchor.constraint(
                equalTo: imageView.widthAnchor,
                multiplier: 1.4
            ),

            nameLabel.topAnchor.constraint(
                equalTo: imageView.bottomAnchor,
                constant: 6
            ),

            nameLabel.leadingAnchor.constraint(
                equalTo: contentView.leadingAnchor
            ),

            nameLabel.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor
            ),

            nameLabel.bottomAnchor.constraint(
                lessThanOrEqualTo: contentView.bottomAnchor
            )
        ])
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        imageTask?.cancel()

        imageView.image = nil
        nameLabel.text = nil
    }

    func configure(with card: MTGCard) {

        nameLabel.text = card.name + " - " + card.set

        guard let url = card.imageUris?.normal else {
            return
        }

        imageTask = URLSession.shared.dataTask(
            with: url
        ) { [weak self] data, _, _ in

            guard
                let self,
                let data,
                let image = UIImage(data: data)
            else {
                return
            }

            DispatchQueue.main.async {
                self.imageView.image = image
            }
        }

        imageTask?.resume()
    }
}
