//
//  BulkDataCell.swift
//  TcgScanner
//
//  Created by Joel James on 19/06/2026.
//

import Foundation
import UIKit

final class BulkDataCell: UITableViewCell {
    static let reuseID = "BulkDataCell"
    
    private let titleLabel: UILabel = {
        let lbl = UILabel()
        lbl.font = .systemFont(ofSize: 16)
        lbl.text = "Scryfall Oracle Cards"
        return lbl
    }()
    
    private let statusBadge: UILabel = {
        let lbl = UILabel()
        lbl.font               = .systemFont(ofSize: 12, weight: .semibold)
        lbl.textColor          = .white
        lbl.textAlignment      = .center
        lbl.layer.cornerRadius = 8
        lbl.clipsToBounds      = true
        return lbl
    }()
    
    private let detailLabel: UILabel = {
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
        
        statusBadge.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(textStack)
        contentView.addSubview(statusBadge)
        
        NSLayoutConstraint.activate([
            textStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            textStack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            textStack.trailingAnchor.constraint(lessThanOrEqualTo: statusBadge.leadingAnchor, constant: -8),
            
            statusBadge.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            statusBadge.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            statusBadge.widthAnchor.constraint(greaterThanOrEqualToConstant: 60),
            statusBadge.heightAnchor.constraint(equalToConstant: 24),
        ])
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    func configure() {
        
        let cardCount =
        CardDatabaseService.shared.cardCount()
        
        let featureCount =
        CardDatabaseService.shared.featurePrintCount()
        
        titleLabel.text = "Settings"
        
        detailLabel.text =
        "\(featureCount.formatted()) vision features"
        
        statusBadge.text = "\(cardCount.formatted())"
        statusBadge.backgroundColor = .systemBlue
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        detailLabel.text = nil
        statusBadge.text = nil
    }
}

