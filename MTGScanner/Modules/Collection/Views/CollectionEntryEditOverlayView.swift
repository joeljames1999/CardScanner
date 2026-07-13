//
//  CollectionEntryEditOverlayView.swift
//  TcgScanner
//

import UIKit

final class CollectionEntryEditOverlayView: UIView {

    var onDismiss: (() -> Void)?
    var onQuantityChange: ((Int) -> Void)?
    var onConditionChange: ((CardCondition) -> Void)?
    var onFoilChange: ((Bool) -> Void)?
    var onRemoveAll: (() -> Void)?
    var onOpenDetails: (() -> Void)?
    var onChangePrinting: (() -> Void)?

    private let entry: CollectionEntry
    private let card: MTGCard?
    private let forcedFinish: CardFinish?

    private var quantity: Int
    private var condition: CardCondition
    private var isFoil: Bool
    private var isDismissing = false
    private var imageLoadTask: Task<Void, Never>?
    private var representedSetCode: String?

    private let dimmingView = UIView()
    private let contentContainer = UIView()
    private let cardImageView = UIImageView()
    private let sheetView = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
    private let grabberView = UIView()
    private let detailButton = UIButton(type: .system)
    private let titleLabel = UILabel()
    private let setImageView = UIImageView()
    private let metadataLabel = UILabel()
    private let collectorLabel = UILabel()
    private let quantityValueLabel = UILabel()
    private let minusButton = UIButton(type: .system)
    private let plusButton = UIButton(type: .system)
    private let conditionButton = UIButton(type: .system)
    private let changePrintingButton = UIButton(type: .system)
    private let foilControl = UISegmentedControl(items: ["Off", "On"])
    private let removeButton = UIButton(type: .system)
    private weak var changePrintingRow: UIView?

    init(entry: CollectionEntry, card: MTGCard?) {
        let forcedFinish = Self.forcedFinish(for: entry, card: card)

        self.entry = entry
        self.card = card
        self.forcedFinish = forcedFinish
        self.quantity = entry.count
        self.condition = entry.condition
        self.isFoil = forcedFinish?.isFoilLike ?? entry.resolvedFinish.isFoilLike
        super.init(frame: .zero)

        configureViews()
        layoutViews()
        configureContent()
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    deinit {
        imageLoadTask?.cancel()
    }

    func dismiss(animated: Bool = true) {
        guard !isDismissing else { return }
        isDismissing = true

        let completion = {
            self.removeFromSuperview()
            self.onDismiss?()
        }

        guard animated else {
            completion()
            return
        }

        UIView.animate(
            withDuration: 0.18,
            animations: {
                self.alpha = 0
                self.contentContainer.transform = CGAffineTransform(translationX: 0, y: 24)
            },
            completion: { _ in completion() }
        )
    }

    func setChangePrintingAvailable(_ isAvailable: Bool) {
        changePrintingRow?.isHidden = !isAvailable
    }

    func animateIn() {
        alpha = 0
        contentContainer.transform = CGAffineTransform(translationX: 0, y: 28)

        UIView.animate(
            withDuration: 0.24,
            delay: 0,
            usingSpringWithDamping: 0.9,
            initialSpringVelocity: 0.3,
            options: [.curveEaseOut],
            animations: {
                self.alpha = 1
                self.contentContainer.transform = .identity
            }
        )
    }
}

private extension CollectionEntryEditOverlayView {

    static func forcedFinish(for entry: CollectionEntry, card: MTGCard?) -> CardFinish? {
        guard let finishes = card?.availableFinishes, !finishes.isEmpty else {
            return nil
        }

        let canToggleFoil = finishes.contains(.nonfoil) && finishes.contains(.foil)
        guard !canToggleFoil else {
            return nil
        }

        if finishes.contains(entry.resolvedFinish) {
            return entry.resolvedFinish
        }

        return finishes.first
    }

    func configureViews() {
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .clear

        dimmingView.translatesAutoresizingMaskIntoConstraints = false
        dimmingView.backgroundColor = UIColor.black.withAlphaComponent(0.58)
        dimmingView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(dimmingTapped)))

        contentContainer.translatesAutoresizingMaskIntoConstraints = false
        let outsideTap = UITapGestureRecognizer(target: self, action: #selector(contentContainerTapped(_:)))
        outsideTap.cancelsTouchesInView = false
        contentContainer.addGestureRecognizer(outsideTap)

        cardImageView.translatesAutoresizingMaskIntoConstraints = false
        cardImageView.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        cardImageView.contentMode = .scaleAspectFit
        cardImageView.clipsToBounds = true
        cardImageView.layer.cornerRadius = 12
        cardImageView.layer.cornerCurve = .continuous
        cardImageView.layer.borderWidth = 1
        cardImageView.layer.borderColor = UIColor.white.withAlphaComponent(0.18).cgColor
        cardImageView.image = UIImage(systemName: "photo")
        cardImageView.tintColor = .secondaryLabel
        cardImageView.isUserInteractionEnabled = true
        cardImageView.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(handleDismissPan(_:))))

        sheetView.translatesAutoresizingMaskIntoConstraints = false
        sheetView.layer.cornerRadius = 28
        sheetView.layer.cornerCurve = .continuous
        sheetView.clipsToBounds = true
        sheetView.layer.borderWidth = 1
        sheetView.layer.borderColor = UIColor.white.withAlphaComponent(0.18).cgColor
        sheetView.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(handleDismissPan(_:))))

        grabberView.translatesAutoresizingMaskIntoConstraints = false
        grabberView.backgroundColor = UIColor.white.withAlphaComponent(0.68)
        grabberView.layer.cornerRadius = 2

        detailButton.translatesAutoresizingMaskIntoConstraints = false
        detailButton.setImage(UIImage(systemName: "info.circle"), for: .normal)
        detailButton.tintColor = .white
        detailButton.backgroundColor = UIColor.white.withAlphaComponent(0.08)
        detailButton.layer.cornerRadius = 18
        detailButton.layer.cornerCurve = .continuous
        detailButton.layer.borderWidth = 1
        detailButton.layer.borderColor = UIColor.white.withAlphaComponent(0.12).cgColor
        detailButton.isHidden = card == nil
        detailButton.addTarget(self, action: #selector(detailTapped), for: .touchUpInside)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.textColor = .white
        titleLabel.font = .systemFont(ofSize: 24, weight: .bold)
        titleLabel.numberOfLines = 2
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.82

        setImageView.translatesAutoresizingMaskIntoConstraints = false
        setImageView.contentMode = .scaleAspectFit

        metadataLabel.translatesAutoresizingMaskIntoConstraints = false
        metadataLabel.textColor = UIColor.white.withAlphaComponent(0.66)
        metadataLabel.font = .systemFont(ofSize: 15, weight: .medium)
        metadataLabel.numberOfLines = 1
        metadataLabel.adjustsFontSizeToFitWidth = true
        metadataLabel.minimumScaleFactor = 0.78

        collectorLabel.translatesAutoresizingMaskIntoConstraints = false
        collectorLabel.textColor = UIColor.white.withAlphaComponent(0.62)
        collectorLabel.font = .systemFont(ofSize: 14, weight: .regular)

        quantityValueLabel.translatesAutoresizingMaskIntoConstraints = false
        quantityValueLabel.textColor = .white
        quantityValueLabel.font = .systemFont(ofSize: 18, weight: .bold)
        quantityValueLabel.textAlignment = .center

        configureStepperButton(minusButton, systemImage: "minus")
        configureStepperButton(plusButton, systemImage: "plus")
        minusButton.addTarget(self, action: #selector(decreaseQuantity), for: .touchUpInside)
        plusButton.addTarget(self, action: #selector(increaseQuantity), for: .touchUpInside)

        conditionButton.translatesAutoresizingMaskIntoConstraints = false
        conditionButton.tintColor = .white
        conditionButton.contentHorizontalAlignment = .right
        conditionButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        conditionButton.showsMenuAsPrimaryAction = true

        changePrintingButton.translatesAutoresizingMaskIntoConstraints = false
        changePrintingButton.setTitle("Choose", for: .normal)
        changePrintingButton.setImage(UIImage(systemName: "chevron.right"), for: .normal)
        changePrintingButton.semanticContentAttribute = .forceRightToLeft
        changePrintingButton.tintColor = .white.withAlphaComponent(0.86)
        changePrintingButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        changePrintingButton.addTarget(self, action: #selector(changePrintingTapped), for: .touchUpInside)

        foilControl.translatesAutoresizingMaskIntoConstraints = false
        foilControl.selectedSegmentIndex = isFoil ? 1 : 0
        foilControl.selectedSegmentTintColor = .brandBlue
        foilControl.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
        foilControl.setTitleTextAttributes([.foregroundColor: UIColor.white.withAlphaComponent(0.82)], for: .normal)
        foilControl.addTarget(self, action: #selector(foilChanged), for: .valueChanged)

        removeButton.translatesAutoresizingMaskIntoConstraints = false
        removeButton.setTitle("Remove All Copies", for: .normal)
        removeButton.setImage(UIImage(systemName: "trash"), for: .normal)
        removeButton.tintColor = .white
        removeButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .bold)
        removeButton.backgroundColor = UIColor.systemRed.withAlphaComponent(0.32)
        removeButton.layer.cornerRadius = 14
        removeButton.layer.cornerCurve = .continuous
        removeButton.layer.borderWidth = 1
        removeButton.layer.borderColor = UIColor.systemRed.withAlphaComponent(0.85).cgColor
        removeButton.addTarget(self, action: #selector(removeTapped), for: .touchUpInside)
    }

    func layoutViews() {
        addSubview(dimmingView)
        addSubview(contentContainer)
        contentContainer.addSubview(cardImageView)
        contentContainer.addSubview(sheetView)

        let sheetContent = sheetView.contentView
        sheetContent.addSubview(grabberView)
        sheetContent.addSubview(detailButton)
        sheetContent.addSubview(titleLabel)
        sheetContent.addSubview(setImageView)
        sheetContent.addSubview(metadataLabel)
        sheetContent.addSubview(collectorLabel)

        let quantityRow = makeRow(icon: "rectangle.stack", title: "Quantity", trailing: quantityControlsView())
        let conditionRow = makeRow(icon: "sparkles.rectangle.stack", title: "Condition", trailing: conditionButton)
        let changePrintingRow = makeRow(icon: "rectangle.on.rectangle", title: "Change Printing", trailing: changePrintingButton)
        let foilRow = makeRow(icon: "sparkles", title: "Foil", trailing: foilControl)
        changePrintingRow.isHidden = true
        foilRow.isHidden = forcedFinish != nil
        self.changePrintingRow = changePrintingRow

        let stackView = UIStackView(arrangedSubviews: [quantityRow, conditionRow, changePrintingRow, foilRow, removeButton])
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.spacing = 8
        sheetContent.addSubview(stackView)

        NSLayoutConstraint.activate([
            dimmingView.topAnchor.constraint(equalTo: topAnchor),
            dimmingView.leadingAnchor.constraint(equalTo: leadingAnchor),
            dimmingView.trailingAnchor.constraint(equalTo: trailingAnchor),
            dimmingView.bottomAnchor.constraint(equalTo: bottomAnchor),

            contentContainer.topAnchor.constraint(equalTo: topAnchor),
            contentContainer.leadingAnchor.constraint(equalTo: leadingAnchor),
            contentContainer.trailingAnchor.constraint(equalTo: trailingAnchor),
            contentContainer.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -10),

            sheetView.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor, constant: 16),
            sheetView.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor, constant: -16),
            sheetView.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor),

            cardImageView.centerXAnchor.constraint(equalTo: contentContainer.centerXAnchor),
            cardImageView.widthAnchor.constraint(equalToConstant: 166),
            cardImageView.heightAnchor.constraint(equalTo: cardImageView.widthAnchor, multiplier: 1.397),
            cardImageView.bottomAnchor.constraint(equalTo: sheetView.topAnchor, constant: -8),
            cardImageView.topAnchor.constraint(greaterThanOrEqualTo: contentContainer.topAnchor, constant: 8),

            grabberView.topAnchor.constraint(equalTo: sheetContent.topAnchor, constant: 12),
            grabberView.centerXAnchor.constraint(equalTo: sheetContent.centerXAnchor),
            grabberView.widthAnchor.constraint(equalToConstant: 42),
            grabberView.heightAnchor.constraint(equalToConstant: 4),

            detailButton.topAnchor.constraint(equalTo: grabberView.bottomAnchor, constant: 14),
            detailButton.trailingAnchor.constraint(equalTo: sheetContent.trailingAnchor, constant: -24),
            detailButton.widthAnchor.constraint(equalToConstant: 36),
            detailButton.heightAnchor.constraint(equalToConstant: 36),

            titleLabel.topAnchor.constraint(equalTo: grabberView.bottomAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: sheetContent.leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(equalTo: detailButton.leadingAnchor, constant: -12),

            setImageView.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            setImageView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 7),
            setImageView.widthAnchor.constraint(equalToConstant: 17),
            setImageView.heightAnchor.constraint(equalToConstant: 17),

            metadataLabel.leadingAnchor.constraint(equalTo: setImageView.trailingAnchor, constant: 8),
            metadataLabel.centerYAnchor.constraint(equalTo: setImageView.centerYAnchor),
            metadataLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),

            collectorLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            collectorLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            collectorLabel.topAnchor.constraint(equalTo: metadataLabel.bottomAnchor, constant: 5),

            stackView.topAnchor.constraint(equalTo: collectorLabel.bottomAnchor, constant: 12),
            stackView.leadingAnchor.constraint(equalTo: sheetContent.leadingAnchor, constant: 18),
            stackView.trailingAnchor.constraint(equalTo: sheetContent.trailingAnchor, constant: -18),
            stackView.bottomAnchor.constraint(equalTo: sheetContent.bottomAnchor, constant: -16),

            removeButton.heightAnchor.constraint(equalToConstant: 48)
        ])
    }

    func configureContent() {
        let setCode = entry.setCode.isEmpty ? card?.set ?? "" : entry.setCode
        let setName = entry.setName.isEmpty ? card?.setName ?? "" : entry.setName
        let collectorNumber = entry.collectorNumber.isEmpty ? card?.collectorNumber ?? "" : entry.collectorNumber
        let rarity = entry.rarity == "unknown" ? card?.rarity ?? entry.rarity : entry.rarity

        titleLabel.text = entry.name
        metadataLabel.text = "\(setCode.uppercased()) • \(rarity.capitalized)"
        collectorLabel.text = "#\(collectorNumber) • \(setName)"
        quantityValueLabel.text = "\(quantity)"
        conditionButton.setTitle(condition.rawValue, for: .normal)
        conditionButton.menu = makeConditionMenu()

        loadImage(entry.imageURL ?? card?.displayImage)
        loadSetSymbol(set: setCode, rarity: rarity)
    }

    func makeRow(icon: String, title: String, trailing: UIView) -> UIView {
        let row = UIView()
        row.translatesAutoresizingMaskIntoConstraints = false
        row.backgroundColor = UIColor.white.withAlphaComponent(0.055)
        row.layer.cornerRadius = 14
        row.layer.cornerCurve = .continuous
        row.layer.borderWidth = 1
        row.layer.borderColor = UIColor.white.withAlphaComponent(0.09).cgColor

        let iconView = UIImageView(image: UIImage(systemName: icon))
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.contentMode = .scaleAspectFit
        iconView.tintColor = .white

        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = title
        label.textColor = .white
        label.font = .systemFont(ofSize: 16, weight: .semibold)

        row.addSubview(iconView)
        row.addSubview(label)
        row.addSubview(trailing)

        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(equalToConstant: 48),
            iconView.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 16),
            iconView.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24),

            label.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 14),
            label.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            label.trailingAnchor.constraint(lessThanOrEqualTo: trailing.leadingAnchor, constant: -12),

            trailing.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -16),
            trailing.centerYAnchor.constraint(equalTo: row.centerYAnchor)
        ])

        return row
    }

    func quantityControlsView() -> UIView {
        let controls = UIStackView(arrangedSubviews: [minusButton, quantityValueLabel, plusButton])
        controls.translatesAutoresizingMaskIntoConstraints = false
        controls.axis = .horizontal
        controls.alignment = .center
        controls.spacing = 14

        NSLayoutConstraint.activate([
            minusButton.widthAnchor.constraint(equalToConstant: 34),
            minusButton.heightAnchor.constraint(equalToConstant: 34),
            plusButton.widthAnchor.constraint(equalToConstant: 34),
            plusButton.heightAnchor.constraint(equalToConstant: 34),
            quantityValueLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 28)
        ])

        return controls
    }

    func configureStepperButton(_ button: UIButton, systemImage: String) {
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(systemName: systemImage), for: .normal)
        button.tintColor = systemImage == "plus" ? .brandBlue : .white
        button.backgroundColor = UIColor.white.withAlphaComponent(0.08)
        button.layer.cornerRadius = 17
        button.layer.cornerCurve = .continuous
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.white.withAlphaComponent(0.1).cgColor
    }

    func makeConditionMenu() -> UIMenu {
        let actions = CardCondition.allCases.map { value in
            UIAction(
                title: value.rawValue,
                state: value == condition ? .on : .off
            ) { [weak self] _ in
                guard let self else { return }
                self.condition = value
                self.conditionButton.setTitle(value.rawValue, for: .normal)
                self.conditionButton.menu = self.makeConditionMenu()
                self.onConditionChange?(value)
            }
        }

        return UIMenu(children: actions)
    }

    func loadImage(_ url: URL?) {
        imageLoadTask?.cancel()
        cardImageView.image = UIImage(systemName: "photo")
        cardImageView.contentMode = .scaleAspectFit

        guard let url else { return }

        imageLoadTask = Task { [weak self] in
            guard
                let image = await ImageLoader.shared.image(for: url),
                !Task.isCancelled
            else { return }

            await MainActor.run {
                self?.cardImageView.image = image
                self?.cardImageView.contentMode = .scaleAspectFill
                self?.imageLoadTask = nil
            }
        }
    }

    func loadSetSymbol(set: String, rarity: String) {
        let representedSetCode = set.lowercased()
        self.representedSetCode = representedSetCode
        setImageView.image = nil

        SetSymbolService.shared.image(for: set) { [weak self] image in
            guard
                let self,
                self.representedSetCode == representedSetCode
            else { return }

            self.setImageView.image = image?.withRenderingMode(.alwaysTemplate)
            self.setImageView.tintColor = self.rarityColor(rarity)
        }
    }

    func rarityColor(_ rarity: String) -> UIColor {
        switch rarity.lowercased() {
        case "common":
            return .white.withAlphaComponent(0.75)
        case "uncommon":
            return UIColor(red: 0.75, green: 0.75, blue: 0.75, alpha: 1)
        case "rare":
            return UIColor(red: 0.86, green: 0.65, blue: 0.13, alpha: 1)
        case "mythic", "mythic rare":
            return UIColor(red: 0.92, green: 0.36, blue: 0.08, alpha: 1)
        case "special":
            return .systemPurple
        case "bonus":
            return .systemTeal
        default:
            return .white
        }
    }

    @objc func dimmingTapped() {
        dismiss()
    }

    @objc func contentContainerTapped(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: contentContainer)
        guard
            !cardImageView.frame.contains(location),
            !sheetView.frame.contains(location)
        else {
            return
        }

        dismiss()
    }

    @objc func handleDismissPan(_ gesture: UIPanGestureRecognizer) {
        guard !isDismissing else { return }

        let translationY = max(0, gesture.translation(in: self).y)
        let velocityY = gesture.velocity(in: self).y

        switch gesture.state {
        case .changed:
            contentContainer.transform = CGAffineTransform(translationX: 0, y: translationY)
            let progress = min(translationY / 220, 1)
            alpha = 1 - (progress * 0.35)

        case .ended, .cancelled, .failed:
            if translationY > 90 || velocityY > 700 {
                dismiss()
            } else {
                UIView.animate(
                    withDuration: 0.2,
                    delay: 0,
                    usingSpringWithDamping: 0.86,
                    initialSpringVelocity: 0.2,
                    options: [.curveEaseOut],
                    animations: {
                        self.contentContainer.transform = .identity
                        self.alpha = 1
                    }
                )
            }

        default:
            break
        }
    }

    @objc func decreaseQuantity() {
        guard quantity > 1 else { return }
        quantity -= 1
        quantityValueLabel.text = "\(quantity)"
        onQuantityChange?(quantity)
    }

    @objc func increaseQuantity() {
        quantity += 1
        quantityValueLabel.text = "\(quantity)"
        onQuantityChange?(quantity)
    }

    @objc func foilChanged() {
        isFoil = foilControl.selectedSegmentIndex == 1
        onFoilChange?(isFoil)
    }

    @objc func removeTapped() {
        onRemoveAll?()
    }

    @objc func detailTapped() {
        onOpenDetails?()
    }

    @objc func changePrintingTapped() {
        onChangePrinting?()
    }
}
