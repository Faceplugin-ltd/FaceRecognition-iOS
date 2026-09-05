import UIKit
import CoreGraphics

public struct FaceAttribute {
    public let value: String
    public let confidence: String?

    public init(value: String, confidence: String?) {
        self.value = value
        self.confidence = confidence
    }
}

public struct DetectedFace {
    public let faceId: Int
    public let region: CGRect
    public let attributes: [String: FaceAttribute]
    public let yaw: Double
    public let pitch: Double
    public let roll: Double
    public let landmarkCount: Int
    public let landmarks: [CGPoint]
    public let luminance: Float

    public init(
        faceId: Int,
        region: CGRect,
        attributes: [String: FaceAttribute],
        yaw: Double,
        pitch: Double,
        roll: Double,
        landmarkCount: Int,
        landmarks: [CGPoint],
        luminance: Float = 0
    ) {
        self.faceId = faceId
        self.region = region
        self.attributes = attributes
        self.yaw = yaw
        self.pitch = pitch
        self.roll = roll
        self.landmarkCount = landmarkCount
        self.landmarks = landmarks
        self.luminance = luminance
    }

    public func mergingAttributes(_ extra: [String: FaceAttribute]) -> DetectedFace {
        var merged = attributes
        for (key, value) in extra where merged[key] == nil {
            merged[key] = value
        }
        return DetectedFace(
            faceId: faceId,
            region: region,
            attributes: merged,
            yaw: yaw,
            pitch: pitch,
            roll: roll,
            landmarkCount: landmarkCount,
            landmarks: landmarks,
            luminance: luminance
        )
    }
}

public struct CameraFrame {
    public let image: UIImage
    public let uprightSize: CGSize
    public let bufferSize: CGSize

    public init(image: UIImage, uprightSize: CGSize, bufferSize: CGSize) {
        self.image = image
        self.uprightSize = uprightSize
        self.bufferSize = bufferSize
    }
}

public struct VideoWorkerActiveLiveness {
    public let verdict: String
    public let checkType: String
    public let progress: Double

    public init(verdict: String, checkType: String, progress: Double) {
        self.verdict = verdict
        self.checkType = checkType
        self.progress = progress
    }
}

public struct VideoWorkerMatch {
    public let matched: Bool
    public let personIndex: Int?
    public let score: Double?

    public init(matched: Bool, personIndex: Int?, score: Double?) {
        self.matched = matched
        self.personIndex = personIndex
        self.score = score
    }
}

public struct VideoWorkerFace {
    public let trackId: Int
    public let region: CGRect
    public let landmarks: [CGPoint]
    public let weak: Bool
    public let match: VideoWorkerMatch?
    public let age: Double?
    public let gender: String?
    public let emotion: String?
    public let activeLiveness: VideoWorkerActiveLiveness?
    public let yaw: Double
    public let pitch: Double
    public let roll: Double

    public init(
        trackId: Int,
        region: CGRect,
        landmarks: [CGPoint],
        weak: Bool,
        match: VideoWorkerMatch?,
        age: Double?,
        gender: String?,
        emotion: String?,
        activeLiveness: VideoWorkerActiveLiveness?,
        yaw: Double = 0,
        pitch: Double = 0,
        roll: Double = 0
    ) {
        self.trackId = trackId
        self.region = region
        self.landmarks = landmarks
        self.weak = weak
        self.match = match
        self.age = age
        self.gender = gender
        self.emotion = emotion
        self.activeLiveness = activeLiveness
        self.yaw = yaw
        self.pitch = pitch
        self.roll = roll
    }
}

public enum VideoWorkerEvent {
    case tracking(
        frameId: Int,
        faces: [VideoWorkerFace],
        singleFace: Bool,
        frameSize: CGSize
    )
    case match(trackId: Int, matched: Bool, personIndex: Int?, score: Double?)
}
