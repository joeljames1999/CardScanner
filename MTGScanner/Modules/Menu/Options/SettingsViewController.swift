//
//  SettingsViewController.swift
//  TcgScanner
//
//  Created by Joel James on 04/06/2026.
//

import Foundation
import UIKit

final class SettingsViewController: UIViewController {

    private enum Row: CaseIterable {
        case notifications
        case currency
        case cardLanguage
        case priceData

        var title: String {
            switch self {
            case .notifications: return "Notifications"
            case .currency: return "Currency"
            case .cardLanguage: return "Card Language"
            case .priceData: return "PriceData"
            }
        }

        var detail: String {
            switch self {
            case .notifications:
                return "Notifications settings"
            case .currency:
                let currency = CurrencySettings.shared.preferredCurrency
                return "\(currency.rawValue) - \(currency.displayName)"
            case .cardLanguage:
                let language = CardLanguageSettings.shared.preferredLanguage
                return "\(language.displayName) (\(language.rawValue))"
            case .priceData:
                return "Price data settings"
            }
        }
    }

    private lazy var tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .insetGrouped)
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.register(SettingsOptionCell.self, forCellReuseIdentifier: SettingsOptionCell.reuseID)
        tv.dataSource = self
        tv.delegate = self
        return tv
    }()

    private let rows = Row.allCases

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Settings"
        view.backgroundColor = .systemGroupedBackground
        setupLayout()
    }

    private func setupLayout() {
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func showLanguagePicker() {
        let alert = UIAlertController(
            title: "Card Language",
            message: nil,
            preferredStyle: .actionSheet
        )

        for language in CardLanguage.allCases {
            let isSelected = language == CardLanguageSettings.shared.preferredLanguage
            let suffix = isSelected ? " (Current)" : ""
            let title = "\(language.displayName) - \(language.rawValue)\(suffix)"
            let action = UIAlertAction(title: title, style: .default) { _ in
                CardLanguageSettings.shared.preferredLanguage = language
                self.tableView.reloadData()
            }

            alert.addAction(action)
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        if let popover = alert.popoverPresentationController,
           let selectedIndex = rows.firstIndex(of: .cardLanguage) {
            let indexPath = IndexPath(row: selectedIndex, section: 0)
            popover.sourceView = tableView.cellForRow(at: indexPath) ?? tableView
            popover.sourceRect = tableView.rectForRow(at: indexPath)
        }

        present(alert, animated: true)
    }

    private func showCurrencyPicker() {
        let alert = UIAlertController(
            title: "Currency",
            message: nil,
            preferredStyle: .actionSheet
        )

        for currency in PriceCurrency.allCases {
            let isSelected = currency == CurrencySettings.shared.preferredCurrency
            let suffix = isSelected ? " (Current)" : ""
            let title = "\(currency.rawValue) - \(currency.displayName)\(suffix)"
            let action = UIAlertAction(title: title, style: .default) { _ in
                CurrencySettings.shared.preferredCurrency = currency
                self.tableView.reloadData()
            }

            alert.addAction(action)
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        if let popover = alert.popoverPresentationController,
           let selectedIndex = rows.firstIndex(of: .currency) {
            let indexPath = IndexPath(row: selectedIndex, section: 0)
            popover.sourceView = tableView.cellForRow(at: indexPath) ?? tableView
            popover.sourceRect = tableView.rectForRow(at: indexPath)
        }

        present(alert, animated: true)
    }
}

extension SettingsViewController: UITableViewDataSource, UITableViewDelegate {

    func numberOfSections(in tableView: UITableView) -> Int {
        1
    }

    func tableView(
        _ tableView: UITableView,
        numberOfRowsInSection section: Int
    ) -> Int {
        rows.count
    }

    func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {

        let cell = SettingsOptionCell(
            style: .default,
            reuseIdentifier: SettingsOptionCell.reuseID
        )

        let row = rows[indexPath.row]
        cell.setLabels(
            titleLabel: row.title,
            detailLabel: row.detail
        )
        cell.accessoryType = (row == .currency || row == .cardLanguage) ? .disclosureIndicator : .none

        return cell
    }

    func tableView(
        _ tableView: UITableView,
        didSelectRowAt indexPath: IndexPath
    ) {

        tableView.deselectRow(at: indexPath, animated: true)

        switch rows[indexPath.row] {
        case .currency:
            showCurrencyPicker()
        case .cardLanguage:
            showLanguagePicker()
        case .notifications, .priceData:
            return
        }
    }
}
