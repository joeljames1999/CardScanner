//
//  CollectionViewController+Search.swift
//  TcgScanner
//
//  Created by Joel James on 06/07/2026.
//

import Foundation
import UIKit

extension CollectionViewController: UISearchResultsUpdating {

    func updateSearchResults(
        for searchController: UISearchController
    ) {

        viewModel.searchText =
            searchController.searchBar.text ?? ""
    }
}

extension CollectionViewController {

    func configureSearchController() {

        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Search Collection"

        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
    }
}
