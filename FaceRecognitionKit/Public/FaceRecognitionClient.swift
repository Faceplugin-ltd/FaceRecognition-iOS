import AVFoundation
import Foundation
import UIKit

/// Cropped face from a gallery photo ready for enrollment naming.
public struct GalleryFaceCandidate {
    public let crop: UIImage
    public let region: CGRect

    public init(crop: UIImage, region: CGRect) {
        self.crop = crop
        self.region = region
    }
}

/// Single entry point for integrators of FaceRecognitionSDK. Prefer this over calling `FaceRecognitionSDK` directly.
public final class FaceRecognitionClient {
    public static let shared = FaceRecognitionClient()

    private let readyLock = NSLock()
    private var engineReadyFlag = false

    public var isEngineReady: Bool {
        readyLock.lock()
        defer { readyLock.unlock() }
        return engineReadyFlag
    }

    private init() {}

    // MARK: - Lifecycle

    public func activate(license: String, completion: @escaping (Int) -> Void) {
        FaceRecognitionSDKQueue.async { [weak self] in
            guard let self else { return }
            if self.isEngineReady {
                DispatchQueue.main.async { completion(0) }
                return
            }
            _ = FaceRecognitionSDK.getMachineCode()
            var ret = FaceRecognitionSDK.setActivation(license)
            if ret == 0 {
                ret = FaceRecognitionSDK.initSDK()
            }
            if ret == 0 {
                self.readyLock.lock()
                self.engineReadyFlag = true
                self.readyLock.unlock()
            }
            DispatchQueue.main.async { completion(Int(ret)) }
        }
    }

    public func deactivate() {
        FaceRecognitionSDKQueue.sync {
            FaceRecognitionSDK.deinitSDK()
            self.readyLock.lock()
            self.engineReadyFlag = false
            self.readyLock.unlock()
        }
    }

    public func setLandmarkMode(_ mode: Int) -> Int {
        FaceRecognitionSDKQueue.setLandmarkMode(mode)
    }

    public func landmarkMode() -> Int {
        FaceRecognitionSDKQueue.landmarkMode()
    }

    public func detect(
        _ image: UIImage,
        crop: Bool = false,
        flags: FaceRecognitionDetectFlags = .all
    ) -> String? {
        FaceRecognitionSDKQueue.detect(image, crop: crop, flags: flags)
    }

    public func extractFeature(from image: UIImage) -> Data? {
        guard let json = FaceRecognitionSDKQueue.extractFeature(from: image) else { return nil }
        return FaceJSON.parseFeatureData(json)
    }

    public func extractFeature(fromSampleBuffer sampleBuffer: CMSampleBuffer) -> Data? {
        guard let json = FaceRecognitionSDKQueue.extractFeature(fromSampleBuffer: sampleBuffer) else {
            return nil
        }
        return FaceJSON.parseFeatureData(json)
    }

    public func similarity(feature1: Data, feature2: Data) -> Float {
        FaceRecognitionSDKQueue.similarity(feature1: feature1, feature2: feature2)
    }

    public func quality(_ image: UIImage, crop: Bool = false) -> String? {
        FaceRecognitionSDKQueue.quality(image, crop: crop)
    }

    // MARK: - VideoWorker

    @discardableResult
    public func startVideoWorker(config: FaceRecognitionVideoWorkerConfig) -> Int {
        FaceRecognitionSDKQueue.startVideoWorker(config: config)
    }

    public func setVideoWorkerEventHandler(_ handler: ((String) -> Void)?) {
        FaceRecognitionSDKQueue.setVideoWorkerEventHandler(handler)
    }

    @discardableResult
    public func syncDatabase(matchThreshold: Float) -> Int {
        FaceRecognitionSDKQueue.syncVideoWorkerDatabase(matchThreshold: matchThreshold)
    }

    @discardableResult
    public func addFrame(_ image: UIImage) -> Int {
        FaceRecognitionSDKQueue.addVideoWorkerFrameNonBlocking(image)
    }

    @discardableResult
    public func addSampleBuffer(_ sampleBuffer: CMSampleBuffer) -> Int {
        FaceRecognitionSDKQueue.addVideoWorkerSampleBuffer(sampleBuffer)
    }

    public func stopVideoWorker() {
        FaceRecognitionSDKQueue.stopVideoWorker()
    }

    public func makeTrackingConfig(matchThreshold: Float) -> FaceRecognitionVideoWorkerConfig {
        IdentityLiveness.makeTrackingConfig(matchThreshold: matchThreshold)
    }

    public func makeIdentityConfig(
        matchThreshold: Float,
        livenessType: IdentityLivenessType,
        checks: [ActiveLivenessCheckKind],
        params: ActiveLivenessParams = .default,
        frontCamera: Bool = false
    ) -> FaceRecognitionVideoWorkerConfig {
        IdentityLiveness.makeIdentityConfig(
            matchThreshold: matchThreshold,
            livenessType: livenessType,
            checks: checks,
            params: params,
            frontCamera: frontCamera
        )
    }

    // MARK: - Database

    public var enrolledCount: Int { FaceDatabase.shared.count }
    public var isEnrollmentEmpty: Bool { FaceDatabase.shared.isEmpty }

    public func loadDatabase() {
        FaceDatabase.shared.load()
    }

    public func enrolledPeople() -> [EnrolledPerson] {
        FaceDatabase.shared.people
    }

    @discardableResult
    public func enroll(name: String, feature: Data, thumbnail: UIImage?) -> EnrolledPerson? {
        FaceDatabase.shared.add(name: name, feature: feature, thumbnail: thumbnail)
    }

    public func removeEnrolled(ids: Set<String>) {
        FaceDatabase.shared.remove(ids: ids)
    }

    public func clearEnrolled() {
        FaceDatabase.shared.clear()
    }

    public func bestMatch(for feature: Data, threshold: Float) -> (person: EnrolledPerson, score: Float)? {
        FaceDatabase.shared.bestMatch(for: feature, threshold: threshold)
    }

    public func person(atVideoWorkerIndex index: Int) -> EnrolledPerson? {
        FaceDatabase.shared.person(atVideoWorkerIndex: index)
    }

    public func thumbnail(for person: EnrolledPerson) -> UIImage? {
        FaceDatabase.shared.thumbnail(for: person)
    }

    // MARK: - Gallery enroll helpers

    /// Detect faces, crop each, skip already-enrolled matches.
    public func galleryCandidates(
        from image: UIImage,
        matchThreshold: Float
    ) -> (candidates: [GalleryFaceCandidate], totalDetected: Int) {
        let upright = CameraFrameUtils.normalizedUp(image)
        let prepared = CameraFrameUtils.enginePreparedImage(upright)
        _ = setLandmarkMode(14)
        let detectJSON = FaceRecognitionSDKQueue.detect(prepared, crop: false, flags: [.landmarks])
        let faces = (detectJSON.map { FaceJSON.parseDetect($0) } ?? [])
            .sorted {
                $0.region.width * $0.region.height > $1.region.width * $1.region.height
            }
        let candidates: [GalleryFaceCandidate] = faces.compactMap { face in
            guard let crop = CameraFrameUtils.cropFace(fromEngineImage: prepared, region: face.region) else {
                return nil
            }
            if let feature = extractFeature(from: crop),
               bestMatch(for: feature, threshold: matchThreshold) != nil {
                return nil
            }
            return GalleryFaceCandidate(crop: crop, region: face.region)
        }
        return (candidates, faces.count)
    }

    public func passive2DVerdict(
        from attribute: FaceAttribute?,
        threshold: Float
    ) -> (passed: Bool, label: String, score: Float?) {
        IdentityLiveness.passive2DVerdict(from: attribute, threshold: threshold)
    }

    public func async(_ work: @escaping () -> Void) {
        FaceRecognitionSDKQueue.async(work)
    }

    // MARK: - Android-parity helpers

    /// Mirrors Android `FaceDetectionParam` presets used by the demo app.
    public enum FaceDetectionPurpose {
        /// Gallery enroll — landmarks only.
        case galleryEnroll
        /// Oval capture still — pose, landmarks, quality, eyes, liveness, mask.
        case capture
        /// Identify camera / attribute gallery — all attributes.
        case fullAttributes
        /// Live Identify side detect.
        case livenessOnly
        /// Live Capture side detect.
        case eyesOnly
    }

    public func detectFlags(for purpose: FaceDetectionPurpose, livenessLevel: Int = 0) -> FaceRecognitionDetectFlags {
        switch purpose {
        case .galleryEnroll:
            return [.landmarks]
        case .capture:
            var flags: FaceRecognitionDetectFlags = [
                .pose, .landmarks, .quality, .faceQuality, .eyes, .liveness, .mask
            ]
            if livenessLevel == 0 {
                flags.insert(.livenessAccurate)
            }
            return flags
        case .fullAttributes:
            var flags: FaceRecognitionDetectFlags = .all
            flags.insert(.glasses)
            if livenessLevel == 0 {
                flags.insert(.livenessAccurate)
            } else {
                flags.remove(.livenessAccurate)
            }
            return flags
        case .livenessOnly:
            return LiveDetect.livenessOnlyFlags(level: livenessLevel)
        case .eyesOnly:
            return LiveDetect.eyesOnlyFlags()
        }
    }

    public func faceDetection(from image: UIImage, purpose: FaceDetectionPurpose, livenessLevel: Int = 0) -> [DetectedFace] {
        let flags = detectFlags(for: purpose, livenessLevel: livenessLevel)
        if flags.contains(.landmarks) {
            _ = setLandmarkMode(14)
        }
        guard let json = detect(image, crop: false, flags: flags) else { return [] }
        return FaceJSON.parseDetect(json, source: image)
    }

    public func faceDetection(from image: UIImage, allAttributes: Bool = true, livenessLevel: Int = 0) -> [DetectedFace] {
        faceDetection(
            from: image,
            purpose: allAttributes ? .fullAttributes : .galleryEnroll,
            livenessLevel: livenessLevel
        )
    }

    public func templateExtraction(from image: UIImage, face: DetectedFace) -> Data? {
        guard let crop = CameraFrameUtils.cropFace(fromEngineImage: image, region: face.region) else {
            return nil
        }
        return extractFeature(from: crop)
    }
}
