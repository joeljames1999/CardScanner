//
//  CollectionViewController+ImportExport.swift
//  TcgScanner
//
//  Created by Joel James on 06/07/2026.
//

import Foundation
import UIKit
import UniformTypeIdentifiers

extension CollectionViewController: UIDocumentPickerDelegate {

    @objc
    func exportTapped() {

        guard !viewModel.entries.isEmpty else {

            showAlert(
                title: "Nothing to Export",
                message: "Your collection is empty."
            )

            return
        }

        guard
            let url = CSVService.shared.saveToFile(viewModel.entries)
        else {

            showAlert(
                title: "Export Failed",
                message: "Unable to create CSV."
            )

            return
        }

        let activity = UIActivityViewController(
            activityItems: [url],
            applicationActivities: nil
        )

        present(activity, animated: true)
    }

    @objc
    func importTapped() {

        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: [
                .commaSeparatedText,
                .text
            ]
        )

        picker.delegate = self

        present(picker, animated: true)
    }

    func documentPicker(
        _ controller: UIDocumentPickerViewController,
        didPickDocumentsAt urls: [URL]
    ) {

        guard let url = urls.first else {
            return
        }

        guard url.startAccessingSecurityScopedResource() else {
            return
        }

        showImportLoading()

        DispatchQueue.global(qos: .userInitiated).async {

            defer {
                url.stopAccessingSecurityScopedResource()
            }

            do {

                let csv = try String(
                    contentsOf: url,
                    encoding: .utf8
                )

                let result = CSVService.shared.importCSV(csv)

                DispatchQueue.main.async {

                    CollectionStore.shared.merge(result.entries)

                    self.hideImportLoading()

                    self.viewModel.refresh()

                    self.collectionView.reloadData()

                    self.showAlert(
                        title: "Import Complete",
                        message:
                        "Imported \(result.entries.count) cards" +
                        (result.skippedRows > 0
                         ? "\nSkipped \(result.skippedRows) rows."
                         : "")
                    )
                }

            } catch {

                DispatchQueue.main.async {

                    self.hideImportLoading()

                    self.showAlert(
                        title: "Import Failed",
                        message: error.localizedDescription
                    )
                }
            }
        }
    }
}
