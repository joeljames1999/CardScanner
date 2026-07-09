//
//  CollectionViewController+Layout.swift
//  TcgScanner
//
//  Created by Joel James on 06/07/2026.
//

import Foundation
import UIKit

extension CollectionViewController {

    func configureLayout() {

        collectionView.translatesAutoresizingMaskIntoConstraints = false
        emptyStateView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(collectionView)
        view.addSubview(emptyStateView)

        NSLayoutConstraint.activate([

            collectionView.topAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.topAnchor
            ),

            collectionView.leadingAnchor.constraint(
                equalTo: view.leadingAnchor
            ),

            collectionView.trailingAnchor.constraint(
                equalTo: view.trailingAnchor
            ),

            collectionView.bottomAnchor.constraint(
                equalTo: view.bottomAnchor
            ),

            emptyStateView.leadingAnchor.constraint(
                equalTo: view.leadingAnchor
            ),

            emptyStateView.trailingAnchor.constraint(
                equalTo: view.trailingAnchor
            ),

            emptyStateView.topAnchor.constraint(
                equalTo: collectionView.topAnchor
            ),

            emptyStateView.bottomAnchor.constraint(
                equalTo: view.bottomAnchor
            )
        ])
    }

    func createLayout() -> UICollectionViewLayout {

        UICollectionViewCompositionalLayout { _, environment in

            let columns = environment.container.effectiveContentSize.width > 700 ? 5 : 3

            let spacing: CGFloat = 10

            let availableWidth =
                environment.container.effectiveContentSize.width

            let totalSpacing =
                spacing * CGFloat(columns + 1)

            let width =
                (availableWidth - totalSpacing) / CGFloat(columns)

            let cardRatio: CGFloat = 63.0 / 88.0

            let footerHeight: CGFloat = 58

            let height =
                (width / cardRatio) + footerHeight

            let itemSize = NSCollectionLayoutSize(
                widthDimension: .absolute(width),
                heightDimension: .absolute(height)
            )

            let item = NSCollectionLayoutItem(layoutSize: itemSize)

            let groupSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1),
                heightDimension: .absolute(height)
            )

            let group = NSCollectionLayoutGroup.horizontal(
                layoutSize: groupSize,
                subitems: Array(repeating: item, count: columns)
            )

            group.interItemSpacing = .fixed(spacing)

            let section = NSCollectionLayoutSection(group: group)

            section.interGroupSpacing = spacing
            section.boundarySupplementaryItems = [
                NSCollectionLayoutBoundarySupplementaryItem(
                    layoutSize: NSCollectionLayoutSize(
                        widthDimension: .fractionalWidth(1),
                        heightDimension: .absolute(342)
                    ),
                    elementKind: UICollectionView.elementKindSectionHeader,
                    alignment: .top
                )
            ]

            section.contentInsets = NSDirectionalEdgeInsets(
                top: spacing,
                leading: spacing,
                bottom: 100,
                trailing: spacing
            )

            return section
        }
    }
}
