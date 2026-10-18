@preconcurrency import AVFoundation
import CoreImage
import CoreImage.CIFilterBuiltins
import Vision

enum CutoutResult: Sendable {
    case frame(CGImage)
    case failure(String)
}

enum PersonMatte {
    /// Scales an intensity mask to the camera image and makes background pixels transparent.
    /// Black mask pixels select transparency; white pixels retain the camera image.
    static func composite(source: CIImage, mask: CIImage) -> CIImage? {
        guard !source.extent.isEmpty, !mask.extent.isEmpty,
              !source.extent.isInfinite, !mask.extent.isInfinite else { return nil }
        let normalized = mask.transformed(by: CGAffineTransform(
            translationX: -mask.extent.minX, y: -mask.extent.minY
        ))
        let scaled = normalized.clampedToExtent().transformed(by: CGAffineTransform(
            scaleX: source.extent.width / mask.extent.width,
            y: source.extent.height / mask.extent.height
        )).transformed(by: CGAffineTransform(
            translationX: source.extent.minX, y: source.extent.minY
        ))
        let blend = CIFilter.blendWithMask()
        blend.inputImage = source
        blend.backgroundImage = CIImage(color: .clear).cropped(to: source.extent)
        blend.maskImage = scaled
        return blend.outputImage?.cropped(to: source.extent)
    }
}

// Vision's temporal request, context, and callback are confined to this delegate's serial frame queue.
final class CutoutProcessor: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    let queue = DispatchQueue(label: "Presenter.cutout", qos: .userInitiated)
    private var context: CIContext?
    private let colorSpace = CGColorSpaceCreateDeviceRGB()
    private var request: VNGeneratePersonSegmentationRequest?
    private var report: (@Sendable (CutoutResult) -> Void)?

    /// Drains earlier frames and resets temporal state. Call from the session queue, never the frame queue.
    func configure(enabled: Bool, report: @escaping @Sendable (CutoutResult) -> Void) {
        queue.sync { [self] in
            if enabled {
                self.report = report
                let request = VNGeneratePersonSegmentationRequest()
                request.qualityLevel = .balanced
                request.outputPixelFormat = kCVPixelFormatType_OneComponent8
                self.request = request
            } else {
                releaseResources()
            }
        }
    }

    /// Releases segmentation and rendering resources after earlier frames finish.
    func suspend() {
        queue.async { [self] in releaseResources() }
    }

    private func releaseResources() {
        request = nil
        report = nil
        // Hiding the camera should release GPU caches as well as the capture session.
        context?.clearCaches()
        context = nil
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let request, let report,
              let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        autoreleasepool {
            let context = self.context ?? CIContext(options: [.cacheIntermediates: false])
            self.context = context
            do {
                // Mac webcam buffers are upright; mirroring happens once on the completed display layer.
                try VNImageRequestHandler(cvPixelBuffer: buffer, orientation: .up).perform([request])
                guard let observation = request.results?.first else {
                    report(.failure("Vision did not return a person mask. Choose another style or retry the camera."))
                    return
                }
                let source = CIImage(cvPixelBuffer: buffer)
                let mask = CIImage(cvPixelBuffer: observation.pixelBuffer)
                guard let composite = PersonMatte.composite(source: source, mask: mask) else {
                    report(.failure("The person mask could not be aligned with this camera."))
                    return
                }
                // Keep texture memory bounded when the overlay is enlarged.
                let scale = min(1, 1280 / max(composite.extent.width, composite.extent.height))
                let image = composite.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
                guard let rendered = context.createCGImage(
                    image, from: image.extent, format: .RGBA8, colorSpace: colorSpace
                ) else {
                    report(.failure("The cutout could not be rendered. Choose another style or retry the camera."))
                    return
                }
                report(.frame(rendered))
            } catch {
                report(.failure("Background removal failed: \(error.localizedDescription)"))
            }
        }
    }
}
