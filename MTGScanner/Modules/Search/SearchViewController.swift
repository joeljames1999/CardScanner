import UIKit
import Combine

final class CardSearchViewController: UIViewController {

    private let viewModel = CardSearchViewModel()
    private var cancellables = Set<AnyCancellable>()

    private lazy var collectionView: UICollectionView = {

        let layout = UICollectionViewFlowLayout()

        let spacing: CGFloat = 12
        let width = (UIScreen.main.bounds.width - 36) / 2

        layout.itemSize = CGSize(
            width: width,
            height: width * 1.55
        )

        layout.minimumLineSpacing = spacing
        layout.minimumInteritemSpacing = spacing

        let cv = UICollectionView(
            frame: .zero,
            collectionViewLayout: layout
        )

        cv.translatesAutoresizingMaskIntoConstraints = false
        cv.backgroundColor = .systemBackground

        cv.register(
            CardSearchCell.self,
            forCellWithReuseIdentifier: CardSearchCell.reuseIdentifier
        )

        cv.delegate = self
        cv.dataSource = self

        return cv
    }()

    private let searchController = UISearchController()
    
    // Filter badge
    private lazy var filterButton: UIBarButtonItem = {
        UIBarButtonItem(
            image: UIImage(systemName: "line.3.horizontal.decrease.circle"),
            style: .plain,
            target: self,
            action: #selector(openFilters)
        )
    }()
    
    private lazy var filterBadge: UILabel = {
        let lbl = UILabel()
        lbl.translatesAutoresizingMaskIntoConstraints = false
        lbl.font = .systemFont(ofSize: 10, weight: .bold)
        lbl.textColor = .white
        lbl.textAlignment = .center
        lbl.backgroundColor = .systemRed
        lbl.layer.cornerRadius = 8
        lbl.clipsToBounds = true
        lbl.widthAnchor.constraint(equalToConstant: 16).isActive = true
        lbl.heightAnchor.constraint(equalToConstant: 16).isActive = true
        lbl.isHidden = true
        return lbl
    }()

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Search"

        view.backgroundColor = .systemBackground

        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false

        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Search cards"

        // Add filter button with badge
        navigationItem.rightBarButtonItem = filterButton
        view.addSubview(filterBadge)
        
        NSLayoutConstraint.activate([
            filterBadge.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -16),
            filterBadge.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
        ])

        view.addSubview(collectionView)

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        bindViewModel()
    }

    private func bindViewModel() {
        
        // Update collection view when cards change
        viewModel.$cards
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.collectionView.reloadData()
            }
            .store(in: &cancellables)
        
        // Update badge when filter changes
        viewModel.$filter
            .receive(on: DispatchQueue.main)
            .sink { [weak self] filter in
                self?.updateFilterBadge(filter)
            }
            .store(in: &cancellables)
    }
    
    private func updateFilterBadge(_ filter: SearchFilter) {
        let activeCount = filter.selectedRarities.count +
                         filter.selectedSets.count +
                         filter.selectedManaCosts.count +
                         filter.selectedManaColors.count
        
        if activeCount > 0 {
            filterBadge.text = "\(activeCount)"
            filterBadge.isHidden = false
        } else {
            filterBadge.isHidden = true
        }
    }
    
    @objc private func openFilters() {
        let filterVC = CardFilterViewController()
        filterVC.currentFilter = viewModel.filter
        
        // When filter changes, update view model
        filterVC.onFilterChange = { [weak self] newFilter in
            self?.viewModel.updateFilter(newFilter)
        }
        
        let nav = UINavigationController(rootViewController: filterVC)
        if let sheet = nav.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
        present(nav, animated: true)
    }
}

// MARK: Search

extension CardSearchViewController: UISearchResultsUpdating {

    func updateSearchResults(
        for searchController: UISearchController
    ) {
        let text = searchController.searchBar.text ?? ""
        viewModel.searchText = text
    }
}

// MARK: Collection View

extension CardSearchViewController:
UICollectionViewDataSource,
UICollectionViewDelegate {

    func collectionView(
        _ collectionView: UICollectionView,
        numberOfItemsInSection section: Int
    ) -> Int {

        viewModel.cards.count
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {

        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: CardSearchCell.reuseIdentifier,
            for: indexPath
        ) as! CardSearchCell

        cell.configure(
            with: viewModel.cards[indexPath.item]
        )

        return cell
    }

    func collectionView(
        _ collectionView: UICollectionView,
        didSelectItemAt indexPath: IndexPath
    ) {

        let card = viewModel.cards[indexPath.item]

        let vc = CardDetailViewController(
            card: card
        )

        navigationController?.pushViewController(
            vc,
            animated: true
        )
    }
}
