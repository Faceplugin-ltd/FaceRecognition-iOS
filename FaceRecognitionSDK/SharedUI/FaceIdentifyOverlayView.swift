import UIKit
import FaceRecognitionKit

/// Android `FaceView` — cyan while liveness unknown, REAL/SPOOF once filled.
final class FaceIdentifyOverlayView: UIView {
    private var frameSize: CGSize = .zero
    private var faces: [DetectedFace] = []
    private var mirror = true

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        backgroundColor = .clear
        contentMode = .redraw
    }

    required init?(coder: NSCoder) { nil }

    func update(faces: [DetectedFace], frameSize: CGSize, mirror: Bool) {
        self.faces = faces
        self.frameSize = frameSize
        self.mirror = mirror
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        guard frameSize.width > 0, frameSize.height > 0 else { return }
        let bounds = self.bounds

        for face in faces {
            guard let box = FaceJSON.mapRectToOverlay(
                face.boxRect,
                frameSize: frameSize,
                overlayBounds: bounds,
                mirror: mirror
            ) else { continue }

            let livenessKnown = hasLiveness(face)
            let live = livenessKnown && AppSettings.livenessPassed(
                score: face.livenessScore,
                label: face.livenessLabel
            )
            let color: UIColor
            let label: String?
            if !livenessKnown {
                color = UIColor.cyan
                label = nil
            } else if !live {
                color = UIColor.red
                label = "SPOOF \(face.livenessScore)"
            } else {
                color = UIColor.green
                label = "REAL \(face.livenessScore)"
            }

            if let label {
                let textAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.boldSystemFont(ofSize: 16),
                    .foregroundColor: color,
                ]
                (label as NSString).draw(at: CGPoint(x: box.minX + 10, y: box.minY - 24), withAttributes: textAttrs)
            }

            guard let ctx = UIGraphicsGetCurrentContext() else { continue }
            ctx.setStrokeColor(color.cgColor)
            ctx.setLineWidth(5)
            ctx.stroke(box)

            ctx.setFillColor(color.cgColor)
            let landmarks = FaceJSON.mapPointsToOverlay(
                face.landmarks,
                frameSize: frameSize,
                overlayBounds: bounds,
                mirror: mirror
            )
            let r = FaceDrawMetrics.landmarkRadius(displayedWidth: box.width)
            for pt in landmarks {
                ctx.fillEllipse(in: CGRect(x: pt.x - r, y: pt.y - r, width: r * 2, height: r * 2))
            }
        }
    }

    private func hasLiveness(_ face: DetectedFace) -> Bool {
        if let label = face.livenessLabel, !label.isEmpty { return true }
        return face.livenessScore > 0.001
    }
}
