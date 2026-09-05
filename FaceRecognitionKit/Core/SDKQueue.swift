import UIKit
import AVFoundation

/// Serial access to the native `FaceRecognitionSDK` ObjC API (`facerecognitionsdk.framework`).
/// The engine is not safe for concurrent use — overlapping detect/feature work from the camera
/// and database seeding can freeze or crash on device.
public enum FaceRecognitionSDKQueue {
    private static let key = DispatchSpecificKey<Void>()
    private static let queue: DispatchQueue = {
        let q = DispatchQueue(label: "com.faceplugin.facerecognitionsdk.sdk", qos: .userInitiated)
        q.setSpecific(key: key, value: ())
        return q
    }()
    private static let frameLock = NSLock()
    private static var frameBusy = false

    public static func async(_ work: @escaping () -> Void) {
        queue.async(execute: work)
    }

    public static func sync<T>(_ work: () -> T) -> T {
        if DispatchQueue.getSpecific(key: key) != nil {
            return work()
        }
        return queue.sync(execute: work)
    }

    public static func detect(_ image: UIImage, crop: Bool, flags: FaceRecognitionDetectFlags = .all) -> String? {
        sync { FaceRecognitionSDK.detect(image, crop: crop, flags: flags) }
    }

    public static func setLandmarkMode(_ mode: Int) -> Int {
        sync { Int(FaceRecognitionSDK.setLandmarkMode(Int32(mode))) }
    }

    public static func landmarkMode() -> Int {
        sync { Int(FaceRecognitionSDK.landmarkMode()) }
    }

    public static func estimatorStatus() -> String? {
        sync { FaceRecognitionSDK.estimatorStatusJSON() }
    }

    public static func quality(_ image: UIImage, crop: Bool) -> String? {
        sync { FaceRecognitionSDK.qualityImage(image, crop: crop) }
    }

    public static func extractFeature(from image: UIImage) -> String? {
        sync { FaceRecognitionSDK.extractFeature(from: image) }
    }

    public static func extractFeature(fromSampleBuffer sampleBuffer: CMSampleBuffer) -> String? {
        sync { FaceRecognitionSDK.extractFeature(with: sampleBuffer) }
    }

    public static func similarity(feature1: Data, feature2: Data) -> Float {
        sync { FaceRecognitionSDK.similarity(withFeature1: feature1, feature2: feature2) }
    }

    public static func startVideoWorker(config: FaceRecognitionVideoWorkerConfig) -> Int {
        sync {
            FaceRecognitionSDK.stopVideoWorker()
            return Int(FaceRecognitionSDK.startVideoWorker(with: config))
        }
    }

    public static func stopVideoWorker() {
        FaceRecognitionSDK.setVideoWorkerEventHandler(nil)
        async {
            FaceRecognitionSDK.stopVideoWorker()
            frameLock.lock()
            frameBusy = false
            frameLock.unlock()
        }
    }

    public static func setVideoWorkerEventHandler(_ handler: ((String) -> Void)?) {
        if let handler {
            FaceRecognitionSDK.setVideoWorkerEventHandler { json in
                handler(json)
            }
        } else {
            FaceRecognitionSDK.setVideoWorkerEventHandler(nil)
        }
    }

    @discardableResult
    public static func syncVideoWorkerDatabase(matchThreshold: Float) -> Int {
        let features = FaceDatabase.shared.featureTemplates()
        return sync {
            Int(FaceRecognitionSDK.syncVideoWorkerDatabase(
                withFeatures: features,
                matchThreshold: matchThreshold
            ))
        }
    }

    @discardableResult
    public static func addVideoWorkerFrame(_ image: UIImage) -> Int {
        sync { Int(FaceRecognitionSDK.addVideoWorkerFrame(image)) }
    }

    /// Non-blocking live add (Android `FaceRecognitionQueue.addVideoWorkerFrame`).
    @discardableResult
    public static func addVideoWorkerFrameNonBlocking(_ image: UIImage) -> Int {
        frameLock.lock()
        if frameBusy {
            frameLock.unlock()
            return 0
        }
        frameBusy = true
        frameLock.unlock()
        async {
            defer {
                frameLock.lock()
                frameBusy = false
                frameLock.unlock()
            }
            _ = FaceRecognitionSDK.addVideoWorkerFrame(image)
        }
        return 0
    }

    /// Fast path for live camera — call from the camera queue.
    @discardableResult
    public static func addVideoWorkerSampleBuffer(_ sampleBuffer: CMSampleBuffer) -> Int {
        Int(FaceRecognitionSDK.addVideoWorkerSampleBuffer(sampleBuffer))
    }
}
