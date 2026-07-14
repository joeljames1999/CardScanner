import UIKit
import Combine

final class MenuViewController: UIViewController {

    private var cancellables = Set<AnyCancellable>()

    // MARK: - UI

    private lazy var tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .insetGrouped)
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tv.register(BulkDataCell.self, forCellReuseIdentifier: BulkDataCell.reuseID)
        tv.register(SettingsCell.self, forCellReuseIdentifier: SettingsCell.reuseID)
        tv.dataSource = self
        tv.delegate   = self
        return tv
    }()

    private lazy var downloadOverlay: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor    = UIColor.systemBackground.withAlphaComponent(0.95)
        v.layer.cornerRadius = 20
        v.layer.shadowColor  = UIColor.black.cgColor
        v.layer.shadowOpacity = 0.15
        v.layer.shadowRadius  = 12
        v.isHidden = true
        return v
    }()

    private lazy var downloadIconView: UIImageView = {
        let iv = UIImageView(image: UIImage(systemName: "arrow.down.circle.fill"))
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.tintColor   = .systemBlue
        iv.contentMode = .scaleAspectFit
        return iv
    }()

    private lazy var downloadTitleLabel: UILabel = {
        let lbl = UILabel()
        lbl.translatesAutoresizingMaskIntoConstraints = false
        lbl.font          = .systemFont(ofSize: 17, weight: .semibold)
        lbl.textAlignment = .center
        lbl.text          = "Updating Card Database"
        return lbl
    }()

    private lazy var downloadSubtitleLabel: UILabel = {
        let lbl = UILabel()
        lbl.translatesAutoresizingMaskIntoConstraints = false
        lbl.font          = .systemFont(ofSize: 13)
        lbl.textColor     = .secondaryLabel
        lbl.textAlignment = .center
        lbl.numberOfLines = 2
        return lbl
    }()

    private lazy var progressView: UIProgressView = {
        let pv = UIProgressView(progressViewStyle: .default)
        pv.translatesAutoresizingMaskIntoConstraints = false
        pv.layer.cornerRadius = 3
        pv.clipsToBounds      = true
        return pv
    }()

    private lazy var progressLabel: UILabel = {
        let lbl = UILabel()
        lbl.translatesAutoresizingMaskIntoConstraints = false
        lbl.font          = .monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        lbl.textColor     = .secondaryLabel
        lbl.textAlignment = .center
        return lbl
    }()

    private lazy var activityIndicator: UIActivityIndicatorView = {
        let ai = UIActivityIndicatorView(style: .medium)
        ai.translatesAutoresizingMaskIntoConstraints = false
        ai.hidesWhenStopped = true
        return ai
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Menu"
        view.backgroundColor = .systemGroupedBackground
        setupLayout()
        observeDownloadState()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Refresh the cell every time the tab is shown so status is always current
        tableView.reloadData()
    }

    // MARK: - Layout

    private func setupLayout() {
        view.addSubview(tableView)
        view.addSubview(downloadOverlay)

        let stack = UIStackView(arrangedSubviews: [
            downloadIconView,
            downloadTitleLabel,
            downloadSubtitleLabel,
            progressView,
            progressLabel
        ])
        stack.axis      = .vertical
        stack.spacing   = 12
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false

        downloadOverlay.addSubview(stack)
        downloadOverlay.addSubview(activityIndicator)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            downloadOverlay.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            downloadOverlay.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            downloadOverlay.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.82),

            stack.topAnchor.constraint(equalTo: downloadOverlay.topAnchor, constant: 28),
            stack.leadingAnchor.constraint(equalTo: downloadOverlay.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: downloadOverlay.trailingAnchor, constant: -24),
            stack.bottomAnchor.constraint(equalTo: downloadOverlay.bottomAnchor, constant: -28),

            downloadIconView.heightAnchor.constraint(equalToConstant: 48),
            progressView.heightAnchor.constraint(equalToConstant: 6),

            activityIndicator.topAnchor.constraint(equalTo: downloadOverlay.topAnchor, constant: 16),
            activityIndicator.trailingAnchor.constraint(equalTo: downloadOverlay.trailingAnchor, constant: -16),
        ])
    }

    // MARK: - Observe Download State

    private func observeDownloadState() {
        ScryfallBulkService.shared.$downloadState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in self?.handleDownloadState(state) }
            .store(in: &cancellables)
    }

    private func handleDownloadState(_ state: ScryfallBulkService.DownloadState) {
        switch state {
        case .idle:
            hideOverlay()

        case .fetchingManifest:
            showOverlay()
            downloadTitleLabel.text    = "Checking for Updates"
            downloadSubtitleLabel.text = "Fetching card database manifest…"
            progressView.isHidden      = true
            progressLabel.isHidden     = true
            activityIndicator.startAnimating()

        case .downloading(let progress, let totalBytes):
            showOverlay()
            activityIndicator.stopAnimating()
            downloadTitleLabel.text    = "Downloading Card Database"
            progressView.isHidden      = false
            progressLabel.isHidden     = false
            progressView.setProgress(Float(progress), animated: true)
            let received = Int64(Double(totalBytes) * progress)
            let total    = ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
            let done     = ByteCountFormatter.string(fromByteCount: received,   countStyle: .file)
            downloadSubtitleLabel.text = "Downloading Scryfall oracle cards"
            progressLabel.text         = "\(done) / \(total)  ·  \(Int(progress * 100))%"

        case .importing(let done, _):
            // Matches DownloadState.importing(done: Int, total: Int)
            showOverlay()
            activityIndicator.startAnimating()
            downloadTitleLabel.text    = "Importing Cards"
            progressView.isHidden      = true
            progressLabel.isHidden     = true
            downloadSubtitleLabel.text = done > 0
                ? "Imported \(done.formatted()) cards…"
                : "Writing cards to local database…"

        case .done:
            activityIndicator.stopAnimating()
            hideOverlay()
            // Small delay ensures CardDatabaseService has fully committed before we read isEmpty
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.tableView.reloadData()
            }

        case .failed(let message):
            activityIndicator.stopAnimating()
            hideOverlay()
            tableView.reloadData()
            let alert = UIAlertController(title: "Update Failed", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        }
    }

    private func showOverlay() {
        guard downloadOverlay.isHidden else { return }
        downloadOverlay.isHidden = false
        downloadOverlay.alpha    = 0
        UIView.animate(withDuration: 0.25) { self.downloadOverlay.alpha = 1 }
    }

    private func hideOverlay() {
        UIView.animate(withDuration: 0.25, animations: {
            self.downloadOverlay.alpha = 0
        }) { _ in
            self.downloadOverlay.isHidden = true
        }
    }
}

// MARK: - UITableViewDataSource

extension MenuViewController: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int { 2 }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { 1 }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 {
            "Card Database"
        } else {
            "Settings"
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = tableView.dequeueReusableCell(
                withIdentifier: BulkDataCell.reuseID,
                for: indexPath
            ) as! BulkDataCell
            cell.configure()
            return cell
        } else {
            let cell = tableView.dequeueReusableCell(
                withIdentifier: SettingsCell.reuseID,
                for: indexPath) as! SettingsCell
            return cell
        }
    }
}

// MARK: - UITableViewDelegate

extension MenuViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        if indexPath.section == 0 {
            
            let alert = UIAlertController(
                title: "Update Card Database",
                message: "This will re-download the full Scryfall card database (~30–50 MB). Continue?",
                preferredStyle: .actionSheet
            )
            alert.addAction(UIAlertAction(title: "Update Now", style: .default) { _ in
                Task { await ScryfallBulkService.shared.forceRefresh() }
            })
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            present(alert, animated: true)
        } else {
            let vc = SettingsViewController()
            navigationController?.pushViewController(vc, animated: true)
        }
    }
}
