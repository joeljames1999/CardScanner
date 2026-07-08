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

        cell.configure(with: entry)

        return cell
    }

    func collectionView(
        _ collectionView: UICollectionView,
        didSelectItemAt indexPath: IndexPath
    ) {
        let entry = viewModel.filteredEntries[indexPath.item]

        guard let card = viewModel.card(for: entry) else {
            return
        }

        let vc = CardDetailViewController(
            card: card,
            actionMode: .addToCollection
        )

        navigationController?.pushViewController(
            vc,
            animated: true
        )
    }
}
