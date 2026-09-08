import AVFoundation
import Foundation

/// Mirrors Android `SettingsActivity` preference keys and defaults.
enum AppSettings {
    static let defaults = UserDefaults.standard

    static let defaultCameraLens = "front"
    static let defaultLivenessThreshold = "0.5"
    static let defaultIdentifyThreshold = "0.67"
    static let defaultLivenessLevel = "0"
    static let defaultYawThreshold = "40.0"
    static let defaultRollThreshold = "40.0"
    static let defaultPitchThreshold = "40.0"
    static let defaultEyecloseThreshold = "0.5"

    private static let prefsSchemaKey = "prefs_schema"
    private static let prefsSchemaVW = 1

    /// Write Face SDK defaults once so capture is not stuck on the old 10° / 0.7 prefs.
    static func applyEngineDefaults() {
        if defaults.integer(forKey: prefsSchemaKey) >= prefsSchemaVW { return }
        defaults.set(defaultCameraLens, forKey: "camera_lens")
        defaults.set(defaultLivenessThreshold, forKey: "liveness_threshold")
        defaults.set(defaultLivenessLevel, forKey: "liveness_level")
        defaults.set(defaultIdentifyThreshold, forKey: "identify_threshold")
        defaults.set(defaultYawThreshold, forKey: "yaw_threshold")
        defaults.set(defaultRollThreshold, forKey: "roll_threshold")
        defaults.set(defaultPitchThreshold, forKey: "pitch_threshold")
        defaults.set(defaultEyecloseThreshold, forKey: "eyeclose_threshold")
        defaults.set(prefsSchemaVW, forKey: prefsSchemaKey)
    }

    static var useFrontCamera: Bool {
        get { (defaults.string(forKey: "camera_lens") ?? defaultCameraLens) != "back" }
        set { defaults.set(newValue ? "front" : "back", forKey: "camera_lens") }
    }

    static var cameraPosition: AVCaptureDevice.Position {
        useFrontCamera ? .front : .back
    }

    static var livenessThreshold: Float {
        floatPref("liveness_threshold", default: defaultLivenessThreshold)
    }

    static var identifyThreshold: Float {
        floatPref("identify_threshold", default: defaultIdentifyThreshold)
    }

    static var livenessLevel: Int {
        (defaults.string(forKey: "liveness_level") ?? defaultLivenessLevel) == "0" ? 0 : 1
    }

    static var yawThreshold: Float {
        floatPref("yaw_threshold", default: defaultYawThreshold)
    }

    static var rollThreshold: Float {
        floatPref("roll_threshold", default: defaultRollThreshold)
    }

    static var pitchThreshold: Float {
        floatPref("pitch_threshold", default: defaultPitchThreshold)
    }

    static var eyecloseThreshold: Float {
        floatPref("eyeclose_threshold", default: defaultEyecloseThreshold)
    }

    /// Real vs spoof for Identify / Capture / overlay. Spoof labels always fail.
    static func livenessPassed(score: Float, label: String?) -> Bool {
        let lower = (label ?? "").lowercased()
        if lower.contains("spoof") || lower.contains("fake") { return false }
        return score >= livenessThreshold
    }

    static func restoreDefaults() {
        defaults.set(defaultCameraLens, forKey: "camera_lens")
        defaults.set(defaultLivenessThreshold, forKey: "liveness_threshold")
        defaults.set(defaultIdentifyThreshold, forKey: "identify_threshold")
        defaults.set(defaultLivenessLevel, forKey: "liveness_level")
        defaults.set(defaultYawThreshold, forKey: "yaw_threshold")
        defaults.set(defaultRollThreshold, forKey: "roll_threshold")
        defaults.set(defaultPitchThreshold, forKey: "pitch_threshold")
        defaults.set(defaultEyecloseThreshold, forKey: "eyeclose_threshold")
        defaults.set(prefsSchemaVW, forKey: prefsSchemaKey)
    }

    private static func floatPref(_ key: String, default defaultValue: String) -> Float {
        Float(defaults.string(forKey: key) ?? defaultValue) ?? 0
    }
}
