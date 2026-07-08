//
//  CollectionViewController+Actions.swift
//  TcgScanner
//
//  Created by Joel James on 06/07/2026.
//

import Foundation
import UIKit

extension CollectionViewController {

    func showSortMenu() {

        let alert = UIAlertController(
            title: "Sort Collection",
            message: nil,
            preferredStyle: .actionSheet
        )

        alert.addAction(UIAlertAction(
            title: "Name",
            style: .default
        ) { _ in
            CollectionStore.shared.sort(by: .name)
            self.viewModel.refresh()
        })

        alert.addAction(UIAlertAction(
            title: "Set",
            style: .default
        ) { _ in
            CollectionStore.shared.sort(by: .set)
            self.viewModel.refresh()
        })

        alert.addAction(UIAlertAction(
            title: "Price",
            style: .default
        ) { _ in
            CollectionStore.shared.sort(by: .price)
            self.viewModel.refresh()
        })

        alert.addAction(UIAlertAction(
            title: "Recently Added",
            style: .default
        ) { _ in
            CollectionStore.shared.sort(by: .date)
            self.viewModel.refresh()
        })

        alert.addAction(
            UIAlertAction(
                title: "Cancel",
                style: .cancel
            )
        )

        present(alert, animated: true)
    }

    func openFilters() {

        let vc = CardFilterViewController()

        vc.currentFilter = viewModel.filter
        vc.showsFoilFilter = true
        vc.isFoilFilterSelected = viewModel.showFoilsOnly

        vc.onFilterChange = { [weak self] filter in

            self?.viewModel.updateFilter(filter)
        }

        vc.onFoilFilterChange = { [weak self] showFoilsOnly in

            self?.viewModel.updateFoilsOnly(showFoilsOnly)
        }

        let nav = UINavigationController(rootViewController: vc)

        if let sheet = nav.sheetPresentationController {

            sheet.detents = [
                .medium(),
                .large()
            ]

            sheet.prefersGrabberVisible = true
        }

        present(nav, animated: true)
    }
}
