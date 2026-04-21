import UIKit

// MARK: - ScannerOverlayView
// Draws a dynamic highlight around the detected card rectangle.
// Vision uses bottom-left origin normalised coords; UIKit uses top-left — we flip Y.

final class ScannerOverlayView: UIView {

    // MARK: Layers

    private let borderLayer: CAShapeLayer = {
        let l = CAShapeLayer()
        l.strokeColor     = UIColor.systemBlue.cgColor
        l.fillColor       = UIColor.systemBlue.withAlphaComponent(0.08).cgColor
        l.lineWidth       = 2.5
        l.lineDashPattern = [8, 4]
        l.opacity         = 0
        return l
    }()

    private let cornerLayers: [CAShapeLayer] = (0..<4).map { _ in
        let l = CAShapeLayer()
        l.strokeColor = UIColor.white.cgColor
        l.fillColor   = UIColor.clear.cgColor
        l.lineWidth   = 3
        l.lineCap     = .round
        l.opacity     = 0
        return l
    }

    private let statusLabel: UILabel = {
        let lbl = UILabel()
        lbl.font               = .systemFont(ofSize: 13, weight: .semibold)
        lbl.textColor          = .white
        lbl.backgroundColor    = UIColor.black.withAlphaComponent(0.6)
        lbl.textAlignment      = .center
        lbl.layer.cornerRadius = 10
        lbl.clipsToBounds      = true
        lbl.alpha              = 0
        return lbl
    }()

    // MARK: Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        layer.addSublayer(borderLayer)
        cornerLayers.forEach { layer.addSublayer($0) }
        addSubview(statusLabel)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        statusLabel.frame = CGRect(x: 16, y: bounds.height - 60, width: bounds.width - 32, height: 32)
    }

    // MARK: Public API

    func updateDetectedRect(_ normRect: CGRect?) {
        guard let normRect else {
            fadeOut()
            return
        }
        let rect = convertVisionRect(normRect)
        drawBorder(rect)
        drawCorners(rect)
        fadeIn()
    }

    func showFound(cardName: String) {
        borderLayer.strokeColor = UIColor.systemGreen.cgColor
        borderLayer.fillColor   = UIColor.systemGreen.withAlphaComponent(0.1).cgColor
        cornerLayers.forEach { $0.strokeColor = UIColor.systemGreen.cgColor }
        statusLabel.text  = "  ✓  \(cardName)  "
        UIView.animate(withDuration: 0.2) { self.statusLabel.alpha = 1 }
    }

    func resetToScanning() {
        borderLayer.strokeColor = UIColor.systemBlue.cgColor
        borderLayer.fillColor   = UIColor.systemBlue.withAlphaComponent(0.08).cgColor
        cornerLayers.forEach { $0.strokeColor = UIColor.white.cgColor }
        UIView.animate(withDuration: 0.2) { self.statusLabel.alpha = 0 }
    }

    // MARK: Drawing

    private func drawBorder(_ rect: CGRect) {
        borderLayer.path = UIBezierPath(roundedRect: rect, cornerRadius: 8).cgPath
    }

    private func drawCorners(_ rect: CGRect) {
        let len: CGFloat = 22
        let corners: [(CGPoint, CGPoint, CGPoint)] = [
            (CGPoint(x: rect.minX, y: rect.minY + len), CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.minX + len, y: rect.minY)),
            (CGPoint(x: rect.maxX - len, y: rect.minY), CGPoint(x: rect.maxX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.minY + len)),
            (CGPoint(x: rect.maxX, y: rect.maxY - len), CGPoint(x: rect.maxX, y: rect.maxY), CGPoint(x: rect.maxX - len, y: rect.maxY)),
            (CGPoint(x: rect.minX + len, y: rect.maxY), CGPoint(x: rect.minX, y: rect.maxY), CGPoint(x: rect.minX, y: rect.maxY - len)),
        ]
        for (i, (p1, p2, p3)) in corners.enumerated() {
            let path = UIBezierPath()
            path.move(to: p1); path.addLine(to: p2); path.addLine(to: p3)
            cornerLayers[i].path = path.cgPath
        }
    }

    // MARK: Coordinate Conversion

    private func convertVisionRect(_ norm: CGRect) -> CGRect {
        CGRect(
            x: norm.origin.x * bounds.width,
            y: (1 - norm.origin.y - norm.height) * bounds.height,
            width:  norm.width  * bounds.width,
            height: norm.height * bounds.height
        )
    }

    // MARK: Fade

    private func fadeIn() {
        guard borderLayer.opacity == 0 else { return }
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.15)
        borderLayer.opacity = 1
        cornerLayers.forEach { $0.opacity = 1 }
        CATransaction.commit()
    }

    private func fadeOut() {
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.3)
        borderLayer.opacity = 0
        cornerLayers.forEach { $0.opacity = 0 }
        CATransaction.commit()
        UIView.animate(withDuration: 0.2) { self.statusLabel.alpha = 0 }
    }
}
