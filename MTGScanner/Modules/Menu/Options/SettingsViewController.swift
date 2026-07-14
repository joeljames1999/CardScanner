//
//  SettingsViewController.swift
//  TcgScanner
//
//  Created by Joel James on 04/06/2026.
//

import Foundation
import MessageUI
import UIKit

final class SettingsViewController: UIViewController {

    private let feedbackEmailAddress = "joel.james.tcgcompanion@gmail.com"

    private enum Section: Int, CaseIterable {
        case preferences
        case privacy
        case about

        var title: String {
            switch self {
            case .preferences: return "Preferences"
            case .privacy: return "Privacy & Diagnostics"
            case .about: return "About"
            }
        }

        var rows: [Row] {
            switch self {
            case .preferences:
                return [.currency, .cardLanguage]
            case .privacy:
                return [.privacy, .privacyChoices, .diagnostics]
            case .about:
                return [.about, .dataSources, .feedback]
            }
        }
    }

    private enum Row {
        case currency
        case cardLanguage
        case privacy
        case privacyChoices
        case diagnostics
        case about
        case dataSources
        case feedback

        var title: String {
            switch self {
            case .currency: return "Currency"
            case .cardLanguage: return "Card Language"
            case .privacy: return "Privacy"
            case .privacyChoices: return "Ad Privacy Choices"
            case .diagnostics: return "Diagnostics"
            case .about: return "About"
            case .dataSources: return "Data Sources"
            case .feedback: return "Send Feedback"
            }
        }

        var detail: String {
            switch self {
            case .currency:
                let currency = CurrencySettings.shared.preferredCurrency
                return "\(currency.rawValue) - \(currency.displayName)"
            case .cardLanguage:
                let language = CardLanguageSettings.shared.preferredLanguage
                return "\(language.displayName) (\(language.rawValue))"
            case .privacy:
                return "Camera, ads, consent, and analytics status"
            case .privacyChoices:
                return "Manage Google ad privacy options"
            case .diagnostics:
                return "Apple crash reports, no analytics SDK"
            case .about:
                return "App details and release information"
            case .dataSources:
                return "Scryfall data and price notes"
            case .feedback:
                return "joel.james.tcgcompanion@gmail.com"
            }
        }

        var hasDisclosure: Bool {
            switch self {
            default:
                return true
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

    private func row(at indexPath: IndexPath) -> Row {
        Section.allCases[indexPath.section].rows[indexPath.row]
    }

    private func showFeedbackComposer() {
        let subject = "TCGCompanion Feedback"
        let body = feedbackEmailBody()

        if MFMailComposeViewController.canSendMail() {
            let composer = MFMailComposeViewController()
            composer.mailComposeDelegate = self
            composer.setToRecipients([feedbackEmailAddress])
            composer.setSubject(subject)
            composer.setMessageBody(body, isHTML: false)
            present(composer, animated: true)
            return
        }

        var components = URLComponents()
        components.scheme = "mailto"
        components.path = feedbackEmailAddress
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body)
        ]

        if let url = components.url {
            UIApplication.shared.open(url)
        }
    }

    private func feedbackEmailBody() -> String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let build = info?["CFBundleVersion"] as? String ?? "Unknown"
        let device = UIDevice.current
        let screen = view.window?.windowScene?.screen
        let screenBounds = screen?.bounds ?? .zero
        let scale = screen?.scale ?? 1
        let screenSize = "\(Int(screenBounds.width * scale)) x \(Int(screenBounds.height * scale))"
        let locale = Locale.current.identifier

        return """


---
App: TCGCompanion
Version: \(version) (\(build))
iOS: \(device.systemVersion)
Device: \(device.model)
Screen: \(screenSize)
Locale: \(locale)
"""
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

        if let popover = alert.popoverPresentationController {
            let indexPath = IndexPath(row: 1, section: Section.preferences.rawValue)
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

        if let popover = alert.popoverPresentationController {
            let indexPath = IndexPath(row: 0, section: Section.preferences.rawValue)
            popover.sourceView = tableView.cellForRow(at: indexPath) ?? tableView
            popover.sourceRect = tableView.rectForRow(at: indexPath)
        }

        present(alert, animated: true)
    }
}

extension SettingsViewController: UITableViewDataSource, UITableViewDelegate {

    func numberOfSections(in tableView: UITableView) -> Int {
        Section.allCases.count
    }

    func tableView(
        _ tableView: UITableView,
        titleForHeaderInSection section: Int
    ) -> String? {
        Section.allCases[section].title
    }

    func tableView(
        _ tableView: UITableView,
        numberOfRowsInSection section: Int
    ) -> Int {
        Section.allCases[section].rows.count
    }

    func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {

        let cell = SettingsOptionCell(
            style: .default,
            reuseIdentifier: SettingsOptionCell.reuseID
        )

        let row = row(at: indexPath)
        cell.setLabels(
            titleLabel: row.title,
            detailLabel: row.detail
        )
        cell.accessoryType = row.hasDisclosure ? .disclosureIndicator : .none

        return cell
    }

    func tableView(
        _ tableView: UITableView,
        didSelectRowAt indexPath: IndexPath
    ) {

        tableView.deselectRow(at: indexPath, animated: true)

        switch row(at: indexPath) {
        case .currency:
            showCurrencyPicker()
        case .cardLanguage:
            showLanguagePicker()
        case .privacy:
            navigationController?.pushViewController(AppInfoViewController(page: .privacy), animated: true)
        case .privacyChoices:
            AdConsentManager.shared.presentPrivacyOptions(from: self)
        case .diagnostics:
            navigationController?.pushViewController(AppInfoViewController(page: .diagnostics), animated: true)
        case .about:
            navigationController?.pushViewController(AppInfoViewController(page: .about), animated: true)
        case .dataSources:
            navigationController?.pushViewController(AppInfoViewController(page: .dataSources), animated: true)
        case .feedback:
            showFeedbackComposer()
        }
    }
}

extension SettingsViewController: MFMailComposeViewControllerDelegate {

    func mailComposeController(
        _ controller: MFMailComposeViewController,
        didFinishWith result: MFMailComposeResult,
        error: Error?
    ) {
        controller.dismiss(animated: true)
    }
}
