import UIKit
import AVFoundation
import CoreData

class CaptureViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate , CAAnimationDelegate{
   
    enum FACE_CAPTURE_STATE: Comparable {
        case NO_FACE,
        MULTIPLE_FACES,
        FIT_IN_CIRCLE,
        MOVE_CLOSER,
        NO_FRONT,
        FACE_OCCLUDED,
        EYE_CLOSED,
        MOUTH_OPENED,
        SPOOFED_FACE,
        CAPTURE_OK
    }
    
    enum VIEW_MODE {
        case MODE_NONE,
        NO_FACE_PAEPARE,
        REPEAT_NO_FACE_PREPARE,
        TO_FACE_CIRCLE,
        FACE_CIRCLE_TO_NO_FACE,
        FACE_CIRCLE,
        FACE_CAPTURE_PREPRARE,
        FACE_CAPTURE_DONE
    }

    
    @IBOutlet weak var cameraView: UIView!
    @IBOutlet weak var resultView: UIView!
    @IBOutlet weak var captureView: UIView!
    @IBOutlet weak var warningLbl: UILabel!
    
    @IBOutlet weak var livenessLbl: UILabel!
    @IBOutlet weak var qualityLbl: UILabel!
    @IBOutlet weak var luminanceLbl: UILabel!
    @IBOutlet weak var enrollBtnView: UIView!
    
    var cameraLens_val = 0
    var livenessThreshold = Float(0)
    var identifyThreshold = Float(0)

    let focusLayer = CAShapeLayer()
    let angleLayer = CAShapeLayer()
    let fillLayer = CAShapeLayer()

    var viewMode = VIEW_MODE.MODE_NONE
    var frameSize = CGSize(width: 1080, height: 1920)
    var capturedImage: UIImage? = nil
    var capturedFace: FaceBox? = nil

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
        
        cameraView.translatesAutoresizingMaskIntoConstraints = true
        cameraView.frame = view.bounds

        resultView.translatesAutoresizingMaskIntoConstraints = true
        resultView.frame = view.bounds

        captureView.translatesAutoresizingMaskIntoConstraints = true
        captureView.frame = view.bounds
        captureView.backgroundColor = UIColor.clear

        let defaults = UserDefaults.standard
        cameraLens_val = defaults.integer(forKey: "camera_lens")
        livenessThreshold = defaults.float(forKey: "liveness_threshold")
        identifyThreshold = defaults.float(forKey: "identify_threshold")

        startCamera()
        
        self.enrollBtnView.clipsToBounds = true
        self.enrollBtnView.layer.cornerRadius = 25
    }
    
    @IBAction func done_clicked(_ sender: Any) {
        if let vc = self.presentingViewController as? ViewController {
            self.dismiss(animated: true, completion: nil)
        }
    }

    @IBAction func enroll_touch_down(_ sender: Any) {
        UIView.animate(withDuration: 0.5) {
            self.enrollBtnView.backgroundColor = UIColor(named: "clr_main_button_bg2") // Change to desired color
        }
    }
    
    @IBAction func enroll_touch_up(_ sender: Any) {
        UIView.animate(withDuration: 0.5) {
            self.enrollBtnView.backgroundColor = UIColor(named: "clr_main_button_bg1") // Change to desired color
        }
    }
    
    @IBAction func enroll_clicked(_ sender: Any) {
        UIView.animate(withDuration: 0.5) {
            self.enrollBtnView.backgroundColor = UIColor(named: "AccentColor") // Change to desired color
        }
        
        let templates = FaceSDK.templateExtraction(capturedImage!, faceBox: capturedFace!)
        if(templates.isEmpty) {
            return
        }
        
        let faceImage = capturedImage!.cropFace(faceBox: self.capturedFace!)
        
        let context = self.persistentContainer.viewContext
        let entity = NSEntityDescription.entity(forEntityName: ViewController.ENTITIES_NAME, in: context)!
        let user = NSManagedObject(entity: entity, insertInto: context)

        let name = "Person" + String(Int.random(in: 10000...20000))
        let face = faceImage!.jpegData(compressionQuality: CGFloat(1.0))
        
        user.setValue(name, forKey: ViewController.ATTRIBUTE_NAME)
        user.setValue(templates, forKey: ViewController.ATTRIBUTE_TEMPLATES)
        user.setValue(face, forKey: ViewController.ATTRIBUTE_FACE)
        
        do {
            try context.save()
        } catch let error as NSError {
            print("Could not save. \(error), \(error.userInfo)")
        }
        
        if let vc = self.presentingViewController as? ViewController {
            self.dismiss(animated: true, completion: {
                vc.personView.reloadData()
            })
        }
    }

    func startCamera() {
        var cameraLens = AVCaptureDevice.Position.front
        if(cameraLens_val == 0) {
            cameraLens = AVCaptureDevice.Position.back
        }
        
        // Create an AVCaptureSession
        let session = AVCaptureSession()
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
        
        guard let pixelBuffer: CVPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags.readOnly)
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        
        let context = CIContext()
        let cgImage = context.createCGImage(ciImage, from: ciImage.extent)
        let image = UIImage(cgImage: cgImage!)
        CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags.readOnly)
        
        // Rotate and flip the image
        let capturedImage = image.rotate(radians: .pi/2).flipHorizontally()
        frameSize = capturedImage.size
        
        if(viewMode == VIEW_MODE.MODE_NONE) {
            DispatchQueue.main.sync {
                setViewMode(viewMode: VIEW_MODE.NO_FACE_PAEPARE)
            }
        }
        
        let param = FaceDetectionParam()
        param.check_mouth_opened = true
        param.check_eye_closeness = true
        param.check_face_occlusion = true
        
        let faceBoxes = FaceSDK.faceDetection(capturedImage, param: param)
        for faceBox in (faceBoxes as NSArray as! [FaceBox]) {
            if(cameraLens_val == 0) {
                let tmp = faceBox.x1
                faceBox.x1 = Int32(capturedImage.size.width) - faceBox.x2 - 1;
                faceBox.x2 = Int32(capturedImage.size.width) - tmp - 1;
            }
        }
        
        let faceCaptureState = CaptureViewController.checkFace(faceBoxes: faceBoxes, frameWidth: Int(capturedImage.size.width), frameHeight: Int(capturedImage.size.height))
        
        if(viewMode == VIEW_MODE.REPEAT_NO_FACE_PREPARE) {
            if(faceCaptureState > FACE_CAPTURE_STATE.NO_FACE) {
                DispatchQueue.main.sync {
                    setViewMode(viewMode: VIEW_MODE.TO_FACE_CIRCLE)
                }
            }
        } else if(viewMode == VIEW_MODE.FACE_CIRCLE) {
            DispatchQueue.main.sync {
                angleLayer.removeFromSuperlayer()
                if(faceBoxes != nil && faceBoxes.count > 0) {
                    let roiRect = getROIRectOnView(frameSize: frameSize)
                    let faceBox = faceBoxes[0] as! FaceBox
                    let yaw = faceBox.yaw
                    let pitch = faceBox.pitch
                    let anglePath = UIBezierPath()
                    anglePath.move(to: CGPoint(x: roiRect.midX, y: roiRect.minY))
                    anglePath.addQuadCurve(to: CGPoint(x: roiRect.midX, y: roiRect.maxY), controlPoint: CGPoint(x: roiRect.midX - roiRect.width * CGFloat(sin(yaw * .pi / 180)), y: roiRect.midY))
                    anglePath.addQuadCurve(to: CGPoint(x: roiRect.midX, y: roiRect.minY), controlPoint: CGPoint(x: roiRect.midX - roiRect.width * CGFloat(sin(yaw * .pi / 180)) / 3, y: roiRect.midY))

                    anglePath.move(to: CGPoint(x: roiRect.minX, y: roiRect.midY))
                    anglePath.addQuadCurve(to: CGPoint(x: roiRect.maxX, y: roiRect.midY), controlPoint: CGPoint(x: roiRect.midX, y: roiRect.midY + roiRect.width * CGFloat(sin(pitch * .pi / 180))))
                    anglePath.addQuadCurve(to: CGPoint(x: roiRect.minX, y: roiRect.midY), controlPoint: CGPoint(x: roiRect.midX, y: roiRect.midY + roiRect.width * CGFloat(sin(pitch * .pi / 180)) / 3))
                    
                    angleLayer.path = anglePath.cgPath
                    angleLayer.strokeColor = UIColor(named: "clr_roi_line")?.withAlphaComponent(0.5).cgColor
                    angleLayer.lineWidth = 0
                    angleLayer.fillColor = UIColor(named: "clr_roi_line")?.withAlphaComponent(0.5).cgColor
                    
                    captureView.layer.addSublayer(angleLayer)
                }
                
                if(faceCaptureState == FACE_CAPTURE_STATE.NO_FACE) {
                    warningLbl.text = ""
                    setViewMode(viewMode: VIEW_MODE.FACE_CIRCLE_TO_NO_FACE)
                } else if(faceCaptureState == FACE_CAPTURE_STATE.MULTIPLE_FACES) {
                    warningLbl.text = "Multiple face detected!"
                } else if(faceCaptureState == FACE_CAPTURE_STATE.FIT_IN_CIRCLE) {
                    warningLbl.text = "Fit in circle!"
                } else if(faceCaptureState == FACE_CAPTURE_STATE.MOVE_CLOSER) {
                    warningLbl.text = "Move closer!"
                } else if(faceCaptureState == FACE_CAPTURE_STATE.NO_FRONT) {
                    warningLbl.text = "Not fronted face!"
                } else if(faceCaptureState == FACE_CAPTURE_STATE.FACE_OCCLUDED) {
                    warningLbl.text = "Face occluded!"
                } else if(faceCaptureState == FACE_CAPTURE_STATE.EYE_CLOSED) {
                    warningLbl.text = "Eye closed!"
                } else if(faceCaptureState == FACE_CAPTURE_STATE.MOUTH_OPENED) {
                    warningLbl.text = "Mouth opened!"
                } else if(faceCaptureState == FACE_CAPTURE_STATE.SPOOFED_FACE) {
                    warningLbl.text = "Spoof face"
                } else {
                    warningLbl.text = ""
                    
                    setViewMode(viewMode: VIEW_MODE.FACE_CAPTURE_PREPRARE)
                }
            }
            
            if(faceCaptureState == FACE_CAPTURE_STATE.CAPTURE_OK) {
                self.capturedImage = capturedImage
                self.capturedFace = faceBoxes[0] as! FaceBox
            }
        } else if(viewMode == VIEW_MODE.FACE_CAPTURE_PREPRARE) {
            if(faceCaptureState == FACE_CAPTURE_STATE.CAPTURE_OK) {
                let faceBox = faceBoxes[0] as! FaceBox
                if(faceBox.face_quality > self.capturedFace!.face_quality) {
                    self.capturedImage = capturedImage
                    self.capturedFace = faceBox
                }
            }
        }
    }
       
    func setViewMode(viewMode: VIEW_MODE) {
        self.viewMode = viewMode
        
        if(self.viewMode == VIEW_MODE.NO_FACE_PAEPARE) {
            focusLayer.removeFromSuperlayer()
            focusLayer.removeAllAnimations()
            fillLayer.removeFromSuperlayer()
            fillLayer.removeAllAnimations()
            angleLayer.removeFromSuperlayer()

            let roiRect = getROIRectOnView(frameSize: frameSize)
            let roiFirstRect = roiRect.scale(scaleFactor: 1.4)
            let roiDistRect = roiRect.scale(scaleFactor: 0.88)
            
            let roiFirstPath = getROIPath(roiViewRect: roiFirstRect, roiMode: 0)
            let roiDistPath = getROIPath(roiViewRect: roiDistRect, roiMode: 0)
            
            focusLayer.path = roiFirstPath.cgPath
            focusLayer.strokeColor = UIColor(named: "clr_roi_line")?.cgColor
            focusLayer.lineWidth = 5
            focusLayer.fillColor = nil
            captureView.layer.addSublayer(focusLayer)
            
            let animation = CABasicAnimation(keyPath: "path")
            animation.duration = 0.4

            animation.toValue = roiDistPath.cgPath
            animation.fillMode = .forwards
            animation.isRemovedOnCompletion = false
            animation.delegate = self

            let opacity_animation = CABasicAnimation(keyPath: "opacity")
            opacity_animation.duration = 0.4

            opacity_animation.fromValue = 0
            opacity_animation.toValue = 1.0
            opacity_animation.isRemovedOnCompletion = false
            opacity_animation.fillMode = .forwards

            focusLayer.add(animation, forKey: "no_face_prepare")
            focusLayer.add(opacity_animation, forKey: "opacity")
        } else if (self.viewMode == VIEW_MODE.REPEAT_NO_FACE_PREPARE) {
            focusLayer.removeFromSuperlayer()
            focusLayer.removeAllAnimations()
            fillLayer.removeFromSuperlayer()
            fillLayer.removeAllAnimations()
            angleLayer.removeFromSuperlayer()

            let roiRect = getROIRectOnView(frameSize: frameSize)
            let roiFirstRect = roiRect.scale(scaleFactor: 0.88)
            let roiDistRect = roiRect.scale(scaleFactor: 0.92)
            
            let roiFirstPath = getROIPath(roiViewRect: roiFirstRect, roiMode: 0)
            let roiDistPath = getROIPath(roiViewRect: roiDistRect, roiMode: 0)
            
            focusLayer.path = roiFirstPath.cgPath
            focusLayer.strokeColor = UIColor(named: "clr_roi_line")?.cgColor
            focusLayer.lineWidth = 5
            focusLayer.fillColor = nil
            captureView.layer.addSublayer(focusLayer)
            
            let animation = CABasicAnimation(keyPath: "path")
            animation.duration = 1.1

            animation.toValue = roiDistPath.cgPath
            animation.repeatCount = .infinity
            animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            animation.autoreverses = true
            animation.isRemovedOnCompletion = false
            animation.delegate = self

            focusLayer.add(animation, forKey: "repeat_no_face_prepare")
        } else if(self.viewMode == VIEW_MODE.TO_FACE_CIRCLE) {
            focusLayer.removeFromSuperlayer()
            focusLayer.removeAllAnimations()
            fillLayer.removeFromSuperlayer()
            fillLayer.removeAllAnimations()
            angleLayer.removeFromSuperlayer()

            let roiRect = getROIRectOnView(frameSize: frameSize)
            let eclipse = CGPath(ellipseIn: roiRect, transform: nil)
            let semicircle = UIBezierPath(cgPath: eclipse)

            let path = UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: self.view.bounds.width, height: self.view.bounds.height), cornerRadius: 0)
            path.append(semicircle)
            path.usesEvenOddFillRule = true
                      
            
            fillLayer.frame = CGRect(x: 0, y: 0, width: self.view.bounds.width, height: self.view.bounds.height)
            fillLayer.path = path.cgPath
            fillLayer.fillRule = .evenOdd
            fillLayer.fillColor = UIColor.black.cgColor

            let opacity_animation = CABasicAnimation(keyPath: "opacity")
            opacity_animation.duration = 0.6

            opacity_animation.fromValue = 0
            opacity_animation.toValue = 1.0
            opacity_animation.fillMode = .forwards
            opacity_animation.isRemovedOnCompletion = false
            

            fillLayer.add(opacity_animation, forKey: "to_face_circle_opacity")
            captureView.layer.addSublayer(fillLayer)
            
            let roiFirstRect = roiRect.scale(scaleFactor: 1.0)
            let roiDistRect = roiRect.scale(scaleFactor: 1.0)
            
            let roiFirstPath = getROIPath(roiViewRect: roiFirstRect, roiMode: 0)
            let roiDistPath = getROIPath(roiViewRect: roiDistRect, roiMode: 1)
            
            focusLayer.path = roiFirstPath.cgPath
            focusLayer.strokeColor = UIColor(named: "clr_roi_line")?.cgColor
            focusLayer.lineWidth = 5
            focusLayer.fillColor = nil
            captureView.layer.addSublayer(focusLayer)
            
            let animation = CABasicAnimation(keyPath: "path")
            animation.duration = 0.6

            animation.toValue = roiDistPath.cgPath
            animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            animation.fillMode = .forwards
            animation.isRemovedOnCompletion = false
            animation.delegate = self

            focusLayer.add(animation, forKey: "to_face_circle")
        } else if(self.viewMode == VIEW_MODE.FACE_CIRCLE) {
            focusLayer.removeFromSuperlayer()
            focusLayer.removeAllAnimations()
            angleLayer.removeFromSuperlayer()

            let roiRect = getROIRectOnView(frameSize: frameSize)
            let roiFirstRect = roiRect.scale(scaleFactor: 1.0)
            let roiFirstPath = getROIPath(roiViewRect: roiFirstRect, roiMode: 2)

            focusLayer.path = roiFirstPath.cgPath
            focusLayer.strokeColor = UIColor(named: "clr_roi_line")?.cgColor
            focusLayer.lineWidth = 2
            focusLayer.fillColor = nil
            
            captureView.layer.addSublayer(focusLayer)
        } else if(self.viewMode == VIEW_MODE.FACE_CIRCLE_TO_NO_FACE) {
            focusLayer.removeFromSuperlayer()
            focusLayer.removeAllAnimations()
            fillLayer.removeFromSuperlayer()
            fillLayer.removeAllAnimations()
            angleLayer.removeFromSuperlayer()

            let roiRect = getROIRectOnView(frameSize: frameSize)
            let eclipse = CGPath(ellipseIn: roiRect, transform: nil)
            let semicircle = UIBezierPath(cgPath: eclipse)

            let path = UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: self.view.bounds.width, height: self.view.bounds.height), cornerRadius: 0)
            path.append(semicircle)
            path.usesEvenOddFillRule = true
                      
            
            fillLayer.frame = CGRect(x: 0, y: 0, width: self.view.bounds.width, height: self.view.bounds.height)
            fillLayer.path = path.cgPath
            fillLayer.fillRule = .evenOdd
            fillLayer.fillColor = UIColor.black.cgColor

            let opacity_animation = CABasicAnimation(keyPath: "opacity")
            opacity_animation.duration = 0.6

            opacity_animation.fromValue = 1.0
            opacity_animation.toValue = 0.0
            opacity_animation.fillMode = .forwards
            opacity_animation.isRemovedOnCompletion = false

            fillLayer.add(opacity_animation, forKey: "face_circle_to_no_face_opacity")
            captureView.layer.addSublayer(fillLayer)
            
            let roiFirstRect = roiRect.scale(scaleFactor: 1.0)
            let roiDistRect = roiRect.scale(scaleFactor: 1.0)
            
            let roiFirstPath = getROIPath(roiViewRect: roiFirstRect, roiMode: 1)
            let roiDistPath = getROIPath(roiViewRect: roiDistRect, roiMode: 0)
            
            focusLayer.path = roiFirstPath.cgPath
            focusLayer.strokeColor = UIColor(named: "clr_roi_line")?.cgColor
            focusLayer.lineWidth = 5
            focusLayer.fillColor = nil
            captureView.layer.addSublayer(focusLayer)
            
            let animation = CABasicAnimation(keyPath: "path")
            animation.duration = 0.6

            animation.toValue = roiDistPath.cgPath
            animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            animation.fillMode = .forwards
            animation.isRemovedOnCompletion = false
            animation.delegate = self

            focusLayer.add(animation, forKey: "face_circle_to_no_face")
        } else if(self.viewMode == VIEW_MODE.FACE_CAPTURE_PREPRARE) {
            focusLayer.removeFromSuperlayer()
            focusLayer.removeAllAnimations()
            fillLayer.removeFromSuperlayer()
            fillLayer.removeAllAnimations()
            angleLayer.removeFromSuperlayer()

            let roiRect = getROIRectOnView(frameSize: frameSize)
            let eclipse = CGPath(ellipseIn: roiRect, transform: nil)
            let semicircle = UIBezierPath(cgPath: eclipse)

            let path = UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: self.view.bounds.width, height: self.view.bounds.height), cornerRadius: 0)
            path.append(semicircle)
            path.usesEvenOddFillRule = true
                      
            
            fillLayer.frame = CGRect(x: 0, y: 0, width: self.view.bounds.width, height: self.view.bounds.height)
            fillLayer.path = path.cgPath
            fillLayer.fillRule = .evenOdd
            fillLayer.fillColor = UIColor.black.cgColor

            captureView.layer.addSublayer(fillLayer)
            
            let roiFirstRect = roiRect.scale(scaleFactor: 1.0)
            let roiDistRect = roiRect.scale(scaleFactor: 1.0)
            
            let roiFirstPath = UIBezierPath()
            let roiDistPath = UIBezierPath()
            
            roiFirstPath.append(semicircle)

            let eclipse1 = CGPath(ellipseIn: CGRect(x: roiRect.midX, y: roiRect.midY, width: 0, height: 0), transform: nil)
            let semicircle1 = UIBezierPath(cgPath: eclipse1)
            roiFirstPath.append(semicircle)
            roiFirstPath.usesEvenOddFillRule = true
            
            roiDistPath.append(semicircle)
            roiDistPath.append(semicircle1)
            roiDistPath.usesEvenOddFillRule = true

            focusLayer.path = roiFirstPath.cgPath
            focusLayer.fillColor = UIColor(named: "clr_roi_circle")?.cgColor
            focusLayer.fillRule = .evenOdd
            focusLayer.strokeColor = UIColor.clear.cgColor
            focusLayer.lineWidth = 1

            captureView.layer.addSublayer(focusLayer)
            
            let animation = CABasicAnimation(keyPath: "path")
            animation.duration = 0.5

            animation.fromValue = roiFirstPath.cgPath
            animation.toValue = roiDistPath.cgPath
            animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            animation.fillMode = .forwards
            animation.isRemovedOnCompletion = false
            animation.delegate = self

            focusLayer.add(animation, forKey: "face_capture_prepare")
        } else if(self.viewMode == VIEW_MODE.FACE_CAPTURE_DONE) {
            focusLayer.removeFromSuperlayer()
            focusLayer.removeAllAnimations()
            fillLayer.removeFromSuperlayer()
            fillLayer.removeAllAnimations()
            angleLayer.removeFromSuperlayer()

            let roiRect = getROIRectOnView(frameSize: frameSize).scale(scaleFactor: 0.8)
            let eclipse = CGPath(ellipseIn: roiRect, transform: nil)
            let semicircle = UIBezierPath(cgPath: eclipse)

            let path = UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: self.view.bounds.width, height: self.view.bounds.height), cornerRadius: 0)
            
            fillLayer.frame = CGRect(x: 0, y: 0, width: self.view.bounds.width, height: self.view.bounds.height)
            fillLayer.path = path.cgPath
            fillLayer.fillColor = UIColor.black.cgColor

            let capturedFaceView = UIImageView()
            capturedFaceView.frame = getROIRectOnView(frameSize: frameSize).scale(scaleFactor: 0.8)
            capturedFaceView.image = self.capturedImage!.crop(rect: CaptureViewController.getROIRect1(frameSize: frameSize))
            capturedFaceView.layer.cornerRadius = capturedFaceView.frame.width / 2
            capturedFaceView.clipsToBounds = true

            captureView.layer.addSublayer(fillLayer)
            captureView.addSubview(capturedFaceView)

            let roiFirstRect = roiRect
            let roiDistRect = roiRect
            
            let roiFirstPath = UIBezierPath()
            let roiDistPath = UIBezierPath()
            
            roiFirstPath.append(semicircle)

            focusLayer.path = roiFirstPath.cgPath
            focusLayer.fillColor = UIColor.clear.cgColor
            focusLayer.strokeColor = UIColor(named: "clr_roi_circle")?.cgColor
            focusLayer.lineWidth = 8

            captureView.layer.addSublayer(focusLayer)
            
            let move_offset = view.bounds.width / 5 - roiRect.minY

            let animation = CABasicAnimation(keyPath: "position")
            animation.duration = 0.5

            animation.fromValue = focusLayer.position
            animation.toValue = CGPoint(x: focusLayer.position.x, y: focusLayer.position.y + move_offset)
            animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            animation.fillMode = .forwards
            animation.isRemovedOnCompletion = false
            animation.delegate = self

            focusLayer.add(animation, forKey: "face_capture_done")

            let image_animation = CABasicAnimation(keyPath: "position")
            image_animation.duration = 0.5

            image_animation.fromValue = capturedFaceView.layer.position
            image_animation.toValue = CGPoint(x: capturedFaceView.layer.position.x, y: capturedFaceView.layer.position.y + move_offset)
            image_animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            image_animation.fillMode = .forwards
            image_animation.isRemovedOnCompletion = false
            capturedFaceView.layer.add(image_animation, forKey: nil)
        }
    }
    
    func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
        if flag {
            if focusLayer.animation(forKey: "no_face_prepare") == anim {
                setViewMode(viewMode: VIEW_MODE.REPEAT_NO_FACE_PREPARE)
            } else if focusLayer.animation(forKey: "to_face_circle") == anim {
                setViewMode(viewMode: VIEW_MODE.FACE_CIRCLE)
            } else if focusLayer.animation(forKey: "face_circle_to_no_face") == anim {
                setViewMode(viewMode: VIEW_MODE.NO_FACE_PAEPARE)
            } else if focusLayer.animation(forKey: "face_capture_prepare") == anim {
                setViewMode(viewMode: VIEW_MODE.FACE_CAPTURE_DONE)
            } else if focusLayer.animation(forKey: "face_capture_done") == anim {
                let param = FaceDetectionParam()
                param.check_liveness = true
                               
                let faceBoxes = FaceSDK.faceDetection(self.capturedImage!, param: param)
                if(faceBoxes != nil && faceBoxes.count > 0) {
                    let faceBox = faceBoxes[0] as! FaceBox
                    if(faceBox.liveness > livenessThreshold) {
                        let msg = String(format: "Liveness: Real, score = %.3f", faceBox.liveness)
                        livenessLbl.text = msg
                    } else {
                        let msg = String(format: "Liveness: Spoof, score = %.3f", faceBox.liveness)
                        livenessLbl.text = msg
                    }
                }
                
                if(capturedFace!.face_quality < 0.5) {
                    let msg = String(format: "Quality: Low, score = %.3f", capturedFace!.face_quality)
                    qualityLbl.text = msg
                } else if(capturedFace!.face_quality < 0.75) {
                    let msg = String(format: "Quality: Medium, score = %.3f", capturedFace!.face_quality)
                    qualityLbl.text = msg
                } else {
                    let msg = String(format: "Quality: High, score = %.3f", capturedFace!.face_quality)
                    qualityLbl.text = msg
                }
                
                let msg = String(format: "Luminance: %.3f", capturedFace!.face_luminance)
                luminanceLbl.text = msg
                
                self.resultView.isHidden = false
            }
        }
    }
    
    func getROIRectOnView(frameSize: CGSize) -> CGRect {
        let roiRect = CaptureViewController.getROIRect1(frameSize: frameSize)
        let ratioView = view.bounds.size.width / view.bounds.size.height
        let ratioFrame = frameSize.width / frameSize.height
        var roiViewRect = CGRect()
        
        if(ratioView < ratioFrame) {
            let dx = ((view.bounds.height * ratioFrame) - view.bounds.width) / 2
            let dy = CGFloat(0)
            let ratio = view.bounds.height / frameSize.height

            let x1 = roiRect.minX * ratio - dx
            let y1 = roiRect.minY * ratio - dy
            let x2 = roiRect.maxX * ratio -  dx
            let y2 = roiRect.maxY * ratio - dy

            roiViewRect = CGRect(x: Int(x1), y: Int(y1), width: Int(x2 - x1), height: Int(y2 - y1))
        } else {
            let dx = CGFloat(0)
            let dy = ((view.bounds.width / ratioFrame) - view.bounds.height) / 2
            let ratio = view.bounds.height / frameSize.height

            let x1 = roiRect.minX * ratio - dx
            let y1 = roiRect.minY * ratio - dy
            let x2 = roiRect.maxX * ratio -  dx
            let y2 = roiRect.maxY * ratio - dy

            roiViewRect = CGRect(x: Int(x1), y: Int(y1), width: Int(x2 - x1), height: Int(y2 - y1))
        }
        
        return roiViewRect
    }
    
    func getROIPath(roiViewRect: CGRect, roiMode: Int) -> UIBezierPath {
        
        var lineWidth = roiViewRect.width / 5
        var lineWidthOffset = CGFloat(0)
        var lineHeight = roiViewRect.height / 5
        var lineHeightOffset = CGFloat(0)
        var quad_r = roiViewRect.width / 12
        if(roiMode == 1) {
            lineWidth = 0
            lineHeight = 0
            lineWidthOffset = roiViewRect.width / 2
            lineHeightOffset = roiViewRect.height / 2
            quad_r = roiViewRect.width / 2
        }

        if(roiMode == 0 || roiMode == 1) {
            let path = UIBezierPath()
            path.move(to: CGPoint(x: roiViewRect.minX, y: roiViewRect.minY + lineHeight + lineHeightOffset))
            path.addLine(to: CGPoint(x: roiViewRect.minX, y: roiViewRect.minY + quad_r))
            path.addArc(withCenter: CGPoint(x: roiViewRect.minX + quad_r, y: roiViewRect.minY + quad_r), radius: quad_r, startAngle: CGFloat.pi, endAngle: CGFloat.pi + CGFloat.pi / 2, clockwise: true)
            path.addLine(to: CGPoint(x: roiViewRect.minX + lineWidth + lineWidthOffset, y: roiViewRect.minY))

            path.move(to: CGPoint(x: roiViewRect.maxX, y: roiViewRect.minY + lineHeight + lineHeightOffset))
            path.addLine(to: CGPoint(x: roiViewRect.maxX, y: roiViewRect.minY + quad_r))
            path.addArc(withCenter: CGPoint(x: roiViewRect.maxX - quad_r, y: roiViewRect.minY + quad_r), radius: quad_r, startAngle: 0, endAngle: CGFloat(-Double.pi/2), clockwise: false)
            path.addLine(to: CGPoint(x: roiViewRect.maxX - lineWidth - lineWidthOffset, y: roiViewRect.minY))

            path.move(to: CGPoint(x: roiViewRect.maxX, y: roiViewRect.maxY - lineHeight - lineHeightOffset))
            path.addLine(to: CGPoint(x: roiViewRect.maxX, y: roiViewRect.maxY - quad_r))
            path.addArc(withCenter: CGPoint(x: roiViewRect.maxX - quad_r, y: roiViewRect.maxY - quad_r), radius: quad_r, startAngle: 0, endAngle: CGFloat(Double.pi/2), clockwise: true)
            path.addLine(to: CGPoint(x: roiViewRect.maxX - lineWidth - lineWidthOffset, y: roiViewRect.maxY))

            path.move(to: CGPoint(x: roiViewRect.minX, y: roiViewRect.maxY - lineHeight - lineHeightOffset))
            path.addLine(to: CGPoint(x: roiViewRect.minX, y: roiViewRect.maxY - quad_r))
            path.addArc(withCenter: CGPoint(x: roiViewRect.minX + quad_r, y: roiViewRect.maxY - quad_r), radius: quad_r, startAngle: CGFloat.pi, endAngle: CGFloat.pi - CGFloat(Double.pi/2), clockwise: false)
            path.addLine(to: CGPoint(x: roiViewRect.minX + lineWidth + lineWidthOffset, y: roiViewRect.maxY))
            
            return path
        } else if(roiMode == 2) {
            let path = UIBezierPath()
            let centerX = Double(roiViewRect.midX)
            let centerY = Double(roiViewRect.midY)

            for i in stride(from: 0, to: 360, by: 5) {
                let r1 = roiViewRect.width / 2 + 5
                let r2 = roiViewRect.width / 2 + 20

                let th = Double(i) * Double.pi / 180
                var x1 = sin(CGFloat(th)) * r1
                var x2 = sin(CGFloat(th)) * r2
                var y1 = cos(CGFloat(th)) * r1
                var y2 = cos(CGFloat(th)) * r2
                
                path.move(to: CGPoint(x: centerX + x1, y: centerY - y1))
                path.addLine(to: CGPoint(x: centerX + x2, y: centerY - y2))
            }
            
            return path
        }
        
        return UIBezierPath()
    }
    
    
    static func checkFace(faceBoxes: NSMutableArray?, frameWidth: Int, frameHeight: Int) -> FACE_CAPTURE_STATE{
        
        if(faceBoxes == nil || faceBoxes?.count == 0) {
            return FACE_CAPTURE_STATE.NO_FACE
        }
        
        if(faceBoxes!.count > 1) {
            return FACE_CAPTURE_STATE.MULTIPLE_FACES
        }
        
        let faceBox = faceBoxes![0] as! FaceBox
        var faceLeft = Float.greatestFiniteMagnitude
        var faceRight = Float(0)
        var faceBottom = Float(0)
        
        let landmarkArray = faceBox.landmark.withUnsafeBytes{Array($0.bindMemory(to: Float.self))}
        for i in 0...67 {
            faceLeft = min(faceLeft, landmarkArray[i * 2])
            faceRight = max(faceRight, landmarkArray[i * 2])
            faceBottom = max(faceBottom, landmarkArray[i * 2 + 1])
        }
        
        let roiRect = CaptureViewController.getROIRect(frameSize: CGSize(width: Double(frameWidth), height: Double(frameHeight)))
        let sizeRate = Float(0.3)
        let interRate = Float(0.03)
        let centerY = Float(faceBox.y1 + faceBox.y2) / Float(2)
        let topY = centerY - Float(faceBox.y2 - faceBox.y1) * 2 / 3
        let interX = max(0, Float(roiRect.minX) - faceLeft) + max(0, faceRight - Float(roiRect.maxX))
        let interY = max(0, Float(roiRect.minY) - topY) + max(0, faceBottom - Float(roiRect.maxY))
        if((interX / Float(roiRect.width)) > interRate || (interY / Float(roiRect.height)) > interRate) {
            return FACE_CAPTURE_STATE.FIT_IN_CIRCLE
        }
        
        if(Float(faceBox.y2 - faceBox.y1) * Float(faceBox.y2 - faceBox.y1) < Float(roiRect.width) * Float(roiRect.height) * sizeRate) {
            return FACE_CAPTURE_STATE.MOVE_CLOSER
        }
        
        let defaults = UserDefaults.standard
        let yawThreshold = defaults.float(forKey: "yaw_threshold")
        let rollThreshold = defaults.float(forKey: "roll_threshold")
        let pitchThreshold = defaults.float(forKey: "pitch_threshold")
        let eyeCloseThreshold = defaults.float(forKey: "eyeclose_threshold")
        let occlusionThreshold = defaults.float(forKey: "occlusion_threshold")
        let mouthOpenThreshold = defaults.float(forKey: "mouthopen_threshold")
        
        if(abs(faceBox.yaw) > yawThreshold ||
           abs(faceBox.roll) > rollThreshold ||
           abs(faceBox.pitch) > pitchThreshold) {
            return FACE_CAPTURE_STATE.NO_FRONT
        }
        
        if(faceBox.face_occlusion > occlusionThreshold) {
            return FACE_CAPTURE_STATE.FACE_OCCLUDED
        }
        
        if(faceBox.left_eye > eyeCloseThreshold || faceBox.right_eye > eyeCloseThreshold) {
            return FACE_CAPTURE_STATE.EYE_CLOSED
        }
        
        if(faceBox.face_mouth_opened > mouthOpenThreshold) {
            return FACE_CAPTURE_STATE.MOUTH_OPENED
        }

        return FACE_CAPTURE_STATE.CAPTURE_OK
    }
    
    public static func getROIRect(frameSize: CGSize) -> CGRect {
        let margin = frameSize.width / 6
        let rectHeight = (frameSize.width - 2 * margin) * 6 / 5
        
        let roiRect = CGRect(x: margin, y: (frameSize.height - rectHeight) / 2, width: frameSize.width - 2 * margin, height: rectHeight)
        return roiRect
    }
    
    public static func getROIRect1(frameSize: CGSize) -> CGRect {
        let margin = frameSize.width / 6
        let rectHeight = (frameSize.width - 2 * margin)
        
        let roiRect = CGRect(x: margin, y: (frameSize.height - rectHeight) / 2, width: frameSize.width - 2 * margin, height: rectHeight)
        return roiRect
    }
}

extension CGRect {
    func scale(scaleFactor: CGFloat) -> CGRect {
        let center = CGPoint(x: midX, y: midY)
        var transform = CGAffineTransform.identity
        transform = transform.translatedBy(x: center.x, y: center.y)
        transform = transform.scaledBy(x: scaleFactor, y: scaleFactor)
        transform = transform.translatedBy(x: -center.x, y: -center.y)
        return applying(transform)
    }
}
