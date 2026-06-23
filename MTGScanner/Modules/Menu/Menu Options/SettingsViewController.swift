//
//  SettingsViewController.swift
//  TcgScanner
//
//  Created by Joel James on 04/06/2026.
//

import Foundation
import UIKit

final class SettingsViewController: UIViewController {
    
    private lazy var tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .insetGrouped)
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tv.register(SettingsOptionCell.self, forCellReuseIdentifier: SettingsOptionCell.reuseID)
        tv.dataSource = self
        tv.delegate   = self
        return tv
    }()
    let cellsName = ["Notifications","PriceData"]
    let cellsDetailLabels : [String: String] = ["Notifications":"Notifications settings", "PriceData": "Price data settings"]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Menu"
        view.backgroundColor = .systemGroupedBackground
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        tableView.reloadData()
        setupLayout()
    }
    
    private func setupLayout() {
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }
}

extension SettingsViewController : UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return cellsName.count
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = SettingsOptionCell(style: .default, reuseIdentifier: SettingsOptionCell.reuseID)
        let cellName = cellsName[indexPath.row]
        cell.setLabels(titleLabel: cellName, detailLabel: cellsDetailLabels[cellName] ?? "")
        return cell
    }
}
