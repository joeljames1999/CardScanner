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

    private let imageContainerView = UIView()
    private let cardImageView = UIImageView()

    private let quantityBadge = PaddingLabel()

    private let priceBadge = PaddingLabel()

    private let bottomInfoView = UIView()

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
        contentView.backgroundColor = UIColor(
            red: 0.055,
            green: 0.065,
            blue: 0.08,
            alpha: 1
        )

        contentView.layer.cornerRadius = 16
        contentView.layer.cornerCurve = .continuous
        contentView.layer.masksToBounds = true
        contentView.layer.borderWidth = 1
        contentView.layer.borderColor = UIColor.brandBlue.withAlphaComponent(0.5).cgColor

        layer.shadowColor = UIColor.brandBlue.cgColor
        layer.shadowOpacity = 0.16
        layer.shadowRadius = 12
        layer.shadowOffset = CGSize(width: 0, height: 5)

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

        priceBadge.text = PriceFormatter.string(usd: entry.priceValue)

        loadImage(entry.imageURL ?? card?.displayImage)

        loadSetSymbol(
            set: setCode,
            rarity: rarity
        )
    }

    // MARK: Setup

    private func configureViews() {

        imageContainerView.translatesAutoresizingMaskIntoConstraints = false
        imageContainerView.backgroundColor = .black
        imageContainerView.layer.cornerRadius = 10
        imageContainerView.layer.cornerCurve = .continuous
        imageContainerView.layer.masksToBounds = true

        cardImageView.translatesAutoresizingMaskIntoConstraints = false
        cardImageView.contentMode = .scaleAspectFill
        cardImageView.clipsToBounds = true
        cardImageView.backgroundColor = .black

        quantityBadge.translatesAutoresizingMaskIntoConstraints = false
        quantityBadge.backgroundColor = UIColor(
            red: 0.07,
            green: 0.08,
            blue: 0.1,
            alpha: 0.92
        )
        quantityBadge.textColor = .white
        quantityBadge.font = .boldSystemFont(ofSize: 12)
        quantityBadge.layer.cornerRadius = 8
        quantityBadge.clipsToBounds = true
        quantityBadge.layer.borderWidth = 1
        quantityBadge.layer.borderColor = UIColor.brandBlue.withAlphaComponent(0.75).cgColor

        priceBadge.translatesAutoresizingMaskIntoConstraints = false
        priceBadge.backgroundColor = UIColor(
            red: 0.07,
            green: 0.08,
            blue: 0.1,
            alpha: 0.92
        )
        priceBadge.textColor = .white
        priceBadge.font = .boldSystemFont(ofSize: 11)
        priceBadge.layer.cornerRadius = 8
        priceBadge.clipsToBounds = true
        priceBadge.layer.borderWidth = 1
        priceBadge.layer.borderColor = UIColor.brandBlue.withAlphaComponent(0.75).cgColor

        bottomInfoView.translatesAutoresizingMaskIntoConstraints = false
        bottomInfoView.backgroundColor = UIColor.white.withAlphaComponent(0.055)
        bottomInfoView.layer.cornerRadius = 10
        bottomInfoView.layer.cornerCurve = .continuous
        bottomInfoView.layer.borderWidth = 1
        bottomInfoView.layer.borderColor = UIColor.white.withAlphaComponent(0.08).cgColor

        setImageView.translatesAutoresizingMaskIntoConstraints = false
        setImageView.contentMode = .scaleAspectFit

        collectorLabel.translatesAutoresizingMaskIntoConstraints = false
        collectorLabel.textColor = UIColor.white.withAlphaComponent(0.88)
        collectorLabel.font = .systemFont(ofSize: 13, weight: .bold)
        collectorLabel.numberOfLines = 2
        collectorLabel.textAlignment = .left
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

        contentView.addSubview(imageContainerView)
        imageContainerView.addSubview(cardImageView)

        contentView.addSubview(quantityBadge)
        contentView.addSubview(priceBadge)

        contentView.addSubview(bottomInfoView)

        bottomInfoView.addSubview(setImageView)
        bottomInfoView.addSubview(collectorLabel)
        bottomInfoView.addSubview(foilImageView)

        NSLayoutConstraint.activate([

            imageContainerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            imageContainerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            imageContainerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            imageContainerView.bottomAnchor.constraint(equalTo: bottomInfoView.topAnchor, constant: -8),

            cardImageView.topAnchor.constraint(equalTo: imageContainerView.topAnchor),
            cardImageView.leadingAnchor.constraint(equalTo: imageContainerView.leadingAnchor),
            cardImageView.trailingAnchor.constraint(equalTo: imageContainerView.trailingAnchor),
            cardImageView.bottomAnchor.constraint(equalTo: imageContainerView.bottomAnchor),

            quantityBadge.topAnchor.constraint(equalTo: imageContainerView.topAnchor, constant: 5),
            quantityBadge.leadingAnchor.constraint(equalTo: imageContainerView.leadingAnchor, constant: 5),

            priceBadge.topAnchor.constraint(equalTo: imageContainerView.topAnchor, constant: 5),
            priceBadge.trailingAnchor.constraint(equalTo: imageContainerView.trailingAnchor, constant: -5),

            bottomInfoView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            bottomInfoView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            bottomInfoView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            bottomInfoView.heightAnchor.constraint(equalToConstant: 42),

            setImageView.leadingAnchor.constraint(equalTo: bottomInfoView.leadingAnchor, constant: 9),
            setImageView.centerYAnchor.constraint(equalTo: bottomInfoView.centerYAnchor),
            setImageView.widthAnchor.constraint(equalToConstant: 18),
            setImageView.heightAnchor.constraint(equalToConstant: 18),

            collectorLabel.leadingAnchor.constraint(equalTo: setImageView.trailingAnchor, constant: 7),
            collectorLabel.trailingAnchor.constraint(lessThanOrEqualTo: foilImageView.leadingAnchor, constant: -5),
            collectorLabel.topAnchor.constraint(greaterThanOrEqualTo: bottomInfoView.topAnchor, constant: 5),
            collectorLabel.bottomAnchor.constraint(lessThanOrEqualTo: bottomInfoView.bottomAnchor, constant: -5),
            collectorLabel.centerYAnchor.constraint(equalTo: setImageView.centerYAnchor),

            foilImageView.trailingAnchor.constraint(equalTo: bottomInfoView.trailingAnchor, constant: -9),
            foilImageView.centerYAnchor.constraint(equalTo: bottomInfoView.centerYAnchor),
            foilImageView.widthAnchor.constraint(equalToConstant: 14),
            foilImageView.heightAnchor.constraint(equalToConstant: 14)
        ])
    }

    // MARK: Image

    private func loadImage(_ url: URL?) {

        imageLoadTask?.cancel()
        representedImageURL = url
        cardImageView.image = UIImage(systemName: "photo")
        cardImageView.contentMode = .scaleAspectFit

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
                self?.cardImageView.contentMode = .scaleAspectFill
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
            return .white.withAlphaComponent(0.75)

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
