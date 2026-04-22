import UIKit
import AVFoundation
import Vision
import CoreImage

final class ScannerViewController: UIViewController {

    private let session = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let previewLayer = AVCaptureVideoPreviewLayer()

    private let viewModel = ScannerViewModel()

    private let imageView = UIImageView() // debug preview
    private let ciContext = CIContext()

    private var isProcessing = false

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupCamera()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer.frame = view.bounds
        imageView.frame = CGRect(x: 20, y: 50, width: 120, height: 168)
    }

    private func setupUI() {
        view.backgroundColor = .black

        previewLayer.session = session
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)

        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        imageView.layer.cornerRadius = 8
        imageView.clipsToBounds = true
        view.addSubview(imageView)
    }

    private func setupCamera() {
        session.sessionPreset = .high

        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else {
            return
        }

        if session.canAddInput(input) {
            session.addInput(input)
        }

        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "camera.frame.processing"))
        videoOutput.alwaysDiscardsLateVideoFrames = true

        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        }

        if let connection = videoOutput.connection(with: .video) {
            connection.videoOrientation = .portrait
        }

        session.startRunning()
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension ScannerViewController: AVCaptureVideoDataOutputSampleBufferDelegate {

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {

        guard !isProcessing else { return }
        isProcessing = true

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            isProcessing = false
            return
        }

        let request = VNDetectRectanglesRequest { [weak self] request, error in
            guard let self = self else { return }
            defer { self.isProcessing = false }

            guard error == nil,
                  let observation = request.results?.first as? VNRectangleObservation else {
                return
            }

            let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            let corrected = self.perspectiveCorrect(ciImage: ciImage, rect: observation)

            guard let cgImage = self.ciContext.createCGImage(corrected, from: corrected.extent) else {
                return
            }

            let uiImage = UIImage(cgImage: cgImage, scale: 1.0, orientation: .down)
            let fixedImage = self.rotate180(uiImage)
            let resized = self.resizeImage(fixedImage)

            DispatchQueue.main.async {
                self.imageView.image = resized
            }

            self.viewModel.processFrame(resized)
        }

        request.minimumConfidence = 0.7
        request.maximumObservations = 1
        request.minimumAspectRatio = 0.6
        request.maximumAspectRatio = 0.8

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer,
                                            orientation: .right,
                                            options: [:])

        try? handler.perform([request])
    }
}

// MARK: - Image Helpers

private extension ScannerViewController {

    func perspectiveCorrect(ciImage: CIImage, rect: VNRectangleObservation) -> CIImage {
        let size = ciImage.extent.size

        let topLeft = CGPoint(x: rect.topLeft.x * size.width,
                              y: (1 - rect.topLeft.y) * size.height)

        let topRight = CGPoint(x: rect.topRight.x * size.width,
                               y: (1 - rect.topRight.y) * size.height)

        let bottomLeft = CGPoint(x: rect.bottomLeft.x * size.width,
                                 y: (1 - rect.bottomLeft.y) * size.height)

        let bottomRight = CGPoint(x: rect.bottomRight.x * size.width,
                                  y: (1 - rect.bottomRight.y) * size.height)

        return ciImage.applyingFilter("CIPerspectiveCorrection", parameters: [
            "inputTopLeft": CIVector(cgPoint: bottomLeft),
            "inputTopRight": CIVector(cgPoint: bottomRight),
            "inputBottomLeft": CIVector(cgPoint: topLeft),
            "inputBottomRight": CIVector(cgPoint: topRight)
        ])
    }

    func rotate180(_ image: UIImage) -> UIImage {
        guard let cgImage = image.cgImage else { return image }
        return UIImage(cgImage: cgImage, scale: 1.0, orientation: .down)
    }

    func resizeImage(_ image: UIImage) -> UIImage {
        let targetWidth: CGFloat = 300
        let targetHeight: CGFloat = targetWidth / 0.7159 // MTG ratio

        let targetSize = CGSize(width: targetWidth, height: targetHeight)

        UIGraphicsBeginImageContextWithOptions(targetSize, true, 1.0)
        image.draw(in: CGRect(origin: .zero, size: targetSize))
        let resized = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return resized ?? image
    }
}
