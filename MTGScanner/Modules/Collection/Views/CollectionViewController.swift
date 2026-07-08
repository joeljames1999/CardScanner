//
//  CollectionViewController.swift
//

import UIKit
import Combine

final class CollectionViewController: UIViewController {

    // MARK: ViewModel

    let viewModel = CollectionViewModel()
    var cancellables = Set<AnyCancellable>()

    // MARK: UI

    let dashboardView = CollectionDashboardView()
    let emptyStateView = CollectionEmptyStateView()

    lazy var collectionView: UICollectionView = {

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

    lazy var searchController: UISearchController = {

        let search = UISearchController(searchResultsController: nil)

        search.searchResultsUpdater = self
        search.obscuresBackgroundDuringPresentation = false
        search.searchBar.placeholder = "Search Collection"

        return search
    }()

    // MARK: Loading

    let loadingView = UIVisualEffectView(
        effect: UIBlurEffect(style: .systemMaterial)
    )

    let spinner = UIActivityIndicatorView(style: .large)

    let loadingLabel: UILabel = {

        let label = UILabel()

        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .preferredFont(forTextStyle: .headline)
        label.text = "Importing Collection..."

        return label

    }()

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        print("APP STARTED")
        title = "Collection"
        view.backgroundColor = .systemBackground

        navigationItem.largeTitleDisplayMode = .never
        navigationItem.searchController = searchController

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "ellipsis.circle"),
            menu: makeMenu()
        )

        configureLayout()
        bindViewModel()
        configureDashboardActions()
        configureEmptyStateActions()
        viewModel.startObservingCollectionChanges()
        viewModel.refresh()
    }
}

private extension CollectionViewController {

    func configureDashboardActions() {

        dashboardView.onSort = { [weak self] in
            self?.showSortMenu()
        }

        dashboardView.onFilter = { [weak self] in
            self?.openFilters()
        }
    }

    func configureEmptyStateActions() {

        emptyStateView.onImport = { [weak self] in
            self?.importTapped()
        }
    }

    func prefetchVisibleThumbnailImages(from entries: [CollectionEntry]) {

        let urls = entries
            .prefix(36)
            .compactMap(\.imageURL)

        guard !urls.isEmpty else {
            return
        }

        Task {
            await ImageLoader.shared.prefetch(Array(urls))
        }
    }

    private func bindViewModel() {

        viewModel.$filteredEntries
            .receive(on: DispatchQueue.main)
            .sink { [weak self] entries in

                guard let self else { return }

                collectionView.reloadData()
                prefetchVisibleThumbnailImages(from: entries)
                emptyStateView.isHidden = !(viewModel.totalCards == 0)

                dashboardView.configure(
                    cards: viewModel.totalCards,
                    value: viewModel.totalValue,
                    activeFilters: viewModel.activeFilterCount
                )
            }
            .store(in: &cancellables)

        viewModel.$filter
            .receive(on: DispatchQueue.main)
            .sink { [weak self] filter in

                guard let self else { return }

                dashboardView.updateFilterBadge(filter)

                dashboardView.configure(
                    cards: viewModel.totalCards,
                    value: viewModel.totalValue,
                    activeFilters: viewModel.activeFilterCount
                )
            }
            .store(in: &cancellables)
    }
}
