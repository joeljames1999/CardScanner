import UIKit

final class FilterColorModeCell: UITableViewCell {

    static let reuseID = "FilterColorModeCell"

    private var onChange: ((ColorFilterMode) -> Void)?

    private let segmentedControl: UISegmentedControl = {

        let control = UISegmentedControl(
            items: [
                "Any Selected",
                "Exact Match"
            ]
        )

        control.translatesAutoresizingMaskIntoConstraints = false

        return control
    }()

    override init(
        style: UITableViewCell.CellStyle,
        reuseIdentifier: String?
    ) {

        super.init(
            style: style,
            reuseIdentifier: reuseIdentifier
        )

        selectionStyle = .none

        contentView.addSubview(segmentedControl)

        NSLayoutConstraint.activate([

            segmentedControl.topAnchor.constraint(
                equalTo: contentView.topAnchor,
                constant: 8
            ),

            segmentedControl.bottomAnchor.constraint(
                equalTo: contentView.bottomAnchor,
                constant: -8
            ),

            segmentedControl.leadingAnchor.constraint(
                equalTo: contentView.leadingAnchor,
                constant: 16
            ),

            segmentedControl.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor,
                constant: -16
            )
        ])

        segmentedControl.addTarget(
            self,
            action: #selector(valueChanged),
            for: .valueChanged
        )
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    func configure(
        mode: ColorFilterMode,
        onChange: @escaping (ColorFilterMode) -> Void
    ) {

        self.onChange = onChange

        segmentedControl.selectedSegmentIndex =
            mode == .includesAnyOfThese ? 0 : 1
    }

    @objc
    private func valueChanged() {

        let mode: ColorFilterMode =
            segmentedControl.selectedSegmentIndex == 0
            ? .includesAnyOfThese
            : .includesOnlyThese

        onChange?(mode)
    }
}
