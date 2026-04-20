import UIKit

// MARK: - Scanner Overlay State

enum OverlayState {
    case idle, scanning, found
}

// MARK: - ScannerOverlayView

/// Draws a card-shaped reticule with corner markers and a scanning animation.
final class ScannerOverlayView: UIView {

    // MARK: Constants

    private enum Layout {
        static let cardAspect: CGFloat = 63.0 / 88.0   // Standard MTG card ratio
        static let cornerLength: CGFloat = 24
        static let cornerWidth: CGFloat  = 3
        static let horizontalInset: CGFloat = 40
    }

    // MARK: UI

    private let cornerLayers: [CAShapeLayer] = (0..<4).map { _ in
        let l = CAShapeLayer()
        l.strokeColor = UIColor.white.cgColor
        l.fillColor   = UIColor.clear.cgColor
        l.lineWidth   = Layout.cornerWidth
        l.lineCap     = .round
        return l
    }

    private let scanLine: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.8)
        v.alpha = 0
        return v
    }()

    private let dimLayer: CALayer = {
        let l = CALayer()
        l.backgroundColor = UIColor.black.withAlphaComponent(0.45).cgColor
        return l
    }()

    // MARK: Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isUserInteractionEnabled = false
        cornerLayers.forEach { layer.addSublayer($0) }
        layer.insertSublayer(dimLayer, at: 0)
        addSubview(scanLine)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        dimLayer.frame = bounds
        updateCorners()
    }

    private var cardRect: CGRect {
        let w = bounds.width - (Layout.horizontalInset * 2)
        let h = w / Layout.cardAspect
        let x = Layout.horizontalInset
        let y = (bounds.height - h) / 2
        return CGRect(x: x, y: y, width: w, height: h)
    }

    private func updateCorners() {
        let rect = cardRect
        let cl = Layout.cornerLength

        // TL, TR, BR, BL
        let corners: [(CGPoint, CGPoint, CGPoint)] = [
            (CGPoint(x: rect.minX, y: rect.minY + cl), CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.minX + cl, y: rect.minY)),
            (CGPoint(x: rect.maxX - cl, y: rect.minY), CGPoint(x: rect.maxX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.minY + cl)),
            (CGPoint(x: rect.maxX, y: rect.maxY - cl), CGPoint(x: rect.maxX, y: rect.maxY), CGPoint(x: rect.maxX - cl, y: rect.maxY)),
            (CGPoint(x: rect.minX + cl, y: rect.maxY), CGPoint(x: rect.minX, y: rect.maxY), CGPoint(x: rect.minX, y: rect.maxY - cl)),
        ]

        for (i, (p1, p2, p3)) in corners.enumerated() {
            let path = UIBezierPath()
            path.move(to: p1)
            path.addLine(to: p2)
            path.addLine(to: p3)
            cornerLayers[i].path = path.cgPath
        }

        scanLine.frame = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: 2)
    }

    // MARK: State

    func setState(_ state: OverlayState) {
        switch state {
        case .idle:
            setCornerColor(.white)
            stopScanAnimation()
        case .scanning:
            setCornerColor(.systemBlue)
            startScanAnimation()
        case .found:
            setCornerColor(.systemGreen)
            stopScanAnimation()
        }
    }

    private func setCornerColor(_ color: UIColor) {
        cornerLayers.forEach { $0.strokeColor = color.cgColor }
    }

    // MARK: Scan Line Animation

    private func startScanAnimation() {
        scanLine.alpha = 1
        let rect = cardRect
        scanLine.frame = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: 2)

        UIView.animate(
            withDuration: 1.6,
            delay: 0,
            options: [.repeat, .autoreverse, .curveEaseInOut],
            animations: { [weak self] in
                guard let self else { return }
                let r = self.cardRect
                self.scanLine.frame = CGRect(x: r.minX, y: r.maxY - 2, width: r.width, height: 2)
            }
        )
    }

    private func stopScanAnimation() {
        scanLine.layer.removeAllAnimations()
        scanLine.alpha = 0
    }
}
