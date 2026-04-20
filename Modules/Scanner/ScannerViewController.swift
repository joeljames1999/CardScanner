import UIKit
import Combine

// MARK: - ScannerViewController

final class ScannerViewController: UIViewController {

    // MARK: Services & ViewModel

    private let cameraService = CameraService()
    private let ocrService    = OCRService()
    private let viewModel     = ScannerViewModel()
    private var cancellables  = Set<AnyCancellable>()

    // MARK: UI

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

    private lazy var scanButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.title         = "Scan Card"
        config.image         = UIImage(systemName: "viewfinder")
        config.imagePadding  = 8
        config.baseBackgroundColor = .systemBlue
        config.cornerStyle   = .capsule
        let btn = UIButton(configuration: config)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.addTarget(self, action: #selector(scanButtonTapped), for: .touchUpInside)
        return btn
    }()

    private lazy var statusLabel: UILabel = {
        let lbl = UILabel()
        lbl.translatesAutoresizingMaskIntoConstraints = false
        lbl.text          = "Point camera at a Magic card"
        lbl.textColor     = .white
        lbl.textAlignment = .center
        lbl.font          = .systemFont(ofSize: 14, weight: .medium)
        lbl.numberOfLines = 2
        return lbl
    }()

    private lazy var collectionButton: UIBarButtonItem = {
        UIBarButtonItem(
            image: UIImage(systemName: "rectangle.stack"),
            style: .plain,
            target: self,
            action: #selector(openCollection)
        )
    }()

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "MTG Scanner"
        navigationItem.rightBarButtonItem = collectionButton
        setupLayout()
        setupCamera()
        bindViewModel()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        cameraService.start()
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

    // MARK: Layout

    private func setupLayout() {
        view.backgroundColor = .systemBackground

        view.addSubview(cameraContainerView)
        view.addSubview(overlayView)
        view.addSubview(statusLabel)
        view.addSubview(scanButton)

        NSLayoutConstraint.activate([
            cameraContainerView.topAnchor.constraint(equalTo: view.topAnchor),
            cameraContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            cameraContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            cameraContainerView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.72),

            overlayView.topAnchor.constraint(equalTo: cameraContainerView.topAnchor),
            overlayView.leadingAnchor.constraint(equalTo: cameraContainerView.leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: cameraContainerView.trailingAnchor),
            overlayView.bottomAnchor.constraint(equalTo: cameraContainerView.bottomAnchor),

            statusLabel.topAnchor.constraint(equalTo: cameraContainerView.bottomAnchor, constant: 16),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            scanButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
            scanButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            scanButton.widthAnchor.constraint(equalToConstant: 160),
            scanButton.heightAnchor.constraint(equalToConstant: 50),
        ])
    }

    // MARK: Camera Setup

    private func setupCamera() {
        CameraService.requestPermission { [weak self] granted in
            DispatchQueue.main.async {
                guard let self else { return }
                if granted {
                    self.cameraService.configure(in: self.cameraContainerView)
                    self.cameraService.start()
                    self.setupFrameCallback()
                } else {
                    self.showPermissionDenied()
                }
            }
        }
    }

    private func setupFrameCallback() {
        cameraService.onFrameCaptured = { [weak self] pixelBuffer in
            guard let self else { return }
            self.ocrService.recognizeCardName(in: pixelBuffer) { name in
                // Already on main thread from OCRService
                guard let name else { return }
                self.viewModel.handleDetectedText(name)
            }
        }
    }

    // MARK: ViewModel Binding

    private func bindViewModel() {
        viewModel.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.handleStateChange(state)
            }
            .store(in: &cancellables)
    }

    private func handleStateChange(_ state: ScannerState) {
        switch state {
        case .idle:
            overlayView.setState(.idle)
            statusLabel.text = "Point camera at a Magic card"

        case .scanning:
            overlayView.setState(.scanning)
            statusLabel.text = "Looking for card name…"

        case .found(let card):
            overlayView.setState(.found)
            statusLabel.text = "Found: \(card.name)"
            presentCardDetail(card)

        case .error(let message):
            overlayView.setState(.idle)
            statusLabel.text = message
        }
    }

    // MARK: Actions

    @objc private func scanButtonTapped() {
        ocrService.resetThrottle()
        viewModel.startScanning()
    }

    @objc private func openCollection() {
        let collectionVC = CollectionViewController()
        navigationController?.pushViewController(collectionVC, animated: true)
    }

    private func presentCardDetail(_ card: MTGCard) {
        let detailVC = CardDetailViewController(card: card)
        detailVC.onDismiss = { [weak self] in
            self?.viewModel.resetToScanning()
        }
        let nav = UINavigationController(rootViewController: detailVC)
        if let sheet = nav.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
        present(nav, animated: true)
    }

    // MARK: Error States

    private func showPermissionDenied() {
        statusLabel.text = "Camera access denied. Enable it in Settings."
        scanButton.isEnabled = false
    }
}
