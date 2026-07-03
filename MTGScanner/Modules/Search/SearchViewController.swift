import UIKit
import Combine

final class CardSearchViewController: UIViewController {

    private let viewModel = CardSearchViewModel()
    private var cancellables = Set<AnyCancellable>()

    private lazy var collectionView: UICollectionView = {

        let layout = UICollectionViewFlowLayout()

        let spacing: CGFloat = 12
        let width = (UIScreen.main.bounds.width - 48) / 2

        layout.itemSize = CGSize(
            width: width,
            height: width * 1.55
        )

        layout.minimumLineSpacing = 16
        layout.minimumInteritemSpacing = 16
        

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

    private let headerGlow = UIView()

    private let headerView = UIView()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Search"
        label.font = .systemFont(
            ofSize: 34,
            weight: .bold
        )
        return label
    }()

    private let cardCountLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(
            ofSize: 15,
            weight: .medium
        )
        label.textColor = .secondaryLabel
        return label
    }()

    private let searchField = UISearchBar()
    
    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        title = nil

        view.backgroundColor = .systemBackground

        setupUI()
        bindViewModel()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        let tf = UITextField(frame: .zero)
        view.addSubview(tf)

        tf.becomeFirstResponder()
        tf.resignFirstResponder()

        tf.removeFromSuperview()
    }

    private func setupUI() {

        headerGlow.translatesAutoresizingMaskIntoConstraints = false
        headerGlow.backgroundColor =
        UIColor.accentColor.withAlphaComponent(0.15)

        view.addSubview(headerGlow)

        headerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(headerView)

        [
            titleLabel,
            cardCountLabel,
            searchField,
            collectionView
        ].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }

        searchField.delegate = self
        searchField.placeholder = "Search cards"
        searchField.searchBarStyle = .minimal

        let filterButton = UIButton(
            type: .system
        )

        filterButton.setImage(
            UIImage(
                systemName:
                "line.3.horizontal.decrease.circle.fill"
            ),
            for: .normal
        )

        filterButton.tintColor = UIColor.accentColor

        filterButton.addTarget(
            self,
            action: #selector(openFilters),
            for: .touchUpInside
        )

        searchField.searchTextField.rightView =
            filterButton

        searchField.searchTextField.rightViewMode =
            .always

        NSLayoutConstraint.activate([

            headerGlow.topAnchor.constraint(
                equalTo: view.topAnchor
            ),

            headerGlow.leadingAnchor.constraint(
                equalTo: view.leadingAnchor
            ),

            headerGlow.trailingAnchor.constraint(
                equalTo: view.trailingAnchor
            ),

            headerGlow.heightAnchor.constraint(
                equalToConstant: 220
            ),

            titleLabel.topAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.topAnchor,
                constant: 12
            ),

            titleLabel.leadingAnchor.constraint(
                equalTo: view.leadingAnchor,
                constant: 20
            ),

            cardCountLabel.topAnchor.constraint(
                equalTo: titleLabel.bottomAnchor,
                constant: 4
            ),

            cardCountLabel.leadingAnchor.constraint(
                equalTo: titleLabel.leadingAnchor
            ),

            searchField.topAnchor.constraint(
                equalTo: cardCountLabel.bottomAnchor,
                constant: 16
            ),

            searchField.leadingAnchor.constraint(
                equalTo: view.leadingAnchor,
                constant: 16
            ),

            searchField.trailingAnchor.constraint(
                equalTo: view.trailingAnchor,
                constant: -16
            ),

            collectionView.topAnchor.constraint(
                equalTo: searchField.bottomAnchor,
                constant: 20
            ),

            collectionView.leadingAnchor.constraint(
                equalTo: view.leadingAnchor,
                constant: 16
            ),

            collectionView.trailingAnchor.constraint(
                equalTo: view.trailingAnchor,
                constant: -16
            ),

            collectionView.bottomAnchor.constraint(
                equalTo: view.bottomAnchor
            )
        ])
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        if headerGlow.layer.sublayers?.isEmpty ?? true {

            let gradient = CAGradientLayer()

            gradient.frame = headerGlow.bounds

            gradient.colors = [
                UIColor.accentColor.withAlphaComponent(0.35).cgColor,
                UIColor.clear.cgColor
            ]

            gradient.startPoint = CGPoint(x: 0.5, y: 0)
            gradient.endPoint = CGPoint(x: 0.5, y: 1)

            headerGlow.layer.addSublayer(
                gradient
            )
        }
    }
    
    private func bindViewModel() {
        
        // Update collection view when cards change
        viewModel.$cards
            .receive(on: DispatchQueue.main)
            .sink { [weak self] cards in

                self?.cardCountLabel.text =
                    "\(cards.count) cards"

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

extension CardSearchViewController:
UISearchBarDelegate {

    func searchBar(
        _ searchBar: UISearchBar,
        textDidChange searchText: String
    ) {
        viewModel.searchText = searchText
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
