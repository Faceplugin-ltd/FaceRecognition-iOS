import Foundation
import UIKit

/// Identity screen liveness modes (engine-style).
public enum IdentityLivenessType: String, CaseIterable {
    case active
    case passive
    case passiveBlink

    public var title: String {
        switch self {
        case .active: return "Active"
        case .passive: return "Passive"
        case .passiveBlink: return "Passive + blink"
        }
    }
}

/// Vendor Active Liveness check kinds (unique per VideoWorker session).
public enum ActiveLivenessCheckKind: String, CaseIterable {
    case smile
    case blink
    case turnUp
    case turnDown
    case turnRight
    case turnLeft
    case perspective

    public var sdkCheck: FaceRecognitionActiveLivenessCheck {
        switch self {
        case .smile: return .smile
        case .blink: return .blink
        case .turnUp: return .turnUp
        case .turnDown: return .turnDown
        case .turnRight: return .turnRight
        case .turnLeft: return .turnLeft
        case .perspective: return .perspective
        }
    }

    public var sdkCheckRawValue: Int { Int(sdkCheck.rawValue) }

    public var title: String {
        switch self {
        case .smile: return "Smile"
        case .blink: return "Close your eyes"
        case .turnUp: return "Look up"
        case .turnDown: return "Look down"
        case .turnRight: return "Turn right"
        case .turnLeft: return "Turn left"
        case .perspective: return "Move closer / farther"
        }
    }

    public var defaultPrompt: String { title }

    public static func fromSdkCheckType(_ checkType: String) -> ActiveLivenessCheckKind? {
        switch checkType {
        case "smile": return .smile
        case "blink": return .blink
        case "turn_up": return .turnUp
        case "turn_down": return .turnDown
        case "turn_right": return .turnRight
        case "turn_left": return .turnLeft
        case "perspective": return .perspective
        default: return nil
        }
    }

    /// Front-camera mirrored BGRA flips yaw — swap left/right for the engine.
    public static func mirrored(_ kind: ActiveLivenessCheckKind) -> ActiveLivenessCheckKind {
        switch kind {
        case .turnLeft: return .turnRight
        case .turnRight: return .turnLeft
        default: return kind
        }
    }
}

/// Explicit Active Liveness thresholds (no UserDefaults — host apps supply values).
public struct ActiveLivenessParams: Equatable {
    public var smileThreshold: Float
    public var blinksThreshold: Float
    public var blinksNumber: Int
    public var yawThreshold: Float
    public var pitchThreshold: Float
    public var perspectiveThreshold: Float
    public var faceAlignAngle: Float
    public var maxFramesWait: Int
    public var checkCount: Int

    public init(
        smileThreshold: Float = 0.9,
        blinksThreshold: Float = 0.3,
        blinksNumber: Int = 2,
        yawThreshold: Float = 40,
        pitchThreshold: Float = 20,
        perspectiveThreshold: Float = 0.1,
        faceAlignAngle: Float = 10,
        maxFramesWait: Int = 200,
        checkCount: Int = 3
    ) {
        self.smileThreshold = smileThreshold
        self.blinksThreshold = blinksThreshold
        self.blinksNumber = blinksNumber
        self.yawThreshold = yawThreshold
        self.pitchThreshold = pitchThreshold
        self.perspectiveThreshold = perspectiveThreshold
        self.faceAlignAngle = faceAlignAngle
        self.maxFramesWait = maxFramesWait
        self.checkCount = checkCount
    }

    public static let `default` = ActiveLivenessParams()
}

public enum IdentityLiveness {
    public static let defaultChecksOrder: [ActiveLivenessCheckKind] = [.smile, .blink, .turnLeft]

    public static func makeTrackingConfig(matchThreshold: Float) -> FaceRecognitionVideoWorkerConfig {
        let config = FaceRecognitionVideoWorkerConfig(matchThreshold: matchThreshold)
        let al = FaceRecognitionActiveLivenessConfig.default()
        al.enabled = false
        config.activeLiveness = al
        return config
    }

    public static func makeIdentityConfig(
        matchThreshold: Float,
        livenessType: IdentityLivenessType,
        checks: [ActiveLivenessCheckKind],
        params: ActiveLivenessParams = .default,
        frontCamera: Bool = false
    ) -> FaceRecognitionVideoWorkerConfig {
        let config = FaceRecognitionVideoWorkerConfig(matchThreshold: matchThreshold)
        let al = FaceRecognitionActiveLivenessConfig.default()
        al.enabled = true
        let resolved: [ActiveLivenessCheckKind]
        switch livenessType {
        case .passiveBlink:
            resolved = [.blink]
        case .active:
            resolved = checks.isEmpty ? defaultChecksOrder : checks
        case .passive:
            resolved = []
        }
        let engineChecks = frontCamera ? resolved.map(ActiveLivenessCheckKind.mirrored) : resolved
        al.checks = engineChecks.map { NSNumber(value: $0.sdkCheckRawValue) }
        al.smileThreshold = params.smileThreshold
        al.blinksThreshold = params.blinksThreshold
        al.blinksNumber = params.blinksNumber
        al.yawThreshold = params.yawThreshold
        al.pitchThreshold = params.pitchThreshold
        al.perspectiveThreshold = params.perspectiveThreshold
        al.faceAlignAngle = params.faceAlignAngle
        al.maxFramesWait = params.maxFramesWait
        al.checkCount = max(params.checkCount, engineChecks.count)
        config.activeLiveness = al
        return config
    }

    public static func instruction(
        checkType: String,
        verdict: String,
        prompts: [ActiveLivenessCheckKind: String] = [:],
        frontCamera: Bool = false
    ) -> String {
        switch verdict {
        case "waiting_face_align":
            return "Center your face"
        case "check_fail":
            return "Try again"
        case "all_checks_passed":
            return "Liveness verified"
        default:
            if var kind = ActiveLivenessCheckKind.fromSdkCheckType(checkType) {
                if frontCamera {
                    kind = ActiveLivenessCheckKind.mirrored(kind)
                }
                return prompts[kind] ?? kind.defaultPrompt
            }
            return "Follow the prompt"
        }
    }

    public static func passive2DVerdict(
        from attribute: FaceAttribute?,
        threshold: Float
    ) -> (passed: Bool, label: String, score: Float?) {
        let raw = (attribute?.value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = raw.lowercased()
        let score = attribute?.confidence.flatMap { Float($0) }

        if lower.contains("spoof") || lower.contains("fake") {
            let label = score.map { String(format: "Spoof (%.2f)", $0) } ?? "Spoof"
            return (false, label, score)
        }
        if lower.contains("real") {
            if let score, score + 0.000_1 >= threshold {
                return (true, String(format: "Real (%.2f)", score), score)
            }
            if let score {
                return (false, String(format: "Below threshold (%.2f)", score), score)
            }
            return (false, "Below threshold", nil)
        }
        if raw.isEmpty {
            return (false, "Checking liveness…", score)
        }
        return (false, raw, score)
    }
}
