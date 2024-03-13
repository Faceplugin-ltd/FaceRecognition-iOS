import UIKit
import AVFoundation

class AboutViewController: UIViewController{
       
    @IBOutlet weak var ContactUsBtn: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.ContactUsBtn.clipsToBounds = true
        self.ContactUsBtn.layer.cornerRadius = 25
    }
    
    /*@IBAction func testBtn_clicked(_ sender: UIButton) {
        if sender.isSelected{
            sender.isSelected = false
            print("Front")
        } else {
            sender.isSelected = true
            print("Back")
        }
    }*/
    
    @IBAction func contactUs_clicked(_ sender: Any) {
        guard let popupNavController = storyboard?.instantiateViewController(withIdentifier: "ContactUsVC") as? ContactUsVC else { return }
        present(popupNavController, animated: true, completion: nil)
    }
    
    @IBAction func done_clicked(_ sender: Any) {
        if let vc = self.presentingViewController as? ViewController {
            self.dismiss(animated: true, completion: nil)
        }
    }
}

extension AboutViewController: BottomPopupDelegate {
    
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


