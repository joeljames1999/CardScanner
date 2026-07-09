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

    private let iconContainer = UIView()
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let actionPill = UIButton(type: .system)
    private let usesIconOnlyPill: Bool

    init(
        title: String,
        subtitle: String,
        symbol: String,
        actionTitle: String = "",
        accentColor: UIColor
    ) {

        self.accentColor = accentColor
        self.usesIconOnlyPill = actionTitle.count > 5

        super.init(frame: .zero)

        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = accentColor
        layer.cornerRadius = 24
        layer.cornerCurve = .continuous
        layer.shadowColor = accentColor.cgColor
        layer.shadowOpacity = 0.18
        layer.shadowRadius = 18
        layer.shadowOffset = CGSize(width: 0, height: 8)
        isAccessibilityElement = true
        accessibilityTraits = .button
        accessibilityLabel = title
        accessibilityHint = subtitle

        iconContainer.backgroundColor = UIColor.white.withAlphaComponent(0.18)
        iconContainer.layer.cornerRadius = 18
        iconContainer.layer.cornerCurve = .continuous

        iconView.image = UIImage(systemName: symbol)
        iconView.tintColor = .white
        iconView.contentMode = .scaleAspectFit
        iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(
            pointSize: 24,
            weight: .semibold
        )

        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 19, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.numberOfLines = 2
        titleLabel.lineBreakMode = .byWordWrapping
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.82

        subtitleLabel.text = subtitle
        subtitleLabel.font = .systemFont(ofSize: 14, weight: .medium)
        subtitleLabel.textColor = UIColor.white.withAlphaComponent(0.78)
        subtitleLabel.numberOfLines = 2

        configureActionPill(title: actionTitle)
        setupLayout()
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.15) {
                self.transform = self.isHighlighted
                    ? CGAffineTransform(scaleX: 0.97, y: 0.97)
                    : .identity
            }
        }
    }

    private func configureActionPill(title: String) {
        var config = UIButton.Configuration.filled()

        if !usesIconOnlyPill {
            var titleText = AttributedString(title)
            titleText.font = .systemFont(ofSize: 16, weight: .semibold)
            config.attributedTitle = titleText
        }

        config.image = UIImage(systemName: "arrow.right")
        config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(
            pointSize: 18,
            weight: .semibold
        )
        config.imagePlacement = .trailing
        config.imagePadding = usesIconOnlyPill ? 0 : 6
        config.cornerStyle = .capsule
        config.baseBackgroundColor = .white
        config.baseForegroundColor = accentColor
        config.contentInsets = usesIconOnlyPill
            ? NSDirectionalEdgeInsets(top: 9, leading: 14, bottom: 9, trailing: 14)
            : NSDirectionalEdgeInsets(top: 9, leading: 12, bottom: 9, trailing: 12)

        actionPill.configuration = config
        actionPill.titleLabel?.numberOfLines = 1
        actionPill.titleLabel?.adjustsFontSizeToFitWidth = true
        actionPill.titleLabel?.minimumScaleFactor = 0.5
        actionPill.isUserInteractionEnabled = false
        actionPill.isAccessibilityElement = false
    }

    private func setupLayout() {
        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        iconView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        actionPill.translatesAutoresizingMaskIntoConstraints = false

        iconContainer.addSubview(iconView)

        let textStack = UIStackView(arrangedSubviews: [
            titleLabel,
            subtitleLabel
        ])
        textStack.axis = .vertical
        textStack.spacing = 4
        textStack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(iconContainer)
        addSubview(textStack)
        addSubview(actionPill)

        NSLayoutConstraint.activate([
            iconContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),
            iconContainer.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconContainer.widthAnchor.constraint(equalToConstant: 48),
            iconContainer.heightAnchor.constraint(equalToConstant: 48),

            iconView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 28),
            iconView.heightAnchor.constraint(equalToConstant: 28),

            textStack.leadingAnchor.constraint(equalTo: iconContainer.trailingAnchor, constant: 14),
            textStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            textStack.trailingAnchor.constraint(lessThanOrEqualTo: actionPill.leadingAnchor, constant: -12),

            actionPill.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            actionPill.centerYAnchor.constraint(equalTo: centerYAnchor),
            actionPill.widthAnchor.constraint(equalToConstant: 56), // if adding text change to 144
            actionPill.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
}
