import UIKit

// MARK: - SessionViewController
// Shows the temporary list of cards scanned this session.
// User can edit quantities, remove cards, then commit to main collection.

final class SessionViewController: UIViewController {

    // MARK: Properties

    private let store = SessionStore.shared
    var onCommit: (() -> Void)?
    private var searchResults: [MTGCard] = []
    private var searchTask: Task<Void, Never>?
    private var isSearching: Bool {
        !(searchField.text?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
    }

    // MARK: UI

    private lazy var tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .insetGrouped)
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.register(SessionCardCell.self, forCellReuseIdentifier: SessionCardCell.reuseID)
        tv.dataSource = self
        tv.delegate   = self
        return tv
    }()
    
    private lazy var searchField: UISearchBar = {
        let sb = UISearchBar()
        sb.translatesAutoresizingMaskIntoConstraints = false
        sb.placeholder = "Add card to session..."
        sb.delegate = self
        return sb
    }()

    private lazy var emptyStateLabel: UILabel = {
        let lbl = UILabel()
        lbl.translatesAutoresizingMaskIntoConstraints = false
        lbl.text          = "No cards scanned yet.\nPoint the camera at a Magic card to start."
        lbl.textColor     = .secondaryLabel
        lbl.textAlignment = .center
        lbl.font          = .systemFont(ofSize: 15)
        lbl.numberOfLines = 0
        lbl.isHidden      = true
        return lbl
    }()

    private lazy var summaryBar: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = .secondarySystemBackground
        v.layer.borderColor = UIColor.separator.cgColor
        v.layer.borderWidth = 0.5
        return v
    }()

    private lazy var summaryLabel: UILabel = {
        let lbl = UILabel()
        lbl.font      = .systemFont(ofSize: 14)
        lbl.textColor = .secondaryLabel
        lbl.translatesAutoresizingMaskIntoConstraints = false
        return lbl
    }()

    private lazy var commitButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.title       = "Add to Collection"
        config.image       = UIImage(systemName: "plus.circle.fill")
        config.imagePadding = 6
        config.cornerStyle  = .capsule
        config.baseBackgroundColor = .systemBlue
        let btn = UIButton(configuration: config)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.addTarget(self, action: #selector(commitTapped), for: .touchUpInside)
        return btn
    }()

    private lazy var clearButton: UIBarButtonItem = {
        UIBarButtonItem(title: "Clear", style: .plain, target: self, action: #selector(clearTapped))
    }()

    // MARK: Lifecycle

    deinit {
        searchTask?.cancel()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Session"
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.rightBarButtonItem = clearButton
        setupLayout()
        reload()
    }

    // MARK: Layout

    private func setupLayout() {
        view.backgroundColor = .systemGroupedBackground
        view.addSubview(searchField)
        view.addSubview(tableView)
        view.addSubview(emptyStateLabel)
        view.addSubview(summaryBar)

        summaryBar.addSubview(summaryLabel)
        summaryBar.addSubview(commitButton)

        NSLayoutConstraint.activate([

            summaryBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            summaryBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            summaryBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            summaryBar.heightAnchor.constraint(equalToConstant: 72),

            summaryLabel.leadingAnchor.constraint(equalTo: summaryBar.leadingAnchor, constant: 20),
            summaryLabel.centerYAnchor.constraint(equalTo: summaryBar.centerYAnchor),

            commitButton.trailingAnchor.constraint(equalTo: summaryBar.trailingAnchor, constant: -16),
            commitButton.centerYAnchor.constraint(equalTo: summaryBar.centerYAnchor),
            commitButton.heightAnchor.constraint(equalToConstant: 44),

            searchField.topAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.topAnchor
            ),

            searchField.leadingAnchor.constraint(
                equalTo: view.leadingAnchor
            ),

            searchField.trailingAnchor.constraint(
                equalTo: view.trailingAnchor
            ),

            tableView.topAnchor.constraint(
                equalTo: searchField.bottomAnchor
            ),

            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: summaryBar.topAnchor),

            emptyStateLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -40),
            emptyStateLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            emptyStateLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32)
        ])
    }

    // MARK: Data

    private func reload() {
        let entries = store.entries

        emptyStateLabel.isHidden = !entries.isEmpty || isSearching
        clearButton.isEnabled = !entries.isEmpty
        commitButton.isEnabled = !entries.isEmpty

        if isSearching {
            summaryLabel.text = searchResults.isEmpty
                ? "No matches"
                : "\(searchResults.count) match\(searchResults.count == 1 ? "" : "es")"
        } else {
            summaryLabel.text = entries.isEmpty
                ? "No cards"
                : "\(store.totalCards) card\(store.totalCards == 1 ? "" : "s")"
        }

        tableView.reloadData()
    }

    // MARK: Actions

    @objc private func commitTapped() {
        let entries = store.entries
        guard !entries.isEmpty else { return }

        let alert = UIAlertController(
            title: "Add to Collection",
            message: "Add \(store.totalCards) card\(store.totalCards == 1 ? "" : "s") to your collection?",
            preferredStyle: .actionSheet
        )

        alert.addAction(UIAlertAction(title: "Add \(store.totalCards) card\(store.totalCards == 1 ? "" : "s")", style: .default) { [weak self] _ in
            CollectionStore.shared.addSessionEntries(entries)
            self?.store.clear()
            self?.reload()
            self?.onCommit?()

            let feedback = UINotificationFeedbackGenerator()
            feedback.notificationOccurred(.success)
        })

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
    
    private func performSearch(_ text: String) {

        searchTask?.cancel()

        let trimmed = text.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !trimmed.isEmpty else {
            searchResults.removeAll()
            tableView.reloadData()
            return
        }

        let repository = AppDatabase.shared.cards
        searchTask = Task { [weak self, repository] in
            try? await Task.sleep(nanoseconds: 180_000_000)

            guard !Task.isCancelled else {
                return
            }

            let results = await Task.detached(priority: .userInitiated) {
                (try? repository.search(
                    query: trimmed,
                    filter: SearchFilter()
                )) ?? []
            }.value

            guard !Task.isCancelled else {
                return
            }

            self?.searchResults = results
            self?.reload()
        }
    }

    @objc private func clearTapped() {
        guard !store.isEmpty else { return }

        let alert = UIAlertController(title: "Clear Session", message: "Remove all \(store.totalCards) scanned cards?", preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Clear All", style: .destructive) { [weak self] _ in
            self?.store.clear()
            self?.reload()
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
}

// MARK: - UITableViewDataSource

extension SessionViewController: UITableViewDataSource {
    func tableView(
        _ tableView: UITableView,
        numberOfRowsInSection section: Int
    ) -> Int {

        if isSearching {
            return searchResults.count
        }

        return store.entries.count
    }

    func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {

        let cell = tableView.dequeueReusableCell(
            withIdentifier: SessionCardCell.reuseID,
            for: indexPath
        ) as! SessionCardCell

        if isSearching {

            let card = searchResults[indexPath.row]

            let entry = SessionEntry(
                card: card,
                count: 1
            )

            cell.configure(with: entry)

            return cell
        }

        let entry = store.entries[indexPath.row]

        cell.configure(with: entry)

        cell.onCountChange = { [weak self] newCount in
            self?.store.setCount(
                id: entry.id,
                count: newCount
            )
            self?.reload()
        }

        return cell
    }
    
    func tableView(
        _ tableView: UITableView,
        didSelectRowAt indexPath: IndexPath
    ) {

        guard isSearching else {
            return
        }

        let card = searchResults[indexPath.row]

        SessionStore.shared.addOrIncrement(card: card)

        searchField.text = ""

        searchResults.removeAll()

        searchField.resignFirstResponder()

        reload()
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        guard !isSearching else {
            return
        }

        if editingStyle == .delete {
            let entry = store.entries[indexPath.row]
            store.remove(id: entry.id)
            tableView.deleteRows(at: [indexPath], with: .automatic)
            reload()
        }
    }
}

// MARK: - UITableViewDelegate

extension SessionViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat { 72 }
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        store.isEmpty ? nil : "Scanned this session"
    }
}

// MARK: - SessionCardCell

final class SessionCardCell: UITableViewCell {
    static let reuseID = "SessionCardCell"

    var onCountChange: ((Int) -> Void)?
    private var currentCount: Int = 1

    private let thumbImageView: UIImageView = {
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.contentMode        = .scaleAspectFill
        iv.clipsToBounds      = true
        iv.layer.cornerRadius = 4
        iv.backgroundColor    = .secondarySystemBackground
        return iv
    }()

    private let nameLabel: UILabel = {
        let lbl = UILabel()
        lbl.font          = .systemFont(ofSize: 15, weight: .semibold)
        lbl.numberOfLines = 1
        return lbl
    }()

    private let setLabel: UILabel = {
        let lbl = UILabel()
        lbl.font      = .systemFont(ofSize: 12)
        lbl.textColor = .secondaryLabel
        return lbl
    }()

    private let priceLabel: UILabel = {
        let lbl = UILabel()
        lbl.font      = .systemFont(ofSize: 12, weight: .medium)
        lbl.textColor = .systemGreen
        return lbl
    }()

    private lazy var stepper: UIStepper = {
        let s = UIStepper()
        s.translatesAutoresizingMaskIntoConstraints = false
        s.minimumValue = 1
        s.maximumValue = 99
        s.addTarget(self, action: #selector(stepperChanged), for: .valueChanged)
        return s
    }()

    private let countLabel: UILabel = {
        let lbl = UILabel()
        lbl.font          = .systemFont(ofSize: 14, weight: .semibold)
        lbl.textAlignment = .center
        lbl.translatesAutoresizingMaskIntoConstraints = false
        lbl.widthAnchor.constraint(equalToConstant: 28).isActive = true
        return lbl
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none

        let infoStack = UIStackView(arrangedSubviews: [nameLabel, setLabel, priceLabel])
        infoStack.axis    = .vertical
        infoStack.spacing = 2
        infoStack.translatesAutoresizingMaskIntoConstraints = false

        let controlStack = UIStackView(arrangedSubviews: [countLabel, stepper])
        controlStack.axis      = .horizontal
        controlStack.spacing   = 4
        controlStack.alignment = .center
        controlStack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(thumbImageView)
        contentView.addSubview(infoStack)
        contentView.addSubview(controlStack)

        NSLayoutConstraint.activate([
            thumbImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            thumbImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            thumbImageView.widthAnchor.constraint(equalToConstant: 36),
            thumbImageView.heightAnchor.constraint(equalToConstant: 50),

            infoStack.leadingAnchor.constraint(equalTo: thumbImageView.trailingAnchor, constant: 12),
            infoStack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            infoStack.trailingAnchor.constraint(lessThanOrEqualTo: controlStack.leadingAnchor, constant: -8),

            controlStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            controlStack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(with entry: SessionEntry) {
        nameLabel.text  = entry.card.name
        setLabel.text   = "\(entry.card.setName) · \(entry.card.rarity.capitalized)"
        priceLabel.text = entry.card.prices?.usd.map { "$\($0)" } ?? ""
        currentCount    = entry.count
        countLabel.text = "×\(entry.count)"
        stepper.value   = Double(entry.count)
        thumbImageView.image = nil

        if let url = entry.card.imageUris?.small {
            Task {
                if let (data, _) = try? await URLSession.shared.data(from: url),
                   let img = UIImage(data: data) {
                    await MainActor.run { self.thumbImageView.image = img }
                }
            }
        }
    }

    @objc private func stepperChanged() {
        let newCount = Int(stepper.value)
        countLabel.text = "×\(newCount)"
        onCountChange?(newCount)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        thumbImageView.image = nil
        onCountChange = nil
    }
}

extension SessionViewController: UISearchBarDelegate {

    func searchBar(
        _ searchBar: UISearchBar,
        textDidChange searchText: String
    ) {
        performSearch(searchText)
    }

    func searchBarSearchButtonClicked(
        _ searchBar: UISearchBar
    ) {
        searchBar.resignFirstResponder()
    }
}
