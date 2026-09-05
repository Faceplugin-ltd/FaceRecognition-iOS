import UIKit
import FaceRecognitionKit

enum FaceUtils {
    /// Same crop as Android `Utils.cropFace` (1.4× box, square, scaled to ~200px).
    static func cropFace(from image: UIImage, face: DetectedFace) -> UIImage? {
        let box = face.boxRect
        let centerX = box.midX
        let centerY = box.midY
        var cropWidth = box.width * 1.4
        var cropX1 = centerX - cropWidth * 0.5
        var cropY1 = centerY - cropWidth * 0.5
        var cropX2 = centerX + cropWidth * 0.5
        var cropY2 = centerY + cropWidth * 0.5
        let bounds = CGRect(origin: .zero, size: image.size)
        cropX1 = max(0, cropX1)
        cropY1 = max(0, cropY1)
        cropX2 = min(bounds.width, cropX2)
        cropY2 = min(bounds.height, cropY2)
        let cropRect = CGRect(x: cropX1, y: cropY1, width: cropX2 - cropX1, height: cropY2 - cropY1)
        guard cropRect.width > 1, cropRect.height > 1,
              let cg = image.cgImage?.cropping(to: cropRect) else { return nil }
        let cropped = UIImage(cgImage: cg, scale: image.scale, orientation: .up)
        let target = CGSize(width: 200, height: 200)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            cropped.draw(in: CGRect(origin: .zero, size: target))
        }
    }

    static func mapLandmarksToCrop(face: DetectedFace, cropSize: CGSize) -> [CGPoint] {
        guard cropSize.width > 0, cropSize.height > 0 else { return [] }
        let box = face.boxRect
        let centerX = box.midX
        let centerY = box.midY
        let cropWidth = box.width * 1.4
        let cropX1 = max(0, centerX - cropWidth * 0.5)
        let cropY1 = max(0, centerY - cropWidth * 0.5)
        let cropX2 = centerX + cropWidth * 0.5
        let cropY2 = centerY + cropWidth * 0.5
        let srcW = cropX2 - cropX1
        let srcH = cropY2 - cropY1
        guard srcW > 1, srcH > 1 else { return [] }
        let sx = cropSize.width / srcW
        let sy = cropSize.height / srcH
        return face.landmarks.map { pt in
            CGPoint(x: (pt.x - cropX1) * sx, y: (pt.y - cropY1) * sy)
        }
    }
}
