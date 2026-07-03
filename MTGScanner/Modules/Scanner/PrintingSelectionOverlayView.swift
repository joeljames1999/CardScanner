//
//  PrintingSelectionOverlayView.swift
//  TcgScanner
//
//  Created by Joel James on 18/06/2026.
//

import UIKit

final class PrintingSelectionOverlayView: UIView {

    // MARK: - Callbacks

    var onSelect: ((MTGCard) -> Void)?
    var onCancel: (() -> Void)?

    // MARK: - Properties

    private let printings: [MTGCard]

    // MARK: - UI

    private let dimView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.65)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemBackground
        view.layer.cornerRadius = 24
        view.layer.maskedCorners = [
            .layerMinXMinYCorner,
            .layerMaxXMinYCorner
        ]
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Select Printing"
        label.font = .systemFont(
            ofSize: 22,
            weight: .bold
        )
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var closeButton: UIButton = {
        let button = UIButton(type: .system)

        button.setImage(
            UIImage(systemName: "xmark.circle.fill"),
            for: .normal
        )

        button.tintColor = .secondaryLabel

        button.addTarget(
            self,
            action: #selector(cancelTapped),
            for: .touchUpInside
        )

        button.translatesAutoresizingMaskIntoConstraints = false

        return button
    }()

    private lazy var tableView: UITableView = {
        let table = UITableView(
            frame: .zero,
            style: .plain
        )

        table.translatesAutoresizingMaskIntoConstraints = false

        table.delegate = self
        table.dataSource = self

        table.rowHeight = 72

        table.register(
            PrintingCell.self,
            forCellReuseIdentifier: PrintingCell.reuseID
        )

        return table
    }()

    // MARK: - Init

    init(printings: [MTGCard]) {
        self.printings = printings
        super.init(frame: .zero)

        setupLayout()
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    // MARK: - Layout

    private func setupLayout() {

        backgroundColor = .clear

        addSubview(dimView)
        addSubview(containerView)

        containerView.addSubview(titleLabel)
        containerView.addSubview(closeButton)
        containerView.addSubview(tableView)

        NSLayoutConstraint.activate([

            dimView.topAnchor.constraint(equalTo: topAnchor),
            dimView.leadingAnchor.constraint(equalTo: leadingAnchor),
            dimView.trailingAnchor.constraint(equalTo: trailingAnchor),
            dimView.bottomAnchor.constraint(equalTo: bottomAnchor),

            containerView.leadingAnchor.constraint(
                equalTo: leadingAnchor
            ),

            containerView.trailingAnchor.constraint(
                equalTo: trailingAnchor
            ),

            containerView.bottomAnchor.constraint(
                equalTo: bottomAnchor
            ),

            containerView.heightAnchor.constraint(
                equalToConstant: 500
            ),

            titleLabel.topAnchor.constraint(
                equalTo: containerView.topAnchor,
                constant: 20
            ),

            titleLabel.leadingAnchor.constraint(
                equalTo: containerView.leadingAnchor,
                constant: 20
            ),

            closeButton.centerYAnchor.constraint(
                equalTo: titleLabel.centerYAnchor
            ),

            closeButton.trailingAnchor.constraint(
                equalTo: containerView.trailingAnchor,
                constant: -20
            ),

            tableView.topAnchor.constraint(
                equalTo: titleLabel.bottomAnchor,
                constant: 16
            ),

            tableView.leadingAnchor.constraint(
                equalTo: containerView.leadingAnchor
            ),

            tableView.trailingAnchor.constraint(
                equalTo: containerView.trailingAnchor
            ),

            tableView.bottomAnchor.constraint(
                equalTo: containerView.bottomAnchor
            )
        ])

        let tap = UITapGestureRecognizer(
            target: self,
            action: #selector(cancelTapped)
        )

        dimView.addGestureRecognizer(tap)
    }

    // MARK: - Actions

    @objc
    private func cancelTapped() {
        onCancel?()
    }
}

// MARK: - UITableViewDataSource

extension PrintingSelectionOverlayView:
UITableViewDataSource {

    func tableView(
        _ tableView: UITableView,
        numberOfRowsInSection section: Int
    ) -> Int {
        printings.count
    }

    func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {

        let cell = tableView.dequeueReusableCell(
            withIdentifier: PrintingCell.reuseID,
            for: indexPath
        ) as! PrintingCell

        cell.configure(
            with: printings[indexPath.row]
        )

        return cell
    }
}

// MARK: - UITableViewDelegate

extension PrintingSelectionOverlayView:
UITableViewDelegate {

    func tableView(
        _ tableView: UITableView,
        didSelectRowAt indexPath: IndexPath
    ) {

        tableView.deselectRow(
            at: indexPath,
            animated: true
        )

        onSelect?(printings[indexPath.row])
    }
}

// MARK: - Printing Cell

final class PrintingCell: UITableViewCell {

    static let reuseID = "PrintingCell"

    private let cardImageView: UIImageView = {
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.layer.cornerRadius = 6
        iv.clipsToBounds = true
        iv.contentMode = .scaleAspectFill
        iv.backgroundColor = .secondarySystemBackground
        return iv
    }()

    private let titleLabel: UILabel = {
        let lbl = UILabel()
        lbl.font = .systemFont(
            ofSize: 16,
            weight: .semibold
        )
        lbl.numberOfLines = 1
        return lbl
    }()

    private let subtitleLabel: UILabel = {
        let lbl = UILabel()
        lbl.font = .systemFont(
            ofSize: 13
        )
        lbl.textColor = .secondaryLabel
        lbl.numberOfLines = 2
        return lbl
    }()

    override init(
        style: UITableViewCell.CellStyle,
        reuseIdentifier: String?
    ) {
        super.init(
            style: style,
            reuseIdentifier: reuseIdentifier
        )

        setupLayout()
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    private func setupLayout() {

        let stack = UIStackView(
            arrangedSubviews: [
                titleLabel,
                subtitleLabel
            ]
        )

        stack.axis = .vertical
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(cardImageView)
        contentView.addSubview(stack)

        NSLayoutConstraint.activate([

            cardImageView.leadingAnchor.constraint(
                equalTo: contentView.leadingAnchor,
                constant: 12
            ),

            cardImageView.centerYAnchor.constraint(
                equalTo: contentView.centerYAnchor
            ),

            cardImageView.widthAnchor.constraint(
                equalToConstant: 42
            ),

            cardImageView.heightAnchor.constraint(
                equalToConstant: 58
            ),

            stack.leadingAnchor.constraint(
                equalTo: cardImageView.trailingAnchor,
                constant: 12
            ),

            stack.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor,
                constant: -12
            ),

            stack.centerYAnchor.constraint(
                equalTo: contentView.centerYAnchor
            )
        ])
    }

    func configure(with card: MTGCard) {

        titleLabel.text = "\(card.set.uppercased()) #\(card.collectorNumber)"
        subtitleLabel.text = card.setName
        cardImageView.image = nil

        guard let url = card.imageUris?.normal ?? card.imageUris?.artCrop else {
            return
        }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard
                let self,
                let data,
                let image = UIImage(data: data)
            else {
                return
            }

            DispatchQueue.main.async {
                self.cardImageView.image = image
            }
        }.resume()
    }
    override func prepareForReuse() {
        super.prepareForReuse()
        cardImageView.image = nil
        titleLabel.text = nil
        subtitleLabel.text = nil
    }
}
