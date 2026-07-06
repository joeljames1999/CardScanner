//
//  CarDetailPrintingCell.swift
//  TcgScanner
//
//  Created by Joel James on 04/07/2026.
//

import Foundation
import UIKit

final class CardDetailPrintingCell: UICollectionViewCell {

    static let reuseIdentifier = "CardDetailPrintingCell"

    private let imageView = UIImageView()

    private let setLabel = UILabel()

    private var showingBack = false
    
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
    
//    private func updateArtwork() {
//
//        let url: URL?
//
//        if showingBack {
//
//            url = card.backFace?.imageUris?.normal
//
//        } else {
//
//            url = card.displayImage
//        }
//
//        imageView.load(url)
//    }
//    
//    @objc
//    func flipCard() {
//
//        showingBack.toggle()
//
//        UIView.transition(
//            with: imageView,
//            duration: 0.35,
//            options: .transitionFlipFromLeft
//        ) {
//
//            self.updateArtwork()
//
//        }
//    }
//    
}
