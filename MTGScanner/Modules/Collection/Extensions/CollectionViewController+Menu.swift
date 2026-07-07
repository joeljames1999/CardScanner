//
//  CollectionViewController+Menu.swift
//  TcgScanner
//
//  Created by Joel James on 06/07/2026.
//

import Foundation
import UIKit

extension CollectionViewController {

    func makeMenu() -> UIMenu {

        UIMenu(children: [

            UIAction(
                title: "Import Collection",
                image: UIImage(systemName: "square.and.arrow.down")
            ) { [weak self] _ in

                self?.importTapped()

            },

            UIAction(
                title: "Export Collection",
                image: UIImage(systemName: "square.and.arrow.up")
            ) { [weak self] _ in

                self?.exportTapped()

            },

            UIDeferredMenuElement.uncached { completion in

                completion([

                    UIAction(
                        title: "Settings",
                        image: UIImage(systemName: "gear")
                    ) { _ in

                    }

                ])
            }
        ])
    }
}
