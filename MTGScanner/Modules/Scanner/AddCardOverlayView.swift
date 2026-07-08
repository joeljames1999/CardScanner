//
//  AddCardOverlayView.swift
//  TcgScanner
//
//  Created by Joel James on 18/06/2026.
//

import Foundation
import UIKit

struct CardAddDetails {
    let quantity: Int
    let isFoil: Bool
    let isAltered: Bool
    let language: String
}

final class AddCardOverlayView: UIView {

    // MARK: Callbacks

    var onAdd: ((CardAddDetails) -> Void)?
    var onCancel: (() -> Void)?

    // MARK: Data

    private let card: MTGCard
    private let availableLanguages: [ScannerLanguage]
    private var representedImageURL: URL?

    // MARK: State

    private var quantity = 1 {
        didSet {
            quantityLabel.text = "\(quantity)"
            minusButton.alpha = quantity == 1 ? 0.35 : 1
        }
    }

    private var selectedLanguage: ScannerLanguage {
        didSet {
            selectedLanguageLabel.text = selectedLanguage.shortName
            languageButton.accessibilityLabel = "Language: \(selectedLanguage.name)"
        }
    }

    // MARK: UI

    private let barView: UIVisualEffectView = {
        let view = UIVisualEffectView(
            effect: UIBlurEffect(style: .systemUltraThinMaterialDark)
        )
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layer.cornerRadius = 18
        view.layer.cornerCurve = .continuous
        view.clipsToBounds = true
        return view
    }()

    private let thumbnailImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 5
        imageView.backgroundColor = UIColor.white.withAlphaComponent(0.12)
        imageView.tintColor = UIColor.white.withAlphaComponent(0.7)
        imageView.image = UIImage(systemName: "photo")
        return imageView
    }()

    private lazy var minusButton = makeIconButton(
        systemName: "minus.circle.fill",
        action: #selector(decreaseQuantity),
        accessibilityLabel: "Decrease quantity"
    )

    private let quantityLabel: UILabel = {
        let label = UILabel()
        label.font = .monospacedDigitSystemFont(ofSize: 15, weight: .bold)
        label.textColor = .white
        label.textAlignment = .center
        label.text = "1"
        return label
    }()

    private lazy var plusButton = makeIconButton(
        systemName: "plus.circle.fill",
        action: #selector(increaseQuantity),
        accessibilityLabel: "Increase quantity"
    )

    private lazy var foilButton = makeToggleButton(title: "Foil")
    private lazy var alteredButton = makeToggleButton(title: "Alt")

    private let selectedLanguageLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .bold)
        label.textColor = .white
        label.textAlignment = .center
        return label
    }()

    private lazy var languageButton: UIButton = {
        var config = UIButton.Configuration.tinted()
        config.image = UIImage(systemName: "globe")
        config.imagePadding = 3
        config.baseForegroundColor = .white
        config.baseBackgroundColor = UIColor.white.withAlphaComponent(0.18)
        config.cornerStyle = .capsule
        config.contentInsets = NSDirectionalEdgeInsets(
            top: 6,
            leading: 7,
            bottom: 6,
            trailing: 7
        )

        let button = UIButton(configuration: config)
        button.addSubview(selectedLanguageLabel)
        button.showsMenuAsPrimaryAction = true
        button.menu = makeLanguageMenu()
        return button
    }()

    private lazy var addButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.image = UIImage(systemName: "checkmark")
        config.baseBackgroundColor = .systemGreen
        config.baseForegroundColor = .white
        config.cornerStyle = .capsule
        config.contentInsets = NSDirectionalEdgeInsets(
            top: 8,
            leading: 9,
            bottom: 8,
            trailing: 9
        )

        let button = UIButton(configuration: config)
        button.addTarget(
            self,
            action: #selector(addPressed),
            for: .touchUpInside
        )
        button.accessibilityLabel = "Add to session"
        return button
    }()

    private lazy var cancelButton = makeIconButton(
        systemName: "xmark.circle.fill",
        action: #selector(cancelPressed),
        accessibilityLabel: "Cancel add"
    )

    // MARK: Init

    init(
        card: MTGCard,
        availableLanguages: [ScannerLanguage],
        baseLanguage: ScannerLanguage
    ) {
        self.card = card
        self.availableLanguages = availableLanguages
        self.selectedLanguage = availableLanguages.first {
            $0.code == baseLanguage.code
        } ?? availableLanguages.first ?? baseLanguage
        super.init(frame: .zero)

        setupLayout()
        configure()
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    // MARK: Layout

    private func setupLayout() {
        backgroundColor = .clear
        addSubview(barView)

        let quantityStack = UIStackView(arrangedSubviews: [
            minusButton,
            quantityLabel,
            plusButton
        ])
        quantityStack.axis = .horizontal
        quantityStack.alignment = .center
        quantityStack.spacing = 2

        let controlsStack = UIStackView(arrangedSubviews: [
            thumbnailImageView,
            quantityStack,
            foilButton,
            alteredButton,
            languageButton,
            addButton,
            cancelButton
        ])
        controlsStack.axis = .horizontal
        controlsStack.alignment = .center
        controlsStack.spacing = 5
        controlsStack.translatesAutoresizingMaskIntoConstraints = false

        selectedLanguageLabel.translatesAutoresizingMaskIntoConstraints = false
        barView.contentView.addSubview(controlsStack)

        NSLayoutConstraint.activate([
            barView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            barView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            barView.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -12),

            controlsStack.topAnchor.constraint(equalTo: barView.contentView.topAnchor, constant: 8),
            controlsStack.leadingAnchor.constraint(equalTo: barView.contentView.leadingAnchor, constant: 8),
            controlsStack.trailingAnchor.constraint(equalTo: barView.contentView.trailingAnchor, constant: -8),
            controlsStack.bottomAnchor.constraint(equalTo: barView.contentView.bottomAnchor, constant: -8),

            thumbnailImageView.widthAnchor.constraint(equalToConstant: 34),
            thumbnailImageView.heightAnchor.constraint(equalToConstant: 48),
            quantityLabel.widthAnchor.constraint(equalToConstant: 20),
            minusButton.widthAnchor.constraint(equalToConstant: 26),
            minusButton.heightAnchor.constraint(equalToConstant: 26),
            plusButton.widthAnchor.constraint(equalToConstant: 26),
            plusButton.heightAnchor.constraint(equalToConstant: 26),
            languageButton.widthAnchor.constraint(equalToConstant: 42),
            addButton.widthAnchor.constraint(equalToConstant: 36),
            cancelButton.widthAnchor.constraint(equalToConstant: 28),
            cancelButton.heightAnchor.constraint(equalToConstant: 28),

            selectedLanguageLabel.centerXAnchor.constraint(equalTo: languageButton.centerXAnchor, constant: 7),
            selectedLanguageLabel.centerYAnchor.constraint(equalTo: languageButton.centerYAnchor),
            selectedLanguageLabel.widthAnchor.constraint(equalToConstant: 22)
        ])
    }

    private func configure() {
        minusButton.alpha = 0.35
        selectedLanguageLabel.text = selectedLanguage.shortName
        languageButton.accessibilityLabel = "Language: \(selectedLanguage.name)"
        loadThumbnail(from: card.displayImage)
    }

    private func loadThumbnail(from url: URL?) {
        representedImageURL = url

        guard let url else {
            return
        }

        Task { [weak self] in
            guard
                let (data, _) = try? await URLSession.shared.data(from: url),
                let image = UIImage(data: data),
                !Task.isCancelled
            else {
                return
            }

            await MainActor.run {
                guard self?.representedImageURL == url else {
                    return
                }

                self?.thumbnailImageView.image = image
            }
        }
    }

    // MARK: Buttons

    private func makeIconButton(
        systemName: String,
        action: Selector,
        accessibilityLabel: String
    ) -> UIButton {
        var config = UIButton.Configuration.plain()
        config.image = UIImage(systemName: systemName)
        config.baseForegroundColor = .white
        config.contentInsets = NSDirectionalEdgeInsets(
            top: 2,
            leading: 2,
            bottom: 2,
            trailing: 2
        )

        let button = UIButton(configuration: config)
        button.addTarget(self, action: action, for: .touchUpInside)
        button.accessibilityLabel = accessibilityLabel
        return button
    }

    private func makeToggleButton(title: String) -> UIButton {
        var config = UIButton.Configuration.tinted()
        config.title = title
        config.baseForegroundColor = .white
        config.baseBackgroundColor = UIColor.white.withAlphaComponent(0.14)
        config.cornerStyle = .capsule
        config.contentInsets = NSDirectionalEdgeInsets(
            top: 6,
            leading: 6,
            bottom: 6,
            trailing: 6
        )

        let button = UIButton(configuration: config)
        button.titleLabel?.font = .systemFont(ofSize: 12, weight: .semibold)
        button.addTarget(
            self,
            action: #selector(toggleButtonPressed(_:)),
            for: .touchUpInside
        )
        return button
    }

    private func makeLanguageMenu() -> UIMenu {
        UIMenu(
            title: "Language",
            children: availableLanguages.map { language in
                UIAction(
                    title: language.name,
                    state: language.code == selectedLanguage.code ? .on : .off
                ) { [weak self] _ in
                    self?.selectLanguage(language)
                }
            }
        )
    }

    private func selectLanguage(_ language: ScannerLanguage) {
        selectedLanguage = language
        languageButton.menu = makeLanguageMenu()
    }

    private func updateToggleAppearance(_ button: UIButton) {
        let isSelected = button.isSelected
        button.configuration?.baseBackgroundColor = isSelected
            ? UIColor.systemYellow.withAlphaComponent(0.9)
            : UIColor.white.withAlphaComponent(0.14)
        button.configuration?.baseForegroundColor = isSelected ? .black : .white
    }

    // MARK: Actions

    @objc
    private func increaseQuantity() {
        quantity += 1
    }

    @objc
    private func decreaseQuantity() {
        quantity = max(1, quantity - 1)
    }

    @objc
    private func toggleButtonPressed(_ sender: UIButton) {
        sender.isSelected.toggle()
        updateToggleAppearance(sender)
    }

    @objc
    private func addPressed() {
        onAdd?(
            CardAddDetails(
                quantity: quantity,
                isFoil: foilButton.isSelected,
                isAltered: alteredButton.isSelected,
                language: selectedLanguage.name
            )
        )
    }

    @objc
    private func cancelPressed() {
        onCancel?()
    }
}
