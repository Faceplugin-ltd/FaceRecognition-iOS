import CoreGraphics
import Foundation

public extension DetectedFace {
    func attributeLabel(_ keys: [String]) -> String? {
        for key in keys {
            if let value = attributes[key]?.value, !value.isEmpty { return value }
        }
        return nil
    }

    func attributeScore(_ keys: [String]) -> Float {
        for key in keys {
            guard let attr = attributes[key] else { continue }
            if let confidence = attr.confidence, let score = Float(confidence) { return score }
            if let score = Float(attr.value) { return score }
        }
        return 0
    }

    var livenessScore: Float { attributeScore(["Liveness2D", "liveness"]) }
    var livenessLabel: String? { attributeLabel(["Liveness2D", "liveness"]) }
    var faceQualityScore: Float { attributeScore(["FaceQuality", "ExpressionLevel", "face_quality"]) }
    var qualityLabel: String? { attributeLabel(["FaceQuality", "ExpressionLevel"]) }
    var faceLuminance: Float {
        if luminance > 0 { return luminance }
        return attributeScore(["Luminance", "face_luminance"])
    }
    var leftEyeClosed: Float { attributeScore(["EyesLeft", "left_eye_closed"]) }
    var rightEyeClosed: Float { attributeScore(["EyesRight", "right_eye_closed"]) }
    var faceOcclusion: Float { attributeScore(["Occlusion", "face_occlusion"]) }
    var mouthOpened: Float {
        let score = attributeScore(["Mouth", "mouth_opened"])
        if score > 0 { return score }
        return Self.mouthOpenFromLandmarks(landmarks: landmarks, faceHeight: boxRect.height)
    }
    var ageValue: Int { Int(attributeScore(["Age", "age"])) }
    var genderValue: Int {
        let label = attributeLabel(["Gender", "gender"])?.lowercased() ?? ""
        if label.contains("female") || label == "1" { return 1 }
        if label.contains("male") || label == "0" { return 0 }
        return Int(attributeScore(["Gender", "gender"]))
    }
    var genderLabel: String? { attributeLabel(["Gender", "gender"]) }
    var emotionLabel: String? { attributeLabel(["Emotion", "emotion"]) }
    var maskLabel: String? { attributeLabel(["MedicalMask", "Mask", "mask"]) }
    var deepfakeLabel: String? { attributeLabel(["Deepfake", "deepfake"]) }
    var eyesLeftLabel: String? { attributeLabel(["EyesLeft"]) }
    var eyesRightLabel: String? { attributeLabel(["EyesRight"]) }

    var boxRect: CGRect { region }

    /// Android `FaceBoxParser.mouthOpenFromLandmarks` (68-point iBUG inner lip).
    static func mouthOpenFromLandmarks(landmarks: [CGPoint], faceHeight: CGFloat) -> Float {
        guard landmarks.count >= 67, faceHeight > 1 else { return 0 }
        let ux = landmarks[62].x, uy = landmarks[62].y
        let lx = landmarks[66].x, ly = landmarks[66].y
        let gap = hypot(lx - ux, ly - uy)
        return Float(min(1, gap / (faceHeight * 0.12)))
    }
}
