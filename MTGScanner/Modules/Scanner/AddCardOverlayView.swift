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
    let language: String
}

final class AddCardOverlayView: UIView {

    // MARK: Callbacks

    var onAdd: ((CardAddDetails) -> Void)?
    var onCancel: (() -> Void)?

    // MARK: Data

    private let card: MTGCard

    private let languages = [
        "English",
        "Japanese",
        "German",
        "French",
        "Italian",
        "Spanish",
        "Portuguese",
        "Russian",
        "Korean",
        "Chinese"
    ]

    // MARK: State

    private var quantity = 1 {
        didSet {
            quantityLabel.text = "\(quantity)"
        }
    }

    // MARK: UI

    private let dimView: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let cardView: UIView = {
        let v = UIView()
        v.backgroundColor = .systemBackground
        v.layer.cornerRadius = 20
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let nameLabel: UILabel = {
        let lbl = UILabel()
        lbl.font = .boldSystemFont(ofSize: 20)
        lbl.textAlignment = .center
        lbl.numberOfLines = 2
        lbl.translatesAutoresizingMaskIntoConstraints = false
        return lbl
    }()

    private let quantityLabel: UILabel = {
        let lbl = UILabel()
        lbl.font = .boldSystemFont(ofSize: 20)
        lbl.textAlignment = .center
        lbl.text = "1"
        lbl.translatesAutoresizingMaskIntoConstraints = false
        return lbl
    }()

    private lazy var minusButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.title = "-"
        let btn = UIButton(configuration: config)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.addTarget(
            self,
            action: #selector(decreaseQuantity),
            for: .touchUpInside
        )
        return btn
    }()

    private lazy var plusButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.title = "+"
        let btn = UIButton(configuration: config)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.addTarget(
            self,
            action: #selector(increaseQuantity),
            for: .touchUpInside
        )
        return btn
    }()

    private let foilSwitch: UISwitch = {
        let sw = UISwitch()
        sw.translatesAutoresizingMaskIntoConstraints = false
        return sw
    }()

    private lazy var languageButton: UIButton = {
        var config = UIButton.Configuration.gray()
        config.title = "English"

        let btn = UIButton(configuration: config)
        btn.translatesAutoresizingMaskIntoConstraints = false

        btn.menu = UIMenu(
            children: languages.map { language in
                UIAction(title: language) { [weak self] _ in
                    btn.configuration?.title = language
                    self?.selectedLanguage = language
                }
            }
        )

        btn.showsMenuAsPrimaryAction = true

        return btn
    }()

    private lazy var addButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.title = "Add To Session"

        let btn = UIButton(configuration: config)
        btn.translatesAutoresizingMaskIntoConstraints = false

        btn.addTarget(
            self,
            action: #selector(addPressed),
            for: .touchUpInside
        )

        return btn
    }()

    private lazy var cancelButton: UIButton = {
        var config = UIButton.Configuration.tinted()
        config.title = "Cancel"

        let btn = UIButton(configuration: config)
        btn.translatesAutoresizingMaskIntoConstraints = false

        btn.addTarget(
            self,
            action: #selector(cancelPressed),
            for: .touchUpInside
        )

        return btn
    }()

    private var selectedLanguage = "English"

    // MARK: Init

    init(card: MTGCard) {
        self.card = card
        super.init(frame: .zero)

        setupLayout()
        configure()
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    // MARK: Layout

    private func setupLayout() {

        addSubview(dimView)
        addSubview(cardView)

        NSLayoutConstraint.activate([
            dimView.leadingAnchor.constraint(equalTo: leadingAnchor),
            dimView.trailingAnchor.constraint(equalTo: trailingAnchor),
            dimView.topAnchor.constraint(equalTo: topAnchor),
            dimView.bottomAnchor.constraint(equalTo: bottomAnchor),

            cardView.centerXAnchor.constraint(equalTo: centerXAnchor),
            cardView.centerYAnchor.constraint(equalTo: centerYAnchor),
            cardView.widthAnchor.constraint(equalToConstant: 340)
        ])

        let quantityStack = UIStackView(
            arrangedSubviews: [
                minusButton,
                quantityLabel,
                plusButton
            ]
        )

        quantityStack.axis = .horizontal
        quantityStack.spacing = 12
        quantityStack.alignment = .center
        quantityStack.distribution = .equalSpacing
        
        let foilRow = UIStackView(
            arrangedSubviews: [
                UILabel.make("Foil"),
                foilSwitch
            ]
        )

        foilRow.axis = .horizontal
        foilRow.distribution = .equalSpacing

        let languageRow = UIStackView(
            arrangedSubviews: [
                UILabel.make("Language"),
                languageButton
            ]
        )

        languageRow.axis = .horizontal
        languageRow.distribution = .equalSpacing

        let stack = UIStackView(
            arrangedSubviews: [
                imageView,
                nameLabel,
                quantityStack,
                foilRow,
                languageRow,
                addButton,
                cancelButton
            ]
        )

        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false

        cardView.addSubview(stack)

        NSLayoutConstraint.activate([
            imageView.heightAnchor.constraint(equalToConstant: 180),

            stack.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -20)
        ])
    }

    // MARK: Configure

    private func configure() {

        nameLabel.text = card.name

        if let url = card.imageUris?.normal {

            Task {

                if let (data, _) = try? await URLSession.shared.data(from: url),
                   let image = UIImage(data: data) {

                    await MainActor.run {
                        self.imageView.image = image
                    }
                }
            }
        }
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
    private func addPressed() {

        onAdd?(
            CardAddDetails(
                quantity: quantity,
                isFoil: foilSwitch.isOn,
                language: selectedLanguage
            )
        )
    }

    @objc
    private func cancelPressed() {
        onCancel?()
    }
}

private extension UILabel {

    static func make(_ text: String) -> UILabel {

        let label = UILabel()
        label.text = text
        return label
    }
}
