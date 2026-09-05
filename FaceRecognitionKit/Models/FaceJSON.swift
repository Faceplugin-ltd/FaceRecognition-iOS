import AVFoundation
import UIKit

public enum FaceJSON {
    public static func parseDetect(_ json: String, source: UIImage? = nil) -> [DetectedFace] {
        guard let data = json.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let faces = root["data"] as? [[String: Any]] else {
            return []
        }
        return faces.compactMap { face in
            guard let region = face["faceRegion"] as? [String: Any],
                  let x = doubleValue(region["x"]),
                  let y = doubleValue(region["y"]),
                  let w = doubleValue(region["width"]),
                  let h = doubleValue(region["height"]) else {
                return nil
            }
            let pose = face["facePose"] as? [String: Any]
            let points = face["facePoints"] as? [[String: Any]] ?? []
            let landmarks = filterFda14(parseLandmarks(points))
            let box = CGRect(x: x, y: y, width: w, height: h)
            return DetectedFace(
                faceId: intValue(face["faceId"]) ?? 0,
                region: box,
                attributes: parseAttributes(face["attributes"] as? [String: Any]),
                yaw: doubleValue(pose?["yaw"]) ?? 0,
                pitch: doubleValue(pose?["pitch"]) ?? 0,
                roll: doubleValue(pose?["roll"]) ?? 0,
                landmarkCount: landmarks.count,
                landmarks: landmarks,
                luminance: luminance(source, box: box)
            )
        }
    }

    public static func parseVideoWorkerEvent(_ json: String) -> VideoWorkerEvent? {
        guard let data = json.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let event = root["event"] as? String else {
            return nil
        }
        switch event {
        case "tracking":
            let faces = parseVideoWorkerFaces(root["faces"] as? [[String: Any]] ?? [])
            let fw = doubleValue(root["frame_width"]) ?? 0
            let fh = doubleValue(root["frame_height"]) ?? 0
            let frameSize = videoWorkerFrameSize(bufferWidth: Int(fw), bufferHeight: Int(fh))
            return .tracking(
                frameId: intValue(root["frame_id"]) ?? 0,
                faces: faces,
                singleFace: (root["single_face"] as? NSNumber)?.boolValue ?? (faces.count == 1),
                frameSize: frameSize
            )
        case "match":
            return .match(
                trackId: intValue(root["track_id"]) ?? 0,
                matched: (root["matched"] as? NSNumber)?.boolValue ?? false,
                personIndex: intValue(root["person_index"]),
                score: doubleValue(root["score"])
            )
        default:
            return nil
        }
    }

    private static func parseVideoWorkerFaces(_ faces: [[String: Any]]) -> [VideoWorkerFace] {
        faces.compactMap { face in
            guard let region = face["faceRegion"] as? [String: Any],
                  let x = doubleValue(region["x"]),
                  let y = doubleValue(region["y"]),
                  let w = doubleValue(region["width"]),
                  let h = doubleValue(region["height"]) else {
                return nil
            }
            let points = face["facePoints"] as? [[String: Any]] ?? []
            let matchRaw = face["match"] as? [String: Any]
            let match: VideoWorkerMatch?
            if let matchRaw {
                let matched = (matchRaw["matched"] as? NSNumber)?.boolValue ?? false
                let personIndex = intValue(matchRaw["person_index"])
                let score = doubleValue(matchRaw["score"])
                match = VideoWorkerMatch(matched: matched, personIndex: personIndex, score: score)
            } else {
                match = nil
            }
            let pose = face["facePose"] as? [String: Any]
            return VideoWorkerFace(
                trackId: intValue(face["track_id"]) ?? 0,
                region: CGRect(x: x, y: y, width: w, height: h),
                landmarks: filterFda14(parseLandmarks(points)),
                weak: (face["weak"] as? NSNumber)?.boolValue ?? false,
                match: match,
                age: doubleValue(face["age"]),
                gender: face["gender"] as? String,
                emotion: face["emotion"] as? String,
                activeLiveness: parseActiveLiveness(face["activeLiveness"] as? [String: Any]),
                yaw: doubleValue(pose?["yaw"]) ?? 0,
                pitch: doubleValue(pose?["pitch"]) ?? 0,
                roll: doubleValue(pose?["roll"]) ?? 0
            )
        }
    }

    private static func parseActiveLiveness(_ raw: [String: Any]?) -> VideoWorkerActiveLiveness? {
        guard let raw else { return nil }
        let verdict = raw["verdict"] as? String ?? "not_computed"
        let checkType = raw["checkType"] as? String ?? "none"
        let progress = doubleValue(raw["progress"]) ?? 0
        return VideoWorkerActiveLiveness(verdict: verdict, checkType: checkType, progress: progress)
    }

    /// Same as Android: keep the event's frame_width / frame_height.
    public static func videoWorkerFrameSize(bufferWidth: Int, bufferHeight: Int) -> CGSize {
        guard bufferWidth > 0, bufferHeight > 0 else {
            return .zero
        }
        return CGSize(width: CGFloat(bufferWidth), height: CGFloat(bufferHeight))
    }

    public static func toDetectedFaces(_ faces: [VideoWorkerFace], includeWeak: Bool = false) -> [DetectedFace] {
        faces.compactMap { face in
            if !includeWeak && face.weak { return nil }
            return toDetectedFace(face)
        }
    }

    public static func toDetectedFace(_ face: VideoWorkerFace) -> DetectedFace {
        DetectedFace(
            faceId: face.trackId,
            region: face.region,
            attributes: [:],
            yaw: face.yaw,
            pitch: face.pitch,
            roll: face.roll,
            landmarkCount: face.landmarks.count,
            landmarks: face.landmarks
        )
    }

    public static func parseQualityAttributes(_ json: String) -> [String: FaceAttribute] {
        guard let data = json.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = root["data"] as? [[String: Any]],
              let first = items.first else {
            return [:]
        }
        return parseAttributes(first["attributes"] as? [String: Any])
    }

    public static func parseFeatureData(_ json: String) -> Data? {
        guard let data = json.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        if let results = root["results"] as? [[String: Any]],
           let features = results.first?["features"] as? [[String: Any]],
           let b64 = features.first?["feature"] as? String {
            return Data(base64Encoded: b64)
        }
        if let features = root["features"] as? [[String: Any]],
           let b64 = features.first?["feature"] as? String {
            return Data(base64Encoded: b64)
        }
        return nil
    }

    public static func displayLines(
        for face: DetectedFace,
        showMissingFields: Bool = false
    ) -> [String] {
        var lines: [String] = []
        lines.append(String(
            format: "Image position: x=%.0f y=%.0f",
            face.region.origin.x,
            face.region.origin.y
        ))
        lines.append(String(
            format: "Face size: %.0f × %.0f px",
            face.region.width,
            face.region.height
        ))
        lines.append(String(format: "Yaw: %.1f°", face.yaw))
        lines.append(String(format: "Pitch: %.1f°", face.pitch))
        lines.append(String(format: "Roll: %.1f°", face.roll))
        appendAttribute(&lines, title: "Age", keys: ["Age", "age"], from: face.attributes, showMissing: showMissingFields)
        appendAttribute(&lines, title: "Gender", keys: ["Gender", "gender"], from: face.attributes, showMissing: showMissingFields)
        appendAttribute(&lines, title: "Emotion", keys: ["Emotion", "emotion"], from: face.attributes, showMissing: showMissingFields)
        appendAttribute(&lines, title: "Medical mask", keys: ["MedicalMask", "Mask", "mask"], from: face.attributes, showMissing: showMissingFields)
        appendAttribute(&lines, title: "Blur level", keys: ["BlurLevel", "blurLevel", "Sharpness"], from: face.attributes, showMissing: showMissingFields)
        appendAttribute(&lines, title: "Noise level", keys: ["NoiseLevel", "noiseLevel", "Noise"], from: face.attributes, showMissing: showMissingFields)
        appendAttribute(&lines, title: "Face quality", keys: ["FaceQuality", "ExpressionLevel"], from: face.attributes, showMissing: showMissingFields)
        appendAttribute(&lines, title: "Liveness (2D)", keys: ["Liveness2D"], from: face.attributes, showMissing: showMissingFields)
        appendAttribute(&lines, title: "Left eye", keys: ["EyesLeft"], from: face.attributes, showMissing: showMissingFields)
        appendAttribute(&lines, title: "Right eye", keys: ["EyesRight"], from: face.attributes, showMissing: showMissingFields)
        if face.landmarkCount > 0 {
            lines.append("Landmarks: \(face.landmarkCount)")
        }
        return lines
    }

    public static func attributeSummary(_ face: DetectedFace) -> String {
        displayLines(for: face).joined(separator: "\n")
    }

    /// All geometry + every attribute present on `face`.
    public static func allRecognizedRows(_ face: DetectedFace) -> [(String, String)] {
        var rows: [(String, String)] = []
        rows.append(("Face ID", "\(face.faceId)"))
        rows.append((
            "Position",
            String(format: "x=%.0f y=%.0f", face.region.origin.x, face.region.origin.y)
        ))
        rows.append((
            "Size",
            String(format: "%.0f × %.0f px", face.region.width, face.region.height)
        ))
        rows.append(("Yaw", String(format: "%.1f°", face.yaw)))
        rows.append(("Pitch", String(format: "%.1f°", face.pitch)))
        rows.append(("Roll", String(format: "%.1f°", face.roll)))
        if face.landmarkCount > 0 {
            rows.append(("Landmarks", "\(face.landmarkCount)"))
        }
        let preferred = [
            "Age", "age",
            "Gender", "gender",
            "Emotion", "emotion",
            "MedicalMask", "Mask", "mask",
            "BlurLevel", "blurLevel", "Sharpness",
            "NoiseLevel", "noiseLevel", "Noise",
            "FaceQuality", "ExpressionLevel",
            "Liveness2D",
            "EyesLeft", "EyesRight",
        ]
        var seen = Set<String>()
        func addAttr(_ key: String, _ attr: FaceAttribute) {
            let lk = key.lowercased()
            guard seen.insert(lk).inserted else { return }
            if let confidence = attr.confidence, !confidence.isEmpty {
                rows.append((key, "\(attr.value) (\(confidence))"))
            } else {
                rows.append((key, attr.value))
            }
        }
        for key in preferred {
            if let attr = face.attributes[key] {
                addAttr(key, attr)
            }
        }
        for (key, attr) in face.attributes {
            addAttr(key, attr)
        }
        return rows
    }

    /// Size of the upright bitmap passed to the SDK (matches `prepareImageForEngine` output).
    public static func uprightImageSize(for image: UIImage) -> CGSize {
        var size = image.size
        guard size.width > 0, size.height > 0 else { return size }
        let maxSide: CGFloat = 1280
        let longSide = max(size.width, size.height)
        guard longSide > maxSide else { return size }
        let scale = maxSide / longSide
        return CGSize(width: round(size.width * scale), height: round(size.height * scale))
    }

    /// Same overlay mapping as FaceLiveness-iOS `CameraViewController.mapFaceRect`.
    /// SDK coordinates are in the camera frame the engine processed; preview is aspect-fill
    /// and the front camera is mirrored horizontally.
    public static func mapPointToOverlay(
        _ point: CGPoint,
        frameSize: CGSize,
        overlayBounds: CGRect,
        mirror: Bool
    ) -> CGPoint? {
        let viewW = overlayBounds.width
        let viewH = overlayBounds.height
        let frameW = frameSize.width
        let frameH = frameSize.height
        guard viewW > 0, viewH > 0, frameW > 0, frameH > 0 else { return nil }
        let scale = max(viewW / frameW, viewH / frameH)
        let dx = (viewW - frameW * scale) / 2
        let dy = (viewH - frameH * scale) / 2
        var vx = point.x * scale + dx
        let vy = point.y * scale + dy
        if mirror { vx = viewW - vx }
        return CGPoint(x: vx, y: vy)
    }

    public static func mapRectToOverlay(
        _ rect: CGRect,
        frameSize: CGSize,
        overlayBounds: CGRect,
        mirror: Bool
    ) -> CGRect? {
        guard let p1 = mapPointToOverlay(
            CGPoint(x: rect.minX, y: rect.minY),
            frameSize: frameSize,
            overlayBounds: overlayBounds,
            mirror: mirror
        ), let p2 = mapPointToOverlay(
            CGPoint(x: rect.maxX, y: rect.maxY),
            frameSize: frameSize,
            overlayBounds: overlayBounds,
            mirror: mirror
        ) else {
            return nil
        }
        return CGRect(
            x: min(p1.x, p2.x),
            y: min(p1.y, p2.y),
            width: abs(p2.x - p1.x),
            height: abs(p2.y - p1.y)
        )
    }

    public static func mapPointsToOverlay(
        _ points: [CGPoint],
        frameSize: CGSize,
        overlayBounds: CGRect,
        mirror: Bool
    ) -> [CGPoint] {
        points.compactMap {
            mapPointToOverlay($0, frameSize: frameSize, overlayBounds: overlayBounds, mirror: mirror)
        }
    }

    private static func parseLandmarks(_ raw: [[String: Any]]) -> [CGPoint] {
        raw.compactMap { point in
            guard let x = doubleValue(point["x"]), let y = doubleValue(point["y"]) else {
                return nil
            }
            return CGPoint(x: x, y: y)
        }
    }

    /// Android `FaceBoxParser.filterFda14`: FDA 21 = 7×3, drop triad centroid → 14.
    static func filterFda14(_ points: [CGPoint]) -> [CGPoint] {
        guard points.count == 21 else { return points }
        var out: [CGPoint] = []
        var i = 0
        while i + 2 < points.count {
            let triad = [points[i], points[i + 1], points[i + 2]]
            let cx = (triad[0].x + triad[1].x + triad[2].x) / 3
            let cy = (triad[0].y + triad[1].y + triad[2].y) / 3
            var drop = 0
            var best = hypot(triad[0].x - cx, triad[0].y - cy)
            for k in 1..<3 {
                let d = hypot(triad[k].x - cx, triad[k].y - cy)
                if d < best {
                    best = d
                    drop = k
                }
            }
            for k in 0..<3 where k != drop {
                out.append(triad[k])
            }
            i += 3
        }
        return out
    }

    /// Android `FaceBoxParser.luminance` — sample the face box on the source bitmap.
    static func luminance(_ source: UIImage?, box: CGRect) -> Float {
        guard let source, let cg = source.cgImage else { return 0 }
        let imgW = cg.width
        let imgH = cg.height
        guard imgW > 1, imgH > 1 else { return 0 }
        let left = max(0, Int(box.minX))
        let top = max(0, Int(box.minY))
        let right = min(imgW, Int(box.maxX))
        let bottom = min(imgH, Int(box.maxY))
        guard right - left >= 2, bottom - top >= 2 else { return 0 }
        let stepX = max(1, (right - left) / 16)
        let stepY = max(1, (bottom - top) / 16)
        guard let ctx = CGContext(
            data: nil,
            width: imgW,
            height: imgH,
            bitsPerComponent: 8,
            bytesPerRow: imgW * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return 0 }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: imgW, height: imgH))
        guard let data = ctx.data else { return 0 }
        let ptr = data.bindMemory(to: UInt8.self, capacity: imgW * imgH * 4)
        var sum: Int64 = 0
        var n = 0
        var y = top
        while y < bottom {
            var x = left
            while x < right {
                let o = (y * imgW + x) * 4
                let r = Int64(ptr[o])
                let g = Int64(ptr[o + 1])
                let b = Int64(ptr[o + 2])
                sum += (r * 299 + g * 587 + b * 114) / 1000
                n += 1
                x += stepX
            }
            y += stepY
        }
        guard n > 0 else { return 0 }
        return Float(sum) / Float(n) / 255
    }

    public static func mapRect(
        _ rect: CGRect,
        uprightSize: CGSize,
        bufferSize: CGSize,
        previewLayer: AVCaptureVideoPreviewLayer,
        frontCamera: Bool
    ) -> CGRect? {
        mapRectToOverlay(
            rect,
            frameSize: bufferSize.width > 0 ? bufferSize : uprightSize,
            overlayBounds: previewLayer.bounds,
            mirror: frontCamera
        )
    }

    public static func prettyJSON(_ json: String?) -> String? {
        guard let json, !json.isEmpty,
              let data = json.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              let prettyData = try? JSONSerialization.data(
                withJSONObject: object,
                options: [.prettyPrinted, .sortedKeys]
              ),
              let pretty = String(data: prettyData, encoding: .utf8) else {
            return json
        }
        return pretty
    }

    /// Attribute-mode panel: parsed fields plus optional raw SDK responses.
    public static func attributePanelText(
        for face: DetectedFace?,
        detectJSON: String?,
        qualityJSON: String?,
        estimatorJSON: String? = nil,
        showMissingFields: Bool = true
    ) -> String {
        var sections: [String] = []

        if let face {
            let parsed = displayLines(for: face, showMissingFields: showMissingFields)
            sections.append(parsed.joined(separator: "\n"))
        } else {
            sections.append("No face detected")
        }

        return sections.joined(separator: "\n")
    }

    private static func appendAttribute(
        _ lines: inout [String],
        title: String,
        keys: [String],
        from attributes: [String: FaceAttribute],
        showMissing: Bool
    ) {
        if let attr = keys.compactMap({ attributes[$0] }).first {
            if let confidence = attr.confidence, !confidence.isEmpty {
                lines.append("\(title): \(attr.value) (\(confidence))")
            } else {
                lines.append("\(title): \(attr.value)")
            }
            return
        }
        if showMissing {
            lines.append("\(title): — (missing from SDK)")
        }
    }

    private static func parseAttributes(_ raw: [String: Any]?) -> [String: FaceAttribute] {
        guard let raw else { return [:] }
        var out: [String: FaceAttribute] = [:]
        for (key, value) in raw {
            if let dict = value as? [String: Any] {
                let val = dict["value"].map { formatAttributeValue($0) } ?? ""
                let conf = dict["confidence"].map { formatAttributeValue($0) }
                if !val.isEmpty {
                    out[key] = FaceAttribute(value: val, confidence: conf)
                }
            } else {
                let val = formatAttributeValue(value)
                if !val.isEmpty {
                    out[key] = FaceAttribute(value: val, confidence: nil)
                }
            }
        }
        return out
    }

    private static func formatAttributeValue(_ value: Any) -> String {
        if let n = value as? NSNumber {
            let d = n.doubleValue
            if abs(d - round(d)) < 0.001 {
                return String(Int(round(d)))
            }
            return String(format: "%.2f", d)
        }
        return String(describing: value)
    }

    private static func doubleValue(_ value: Any?) -> Double? {
        if let n = value as? NSNumber { return n.doubleValue }
        if let s = value as? String { return Double(s) }
        return nil
    }

    private static func intValue(_ value: Any?) -> Int? {
        if let n = value as? NSNumber { return n.intValue }
        if let s = value as? String { return Int(s) }
        return nil
    }
}

