import UIKit
import Vision
import AVFoundation

final class ScannerOverlayView: UIView {

    private let shapeLayer = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)

        shapeLayer.strokeColor = UIColor.blue.cgColor
        shapeLayer.lineWidth = 3
        shapeLayer.fillColor = UIColor.clear.cgColor

        layer.addSublayer(shapeLayer)
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    func resetToScanning() {
        shapeLayer.path = nil
    }

    func showFound(cardName: String) {
        shapeLayer.strokeColor = UIColor.systemGreen.cgColor
    }

    // 🔥 REAL FIX: draw actual detected quadrilateral
    func updateDetectedRect(
        _ rect: VNRectangleObservation?,
        previewLayer: AVCaptureVideoPreviewLayer?
    ) {

        guard let rect, let previewLayer else {
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

        shapeLayer.path = path.cgPath
    }
}
