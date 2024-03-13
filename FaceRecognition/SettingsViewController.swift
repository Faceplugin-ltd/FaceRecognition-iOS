import UIKit
import AVFoundation
import CoreData

class SettingsViewController: UIViewController{
    
    static let CAMERA_LENS_DEFAULT = 1
    static let LIVENESS_THRESHOLD_DEFAULT = Float(0.7)
    static let IDENTIFY_THRESHOLD_DEFAULT = Float(0.8)
    static let YAW_THRESHOLD_DEFAULT = Float(10.0)
    static let ROLL_THRESHOLD_DEFAULT = Float(10.0)
    static let PITCH_THRESHOLD_DEFAULT = Float(10.0)
    static let OCCLUSION_THRESHOLD_DEFAULT = Float(0.5)
    static let EYECLOSE_THRESHOLD_DEFAULT = Float(0.8)
    static let MOUTHOPEN_THRESHOLD_DEFAULT = Float(0.5)
    
    
    @IBOutlet weak var cameraLensSwitch: UISwitch!
    @IBOutlet weak var livenessThresholdLbl: UILabel!
    @IBOutlet weak var identifyThresholdLbl: UILabel!
    @IBOutlet weak var yawThresholdLbl: UILabel!
    @IBOutlet weak var rollThresholdLbl: UILabel!
    @IBOutlet weak var pitchThresholdLbl: UILabel!
    @IBOutlet weak var occlusionThresholdLbl: UILabel!
    @IBOutlet weak var eyeClosureThresholdLbl: UILabel!
    @IBOutlet weak var mouthOpenThresholdLbl: UILabel!

    @IBOutlet weak var cameraLensLbl: UILabel!
    
    
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
        
        let defaults = UserDefaults.standard
        let cameraLens = defaults.integer(forKey: "camera_lens")

        if(cameraLens == 0) {
            cameraLensSwitch.isOn = false
            cameraLensLbl.text = "Back"
        } else {
            cameraLensSwitch.isOn = true
            cameraLensLbl.text = "Front"
        }
        
        let livenessThreshold = defaults.float(forKey: "liveness_threshold")
        livenessThresholdLbl.text = String(livenessThreshold)

        let identifyThreshold = defaults.float(forKey: "identify_threshold")
        identifyThresholdLbl.text = String(identifyThreshold)

        let yawThreshold = defaults.float(forKey: "yaw_threshold")
        yawThresholdLbl.text = String(yawThreshold)

        let rollThreshold = defaults.float(forKey: "roll_threshold")
        rollThresholdLbl.text = String(rollThreshold)

        let pitchThreshold = defaults.float(forKey: "pitch_threshold")
        pitchThresholdLbl.text = String(pitchThreshold)

        let eyeCloseThreshold = defaults.float(forKey: "eyeclose_threshold")
        eyeClosureThresholdLbl.text = String(eyeCloseThreshold)

        let mouthOpenThreshold = defaults.float(forKey: "mouthopen_threshold")
        mouthOpenThresholdLbl.text = String(mouthOpenThreshold)

        let occlusionThreshold = defaults.float(forKey: "occlusion_threshold")
        occlusionThresholdLbl.text = String(occlusionThreshold)
    }
    
    static func setDefaultSettings() {
        let defaults = UserDefaults.standard
        let defaultChanged = defaults.bool(forKey: "default_changed")
        if(defaultChanged == false) {
            defaults.set(true, forKey: "default_changed")
            
            defaults.set(SettingsViewController.CAMERA_LENS_DEFAULT, forKey: "camera_lens")
            defaults.set(SettingsViewController.LIVENESS_THRESHOLD_DEFAULT, forKey: "liveness_threshold")
            defaults.set(SettingsViewController.IDENTIFY_THRESHOLD_DEFAULT, forKey: "identify_threshold")
            defaults.set(SettingsViewController.YAW_THRESHOLD_DEFAULT, forKey: "yaw_threshold")
            defaults.set(SettingsViewController.ROLL_THRESHOLD_DEFAULT, forKey: "roll_threshold")
            defaults.set(SettingsViewController.PITCH_THRESHOLD_DEFAULT, forKey: "pitch_threshold")
            defaults.set(SettingsViewController.EYECLOSE_THRESHOLD_DEFAULT, forKey: "eyeclose_threshold")
            defaults.set(SettingsViewController.MOUTHOPEN_THRESHOLD_DEFAULT, forKey: "mouthopen_threshold")
            defaults.set(SettingsViewController.OCCLUSION_THRESHOLD_DEFAULT, forKey: "occlusion_threshold")
        }
    }
        
    @IBAction func done_clicked(_ sender: Any) {
        if let vc = self.presentingViewController as? ViewController {
            self.dismiss(animated: true, completion: {
                vc.personView.reloadData()
                let context = self.persistentContainer.viewContext
                let count = try! context.count(for: NSFetchRequest(entityName: ViewController.ENTITIES_NAME))
                if count == 0 {
                    vc.personView.isHidden = true
                }
            })
        }
    }
    
    @IBAction func cameraLens_switch(_ sender: Any) {
        let defaults = UserDefaults.standard
        if(cameraLensSwitch.isOn) {
            defaults.set(1, forKey: "camera_lens")
            cameraLensLbl.text = "Front"
        } else {
            defaults.set(0, forKey: "camera_lens")
            cameraLensLbl.text = "Back"
        }
    }
    
    func threshold_clicked(mode: Int) {
        var title = "Liveness threshold"
        if(mode == 1) {
            title = "Identify threshold"
        } else if(mode == 2) {
            title = "Occlusion threshold"
        } else if(mode == 3) {
            title = "Eye closure threshold"
        } else if(mode == 4) {
            title = "Mouth open threshold"
        }
        
        let alertController = UIAlertController(title: title, message: "Please input a number between 0 and 1.", preferredStyle: .alert)

        let minimum = Float(0)
        let maximum = Float(1)
        alertController.addTextField { (textField) in
            textField.keyboardType = .decimalPad
            
            let defaults = UserDefaults.standard
            
            if(mode == 0) {
                textField.text = String(defaults.float(forKey: "liveness_threshold"))
            } else if(mode == 1) {
                textField.text = String(defaults.float(forKey: "identify_threshold"))
            } else if(mode == 2) {
                textField.text = String(defaults.float(forKey: "occlusion_threshold"))
            } else if(mode == 3) {
                textField.text = String(defaults.float(forKey: "eyeclose_threshold"))
            } else if(mode == 4) {
                textField.text = String(defaults.float(forKey: "mouthopen_threshold"))
            }
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        
        let submitAction = UIAlertAction(title: "Ok", style: .default) { (action) in
            
            var hasError = false
            var errorStr = ""
            let defaults = UserDefaults.standard
            
            if let numberString = alertController.textFields?.first?.text, let number = Float(numberString) {
                if(number < Float(minimum) || number > Float(maximum)) {
                    hasError = true
                    errorStr = "Invalid value"
                } else {
                    
                    if(mode == 0) {
                        self.livenessThresholdLbl.text = String(number)
                        defaults.set(number, forKey: "liveness_threshold")
                    } else if(mode == 1) {
                        self.identifyThresholdLbl.text = String(number)
                        defaults.set(number, forKey: "identify_threshold")
                    } else if(mode == 2) {
                        self.occlusionThresholdLbl.text = String(number)
                        defaults.set(number, forKey: "occlusion_threshold")
                    } else if(mode == 3) {
                        self.eyeClosureThresholdLbl.text = String(number)
                        defaults.set(number, forKey: "eyeclose_threshold")
                    } else if(mode == 4) {
                        self.mouthOpenThresholdLbl.text = String(number)
                        defaults.set(number, forKey: "mouthopen_threshold")
                    }
                }
            } else {
                hasError = true
                errorStr = "Invalid value"
            }
            
            if(hasError) {
                let errorNotification = UIAlertController(title: "Error", message: errorStr, preferredStyle: .alert)
                let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
                errorNotification.addAction(okAction)
                self.present(errorNotification, animated: true, completion: nil)

                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    errorNotification.dismiss(animated: true, completion: nil)
                }
            }
        }
        
        alertController.addAction(cancelAction)
        alertController.addAction(submitAction)
        
        present(alertController, animated: true, completion: nil)
    }
    
    @IBAction func livenessThreshold_clicked(_ sender: Any) {
        threshold_clicked(mode: 0)
    }
    
    @IBAction func identifyThreshold_clicked(_ sender: Any) {
        
        threshold_clicked(mode: 1)
    }
    
    func angles_clicked(mode: Int) {
        var title = "Yaw threshold"
        if(mode == 1) {
            title = "Roll threshold"
        } else if(mode == 2) {
            title = "Pitch threshold"
        }
        
        let alertController = UIAlertController(title: title, message: "Please input a number between 0 and 30.", preferredStyle: .alert)

        let minimum = Float(0)
        let maximum = Float(30)
        alertController.addTextField { (textField) in
            textField.keyboardType = .decimalPad
            
            let defaults = UserDefaults.standard
            
            if(mode == 0) {
                textField.text = String(defaults.float(forKey: "yaw_threshold"))
            } else if(mode == 1) {
                textField.text = String(defaults.float(forKey: "roll_threshold"))
            }  else if(mode == 2) {
                textField.text = String(defaults.float(forKey: "pitch_threshold"))
            }
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        
        let submitAction = UIAlertAction(title: "Ok", style: .default) { (action) in
            
            var hasError = false
            var errorStr = ""
            let defaults = UserDefaults.standard
            
            if let numberString = alertController.textFields?.first?.text, let number = Float(numberString) {
                if(number < Float(minimum) || number > Float(maximum)) {
                    hasError = true
                    errorStr = "Invalid value"
                } else {
                    
                    if(mode == 0) {
                        self.yawThresholdLbl.text = String(number)
                        defaults.set(number, forKey: "yaw_threshold")
                    } else if(mode == 1) {
                        self.rollThresholdLbl.text = String(number)
                        defaults.set(number, forKey: "roll_threshold")
                    } else if(mode == 2) {
                        self.pitchThresholdLbl.text = String(number)
                        defaults.set(number, forKey: "pitch_threshold")
                    }
                }
            } else {
                hasError = true
                errorStr = "Invalid value"
            }
            
            if(hasError) {
                let errorNotification = UIAlertController(title: "Error", message: errorStr, preferredStyle: .alert)
                let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
                errorNotification.addAction(okAction)
                self.present(errorNotification, animated: true, completion: nil)

                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    errorNotification.dismiss(animated: true, completion: nil)
                }
            }
        }
        
        alertController.addAction(cancelAction)
        alertController.addAction(submitAction)
        
        present(alertController, animated: true, completion: nil)
    }
    
    @IBAction func yaw_clicked(_ sender: Any) {
        angles_clicked(mode: 0)
    }
    
    @IBAction func roll_clicked(_ sender: Any) {
        angles_clicked(mode: 1)
    }
    
    @IBAction func pitch_clicked(_ sender: Any) {
        angles_clicked(mode: 2)
    }
    
    @IBAction func occlusion_clicked(_ sender: Any) {
        threshold_clicked(mode: 2)
    }
    
    @IBAction func eye_close_clicked(_ sender: Any) {
        threshold_clicked(mode: 3)
    }
    
    @IBAction func mouth_open_clicked(_ sender: Any) {
        threshold_clicked(mode: 4)
    }
    
    
    @IBAction func restore_settings_clicked(_ sender: Any) {
        let defaults = UserDefaults.standard
        defaults.set(false, forKey: "default_changed")
        
        SettingsViewController.setDefaultSettings()
        showToast(message: "The default settings has been restored.")
        self.viewDidLoad()
    }
    
    
    @IBAction func clear_all_person_clicked(_ sender: Any) {
        
        let context = self.persistentContainer.viewContext
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: ViewController.ENTITIES_NAME)

        do {
            let persons = try context.fetch(fetchRequest) as! [NSManagedObject]
            for person in persons {
                context.delete(person)
            }
            try context.save()
        } catch {
            print("Failed fetching: \(error)")
        }
        
        showToast(message: "All personal data has been cleared.")
    }
}

