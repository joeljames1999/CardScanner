import UIKit
import Vision
import AVFoundation

final class ScannerOverlayView: UIView {

    private let glowLayer = CAShapeLayer()
    private let shapeLayer = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)

        glowLayer.strokeColor = UIColor.brandBlue.cgColor
        glowLayer.lineWidth = 9
        glowLayer.fillColor = UIColor.clear.cgColor
        glowLayer.opacity = 0.38
        glowLayer.lineJoin = .round
        glowLayer.lineCap = .round
        glowLayer.shadowColor = UIColor.accentColor.cgColor
        glowLayer.shadowRadius = 16
        glowLayer.shadowOpacity = 1
        glowLayer.shadowOffset = .zero

        shapeLayer.strokeColor = UIColor.brandBlue.cgColor
        shapeLayer.lineWidth = 3
        shapeLayer.fillColor = UIColor.clear.cgColor
        shapeLayer.lineJoin = .round
        shapeLayer.lineCap = .round

        layer.addSublayer(glowLayer)
        layer.addSublayer(shapeLayer)
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    func resetToScanning() {
        glowLayer.path = nil
        shapeLayer.path = nil
        glowLayer.strokeColor = UIColor.brandBlue.cgColor
        glowLayer.shadowColor = UIColor.accentColor.cgColor
        shapeLayer.strokeColor = UIColor.brandBlue.cgColor
    }

    func showFound(cardName: String) {
        glowLayer.strokeColor = UIColor.white.cgColor
        glowLayer.shadowColor = UIColor.accentColor.cgColor
        shapeLayer.strokeColor = UIColor.white.cgColor
    }

    // 🔥 REAL FIX: draw actual detected quadrilateral
    func updateDetectedRect(
        _ rect: VNRectangleObservation?,
        previewLayer: AVCaptureVideoPreviewLayer?
    ) {

        guard let rect, let previewLayer else {
            glowLayer.path = nil
            shapeLayer.path = nil
            return
        }

        func convert(_ point: CGPoint) -> CGPoint {
            let converted = previewLayer.layerPointConverted(
                fromCaptureDevicePoint: point
            )
            return converted
        }

        let path = UIBezierPath()

        let topLeft = convert(rect.topLeft)
        let topRight = convert(rect.topRight)
        let bottomRight = convert(rect.bottomRight)
        let bottomLeft = convert(rect.bottomLeft)

        path.move(to: topLeft)
        path.addLine(to: topRight)
        path.addLine(to: bottomRight)
        path.addLine(to: bottomLeft)
        path.close()

        glowLayer.path = path.cgPath
        shapeLayer.path = path.cgPath
    }
}
