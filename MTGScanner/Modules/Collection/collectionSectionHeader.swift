//
//  collectionSectionHeader.swift
//  TcgScanner
//
//  Created by Joel James on 04/07/2026.
//

import Foundation
import UIKit

final class CollectionSectionHeader: UICollectionReusableView {

    static let reuseIdentifier = "CollectionSectionHeader"

    // MARK: Callbacks

    var onImport: (() -> Void)?
    var onExport: (() -> Void)?
    var onSort: (() -> Void)?
    var onFilter: (() -> Void)?

    // MARK: UI

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 32, weight: .bold)
        label.text = "Collection"
        return label
    }()

    private let countLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.textColor = .secondaryLabel
        return label
    }()

    private lazy var filterButton = makeCapsuleButton(
        title: "All",
        image: "line.3.horizontal.decrease"
    )

    private lazy var sortButton = makeCapsuleButton(
        title: "Sort",
        image: "arrow.up.arrow.down"
    )

    private lazy var exportButton = makeIconButton(
        "square.and.arrow.up",
        selector: #selector(exportTapped)
    )

    private lazy var importButton = makeIconButton(
        "square.and.arrow.down",
        selector: #selector(importTapped)
    )

    // MARK: Init

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .systemBackground

        addSubview(titleLabel)
        addSubview(countLabel)
        addSubview(filterButton)
        addSubview(sortButton)
        addSubview(exportButton)
        addSubview(importButton)

        [
            titleLabel,
            countLabel,
            filterButton,
            sortButton,
            exportButton,
            importButton
        ].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        NSLayoutConstraint.activate([

            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),

            countLabel.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            countLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),

            filterButton.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 18),
            filterButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            filterButton.heightAnchor.constraint(equalToConstant: 36),

            sortButton.centerYAnchor.constraint(equalTo: filterButton.centerYAnchor),
            sortButton.leadingAnchor.constraint(equalTo: filterButton.trailingAnchor, constant: 10),
            sortButton.heightAnchor.constraint(equalToConstant: 36),

            importButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            importButton.centerYAnchor.constraint(equalTo: filterButton.centerYAnchor),

            exportButton.trailingAnchor.constraint(equalTo: importButton.leadingAnchor, constant: -12),
            exportButton.centerYAnchor.constraint(equalTo: filterButton.centerYAnchor),

            bottomAnchor.constraint(equalTo: filterButton.bottomAnchor, constant: 14)
        ])

        filterButton.addTarget(
            self,
            action: #selector(filterTapped),
            for: .touchUpInside
        )

        sortButton.addTarget(
            self,
            action: #selector(sortTapped),
            for: .touchUpInside
        )
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    // MARK: Configure

    func configure(cardCount: Int) {

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal

        countLabel.text =
            "\(formatter.string(from: NSNumber(value: cardCount)) ?? "\(cardCount)") cards"
    }

    // MARK: Actions

    @objc
    private func filterTapped() {
        onFilter?()
    }

    @objc
    private func sortTapped() {
        onSort?()
    }

    @objc
    private func exportTapped() {
        onExport?()
    }

    @objc
    private func importTapped() {
        onImport?()
    }
}

private extension CollectionSectionHeader {

    func makeCapsuleButton(
        title: String,
        image: String
    ) -> UIButton {

        var config = UIButton.Configuration.gray()

        config.title = title
        config.image = UIImage(systemName: image)
        config.imagePlacement = .leading
        config.imagePadding = 6
        config.cornerStyle = .capsule

        return UIButton(configuration: config)
    }

    func makeIconButton(
        _ image: String,
        selector: Selector
    ) -> UIButton {

        var config = UIButton.Configuration.plain()

        config.image = UIImage(systemName: image)

        let button = UIButton(configuration: config)

        button.addTarget(
            self,
            action: selector,
            for: .touchUpInside
        )

        return button
    }
}
