import UIKit

final class CardDetailPrintingCell: UICollectionViewCell {

    static let reuseIdentifier = "CardDetailPrintingCell"

    private let imageView = UIImageView()

    private let setLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)

        contentView.layer.cornerRadius = 10
        contentView.clipsToBounds = true

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit

        setLabel.translatesAutoresizingMaskIntoConstraints = false
        setLabel.font = .systemFont(
            ofSize: 12,
            weight: .medium
        )
        setLabel.textAlignment = .center
        setLabel.numberOfLines = 2

        contentView.addSubview(imageView)
        contentView.addSubview(setLabel)

        NSLayoutConstraint.activate([

            imageView.topAnchor.constraint(
                equalTo: contentView.topAnchor
            ),

            imageView.leadingAnchor.constraint(
                equalTo: contentView.leadingAnchor
            ),

            imageView.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor
            ),

            imageView.heightAnchor.constraint(
                equalToConstant: 140
            ),

            setLabel.topAnchor.constraint(
                equalTo: imageView.bottomAnchor,
                constant: 4
            ),

            setLabel.leadingAnchor.constraint(
                equalTo: contentView.leadingAnchor
            ),

            setLabel.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor
            )
        ])
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    func configure(with card: MTGCard) {

        setLabel.text =
        "\(card.set.uppercased()) #\(card.collectorNumber)"

        imageView.image = nil

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
                self.imageView.image = image
            }
        }
    }
}
