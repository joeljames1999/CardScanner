<<<<<<< HEAD
import UIKit

// MARK: - CardConfirmationViewController
// Shown as a medium sheet after Gemini identifies a card.
// User sees card image + details and can confirm or dismiss.

final class CardConfirmationViewController: UIViewController {

    // MARK: - Properties

    private let card: MTGCard
    var onConfirm: (() -> Void)?
    var onDismiss: (() -> Void)?

    // MARK: - UI

    private lazy var cardImageView: UIImageView = {
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.contentMode        = .scaleAspectFit
        iv.layer.cornerRadius = 12
        iv.clipsToBounds      = true
        iv.backgroundColor    = .secondarySystemBackground
        return iv
    }()

    private lazy var nameLabel: UILabel = {
        let lbl = UILabel()
        lbl.font          = .systemFont(ofSize: 20, weight: .bold)
        lbl.numberOfLines = 2
        lbl.textAlignment = .center
        return lbl
    }()

    private lazy var subtitleLabel: UILabel = {
        let lbl = UILabel()
        lbl.font          = .systemFont(ofSize: 14)
        lbl.textColor     = .secondaryLabel
        lbl.textAlignment = .center
        lbl.numberOfLines = 2
        return lbl
    }()

    private lazy var priceLabel: UILabel = {
        let lbl = UILabel()
        lbl.font          = .systemFont(ofSize: 16, weight: .semibold)
        lbl.textColor     = .systemGreen
        lbl.textAlignment = .center
        return lbl
    }()

    private lazy var addButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.title            = "Add to Session"
        config.image            = UIImage(systemName: "plus.circle.fill")
        config.imagePadding     = 8
        config.cornerStyle      = .capsule
        config.baseBackgroundColor = .systemBlue
        let btn = UIButton(configuration: config)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.addTarget(self, action: #selector(addTapped), for: .touchUpInside)
        return btn
    }()

    private lazy var notThisCardButton: UIButton = {
        var config = UIButton.Configuration.plain()
        config.title      = "Not this card"
        config.cornerStyle = .capsule
        let btn = UIButton(configuration: config)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.addTarget(self, action: #selector(dismissTapped), for: .touchUpInside)
        return btn
    }()

    private lazy var viewDetailsButton: UIButton = {
        var config = UIButton.Configuration.tinted()
        config.title       = "View Full Details"
        config.image       = UIImage(systemName: "info.circle")
        config.imagePadding = 6
        config.cornerStyle  = .capsule
        let btn = UIButton(configuration: config)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.addTarget(self, action: #selector(viewDetailsTapped), for: .touchUpInside)
        return btn
    }()

    // MARK: - Init

    init(card: MTGCard) {
        self.card = card
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        navigationItem.title = "Card Found"
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            systemItem: .close,
            primaryAction: UIAction { [weak self] _ in
                self?.dismissTapped()
            }
        )

        setupLayout()
        populateData()
        loadImage()
    }

    // MARK: - Layout

    private func setupLayout() {
        let textStack = UIStackView(arrangedSubviews: [nameLabel, subtitleLabel, priceLabel])
        textStack.axis      = .vertical
        textStack.spacing   = 6
        textStack.alignment = .center
        textStack.translatesAutoresizingMaskIntoConstraints = false

        let buttonStack = UIStackView(arrangedSubviews: [addButton, viewDetailsButton, notThisCardButton])
        buttonStack.axis      = .vertical
        buttonStack.spacing   = 10
        buttonStack.alignment = .fill
        buttonStack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(cardImageView)
        view.addSubview(textStack)
        view.addSubview(buttonStack)

        let p: CGFloat = 24

        NSLayoutConstraint.activate([
            cardImageView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: p),
            cardImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            cardImageView.widthAnchor.constraint(equalToConstant: 110),
            cardImageView.heightAnchor.constraint(equalTo: cardImageView.widthAnchor, multiplier: 88.0 / 63.0),

            textStack.topAnchor.constraint(equalTo: cardImageView.bottomAnchor, constant: 16),
            textStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: p),
            textStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -p),

            buttonStack.topAnchor.constraint(equalTo: textStack.bottomAnchor, constant: 24),
            buttonStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: p),
            buttonStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -p),

            addButton.heightAnchor.constraint(equalToConstant: 50),
            viewDetailsButton.heightAnchor.constraint(equalToConstant: 44),
        ])
    }

    // MARK: - Data

    private func populateData() {
        nameLabel.text = card.name

        var subtitleParts: [String] = [card.setName]
        if let mana = card.manaCost, !mana.isEmpty { subtitleParts.append(mana) }
        subtitleParts.append(card.typeLine)
        subtitleLabel.text = subtitleParts.joined(separator: " · ")

        if let usd = card.prices?.usd {
            priceLabel.text = "$\(usd)"
        } else {
            priceLabel.text = "Price unavailable"
            priceLabel.textColor = .secondaryLabel
        }
    }

    private func loadImage() {
        guard let url = card.imageUris?.normal else { return }
        Task {
            if let (data, _) = try? await URLSession.shared.data(from: url),
               let image = UIImage(data: data) {
                await MainActor.run {
                    UIView.transition(with: self.cardImageView, duration: 0.2, options: .transitionCrossDissolve) {
                        self.cardImageView.image = image
                    }
                }
            }
        }
    }

    // MARK: - Actions

    @objc private func addTapped() {
        onConfirm?()
    }

    @objc private func dismissTapped() {
        onDismiss?()
    }

    @objc private func viewDetailsTapped() {
        let detailVC = CardDetailViewController(card: card)
        detailVC.onDismiss = { [weak self] in
            // After viewing details, still let them add or dismiss
        }
        navigationController?.pushViewController(detailVC, animated: true)
    }
}
=======
//
//  CardConfirmationViewController.swift
//  TcgScanner
//
//  Created by Joel James on 21/04/2026.
//

import Foundation
>>>>>>> 7d67abed8899bd6b484c1167ed5531a4fe6a2be0
