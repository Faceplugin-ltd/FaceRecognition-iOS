import AVFoundation
import UIKit
import FaceRecognitionKit

/// Android `CaptureActivity` — VideoWorker boxes + eyes side-detect + oval coach.
final class CaptureCameraViewController: BaseCameraViewController {
    private let overlay = CaptureOverlayView()
    private let warningLabel = UILabel()
    private let resultPanel = UIView()
    private let livenessLabel = UILabel()
    private let qualityLabel = UILabel()
    private let luminanceLabel = UILabel()
    private let enrollButton = UIButton(type: .system)
    private var capturedBitmap: UIImage?
    private var capturedFace: DetectedFace?
    private var cameraStopped = false
    private var videoWorkerReady = false
    private var pbBusy = false
    private var lastFrame: UIImage?
    private var lastFrameSize: CGSize = CameraFrameUtils.androidPreviewSize
    private var lastEyeBoxes: [DetectedFace] = []
    private let stateLock = NSLock()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Face Capture"

        overlay.translatesAutoresizingMaskIntoConstraints = false
        overlay.onCaptureAnimationFinished = { [weak self] in self?.showCaptureResult() }
        view.addSubview(overlay)

        warningLabel.textColor = .white
        warningLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        warningLabel.textAlignment = .center
        warningLabel.numberOfLines = 2
        warningLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(warningLabel)

        resultPanel.backgroundColor = FPColor.surfaceAlt
        resultPanel.layer.cornerRadius = 12
        resultPanel.isHidden = true
        resultPanel.translatesAutoresizingMaskIntoConstraints = false
        [livenessLabel, qualityLabel, luminanceLabel].forEach {
            $0.textColor = FPColor.text
            $0.font = .systemFont(ofSize: 14)
            $0.numberOfLines = 0
            $0.translatesAutoresizingMaskIntoConstraints = false
            resultPanel.addSubview($0)
        }
        enrollButton.setTitle("Enroll", for: .normal)
        enrollButton.backgroundColor = FPColor.purple
        enrollButton.setTitleColor(FPColor.text, for: .normal)
        enrollButton.layer.cornerRadius = 10
        enrollButton.addTarget(self, action: #selector(enrollTapped), for: .touchUpInside)
        enrollButton.translatesAutoresizingMaskIntoConstraints = false
        resultPanel.addSubview(enrollButton)
        view.addSubview(resultPanel)

        NSLayoutConstraint.activate([
            overlay.topAnchor.constraint(equalTo: cameraView.topAnchor),
            overlay.leadingAnchor.constraint(equalTo: cameraView.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: cameraView.trailingAnchor),
            overlay.bottomAnchor.constraint(equalTo: cameraView.bottomAnchor),

            warningLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            warningLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            warningLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            warningLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -120),

            resultPanel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            resultPanel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            resultPanel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),

            livenessLabel.topAnchor.constraint(equalTo: resultPanel.topAnchor, constant: 12),
            livenessLabel.leadingAnchor.constraint(equalTo: resultPanel.leadingAnchor, constant: 12),
            livenessLabel.trailingAnchor.constraint(equalTo: resultPanel.trailingAnchor, constant: -12),

            qualityLabel.topAnchor.constraint(equalTo: livenessLabel.bottomAnchor, constant: 8),
            qualityLabel.leadingAnchor.constraint(equalTo: livenessLabel.leadingAnchor),
            qualityLabel.trailingAnchor.constraint(equalTo: livenessLabel.trailingAnchor),

            luminanceLabel.topAnchor.constraint(equalTo: qualityLabel.bottomAnchor, constant: 8),
            luminanceLabel.leadingAnchor.constraint(equalTo: livenessLabel.leadingAnchor),
            luminanceLabel.trailingAnchor.constraint(equalTo: livenessLabel.trailingAnchor),

            enrollButton.topAnchor.constraint(equalTo: luminanceLabel.bottomAnchor, constant: 12),
            enrollButton.leadingAnchor.constraint(equalTo: resultPanel.leadingAnchor, constant: 12),
            enrollButton.trailingAnchor.constraint(equalTo: resultPanel.trailingAnchor, constant: -12),
            enrollButton.bottomAnchor.constraint(equalTo: resultPanel.bottomAnchor, constant: -12),
            enrollButton.heightAnchor.constraint(equalToConstant: 44),
        ])

        overlay.setViewMode(.noFacePrepare)
        overlay.setMirrorX(useFrontCamera)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        overlay.setMirrorX(useFrontCamera)
        if overlay.viewMode != .faceCaptureDone {
            startVideoWorker()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        stopVideoWorker()
        overlay.setFaceBoxes(nil)
        super.viewWillDisappear(animated)
    }

    override func onSampleBuffer(_ sampleBuffer: CMSampleBuffer, connection: AVCaptureConnection) {
        guard overlay.viewMode != .noFacePrepare,
              overlay.viewMode != .faceCaptureDone,
              videoWorkerReady else { return }
        guard let prepared = CameraFrameUtils.liveEngineImage(
            from: sampleBuffer,
            frontCamera: useFrontCamera
        ) else { return }

        stateLock.lock()
        lastFrame = prepared
        lastFrameSize = prepared.size
        stateLock.unlock()

        FaceRecognitionClient.shared.addFrame(prepared)
        requestEyes(prepared)
    }

    private func startVideoWorker() {
        let client = FaceRecognitionClient.shared
        client.setVideoWorkerEventHandler { [weak self] json in
            self?.onVideoWorkerEvent(json)
        }
        client.async { [weak self] in
            let config = client.makeTrackingConfig(matchThreshold: 0.8)
            let started = client.startVideoWorker(config: config)
            DispatchQueue.main.async {
                guard let self, self.viewIfLoaded?.window != nil else {
                    client.stopVideoWorker()
                    return
                }
                self.videoWorkerReady = started == 0
            }
        }
    }

    private func stopVideoWorker() {
        videoWorkerReady = false
        FaceRecognitionClient.shared.stopVideoWorker()
        stateLock.lock()
        lastEyeBoxes = []
        stateLock.unlock()
    }

    private func onVideoWorkerEvent(_ json: String) {
        guard let event = FaceJSON.parseVideoWorkerEvent(json),
              case let .tracking(_, faces, _, frameSize) = event else { return }
        var boxes = FaceJSON.toDetectedFaces(faces, includeWeak: false)
        stateLock.lock()
        let eyes = lastEyeBoxes
        let storedFrame = lastFrame
        let storedSize = lastFrameSize
        stateLock.unlock()
        boxes = LiveDetect.mergeEyes(boxes, pb: eyes, swapLeftRight: useFrontCamera)
        let size = storedSize.width > 0 ? storedSize : frameSize
        applyCaptureTracking(faceBoxes: boxes, frame: storedFrame, frameSize: size)
    }

    private func requestEyes(_ frame: UIImage) {
        if overlay.viewMode == .faceCaptureDone { return }
        stateLock.lock()
        if pbBusy {
            stateLock.unlock()
            return
        }
        pbBusy = true
        stateLock.unlock()

        FaceRecognitionClient.shared.async { [weak self] in
            let boxes = FaceRecognitionClient.shared.faceDetection(from: frame, purpose: .eyesOnly)
            self?.stateLock.lock()
            self?.lastEyeBoxes = boxes
            self?.pbBusy = false
            self?.stateLock.unlock()
        }
    }

    private func applyCaptureTracking(faceBoxes: [DetectedFace], frame: UIImage?, frameSize: CGSize) {
        let state = CaptureFaceChecker.checkFace(faceBoxes, frameSize: frameSize)

        if overlay.viewMode == .repeatNoFacePrepare {
            if state > .noFace {
                DispatchQueue.main.async { [weak self] in
                    self?.overlay.setViewMode(.toFaceCircle)
                }
            }
            return
        }

        if overlay.viewMode == .faceCircle {
            var captureCopy: UIImage?
            var captureFace: DetectedFace?
            if state == .captureOk, let frame, !faceBoxes.isEmpty {
                captureCopy = frame
                captureFace = faceBoxes[0]
            }
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.overlay.setFrameSize(frameSize)
                self.overlay.setFaceBoxes(faceBoxes)
                switch state {
                case .noFace:
                    self.warningLabel.text = ""
                    self.overlay.setViewMode(.faceCircleToNoFace)
                case .captureOk:
                    self.stateLock.lock()
                    let eyesEmpty = self.lastEyeBoxes.isEmpty
                    self.stateLock.unlock()
                    if eyesEmpty {
                        self.warningLabel.text = ""
                        return
                    }
                    self.warningLabel.text = ""
                    self.overlay.setViewMode(.faceCapturePrepare)
                    if let captureCopy, let captureFace {
                        self.capturedBitmap = captureCopy
                        self.capturedFace = captureFace
                        self.overlay.setCapturedBitmap(captureCopy)
                    }
                default:
                    self.warningLabel.text = CaptureFaceChecker.warning(for: state)
                }
            }
            return
        }

        if overlay.viewMode == .faceCapturePrepare {
            if state == .captureOk, let frame, !faceBoxes.isEmpty {
                DispatchQueue.main.async { [weak self] in
                    self?.capturedBitmap = frame
                    self?.capturedFace = faceBoxes[0]
                    self?.overlay.setCapturedBitmap(frame)
                }
            }
            return
        }

        if overlay.viewMode == .faceCaptureDone {
            DispatchQueue.main.async { [weak self] in
                self?.stopCameraOnce()
            }
        }
    }

    private func stopCameraOnce() {
        guard !cameraStopped else { return }
        cameraStopped = true
        sessionQueue.async { [weak self] in
            self?.session.stopRunning()
        }
    }

    private func showCaptureResult() {
        guard let capturedBitmap else {
            resultPanel.isHidden = false
            return
        }
        let fallback = capturedFace
        let level = AppSettings.livenessLevel
        FaceRecognitionClient.shared.async { [weak self] in
            var shown = fallback
            let faces = FaceRecognitionClient.shared.faceDetection(
                from: capturedBitmap,
                purpose: .fullAttributes,
                livenessLevel: level
            )
            if let first = faces.first {
                shown = first
            }
            DispatchQueue.main.async {
                self?.applyCaptureResult(shown)
            }
        }
    }

    private func applyCaptureResult(_ shown: DetectedFace?) {
        guard let shown, capturedBitmap != nil else {
            resultPanel.isHidden = false
            return
        }
        capturedFace = shown
        let lower = (shown.livenessLabel ?? "").lowercased()
        if lower.contains("spoof") || lower.contains("fake") {
            livenessLabel.text = "Liveness: Spoof, score = \(shown.livenessScore)"
        } else if shown.livenessScore >= AppSettings.livenessThreshold {
            livenessLabel.text = "Liveness: Real, score = \(shown.livenessScore)"
        } else {
            livenessLabel.text = "Liveness: Spoof, score = \(shown.livenessScore)"
        }
        qualityLabel.text = ResultDetails.qualityText(shown.faceQualityScore)
        if let ql = shown.qualityLabel, !ql.isEmpty {
            qualityLabel.text? += "\n\(ql)"
        }
        luminanceLabel.text = "Luminance: \(shown.faceLuminance)"
        if let capturedBitmap {
            let stillState = CaptureFaceChecker.checkFace([shown], frameSize: capturedBitmap.size)
            if stillState == .faceOccluded {
                warningLabel.text = "Face occluded!"
            } else if stillState == .eyeClosed {
                warningLabel.text = "Eye closed!"
            }
        }
        resultPanel.isHidden = false
    }

    @objc private func enrollTapped() {
        guard let capturedBitmap, let capturedFace else {
            presentToast("Enrollment failed")
            return
        }
        FaceRecognitionClient.shared.async { [weak self] in
            guard let self else { return }
            let faceImage = FaceUtils.cropFace(from: capturedBitmap, face: capturedFace)
            let feature = FaceRecognitionClient.shared.templateExtraction(from: capturedBitmap, face: capturedFace)
            DispatchQueue.main.async {
                guard let feature, !feature.isEmpty else {
                    self.presentToast("Enrollment failed")
                    return
                }
                let name = "Person\(Int.random(in: 10_000...20_000))"
                if FaceRecognitionClient.shared.enroll(name: name, feature: feature, thumbnail: faceImage) != nil {
                    self.presentToast("Person enrolled!")
                    self.navigationController?.popViewController(animated: true)
                } else {
                    self.presentToast("Enrollment failed")
                }
            }
        }
    }

    private func presentToast(_ message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        present(alert, animated: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { alert.dismiss(animated: true) }
    }
}
