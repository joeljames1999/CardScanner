//
//  CollectionCardCell.swift
//  TcgScanner
//
//  Created by Joel James on 04/07/2026.
//

import Foundation
import UIKit

final class CollectionCardCell: UICollectionViewCell {

    static let reuseIdentifier = "CollectionCardCell"

    // MARK: UI

    private let cardImageView = UIImageView()

    private let quantityBadge = PaddingLabel()

    private let priceBadge = PaddingLabel()

    private let bottomBlur = UIVisualEffectView(
        effect: UIBlurEffect(style: .systemUltraThinMaterialLight)
    )

    private let setImageView = UIImageView()

    private let collectorLabel = UILabel()

    private let foilImageView = UIImageView()

    private var imageLoadTask: Task<Void, Never>?
    private var representedImageURL: URL?
    private var representedSetCode: String?

    // MARK: Init

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear

        contentView.layer.cornerRadius = 14
        contentView.layer.cornerCurve = .continuous
        contentView.layer.masksToBounds = true

        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.18
        layer.shadowRadius = 8
        layer.shadowOffset = CGSize(width: 0, height: 3)

        configureViews()
        layoutViews()
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        imageLoadTask?.cancel()
        imageLoadTask = nil
        representedImageURL = nil
        representedSetCode = nil
        cardImageView.image = UIImage(systemName: "photo")
        setImageView.image = nil
        foilImageView.isHidden = true
    }

    // MARK: Configure

    func configure(
        with entry: CollectionEntry,
        card: MTGCard? = nil
    ) {

        let setCode = entry.setCode.isEmpty ? card?.set ?? "" : entry.setCode
        let collectorNumber = entry.collectorNumber.isEmpty ? card?.collectorNumber ?? "" : entry.collectorNumber
        let rarity = entry.rarity == "unknown" ? card?.rarity ?? entry.rarity : entry.rarity

        collectorLabel.text = "\(setCode.uppercased()): #\(collectorNumber)"
        foilImageView.isHidden = !entry.isFoil

        quantityBadge.text = "×\(entry.count)"

        if let price = entry.purchasePrice {
            priceBadge.text = String(format: "$%.2f", price)
        } else {
            priceBadge.text = "--"
        }

        loadImage(entry.imageURL ?? card?.displayImage)

        loadSetSymbol(
            set: setCode,
            rarity: rarity
        )
    }

    // MARK: Setup

    private func configureViews() {

        cardImageView.translatesAutoresizingMaskIntoConstraints = false
        cardImageView.contentMode = .scaleAspectFit
        cardImageView.clipsToBounds = false
        cardImageView.backgroundColor = .black

        quantityBadge.translatesAutoresizingMaskIntoConstraints = false
        quantityBadge.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.9)
        quantityBadge.textColor = .white
        quantityBadge.font = .boldSystemFont(ofSize: 11)
        quantityBadge.layer.cornerRadius = 7
        quantityBadge.clipsToBounds = true

        priceBadge.translatesAutoresizingMaskIntoConstraints = false
        priceBadge.backgroundColor = UIColor.black.withAlphaComponent(0.75)
        priceBadge.textColor = .white
        priceBadge.font = .boldSystemFont(ofSize: 10)
        priceBadge.layer.cornerRadius = 7
        priceBadge.clipsToBounds = true

        bottomBlur.translatesAutoresizingMaskIntoConstraints = false

        setImageView.translatesAutoresizingMaskIntoConstraints = false
        setImageView.contentMode = .scaleAspectFit

        collectorLabel.translatesAutoresizingMaskIntoConstraints = false
        collectorLabel.textColor = .label
        collectorLabel.font = .boldSystemFont(ofSize: 12)
        collectorLabel.numberOfLines = 2
        collectorLabel.textAlignment = .center
        collectorLabel.adjustsFontSizeToFitWidth = true
        collectorLabel.minimumScaleFactor = 0.8

        foilImageView.translatesAutoresizingMaskIntoConstraints = false
        foilImageView.image = UIImage(systemName: "star.fill")
        foilImageView.contentMode = .scaleAspectFit
        foilImageView.tintColor = UIColor(
            red: 0.95,
            green: 0.72,
            blue: 0.18,
            alpha: 1
        )
        foilImageView.isHidden = true
    }

    private func layoutViews() {

        contentView.addSubview(cardImageView)

        contentView.addSubview(quantityBadge)
        contentView.addSubview(priceBadge)

        contentView.addSubview(bottomBlur)

        bottomBlur.contentView.addSubview(setImageView)
        bottomBlur.contentView.addSubview(collectorLabel)
        bottomBlur.contentView.addSubview(foilImageView)

        NSLayoutConstraint.activate([

            cardImageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            cardImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            cardImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            cardImageView.bottomAnchor.constraint(equalTo: bottomBlur.topAnchor),

            quantityBadge.topAnchor.constraint(equalTo: cardImageView.topAnchor, constant: 5),
            quantityBadge.leadingAnchor.constraint(equalTo: cardImageView.leadingAnchor, constant: 5),

            priceBadge.topAnchor.constraint(equalTo: cardImageView.topAnchor, constant: 5),
            priceBadge.trailingAnchor.constraint(equalTo: cardImageView.trailingAnchor, constant: -5),

            bottomBlur.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            bottomBlur.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            bottomBlur.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            bottomBlur.heightAnchor.constraint(equalToConstant: 36),

            setImageView.leadingAnchor.constraint(equalTo: bottomBlur.leadingAnchor, constant: 6),
            setImageView.centerYAnchor.constraint(equalTo: bottomBlur.centerYAnchor),
            setImageView.widthAnchor.constraint(equalToConstant: 14),
            setImageView.heightAnchor.constraint(equalToConstant: 14),

            collectorLabel.leadingAnchor.constraint(equalTo: setImageView.trailingAnchor, constant: 4),
            collectorLabel.trailingAnchor.constraint(lessThanOrEqualTo: foilImageView.leadingAnchor, constant: -4),
            collectorLabel.topAnchor.constraint(greaterThanOrEqualTo: bottomBlur.topAnchor, constant: 4),
            collectorLabel.bottomAnchor.constraint(lessThanOrEqualTo: bottomBlur.bottomAnchor, constant: -4),
            collectorLabel.centerYAnchor.constraint(equalTo: setImageView.centerYAnchor),

            foilImageView.trailingAnchor.constraint(equalTo: bottomBlur.trailingAnchor, constant: -6),
            foilImageView.centerYAnchor.constraint(equalTo: bottomBlur.centerYAnchor),
            foilImageView.widthAnchor.constraint(equalToConstant: 14),
            foilImageView.heightAnchor.constraint(equalToConstant: 14)
        ])
    }

    // MARK: Image

    private func loadImage(_ url: URL?) {

        imageLoadTask?.cancel()
        representedImageURL = url
        cardImageView.image = UIImage(systemName: "photo")

        guard let url else {
            return
        }

        imageLoadTask = Task { [weak self] in

            guard
                let image = await ImageLoader.shared.image(for: url),
                !Task.isCancelled
            else { return }

            await MainActor.run {
                guard self?.representedImageURL == url else {
                    return
                }

                self?.cardImageView.image = image
                self?.imageLoadTask = nil
            }
        }
    }

    // MARK: Set Symbol

    private func loadSetSymbol(
        set: String,
        rarity: String
    ) {

        let representedSetCode = set.lowercased()
        self.representedSetCode = representedSetCode
        setImageView.image = nil

        SetSymbolService.shared.image(for: set) { [weak self] image in

            guard
                let self,
                self.representedSetCode == representedSetCode
            else { return }

            self.setImageView.image = image?.withRenderingMode(.alwaysTemplate)
            self.setImageView.tintColor = self.rarityColor(rarity)
        }
    }

    private func rarityColor(
        _ rarity: String
    ) -> UIColor {

        switch rarity.lowercased() {

        case "common":
            return .black

        case "uncommon":
            return UIColor(
                red: 0.75,
                green: 0.75,
                blue: 0.75,
                alpha: 1
            )

        case "rare":
            return UIColor(
                red: 0.86,
                green: 0.65,
                blue: 0.13,
                alpha: 1
            )

        case "mythic", "mythic rare":
            return UIColor(
                red: 0.92,
                green: 0.36,
                blue: 0.08,
                alpha: 1
            )

        case "special":
            return UIColor.systemPurple

        case "bonus":
            return UIColor.systemTeal

        default:
            return .white
        }
    }
}
