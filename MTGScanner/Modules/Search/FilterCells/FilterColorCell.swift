import UIKit

final class FilterColorCell: UITableViewCell {

    static let reuseID = "FilterColorCell"

    private var selectedColors: Set<SearchFilter.ManaColor> = []
    private var onSelectionChanged: ((SearchFilter.ManaColor) -> Void)?

    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.alignment = .center
        stack.distribution = .fillEqually
        stack.spacing = 12
        return stack
    }()

    private var buttons: [UIButton] = []

    override init(style: UITableViewCell.CellStyle,
                  reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        selectionStyle = .none

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

        SearchFilter.ManaColor.allCases.enumerated().forEach {
            index,
            color in

            let button = UIButton(type: .custom)

            button.tag = index

            button.setImage(color.image, for: .normal)

            button.imageView?.contentMode = .scaleAspectFit

            button.widthAnchor.constraint(
                equalToConstant: 44
            ).isActive = true

            button.heightAnchor.constraint(
                equalToConstant: 44
            ).isActive = true

            button.layer.cornerRadius = 22
            button.layer.borderWidth = 2

            button.addTarget(
                self,
                action: #selector(symbolTapped(_:)),
                for: .touchUpInside
            )

            buttons.append(button)
            stackView.addArrangedSubview(button)
        }
    }

    func configure(
        selectedColors: Set<SearchFilter.ManaColor>,
        onSelectionChanged: @escaping (SearchFilter.ManaColor) -> Void
    ) {

        self.selectedColors = selectedColors
        self.onSelectionChanged = onSelectionChanged

        updateAppearance()
    }

    private func updateAppearance() {

        for (index, button) in buttons.enumerated() {

            let color = SearchFilter.ManaColor.allCases[index]

            let selected = selectedColors.contains(color)

            button.alpha = selected ? 1.0 : 0.4

            button.layer.borderColor =
                selected
                ? UIColor.systemBlue.cgColor
                : UIColor.clear.cgColor
        }
    }

    @objc
    private func symbolTapped(_ sender: UIButton) {

        let color =
            SearchFilter.ManaColor.allCases[sender.tag]

        onSelectionChanged?(color)
    }
}
