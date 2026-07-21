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

    private let summaryCard = UIView()
    private let gradientLayer = CAGradientLayer()
    private let iconContainer = UIView()
    private let iconView = UIImageView(image: UIImage(systemName: "rectangle.stack.fill"))
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let valueTitleLabel = UILabel()
    private let valueLabel = UILabel()
    private let cardsStatView = SummaryStatView(title: "Cards", symbol: "rectangle.stack")

    private lazy var sortButton = makePrimaryButton(
        title: "Sort",
        image: "arrow.up.arrow.down",
        action: #selector(sortTapped)
    )

    private lazy var filterButton = makePrimaryButton(
        title: "Filter",
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

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = summaryCard.bounds
    }

    // MARK: Configure

    func configure(
        cards: Int,
        value: Double,
        activeFilters: Int
    ) {

        let number = NumberFormatter()
        number.numberStyle = .decimal

        cardsStatView.setValue(number.string(from: NSNumber(value: cards)) ?? "0")
        valueLabel.text = PriceFormatter.string(usd: value)
    }
}

extension CollectionDashboardView {

    func setup() {
        setupSummaryCard()

        let buttonRow = UIStackView(arrangedSubviews: [
            sortButton,
            filterButton
        ])
        buttonRow.axis = .horizontal
        buttonRow.spacing = 12
        buttonRow.distribution = .fillEqually

        let stack = UIStackView(arrangedSubviews: [
            summaryCard,
            buttonRow
        ])
        stack.axis = .vertical
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16),

            summaryCard.heightAnchor.constraint(greaterThanOrEqualToConstant: 220)
        ])
    }

    func setupSummaryCard() {
        summaryCard.translatesAutoresizingMaskIntoConstraints = false
        summaryCard.layer.cornerRadius = 28
        summaryCard.layer.cornerCurve = .continuous
        summaryCard.layer.masksToBounds = true

        gradientLayer.colors = [
            UIColor.brandBlueDark.cgColor,
            UIColor.brandBlue.cgColor,
            UIColor.accentColor.cgColor
        ]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        summaryCard.layer.insertSublayer(gradientLayer, at: 0)

        iconContainer.backgroundColor = UIColor.white.withAlphaComponent(0.18)
        iconContainer.layer.cornerRadius = 18
        iconContainer.layer.cornerCurve = .continuous

        iconView.tintColor = .white
        iconView.contentMode = .scaleAspectFit
        iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(
            pointSize: 26,
            weight: .semibold
        )

        titleLabel.text = "Collection"
        titleLabel.font = .systemFont(ofSize: 30, weight: .bold)
        titleLabel.textColor = .white

        subtitleLabel.text = "Total collection value"
        subtitleLabel.font = .systemFont(ofSize: 15, weight: .medium)
        subtitleLabel.textColor = UIColor.white.withAlphaComponent(0.82)

        valueTitleLabel.text = "Value"
        valueTitleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        valueTitleLabel.textColor = UIColor.white.withAlphaComponent(0.72)

        valueLabel.font = .systemFont(ofSize: 34, weight: .bold)
        valueLabel.textColor = .white
        valueLabel.adjustsFontSizeToFitWidth = true
        valueLabel.minimumScaleFactor = 0.68
        valueLabel.numberOfLines = 1

        let titleStack = UIStackView(arrangedSubviews: [
            titleLabel,
            subtitleLabel
        ])
        titleStack.axis = .vertical
        titleStack.spacing = 4

        let topRow = UIStackView(arrangedSubviews: [
            iconContainer,
            titleStack
        ])
        topRow.axis = .horizontal
        topRow.alignment = .center
        topRow.spacing = 12

        let valueStack = UIStackView(arrangedSubviews: [
            valueTitleLabel,
            valueLabel
        ])
        valueStack.axis = .vertical
        valueStack.spacing = 2

        let statStack = UIStackView(arrangedSubviews: [cardsStatView])
        statStack.axis = .horizontal
        statStack.alignment = .center
        statStack.distribution = .fill

        let contentStack = UIStackView(arrangedSubviews: [
            topRow,
            valueStack,
            statStack
        ])
        contentStack.axis = .vertical
        contentStack.spacing = 18
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        iconView.translatesAutoresizingMaskIntoConstraints = false

        iconContainer.addSubview(iconView)
        summaryCard.addSubview(contentStack)

        NSLayoutConstraint.activate([
            iconContainer.widthAnchor.constraint(equalToConstant: 48),
            iconContainer.heightAnchor.constraint(equalToConstant: 48),

            iconView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 30),
            iconView.heightAnchor.constraint(equalToConstant: 30),

            contentStack.topAnchor.constraint(equalTo: summaryCard.topAnchor, constant: 18),
            contentStack.leadingAnchor.constraint(equalTo: summaryCard.leadingAnchor, constant: 18),
            contentStack.trailingAnchor.constraint(equalTo: summaryCard.trailingAnchor, constant: -18),
            contentStack.bottomAnchor.constraint(equalTo: summaryCard.bottomAnchor, constant: -18)
        ])

        cardsStatView.widthAnchor.constraint(
            greaterThanOrEqualTo: summaryCard.widthAnchor,
            multiplier: 0.58
        ).isActive = true
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

        filterButton.configuration?.subtitle = count == 0 ? nil : "\(count)"
    }

    func makePrimaryButton(
        title: String,
        image: String,
        action: Selector
    ) -> UIButton {

        var config = UIButton.Configuration.filled()
        config.cornerStyle = .large
        config.baseBackgroundColor = .brandBlue
        config.baseForegroundColor = .white
        config.image = UIImage(systemName: image)
        config.imagePlacement = .leading
        config.imagePadding = 10

        var titleAttr = AttributedString(title)
        titleAttr.font = .systemFont(ofSize: 17, weight: .bold)

        config.attributedTitle = titleAttr
        config.contentInsets = NSDirectionalEdgeInsets(
            top: 15,
            leading: 16,
            bottom: 15,
            trailing: 16
        )

        let button = UIButton(configuration: config)
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }
}

private final class SummaryStatView: UIView {

    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let valueLabel = UILabel()

    init(title: String, symbol: String) {
        super.init(frame: .zero)

        backgroundColor = UIColor.white.withAlphaComponent(0.16)
        layer.cornerRadius = 16
        layer.cornerCurve = .continuous

        iconView.image = UIImage(systemName: symbol)
        iconView.tintColor = .white
        iconView.contentMode = .scaleAspectFit

        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 12, weight: .medium)
        titleLabel.textColor = UIColor.white.withAlphaComponent(0.82)
        titleLabel.numberOfLines = 1
        titleLabel.setContentCompressionResistancePriority(.required, for: .vertical)

        valueLabel.text = "--"
        valueLabel.font = .systemFont(ofSize: 20, weight: .bold)
        valueLabel.textColor = .white
        valueLabel.adjustsFontSizeToFitWidth = true
        valueLabel.minimumScaleFactor = 0.7
        valueLabel.setContentCompressionResistancePriority(.required, for: .vertical)

        setupLayout()
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    func setValue(_ value: String) {
        valueLabel.text = value
    }

    private func setupLayout() {
        let textStack = UIStackView(arrangedSubviews: [
            titleLabel,
            valueLabel
        ])
        textStack.axis = .vertical
        textStack.spacing = 4
        textStack.alignment = .leading

        let stack = UIStackView(arrangedSubviews: [
            iconView,
            textStack
        ])
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false

        iconView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
            heightAnchor.constraint(greaterThanOrEqualToConstant: 66),

            iconView.widthAnchor.constraint(equalToConstant: 26),
            iconView.heightAnchor.constraint(equalToConstant: 26)
        ])
    }
}
