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
    private var imageLoadTask: Task<Void, Never>?
    private var representedImageURL: URL?

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

    override func prepareForReuse() {
        super.prepareForReuse()

        imageLoadTask?.cancel()
        imageLoadTask = nil
        representedImageURL = nil
        imageView.image = nil
    }

    func configure(
        with card: RecentCard
    ) {
        loadImage(card.imageURL)
    }

    private func loadImage(_ url: URL?) {
        imageLoadTask?.cancel()
        representedImageURL = url
        imageView.image = nil

        guard let url else {
            return
        }

        imageLoadTask = Task { [weak self] in

            guard
                let (data, _) = try? await URLSession.shared.data(from: url),
                !Task.isCancelled,
                let image = UIImage(data: data)
            else { return }

            await MainActor.run {
                guard self?.representedImageURL == url else {
                    return
                }

                self?.imageView.image = image
                self?.imageLoadTask = nil
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
