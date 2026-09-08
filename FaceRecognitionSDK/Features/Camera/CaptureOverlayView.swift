import UIKit
import FaceRecognitionKit

enum FaceCaptureState: Int, Comparable {
    case noFace = 0
    case multipleFaces = 1
    case fitInCircle = 2
    case moveCloser = 3
    case noFront = 4
    case faceOccluded = 5
    case eyeClosed = 6
    case mouthOpened = 7
    case spoofedFace = 8
    case captureOk = 9

    static func < (lhs: FaceCaptureState, rhs: FaceCaptureState) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

enum CaptureViewMode {
    case noFacePrepare
    case repeatNoFacePrepare
    case toFaceCircle
    case faceCircleToNoFace
    case faceCircle
    case faceCapturePrepare
    case faceCaptureDone
}

/// Port of Android `CaptureView` — bracket coach, circle transition, capture animation.
final class CaptureOverlayView: UIView {
    var viewMode: CaptureViewMode = .noFacePrepare
    var onCaptureAnimationFinished: (() -> Void)?

    private var faceBoxes: [DetectedFace] = []
    private var frameSize: CGSize = CameraFrameUtils.androidPreviewSize
    /// Android `CaptureView.mirrorX` — true for the front camera (preview is mirrored).
    private var mirrorX = true
    private var animateValue: CGFloat = 1.4
    private var animator: UIViewPropertyAnimator?
    private var repeatTimer: Timer?
    private var capturedBitmap: UIImage?
    private var roiBitmap: UIImage?
    private var scrimGradient: CGGradient?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        backgroundColor = .clear
        contentMode = .redraw
    }

    required init?(coder: NSCoder) { nil }

    // MARK: - ROI helpers (Android `getROIRect` / `getROIRect1`)

    /// Used by `CaptureActivity.checkFace` — 6:5 oval region in frame coordinates.
    static func roiRect(frameSize: CGSize) -> CGRect {
        let margin = frameSize.width / 6
        let width = frameSize.width - margin * 2
        let height = width * 6 / 5
        let x = margin
        let y = (frameSize.height - height) / 2
        return CGRect(x: x, y: y, width: width, height: height)
    }

    /// Used for on-screen drawing — square region in frame coordinates.
    static func roiRect1(frameSize: CGSize) -> CGRect {
        let margin = frameSize.width / 6
        let side = frameSize.width - margin * 2
        let x = margin
        let y = (frameSize.height - side) / 2
        return CGRect(x: x, y: y, width: side, height: side)
    }

    func setFrameSize(_ size: CGSize) { frameSize = size }

    func setMirrorX(_ value: Bool) {
        mirrorX = value
        setNeedsDisplay()
    }

    func setFaceBoxes(_ boxes: [DetectedFace]?) {
        faceBoxes = boxes ?? []
        setNeedsDisplay()
    }

    func setCapturedBitmap(_ bitmap: UIImage?) {
        capturedBitmap = bitmap
        guard let bitmap else {
            roiBitmap = nil
            return
        }
        let roi = Self.roiRect1(frameSize: frameSize)
        let roiInt = roi.integral
        guard roiInt.width > 1, roiInt.height > 1,
              let cg = bitmap.cgImage?.cropping(to: roiInt) else {
            roiBitmap = nil
            return
        }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: roiInt.size, format: format)
        roiBitmap = renderer.image { ctx in
            let path = UIBezierPath(ovalIn: CGRect(origin: .zero, size: roiInt.size))
            path.addClip()
            UIImage(cgImage: cg, scale: 1, orientation: .up).draw(in: CGRect(origin: .zero, size: roiInt.size))
        }
    }

    func setViewMode(_ mode: CaptureViewMode) {
        viewMode = mode
        animator?.stopAnimation(true)
        animator = nil
        repeatTimer?.invalidate()
        repeatTimer = nil

        switch mode {
        case .noFacePrepare:
            runAnimator(from: 1.4, to: 0.88, duration: 0.8, repeats: false) { [weak self] in
                self?.setViewMode(.repeatNoFacePrepare)
            }
        case .repeatNoFacePrepare:
            animateValue = 0.88
            repeatTimer = Timer.scheduledTimer(withTimeInterval: 1.3, repeats: true) { [weak self] _ in
                guard let self, self.viewMode == .repeatNoFacePrepare else { return }
                UIView.animate(withDuration: 1.3, delay: 0, options: [.autoreverse, .curveEaseInOut]) {
                    self.animateValue = self.animateValue < 0.9 ? 0.92 : 0.88
                    self.setNeedsDisplay()
                }
            }
            setNeedsDisplay()
        case .toFaceCircle:
            runAnimator(from: 1.4, to: 0, duration: 0.8, repeats: false) { [weak self] in
                self?.setViewMode(.faceCircle)
            }
        case .faceCircleToNoFace:
            runAnimator(from: 0, to: 1, duration: 0.6, repeats: false) { [weak self] in
                self?.setViewMode(.noFacePrepare)
            }
        case .faceCircle:
            setNeedsDisplay()
        case .faceCapturePrepare:
            runAnimator(from: 0, to: 1, duration: 0.5, repeats: false) { [weak self] in
                self?.setViewMode(.faceCaptureDone)
            }
        case .faceCaptureDone:
            runAnimator(from: 0, to: 1, duration: 0.5, repeats: false) { [weak self] in
                self?.onCaptureAnimationFinished?()
            }
        }
    }

    private func runAnimator(
        from: CGFloat,
        to: CGFloat,
        duration: TimeInterval,
        repeats: Bool,
        reverse: Bool = false,
        onEnd: (() -> Void)?
    ) {
        animateValue = from
        setNeedsDisplay()
        let anim = UIViewPropertyAnimator(duration: duration, curve: .linear) { [weak self] in
            guard let self else { return }
            self.animateValue = to
            self.setNeedsDisplay()
        }
        if repeats {
            anim.addCompletion { [weak self] pos in
                guard pos == .end, let self, self.viewMode == .repeatNoFacePrepare else { return }
                self.runAnimator(from: 0.88, to: 0.92, duration: 1.3, repeats: true, reverse: true, onEnd: nil)
            }
        } else {
            anim.addCompletion { pos in
                if pos == .end { onEnd?() }
            }
        }
        animator = anim
        anim.startAnimation()
        if repeats && reverse {
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
                guard let self, self.viewMode == .repeatNoFacePrepare else { return }
                self.animateValue = from
                self.setNeedsDisplay()
            }
        }
    }

    // MARK: - Frame → view mapping (Android `onDraw`)

    private func roiViewRect(in canvasSize: CGSize) -> CGRect {
        let roiRect = Self.roiRect1(frameSize: frameSize)
        let ratioView = canvasSize.width / canvasSize.height
        let ratioFrame = frameSize.width / frameSize.height
        var x1: CGFloat, y1: CGFloat, x2: CGFloat, y2: CGFloat
        if ratioView < ratioFrame {
            let dx = (canvasSize.height * ratioFrame - canvasSize.width) / 2
            let ratio = canvasSize.height / frameSize.height
            x1 = roiRect.minX * ratio - dx
            y1 = roiRect.minY * ratio
            x2 = roiRect.maxX * ratio - dx
            y2 = roiRect.maxY * ratio
        } else {
            let dy = (canvasSize.width / ratioFrame - canvasSize.height) / 2
            let ratio = canvasSize.height / frameSize.height
            x1 = roiRect.minX * ratio
            y1 = roiRect.minY * ratio - dy
            x2 = roiRect.maxX * ratio
            y2 = roiRect.maxY * ratio - dy
        }
        return CGRect(x: x1, y: y1, width: x2 - x1, height: y2 - y1)
    }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        let canvasSize = bounds.size
        guard canvasSize.width > 0, canvasSize.height > 0 else { return }

        if scrimGradient == nil {
            let colors = [FPColor.captureScrimStart.cgColor, FPColor.captureScrimEnd.cgColor] as CFArray
            scrimGradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors,
                locations: [0, 1]
            )
        }

        let roiView = roiViewRect(in: canvasSize)

        // Scrim
        if viewMode == .faceCircle || viewMode == .faceCapturePrepare || viewMode == .faceCaptureDone
            || (viewMode == .toFaceCircle && animateValue < 1)
            || viewMode == .faceCircleToNoFace {
            ctx.saveGState()
            if viewMode == .faceCircleToNoFace {
                ctx.setAlpha(1 - animateValue)
            }
            if let scrimGradient {
                ctx.drawLinearGradient(
                    scrimGradient,
                    start: .zero,
                    end: CGPoint(x: canvasSize.width, y: canvasSize.height),
                    options: []
                )
            }
            ctx.restoreGState()
        }

        switch viewMode {
        case .noFacePrepare, .repeatNoFacePrepare, .toFaceCircle, .faceCircleToNoFace:
            drawCornerBrackets(ctx: ctx, roiView: roiView, canvasSize: canvasSize)
            if (viewMode == .toFaceCircle && animateValue < 1) || viewMode == .faceCircleToNoFace {
                drawCircleEraser(ctx: ctx, roiView: roiView)
            }
        case .faceCircle:
            drawCircleCoach(ctx: ctx, roiView: roiView)
        case .faceCapturePrepare:
            drawCapturePrepare(ctx: ctx, roiView: roiView)
        case .faceCaptureDone:
            drawCaptureDone(ctx: ctx, roiView: roiView, canvasSize: canvasSize)
        }
    }

    private func drawCornerBrackets(ctx: CGContext, roiView: CGRect, canvasSize: CGSize) {
        var scaleRoi = roiView
        if viewMode == .noFacePrepare || viewMode == .repeatNoFacePrepare
            || (viewMode == .toFaceCircle && animateValue > 1) {
            Self.scale(&scaleRoi, factor: animateValue)
        }

        var lineW = scaleRoi.width / 5
        var lineH = scaleRoi.height / 5
        var lineWOff: CGFloat = 0
        var lineHOff: CGFloat = 0
        var quadR = scaleRoi.width / 12

        if viewMode == .faceCircle
            || (viewMode == .toFaceCircle && animateValue < 1)
            || viewMode == .faceCircleToNoFace {
            lineW *= animateValue
            lineWOff = scaleRoi.width / 2 * (1 - animateValue)
            lineH *= animateValue
            lineHOff = scaleRoi.height / 2 * (1 - animateValue)
            quadR = scaleRoi.width / 12 + (scaleRoi.width / 2 - scaleRoi.width / 12) * (1 - animateValue) - 20
        }

        ctx.setStrokeColor(FPColor.accent.cgColor)
        ctx.setLineWidth(10)
        ctx.setLineCap(.round)
        if viewMode == .noFacePrepare || (viewMode == .toFaceCircle && animateValue > 1) {
            ctx.setAlpha(min(1, (1.4 - animateValue) / 0.4))
        } else {
            ctx.setAlpha(1)
        }

        drawBracket(ctx: ctx, scaleRoi: scaleRoi, lineW: lineW, lineH: lineH, lineWOff: lineWOff, lineHOff: lineHOff, quadR: quadR)
        ctx.setAlpha(1)
    }

    private func drawBracket(
        ctx: CGContext,
        scaleRoi: CGRect,
        lineW: CGFloat,
        lineH: CGFloat,
        lineWOff: CGFloat,
        lineHOff: CGFloat,
        quadR: CGFloat
    ) {
        // Top-left
        ctx.move(to: CGPoint(x: scaleRoi.minX, y: scaleRoi.minY + lineH + lineHOff))
        ctx.addLine(to: CGPoint(x: scaleRoi.minX, y: scaleRoi.minY + quadR))
        ctx.addArc(
            center: CGPoint(x: scaleRoi.minX + quadR, y: scaleRoi.minY + quadR),
            radius: quadR,
            startAngle: .pi,
            endAngle: .pi * 1.5,
            clockwise: false
        )
        ctx.addLine(to: CGPoint(x: scaleRoi.minX + lineW + lineWOff, y: scaleRoi.minY))
        ctx.strokePath()

        // Top-right
        ctx.move(to: CGPoint(x: scaleRoi.maxX, y: scaleRoi.minY + lineH + lineHOff))
        ctx.addLine(to: CGPoint(x: scaleRoi.maxX, y: scaleRoi.minY + quadR))
        ctx.addArc(
            center: CGPoint(x: scaleRoi.maxX - quadR, y: scaleRoi.minY + quadR),
            radius: quadR,
            startAngle: 0,
            endAngle: -.pi / 2,
            clockwise: true
        )
        ctx.addLine(to: CGPoint(x: scaleRoi.maxX - lineW - lineWOff, y: scaleRoi.minY))
        ctx.strokePath()

        // Bottom-right
        ctx.move(to: CGPoint(x: scaleRoi.maxX, y: scaleRoi.maxY - lineH - lineHOff))
        ctx.addLine(to: CGPoint(x: scaleRoi.maxX, y: scaleRoi.maxY - quadR))
        ctx.addArc(
            center: CGPoint(x: scaleRoi.maxX - quadR, y: scaleRoi.maxY - quadR),
            radius: quadR,
            startAngle: 0,
            endAngle: .pi / 2,
            clockwise: false
        )
        ctx.addLine(to: CGPoint(x: scaleRoi.maxX - lineW - lineWOff, y: scaleRoi.maxY))
        ctx.strokePath()

        // Bottom-left
        ctx.move(to: CGPoint(x: scaleRoi.minX, y: scaleRoi.maxY - lineH - lineHOff))
        ctx.addLine(to: CGPoint(x: scaleRoi.minX, y: scaleRoi.maxY - quadR))
        ctx.addArc(
            center: CGPoint(x: scaleRoi.minX + quadR, y: scaleRoi.maxY - quadR),
            radius: quadR,
            startAngle: .pi,
            endAngle: .pi / 2,
            clockwise: true
        )
        ctx.addLine(to: CGPoint(x: scaleRoi.minX + lineW + lineWOff, y: scaleRoi.maxY))
        ctx.strokePath()
    }

    private func drawCircleEraser(ctx: CGContext, roiView: CGRect) {
        let startWidth = 0.8 * roiView.width * 0.5 / CGFloat(cos(45 * CGFloat.pi / 180))
        let cx = roiView.midX
        let cy = roiView.midY
        let half = roiView.width / 2 * (1 - animateValue) + startWidth * animateValue
        let eraseRect = CGRect(x: cx - half, y: cy - half, width: half * 2, height: half * 2)
        ctx.setBlendMode(.clear)
        ctx.fillEllipse(in: eraseRect)
        ctx.setBlendMode(.normal)
    }

    private func drawCircleCoach(ctx: CGContext, roiView: CGRect) {
        // Clear oval hole
        ctx.setBlendMode(.clear)
        ctx.fillEllipse(in: roiView)
        ctx.setBlendMode(.normal)

        // Outer tick ring
        let cx = roiView.midX
        let cy = roiView.midY
        ctx.setStrokeColor(FPColor.text.cgColor)
        ctx.setLineWidth(8)
        for i in stride(from: 0, to: 360, by: 5) {
            let th = CGFloat(i) * CGFloat.pi / 180
            let a1 = roiView.width / 2 + 10
            let b1 = roiView.height / 2 + 10
            let a2 = roiView.width / 2 + 40
            let b2 = roiView.height / 2 + 40
            var x1 = a1 * b1 / sqrt(b1 * b1 + a1 * a1 * tan(th) * tan(th))
            var x2 = a2 * b2 / sqrt(b2 * b2 + a2 * a2 * tan(th) * tan(th))
            var y1 = sqrt(max(0, 1 - (x1 / a1) * (x1 / a1))) * b1
            var y2 = sqrt(max(0, 1 - (x1 / a1) * (x1 / a1))) * b2
            let mod = i % 360
            if mod > 90 && mod < 270 { x1 = -x1; x2 = -x2 }
            if mod > 180 && mod < 360 { y1 = -y1; y2 = -y2 }
            ctx.move(to: CGPoint(x: cx + x1, y: cy - y1))
            ctx.addLine(to: CGPoint(x: cx + x2, y: cy - y2))
            ctx.strokePath()
        }

        // Yaw / pitch guides — same signs as Android `CaptureView`:
        // front keeps yaw (preview is mirrored); back negates yaw. Pitch is
        // negated for both so the fill leans with the head (tick ring is Y-up).
        if let face = faceBoxes.first {
            ctx.setFillColor(FPColor.accent.withAlphaComponent(0.5).cgColor)
            let yaw = mirrorX ? face.yaw : -face.yaw
            let pitch = -face.pitch
            let path1 = UIBezierPath()
            path1.move(to: CGPoint(x: roiView.midX, y: roiView.minY))
            path1.addQuadCurve(
                to: CGPoint(x: roiView.midX, y: roiView.maxY),
                controlPoint: CGPoint(
                    x: roiView.midX - roiView.width * CGFloat(sin(yaw * CGFloat.pi / 180)),
                    y: roiView.midY
                )
            )
            path1.close()
            path1.fill()

            let path2 = UIBezierPath()
            path2.move(to: CGPoint(x: roiView.minX, y: roiView.midY))
            path2.addQuadCurve(
                to: CGPoint(x: roiView.maxX, y: roiView.midY),
                controlPoint: CGPoint(
                    x: roiView.midX,
                    y: roiView.midY + roiView.width * CGFloat(sin(pitch * CGFloat.pi / 180))
                )
            )
            path2.close()
            path2.fill()
        }
    }

    private func drawCapturePrepare(ctx: CGContext, roiView: CGRect) {
        var border = roiView
        Self.scale(&border, factor: 1.04)
        ctx.setFillColor(FPColor.captureTertiary.cgColor)
        ctx.fillEllipse(in: border)

        var inner = roiView
        Self.scale(&inner, factor: 1 - animateValue)
        ctx.setBlendMode(.clear)
        ctx.fillEllipse(in: inner)
        ctx.setBlendMode(.normal)
    }

    private func drawCaptureDone(ctx: CGContext, roiView: CGRect, canvasSize: CGSize) {
        var border = roiView
        Self.scale(&border, factor: 0.8)
        let slideY = (canvasSize.width / 5 - roiView.minY) * animateValue
        ctx.saveGState()
        ctx.translateBy(x: 0, y: slideY)
        if let roiBitmap {
            roiBitmap.draw(in: border)
        }
        ctx.setStrokeColor(FPColor.captureTertiary.cgColor)
        ctx.setLineWidth(15)
        ctx.strokeEllipse(in: border)
        ctx.restoreGState()
    }

    private static func scale(_ rect: inout CGRect, factor: CGFloat) {
        let dH = rect.width * (factor - 1)
        let dV = rect.height * (factor - 1)
        rect = rect.insetBy(dx: -dH / 2, dy: -dV / 2)
    }
}

enum CaptureFaceChecker {
    /// Same logic as Android `CaptureActivity.checkFace`.
    static func checkFace(_ faceBoxes: [DetectedFace], frameSize: CGSize) -> FaceCaptureState {
        if faceBoxes.isEmpty { return .noFace }
        if faceBoxes.count > 1 { return .multipleFaces }

        let face = faceBoxes[0]
        var faceLeft = CGFloat.greatestFiniteMagnitude
        var faceRight: CGFloat = 0
        var faceBottom: CGFloat = 0
        let nMarks = face.landmarks.count
        if nMarks >= 5 {
            for pt in face.landmarks.prefix(nMarks) {
                faceLeft = min(faceLeft, pt.x)
                faceRight = max(faceRight, pt.x)
                faceBottom = max(faceBottom, pt.y)
            }
        } else {
            faceLeft = face.boxRect.minX
            faceRight = face.boxRect.maxX
            faceBottom = face.boxRect.maxY
        }

        let sizeRate: CGFloat = 0.30
        let interRate: CGFloat = 0.03
        var size = frameSize
        if size.width <= 0 || size.height <= 0 {
            size = CameraFrameUtils.androidPreviewSize
        }
        let roi = CaptureOverlayView.roiRect(frameSize: size)
        let centerY = (face.boxRect.maxY + face.boxRect.minY) / 2
        let topY = centerY - face.boxRect.height * 2 / 3
        let interX = max(0, roi.minX - faceLeft) + max(0, faceRight - roi.maxX)
        let interY = max(0, roi.minY - topY) + max(0, faceBottom - roi.maxY)
        if interX / roi.width > interRate || interY / roi.height > interRate {
            return .fitInCircle
        }
        if face.boxRect.width * face.boxRect.height < roi.width * roi.height * sizeRate {
            return .moveCloser
        }
        if abs(face.yaw) > Double(AppSettings.yawThreshold)
            || abs(face.roll) > Double(AppSettings.rollThreshold)
            || abs(face.pitch) > Double(AppSettings.pitchThreshold) {
            return .noFront
        }
        let mask = (face.maskLabel ?? "").lowercased()
        if mask.contains("yes") {
            return .faceOccluded
        }
        let left = (face.eyesLeftLabel ?? "").lowercased()
        let right = (face.eyesRightLabel ?? "").lowercased()
        if left.contains("closed") || right.contains("closed") {
            return .eyeClosed
        }
        if left.isEmpty && right.isEmpty
            && (face.leftEyeClosed > AppSettings.eyecloseThreshold
                || face.rightEyeClosed > AppSettings.eyecloseThreshold) {
            return .eyeClosed
        }
        return .captureOk
    }

    static func warning(for state: FaceCaptureState) -> String {
        switch state {
        case .multipleFaces: return "Multiple face detected!"
        case .fitInCircle: return "Fit in circle!"
        case .moveCloser: return "Move closer!"
        case .noFront: return "Not fronted face!"
        case .faceOccluded: return "Face occluded!"
        case .eyeClosed: return "Eye closed!"
        case .spoofedFace: return "Spoof face"
        default: return ""
        }
    }
}
