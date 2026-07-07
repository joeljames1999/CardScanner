//
//  CollectionDashboardView.swift
//  TcgScanner
//
//  Created by Joel James on 05/07/2026.
//

import Foundation
import UIKit

final class CollectionDashboardView: UIView {

    // MARK: - Actions

    var onSort: (() -> Void)?
    var onFilter: (() -> Void)?

    // MARK: - UI

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Collection"
        label.font = .systemFont(ofSize: 36, weight: .bold)
        return label
    }()

    private let cardsLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 17, weight: .medium)
        label.textColor = .secondaryLabel
        return label
    }()

    private let valueLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 32, weight: .bold)
        label.textColor = .brandBlue
        label.textAlignment = .right
        return label
    }()

    private lazy var sortButton = makePrimaryButton(
        title: "Sort",
        subtitle: "Organise collection",
        image: "arrow.up.arrow.down",
        action: #selector(sortTapped)
    )

    private lazy var filterButton = makePrimaryButton(
        title: "Filter",
        subtitle: "Refine results",
        image: "line.3.horizontal.decrease.circle",
        action: #selector(filterTapped)
    )

    // MARK: Init

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .systemBackground

        setup()
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    // MARK: Configure
    func configure(
        cards: Int,
        value: Double,
        activeFilters: Int
    ){

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

extension CollectionDashboardView {
    
    func setup() {
        
        let topRow = UIStackView(arrangedSubviews: [
            titleLabel,
            UIView(),
            valueLabel
        ])
        
        topRow.alignment = .bottom
        
        let buttonRow = UIStackView(arrangedSubviews: [
            sortButton,
            filterButton
        ])
        
        buttonRow.axis = .horizontal
        buttonRow.spacing = 12
        buttonRow.distribution = .fillEqually
        
        let stack = UIStackView(arrangedSubviews: [
            topRow,
            cardsLabel,
            buttonRow
        ])
        
        stack.axis = .vertical
        stack.spacing = 18
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(stack)
        
        NSLayoutConstraint.activate([
            
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 18),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -18)
            
        ])
    }
    
    @objc
    func sortTapped() {
        onSort?()
    }
    
    @objc
    func filterTapped() {
        onFilter?()
    }
    
    func updateFilterBadge(_ filter: SearchFilter) {
        
        let count =
        filter.selectedSets.count +
        filter.selectedRarities.count +
        filter.selectedManaCosts.count +
        filter.selectedManaColors.count
        
        if count == 0 {
            
            filterButton.configuration?.subtitle = nil
            
        } else {
            
            filterButton.configuration?.subtitle = "\(count)"
        }
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

private extension CollectionDashboardView {

    func makePrimaryButton(
        title: String,
        subtitle: String,
        image: String,
        action: Selector
    ) -> UIButton {

        var config = UIButton.Configuration.filled()

        config.cornerStyle = .large
        config.baseBackgroundColor = .brandBlue
        config.baseForegroundColor = .white

        config.image = UIImage(systemName: image)
        config.imagePlacement = .leading
        config.imagePadding = 12

        var titleAttr = AttributedString(title)
        titleAttr.font = .systemFont(ofSize: 18, weight: .bold)

        var subtitleAttr = AttributedString(subtitle)
        subtitleAttr.font = .systemFont(ofSize: 13)
        subtitleAttr.foregroundColor = .white.withAlphaComponent(0.85)

        config.attributedTitle = titleAttr
        config.attributedSubtitle = subtitleAttr

        config.contentInsets = NSDirectionalEdgeInsets(
            top: 18,
            leading: 18,
            bottom: 18,
            trailing: 18
        )

        let button = UIButton(configuration: config)

        button.addTarget(
            self,
            action: action,
            for: .touchUpInside
        )

        return button
    }
}
