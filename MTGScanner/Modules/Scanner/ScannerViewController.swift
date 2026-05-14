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
        lbl.backgroundColor    = UIColor.black.withAlphaComponent(0.5)
        lbl.layer.cornerRadius = 8
        lbl.clipsToBounds      = true
        return lbl
    }()

    private lazy var indexBadge: UILabel = {
        let lbl = UILabel()
        lbl.translatesAutoresizingMaskIntoConstraints = false
        lbl.font               = .systemFont(ofSize: 11, weight: .medium)
        lbl.textColor          = .white
        lbl.textAlignment      = .center
        lbl.backgroundColor    = UIColor.systemBlue.withAlphaComponent(0.75)
        lbl.layer.cornerRadius = 10
        lbl.clipsToBounds      = true
        lbl.text               = "0 cards indexed"
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

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "MTG Scanner"
        navigationItem.rightBarButtonItem = sessionButton
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

    // MARK: - Layout

    private func setupLayout() {
        view.backgroundColor = .black

        view.addSubview(cameraContainerView)
        view.addSubview(overlayView)
        view.addSubview(statusLabel)
        view.addSubview(indexBadge)

        NSLayoutConstraint.activate([
            cameraContainerView.topAnchor.constraint(equalTo: view.topAnchor),
            cameraContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            cameraContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            cameraContainerView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.72),

            overlayView.topAnchor.constraint(equalTo: cameraContainerView.topAnchor),
            overlayView.leadingAnchor.constraint(equalTo: cameraContainerView.leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: cameraContainerView.trailingAnchor),
            overlayView.bottomAnchor.constraint(equalTo: cameraContainerView.bottomAnchor),

            statusLabel.topAnchor.constraint(equalTo: cameraContainerView.bottomAnchor, constant: 12),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            indexBadge.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 8),
            indexBadge.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            indexBadge.widthAnchor.constraint(greaterThanOrEqualToConstant: 140),
            indexBadge.heightAnchor.constraint(equalToConstant: 22),
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

        ocrService.onCardImageCaptured = { [weak self] cardImage in
            guard let self else { return }
            Task { @MainActor in
                self.viewModel.processCardImage(cardImage)
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

    // MARK: - ViewModel Binding

    private func bindViewModel() {
        viewModel.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in self?.handleStateChange(state) }
            .store(in: &cancellables)

        viewModel.$hashIndexCount
            .receive(on: DispatchQueue.main)
            .sink { [weak self] count in
                self?.indexBadge.text = "  \(count) card\(count == 1 ? "" : "s") indexed  "
            }
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
            // Single printing — auto-added in VM, just show toast
            overlayView.showFound(cardName: card.name)
            statusLabel.text = "Added: \(card.name)"
            showAddedToast(for: card)
            ocrService.resetForNextScan()
            // Auto-reset after toast
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                self?.viewModel.resetToScanning()
            }

        case .selectPrinting(let printings):
            // Multiple printings — show picker sheet
            overlayView.showFound(cardName: printings.first?.name ?? "")
            statusLabel.text = "Select your printing"
            ocrService.resetForNextScan()
            presentSetPicker(printings: printings)

        case .error(let message):
            overlayView.resetToScanning()
            statusLabel.text = message
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                self?.viewModel.resetToScanning()
                self?.ocrService.resetForNextScan()
            }
        }
    }

    // MARK: - Set Picker

    private func presentSetPicker(printings: [MTGCard]) {
        guard presentedViewController == nil else { return }

        let pickerVC = SetPickerViewController(
            cardName: printings.first?.name ?? "",
            printings: printings
        )

        pickerVC.onSelect = { [weak self] card in
            SessionStore.shared.addOrIncrement(card: card)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            self?.showAddedToast(for: card)
            self?.viewModel.resetToScanning()
        }

        pickerVC.onDismiss = { [weak self] in
            self?.viewModel.resetToScanning()
            self?.ocrService.resetForNextScan()
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
