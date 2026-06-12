import Foundation
import UIKit

final class FilterManaCostRowCell: UITableViewCell {

    static let reuseID = "FilterManaCostRowCell"

    private var buttons: [UIButton] = []
    private var onSelectionChanged: ((Int) -> Void)?

    private let stackView: UIStackView = {

        let stack = UIStackView()

        stack.axis = .horizontal
        stack.alignment = .fill
        stack.distribution = .fillEqually
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false

        return stack
    }()

    override init(
        style: UITableViewCell.CellStyle,
        reuseIdentifier: String?
    ) {

        super.init(
            style: style,
            reuseIdentifier: reuseIdentifier
        )

        contentView.addSubview(stackView)

        NSLayoutConstraint.activate([

            stackView.topAnchor.constraint(
                equalTo: contentView.topAnchor,
                constant: 12
            ),

            stackView.bottomAnchor.constraint(
                equalTo: contentView.bottomAnchor,
                constant: -12
            ),

            stackView.leadingAnchor.constraint(
                equalTo: contentView.leadingAnchor,
                constant: 16
            ),

            stackView.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor,
                constant: -16
            )
        ])

        createButtons()
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    private func createButtons() {

        for cost in 0...6 {

            let button = UIButton(type: .system)

            button.tag = cost

            button.layer.cornerRadius = 10
            button.layer.borderWidth = 1

            button.setTitle(
                cost == 6 ? "6+" : "\(cost)",
                for: .normal
            )

            button.addTarget(
                self,
                action: #selector(buttonTapped(_:)),
                for: .touchUpInside
            )

            buttons.append(button)

            stackView.addArrangedSubview(button)
        }
    }

    func configure(
        selectedCosts: Set<Int>,
        onSelectionChanged: @escaping (Int) -> Void
    ) {

        self.onSelectionChanged = onSelectionChanged

        for button in buttons {

            let selected =
                selectedCosts.contains(button.tag)

            button.backgroundColor =
                selected
                ? .systemBlue
                : .secondarySystemGroupedBackground

            button.setTitleColor(
                selected ? .white : .label,
                for: .normal
            )

            button.layer.borderColor =
                selected
                ? UIColor.systemBlue.cgColor
                : UIColor.separator.cgColor
        }
    }

    @objc private func buttonTapped(
        _ sender: UIButton
    ) {
        onSelectionChanged?(sender.tag)
    }
}
