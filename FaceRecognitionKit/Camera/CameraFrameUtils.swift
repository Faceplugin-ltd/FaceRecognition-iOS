import AVFoundation
import CoreImage
import UIKit

public enum CameraFrameUtils {
    private static let ciContext = CIContext(options: nil)

    /// Android `CameraPreview` target — fallback for capture ROI when frame size is unknown.
    public static let androidPreviewSize = CGSize(width: 720, height: 1280)
    public static let previewMaxSide: CGFloat = 640
    public static let engineMaxSide: CGFloat = 1280

    public static func frame(from sampleBuffer: CMSampleBuffer, frontCamera: Bool, connection: AVCaptureConnection) -> CameraFrame? {
        guard let image = liveEngineImage(from: sampleBuffer, frontCamera: frontCamera) else { return nil }
        return CameraFrame(
            image: image,
            uprightSize: image.size,
            bufferSize: image.size
        )
    }

    /// Portrait unmirrored bitmap for VideoWorker + side detect (Android `fromImageProxy`).
    /// Rotate front −90° / back +90°, then downscale long side ≤ 640. Do not mirror.
    public static func liveEngineImage(from sampleBuffer: CMSampleBuffer, frontCamera: Bool) -> UIImage? {
        guard let rotated = rotatedPortrait(from: sampleBuffer, frontCamera: frontCamera) else { return nil }
        return downscale(rotated, maxSide: previewMaxSide)
    }

    /// Portrait bitmap for the native engine — aliases `liveEngineImage`.
    public static func portraitEngineImage(from sampleBuffer: CMSampleBuffer, frontCamera: Bool) -> UIImage? {
        liveEngineImage(from: sampleBuffer, frontCamera: frontCamera)
    }

    /// Legacy path — prefer `portraitEngineImage` for live camera.
    public static func image(from sampleBuffer: CMSampleBuffer, maxLongSide: CGFloat = 1280) -> UIImage? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
        var ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let extent = ciImage.extent.integral
        guard extent.width > 0, extent.height > 0 else { return nil }

        let longSide = max(extent.width, extent.height)
        let scale = longSide > maxLongSide ? maxLongSide / longSide : 1
        if scale != 1 {
            ciImage = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        }

        let scaledExtent = ciImage.extent.integral
        guard scaledExtent.width > 0, scaledExtent.height > 0 else { return nil }
        return render(ciImage, extent: scaledExtent)
    }

    /// Bake EXIF orientation into pixel data so SDK detect/extract see an upright image.
    public static func normalizedUp(_ image: UIImage) -> UIImage {
        if image.imageOrientation == .up { return image }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }

    /// Same downscale as `FaceRecognitionSDK` `prepareImageForEngine` (long side ≤ 1280).
    public static func enginePreparedImage(_ image: UIImage, maxSide: CGFloat = engineMaxSide) -> UIImage {
        downscale(normalizedUp(image), maxSide: maxSide)
    }

    /// Crop a face using detect `faceRegion` on an **engine-prepared** image.
    public static func cropFace(
        fromEngineImage image: UIImage,
        region: CGRect,
        paddingFraction: CGFloat = 0.12
    ) -> UIImage? {
        guard image.size.width > 0, image.size.height > 0, region.width > 1, region.height > 1 else {
            return nil
        }
        let side = max(region.width, region.height) * (1 + paddingFraction * 2)
        var rect = CGRect(
            x: region.midX - side * 0.5,
            y: region.midY - side * 0.5,
            width: side,
            height: side
        )
        let bounds = CGRect(origin: .zero, size: image.size)
        if rect.width > bounds.width || rect.height > bounds.height {
            let fit = min(bounds.width, bounds.height, side)
            rect.size = CGSize(width: fit, height: fit)
            rect.origin.x = region.midX - fit * 0.5
            rect.origin.y = region.midY - fit * 0.5
        }
        rect.origin.x = min(max(0, rect.origin.x), max(0, bounds.width - rect.width))
        rect.origin.y = min(max(0, rect.origin.y), max(0, bounds.height - rect.height))
        rect = rect.intersection(bounds)
        guard rect.width > 1, rect.height > 1 else { return nil }

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: rect.size, format: format)
        return renderer.image { _ in
            image.draw(at: CGPoint(x: -rect.origin.x, y: -rect.origin.y))
        }
    }

    // MARK: - Private

    private static func rotatedPortrait(from sampleBuffer: CMSampleBuffer, frontCamera: Bool) -> UIImage? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
        var ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        var extent = ciImage.extent.integral
        guard extent.width > 1, extent.height > 1 else { return nil }

        // Sensor buffer is landscape. Android rotates front 270° / back 90°. Do not mirror.
        if extent.width > extent.height {
            let radians = frontCamera ? -CGFloat.pi / 2 : CGFloat.pi / 2
            ciImage = ciImage.transformed(by: CGAffineTransform(rotationAngle: radians))
            extent = ciImage.extent.integral
            ciImage = ciImage.transformed(by: CGAffineTransform(
                translationX: -extent.origin.x,
                y: -extent.origin.y
            ))
            extent = ciImage.extent.integral
        }

        return render(ciImage, extent: extent)
    }

    private static func downscale(_ image: UIImage, maxSide: CGFloat) -> UIImage {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return image }
        let longSide = max(size.width, size.height)
        guard longSide > maxSide else { return image }
        let scale = maxSide / longSide
        let target = CGSize(
            width: (size.width * scale).rounded(),
            height: (size.height * scale).rounded()
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: target, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }

    private static func render(_ ciImage: CIImage, extent: CGRect) -> UIImage? {
        guard extent.width > 0, extent.height > 0,
              let cgImage = ciContext.createCGImage(ciImage, from: extent) else { return nil }
        return UIImage(cgImage: cgImage, scale: 1, orientation: .up)
    }
}
