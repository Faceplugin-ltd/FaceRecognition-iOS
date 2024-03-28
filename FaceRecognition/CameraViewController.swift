import UIKit
import AVFoundation
import CoreData

class CameraViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate{
   
    @IBOutlet weak var cameraView: UIView!
    @IBOutlet weak var faceView: FaceView!
    @IBOutlet weak var resultView: UIView!
    
    var identifiedStr: String?
    var similarityStr: String?
    var livenessStr: String?
    var yawStr: String?
    var rollStr: String?
    var pitchStr: String?
    
    let session = AVCaptureSession()
    
    @IBOutlet weak var enrolledImage: UIImageView!
    @IBOutlet weak var identifiedImage: UIImageView!
    @IBOutlet weak var identifiedLbl: UILabel!
    
    @IBOutlet weak var enrolledView: UIView!
    @IBOutlet weak var identifiedView: UIView!
    @IBOutlet weak var detailsBtn: UIButton!
    
    var recognized = false

    var cameraLens_val = 0
    var livenessThreshold = Float(0)
    var identifyThreshold = Float(0)

    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: ViewController.CORE_DATA_NAME)
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        return container
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        cameraView.translatesAutoresizingMaskIntoConstraints = true
        cameraView.frame = view.bounds
        
        faceView.translatesAutoresizingMaskIntoConstraints = true
        faceView.frame = view.bounds

        resultView.translatesAutoresizingMaskIntoConstraints = true
        resultView.frame = view.bounds
        
        detailsBtn.layer.cornerRadius = 25
        detailsBtn.clipsToBounds = true
        enrolledView.layer.cornerRadius = 8
        enrolledView.clipsToBounds = true
        identifiedView.layer.cornerRadius = 8
        identifiedView.clipsToBounds = true

        let defaults = UserDefaults.standard
        cameraLens_val = defaults.integer(forKey: "camera_lens")
        livenessThreshold = defaults.float(forKey: "liveness_threshold")
        identifyThreshold = defaults.float(forKey: "identify_threshold")

        startCamera()
    }
    
    @IBAction func detailsBtnclicked(_ sender: Any) {
        guard let popupNavController = storyboard?.instantiateViewController(withIdentifier: "IdentifyDetailsVC") as? IdentifyDetailsVC else { return }
        popupNavController.identifiedStr = self.identifiedStr
        popupNavController.similarityStr = self.similarityStr
        popupNavController.livenessStr = self.livenessStr
        popupNavController.yawStr = self.yawStr
        popupNavController.rollStr = self.rollStr
        popupNavController.pitchStr = self.pitchStr
        present(popupNavController, animated: true, completion: nil)
    }
    
    func startCamera() {
        var cameraLens = AVCaptureDevice.Position.front
        if(cameraLens_val == 0) {
            cameraLens = AVCaptureDevice.Position.back
        }
        
        // Create an AVCaptureSession
        session.sessionPreset = .high

        // Create an AVCaptureDevice for the camera
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: cameraLens) else { return }
        guard let input = try? AVCaptureDeviceInput(device: videoDevice) else { return }
        if session.canAddInput(input) {
            session.addInput(input)
        }

        // Create an AVCaptureVideoDataOutput
        let videoOutput = AVCaptureVideoDataOutput()

        // Set the video output's delegate and queue for processing video frames
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue.global(qos: .default))

        // Add the video output to the session
        session.addOutput(videoOutput)

        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        cameraView.layer.addSublayer(previewLayer)

        // Start the session
        session.startRunning()
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        if(recognized == true) {
            return
        }
        
        guard let pixelBuffer: CVPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags.readOnly)
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        
        let context = CIContext()
        let cgImage = context.createCGImage(ciImage, from: ciImage.extent)
        let image = UIImage(cgImage: cgImage!)
        CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags.readOnly)

        // Rotate and flip the image
        let capturedImage = image.rotate(radians: .pi/2).flipHorizontally()
        
        let param = FaceDetectionParam()
        param.check_liveness = true

        let faceBoxes = FaceSDK.faceDetection(capturedImage, param: param)
        for faceBox in (faceBoxes as NSArray as! [FaceBox]) {
            if(cameraLens_val == 0) {
                let tmp = faceBox.x1
                faceBox.x1 = Int32(capturedImage.size.width) - faceBox.x2 - 1;
                faceBox.x2 = Int32(capturedImage.size.width) - tmp - 1;
            }
        }
        
        DispatchQueue.main.sync {
            self.faceView.setFrameSize(frameSize: capturedImage.size)
            self.faceView.setFaceBoxes(faceBoxes: faceBoxes)
        }

        if(faceBoxes.count > 0) {

            let faceBox = faceBoxes[0] as! FaceBox
            if(faceBox.liveness > livenessThreshold) {
                
                let templates = FaceSDK.templateExtraction(capturedImage, faceBox: faceBox)
                
                var maxSimilarity = Float(0)
                var maxSimilarityName = ""
                var maxSimilarityFace: Data? = nil
                
                let context = self.persistentContainer.viewContext
                let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: ViewController.ENTITIES_NAME)

                do {
                    let persons = try context.fetch(fetchRequest) as! [NSManagedObject]
                    for person in persons {
                        
                        let personTemplates = person.value(forKey: ViewController.ATTRIBUTE_TEMPLATES) as! Data
                        
                        let similarity = FaceSDK.similarityCalculation(templates, templates2: personTemplates)
                        
                        if(maxSimilarity < similarity) {
                            maxSimilarity = similarity
                            maxSimilarityName = person.value(forKey: ViewController.ATTRIBUTE_NAME) as! String
                            maxSimilarityFace = person.value(forKey: ViewController.ATTRIBUTE_FACE) as? Data
                        }
                    }
                } catch {
                    print("Failed fetching: \(error)")
                }
                
                if(maxSimilarity > identifyThreshold) {
                    let enrolledFaceImage = UIImage(data: maxSimilarityFace!)
                    let identifiedFaceImage = capturedImage.cropFace(faceBox: faceBox)
                    
                    recognized = true
                    
                    DispatchQueue.main.sync {
                        self.enrolledImage.image = enrolledFaceImage
                        self.identifiedImage.image = identifiedFaceImage
                        self.identifiedLbl.text = "ID: " + maxSimilarityName
                        
                        self.identifiedStr = "Identified: " + maxSimilarityName
                        self.similarityStr = "Similarity: " + String(format: "%.03f", maxSimilarity)
                        self.livenessStr = "Liveness score: " + String(format: "%.03f", faceBox.liveness)
                        self.yawStr = "Yaw: " + String(format: "%.03f", faceBox.yaw)
                        self.rollStr = "Roll: " + String(format: "%.03f", faceBox.yaw)
                        self.pitchStr = "Pitch: " + String(format: "%.03f", faceBox.yaw)
                        
                        self.resultView.showView(isHidden_: true)
                        
                        self.session.stopRunning()
                    }
                }
            }
        }
    }
    
    @IBAction func done_clicked(_ sender: Any) {
        self.resultView.showView(isHidden_: false)
        recognized = false
        
        session.startRunning()
    }
    
}

extension UIView {
    
    func showView(isHidden_: Bool) {
        
        if isHidden_ {
            UIView.animate(withDuration: 0.3, animations: {
                self.alpha = 1.0
            }, completion: {_ in
                self.isHidden = false
            })
        } else {
            UIView.animate(withDuration: 0.3, animations: {
                self.alpha = 0.0
            }, completion: {_ in
                self.isHidden = true
            })
        }
    }
}

extension CameraViewController: BottomPopupDelegate {
    
    func bottomPopupViewLoaded() {
        print("bottomPopupViewLoaded")
    }
    
    func bottomPopupWillAppear() {
        print("bottomPopupWillAppear")
    }
    
    func bottomPopupDidAppear() {
        print("bottomPopupDidAppear")
    }
    
    func bottomPopupWillDismiss() {
        print("bottomPopupWillDismiss")
    }
    
    func bottomPopupDidDismiss() {
        print("bottomPopupDidDismiss")
    }
    
    func bottomPopupDismissInteractionPercentChanged(from oldValue: CGFloat, to newValue: CGFloat) {
        print("bottomPopupDismissInteractionPercentChanged fromValue: \(oldValue) to: \(newValue)")
    }
}
