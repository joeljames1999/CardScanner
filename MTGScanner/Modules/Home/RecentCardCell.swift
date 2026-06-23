//
//  RecentCardCell.swift
//  TcgScanner
//
//  Created by Joel James on 20/06/2026.
//

import UIKit

final class RecentCardCell: UICollectionViewCell {

    static let reuseID = "RecentCardCell"

    private let imageView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 10

        contentView.addSubview(imageView)

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    func configure(
        with card: MTGCard
    ) {

        imageView.image = nil

        guard let url = card.imageUris?.normal else {
            return
        }

        Task {

            if let (data, _) = try? await URLSession.shared.data(from: url),
               let image = UIImage(data: data) {

                await MainActor.run {
                    self.imageView.image = image
                }
            }
        }
    }
}
