import UIKit
import AVFoundation

/// Face crop with 14-point landmark overlay (Android `LandmarkImageView`).
/// Image is a subview; dots/labels draw in an overlay on top (UIKit draws subviews after `draw`).
final class LandmarkImageView: UIView {
    private let imageView = UIImageView()
    private let overlay = LandmarkOverlayView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        overlay.translatesAutoresizingMaskIntoConstraints = false
        overlay.isUserInteractionEnabled = false
        overlay.backgroundColor = .clear
        overlay.isOpaque = false
        overlay.contentMode = .redraw
        addSubview(imageView)
        addSubview(overlay)
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor),
            overlay.topAnchor.constraint(equalTo: imageView.topAnchor),
            overlay.leadingAnchor.constraint(equalTo: imageView.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: imageView.trailingAnchor),
            overlay.bottomAnchor.constraint(equalTo: imageView.bottomAnchor),
        ])
        backgroundColor = FPColor.surfaceAlt
        layer.cornerRadius = 12
        clipsToBounds = true
    }

    required init?(coder: NSCoder) { nil }

    func setContent(_ image: UIImage?, landmarks: [CGPoint]) {
        imageView.image = image
        overlay.imageSize = image?.size ?? .zero
        overlay.landmarks = landmarks
        overlay.setNeedsDisplay()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        overlay.setNeedsDisplay()
    }
}

private final class LandmarkOverlayView: UIView {
    var imageSize: CGSize = .zero
    var landmarks: [CGPoint] = []

    private let landmarkPaint = UIColor(red: 0, green: 0.898, blue: 1.0, alpha: 1) // #00E5FF

    override func draw(_ rect: CGRect) {
        super.draw(rect)
        guard !landmarks.isEmpty, imageSize.width > 0, imageSize.height > 0,
              let ctx = UIGraphicsGetCurrentContext() else { return }
        let imageRect = AVMakeRect(aspectRatio: imageSize, insideRect: bounds)
        guard imageRect.width > 0, imageRect.height > 0 else { return }

        let scale = min(imageRect.width / imageSize.width, imageRect.height / imageSize.height)
        let dx = imageRect.origin.x
        let dy = imageRect.origin.y
        let mapped = landmarks.map { CGPoint(x: $0.x * scale + dx, y: $0.y * scale + dy) }

        let r = FaceDrawMetrics.landmarkRadius(displayedWidth: imageRect.width)
        ctx.setFillColor(landmarkPaint.cgColor)
        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: FaceDrawMetrics.landmarkLabelSize(radius: r)),
            .foregroundColor: UIColor.white,
        ]
        for (index, pt) in mapped.enumerated() {
            ctx.fillEllipse(in: CGRect(x: pt.x - r, y: pt.y - r, width: r * 2, height: r * 2))
            let label = "\(index + 1)" as NSString
            let size = label.size(withAttributes: labelAttrs)
            label.draw(
                at: CGPoint(x: pt.x - size.width / 2, y: pt.y - r - size.height - 1),
                withAttributes: labelAttrs
            )
        }
    }
}

enum FaceDrawMetrics {
    /// Dot size follows the drawn face and the shorter screen side (iPhone 12/13/14 width = 1×).
    static func landmarkRadius(displayedWidth: CGFloat) -> CGFloat {
        let screen = min(UIScreen.main.bounds.width, UIScreen.main.bounds.height)
        let factor = max(0.85, min(screen / 390, 1.55))
        return max(4 * factor, min(displayedWidth * 0.028 * factor, 10 * factor))
    }

    static func landmarkLabelSize(radius: CGFloat) -> CGFloat {
        max(8, min(13, radius * 1.7))
    }
}
