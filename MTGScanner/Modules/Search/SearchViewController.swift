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

        viewModel.$cards
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.collectionView.reloadData()
            }
            .store(in: &cancellables)
    }
}

// MARK: Search

extension CardSearchViewController: UISearchResultsUpdating {

    func updateSearchResults(
        for searchController: UISearchController
    ) {
        let text = searchController.searchBar.text ?? ""

        print("[Search] \(text)")

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
