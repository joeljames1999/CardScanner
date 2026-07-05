//
//  CollectionDashboardView.swift
//  TcgScanner
//
//  Created by Joel James on 05/07/2026.
//

import Foundation
import UIKit

final class CollectionDashboardView: UIView {

    // MARK: Actions

    var onSearch: (() -> Void)?
    var onSort: (() -> Void)?
    var onFilter: (() -> Void)?
    var onImport: (() -> Void)?
    var onExport: (() -> Void)?

    // MARK: UI

    private let titleLabel: UILabel = {

        let label = UILabel()
        label.text = "Collection"
        label.font = .systemFont(ofSize: 34, weight: .bold)
        return label

    }()

    private let cardsLabel: UILabel = {

        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.textColor = .secondaryLabel
        return label

    }()

    private let valueLabel: UILabel = {

        let label = UILabel()
        label.font = .systemFont(ofSize: 28, weight: .bold)
        label.textColor = .systemGreen
        label.textAlignment = .right
        return label

    }()

    private lazy var searchButton = makeSearchButton()

    private lazy var sortButton = makeCapsule(
        title: "Sort",
        image: "arrow.up.arrow.down",
        action: #selector(sortTapped)
    )

    private lazy var filterButton = makeCapsule(
        title: "Filter",
        image: "line.3.horizontal.decrease.circle",
        action: #selector(filterTapped)
    )

    private lazy var exportButton = makeTextButton(
        title: "Export",
        image: "square.and.arrow.up",
        action: #selector(exportTapped)
    )

    private lazy var importButton = makeTextButton(
        title: "Import",
        image: "square.and.arrow.down",
        action: #selector(importTapped)
    )

    // MARK: Init

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .systemBackground

        layer.shadowOpacity = 0.08
        layer.shadowRadius = 12
        layer.shadowOffset = CGSize(width: 0, height: 3)

        setup()
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    // MARK: Configure

    func configure(
        cards: Int,
        value: Double
    ) {

        let number = NumberFormatter()
        number.numberStyle = .decimal

        cardsLabel.text =
            "\(number.string(from: NSNumber(value: cards)) ?? "0") cards"

        let currency = NumberFormatter()
        currency.numberStyle = .currency
        currency.currencyCode = "USD"
        
        valueLabel.text =
            currency.string(from: NSNumber(value: value))
    }
}

private extension CollectionDashboardView {

    func setup() {

        let topRow = UIStackView(arrangedSubviews: [
            titleLabel,
            UIView(),
            valueLabel
        ])

        topRow.alignment = .center

        let buttonRow = UIStackView(arrangedSubviews: [
            sortButton,
            filterButton,
            UIView(),
            exportButton,
            importButton
        ])

        
        exportButton.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        importButton.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        
        buttonRow.spacing = 8
        buttonRow.alignment = .center

        let stack = UIStackView(arrangedSubviews: [

            topRow,
            cardsLabel,
            searchButton,
            buttonRow

        ])

        stack.axis = .vertical
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stack)

        NSLayoutConstraint.activate([

            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16),

            searchButton.heightAnchor.constraint(equalToConstant: 42)
        ])
    }

    @objc func searchTapped() {
        onSearch?()
    }

    @objc func sortTapped() {
        onSort?()
    }

    @objc func filterTapped() {
        onFilter?()
    }

    @objc func exportTapped() {
        onExport?()
    }

    @objc func importTapped() {
        onImport?()
    }
}

private extension CollectionDashboardView {

    func makeSearchButton() -> UIButton {

        var config = UIButton.Configuration.gray()

        config.title = "Search Collection"
        config.image = UIImage(systemName: "magnifyingglass")
        config.imagePlacement = .leading
        config.cornerStyle = .large

        let button = UIButton(configuration: config)

        button.addTarget(
            self,
            action: #selector(searchTapped),
            for: .touchUpInside
        )

        return button
    }

    func makeCapsule(
        title: String,
        image: String,
        action: Selector
    ) -> UIButton {

        var config = UIButton.Configuration.tinted()

        config.title = title
        config.image = UIImage(systemName: image)
        config.cornerStyle = .capsule

        let button = UIButton(configuration: config)

        button.addTarget(
            self,
            action: action,
            for: .touchUpInside
        )

        return button
    }

    func makeTextButton(
        title: String,
        image: String,
        action: Selector
    ) -> UIButton {

        var config = UIButton.Configuration.plain()

        config.title = title
        config.image = UIImage(systemName: image)
        config.imagePlacement = .leading

        let button = UIButton(configuration: config)
        
        button.addTarget(
            self,
            action: action,
            for: .touchUpInside
        )

        return button
    }
}
