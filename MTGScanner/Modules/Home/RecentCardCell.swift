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
        
        layer.cornerRadius = 14

        layer.shadowOpacity = 0.15

        layer.shadowRadius = 12

        layer.shadowOffset =
            CGSize(width: 0, height: 6)
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
    
    override var isHighlighted: Bool {

        didSet {

            UIView.animate(
                withDuration: 0.15
            ) {

                self.transform =
                    self.isHighlighted
                    ? CGAffineTransform(
                        scaleX: 0.95,
                        y: 0.95
                      )
                    : .identity
            }
        }
    }
    
}
