import AVFoundation
import UIKit

class BaseCameraViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    let session = AVCaptureSession()
    let cameraView = UIView()
    let sessionQueue = DispatchQueue(label: "frc.camera.session")
    private let frameQueue = DispatchQueue(label: "frc.camera.frames")
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var videoOutput: AVCaptureVideoDataOutput?
    var currentPosition: AVCaptureDevice.Position = .front
    private var isActive = false
    /// Drop frames while SDK work from the previous sample is still running (Android `KEEP_ONLY_LATEST`).
    private(set) var sdkWorkPending = false

    var useFrontCamera: Bool { currentPosition == .front }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        currentPosition = AppSettings.cameraPosition

        cameraView.backgroundColor = .black
        cameraView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cameraView)
        NSLayoutConstraint.activate([
            cameraView.topAnchor.constraint(equalTo: view.topAnchor),
            cameraView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            cameraView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            cameraView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        ScreenChrome.showInnerBar(on: self)
        isActive = true
        sdkWorkPending = false
        sessionQueue.async { [weak self] in
            self?.configureSessionIfNeeded()
            self?.session.startRunning()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        isActive = false
        sdkWorkPending = false
        sessionQueue.async { [weak self] in
            self?.session.stopRunning()
        }
    }

    func onSampleBuffer(_ sampleBuffer: CMSampleBuffer, connection: AVCaptureConnection) {}

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard isActive, !sdkWorkPending else { return }
        onSampleBuffer(sampleBuffer, connection: connection)
    }

    func beginSDKWork() { sdkWorkPending = true }
    func endSDKWork() { sdkWorkPending = false }

    private func configureSessionIfNeeded() {
        guard session.inputs.isEmpty else { return }
        session.beginConfiguration()
        session.sessionPreset = .hd1280x720
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentPosition),
           let input = try? AVCaptureDeviceInput(device: device),
           session.canAddInput(input) {
            session.addInput(input)
        }
        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: frameQueue)
        if session.canAddOutput(output) {
            session.addOutput(output)
            videoOutput = output
            if let conn = output.connection(with: .video) {
                if conn.isVideoOrientationSupported {
                    conn.videoOrientation = .portrait
                }
                if conn.isVideoMirroringSupported {
                    conn.automaticallyAdjustsVideoMirroring = false
                    conn.isVideoMirrored = false
                }
            }
        }
        session.commitConfiguration()
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let layer = AVCaptureVideoPreviewLayer(session: self.session)
            layer.videoGravity = .resizeAspectFill
            layer.frame = self.cameraView.bounds
            if let conn = layer.connection, conn.isVideoOrientationSupported {
                conn.videoOrientation = .portrait
            }
            self.cameraView.layer.insertSublayer(layer, at: 0)
            self.previewLayer = layer
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = cameraView.bounds
        if let conn = previewLayer?.connection, conn.isVideoOrientationSupported {
            conn.videoOrientation = .portrait
        }
    }
}
