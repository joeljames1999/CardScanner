import UIKit
import AVFoundation
import Vision
import CoreImage
import Combine

final class ScannerViewController: UIViewController {

    // MARK: - Services & ViewModel

    private let cameraService = CameraService()
    private let ocrService    = OCRService()
    private let viewModel     = ScannerViewModel()
    private var cancellables  = Set<AnyCancellable>()
    private var printingOverlay: PrintingSelectionOverlayView?
    private var addCardOverlay: AddCardOverlayView?

    private var isFastScanEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: Self.fastScanDefaultsKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.fastScanDefaultsKey) }
    }

    private var baseLanguage: ScannerLanguage {
        get {
            ScannerLanguages.language(
                for: UserDefaults.standard.string(forKey: Self.baseLanguageDefaultsKey)
            )
        }
        set {
            UserDefaults.standard.set(newValue.code, forKey: Self.baseLanguageDefaultsKey)
        }
    }

    private static let fastScanDefaultsKey = "scanner.fastScanEnabled"
    private static let baseLanguageDefaultsKey = "scanner.baseLanguage"

    // MARK: - UI

    private lazy var cameraContainerView: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = .black
        return v
    }()

    private lazy var overlayView: ScannerOverlayView = {
        let v = ScannerOverlayView()
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private lazy var statusLabel: UILabel = {
        let lbl = UILabel()
        lbl.translatesAutoresizingMaskIntoConstraints = false
        lbl.text               = "Point camera at a Magic card"
        lbl.textColor          = .white
        lbl.textAlignment      = .center
        lbl.font               = .systemFont(ofSize: 14, weight: .medium)
        lbl.numberOfLines      = 2
        lbl.backgroundColor = .clear
        lbl.font = .systemFont(
            ofSize: 24,
            weight: .semibold
        )
        lbl.layer.cornerRadius = 8
        lbl.clipsToBounds      = true
        return lbl
    }()

    private lazy var sessionButton: UIBarButtonItem = {
        UIBarButtonItem(
            image: UIImage(systemName: "tray.full"),
            style: .plain,
            target: self,
            action: #selector(openSession)
        )
    }()
    
    private let bottomPanel = UIVisualEffectView(
        effect: UIBlurEffect(style: .systemUltraThinMaterialDark)
    )
    
    private let scannerGlow = UIView()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Scan Cards"
        configureNavigationItems()
        setupLayout()
        setupCamera()
        bindViewModel()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        cameraService.start()
        viewModel.startScanning()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        cameraService.stop()
        viewModel.stopScanning()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        cameraService.previewLayer?.frame = cameraContainerView.bounds
    }

    // MARK: - Navigation

    private func configureNavigationItems() {
        navigationItem.rightBarButtonItems = [
            sessionButton,
            UIBarButtonItem(
                image: UIImage(systemName: "gearshape"),
                menu: makeSettingsMenu()
            )
        ]
    }

    private func makeSettingsMenu() -> UIMenu {
        let fastScanAction = UIAction(
            title: "Fast Scan",
            image: UIImage(systemName: "bolt.fill"),
            state: isFastScanEnabled ? .on : .off
        ) { [weak self] _ in
            guard let self else { return }
            self.isFastScanEnabled.toggle()
            self.configureNavigationItems()
        }

        let languageMenu = UIMenu(
            title: "Base Language",
            image: UIImage(systemName: "globe"),
            children: ScannerLanguages.all.map { language in
                UIAction(
                    title: language.name,
                    state: language.code == baseLanguage.code ? .on : .off
                ) { [weak self] _ in
                    guard let self else { return }
                    self.baseLanguage = language
                    self.configureNavigationItems()
                }
            }
        )

        return UIMenu(
            title: "Scanner Settings",
            children: [fastScanAction, languageMenu]
        )
    }

    // MARK: - Layout

    private func setupLayout() {
        view.backgroundColor = .black
        scannerGlow.backgroundColor =
        UIColor.brandBlue.withAlphaComponent(0.25)
        
        let gradient = CAGradientLayer()

        gradient.colors = [
            UIColor.brandBlue.withAlphaComponent(0.35).cgColor,
            UIColor.clear.cgColor
        ]
        view.addSubview(cameraContainerView)
        view.addSubview(overlayView)
        view.addSubview(statusLabel)

        NSLayoutConstraint.activate([
            cameraContainerView.topAnchor.constraint(
                equalTo: view.topAnchor
            ),

            cameraContainerView.leadingAnchor.constraint(
                equalTo: view.leadingAnchor
            ),

            cameraContainerView.trailingAnchor.constraint(
                equalTo: view.trailingAnchor
            ),

            cameraContainerView.bottomAnchor.constraint(
                equalTo: view.bottomAnchor
            ),

            overlayView.topAnchor.constraint(equalTo: cameraContainerView.topAnchor),
            overlayView.leadingAnchor.constraint(equalTo: cameraContainerView.leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: cameraContainerView.trailingAnchor),
            overlayView.bottomAnchor.constraint(equalTo: cameraContainerView.bottomAnchor),

            statusLabel.topAnchor.constraint(equalTo: cameraContainerView.bottomAnchor, constant: 12),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            
            bottomPanel.heightAnchor.constraint(
                equalToConstant: 140
            )
        ])
    }

    // MARK: - Camera Setup

    private func setupCamera() {
        CameraService.requestPermission { [weak self] granted in
            DispatchQueue.main.async {
                guard let self else { return }
                guard granted else {
                    self.showPermissionDenied()
                    return
                }
                self.setupFrameCallback()
                self.cameraService.configure(in: self.cameraContainerView)
            }
        }
    }

    private func setupFrameCallback() {

        cameraService.onFrameCaptured = { [weak self] pixelBuffer in
            guard let self else { return }
            self.ocrService.processFrame(pixelBuffer)
        }

        ocrService.onCardImageCaptured = { [weak self] cardImage, result in
            guard let self else { return }

            Task { @MainActor in
                self.viewModel.processCardImage(
                    cardImage,
                    ocrResult: result
                )
            }
        }

        ocrService.onRectangleDetected = { [weak self] rect in
            guard let self else { return }

            DispatchQueue.main.async {
                self.overlayView.updateDetectedRect(
                    rect,
                    previewLayer: self.cameraService.previewLayer
                )
            }
        }
    }
    
    private func showPrintingOverlay(
        printings: [MTGCard]
    ) {

        printingOverlay?.removeFromSuperview()

        let overlay = PrintingSelectionOverlayView(
            printings: printings
        )

        overlay.translatesAutoresizingMaskIntoConstraints = false

        overlay.onSelect = { [weak self] card in

            guard let self else { return }

            overlay.removeFromSuperview()

            self.showAddCardOverlay(
                card: card
            )
        }

        overlay.onCancel = { [weak self] in

            guard let self else { return }

            overlay.removeFromSuperview()
            self.printingOverlay = nil

            self.overlayView.resetToScanning()
            self.ocrService.resetForNextScan()
            self.viewModel.resetToScanning()
        }

        view.addSubview(overlay)

        NSLayoutConstraint.activate([
            overlay.leadingAnchor.constraint(
                equalTo: view.leadingAnchor
            ),
            overlay.trailingAnchor.constraint(
                equalTo: view.trailingAnchor
            ),
            overlay.topAnchor.constraint(
                equalTo: view.topAnchor
            ),
            overlay.bottomAnchor.constraint(
                equalTo: view.bottomAnchor
            )
        ])

        printingOverlay = overlay
    }
    
    private func showAddCardOverlay(
        card: MTGCard
    ) {

        addCardOverlay?.removeFromSuperview()

        let overlay = AddCardOverlayView(
            card: card,
            availableLanguages: availableLanguages(for: card),
            baseLanguage: baseLanguage
        )

        overlay.translatesAutoresizingMaskIntoConstraints = false

        overlay.onAdd = { [weak self] details in

            guard let self else { return }

            let entry = SessionEntry(
                card: card,
                count: details.quantity,
                isFoil: details.isFoil,
                finish: details.finish,
                isAltered: details.isAltered,
                language: details.language
            )

            SessionStore.shared.add(entry)

            overlay.removeFromSuperview()
            self.addCardOverlay = nil

            self.showAddedToast(for: card)

            self.overlayView.resetToScanning()
            self.ocrService.resetForNextScan()
            self.viewModel.resetToScanning()
        }

        overlay.onCancel = { [weak self] in

            guard let self else { return }

            overlay.removeFromSuperview()
            self.addCardOverlay = nil

            self.overlayView.resetToScanning()
            self.ocrService.resetForNextScan()
            self.viewModel.resetToScanning()
        }

        view.addSubview(overlay)
        addCardOverlay = overlay

        NSLayoutConstraint.activate([
            overlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            overlay.topAnchor.constraint(equalTo: view.topAnchor),
            overlay.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func availableLanguages(for card: MTGCard) -> [ScannerLanguage] {
        let codes = (try? AppDatabase.shared.cards.languages(
            name: card.name,
            set: card.set,
            collectorNumber: card.collectorNumber
        )) ?? [card.language ?? "en"]

        return ScannerLanguages.available(from: codes)
    }

    // MARK: - ViewModel Binding

    private func bindViewModel() {
        viewModel.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in self?.handleStateChange(state) }
            .store(in: &cancellables)
    }

    private func handleStateChange(_ state: ScannerState) {
        switch state {
        case .idle:
            overlayView.resetToScanning()
            statusLabel.text = "Point camera at a Magic card"

        case .scanning:
            overlayView.resetToScanning()
            statusLabel.text = "Hold card steady…"
            ocrService.resetForNextScan()

        case .found(let card):

            statusLabel.text = card.name

            if isFastScanEnabled {
                autoAddScannedCard(card)
            } else {
                showAddCardOverlay(card: card)
            }

        case .selectPrinting(let printings):

            print(
                "[ScannerVC] Showing printing picker:",
                printings.count
            )

            overlayView.showFound(
                cardName: printings.first?.name ?? ""
            )

            if isFastScanEnabled, let card = mostRecentPrinting(from: printings) {
                statusLabel.text = card.name
                autoAddScannedCard(card)
            } else {
                showPrintingOverlay(
                    printings: printings
                )
            }

        case .error(let message):
            overlayView.resetToScanning()
            statusLabel.text = message
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                self?.viewModel.resetToScanning()
                self?.ocrService.resetForNextScan()
            }
        }
    }

    // MARK: - Fast Scan

    private func autoAddScannedCard(_ card: MTGCard) {
        let languages = availableLanguages(for: card)
        let language = languages.first {
            $0.code == baseLanguage.code
        } ?? languages.first ?? baseLanguage

        SessionStore.shared.add(
            SessionEntry(
                card: card,
                language: language.name
            )
        )

        showAddedToast(for: card)
        overlayView.resetToScanning()
        ocrService.resetForNextScan()
        viewModel.resetToScanning()
    }

    private func mostRecentPrinting(from printings: [MTGCard]) -> MTGCard? {
        printings.max { lhs, rhs in
            (lhs.releasedAt ?? "") < (rhs.releasedAt ?? "")
        } ?? printings.first
    }

    // MARK: - Set Picker

    private func presentSetPicker(printings: [MTGCard]) {
        guard presentedViewController == nil else { return }

        let pickerVC = SetPickerViewController(
            cardName: printings.first?.name ?? "",
            printings: printings
        )

        pickerVC.onSelect = { [weak self] card in

            guard let self else { return }

            self.showAddCardOverlay(
                card: card
            )
        }
        
        pickerVC.onDismiss = { [weak self] in

            self?.overlayView.resetToScanning()

            self?.ocrService.resetForNextScan()

            self?.viewModel.resetToScanning()
        }

        let nav = UINavigationController(rootViewController: pickerVC)
        if let sheet = nav.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
            sheet.prefersScrollingExpandsWhenScrolledToEdge = true
        }
        present(nav, animated: true)
    }

    // MARK: - Toast

    private func showAddedToast(for card: MTGCard) {
        let toast = UIView()
        toast.backgroundColor    = UIColor.systemGreen.withAlphaComponent(0.92)
        toast.layer.cornerRadius = 14
        toast.clipsToBounds      = true
        toast.translatesAutoresizingMaskIntoConstraints = false
        toast.alpha = 0

        let icon = UIImageView(image: UIImage(systemName: "checkmark.circle.fill"))
        icon.tintColor    = .white
        icon.contentMode  = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false

        let nameLabel = UILabel()
        nameLabel.text      = card.name
        nameLabel.font      = .systemFont(ofSize: 15, weight: .semibold)
        nameLabel.textColor = .white

        let subLabel = UILabel()
        subLabel.text      = "\(card.setName) · Added to session"
        subLabel.font      = .systemFont(ofSize: 12)
        subLabel.textColor = UIColor.white.withAlphaComponent(0.85)

        let textStack = UIStackView(arrangedSubviews: [nameLabel, subLabel])
        textStack.axis    = .vertical
        textStack.spacing = 2
        textStack.translatesAutoresizingMaskIntoConstraints = false

        let hStack = UIStackView(arrangedSubviews: [icon, textStack])
        hStack.axis      = .horizontal
        hStack.spacing   = 10
        hStack.alignment = .center
        hStack.translatesAutoresizingMaskIntoConstraints = false

        toast.addSubview(hStack)
        view.addSubview(toast)

        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: 24),
            icon.heightAnchor.constraint(equalToConstant: 24),

            hStack.topAnchor.constraint(equalTo: toast.topAnchor, constant: 12),
            hStack.bottomAnchor.constraint(equalTo: toast.bottomAnchor, constant: -12),
            hStack.leadingAnchor.constraint(equalTo: toast.leadingAnchor, constant: 16),
            hStack.trailingAnchor.constraint(equalTo: toast.trailingAnchor, constant: -16),

            toast.bottomAnchor.constraint(equalTo: cameraContainerView.bottomAnchor, constant: -24),
            toast.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])

        UIView.animate(withDuration: 0.25) { toast.alpha = 1 }
        UIView.animate(withDuration: 0.3, delay: 1.8, options: .curveEaseIn) {
            toast.alpha = 0
        } completion: { _ in
            toast.removeFromSuperview()
        }

        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    // MARK: - Actions

    @objc private func openSession() {
        let sessionVC = SessionViewController()
        sessionVC.onCommit = { [weak self] in
            self?.tabBarController?.selectedIndex = 3
        }
        let nav = UINavigationController(rootViewController: sessionVC)
        if let sheet = nav.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
        present(nav, animated: true)
    }

    private func showPermissionDenied() {
        statusLabel.text = "Camera access denied. Enable it in Settings."
    }
}
