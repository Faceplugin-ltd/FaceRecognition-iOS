import UIKit
import AVFoundation

class AttributeViewController: UIViewController{
       
    
    @IBOutlet weak var faceView: UIImageView!
    
    @IBOutlet weak var livenessLbl: UILabel!
    @IBOutlet weak var qualityLbl: UILabel!
    @IBOutlet weak var luminanceLbl: UILabel!
    @IBOutlet weak var anglesLbl: UILabel!
    @IBOutlet weak var occlusionLbl: UILabel!
    @IBOutlet weak var eyeClosedLbl: UILabel!
    @IBOutlet weak var mouthOpenLbl: UILabel!
    @IBOutlet weak var ageLbl: UILabel!
    @IBOutlet weak var genderLbl: UILabel!
    
    var image: UIImage?
    var faceBox: FaceBox?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let defaults = UserDefaults.standard
        let livenessThreshold = defaults.float(forKey: "liveness_threshold")
        let occlusionThreshold = defaults.float(forKey: "occlusion_threshold")
        let eyeCloseThreshold = defaults.float(forKey: "eyeclose_threshold")
        let mouthOpenThreshold = defaults.float(forKey: "mouthopen_threshold")

        print("view load", faceBox, image, faceBox!.yaw)
        faceView.image = image!.cropFace(faceBox: faceBox!)
        
        if(faceBox!.liveness > livenessThreshold) {
            let msg = String(format: "Liveness: Real, score = %.3f", faceBox!.liveness)
            livenessLbl.text = msg
        } else {
            let msg = String(format: "Liveness: Spoof, score = %.3f", faceBox!.liveness)
            livenessLbl.text = msg
        }

        if(faceBox!.face_quality < 0.5) {
            let msg = String(format: "Quality: Low, score = %.3f", faceBox!.face_quality)
            qualityLbl.text = msg
        } else if(faceBox!.face_quality < 0.75) {
            let msg = String(format: "Quality: Medium, score = %.3f", faceBox!.face_quality)
            qualityLbl.text = msg
        } else {
            let msg = String(format: "Quality: High, score = %.3f", faceBox!.face_quality)
            qualityLbl.text = msg
        }
        
        var msg = String(format: "Luminance: %.3f", faceBox!.face_luminance)
        luminanceLbl.text = msg
        
        msg = String(format: "Angles: yaw = %.03f, roll = %.03f, pitch = %.03f", faceBox!.yaw, faceBox!.roll, faceBox!.pitch)
        anglesLbl.text = msg

        if(faceBox!.face_occlusion > occlusionThreshold) {
            msg = String(format: "Face occluded: score = %.03f", faceBox!.face_occlusion)
            occlusionLbl.text = msg
        } else {
            msg = String(format: "Face not occluded: score = %.03f", faceBox!.face_occlusion)
            occlusionLbl.text = msg
        }
        
        msg = String(format: "Left eye closed: %@, %.03f, Right eye closed: %@, %.03f", (faceBox!.left_eye > eyeCloseThreshold) ? "true" : "false",
                     faceBox!.left_eye, (faceBox!.left_eye > eyeCloseThreshold) ? "true" : "false", faceBox!.right_eye)

        eyeClosedLbl.text = msg
        
        msg = String(format: "Mouth opened: %@, %.03f", (faceBox!.face_mouth_opened > mouthOpenThreshold) ? "true" : "false", faceBox!.face_mouth_opened)
        mouthOpenLbl.text = msg

        msg = String(format: "Age: %d", faceBox!.age)
        ageLbl.text = msg
        
        if(faceBox!.gender == 0) {
            genderLbl.text = "Gender: Male"
        } else {
            genderLbl.text = "Gender: Female"
        }
    }
    
    @IBAction func done_clicked(_ sender: Any) {
        if let vc = self.presentingViewController as? ViewController {
            self.dismiss(animated: true, completion: nil)
        }
    }
}

