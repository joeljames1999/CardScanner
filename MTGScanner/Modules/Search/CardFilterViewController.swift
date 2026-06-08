import UIKit

// MARK: - CardFilterViewController

final class CardFilterViewController: UIViewController {
    
    // MARK: - Properties
    
    var currentFilter: SearchFilter = SearchFilter()
    var onFilterChange: ((SearchFilter) -> Void)?
    
    private var allSets: [String] = []
    private var setSearchText: String = ""
    
    // MARK: - UI
    
    private lazy var tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .insetGrouped)
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.register(FilterCheckboxCell.self, forCellReuseIdentifier: FilterCheckboxCell.reuseID)
        tv.register(FilterColorCell.self, forCellReuseIdentifier: FilterColorCell.reuseID)
        tv.register(FilterSetSearchCell.self, forCellReuseIdentifier: FilterSetSearchCell.reuseID)
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
        allSets = CardDatabaseService.shared.getAllSets()
        tableView.reloadData()
    }
    
    // MARK: - Actions
    
    @objc private func resetFilters() {
        currentFilter.reset()
        onFilterChange?(currentFilter)
        tableView.reloadData()
    }
    
    private func updateFilter() {
        onFilterChange?(currentFilter)
    }
}

// MARK: - UITableViewDataSource

extension CardFilterViewController: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int { 5 }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0: return SearchFilter.ManaColor.allCases.count  // Mana colors
        case 1: return 7  // Mana costs (0-6+)
        case 2: return 5  // Rarities
        case 3: return 1  // Set search
        case 4: return setSearchText.isEmpty ? allSets.count : allSets.filter { $0.localizedCaseInsensitiveContains(setSearchText) }.count
        default: return 0
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.section {
        case 0:  // Mana Colors
            let cell = tableView.dequeueReusableCell(withIdentifier: FilterColorCell.reuseID, for: indexPath) as! FilterColorCell
            let color = SearchFilter.ManaColor.allCases[indexPath.row]
            let isSelected = currentFilter.selectedManaColors.contains(color)
            cell.configure(color: color, isSelected: isSelected) { [weak self] in
                guard let self else { return }
                if isSelected {
                    self.currentFilter.selectedManaColors.remove(color)
                } else {
                    self.currentFilter.selectedManaColors.insert(color)
                }
                self.updateFilter()
                tableView.reloadRows(at: [indexPath], with: .none)
            }
            return cell
            
        case 1:  // Mana Costs
            let cell = tableView.dequeueReusableCell(withIdentifier: FilterCheckboxCell.reuseID, for: indexPath) as! FilterCheckboxCell
            let cost = indexPath.row
            let label = cost == 6 ? "6+" : "\(cost)"
            let isSelected = currentFilter.selectedManaCosts.contains(cost)
            cell.configure(title: label, isSelected: isSelected) { [weak self] in
                guard let self else { return }
                if isSelected {
                    self.currentFilter.selectedManaCosts.remove(cost)
                } else {
                    self.currentFilter.selectedManaCosts.insert(cost)
                }
                self.updateFilter()
                tableView.reloadRows(at: [indexPath], with: .none)
            }
            return cell
            
        case 2:  // Rarities
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
            
        case 3:  // Set Search
            let cell = tableView.dequeueReusableCell(withIdentifier: FilterSetSearchCell.reuseID, for: indexPath) as! FilterSetSearchCell
            cell.configure(placeholder: "Search sets...") { [weak self] text in
                self?.setSearchText = text
                self?.tableView.reloadSections([4], with: .automatic)
            }
            return cell
            
        case 4:  // Set List Results
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
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0: return "Mana Colors"
        case 1: return "Mana Cost"
        case 2: return "Rarity"
        case 3: return "Sets"
        default: return nil
        }
    }
}

// MARK: - UITableViewDelegate

extension CardFilterViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        indexPath.section == 0 ? 50 : UITableView.automaticDimension
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

// MARK: - FilterColorCell

final class FilterColorCell: UITableViewCell {
    static let reuseID = "FilterColorCell"
    
    private var onTap: (() -> Void)?
    
    private let colorView: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.layer.cornerRadius = 12
        v.layer.borderWidth = 2
        return v
    }()
    
    private let colorNameLabel: UILabel = {
        let lbl = UILabel()
        lbl.font = .systemFont(ofSize: 16, weight: .semibold)
        return lbl
    }()
    
    private let checkmarkImageView: UIImageView = {
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.tintColor = .systemBlue
        iv.contentMode = .scaleAspectFit
        return iv
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupLayout()
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    private func setupLayout() {
        let labelStack = UIStackView(arrangedSubviews: [colorNameLabel])
        labelStack.translatesAutoresizingMaskIntoConstraints = false
        labelStack.axis = .vertical
        labelStack.spacing = 4
        
        contentView.addSubview(colorView)
        contentView.addSubview(labelStack)
        contentView.addSubview(checkmarkImageView)
        
        NSLayoutConstraint.activate([
            colorView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            colorView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            colorView.widthAnchor.constraint(equalToConstant: 32),
            colorView.heightAnchor.constraint(equalToConstant: 32),
            
            labelStack.leadingAnchor.constraint(equalTo: colorView.trailingAnchor, constant: 12),
            labelStack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            
            checkmarkImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            checkmarkImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            checkmarkImageView.widthAnchor.constraint(equalToConstant: 24),
            checkmarkImageView.heightAnchor.constraint(equalToConstant: 24),
        ])
    }
    
    func configure(color: SearchFilter.ManaColor, isSelected: Bool, onTap: @escaping () -> Void) {
        colorNameLabel.text = color.displayName
        colorView.backgroundColor = color.color
        colorView.layer.borderColor = isSelected ? UIColor.systemBlue.cgColor : UIColor.separator.cgColor
        checkmarkImageView.image = isSelected ? UIImage(systemName: "checkmark.circle.fill") : nil
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
