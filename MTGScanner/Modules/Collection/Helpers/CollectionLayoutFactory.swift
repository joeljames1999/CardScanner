//
//  CollectionLayoutFactory.swift
//  TcgScanner
//
//  Created by Joel James on 06/07/2026.
//

import Foundation
import UIKit

enum CollectionLayoutFactory {

    static func makeCollectionLayout() -> UICollectionViewLayout {

        UICollectionViewCompositionalLayout { _, environment in

            let width = environment.container.effectiveContentSize.width

            let isPad = width > 700
            let columns = isPad ? 5 : 3

            let spacing: CGFloat = 10

            let totalSpacing = spacing * CGFloat(columns + 1)
            let availableWidth = width - totalSpacing

            let itemWidth = availableWidth / CGFloat(columns)

            // MTG card ratio (63x88)
            let cardRatio: CGFloat = 63.0 / 88.0

            let itemHeight = (itemWidth / cardRatio) + 42

            let itemSize = NSCollectionLayoutSize(
                widthDimension: .absolute(itemWidth),
                heightDimension: .absolute(itemHeight)
            )

            let item = NSCollectionLayoutItem(layoutSize: itemSize)

            let groupSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1),
                heightDimension: .absolute(itemHeight)
            )

            let group = NSCollectionLayoutGroup.horizontal(
                layoutSize: groupSize,
                subitems: Array(repeating: item, count: columns)
            )

            group.interItemSpacing = .fixed(spacing)

            let section = NSCollectionLayoutSection(group: group)

            section.interGroupSpacing = spacing
            section.contentInsets = NSDirectionalEdgeInsets(
                top: spacing,
                leading: spacing,
                bottom: spacing,
                trailing: spacing
            )

            return section
        }
    }
}
