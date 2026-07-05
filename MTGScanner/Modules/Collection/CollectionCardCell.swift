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
        effect: UIBlurEffect(style: .systemUltraThinMaterialDark)
    )

    private let setImageView = UIImageView()

    private let collectorLabel = UILabel()

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

    // MARK: Configure

    func configure(with entry: CollectionEntry) {

        collectorLabel.text = "\(entry.setCode) #\(entry.collectorNumber)"

        quantityBadge.text = "×\(entry.count)"

        if let price = entry.purchasePrice {
            priceBadge.text = String(format: "$%.2f", price)
        } else {
            priceBadge.text = "--"
        }

        loadImage(entry.imageURL)

        loadSetSymbol(
            set: entry.setCode,
            rarity: entry.rarity
        )
    }

    // MARK: Setup

    private func configureViews() {

        cardImageView.translatesAutoresizingMaskIntoConstraints = false
        cardImageView.contentMode = .scaleAspectFill
        cardImageView.clipsToBounds = true

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
        collectorLabel.textColor = .white
        collectorLabel.font = .boldSystemFont(ofSize: 12)
        collectorLabel.numberOfLines = 2
        collectorLabel.textAlignment = .center
        collectorLabel.adjustsFontSizeToFitWidth = true
        collectorLabel.minimumScaleFactor = 0.8
    }

    private func layoutViews() {

        contentView.addSubview(cardImageView)

        contentView.addSubview(quantityBadge)
        contentView.addSubview(priceBadge)

        contentView.addSubview(bottomBlur)

        bottomBlur.contentView.addSubview(setImageView)
        bottomBlur.contentView.addSubview(collectorLabel)

        NSLayoutConstraint.activate([

            cardImageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            cardImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            cardImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            cardImageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            quantityBadge.bottomAnchor.constraint(equalTo: collectorLabel.topAnchor, constant: -10),
            quantityBadge.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 5),

            priceBadge.bottomAnchor.constraint(equalTo: collectorLabel.topAnchor, constant: -10),
            priceBadge.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -5),

            bottomBlur.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            bottomBlur.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            bottomBlur.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            bottomBlur.heightAnchor.constraint(equalToConstant: 36),

            setImageView.leadingAnchor.constraint(equalTo: bottomBlur.leadingAnchor, constant: 6),
            setImageView.centerYAnchor.constraint(equalTo: bottomBlur.centerYAnchor),
            setImageView.widthAnchor.constraint(equalToConstant: 14),
            setImageView.heightAnchor.constraint(equalToConstant: 14),

            collectorLabel.leadingAnchor.constraint(equalTo: setImageView.trailingAnchor, constant: 4),
            collectorLabel.trailingAnchor.constraint(lessThanOrEqualTo: bottomBlur.trailingAnchor, constant: -6),
            collectorLabel.centerYAnchor.constraint(equalTo: setImageView.centerYAnchor)
        ])
    }

    // MARK: Image

    private func loadImage(_ url: URL?) {

        cardImageView.image = UIImage(systemName: "photo")

        guard let url else {
            return
        }

        Task {

            guard
                let (data, _) = try? await URLSession.shared.data(from: url),
                let image = UIImage(data: data)
            else { return }

            await MainActor.run {
                self.cardImageView.image = image
            }
        }
    }

    // MARK: Set Symbol

    private func loadSetSymbol(
        set: String,
        rarity: String
    ) {

        SetSymbolService.shared.image(for: set) { [weak self] image in

            guard let self else { return }

            self.setImageView.image = image?.withRenderingMode(.alwaysTemplate)
            self.setImageView.tintColor = self.rarityColor(rarity)
        }
    }

    private func rarityColor(
        _ rarity: String
    ) -> UIColor {

        switch rarity.lowercased() {

        case "common":
            return .lightGray

        case "uncommon":
            return UIColor(
                red: 0.72,
                green: 0.72,
                blue: 0.72,
                alpha: 1
            )

        case "rare":
            return UIColor.systemYellow

        case "mythic":
            return UIColor.systemOrange

        case "special":
            return UIColor.systemPurple

        case "bonus":
            return UIColor.systemTeal

        default:
            return .white
        }
    }
}
