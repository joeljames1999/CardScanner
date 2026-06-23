//
//  SettingsOptionsCell.swift
//  TcgScanner
//
//  Created by Joel James on 19/06/2026.
//

import Foundation
import UIKit

final class SettingsOptionCell: UITableViewCell {
    static let reuseID = "SettingOptionCell"
    func setLabels (titleLabel: String, detailLabel: String) {
        self.titleLabel.text  = titleLabel
        self.detailLabel.text = detailLabel
    }
    private var titleLabel: UILabel = {
        let lbl = UILabel()
        lbl.font = .systemFont(ofSize: 16)
        lbl.text = "Settings"
        return lbl
    }()

    private var detailLabel: UILabel = {
        let lbl = UILabel()
        lbl.font      = .systemFont(ofSize: 12)
        lbl.textColor = .secondaryLabel
        return lbl
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        accessoryType = .disclosureIndicator

        let textStack = UIStackView(arrangedSubviews: [titleLabel, detailLabel])
        textStack.axis    = .vertical
        textStack.spacing = 3
        textStack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(textStack)

        NSLayoutConstraint.activate([
            textStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            textStack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    override func prepareForReuse() {
        super.prepareForReuse()
        detailLabel.text = nil
    }
}
