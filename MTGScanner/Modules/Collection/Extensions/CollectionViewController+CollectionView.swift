//
//  CollectionViewController+CollectionView.swift
//  TcgScanner
//
//  Created by Joel James on 06/07/2026.
//

import Foundation
import UIKit

extension CollectionViewController:
UICollectionViewDataSource,
UICollectionViewDelegate {

    func numberOfSections(
        in collectionView: UICollectionView
    ) -> Int {

        1
    }

    func collectionView(
        _ collectionView: UICollectionView,
        numberOfItemsInSection section: Int
    ) -> Int {

        viewModel.filteredEntries.count
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {

        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: CollectionCardCell.reuseIdentifier,
            for: indexPath
        ) as? CollectionCardCell
        else {

            return UICollectionViewCell()
        }

        let entry = viewModel.filteredEntries[indexPath.item]

        cell.configure(
            with: entry,
            card: viewModel.card(for: entry)
        )

        return cell
    }

    func collectionView(
        _ collectionView: UICollectionView,
        viewForSupplementaryElementOfKind kind: String,
        at indexPath: IndexPath
    ) -> UICollectionReusableView {

        guard kind == UICollectionView.elementKindSectionHeader,
              let header = collectionView.dequeueReusableSupplementaryView(
                ofKind: kind,
                withReuseIdentifier: CollectionDashboardHeaderView.reuseIdentifier,
                for: indexPath
              ) as? CollectionDashboardHeaderView
        else {
            return UICollectionReusableView()
        }

        header.embed(dashboardView)
        return header
    }

    func collectionView(
        _ collectionView: UICollectionView,
        didSelectItemAt indexPath: IndexPath
    ) {
        let entry = viewModel.filteredEntries[indexPath.item]
        showEditOverlay(for: entry, card: viewModel.card(for: entry))
    }

    private func forcedFinish(for entry: CollectionEntry, card: MTGCard?) -> CardFinish? {
        guard let finishes = card?.availableFinishes, !finishes.isEmpty else {
            return nil
        }

        let canToggleFoil = finishes.contains(.nonfoil) && finishes.contains(.foil)
        guard !canToggleFoil else {
            return nil
        }

        if finishes.contains(entry.resolvedFinish) {
            return entry.resolvedFinish
        }

        return finishes.first
    }

    private func loadPrintings(named name: String) async -> [MTGCard] {
        await Task.detached {
            (try? AppDatabase.shared.cards.allPrintings(named: name)) ?? []
        }.value
    }

    private func presentSetPicker(for entry: CollectionEntry, printings: [MTGCard]) {
        guard printings.count > 1, presentedViewController == nil else { return }

        let pickerVC = SetPickerViewController(
            cardName: entry.name,
            printings: printings
        )

        pickerVC.onSelect = { [weak self] selectedCard in
            CollectionStore.shared.updatePrinting(id: entry.id, card: selectedCard)
            self?.viewModel.refresh()
        }

        let nav = UINavigationController(rootViewController: pickerVC)
        if let sheet = nav.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
            sheet.prefersScrollingExpandsWhenScrolledToEdge = true
        }

        present(nav, animated: true)
    }

    private func showEditOverlay(for entry: CollectionEntry, card: MTGCard?) {
        editOverlayView?.dismiss(animated: false)

        let overlay = CollectionEntryEditOverlayView(entry: entry, card: card)
        var hasPendingCollectionUpdates = false

        if let forcedFinish = forcedFinish(for: entry, card: card),
           entry.resolvedFinish != forcedFinish {
            hasPendingCollectionUpdates = true
            CollectionStore.shared.updateFinish(id: entry.id, finish: forcedFinish, notify: false)
        }

        editOverlayView = overlay

        overlay.onDismiss = { [weak self, weak overlay] in
            guard self?.editOverlayView === overlay else { return }
            self?.editOverlayView = nil

            if hasPendingCollectionUpdates {
                CollectionStore.shared.publishChanges()
            }
        }

        overlay.onQuantityChange = { quantity in
            hasPendingCollectionUpdates = true
            CollectionStore.shared.updateCount(id: entry.id, count: quantity, notify: false)
        }

        overlay.onConditionChange = { condition in
            hasPendingCollectionUpdates = true
            CollectionStore.shared.updateCondition(id: entry.id, condition: condition, notify: false)
        }

        overlay.onFoilChange = { isFoil in
            hasPendingCollectionUpdates = true
            let finish: CardFinish = isFoil ? .foil : .nonfoil
            CollectionStore.shared.updateFinish(id: entry.id, finish: finish, notify: false)
        }

        overlay.onRemoveAll = { [weak overlay] in
            hasPendingCollectionUpdates = true
            CollectionStore.shared.remove(id: entry.id, notify: false)
            overlay?.dismiss()
        }

        overlay.onOpenDetails = { [weak self, weak overlay] in
            guard let self, let card else { return }

            overlay?.dismiss(animated: false)

            let vc = CardDetailViewController(
                card: card,
                actionMode: .addToCollection
            )

            navigationController?.pushViewController(vc, animated: true)
        }

        var availablePrintings: [MTGCard] = []
        overlay.onChangePrinting = { [weak self, weak overlay] in
            guard let self, availablePrintings.count > 1 else { return }

            overlay?.dismiss(animated: false)
            presentSetPicker(for: entry, printings: availablePrintings)
        }

        guard let parentView = tabBarController?.view ?? view else {
            return
        }

        parentView.addSubview(overlay)

        var constraints = [
            overlay.topAnchor.constraint(equalTo: parentView.topAnchor),
            overlay.leadingAnchor.constraint(equalTo: parentView.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: parentView.trailingAnchor)
        ]

        constraints.append(overlay.bottomAnchor.constraint(equalTo: parentView.bottomAnchor))

        NSLayoutConstraint.activate(constraints)

        overlay.animateIn()

        Task { [weak overlay] in
            let printings = await loadPrintings(named: entry.name)

            await MainActor.run {
                availablePrintings = printings
                overlay?.setChangePrintingAvailable(printings.count > 1)
            }
        }
    }
}

final class CollectionDashboardHeaderView: UICollectionReusableView {

    static let reuseIdentifier = "CollectionDashboardHeaderView"

    func embed(_ dashboardView: CollectionDashboardView) {
        if dashboardView.superview !== self {
            dashboardView.removeFromSuperview()
            dashboardView.translatesAutoresizingMaskIntoConstraints = false
            addSubview(dashboardView)

            NSLayoutConstraint.activate([
                dashboardView.topAnchor.constraint(equalTo: topAnchor),
                dashboardView.leadingAnchor.constraint(equalTo: leadingAnchor),
                dashboardView.trailingAnchor.constraint(equalTo: trailingAnchor),
                dashboardView.bottomAnchor.constraint(equalTo: bottomAnchor)
            ])
        }
    }
}
