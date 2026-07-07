//
//  CollectionViewController+Loading.swift
//  TcgScanner
//
//  Created by Joel James on 06/07/2026.
//

import Foundation
import UIKit

extension CollectionViewController {

    func showImportLoading() {

        loadingView.translatesAutoresizingMaskIntoConstraints = false
        spinner.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(loadingView)

        loadingView.contentView.addSubview(spinner)
        loadingView.contentView.addSubview(loadingLabel)

        NSLayoutConstraint.activate([

            loadingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            loadingView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            loadingView.topAnchor.constraint(equalTo: view.topAnchor),
            loadingView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            spinner.centerXAnchor.constraint(equalTo: loadingView.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: loadingView.centerYAnchor),

            loadingLabel.topAnchor.constraint(
                equalTo: spinner.bottomAnchor,
                constant: 20
            ),

            loadingLabel.centerXAnchor.constraint(
                equalTo: loadingView.centerXAnchor
            )
        ])

        spinner.startAnimating()
    }

    func hideImportLoading() {

        spinner.stopAnimating()
        loadingView.removeFromSuperview()
    }
}
