//
//  CollectionEmptyStateView.swift
//  TcgScanner
//
//  Created by Joel James on 06/07/2026.
//

import Foundation
import UIKit

final class CollectionEmptyStateView: UIView {

    // MARK: - Actions

    var onScan: (() -> Void)?
    var onImport: (() -> Void)?

    // MARK: - UI

    private let imageView: UIImageView = {

        let imageView = UIImageView(
            image: UIImage(systemName: "square.stack.3d.up")
        )

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.tintColor = .brandBlue
        imageView.preferredSymbolConfiguration = .init(
            pointSize: 56,
            weight: .light
        )

        return imageView
    }()

    private let titleLabel: UILabel = {

        let label = UILabel()

        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(
            ofSize: 26,
            weight: .bold
        )

        label.textAlignment = .center
        label.text = "Your collection is empty"

        return label
    }()

    private let subtitleLabel: UILabel = {

        let label = UILabel()

        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 16)
        label.textColor = .secondaryLabel

        label.text =
        """
        Scan your first Magic card or import
        an existing collection to get started.
        """

        return label
    }()

    private lazy var scanButton: UIButton = {

        var config = UIButton.Configuration.filled()

        config.title = "Scan Cards"
        config.image = UIImage(systemName: "camera.viewfinder")
        config.imagePadding = 8
        config.cornerStyle = .capsule
        config.baseBackgroundColor = .brandBlue

        let button = UIButton(configuration: config)

        button.addTarget(
            self,
            action: #selector(scanTapped),
            for: .touchUpInside
        )

        return button
    }()

    private lazy var importButton: UIButton = {

        var config = UIButton.Configuration.tinted()

        config.title = "Import CSV"
        config.image = UIImage(systemName: "square.and.arrow.down")
        config.imagePadding = 8
        config.cornerStyle = .capsule
        config.baseForegroundColor = .brandBlue

        let button = UIButton(configuration: config)

        button.addTarget(
            self,
            action: #selector(importTapped),
            for: .touchUpInside
        )

        return button
    }()

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)

        translatesAutoresizingMaskIntoConstraints = false

        setup()
    }

    required init?(coder: NSCoder) {
        fatalError()
    }
}

// MARK: - Layout

private extension CollectionEmptyStateView {

    func setup() {

        let buttonStack = UIStackView(arrangedSubviews: [
            scanButton,
            importButton
        ])

        buttonStack.axis = .horizontal
        buttonStack.spacing = 12
        buttonStack.distribution = .fillEqually

        let stack = UIStackView(arrangedSubviews: [

            imageView,
            titleLabel,
            subtitleLabel,
            buttonStack

        ])

        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 18
        stack.alignment = .center

        addSubview(stack)

        NSLayoutConstraint.activate([

            imageView.heightAnchor.constraint(equalToConstant: 60),
            imageView.widthAnchor.constraint(equalToConstant: 60),

            scanButton.heightAnchor.constraint(equalToConstant: 44),
            importButton.heightAnchor.constraint(equalToConstant: 44),

            buttonStack.widthAnchor.constraint(equalToConstant: 260),

            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),

            stack.leadingAnchor.constraint(
                greaterThanOrEqualTo: leadingAnchor,
                constant: 24
            ),

            stack.trailingAnchor.constraint(
                lessThanOrEqualTo: trailingAnchor,
                constant: -24
            )
        ])
    }
}

final class CollectionFilteredEmptyStateView: UIView {

    private let imageView: UIImageView = {
        let imageView = UIImageView(image: UIImage(systemName: "line.3.horizontal.decrease.circle"))
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.tintColor = .secondaryLabel
        imageView.preferredSymbolConfiguration = .init(pointSize: 42, weight: .regular)
        return imageView
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 22, weight: .semibold)
        label.textAlignment = .center
        label.text = "No cards match these filters"
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 15)
        label.textColor = .secondaryLabel
        label.text = "Adjust your search or filters to show cards from your collection."
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isHidden = true
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    private func setup() {
        backgroundColor = .systemBackground

        let stack = UIStackView(arrangedSubviews: [
            imageView,
            titleLabel,
            subtitleLabel
        ])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 14
        stack.alignment = .center

        addSubview(stack)

        NSLayoutConstraint.activate([
            imageView.heightAnchor.constraint(equalToConstant: 46),
            imageView.widthAnchor.constraint(equalToConstant: 46),

            stack.topAnchor.constraint(equalTo: topAnchor, constant: 42),
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -28)
        ])
    }
}

// MARK: - Actions

private extension CollectionEmptyStateView {

    @objc
    func scanTapped() {
        onScan?()
    }

    @objc
    func importTapped() {
        onImport?()
    }
}
