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
        v.backgroundColor = .black
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private lazy var overlayView: ScannerOverlayView = {
        let v = ScannerOverlayView()
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private lazy var hintLabel: UILabel = {
        let lbl = UILabel()
        lbl.translatesAutoresizingMaskIntoConstraints = false
        lbl.text          = "Point camera at a Magic card"
        lbl.textColor     = .white
        lbl.textAlignment = .center
        lbl.font          = .systemFont(ofSize: 13, weight: .medium)
        lbl.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        lbl.layer.cornerRadius = 10
        lbl.clipsToBounds = true
        return lbl
    }()

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        title = "TCG Scanner"
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "rectangle.stack"),
            style: .plain,
            target: self,
            action: #selector(openCollection)
        )
        setupLayout()
        setupCamera()
        setupOCRCallbacks()
        bindViewModel()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        cameraService.start()
        viewModel.resetAfterPresentation()
        ocrService.resetCooldown()
        overlayView.resetToScanning()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        cameraService.stop()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        cameraService.previewLayer?.frame = cameraContainerView.bounds
    }

    // MARK: Layout

    private func setupLayout() {
        view.addSubview(cameraContainerView)
        view.addSubview(overlayView)
        view.addSubview(hintLabel)

        NSLayoutConstraint.activate([
            cameraContainerView.topAnchor.constraint(equalTo: view.topAnchor),
            cameraContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            cameraContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            cameraContainerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            overlayView.topAnchor.constraint(equalTo: view.topAnchor),
            overlayView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            overlayView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            hintLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            hintLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            hintLabel.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, constant: -40),
            hintLabel.heightAnchor.constraint(equalToConstant: 36),
        ])

        // Add padding to hintLabel
        hintLabel.setContentHuggingPriority(.required, for: .horizontal)
    }

    // MARK: Camera

    private func setupCamera() {
        CameraService.requestPermission { [weak self] granted in
            guard let self else { return }

            DispatchQueue.main.async {
                if granted {
                    self.cameraService.configure(in: self.cameraContainerView)

                    self.cameraService.onFrameCaptured = { [weak self] buffer in
                        self?.ocrService.processFrame(buffer)
                    }

                    self.cameraService.start()
                } else {
                    self.hintLabel.text = "Camera access required"
                }
            }
        }
    }

    // MARK: OCR Callbacks

    private func setupOCRCallbacks() {
        // Live rectangle tracking — update overlay on every frame
        ocrService.onRectangleDetected = { [weak self] normRect in
            self?.overlayView.updateDetectedRect(normRect)
        }

        // Card name identified — look it up
        ocrService.onCardDetected = { [weak self] name in
            self?.viewModel.handleDetectedName(name)
        }
    }

    // MARK: ViewModel Binding

    private func bindViewModel() {
        viewModel.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in self?.handleState(state) }
            .store(in: &cancellables)
    }

    private func handleState(_ state: ScannerState) {
        switch state {
        case .idle:
            hintLabel.text = "Point camera at a Magic card"
            overlayView.resetToScanning()

        case .detecting:
            hintLabel.text = "Identifying card…"

        case .found(let card):
            overlayView.showFound(cardName: card.name)
            hintLabel.text = card.name
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            presentCardDetail(card)

        case .error(let msg):
            hintLabel.text = msg
            overlayView.resetToScanning()
        }
    }

    // MARK: Navigation

    @objc private func openCollection() {
        let vc = CollectionViewController()
        navigationController?.pushViewController(vc, animated: true)
    }

    private func presentCardDetail(_ card: MTGCard) {
        // Avoid presenting twice if state fires again
        guard presentedViewController == nil else { return }

        let detailVC = CardDetailViewController(card: card)
        let nav = UINavigationController(rootViewController: detailVC)

        if let sheet = nav.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
            sheet.prefersScrollingExpandsWhenScrolledToEdge = false
        }

        detailVC.onDismiss = { [weak self] in
            self?.viewModel.resetAfterPresentation()
            self?.ocrService.resetCooldown()
            self?.overlayView.resetToScanning()
        }

        present(nav, animated: true)
    }
}
