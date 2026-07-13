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
    var backgroundImageName: String?
    var poisonCounters: Int = 0
    var radCounters: Int = 0
    var experienceCounters: Int = 0
    var energyCounters: Int = 0
    var commanderTax: Int = 0
    var hasInitiative: Bool = false
    var isMonarch: Bool = false
    var hasAscended: Bool = false
    var manuallyKnockedOut: Bool = false
}

private struct CommanderDamageSource {
    let playerIndex: Int
    let name: String
    let color: UIColor
    let damage: Int
}

private enum LifeCounterExtraBadgeKind {
    case poison
    case rad
    case experience
    case energy
    case commanderTax
    case initiative
    case monarch
    case ascend
}

private struct LifeCounterExtraBadge {
    let title: String
    let kind: LifeCounterExtraBadgeKind
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
    private var commanderDamageEnabled = true
    private var commanderDamage = Array(
        repeating: Array(repeating: 0, count: 4),
        count: 4
    )
    private var startingPlayerIndex: Int?
    private var starterSelectionTask: Task<Void, Never>?

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

    private lazy var compactCommanderButton: UIButton = {
        var config = UIButton.Configuration.tinted()
        config.image = UIImage(systemName: "crown.fill")
        config.cornerStyle = .capsule
        config.baseForegroundColor = .systemBlue

        let button = UIButton(configuration: config)
        button.addTarget(self, action: #selector(toggleCommanderDamage), for: .touchUpInside)
        button.accessibilityLabel = "Toggle commander damage"
        return button
    }()

    private lazy var compactGameSettingsButton: UIButton = {
        var config = UIButton.Configuration.plain()
        config.image = UIImage(systemName: "gearshape.fill")
        config.cornerStyle = .capsule
        config.baseForegroundColor = .systemBlue

        let button = UIButton(configuration: config)
        button.showsMenuAsPrimaryAction = true
        button.accessibilityLabel = "Game settings"
        return button
    }()

    private lazy var newGameButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.image = UIImage(systemName: "arrow.clockwise")
        config.cornerStyle = .capsule
        config.baseForegroundColor = .white
        config.baseBackgroundColor = .brandBlue
        config.contentInsets = NSDirectionalEdgeInsets(top: 9, leading: 9, bottom: 9, trailing: 9)

        let button = UIButton(configuration: config)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.22
        button.layer.shadowRadius = 12
        button.layer.shadowOffset = CGSize(width: 0, height: 6)
        button.addTarget(self, action: #selector(newGameTapped), for: .touchUpInside)
        button.accessibilityLabel = "Start new game"
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
        view.onIncrementLarge = { [weak self] in
            self?.adjustLife(for: index - 1, by: 10)
        }
        view.onDecrementLarge = { [weak self] in
            self?.adjustLife(for: index - 1, by: -10)
        }
        view.onSettings = { [weak self] in
            self?.openSettings(for: index - 1)
        }
        view.onExtras = { [weak self, weak view] in
            guard let view else {
                return
            }

            self?.showExtras(for: index - 1, sourceView: view)
        }
        view.onExtraBadgeTapped = { [weak self] kind in
            self?.incrementExtra(kind, for: index - 1)
        }
        view.onCommanderDamageIncrement = { [weak self] sourceIndex in
            self?.adjustCommanderDamage(to: index - 1, from: sourceIndex, by: 1)
        }
        view.onCommanderDamageDecrement = { [weak self] sourceIndex in
            self?.adjustCommanderDamage(to: index - 1, from: sourceIndex, by: -1)
        }
        return view
    }

    init() {
        let initialFormat = LifeCounterFormat(name: "Commander", startingLife: 40, playerCount: 4)
        self.selectedFormat = initialFormat
        self.lifeTotals = Array(repeating: initialFormat.startingLife, count: 4)
        self.playerStates = [
            LifeCounterPlayerState(name: "Player 1", colorID: "blue", backgroundImageURL: nil, backgroundImageName: nil),
            LifeCounterPlayerState(name: "Player 2", colorID: "red", backgroundImageURL: nil, backgroundImageName: nil),
            LifeCounterPlayerState(name: "Player 3", colorID: "green", backgroundImageURL: nil, backgroundImageName: nil),
            LifeCounterPlayerState(name: "Player 4", colorID: "purple", backgroundImageURL: nil, backgroundImageName: nil)
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

    deinit {
        starterSelectionTask?.cancel()
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
        view.addSubview(newGameButton)

        compactBar.addArrangedSubview(compactBackButton)
        compactBar.addArrangedSubview(compactFormatButton)
        compactBar.addArrangedSubview(compactGameSettingsButton)

        NSLayoutConstraint.activate([
            compactBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 3),
            compactBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            compactBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            compactBar.heightAnchor.constraint(equalToConstant: 32),

            compactBackButton.widthAnchor.constraint(equalToConstant: 36),
            compactGameSettingsButton.widthAnchor.constraint(equalToConstant: 36),

            gridStack.topAnchor.constraint(equalTo: compactBar.bottomAnchor, constant: 6),
            gridStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            gridStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            gridStack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -10),

            newGameButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            newGameButton.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            newGameButton.widthAnchor.constraint(equalToConstant: 42),
            newGameButton.heightAnchor.constraint(equalToConstant: 42)
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

    private func makeGameSettingsMenu() -> UIMenu {
        UIMenu(
            title: "Game Settings",
            children: [
                UIAction(
                    title: "New Game",
                    image: UIImage(systemName: "arrow.clockwise")
                ) { [weak self] _ in
                    self?.resetGameAndPickStarter()
                },
                UIAction(
                    title: "Reset Game",
                    image: UIImage(systemName: "arrow.counterclockwise")
                ) { [weak self] _ in
                    self?.resetLifeTotals()
                },
                UIAction(
                    title: "Commander Damage",
                    image: UIImage(systemName: "crown.fill"),
                    state: commanderDamageEnabled ? .on : .off
                ) { [weak self] _ in
                    self?.toggleCommanderDamage()
                }
            ]
        )
    }

    private func applyFormat(
        _ format: LifeCounterFormat,
        resetLife: Bool
    ) {
        selectedFormat = format

        if resetLife {
            lifeTotals = Array(repeating: format.startingLife, count: 4)
            commanderDamage = Array(
                repeating: Array(repeating: 0, count: 4),
                count: 4
            )
            commanderDamageEnabled = format.name == "Commander" || format.name == "Brawl"
        }

        var config = compactFormatButton.configuration
        config?.title = "\(format.name) - \(format.startingLife)"
        compactFormatButton.configuration = config
        compactFormatButton.menu = makeFormatMenu()
        refreshCommanderButton()
        compactGameSettingsButton.menu = makeGameSettingsMenu()

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
                color: color,
                isKnockedOut: isPlayerKnockedOut(index),
                isStartingPlayer: startingPlayerIndex == index,
                extrasBadges: extrasBadges(for: index),
                commanderDamageSources: commanderDamageSources(for: index),
                commanderDamageEnabled: commanderDamageEnabled
            )
        }
    }

    private func extrasBadges(for index: Int) -> [LifeCounterExtraBadge] {
        guard index < selectedFormat.playerCount else {
            return []
        }

        let state = playerStates[index]
        var badges: [LifeCounterExtraBadge] = []

        if state.poisonCounters > 0 {
            badges.append(LifeCounterExtraBadge(title: "Poison \(state.poisonCounters)", kind: .poison))
        }
        if state.radCounters > 0 {
            badges.append(LifeCounterExtraBadge(title: "Rad \(state.radCounters)", kind: .rad))
        }
        if state.experienceCounters > 0 {
            badges.append(LifeCounterExtraBadge(title: "EXP \(state.experienceCounters)", kind: .experience))
        }
        if state.energyCounters > 0 {
            badges.append(LifeCounterExtraBadge(title: "Energy \(state.energyCounters)", kind: .energy))
        }
        if state.commanderTax > 0 {
            badges.append(LifeCounterExtraBadge(title: "Tax \(state.commanderTax)", kind: .commanderTax))
        }
        if state.hasInitiative {
            badges.append(LifeCounterExtraBadge(title: "Initiative", kind: .initiative))
        }
        if state.isMonarch {
            badges.append(LifeCounterExtraBadge(title: "Monarch", kind: .monarch))
        }
        if state.hasAscended {
            badges.append(LifeCounterExtraBadge(title: "Ascend", kind: .ascend))
        }

        return badges
    }

    private func commanderDamageSources(for targetIndex: Int) -> [CommanderDamageSource] {
        guard commanderDamageEnabled, targetIndex < selectedFormat.playerCount else {
            return []
        }

        return (0..<selectedFormat.playerCount).compactMap { sourceIndex in
            guard sourceIndex != targetIndex else {
                return nil
            }

            let state = playerStates[sourceIndex]
            let color = colorOptions.first { $0.id == state.colorID }?.color ?? .systemBlue
            return CommanderDamageSource(
                playerIndex: sourceIndex,
                name: state.name,
                color: color,
                damage: commanderDamage[targetIndex][sourceIndex]
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

    private func incrementExtra(
        _ kind: LifeCounterExtraBadgeKind,
        for index: Int
    ) {
        guard index < selectedFormat.playerCount else {
            return
        }

        switch kind {
        case .poison:
            playerStates[index].poisonCounters += 1
        case .rad:
            playerStates[index].radCounters += 1
        case .experience:
            playerStates[index].experienceCounters += 1
        case .energy:
            playerStates[index].energyCounters += 1
        case .commanderTax:
            playerStates[index].commanderTax += 1
        case .initiative, .monarch, .ascend:
            return
        }

        refreshPlayerViews()
    }

    private func resetGameState() {
        lifeTotals = Array(repeating: selectedFormat.startingLife, count: 4)
        commanderDamage = Array(
            repeating: Array(repeating: 0, count: 4),
            count: 4
        )
        startingPlayerIndex = nil
        playerStates = playerStates.map { state in
            LifeCounterPlayerState(
                name: state.name,
                colorID: state.colorID,
                backgroundImageURL: state.backgroundImageURL,
                backgroundImageName: state.backgroundImageName
            )
        }
        refreshPlayerViews()
    }

    private func resetGameAndPickStarter() {
        starterSelectionTask?.cancel()
        resetGameState()

        let activePlayerCount = selectedFormat.playerCount
        guard activePlayerCount > 0 else {
            return
        }

        newGameButton.isEnabled = false
        starterSelectionTask = Task { [weak self] in
            let finalIndex = Int.random(in: 0..<activePlayerCount)
            var cycleIndexes = (0..<activePlayerCount).map { $0 }.shuffled()

            for step in 0..<14 {
                guard !Task.isCancelled else {
                    return
                }

                if cycleIndexes.isEmpty {
                    cycleIndexes = (0..<activePlayerCount).map { $0 }.shuffled()
                }

                let highlightedIndex = step == 13 ? finalIndex : cycleIndexes.removeFirst()

                await MainActor.run {
                    self?.highlightStarterCandidate(highlightedIndex)
                }

                try? await Task.sleep(nanoseconds: step < 10 ? 120_000_000 : 180_000_000)
            }

            guard !Task.isCancelled else {
                return
            }

            await MainActor.run {
                self?.highlightStarterCandidate(finalIndex)
            }

            try? await Task.sleep(nanoseconds: 1_700_000_000)

            guard !Task.isCancelled else {
                return
            }

            await MainActor.run {
                self?.startingPlayerIndex = finalIndex
                self?.clearStarterCandidateHighlights()
                self?.refreshPlayerViews()
                self?.newGameButton.isEnabled = true
            }
        }
    }

    private func highlightStarterCandidate(_ index: Int) {
        for playerIndex in playerViews.indices {
            playerViews[playerIndex].setNameHighlighted(playerIndex == index)
        }
    }

    private func clearStarterCandidateHighlights() {
        playerViews.forEach { view in
            view.setNameHighlighted(false)
        }
    }

    private func adjustCommanderDamage(
        to targetIndex: Int,
        from sourceIndex: Int,
        by amount: Int
    ) {
        guard
            commanderDamageEnabled,
            targetIndex < selectedFormat.playerCount,
            sourceIndex < selectedFormat.playerCount,
            targetIndex != sourceIndex
        else {
            return
        }

        let currentDamage = commanderDamage[targetIndex][sourceIndex]
        let updatedDamage = max(0, currentDamage + amount)
        let appliedDelta = updatedDamage - currentDamage

        guard appliedDelta != 0 else {
            return
        }

        commanderDamage[targetIndex][sourceIndex] = updatedDamage
        lifeTotals[targetIndex] -= appliedDelta
        refreshPlayerViews()
    }

    private func refreshCommanderButton() {
        compactCommanderButton.isHidden = selectedFormat.playerCount < 2

        var config = compactCommanderButton.configuration
        config?.baseForegroundColor = commanderDamageEnabled ? .systemBlue : .secondaryLabel
        config?.baseBackgroundColor = commanderDamageEnabled
            ? UIColor.systemBlue.withAlphaComponent(0.18)
            : UIColor.secondarySystemFill
        compactCommanderButton.configuration = config
        compactGameSettingsButton.menu = makeGameSettingsMenu()
    }

    private func resetPlayerLife(at index: Int) {
        guard index < selectedFormat.playerCount else {
            return
        }

        lifeTotals[index] = selectedFormat.startingLife
        for sourceIndex in 0..<commanderDamage[index].count {
            commanderDamage[index][sourceIndex] = 0
        }
        refreshPlayerViews()
    }

    private func clearCommanderDamage(for index: Int) {
        guard index < selectedFormat.playerCount else {
            return
        }

        for sourceIndex in 0..<commanderDamage[index].count {
            commanderDamage[index][sourceIndex] = 0
        }

        refreshPlayerViews()
    }

    private func updatePlayerState(
        at index: Int,
        state: LifeCounterPlayerState
    ) {
        guard index < selectedFormat.playerCount else {
            return
        }

        playerStates[index] = state
        refreshPlayerViews()
    }

    private func isPlayerKnockedOut(_ index: Int) -> Bool {
        guard index < selectedFormat.playerCount else {
            return false
        }

        return playerStates[index].manuallyKnockedOut
            || lifeTotals[index] <= 0
            || playerStates[index].poisonCounters >= 10
            || commanderDamage[index].contains { $0 >= 21 }
    }

    private func showExtras(
        for index: Int,
        sourceView: UIView
    ) {
        guard index < selectedFormat.playerCount else {
            return
        }

        let extras = LifeCounterPlayerExtrasViewController(
            playerNumber: index + 1,
            state: playerStates[index],
            lifeTotal: lifeTotals[index],
            commanderDamageSources: commanderDamageSources(for: index),
            isCommanderDamageEnabled: commanderDamageEnabled,
            isKnockedOut: isPlayerKnockedOut(index)
        )

        extras.onStateChange = { [weak self] updatedState in
            self?.updatePlayerState(at: index, state: updatedState)
        }
        extras.onCommanderDamageChange = { [weak self] sourceIndex, amount in
            self?.adjustCommanderDamage(to: index, from: sourceIndex, by: amount)
        }
        extras.onResetLife = { [weak self] in
            self?.resetPlayerLife(at: index)
        }
        extras.onOpenSettings = { [weak self, weak extras] in
            extras?.dismiss(animated: true) {
                self?.openSettings(for: index)
            }
        }

        let nav = UINavigationController(rootViewController: extras)
        if let sheet = nav.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }

        present(nav, animated: true)
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
        starterSelectionTask?.cancel()
        clearStarterCandidateHighlights()
        resetGameState()
        newGameButton.isEnabled = true
    }

    @objc private func newGameTapped() {
        resetGameAndPickStarter()
    }

    @objc private func toggleCommanderDamage() {
        commanderDamageEnabled.toggle()
        refreshCommanderButton()
        refreshPlayerViews()
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
    var onIncrementLarge: (() -> Void)?
    var onDecrementLarge: (() -> Void)?
    var onSettings: (() -> Void)?
    var onExtras: (() -> Void)?
    var onExtraBadgeTapped: ((LifeCounterExtraBadgeKind) -> Void)?
    var onCommanderDamageIncrement: ((Int) -> Void)?
    var onCommanderDamageDecrement: ((Int) -> Void)?

    private var imageLoadTask: Task<Void, Never>?
    private var representedImageURL: URL?
    private var isKnockedOutVisualState = false

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

    private let knockedOutLabel: PaddingLabel = {
        let label = PaddingLabel()
        label.text = "Knocked out"
        label.font = .systemFont(ofSize: 12, weight: .bold)
        label.textColor = .white
        label.textAlignment = .center
        label.backgroundColor = UIColor.systemRed.withAlphaComponent(0.78)
        label.layer.cornerRadius = 12
        label.layer.cornerCurve = .continuous
        label.clipsToBounds = true
        label.isHidden = true
        label.contentInsets = UIEdgeInsets(top: 5, left: 10, bottom: 5, right: 10)
        return label
    }()

    private let startingPlayerLabel: PaddingLabel = {
        let label = PaddingLabel()
        label.text = "Starts"
        label.font = .systemFont(ofSize: 12, weight: .bold)
        label.textColor = .white
        label.textAlignment = .center
        label.backgroundColor = UIColor.systemYellow.withAlphaComponent(0.82)
        label.layer.cornerRadius = 12
        label.layer.cornerCurve = .continuous
        label.clipsToBounds = true
        label.isHidden = true
        label.contentInsets = UIEdgeInsets(top: 5, left: 10, bottom: 5, right: 10)
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

    private let commanderDamageStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 6
        stack.distribution = .fillEqually
        stack.isHidden = true
        return stack
    }()

    private let extrasBadgeStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 5
        stack.distribution = .fillEqually
        stack.isHidden = true
        return stack
    }()

    private lazy var extrasButton: UIButton = {
        var config = UIButton.Configuration.tinted()
        config.title = "Extras"
        config.image = UIImage(systemName: "ellipsis.circle.fill")
        config.imagePadding = 5
        config.cornerStyle = .capsule
        config.baseForegroundColor = .white
        config.baseBackgroundColor = UIColor.white.withAlphaComponent(0.18)
        config.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10)

        let button = UIButton(configuration: config)
        button.addTarget(self, action: #selector(extrasTapped), for: .touchUpInside)
        button.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
        return button
    }()

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
        color: UIColor,
        isKnockedOut: Bool,
        isStartingPlayer: Bool,
        extrasBadges: [LifeCounterExtraBadge],
        commanderDamageSources: [CommanderDamageSource],
        commanderDamageEnabled: Bool
    ) {
        nameLabel.text = state.name
        lifeLabel.text = isActive ? "\(life)" : "--"
        isKnockedOutVisualState = isActive && isKnockedOut
        knockedOutLabel.isHidden = !isActive || !isKnockedOut
        startingPlayerLabel.isHidden = !isActive || !isStartingPlayer || isKnockedOut
        alpha = isActive ? 1 : 0.42
        decrementButton.isEnabled = isActive
        incrementButton.isEnabled = isActive
        settingsButton.isEnabled = isActive
        extrasButton.isEnabled = isActive
        backgroundColor = isKnockedOut ? .systemGray3 : color
        layer.borderColor = isKnockedOut
            ? UIColor.systemGray.cgColor
            : color.withAlphaComponent(0.7).cgColor
        configureCommanderDamage(
            sources: commanderDamageSources,
            isEnabled: isActive && commanderDamageEnabled
        )
        configureExtrasBadges(extrasBadges, isActive: isActive)
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

        let stack = UIStackView(arrangedSubviews: [nameStack, lifeLabel, knockedOutLabel, startingPlayerLabel, extrasBadgeStack, controls, commanderDamageStack, extrasButton])
        stack.axis = .vertical
        stack.spacing = 7
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
            decrementButton.heightAnchor.constraint(equalToConstant: 48),
            incrementButton.heightAnchor.constraint(equalToConstant: 48),
            extrasBadgeStack.heightAnchor.constraint(equalToConstant: 28),
            commanderDamageStack.heightAnchor.constraint(equalToConstant: 44),
            extrasButton.heightAnchor.constraint(equalToConstant: 32)
        ])
    }

    private func configureCommanderDamage(
        sources: [CommanderDamageSource],
        isEnabled: Bool
    ) {
        commanderDamageStack.arrangedSubviews.forEach { view in
            commanderDamageStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        commanderDamageStack.isHidden = !isEnabled || sources.isEmpty

        guard isEnabled else {
            return
        }

        for source in sources {
            let button = makeCommanderDamageButton(for: source)
            commanderDamageStack.addArrangedSubview(button)
        }
    }

    private func configureExtrasBadges(
        _ badges: [LifeCounterExtraBadge],
        isActive: Bool
    ) {
        extrasBadgeStack.arrangedSubviews.forEach { view in
            extrasBadgeStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        let visibleBadges = Array(badges.prefix(3))
        extrasBadgeStack.isHidden = !isActive || visibleBadges.isEmpty

        guard isActive else {
            return
        }

        for badge in visibleBadges {
            extrasBadgeStack.addArrangedSubview(makeExtrasBadge(badge))
        }
    }

    private func makeExtrasBadge(_ badge: LifeCounterExtraBadge) -> UIButton {
        var config = UIButton.Configuration.tinted()
        config.title = badge.title
        config.cornerStyle = .capsule
        config.baseForegroundColor = .white
        config.baseBackgroundColor = UIColor.white.withAlphaComponent(0.2)
        config.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 6, bottom: 4, trailing: 6)

        let button = UIButton(configuration: config)
        button.titleLabel?.font = .systemFont(ofSize: 11, weight: .bold)
        button.titleLabel?.adjustsFontSizeToFitWidth = true
        button.titleLabel?.minimumScaleFactor = 0.65
        button.addAction(
            UIAction { [weak self] _ in
                self?.onExtraBadgeTapped?(badge.kind)
            },
            for: .touchUpInside
        )
        return button
    }

    private func makeCommanderDamageButton(for source: CommanderDamageSource) -> UIButton {
        var config = UIButton.Configuration.tinted()
        config.cornerStyle = .capsule
        config.baseForegroundColor = .white
        config.baseBackgroundColor = source.damage >= 21
            ? UIColor.systemRed.withAlphaComponent(0.55)
            : source.color.withAlphaComponent(0.42)
        config.title = "\(shortPlayerName(source.name))\n\(source.damage)"
        config.contentInsets = NSDirectionalEdgeInsets(top: 5, leading: 6, bottom: 5, trailing: 6)

        let button = UIButton(configuration: config)
        button.tag = source.playerIndex
        button.titleLabel?.font = .systemFont(ofSize: 11, weight: .semibold)
        button.titleLabel?.numberOfLines = 2
        button.titleLabel?.textAlignment = .center
        button.titleLabel?.adjustsFontSizeToFitWidth = true
        button.titleLabel?.minimumScaleFactor = 0.55
        button.titleLabel?.lineBreakMode = .byWordWrapping
        button.addTarget(self, action: #selector(commanderDamageTapped(_:)), for: .touchUpInside)
        button.addGestureRecognizer(
            UILongPressGestureRecognizer(target: self, action: #selector(commanderDamageLongPressed(_:)))
        )
        button.accessibilityLabel = "Commander damage from \(source.name), \(source.damage)"
        return button
    }

    private func shortPlayerName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return "P"
        }

        let words = trimmed.split(separator: " ")
        if words.count == 2,
           words[0].localizedCaseInsensitiveCompare("Player") == .orderedSame,
           let number = words.last {
            return "P\(number)"
        }

        return String(trimmed.prefix(3)).uppercased()
    }

    private func loadBackgroundImage(_ url: URL?) {
        imageLoadTask?.cancel()
        representedImageURL = url
        backgroundImageView.image = nil
        backgroundImageView.alpha = 0
        overlayView.backgroundColor = isKnockedOutVisualState
            ? UIColor.systemGray.withAlphaComponent(0.68)
            : UIColor.black.withAlphaComponent(0.18)

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
                self?.backgroundImageView.alpha = self?.isKnockedOutVisualState == true ? 0.35 : 1
                self?.overlayView.backgroundColor = self?.isKnockedOutVisualState == true
                    ? UIColor.systemGray.withAlphaComponent(0.68)
                    : UIColor.black.withAlphaComponent(0.42)
                self?.imageLoadTask = nil
            }
        }
    }

    func setNameHighlighted(_ isHighlighted: Bool) {
        UIView.animate(withDuration: 0.14) {
            self.nameLabel.textColor = isHighlighted ? .systemYellow : .white
            self.nameLabel.transform = isHighlighted
                ? CGAffineTransform(scaleX: 1.08, y: 1.08)
                : .identity
            self.nameLabel.layer.shadowColor = UIColor.systemYellow.cgColor
            self.nameLabel.layer.shadowOpacity = isHighlighted ? 0.9 : 0
            self.nameLabel.layer.shadowRadius = isHighlighted ? 12 : 0
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
        button.addGestureRecognizer(
            UILongPressGestureRecognizer(target: self, action: #selector(lifeButtonLongPressed(_:)))
        )
        return button
    }

    @objc private func settingsTapped() {
        onSettings?()
    }

    @objc private func extrasTapped() {
        onExtras?()
    }

    @objc private func decrementTapped() {
        onDecrement?()
    }

    @objc private func incrementTapped() {
        onIncrement?()
    }

    @objc private func lifeButtonLongPressed(_ recognizer: UILongPressGestureRecognizer) {
        guard
            recognizer.state == .began,
            let button = recognizer.view as? UIButton
        else {
            return
        }

        if button === incrementButton {
            onIncrementLarge?()
        } else if button === decrementButton {
            onDecrementLarge?()
        }
    }

    @objc private func commanderDamageTapped(_ sender: UIButton) {
        onCommanderDamageIncrement?(sender.tag)
    }

    @objc private func commanderDamageLongPressed(_ recognizer: UILongPressGestureRecognizer) {
        guard recognizer.state == .began else {
            return
        }

        onExtras?()
    }
}

private final class LifeCounterPlayerExtrasViewController: UIViewController {

    var onStateChange: ((LifeCounterPlayerState) -> Void)?
    var onCommanderDamageChange: ((Int, Int) -> Void)?
    var onResetLife: (() -> Void)?
    var onOpenSettings: (() -> Void)?

    private let playerNumber: Int
    private var state: LifeCounterPlayerState
    private var lifeTotal: Int
    private var commanderDamageSources: [CommanderDamageSource]
    private let isCommanderDamageEnabled: Bool

    private let stack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let statusLabel: PaddingLabel = {
        let label = PaddingLabel()
        label.font = .systemFont(ofSize: 13, weight: .bold)
        label.textAlignment = .center
        label.layer.cornerRadius = 12
        label.layer.cornerCurve = .continuous
        label.clipsToBounds = true
        label.contentInsets = UIEdgeInsets(top: 6, left: 10, bottom: 6, right: 10)
        return label
    }()

    private let commanderGrid = UIStackView()

    init(
        playerNumber: Int,
        state: LifeCounterPlayerState,
        lifeTotal: Int,
        commanderDamageSources: [CommanderDamageSource],
        isCommanderDamageEnabled: Bool,
        isKnockedOut: Bool
    ) {
        self.playerNumber = playerNumber
        self.state = state
        self.lifeTotal = lifeTotal
        self.commanderDamageSources = commanderDamageSources
        self.isCommanderDamageEnabled = isCommanderDamageEnabled
        super.init(nibName: nil, bundle: nil)
        statusLabel.text = isKnockedOut ? "Knocked out" : "In game"
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "\(state.name) Extras"
        view.backgroundColor = .systemGroupedBackground
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            systemItem: .done,
            primaryAction: UIAction { [weak self] _ in
                self?.dismiss(animated: true)
            }
        )

        setupLayout()
        refreshStatus()
    }

    private func setupLayout() {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        scrollView.addSubview(stack)

        let quickActions = UIStackView(arrangedSubviews: [
            makeActionButton(title: "Settings", symbol: "gearshape.fill") { [weak self] in
                self?.onOpenSettings?()
            },
            makeActionButton(title: "Reset Life", symbol: "arrow.counterclockwise") { [weak self] in
                guard let self else {
                    return
                }

                self.lifeTotal = max(self.lifeTotal, 1)
                self.commanderDamageSources = self.commanderDamageSources.map { source in
                    CommanderDamageSource(
                        playerIndex: source.playerIndex,
                        name: source.name,
                        color: source.color,
                        damage: 0
                    )
                }
                self.onResetLife?()
                self.buildCommanderGrid()
                self.refreshStatus()
            }
        ])
        quickActions.axis = .horizontal
        quickActions.spacing = 10
        quickActions.distribution = .fillEqually

        commanderGrid.axis = .vertical
        commanderGrid.spacing = 10
        buildCommanderGrid()

        stack.addArrangedSubview(statusLabel)
        stack.addArrangedSubview(makeSectionLabel("Commander Damage"))
        stack.addArrangedSubview(commanderGrid)
        stack.addArrangedSubview(makeSectionLabel("Counters"))
        stack.addArrangedSubview(makeCounterRow(title: "Poison", symbol: "drop.fill") { [weak self] in
            self?.state.poisonCounters ?? 0
        } update: { [weak self] value in
            self?.state.poisonCounters = value
        })
        stack.addArrangedSubview(makeCounterRow(title: "Rad", symbol: "atom") { [weak self] in
            self?.state.radCounters ?? 0
        } update: { [weak self] value in
            self?.state.radCounters = value
        })
        stack.addArrangedSubview(makeCounterRow(title: "Experience", symbol: "star.fill") { [weak self] in
            self?.state.experienceCounters ?? 0
        } update: { [weak self] value in
            self?.state.experienceCounters = value
        })
        stack.addArrangedSubview(makeCounterRow(title: "Energy", symbol: "bolt.fill") { [weak self] in
            self?.state.energyCounters ?? 0
        } update: { [weak self] value in
            self?.state.energyCounters = value
        })
        stack.addArrangedSubview(makeCounterRow(title: "Commander Tax", symbol: "crown.fill", step: 2) { [weak self] in
            self?.state.commanderTax ?? 0
        } update: { [weak self] value in
            self?.state.commanderTax = value
        })
        stack.addArrangedSubview(makeSectionLabel("Game Status"))
        stack.addArrangedSubview(makeToggleRow(title: "Initiative", symbol: "figure.run") { [weak self] in
            self?.state.hasInitiative ?? false
        } update: { [weak self] value in
            self?.state.hasInitiative = value
        })
        stack.addArrangedSubview(makeToggleRow(title: "Monarch", symbol: "crown") { [weak self] in
            self?.state.isMonarch ?? false
        } update: { [weak self] value in
            self?.state.isMonarch = value
        })
        stack.addArrangedSubview(makeToggleRow(title: "Ascend", symbol: "sparkles") { [weak self] in
            self?.state.hasAscended ?? false
        } update: { [weak self] value in
            self?.state.hasAscended = value
        })
        stack.addArrangedSubview(makeToggleRow(title: "Knocked Out", symbol: "xmark.octagon.fill") { [weak self] in
            self?.state.manuallyKnockedOut ?? false
        } update: { [weak self] value in
            self?.state.manuallyKnockedOut = value
        })
        stack.addArrangedSubview(quickActions)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 18),
            stack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -28),
            stack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -32)
        ])
    }

    private func buildCommanderGrid() {
        commanderGrid.arrangedSubviews.forEach { view in
            commanderGrid.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        guard isCommanderDamageEnabled, !commanderDamageSources.isEmpty else {
            commanderGrid.addArrangedSubview(makeEmptyLabel("Commander damage is off for this game."))
            return
        }

        let sourcesByPlayer = Dictionary(
            uniqueKeysWithValues: commanderDamageSources.map { ($0.playerIndex, $0) }
        )

        for rowIndexes in [[0, 1], [2, 3]] {
            let row = UIStackView()
            row.axis = .horizontal
            row.spacing = 10
            row.distribution = .fillEqually

            for playerIndex in rowIndexes {
                if let source = sourcesByPlayer[playerIndex] {
                    row.addArrangedSubview(makeCommanderTile(for: source))
                } else {
                    row.addArrangedSubview(makeCommanderPlaceholder())
                }
            }

            commanderGrid.addArrangedSubview(row)
        }
    }

    private func makeCommanderPlaceholder() -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false
        view.alpha = 0
        view.heightAnchor.constraint(equalToConstant: 64).isActive = true
        return view
    }

    private func makeCommanderTile(for source: CommanderDamageSource) -> UIView {
        let tile = UIView()
        tile.backgroundColor = source.damage >= 21
            ? UIColor.systemRed.withAlphaComponent(0.7)
            : source.color.withAlphaComponent(0.5)
        tile.layer.cornerRadius = 14
        tile.layer.cornerCurve = .continuous
        tile.heightAnchor.constraint(equalToConstant: 72).isActive = true

        let minusButton = makeCommanderAdjustButton(symbol: "minus") { [weak self] in
            self?.updateCommanderDamage(from: source.playerIndex, by: -1)
        }
        let plusButton = makeCommanderAdjustButton(symbol: "plus") { [weak self] in
            self?.updateCommanderDamage(from: source.playerIndex, by: 1)
        }

        let label = UILabel()
        label.text = "\(source.name)\n\(source.damage)"
        label.font = .systemFont(ofSize: 15, weight: .bold)
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 2
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.65

        let row = UIStackView(arrangedSubviews: [minusButton, label, plusButton])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 8
        row.translatesAutoresizingMaskIntoConstraints = false

        tile.addSubview(row)

        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: tile.topAnchor, constant: 10),
            row.leadingAnchor.constraint(equalTo: tile.leadingAnchor, constant: 10),
            row.trailingAnchor.constraint(equalTo: tile.trailingAnchor, constant: -10),
            row.bottomAnchor.constraint(equalTo: tile.bottomAnchor, constant: -10),
            minusButton.widthAnchor.constraint(equalToConstant: 32),
            plusButton.widthAnchor.constraint(equalToConstant: 32)
        ])

        return tile
    }

    private func makeCommanderAdjustButton(
        symbol: String,
        action: @escaping () -> Void
    ) -> UIButton {
        var config = UIButton.Configuration.filled()
        config.image = UIImage(systemName: symbol)
        config.cornerStyle = .capsule
        config.baseBackgroundColor = UIColor.white.withAlphaComponent(0.22)
        config.baseForegroundColor = .white
        config.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 6, bottom: 6, trailing: 6)

        let button = UIButton(configuration: config)
        button.addAction(UIAction { _ in action() }, for: .touchUpInside)
        return button
    }

    private func makeCounterRow(
        title: String,
        symbol: String,
        step: Int = 1,
        value: @escaping () -> Int,
        update: @escaping (Int) -> Void
    ) -> UIView {
        let row = makeBaseRow(title: title, symbol: symbol)
        let valueLabel = makeValueLabel("\(value())")
        let minus = makeStepperButton(symbol: "minus") {
            let updated = max(0, value() - step)
            update(updated)
            valueLabel.text = "\(updated)"
            self.publishState()
        }
        let plus = makeStepperButton(symbol: "plus") {
            let updated = value() + step
            update(updated)
            valueLabel.text = "\(updated)"
            self.publishState()
        }

        row.addArrangedSubview(minus)
        row.addArrangedSubview(valueLabel)
        row.addArrangedSubview(plus)
        return row
    }

    private func makeToggleRow(
        title: String,
        symbol: String,
        value: @escaping () -> Bool,
        update: @escaping (Bool) -> Void
    ) -> UIView {
        let row = makeBaseRow(title: title, symbol: symbol)
        let toggle = UISwitch()
        toggle.isOn = value()
        toggle.addAction(
            UIAction { [weak self, weak toggle] _ in
                guard let toggle else {
                    return
                }

                update(toggle.isOn)
                self?.publishState()
            },
            for: .valueChanged
        )
        row.addArrangedSubview(toggle)
        return row
    }

    private func makeBaseRow(
        title: String,
        symbol: String
    ) -> UIStackView {
        let iconView = UIImageView(image: UIImage(systemName: symbol))
        iconView.tintColor = .label
        iconView.contentMode = .scaleAspectFit
        iconView.widthAnchor.constraint(equalToConstant: 28).isActive = true

        let label = UILabel()
        label.text = title
        label.font = .systemFont(ofSize: 17, weight: .semibold)

        let row = UIStackView(arrangedSubviews: [iconView, label])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 12
        row.isLayoutMarginsRelativeArrangement = true
        row.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14)
        row.backgroundColor = .secondarySystemGroupedBackground
        row.layer.cornerRadius = 14
        row.layer.cornerCurve = .continuous
        return row
    }

    private func makeStepperButton(
        symbol: String,
        action: @escaping () -> Void
    ) -> UIButton {
        var config = UIButton.Configuration.tinted()
        config.image = UIImage(systemName: symbol)
        config.cornerStyle = .capsule
        config.baseForegroundColor = .label
        config.baseBackgroundColor = .tertiarySystemFill

        let button = UIButton(configuration: config)
        button.widthAnchor.constraint(equalToConstant: 42).isActive = true
        button.heightAnchor.constraint(equalToConstant: 34).isActive = true
        button.addAction(UIAction { _ in action() }, for: .touchUpInside)
        return button
    }

    private func makeActionButton(
        title: String,
        symbol: String,
        action: @escaping () -> Void
    ) -> UIButton {
        var config = UIButton.Configuration.tinted()
        config.title = title
        config.image = UIImage(systemName: symbol)
        config.imagePadding = 6
        config.cornerStyle = .large
        config.baseForegroundColor = .label
        config.baseBackgroundColor = .secondarySystemGroupedBackground

        let button = UIButton(configuration: config)
        button.heightAnchor.constraint(equalToConstant: 48).isActive = true
        button.addAction(UIAction { _ in action() }, for: .touchUpInside)
        return button
    }

    private func makeValueLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 18, weight: .bold)
        label.textAlignment = .center
        label.widthAnchor.constraint(equalToConstant: 42).isActive = true
        return label
    }

    private func makeSectionLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 15, weight: .bold)
        label.textColor = .secondaryLabel
        return label
    }

    private func makeEmptyLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.backgroundColor = .secondarySystemGroupedBackground
        label.layer.cornerRadius = 14
        label.layer.cornerCurve = .continuous
        label.clipsToBounds = true
        label.heightAnchor.constraint(equalToConstant: 54).isActive = true
        return label
    }

    private func publishState() {
        onStateChange?(state)
        refreshStatus()
    }

    private func refreshStatus() {
        let isKnockedOut = state.manuallyKnockedOut
            || lifeTotal <= 0
            || state.poisonCounters >= 10
            || commanderDamageSources.contains { $0.damage >= 21 }

        statusLabel.text = isKnockedOut ? "Knocked out" : "In game"
        statusLabel.textColor = .white
        statusLabel.backgroundColor = isKnockedOut
            ? UIColor.systemRed.withAlphaComponent(0.82)
            : UIColor.systemGreen.withAlphaComponent(0.82)
    }

    private func updateCommanderDamage(
        from sourceIndex: Int,
        by amount: Int
    ) {
        guard let index = commanderDamageSources.firstIndex(where: { $0.playerIndex == sourceIndex }) else {
            return
        }

        let currentSource = commanderDamageSources[index]
        let updatedDamage = max(0, currentSource.damage + amount)
        let appliedDelta = updatedDamage - currentSource.damage

        guard appliedDelta != 0 else {
            return
        }

        commanderDamageSources[index] = CommanderDamageSource(
            playerIndex: currentSource.playerIndex,
            name: currentSource.name,
            color: currentSource.color,
            damage: updatedDamage
        )
        lifeTotal -= appliedDelta
        onCommanderDamageChange?(sourceIndex, appliedDelta)
        buildCommanderGrid()
        refreshStatus()
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
        if let imageName = state.backgroundImageName, state.backgroundImageURL != nil {
            imageStatusLabel.text = "Background image: \(imageName)"
        } else {
            imageStatusLabel.text = "No background image selected."
        }
    }

    @objc private func colorTapped(_ sender: UIButton) {
        let option = colorOptions[sender.tag]
        state.colorID = option.id
        buildColorButtons()
    }

    @objc private func clearImageTapped() {
        state.backgroundImageURL = nil
        state.backgroundImageName = nil
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
        state.backgroundImageName = card.name
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
