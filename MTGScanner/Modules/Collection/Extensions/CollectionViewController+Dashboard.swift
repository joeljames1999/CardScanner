//
//  CollectionViewController+Dashboard.swift
//  TcgScanner
//
//  Created by Joel James on 06/07/2026.
//

import Foundation
import UIKit

extension CollectionViewController {

    func refreshDashboard() {

        dashboardView.configure(
            cards: viewModel.totalCards,
            value: viewModel.totalValue,
            activeFilters: viewModel.filteredEntries.count
        )
    }
}
