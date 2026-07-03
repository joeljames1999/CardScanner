import UIKit
import UniformTypeIdentifiers

// MARK: - CollectionViewController

final class CollectionViewController: UIViewController {

    // MARK: Data

    private var allEntries: [CollectionEntry] = []
    private var filteredEntries: [CollectionEntry] = []
    private var searchText: String = ""

    // MARK: UI

    private lazy var tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .insetGrouped)
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.register(CollectionCardCell.self, forCellReuseIdentifier: CollectionCardCell.reuseID)
        tv.dataSource = self
        tv.delegate   = self
        return tv
    }()

    private lazy var searchController: UISearchController = {
        let sc = UISearchController(searchResultsController: nil)
        sc.searchResultsUpdater          = self
        sc.obscuresBackgroundDuringPresentation = false
        sc.searchBar.placeholder         = "Search cards…"
        return sc
    }()

    private lazy var statsBar: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = .secondarySystemBackground
        v.layer.borderColor = UIColor.separator.cgColor
        v.layer.borderWidth = 0.5
        return v
    }()

    private lazy var statsLabel: UILabel = {
        let lbl = UILabel()
        lbl.translatesAutoresizingMaskIntoConstraints = false
        lbl.font      = .systemFont(ofSize: 13)
        lbl.textColor = .secondaryLabel
        return lbl
    }()

    private lazy var emptyLabel: UILabel = {
        let lbl = UILabel()
        lbl.translatesAutoresizingMaskIntoConstraints = false
        lbl.text          = "Your collection is empty.\nScan some cards to get started!"
        lbl.textColor     = .secondaryLabel
        lbl.textAlignment = .center
        lbl.font          = .systemFont(ofSize: 15)
        lbl.numberOfLines = 0
        lbl.isHidden      = true
        return lbl
    }()

    private let loadingView = UIVisualEffectView(
        effect: UIBlurEffect(style: .systemMaterial)
    )

    private let activity = UIActivityIndicatorView(style: .large)

    private let loadingLabel: UILabel = {
        let label = UILabel()
        label.text = "Importing collection..."
        label.font = .preferredFont(forTextStyle: .headline)
        label.textAlignment = .center
        return label
    }()
    
    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Collection"
        navigationItem.largeTitleDisplayMode = .automatic
        navigationItem.searchController      = searchController
        navigationItem.hidesSearchBarWhenScrolling = false

        setupNav()
        setupLayout()

        NotificationCenter.default.addObserver(self, selector: #selector(collectionChanged), name: CollectionStore.didChangeNotification, object: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reload()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: Nav

    private func setupNav() {
        let exportBtn = UIBarButtonItem(image: UIImage(systemName: "square.and.arrow.up"), style: .plain, target: self, action: #selector(exportTapped))
        let importBtn = UIBarButtonItem(image: UIImage(systemName: "square.and.arrow.down"), style: .plain, target: self, action: #selector(importTapped))
        let moreBtn   = UIBarButtonItem(image: UIImage(systemName: "ellipsis.circle"), style: .plain, target: self, action: #selector(moreTapped))
        navigationItem.rightBarButtonItems = [moreBtn, exportBtn, importBtn]
    }

    // MARK: Layout

    private func setupLayout() {
        view.backgroundColor = .systemGroupedBackground
        view.addSubview(tableView)
        view.addSubview(statsBar)
        view.addSubview(emptyLabel)
        statsBar.addSubview(statsLabel)

        NSLayoutConstraint.activate([
            statsBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            statsBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            statsBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            statsBar.heightAnchor.constraint(equalToConstant: 44),

            statsLabel.centerXAnchor.constraint(equalTo: statsBar.centerXAnchor),
            statsLabel.centerYAnchor.constraint(equalTo: statsBar.centerYAnchor),

            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: statsBar.topAnchor),

            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -40),
            emptyLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            emptyLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
        ])
    }

    private func showImportLoading() {

        loadingView.translatesAutoresizingMaskIntoConstraints = false
        activity.translatesAutoresizingMaskIntoConstraints = false
        loadingLabel.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(loadingView)
        loadingView.contentView.addSubview(activity)
        loadingView.contentView.addSubview(loadingLabel)

        NSLayoutConstraint.activate([
            loadingView.topAnchor.constraint(equalTo: view.topAnchor),
            loadingView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            loadingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            loadingView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            activity.centerXAnchor.constraint(equalTo: loadingView.centerXAnchor),
            activity.centerYAnchor.constraint(equalTo: loadingView.centerYAnchor),

            loadingLabel.topAnchor.constraint(equalTo: activity.bottomAnchor, constant: 16),
            loadingLabel.centerXAnchor.constraint(equalTo: activity.centerXAnchor)
        ])

        activity.startAnimating()
    }

    private func hideImportLoading() {
        activity.stopAnimating()
        loadingView.removeFromSuperview()
    }
    // MARK: Data

    private func reload() {
        allEntries      = CollectionStore.shared.entries
        filteredEntries = filter(allEntries, query: searchText)
        emptyLabel.isHidden = !allEntries.isEmpty
        updateStats()
        tableView.reloadData()
    }

    private func filter(_ entries: [CollectionEntry], query: String) -> [CollectionEntry] {
        guard !query.isEmpty else { return entries }
        return entries.filter { $0.name.localizedCaseInsensitiveContains(query) || $0.setName.localizedCaseInsensitiveContains(query) }
    }

    private func updateStats() {
        let total = CollectionStore.shared.totalCards
        let value = CollectionStore.shared.estimatedValue
        if total == 0 {
            statsLabel.text = "Empty collection"
        } else {
            statsLabel.text = "\(total) card\(total == 1 ? "" : "s")  ·  Est. $\(String(format: "%.2f", value))"
        }
    }

    @objc private func collectionChanged() {
        DispatchQueue.main.async { self.reload() }
    }

    // MARK: Actions

    @objc private func exportTapped() {
        guard !allEntries.isEmpty else {
            showAlert(title: "Nothing to Export", message: "Your collection is empty.")
            return
        }

        guard let url = CSVService.shared.saveToFile(allEntries) else {
            showAlert(title: "Export Failed", message: "Could not write CSV file.")
            return
        }

        let ac = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        present(ac, animated: true)
    }

    @objc private func importTapped() {
        let types: [UTType] = [.commaSeparatedText, .text, .plainText]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types)
        picker.delegate = self
        present(picker, animated: true)
    }

    @objc private func moreTapped() {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)

        alert.addAction(UIAlertAction(title: "Sort by Name", style: .default) { [weak self] _ in
            self?.sortEntries(by: .name)
        })
        alert.addAction(UIAlertAction(title: "Sort by Set", style: .default) { [weak self] _ in
            self?.sortEntries(by: .set)
        })
        alert.addAction(UIAlertAction(title: "Sort by Price", style: .default) { [weak self] _ in
            self?.sortEntries(by: .price)
        })
        alert.addAction(UIAlertAction(title: "Sort by Date Added", style: .default) { [weak self] _ in
            self?.sortEntries(by: .date)
        })

        if !allEntries.isEmpty {
            alert.addAction(UIAlertAction(title: "Clear Collection", style: .destructive) { [weak self] _ in
                self?.confirmClear()
            })
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }


    private func sortEntries(by key: CollectionStore.SortKey) {
        CollectionStore.shared.sort(by: key)
    }

    private func confirmClear() {
        let total = CollectionStore.shared.totalCards
        let alert = UIAlertController(
            title: "Clear Collection",
            message: "This will permanently delete all \(total) cards. This cannot be undone.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Delete All", style: .destructive) { _ in
            CollectionStore.shared.removeAll()
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UITableViewDataSource

extension CollectionViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        filteredEntries.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: CollectionCardCell.reuseID, for: indexPath) as! CollectionCardCell
        cell.configure(with: filteredEntries[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let entry = filteredEntries[indexPath.row]
            CollectionStore.shared.remove(id: entry.id)
        }
    }
}

// MARK: - UITableViewDelegate

extension CollectionViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat { 72 }
}

// MARK: - UISearchResultsUpdating

extension CollectionViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        searchText      = searchController.searchBar.text ?? ""
        filteredEntries = filter(allEntries, query: searchText)
        tableView.reloadData()
    }
}

// MARK: - UIDocumentPickerDelegate (Import)

extension CollectionViewController: UIDocumentPickerDelegate {

    func documentPicker(
        _ controller: UIDocumentPickerViewController,
        didPickDocumentsAt urls: [URL]
    ) {

        guard let url = urls.first else { return }

        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }

        showImportLoading()

        DispatchQueue.global(qos: .userInitiated).async {

            do {

                let csv = try String(contentsOf: url, encoding: .utf8)

                let result = CSVService.shared.importCSV(csv)

                CollectionStore.shared.merge(result.entries)

                DispatchQueue.main.async {

                    self.hideImportLoading()

                    self.reload()

                    let message =
                    """
                    Imported \(result.entries.count) cards.

                    \(result.skippedRows > 0 ? "Skipped \(result.skippedRows) rows." : "")
                    """

                    self.showAlert(
                        title: "Import Complete",
                        message: message
                    )
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

// MARK: - CollectionCardCell

final class CollectionCardCell: UITableViewCell {
    static let reuseID = "CollectionCardCell"

    private let thumbImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode        = .scaleAspectFill
        imageView.clipsToBounds      = true
        imageView.layer.cornerRadius = 4
        imageView.backgroundColor    = .secondarySystemBackground
        return imageView
    }()

    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font          = .systemFont(ofSize: 15, weight: .semibold)
        label.numberOfLines = 1
        return label
    }()

    private let setLabel: UILabel = {
        let label = UILabel()
        label.font      = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabel
        return label
    }()

    private let countBadge: UILabel = {
        let label = UILabel()
        label.font                  = .systemFont(ofSize: 12, weight: .semibold)
        label.textColor             = .white
        label.backgroundColor       = .systemBlue
        label.textAlignment         = .center
        label.layer.cornerRadius    = 10
        label.clipsToBounds         = true
        label.translatesAutoresizingMaskIntoConstraints = false
        label.widthAnchor.constraint(greaterThanOrEqualToConstant: 28).isActive = true
        label.heightAnchor.constraint(equalToConstant: 20).isActive = true
        return label
    }()

    private let priceLabel: UILabel = {
        let label = UILabel()
        label.font      = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .systemGreen
        return label
    }()

    private let conditionLabel: UILabel = {
        let label = UILabel()
        label.font      = .systemFont(ofSize: 11)
        label.textColor = .tertiaryLabel
        return label
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        let infoStack = UIStackView(arrangedSubviews: [nameLabel, setLabel, conditionLabel])
        infoStack.axis    = .vertical
        infoStack.spacing = 2
        infoStack.translatesAutoresizingMaskIntoConstraints = false

        let rightStack = UIStackView(arrangedSubviews: [countBadge, priceLabel])
        rightStack.axis      = .vertical
        rightStack.spacing   = 4
        rightStack.alignment = .center
        rightStack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(thumbImageView)
        contentView.addSubview(infoStack)
        contentView.addSubview(rightStack)

        NSLayoutConstraint.activate([
            thumbImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            thumbImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            thumbImageView.widthAnchor.constraint(equalToConstant: 36),
            thumbImageView.heightAnchor.constraint(equalToConstant: 50),

            infoStack.leadingAnchor.constraint(equalTo: thumbImageView.trailingAnchor, constant: 12),
            infoStack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            infoStack.trailingAnchor.constraint(lessThanOrEqualTo: rightStack.leadingAnchor, constant: -8),

            rightStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            rightStack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(with entry: CollectionEntry) {
        nameLabel.text      = entry.name
        setLabel.text       = "\(entry.setName) · \(entry.rarity.capitalized)"
        conditionLabel.text = "\(entry.condition.rawValue)\(entry.isFoil ? " · Foil" : "")"
        countBadge.text     = "×\(entry.count)"
        priceLabel.text     = entry.usdPrice.map { "$\($0)" } ?? ""
        thumbImageView.image = nil

        if let url = entry.imageURL {
            Task {
                if let (data, _) = try? await URLSession.shared.data(from: url),
                   let img = UIImage(data: data) {
                    await MainActor.run { self.thumbImageView.image = img }
                }
            }
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        thumbImageView.image = nil
    }
}
