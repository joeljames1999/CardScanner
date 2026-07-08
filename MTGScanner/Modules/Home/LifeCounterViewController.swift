import UIKit

private struct LifeCounterFormat: Equatable {
    let name: String
    let startingLife: Int
    let playerCount: Int
}

private struct PlayerColorOption: Equatable {
    let id: String
    let name: String
    let color: UIColor
}

private struct LifeCounterPlayerState {
    var name: String
    var colorID: String
    var backgroundImageURL: URL?
}

final class LifeCounterViewController: UIViewController {

    private let formats = [
        LifeCounterFormat(name: "Commander", startingLife: 40, playerCount: 4),
        LifeCounterFormat(name: "Standard", startingLife: 20, playerCount: 2),
        LifeCounterFormat(name: "Brawl", startingLife: 25, playerCount: 2),
        LifeCounterFormat(name: "Two-Headed Giant", startingLife: 30, playerCount: 4),
        LifeCounterFormat(name: "Four Player", startingLife: 20, playerCount: 4)
    ]

    private let colorOptions = [
        PlayerColorOption(id: "blue", name: "Blue", color: .systemBlue),
        PlayerColorOption(id: "red", name: "Red", color: .systemRed),
        PlayerColorOption(id: "green", name: "Green", color: .systemGreen),
        PlayerColorOption(id: "purple", name: "Purple", color: .systemPurple),
        PlayerColorOption(id: "orange", name: "Orange", color: .systemOrange),
        PlayerColorOption(id: "teal", name: "Teal", color: .systemTeal),
        PlayerColorOption(id: "pink", name: "Pink", color: .systemPink),
        PlayerColorOption(id: "indigo", name: "Indigo", color: .systemIndigo)
    ]

    private var selectedFormat: LifeCounterFormat
    private var lifeTotals: [Int]
    private var playerStates: [LifeCounterPlayerState]

    private var wasNavigationBarHidden = false

    private lazy var compactBackButton: UIButton = {
        var config = UIButton.Configuration.plain()
        config.image = UIImage(systemName: "chevron.left")
        config.cornerStyle = .capsule

        let button = UIButton(configuration: config)
        button.addTarget(self, action: #selector(closeLifeCounter), for: .touchUpInside)
        return button
    }()

    private lazy var compactFormatButton: UIButton = {
        var config = UIButton.Configuration.tinted()
        config.image = UIImage(systemName: "slider.horizontal.3")
        config.imagePadding = 6
        config.cornerStyle = .capsule

        let button = UIButton(configuration: config)
        button.showsMenuAsPrimaryAction = true
        return button
    }()

    private lazy var compactResetButton: UIButton = {
        var config = UIButton.Configuration.plain()
        config.image = UIImage(systemName: "arrow.counterclockwise")
        config.cornerStyle = .capsule

        let button = UIButton(configuration: config)
        button.addTarget(self, action: #selector(resetLifeTotals), for: .touchUpInside)
        return button
    }()

    private let compactBar: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let gridStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private lazy var playerViews: [LifeCounterPlayerView] = (1...4).map { index in
        let view = LifeCounterPlayerView()
        view.onIncrement = { [weak self] in
            self?.adjustLife(for: index - 1, by: 1)
        }
        view.onDecrement = { [weak self] in
            self?.adjustLife(for: index - 1, by: -1)
        }
        view.onSettings = { [weak self] in
            self?.openSettings(for: index - 1)
        }
        return view
    }

    init() {
        let initialFormat = LifeCounterFormat(name: "Commander", startingLife: 40, playerCount: 4)
        self.selectedFormat = initialFormat
        self.lifeTotals = Array(repeating: initialFormat.startingLife, count: 4)
        self.playerStates = [
            LifeCounterPlayerState(name: "Player 1", colorID: "blue", backgroundImageURL: nil),
            LifeCounterPlayerState(name: "Player 2", colorID: "red", backgroundImageURL: nil),
            LifeCounterPlayerState(name: "Player 3", colorID: "green", backgroundImageURL: nil),
            LifeCounterPlayerState(name: "Player 4", colorID: "purple", backgroundImageURL: nil)
        ]
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground
        setupLayout()
        applyFormat(selectedFormat, resetLife: true)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        wasNavigationBarHidden = navigationController?.isNavigationBarHidden ?? false
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        navigationController?.setNavigationBarHidden(wasNavigationBarHidden, animated: animated)
    }

    private func setupLayout() {
        view.addSubview(compactBar)
        view.addSubview(gridStack)

        compactBar.addArrangedSubview(compactBackButton)
        compactBar.addArrangedSubview(compactFormatButton)
        compactBar.addArrangedSubview(compactResetButton)

        NSLayoutConstraint.activate([
            compactBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 3),
            compactBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            compactBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            compactBar.heightAnchor.constraint(equalToConstant: 32),

            compactBackButton.widthAnchor.constraint(equalToConstant: 36),
            compactResetButton.widthAnchor.constraint(equalToConstant: 36),

            gridStack.topAnchor.constraint(equalTo: compactBar.bottomAnchor, constant: 6),
            gridStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            gridStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            gridStack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -10)
        ])
    }

    private func makeFormatMenu() -> UIMenu {
        let actions = formats.map { format in
            UIAction(
                title: "\(format.name) - \(format.startingLife) life",
                state: format == selectedFormat ? .on : .off
            ) { [weak self] _ in
                self?.applyFormat(format, resetLife: true)
            }
        }

        return UIMenu(title: "Format", children: actions)
    }

    private func applyFormat(
        _ format: LifeCounterFormat,
        resetLife: Bool
    ) {
        selectedFormat = format

        if resetLife {
            lifeTotals = Array(repeating: format.startingLife, count: 4)
        }

        var config = compactFormatButton.configuration
        config?.title = "\(format.name) - \(format.startingLife)"
        compactFormatButton.configuration = config
        compactFormatButton.menu = makeFormatMenu()

        rebuildGrid()
        refreshPlayerViews()
    }

    private func rebuildGrid() {
        gridStack.arrangedSubviews.forEach { row in
            gridStack.removeArrangedSubview(row)
            row.removeFromSuperview()
        }

        if selectedFormat.playerCount <= 2 {
            gridStack.addArrangedSubview(playerViews[0])
            gridStack.addArrangedSubview(playerViews[1])
        } else {
            gridStack.addArrangedSubview(makePlayerRow([playerViews[0], playerViews[1]]))
            gridStack.addArrangedSubview(makePlayerRow([playerViews[2], playerViews[3]]))
        }
    }

    private func makePlayerRow(_ views: [LifeCounterPlayerView]) -> UIStackView {
        let row = UIStackView(arrangedSubviews: views)
        row.axis = .horizontal
        row.spacing = 12
        row.distribution = .fillEqually
        return row
    }

    private func refreshPlayerViews() {
        for index in playerViews.indices {
            let isActive = index < selectedFormat.playerCount
            let state = playerStates[index]
            let color = colorOptions.first { $0.id == state.colorID }?.color ?? .systemBlue

            playerViews[index].configure(
                life: lifeTotals[index],
                isActive: isActive,
                state: state,
                color: color
            )
        }
    }

    private func adjustLife(
        for index: Int,
        by amount: Int
    ) {
        guard index < selectedFormat.playerCount else {
            return
        }

        lifeTotals[index] += amount
        refreshPlayerViews()
    }

    private func openSettings(for index: Int) {
        guard playerStates.indices.contains(index) else {
            return
        }

        let unavailableColorIDs = Set(
            playerStates.enumerated().compactMap { offset, state in
                offset == index ? nil : state.colorID
            }
        )

        let settings = LifeCounterPlayerSettingsViewController(
            playerNumber: index + 1,
            state: playerStates[index],
            colorOptions: colorOptions,
            unavailableColorIDs: unavailableColorIDs
        )

        settings.onSave = { [weak self] updatedState in
            self?.playerStates[index] = updatedState
            self?.refreshPlayerViews()
        }

        let nav = UINavigationController(rootViewController: settings)
        if let sheet = nav.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
        }
        present(nav, animated: true)
    }

    @objc private func resetLifeTotals() {
        applyFormat(selectedFormat, resetLife: true)
    }

    @objc private func closeLifeCounter() {
        if let navigationController {
            navigationController.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
    }
}

private final class LifeCounterPlayerView: UIView {

    var onIncrement: (() -> Void)?
    var onDecrement: (() -> Void)?
    var onSettings: (() -> Void)?

    private var imageLoadTask: Task<Void, Never>?
    private var representedImageURL: URL?

    private let backgroundImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.alpha = 0
        return imageView
    }()

    private let overlayView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor.black.withAlphaComponent(0.18)
        return view
    }()

    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15, weight: .semibold)
        label.textColor = .white
        label.textAlignment = .center
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.75
        return label
    }()

    private lazy var settingsButton: UIButton = {
        var config = UIButton.Configuration.plain()
        config.image = UIImage(systemName: "gearshape.fill")
        config.baseForegroundColor = .white
        config.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4)

        let button = UIButton(configuration: config)
        button.addTarget(self, action: #selector(settingsTapped), for: .touchUpInside)
        button.setPreferredSymbolConfiguration(
            UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold),
            forImageIn: .normal
        )
        return button
    }()

    private let lifeLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 76, weight: .bold)
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.6
        label.textColor = .white
        label.textAlignment = .center
        return label
    }()

    private lazy var decrementButton: UIButton = makeButton(
        symbol: "minus.circle.fill",
        action: #selector(decrementTapped)
    )

    private lazy var incrementButton: UIButton = makeButton(
        symbol: "plus.circle.fill",
        action: #selector(incrementTapped)
    )

    deinit {
        imageLoadTask?.cancel()
    }

    init() {
        super.init(frame: .zero)
        setupLayout()
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    func configure(
        life: Int,
        isActive: Bool,
        state: LifeCounterPlayerState,
        color: UIColor
    ) {
        nameLabel.text = state.name
        lifeLabel.text = isActive ? "\(life)" : "--"
        alpha = isActive ? 1 : 0.42
        decrementButton.isEnabled = isActive
        incrementButton.isEnabled = isActive
        settingsButton.isEnabled = isActive
        backgroundColor = color
        layer.borderColor = color.withAlphaComponent(0.7).cgColor
        loadBackgroundImage(state.backgroundImageURL)
    }

    private func setupLayout() {
        clipsToBounds = true
        layer.cornerRadius = 14
        layer.cornerCurve = .continuous
        layer.borderWidth = 1

        let nameStack = UIStackView(arrangedSubviews: [nameLabel, settingsButton])
        nameStack.axis = .horizontal
        nameStack.spacing = 4
        nameStack.alignment = .center
        nameStack.distribution = .fill

        let controls = UIStackView(arrangedSubviews: [decrementButton, incrementButton])
        controls.axis = .horizontal
        controls.spacing = 18
        controls.distribution = .fillEqually

        let stack = UIStackView(arrangedSubviews: [nameStack, lifeLabel, controls])
        stack.axis = .vertical
        stack.spacing = 12
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(backgroundImageView)
        addSubview(overlayView)
        addSubview(stack)

        NSLayoutConstraint.activate([
            backgroundImageView.topAnchor.constraint(equalTo: topAnchor),
            backgroundImageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            backgroundImageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            backgroundImageView.bottomAnchor.constraint(equalTo: bottomAnchor),

            overlayView.topAnchor.constraint(equalTo: topAnchor),
            overlayView.leadingAnchor.constraint(equalTo: leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: trailingAnchor),
            overlayView.bottomAnchor.constraint(equalTo: bottomAnchor),

            stack.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16),

            settingsButton.widthAnchor.constraint(equalToConstant: 30),
            settingsButton.heightAnchor.constraint(equalToConstant: 30),
            decrementButton.heightAnchor.constraint(equalToConstant: 54),
            incrementButton.heightAnchor.constraint(equalToConstant: 54)
        ])
    }

    private func loadBackgroundImage(_ url: URL?) {
        imageLoadTask?.cancel()
        representedImageURL = url
        backgroundImageView.image = nil
        backgroundImageView.alpha = 0
        overlayView.backgroundColor = UIColor.black.withAlphaComponent(0.18)

        guard let url else {
            return
        }

        imageLoadTask = Task { [weak self] in
            guard
                let (data, _) = try? await URLSession.shared.data(from: url),
                !Task.isCancelled,
                let image = UIImage(data: data)
            else { return }

            await MainActor.run {
                guard self?.representedImageURL == url else {
                    return
                }

                self?.backgroundImageView.image = image
                self?.backgroundImageView.alpha = 1
                self?.overlayView.backgroundColor = UIColor.black.withAlphaComponent(0.42)
                self?.imageLoadTask = nil
            }
        }
    }

    private func makeButton(
        symbol: String,
        action: Selector
    ) -> UIButton {
        var config = UIButton.Configuration.plain()
        config.image = UIImage(systemName: symbol)
        config.baseForegroundColor = .white

        let button = UIButton(configuration: config)
        button.setPreferredSymbolConfiguration(
            UIImage.SymbolConfiguration(pointSize: 32, weight: .semibold),
            forImageIn: .normal
        )
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    @objc private func settingsTapped() {
        onSettings?()
    }

    @objc private func decrementTapped() {
        onDecrement?()
    }

    @objc private func incrementTapped() {
        onIncrement?()
    }
}

private final class LifeCounterPlayerSettingsViewController: UIViewController {

    var onSave: ((LifeCounterPlayerState) -> Void)?

    private let playerNumber: Int
    private let colorOptions: [PlayerColorOption]
    private let unavailableColorIDs: Set<String>
    private var state: LifeCounterPlayerState
    private var searchResults: [MTGCard] = []
    private var searchTask: Task<Void, Never>?

    private let nameField: UITextField = {
        let field = UITextField()
        field.borderStyle = .roundedRect
        field.placeholder = "Player name"
        field.clearButtonMode = .whileEditing
        return field
    }()

    private let colorStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 10
        return stack
    }()

    private let imageStatusLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13)
        label.textColor = .secondaryLabel
        label.numberOfLines = 2
        return label
    }()

    private lazy var searchBar: UISearchBar = {
        let searchBar = UISearchBar()
        searchBar.placeholder = "Search card art"
        searchBar.searchBarStyle = .minimal
        searchBar.delegate = self
        return searchBar
    }()

    private lazy var resultsTableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "CardResultCell")
        tableView.dataSource = self
        tableView.delegate = self
        tableView.layer.cornerRadius = 10
        tableView.layer.borderColor = UIColor.separator.cgColor
        tableView.layer.borderWidth = 0.5
        return tableView
    }()

    init(
        playerNumber: Int,
        state: LifeCounterPlayerState,
        colorOptions: [PlayerColorOption],
        unavailableColorIDs: Set<String>
    ) {
        self.playerNumber = playerNumber
        self.state = state
        self.colorOptions = colorOptions
        self.unavailableColorIDs = unavailableColorIDs
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    deinit {
        searchTask?.cancel()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Player \(playerNumber)"
        view.backgroundColor = .systemGroupedBackground
        configureNavigation()
        setupLayout()
        refreshImageStatus()
    }

    private func configureNavigation() {
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            systemItem: .cancel,
            primaryAction: UIAction { [weak self] _ in
                self?.dismiss(animated: true)
            }
        )

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            systemItem: .save,
            primaryAction: UIAction { [weak self] _ in
                self?.saveTapped()
            }
        )
    }

    private func setupLayout() {
        nameField.text = state.name

        let titleLabel = makeSectionLabel("Name")
        let colorLabel = makeSectionLabel("Color")
        let imageLabel = makeSectionLabel("Background Art")

        buildColorButtons()

        let clearImageButton = UIButton(type: .system)
        clearImageButton.setTitle("Clear background image", for: .normal)
        clearImageButton.addTarget(self, action: #selector(clearImageTapped), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [
            titleLabel,
            nameField,
            colorLabel,
            colorStack,
            imageLabel,
            imageStatusLabel,
            clearImageButton,
            searchBar,
            resultsTableView
        ])
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false

        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        scrollView.addSubview(stack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24),
            stack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -32),

            resultsTableView.heightAnchor.constraint(equalToConstant: 260)
        ])
    }

    private func buildColorButtons() {
        colorStack.arrangedSubviews.forEach { view in
            colorStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        for rowOptions in colorOptions.chunked(into: 4) {
            let row = UIStackView()
            row.axis = .horizontal
            row.spacing = 10
            row.distribution = .fillEqually

            for option in rowOptions {
                let button = makeColorButton(option)
                row.addArrangedSubview(button)
            }

            colorStack.addArrangedSubview(row)
        }
    }

    private func makeColorButton(_ option: PlayerColorOption) -> UIButton {
        let button = UIButton(type: .system)
        button.backgroundColor = option.color
        button.layer.cornerRadius = 12
        button.layer.cornerCurve = .continuous
        button.layer.borderWidth = option.id == state.colorID ? 4 : 1
        button.layer.borderColor = option.id == state.colorID
            ? UIColor.label.cgColor
            : UIColor.separator.cgColor
        button.heightAnchor.constraint(equalToConstant: 46).isActive = true
        button.accessibilityLabel = option.name
        button.tag = colorOptions.firstIndex(of: option) ?? 0

        let isUnavailable = unavailableColorIDs.contains(option.id)
        button.isEnabled = !isUnavailable
        button.alpha = isUnavailable ? 0.28 : 1
        button.addTarget(self, action: #selector(colorTapped(_:)), for: .touchUpInside)
        return button
    }

    private func makeSectionLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 15, weight: .semibold)
        label.textColor = .secondaryLabel
        return label
    }

    private func performSearch(_ text: String) {
        searchTask?.cancel()

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            searchResults = []
            resultsTableView.reloadData()
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
            self?.resultsTableView.reloadData()
        }
    }

    private func refreshImageStatus() {
        imageStatusLabel.text = state.backgroundImageURL == nil
            ? "No background image selected."
            : "Background image selected."
    }

    @objc private func colorTapped(_ sender: UIButton) {
        let option = colorOptions[sender.tag]
        state.colorID = option.id
        buildColorButtons()
    }

    @objc private func clearImageTapped() {
        state.backgroundImageURL = nil
        refreshImageStatus()
    }

    private func saveTapped() {
        let trimmedName = nameField.text?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        state.name = trimmedName.isEmpty ? "Player \(playerNumber)" : trimmedName
        onSave?(state)
        dismiss(animated: true)
    }
}

extension LifeCounterPlayerSettingsViewController: UISearchBarDelegate {

    func searchBar(
        _ searchBar: UISearchBar,
        textDidChange searchText: String
    ) {
        performSearch(searchText)
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
}

extension LifeCounterPlayerSettingsViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(
        _ tableView: UITableView,
        numberOfRowsInSection section: Int
    ) -> Int {
        searchResults.count
    }

    func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: "CardResultCell",
            for: indexPath
        )
        let card = searchResults[indexPath.row]
        var config = cell.defaultContentConfiguration()
        config.text = card.name
        config.secondaryText = "\(card.set.uppercased()) #\(card.collectorNumber)"
        cell.contentConfiguration = config
        return cell
    }

    func tableView(
        _ tableView: UITableView,
        didSelectRowAt indexPath: IndexPath
    ) {
        let card = searchResults[indexPath.row]
        state.backgroundImageURL = card.imageUris?.artCrop ?? card.displayImage
        refreshImageStatus()
        tableView.deselectRow(at: indexPath, animated: true)
        searchBar.resignFirstResponder()
    }
}

private extension Array {

    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map { index in
            Array(self[index..<Swift.min(index + size, count)])
        }
    }
}
