import AVFoundation
import UIKit
import FaceRecognitionKit

/// Android `CameraActivity` — VideoWorker 1:N + side 2D liveness + result screen.
final class IdentifyCameraViewController: BaseCameraViewController {
    private let overlay = FaceIdentifyOverlayView()
    private var recognized = false
    private var confirming = false
    private var videoWorkerReady = false
    private var pbBusy = false
    private var lastFrame: UIImage?
    private var lastFrameSize: CGSize = .zero
    private var lastLivenessBoxes: [DetectedFace] = []
    private let stateLock = NSLock()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Identify"
        overlay.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(overlay)
        NSLayoutConstraint.activate([
            overlay.topAnchor.constraint(equalTo: cameraView.topAnchor),
            overlay.leadingAnchor.constraint(equalTo: cameraView.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: cameraView.trailingAnchor),
            overlay.bottomAnchor.constraint(equalTo: cameraView.bottomAnchor),
        ])
    }

    override func viewWillAppear(_ animated: Bool) {
        recognized = false
        confirming = false
        super.viewWillAppear(animated)
        startVideoWorker()
    }

    override func viewWillDisappear(_ animated: Bool) {
        stopVideoWorker()
        overlay.update(faces: [], frameSize: .zero, mirror: useFrontCamera)
        super.viewWillDisappear(animated)
    }

    override func onSampleBuffer(_ sampleBuffer: CMSampleBuffer, connection: AVCaptureConnection) {
        guard !recognized, videoWorkerReady else { return }
        guard let prepared = CameraFrameUtils.liveEngineImage(
            from: sampleBuffer,
            frontCamera: useFrontCamera
        ) else { return }

        stateLock.lock()
        lastFrame = prepared
        lastFrameSize = prepared.size
        stateLock.unlock()

        FaceRecognitionClient.shared.addFrame(prepared)
        requestLiveness(prepared)
    }

    private func startVideoWorker() {
        let client = FaceRecognitionClient.shared
        let threshold = AppSettings.identifyThreshold
        client.setVideoWorkerEventHandler { [weak self] json in
            self?.onVideoWorkerEvent(json)
        }
        client.async { [weak self] in
            let config = client.makeTrackingConfig(matchThreshold: threshold)
            let started = client.startVideoWorker(config: config)
            let synced = client.syncDatabase(matchThreshold: threshold)
            DispatchQueue.main.async {
                guard let self, self.viewIfLoaded?.window != nil else {
                    client.stopVideoWorker()
                    return
                }
                self.videoWorkerReady = started == 0 && synced == 0
            }
        }
    }

    private func stopVideoWorker() {
        videoWorkerReady = false
        FaceRecognitionClient.shared.stopVideoWorker()
        stateLock.lock()
        lastLivenessBoxes = []
        stateLock.unlock()
    }

    private func onVideoWorkerEvent(_ json: String) {
        if recognized { return }
        guard let event = FaceJSON.parseVideoWorkerEvent(json) else { return }
        switch event {
        case let .tracking(_, faces, _, frameSize):
            var boxes = FaceJSON.toDetectedFaces(faces, includeWeak: true)
            stateLock.lock()
            let live = lastLivenessBoxes
            let storedSize = lastFrameSize
            stateLock.unlock()
            boxes = LiveDetect.mergeLiveness(boxes, pb: live)
            let size = storedSize.width > 0 ? storedSize : frameSize
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.overlay.update(faces: boxes, frameSize: size, mirror: self.useFrontCamera)
            }
            for face in faces where face.match?.matched == true {
                tryConfirmMatch(personIndex: face.match?.personIndex, score: face.match?.score)
                break
            }
        case let .match(_, matched, personIndex, score):
            if matched {
                tryConfirmMatch(personIndex: personIndex, score: score)
            }
        }
    }

    private func requestLiveness(_ frame: UIImage) {
        if recognized { return }
        stateLock.lock()
        if pbBusy {
            stateLock.unlock()
            return
        }
        pbBusy = true
        stateLock.unlock()

        let copy = frame
        let level = AppSettings.livenessLevel
        FaceRecognitionClient.shared.async { [weak self] in
            let boxes = FaceRecognitionClient.shared.faceDetection(
                from: copy,
                purpose: .livenessOnly,
                livenessLevel: level
            )
            self?.stateLock.lock()
            self?.lastLivenessBoxes = boxes
            self?.pbBusy = false
            self?.stateLock.unlock()
        }
    }

    private func liveLivenessFailed() -> Bool {
        stateLock.lock()
        let pb = lastLivenessBoxes
        stateLock.unlock()
        guard let live = pb.first else { return false }
        return !AppSettings.livenessPassed(score: live.livenessScore, label: live.livenessLabel)
    }

    private func tryConfirmMatch(personIndex: Int?, score: Double?) {
        guard let personIndex, let score else { return }
        stateLock.lock()
        let liveEmpty = lastLivenessBoxes.isEmpty
        if recognized || confirming {
            stateLock.unlock()
            return
        }
        stateLock.unlock()
        if liveEmpty { return }
        if liveLivenessFailed() { return }

        stateLock.lock()
        if recognized || confirming {
            stateLock.unlock()
            return
        }
        confirming = true
        let frame = lastFrame
        let liveBoxes = lastLivenessBoxes
        stateLock.unlock()
        guard let frame else {
            stateLock.lock()
            confirming = false
            stateLock.unlock()
            return
        }

        let level = AppSettings.livenessLevel
        FaceRecognitionClient.shared.async { [weak self] in
            guard let self else { return }
            let detected = FaceRecognitionClient.shared.faceDetection(
                from: frame,
                purpose: .fullAttributes,
                livenessLevel: level
            )
            var faceBox = detected.first ?? liveBoxes.first
            guard var faceBox else {
                DispatchQueue.main.async {
                    self.stateLock.lock()
                    self.confirming = false
                    self.stateLock.unlock()
                }
                return
            }
            if !AppSettings.livenessPassed(score: faceBox.livenessScore, label: faceBox.livenessLabel),
               let live = liveBoxes.first {
                var extra: [String: FaceAttribute] = [:]
                if let attr = live.attributes["Liveness2D"] {
                    extra["Liveness2D"] = attr
                }
                faceBox = faceBox.mergingAttributes(extra)
            }
            var person = FaceRecognitionClient.shared.person(atVideoWorkerIndex: personIndex)
            if person == nil, personIndex > 0 {
                person = FaceRecognitionClient.shared.person(atVideoWorkerIndex: personIndex - 1)
            }
            guard let person else {
                DispatchQueue.main.async {
                    self.stateLock.lock()
                    self.confirming = false
                    self.stateLock.unlock()
                }
                return
            }
            self.stateLock.lock()
            self.recognized = true
            self.stateLock.unlock()
            let identifiedCrop = FaceUtils.cropFace(from: frame, face: faceBox)
            let enrolledThumb = FaceRecognitionClient.shared.thumbnail(for: person)
            let landmarks = FaceUtils.mapLandmarksToCrop(
                face: faceBox,
                cropSize: identifiedCrop?.size ?? .zero
            )
            DispatchQueue.main.async {
                guard let nav = self.navigationController else { return }
                let result = ResultViewController(
                    identifiedFace: identifiedCrop,
                    enrolledFace: enrolledThumb,
                    name: person.name,
                    similarity: Float(score),
                    face: faceBox,
                    cropLandmarks: landmarks
                )
                var stack = nav.viewControllers.filter { $0 !== self }
                stack.append(result)
                nav.setViewControllers(stack, animated: true)
            }
        }
    }
}
