import UIKit
import Combine

final class CardSearchViewController: UIViewController {

    private let viewModel = SearchViewModel()
    private var cancellables = Set<AnyCancellable>()

    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        let width: CGFloat = 160

        layout.itemSize = CGSize(
            width: width,
            height: width * 1.55
        )
        layout.minimumLineSpacing = 16
        layout.minimumInteritemSpacing = 16

        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.translatesAutoresizingMaskIntoConstraints = false
        cv.backgroundColor = .systemBackground
        cv.keyboardDismissMode = .onDrag
        cv.register(
            CardSearchCell.self,
            forCellWithReuseIdentifier: CardSearchCell.reuseIdentifier
        )
        cv.delegate = self
        cv.dataSource = self
        return cv
    }()

    private let headerView: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 28
        view.layer.cornerCurve = .continuous
        view.layer.masksToBounds = true
        return view
    }()

    private let headerGradientLayer = CAGradientLayer()

    private let headerIconContainer: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.white.withAlphaComponent(0.18)
        view.layer.cornerRadius = 20
        view.layer.cornerCurve = .continuous
        return view
    }()

    private let headerIconView: UIImageView = {
        let imageView = UIImageView(image: UIImage(systemName: "magnifyingglass.circle.fill"))
        imageView.tintColor = .white
        imageView.contentMode = .scaleAspectFit
        imageView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(
            pointSize: 28,
            weight: .semibold
        )
        return imageView
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Find cards"
        label.font = .systemFont(ofSize: 30, weight: .bold)
        label.textColor = .white
        label.numberOfLines = 1
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.82
        return label
    }()

    private let cardCountLabel: UILabel = {
        let label = UILabel()
        label.text = "Search by name, set, type, or text"
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = UIColor.white.withAlphaComponent(0.78)
        label.numberOfLines = 1
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.8
        return label
    }()

    private let searchField: UISearchBar = {
        let searchBar = UISearchBar()
        searchBar.placeholder = "Search cards"
        searchBar.searchBarStyle = .minimal
        searchBar.returnKeyType = .search
        return searchBar
    }()

    private lazy var filterButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.image = UIImage(systemName: "line.3.horizontal.decrease.circle.fill")
        config.cornerStyle = .capsule
        config.baseBackgroundColor = UIColor.brandBlue
        config.baseForegroundColor = .white
        config.contentInsets = NSDirectionalEdgeInsets(
            top: 9,
            leading: 11,
            bottom: 9,
            trailing: 11
        )

        let button = UIButton(configuration: config)
        button.addTarget(
            self,
            action: #selector(openFilters),
            for: .touchUpInside
        )
        button.accessibilityLabel = "Filters"
        return button
    }()

    private lazy var filterBadge: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 10, weight: .bold)
        label.textColor = .white
        label.textAlignment = .center
        label.backgroundColor = .systemRed
        label.layer.cornerRadius = 8
        label.clipsToBounds = true
        label.isHidden = true
        return label
    }()

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        title = nil
        view.backgroundColor = .systemBackground

        setupUI()
        bindViewModel()
        configureKeyboardDismissal()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        let tf = UITextField(frame: .zero)
        view.addSubview(tf)
        tf.becomeFirstResponder()
        tf.resignFirstResponder()
        tf.removeFromSuperview()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        headerGradientLayer.frame = headerView.bounds
        updateCollectionLayout()
    }

    private func updateCollectionLayout() {
        guard let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout else {
            return
        }

        let availableWidth = collectionView.bounds.width
        guard availableWidth > 0 else {
            return
        }

        let itemWidth = floor((availableWidth - layout.minimumInteritemSpacing) / 2)
        let itemSize = CGSize(
            width: itemWidth,
            height: itemWidth * 1.55
        )

        guard layout.itemSize != itemSize else {
            return
        }

        layout.itemSize = itemSize
        layout.invalidateLayout()
    }

    private func setupUI() {
        headerView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(headerView)
        view.addSubview(collectionView)

        configureHeaderGradient()
        setupHeaderContent()

        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.topAnchor,
                constant: 16
            ),
            headerView.leadingAnchor.constraint(
                equalTo: view.leadingAnchor,
                constant: 20
            ),
            headerView.trailingAnchor.constraint(
                equalTo: view.trailingAnchor,
                constant: -20
            ),

            collectionView.topAnchor.constraint(
                equalTo: headerView.bottomAnchor,
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
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func setupHeaderContent() {
        let titleStack = UIStackView(arrangedSubviews: [
            titleLabel,
            cardCountLabel
        ])
        titleStack.axis = .vertical
        titleStack.spacing = 4

        let topRow = UIStackView(arrangedSubviews: [
            headerIconContainer,
            titleStack
        ])
        topRow.axis = .horizontal
        topRow.alignment = .center
        topRow.spacing = 14

        let searchRow = UIView()
        searchRow.backgroundColor = .white
        searchRow.layer.cornerRadius = 18
        searchRow.layer.cornerCurve = .continuous
        searchRow.layer.shadowColor = UIColor.black.cgColor
        searchRow.layer.shadowOpacity = 0.12
        searchRow.layer.shadowRadius = 14
        searchRow.layer.shadowOffset = CGSize(width: 0, height: 6)

        let contentStack = UIStackView(arrangedSubviews: [
            topRow,
            searchRow
        ])
        contentStack.axis = .vertical
        contentStack.spacing = 20
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        headerIconContainer.translatesAutoresizingMaskIntoConstraints = false
        headerIconView.translatesAutoresizingMaskIntoConstraints = false
        searchRow.translatesAutoresizingMaskIntoConstraints = false
        searchField.translatesAutoresizingMaskIntoConstraints = false
        filterButton.translatesAutoresizingMaskIntoConstraints = false

        headerIconContainer.addSubview(headerIconView)
        searchRow.addSubview(searchField)
        searchRow.addSubview(filterButton)
        filterButton.addSubview(filterBadge)
        headerView.addSubview(contentStack)

        searchField.delegate = self
        styleSearchField()

        NSLayoutConstraint.activate([
            headerIconContainer.widthAnchor.constraint(equalToConstant: 48),
            headerIconContainer.heightAnchor.constraint(equalToConstant: 48),

            headerIconView.centerXAnchor.constraint(equalTo: headerIconContainer.centerXAnchor),
            headerIconView.centerYAnchor.constraint(equalTo: headerIconContainer.centerYAnchor),
            headerIconView.widthAnchor.constraint(equalToConstant: 32),
            headerIconView.heightAnchor.constraint(equalToConstant: 32),

            searchRow.heightAnchor.constraint(equalToConstant: 60),

            searchField.leadingAnchor.constraint(equalTo: searchRow.leadingAnchor, constant: 4),
            searchField.topAnchor.constraint(equalTo: searchRow.topAnchor, constant: 4),
            searchField.bottomAnchor.constraint(equalTo: searchRow.bottomAnchor, constant: -4),
            searchField.trailingAnchor.constraint(equalTo: filterButton.leadingAnchor, constant: -2),

            filterButton.trailingAnchor.constraint(equalTo: searchRow.trailingAnchor, constant: -10),
            filterButton.centerYAnchor.constraint(equalTo: searchRow.centerYAnchor),
            filterButton.widthAnchor.constraint(equalToConstant: 42),
            filterButton.heightAnchor.constraint(equalToConstant: 42),

            filterBadge.topAnchor.constraint(equalTo: filterButton.topAnchor, constant: -4),
            filterBadge.trailingAnchor.constraint(equalTo: filterButton.trailingAnchor, constant: 4),
            filterBadge.widthAnchor.constraint(equalToConstant: 16),
            filterBadge.heightAnchor.constraint(equalToConstant: 16),

            contentStack.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 18),
            contentStack.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 18),
            contentStack.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -18),
            contentStack.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -18)
        ])
    }

    private func styleSearchField() {
        searchField.backgroundImage = UIImage()
        searchField.searchTextField.backgroundColor = .clear
        searchField.searchTextField.font = .systemFont(ofSize: 17, weight: .semibold)
        searchField.searchTextField.textColor = .label
        searchField.searchTextField.tintColor = .brandBlue
        searchField.searchTextField.leftView?.tintColor = .brandBlue
        searchField.searchTextField.clearButtonMode = .whileEditing
    }

    private func configureHeaderGradient() {
        headerGradientLayer.colors = [
            UIColor.brandBlue.cgColor,
            UIColor.accentColor.cgColor,
            UIColor.systemIndigo.cgColor
        ]
        headerGradientLayer.startPoint = CGPoint(x: 0, y: 0)
        headerGradientLayer.endPoint = CGPoint(x: 1, y: 1)
        headerView.layer.insertSublayer(headerGradientLayer, at: 0)
    }

    private func configureKeyboardDismissal() {
        let tapGesture = UITapGestureRecognizer(
            target: self,
            action: #selector(dismissKeyboard)
        )
        tapGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(tapGesture)
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    private func bindViewModel() {
        viewModel.$results
            .receive(on: DispatchQueue.main)
            .sink { [weak self] cards in
                guard let self else { return }

                if cards.isEmpty {
                    cardCountLabel.text = "Search by name, set, type, or text"
                } else {
                    cardCountLabel.text = "\(cards.count) cards found"
                }

                collectionView.reloadData()
            }
            .store(in: &cancellables)

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

extension CardSearchViewController: UISearchBarDelegate {

    func searchBar(
        _ searchBar: UISearchBar,
        textDidChange searchText: String
    ) {
        viewModel.searchText = searchText
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }

    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
}

// MARK: Collection View

extension CardSearchViewController: UICollectionViewDataSource, UICollectionViewDelegate {

    func collectionView(
        _ collectionView: UICollectionView,
        numberOfItemsInSection section: Int
    ) -> Int {
        viewModel.results.count
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {

        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: CardSearchCell.reuseIdentifier,
            for: indexPath
        ) as! CardSearchCell

        cell.configure(with: viewModel.results[indexPath.item])
        return cell
    }

    func collectionView(
        _ collectionView: UICollectionView,
        didSelectItemAt indexPath: IndexPath
    ) {
        let card = viewModel.results[indexPath.item]

        let vc = CardDetailViewController(
            card: card,
            actionMode: .addToCollection
        )

        navigationController?.pushViewController(vc, animated: true)
    }
}
