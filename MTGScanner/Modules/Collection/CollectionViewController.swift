//
//  CollectionViewController.swift
//  TcgScanner
//

import UIKit
import Combine
import UniformTypeIdentifiers

final class CollectionViewController: UIViewController {

    // MARK: - ViewModel

    private let viewModel = CollectionViewModel()
    private var cancellables = Set<AnyCancellable>()
    private let dashboardView = CollectionDashboardView()

    // MARK: - UI

    private lazy var collectionView: UICollectionView = {

        let view = UICollectionView(
            frame: .zero,
            collectionViewLayout: createLayout()
        )

        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .systemBackground
        view.alwaysBounceVertical = true

        view.register(
            CollectionCardCell.self,
            forCellWithReuseIdentifier: CollectionCardCell.reuseIdentifier
        )

        view.delegate = self
        view.dataSource = self

        return view
    }()

    private lazy var searchController: UISearchController = {

        let search = UISearchController(searchResultsController: nil)

        search.searchResultsUpdater = self
        search.obscuresBackgroundDuringPresentation = false
        search.searchBar.placeholder = "Search Collection"

        return search
    }()

    private lazy var emptyStateLabel: UILabel = {

        let label = UILabel()

        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.numberOfLines = 0
        label.font = .preferredFont(forTextStyle: .headline)
        label.textColor = .secondaryLabel

        label.text =
        """
        Your collection is empty.

        Scan cards or import a CSV to get started.
        """

        label.isHidden = true

        return label

    }()

    // MARK: Import Overlay

    private let loadingView = UIVisualEffectView(
        effect: UIBlurEffect(style: .systemMaterial)
    )

    private let spinner = UIActivityIndicatorView(style: .large)

    private let loadingLabel: UILabel = {

        let label = UILabel()

        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .preferredFont(forTextStyle: .headline)
        label.text = "Importing Collection..."

        return label

    }()

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground

        navigationItem.largeTitleDisplayMode = .never
        navigationItem.title = nil
        navigationItem.searchController = searchController

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "ellipsis.circle.fill"),
            menu: makeMenu()
        )
        
        configureLayout()
        

        dashboardView.onSort = { [weak self] in
            self?.showSortMenu()
        }

        dashboardView.onFilter = { [weak self] in
            self?.showFilterMenu()
        }

//        dashboardView.onSearch = { [weak self] in
//            self?.navigationItem.searchController?.searchBar.becomeFirstResponder()
//        }
        
        bindViewModel()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        viewModel.refresh()
    }

    // MARK: Layout

    private func configureLayout() {

        dashboardView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        emptyStateLabel.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(dashboardView)
        view.addSubview(collectionView)
        view.addSubview(emptyStateLabel)

        NSLayoutConstraint.activate([

            dashboardView.topAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.topAnchor
            ),

            dashboardView.leadingAnchor.constraint(
                equalTo: view.leadingAnchor
            ),

            dashboardView.trailingAnchor.constraint(
                equalTo: view.trailingAnchor
            ),

            dashboardView.bottomAnchor.constraint(
                equalTo: collectionView.topAnchor
            ),
            
            collectionView.topAnchor.constraint(
                equalTo: dashboardView.bottomAnchor
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

            emptyStateLabel.centerXAnchor.constraint(
                equalTo: collectionView.centerXAnchor
            ),

            emptyStateLabel.centerYAnchor.constraint(
                equalTo: collectionView.centerYAnchor
            ),

            emptyStateLabel.leadingAnchor.constraint(
                equalTo: view.leadingAnchor,
                constant: 32
            ),

            emptyStateLabel.trailingAnchor.constraint(
                equalTo: view.trailingAnchor,
                constant: -32
            )
        ])
    }

    // MARK: ViewModel

    private func bindViewModel() {

        viewModel.$filteredEntries
            .receive(on: DispatchQueue.main)
            .sink { [weak self] entries in

                guard let self else { return }

                self.emptyStateLabel.isHidden = !entries.isEmpty

                self.collectionView.reloadData()

                self.refreshDashboard()
            }
            .store(in: &cancellables)
    }

    // MARK: Layout

    private func createLayout() -> UICollectionViewLayout {
        CollectionLayoutFactory.makeCollectionLayout()
    }
    
    private func refreshDashboard() {

        let summary = CollectionSummary(entries: viewModel.filteredEntries)
        dashboardView.configure(
            cards: summary.totalCards,
            value: summary.totalValue
        )
    }
    
    private func makeMenu() -> UIMenu {

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

            UIMenu(
                title: "",
                options: .displayInline,
                children: [

                    UIAction(
                        title: "Settings",
                        image: UIImage(systemName: "gear")
                    ) { _ in

                    }
                ]
            )
        ])
    }
    
}

// MARK: - Collection View

extension CollectionViewController: UICollectionViewDataSource {
    
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
        
        guard
            let cell = collectionView.dequeueReusableCell(
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
}

// MARK: - Delegate

extension CollectionViewController: UICollectionViewDelegate {

    func collectionView(
        _ collectionView: UICollectionView,
        didSelectItemAt indexPath: IndexPath
    ) {

        let entry = viewModel.filteredEntries[indexPath.item]

        guard
            let card = CardDatabaseService.shared.findCard(
                named: entry.name,
                set: entry.setCode,
                collectorNumber: entry.collectorNumber
            )
        else {
            return
        }

        let vc = CardDetailViewController(card: card)

        navigationController?.pushViewController(
            vc,
            animated: true
        )
    }
}

// MARK: - Search

extension CollectionViewController: UISearchResultsUpdating {

    func updateSearchResults(
        for searchController: UISearchController
    ) {

        viewModel.searchText =
            searchController.searchBar.text ?? ""
    }
}

// MARK: - Dashboard Actions

private extension CollectionViewController {

    func showSortMenu() {

        let alert = UIAlertController(
            title: "Sort Collection",
            message: nil,
            preferredStyle: .actionSheet
        )

        alert.addAction(
            UIAlertAction(
                title: "Name",
                style: .default
            ) { _ in

                CollectionStore.shared.sort(by: .name)
            }
        )

        alert.addAction(
            UIAlertAction(
                title: "Set",
                style: .default
            ) { _ in

                CollectionStore.shared.sort(by: .set)
            }
        )

        alert.addAction(
            UIAlertAction(
                title: "Price",
                style: .default
            ) { _ in

                CollectionStore.shared.sort(by: .price)
            }
        )

        alert.addAction(
            UIAlertAction(
                title: "Recently Added",
                style: .default
            ) { _ in

                CollectionStore.shared.sort(by: .date)
            }
        )

        alert.addAction(
            UIAlertAction(
                title: "Cancel",
                style: .cancel
            )
        )

        present(
            alert,
            animated: true
        )
    }

    func showFilterMenu() {

        let alert = UIAlertController(
            title: "Filter",
            message: "Coming Soon",
            preferredStyle: .alert
        )

        alert.addAction(
            UIAlertAction(
                title: "OK",
                style: .default
            )
        )

        present(
            alert,
            animated: true
        )
    }
}

// MARK: - Import / Export

extension CollectionViewController: UIDocumentPickerDelegate {

    @objc
    func exportTapped() {

        guard !viewModel.entries.isEmpty else {

            showAlert(
                title: "Nothing to Export",
                message: "Your collection is empty."
            )

            return
        }

        guard
            let url = CSVService.shared.saveToFile(
                viewModel.entries
            )
        else {

            showAlert(
                title: "Export Failed",
                message: "Unable to create CSV."
            )

            return
        }

        let activity = UIActivityViewController(
            activityItems: [url],
            applicationActivities: nil
        )

        present(
            activity,
            animated: true
        )
    }

    @objc
    func importTapped() {

        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: [
                .commaSeparatedText,
                .text
            ]
        )

        picker.delegate = self

        present(
            picker,
            animated: true
        )
    }

    func documentPicker(
        _ controller: UIDocumentPickerViewController,
        didPickDocumentsAt urls: [URL]
    ) {

        guard let url = urls.first else {
            return
        }

        guard url.startAccessingSecurityScopedResource() else {
            return
        }

        print(url)

        showImportLoading()

        DispatchQueue.global(qos: .userInitiated).async {

            defer {
                url.stopAccessingSecurityScopedResource()
            }

            do {

                let csv = try String(contentsOf: url, encoding: .utf8)

                let result = CSVService.shared.importCSV(csv)

                CollectionStore.shared.merge(result.entries)

                DispatchQueue.main.async {
                    self.hideImportLoading()
                    self.viewModel.refresh()
                    self.collectionView.reloadData()
                    // show alert...
                }

            } catch {

                DispatchQueue.main.async {

                    self.hideImportLoading()

                    self.showAlert(
                        title: "Import Failed",
                        message: error.localizedDescription
                    )
                }
            }
        }
    }
}

// MARK: - Loading

private extension CollectionViewController {

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

// MARK: - Alerts

private extension CollectionViewController {

    func showAlert(
        title: String,
        message: String
    ) {

        let alert = UIAlertController(
            title: title,
            message: message,
            preferredStyle: .alert
        )

        alert.addAction(
            UIAlertAction(
                title: "OK",
                style: .default
            )
        )

        present(
            alert,
            animated: true
        )
    }
}
