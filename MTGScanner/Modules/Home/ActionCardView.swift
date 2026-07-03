//
//  ActionCardView.swift
//  TcgScanner
//
//  Created by Joel James on 25/06/2026.
//

import Foundation
import UIKit

final class ActionCardView: UIControl {

    private let accentColor: UIColor

    private let iconView = UIImageView()

    private let titleLabel = UILabel()

    private let subtitleLabel = UILabel()

    init(
        title: String,
        subtitle: String,
        symbol: String,
        accentColor: UIColor
    ) {

        self.accentColor = accentColor

        super.init(frame: .zero)

        translatesAutoresizingMaskIntoConstraints = false

        layer.cornerRadius = 28

        backgroundColor = UIColor.secondarySystemBackground

        layer.borderWidth = 1

        layer.borderColor =
            accentColor.withAlphaComponent(0.15).cgColor

        layer.shadowColor =
            accentColor.cgColor

        layer.shadowOpacity = 0.12

        layer.shadowRadius = 20

        layer.shadowOffset =
            CGSize(width: 0, height: 10)

        iconView.image =
            UIImage(
                systemName: symbol
            )

        iconView.tintColor =
            accentColor

        iconView.preferredSymbolConfiguration =
            UIImage.SymbolConfiguration(
                pointSize: 28,
                weight: .medium
            )

        titleLabel.text = title

        titleLabel.font =
            .systemFont(
                ofSize: 22,
                weight: .bold
            )

        subtitleLabel.text = subtitle

        subtitleLabel.font =
            .systemFont(
                ofSize: 15,
                weight: .medium
            )

        subtitleLabel.textColor =
            .secondaryLabel

        [
            iconView,
            titleLabel,
            subtitleLabel
        ].forEach {

            $0.translatesAutoresizingMaskIntoConstraints =
                false

            addSubview($0)
        }

        NSLayoutConstraint.activate([

            iconView.topAnchor.constraint(
                equalTo: topAnchor,
                constant: 24
            ),

            iconView.leadingAnchor.constraint(
                equalTo: leadingAnchor,
                constant: 24
            ),

            titleLabel.topAnchor.constraint(
                equalTo: iconView.bottomAnchor,
                constant: 16
            ),

            titleLabel.leadingAnchor.constraint(
                equalTo: iconView.leadingAnchor
            ),

            subtitleLabel.topAnchor.constraint(
                equalTo: titleLabel.bottomAnchor,
                constant: 6
            ),

            subtitleLabel.leadingAnchor.constraint(
                equalTo: titleLabel.leadingAnchor
            ),

            subtitleLabel.bottomAnchor.constraint(
                equalTo: bottomAnchor,
                constant: -24
            )
        ])
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    override var isHighlighted: Bool {
        didSet {

            UIView.animate(
                withDuration: 0.15
            ) {

                self.transform =
                    self.isHighlighted
                    ? CGAffineTransform(
                        scaleX: 0.97,
                        y: 0.97
                    )
                    : .identity
            }
        }
    }
}
