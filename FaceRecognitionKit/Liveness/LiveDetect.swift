import CoreGraphics
import Foundation
import UIKit

/// Narrow still-image detects used next to VideoWorker (Android `LiveDetect`).
public enum LiveDetect {
    public static func livenessOnlyFlags(level: Int) -> FaceRecognitionDetectFlags {
        var flags: FaceRecognitionDetectFlags = [.liveness]
        if level == 0 {
            flags.insert(.livenessAccurate)
        }
        return flags
    }

    public static func eyesOnlyFlags() -> FaceRecognitionDetectFlags {
        [.eyes]
    }

    public static func mergeLiveness(_ track: [DetectedFace], pb: [DetectedFace]?) -> [DetectedFace] {
        guard let pb, !pb.isEmpty else { return track }
        return track.map { dst in
            guard let src = bestMatch(dst, pb) else { return dst }
            var extra: [String: FaceAttribute] = [:]
            if let attr = src.attributes["Liveness2D"] ?? src.attributes["liveness"] {
                extra["Liveness2D"] = attr
            }
            return extra.isEmpty ? dst : dst.mergingAttributes(extra)
        }
    }

    public static func mergeEyes(
        _ track: [DetectedFace],
        pb: [DetectedFace]?,
        swapLeftRight: Bool = false
    ) -> [DetectedFace] {
        guard let pb, !pb.isEmpty else { return track }
        return track.map { dst in
            guard let src = bestMatch(dst, pb) else { return dst }
            var extra: [String: FaceAttribute] = [:]
            let left = src.attributes["EyesLeft"]
            let right = src.attributes["EyesRight"]
            if swapLeftRight {
                if let right { extra["EyesLeft"] = right }
                if let left { extra["EyesRight"] = left }
            } else {
                if let left { extra["EyesLeft"] = left }
                if let right { extra["EyesRight"] = right }
            }
            return extra.isEmpty ? dst : dst.mergingAttributes(extra)
        }
    }

    private static func bestMatch(_ dst: DetectedFace, _ pb: [DetectedFace]) -> DetectedFace? {
        if pb.count == 1 { return pb[0] }
        var best: DetectedFace?
        var bestIou: CGFloat = 0.1
        for src in pb {
            let value = iou(dst.region, src.region)
            if value > bestIou {
                bestIou = value
                best = src
            }
        }
        return best ?? pb[0]
    }

    private static func iou(_ a: CGRect, _ b: CGRect) -> CGFloat {
        let inter = a.intersection(b)
        if inter.isNull || inter.isEmpty { return 0 }
        let union = a.width * a.height + b.width * b.height - inter.width * inter.height
        if union <= 0 { return 0 }
        return (inter.width * inter.height) / union
    }
}
