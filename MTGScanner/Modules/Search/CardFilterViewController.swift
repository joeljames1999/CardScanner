import UIKit

// MARK: - CardFilterViewController

final class CardFilterViewController: UIViewController {
    
    // MARK: - Properties
    
    var currentFilter: SearchFilter = SearchFilter()
    var onFilterChange: ((SearchFilter) -> Void)?
    var showsFoilFilter = false
    var isFoilFilterSelected = false
    var onFoilFilterChange: ((Bool) -> Void)?
    
    private var allSets: [String] = []
    private var setSearchText: String = ""
    
    // MARK: - UI
    
    private lazy var tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .insetGrouped)
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.register(FilterCheckboxCell.self, forCellReuseIdentifier: FilterCheckboxCell.reuseID)
        tv.register(FilterColorCell.self, forCellReuseIdentifier: FilterColorCell.reuseID)
        tv.register(FilterSetSearchCell.self, forCellReuseIdentifier: FilterSetSearchCell.reuseID)
        tv.register(FilterManaCostRowCell.self, forCellReuseIdentifier: FilterManaCostRowCell.reuseID)
        tv.register(FilterColorModeCell.self, forCellReuseIdentifier: FilterColorModeCell.reuseID
        )
        tv.dataSource = self
        tv.delegate = self
        return tv
    }()
    
    private lazy var resetButton: UIBarButtonItem = {
        UIBarButtonItem(title: "Reset", style: .plain, target: self, action: #selector(resetFilters))
    }()
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Filters"
        view.backgroundColor = .systemGroupedBackground
        
        navigationItem.rightBarButtonItem = resetButton
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            systemItem: .close,
            primaryAction: UIAction { [weak self] _ in
                self?.dismiss(animated: true)
            }
        )
        
        setupLayout()
        loadAvailableSets()
    }
    
    // MARK: - Layout
    
    private func setupLayout() {
        view.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }
    
    // MARK: - Data Loading
    
    private func loadAvailableSets() {
        // Load sets from database
        allSets = (try? AppDatabase.shared.cards.allSets()) ?? []
        tableView.reloadData()
    }
    
    // MARK: - Actions
    
    @objc private func resetFilters() {
        currentFilter.reset()
        isFoilFilterSelected = false
        onFilterChange?(currentFilter)
        onFoilFilterChange?(false)
        tableView.reloadData()
    }
    
    private func updateFilter() {
        onFilterChange?(currentFilter)
    }
}

// MARK: - UITableViewDataSource

extension CardFilterViewController: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int { 7 }
    
    func tableView(
        _ tableView: UITableView,
        numberOfRowsInSection section: Int
    ) -> Int {

        switch section {

        case 0:
            return showsFoilFilter ? 3 : 2

        case 1:
            return 2

        case 2:
            return 1

        case 3:
            return 5

        case 4:
            return FormatFilter.allCases.count

        case 5:
            return 1

        case 6:
            let filteredSets =
                setSearchText.isEmpty
                ? allSets
                : allSets.filter {
                    $0.localizedCaseInsensitiveContains(
                        setSearchText
                    )
                }

            return filteredSets.count

        default:
            return 0
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.section {
        case 0:

            let cell = tableView.dequeueReusableCell(
                withIdentifier: FilterCheckboxCell.reuseID,
                for: indexPath
            ) as! FilterCheckboxCell

            if indexPath.row == 0 {

                cell.configure(
                    title: "Legal Cards Only",
                    isSelected: currentFilter.legalCardsOnly
                ) { [weak self] in

                    guard let self else { return }

                    self.currentFilter.legalCardsOnly.toggle()

                    self.updateFilter()

                    tableView.reloadRows(
                        at: [indexPath],
                        with: .none
                    )
                }

            } else if indexPath.row == 1 {

                cell.configure(
                    title: "Group Printings",
                    isSelected: currentFilter.groupPrintings
                ) { [weak self] in

                    guard let self else { return }

                    self.currentFilter.groupPrintings.toggle()

                    self.updateFilter()

                    tableView.reloadRows(
                        at: [indexPath],
                        with: .none
                    )
                }

            } else {

                cell.configure(
                    title: "Foil Cards Only",
                    isSelected: isFoilFilterSelected
                ) { [weak self] in

                    guard let self else { return }

                    self.isFoilFilterSelected.toggle()
                    self.onFoilFilterChange?(self.isFoilFilterSelected)

                    tableView.reloadRows(
                        at: [indexPath],
                        with: .none
                    )
                }
            }

            return cell
            
        case 1:

            if indexPath.row == 0 {

                let cell = tableView.dequeueReusableCell(
                    withIdentifier: FilterColorModeCell.reuseID,
                    for: indexPath
                ) as! FilterColorModeCell

                cell.configure(
                    mode: currentFilter.colorFilterMode
                ) { [weak self] mode in

                    guard let self else { return }

                    self.currentFilter.colorFilterMode = mode
                    self.updateFilter()
                }

                return cell
            }

            let cell = tableView.dequeueReusableCell(
                withIdentifier: FilterColorCell.reuseID,
                for: indexPath
            ) as! FilterColorCell

            cell.configure(
                selectedColors: currentFilter.selectedManaColors
            ) { [weak self] color in

                guard let self else { return }

                if self.currentFilter.selectedManaColors.contains(color) {
                    self.currentFilter.selectedManaColors.remove(color)
                } else {
                    self.currentFilter.selectedManaColors.insert(color)
                }

                self.updateFilter()

                tableView.reloadRows(
                    at: [indexPath],
                    with: .none
                )
            }

            return cell
            
        case 2:  // Mana Costs

            let cell = tableView.dequeueReusableCell(
                withIdentifier:
                    FilterManaCostRowCell.reuseID,
                for: indexPath
            ) as! FilterManaCostRowCell

            cell.configure(
                selectedCosts:
                    currentFilter.selectedManaCosts
            ) { [weak self] cost in

                guard let self else { return }

                if self.currentFilter
                    .selectedManaCosts
                    .contains(cost) {

                    self.currentFilter
                        .selectedManaCosts
                        .remove(cost)

                } else {

                    self.currentFilter
                        .selectedManaCosts
                        .insert(cost)
                }

                self.updateFilter()

                tableView.reloadRows(
                    at: [indexPath],
                    with: .none
                )
            }

            return cell
            
        case 3:  // Rarities
            let cell = tableView.dequeueReusableCell(withIdentifier: FilterCheckboxCell.reuseID, for: indexPath) as! FilterCheckboxCell
            let rarities = ["common", "uncommon", "rare", "mythic", "special"]
            let rarity = rarities[indexPath.row]
            let displayRarity = rarity.capitalized
            let isSelected = currentFilter.selectedRarities.contains(rarity)
            cell.configure(title: displayRarity, isSelected: isSelected) { [weak self] in
                guard let self else { return }
                if isSelected {
                    self.currentFilter.selectedRarities.remove(rarity)
                } else {
                    self.currentFilter.selectedRarities.insert(rarity)
                }
                self.updateFilter()
                tableView.reloadRows(at: [indexPath], with: .none)
            }
            return cell
        case 4: //filter

            let cell = tableView.dequeueReusableCell(
                withIdentifier: FilterCheckboxCell.reuseID,
                for: indexPath
            ) as! FilterCheckboxCell

            let format =
                FormatFilter.allCases[indexPath.row]

            let isSelected =
                currentFilter.selectedFormats.contains(format)

            cell.configure(
                title: format.displayName,
                isSelected: isSelected
            ) { [weak self] in

                guard let self else { return }

                if self.currentFilter.selectedFormats.contains(format) {

                    self.currentFilter.selectedFormats.remove(format)

                } else {

                    self.currentFilter.selectedFormats.insert(format)
                }

                self.updateFilter()

                tableView.reloadRows(
                    at: [indexPath],
                    with: .none
                )
            }

            return cell
        case 5:  // Set Search
            let cell = tableView.dequeueReusableCell(withIdentifier: FilterSetSearchCell.reuseID, for: indexPath) as! FilterSetSearchCell
            cell.configure(placeholder: "Search sets...") { [weak self] text in
                self?.setSearchText = text
                self?.tableView.reloadSections([6], with: .automatic)
            }
            return cell
            
        case 6:  // Set List Results
            let cell = tableView.dequeueReusableCell(withIdentifier: FilterCheckboxCell.reuseID, for: indexPath) as! FilterCheckboxCell
            let filteredSets = setSearchText.isEmpty ? allSets : allSets.filter { $0.localizedCaseInsensitiveContains(setSearchText) }
            let setName = filteredSets[indexPath.row]
            let isSelected = currentFilter.selectedSets.contains(setName)
            cell.configure(title: setName, isSelected: isSelected) { [weak self] in
                guard let self else { return }
                if isSelected {
                    self.currentFilter.selectedSets.remove(setName)
                } else {
                    self.currentFilter.selectedSets.insert(setName)
                }
                self.updateFilter()
                tableView.reloadRows(at: [indexPath], with: .none)
            }
            return cell
            
        default:
            return UITableViewCell()
        }
    }
    
    func tableView(
        _ tableView: UITableView,
        titleForHeaderInSection section: Int
    ) -> String? {

        switch section {

        case 0:
            return "Display Options"

        case 1:
            return "Mana Colors"

        case 2:
            return "Mana Cost"

        case 3:
            return "Rarity"
        case 4:
            return "Legal Formats"
        case 5:
            return "Sets"

        default:
            return nil
        }
    }
}

// MARK: - UITableViewDelegate

extension CardFilterViewController: UITableViewDelegate {
    func tableView(
        _ tableView: UITableView,
        heightForRowAt indexPath: IndexPath
    ) -> CGFloat {
        
        if indexPath.section == 1 {

            if indexPath.row == 0 {
                return 52
            }

            return 72
        }
        if indexPath.section == 1 {
            return 72
        }

        return UITableView.automaticDimension
    }
}

// MARK: - FilterCheckboxCell

final class FilterCheckboxCell: UITableViewCell {
    static let reuseID = "FilterCheckboxCell"
    
    private var onTap: (() -> Void)?
    
    private let checkboxImageView: UIImageView = {
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.contentMode = .scaleAspectFit
        iv.tintColor = .systemBlue
        return iv
    }()
    
    private let titleLabel: UILabel = {
        let lbl = UILabel()
        lbl.translatesAutoresizingMaskIntoConstraints = false
        lbl.font = .systemFont(ofSize: 16)
        return lbl
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupLayout()
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    private func setupLayout() {
        contentView.addSubview(checkboxImageView)
        contentView.addSubview(titleLabel)
        
        NSLayoutConstraint.activate([
            checkboxImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            checkboxImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            checkboxImageView.widthAnchor.constraint(equalToConstant: 24),
            checkboxImageView.heightAnchor.constraint(equalToConstant: 24),
            
            titleLabel.leadingAnchor.constraint(equalTo: checkboxImageView.trailingAnchor, constant: 12),
            titleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
        ])
    }
    
    func configure(title: String, isSelected: Bool, onTap: @escaping () -> Void) {
        titleLabel.text = title
        checkboxImageView.image = UIImage(systemName: isSelected ? "checkmark.square.fill" : "square")
        self.onTap = onTap
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        onTap?()
    }
}

// MARK: - FilterSetSearchCell

final class FilterSetSearchCell: UITableViewCell {
    static let reuseID = "FilterSetSearchCell"
    
    private let searchField: UISearchTextField = {
        let field = UISearchTextField()
        field.translatesAutoresizingMaskIntoConstraints = false
        field.placeholder = "Search sets..."
        field.borderStyle = .roundedRect
        field.backgroundColor = .secondarySystemBackground
        return field
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupLayout()
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    private func setupLayout() {
        contentView.addSubview(searchField)
        
        NSLayoutConstraint.activate([
            searchField.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            searchField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            searchField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            searchField.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            searchField.heightAnchor.constraint(equalToConstant: 40),
        ])
    }
    
    func configure(placeholder: String, onTextChange: @escaping (String) -> Void) {
        searchField.placeholder = placeholder
        searchField.addTarget(self, action: #selector(textDidChange), for: .editingChanged)
        self.onTextChange = onTextChange
    }
    
    private var onTextChange: ((String) -> Void)?
    
    @objc private func textDidChange() {
        onTextChange?(searchField.text ?? "")
    }
}
