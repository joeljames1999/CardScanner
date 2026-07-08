//
//  CollectionViewController+Alerts.swift
//  TcgScanner
//
//  Created by Joel James on 06/07/2026.
//

import Foundation
import UIKit

extension CollectionViewController {

    func showAlert(
        title: String,
        message: String
    ) {

        let alert = UIAlertController(
            title: title,
            message: message,
            preferredStyle: .alert
        )

        alert.addAction(
            UIAlertAction(
                title: "OK",
                style: .default
            )
        )

        present(
            alert,
            animated: true
        )
    }

    func confirmDeleteCollection() {

        guard !CollectionStore.shared.entries.isEmpty else {
            showAlert(
                title: "Collection Empty",
                message: "There are no cards to delete."
            )
            return
        }

        let alert = UIAlertController(
            title: "Delete Collection",
            message: "This will permanently delete every card in your collection. Type DELETE to confirm.",
            preferredStyle: .alert
        )

        alert.addTextField { textField in
            textField.placeholder = "DELETE"
            textField.autocapitalizationType = .allCharacters
            textField.autocorrectionType = .no
            textField.clearButtonMode = .whileEditing
        }

        let deleteAction = UIAlertAction(
            title: "Delete",
            style: .destructive
        ) { [weak self] _ in
            CollectionStore.shared.removeAll()
            Task {
                await ImageLoader.shared.clear()
            }
            self?.viewModel.refresh()
            self?.collectionView.reloadData()
        }

        deleteAction.isEnabled = false

        alert.addAction(
            UIAlertAction(
                title: "Cancel",
                style: .cancel
            )
        )

        alert.addAction(deleteAction)

        alert.textFields?.first?.addAction(
            UIAction { _ in
                deleteAction.isEnabled = alert.textFields?.first?.text == "DELETE"
            },
            for: .editingChanged
        )

        present(
            alert,
            animated: true
        )
    }
}
