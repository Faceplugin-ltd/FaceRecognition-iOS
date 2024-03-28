//
//  IdentifyDetailsVC.swift
//  UITestFace
//
//  Created by Dipankar Das on 22/3/24.
//

import Foundation
import UIKit

class IdentifyDetailsVC: BottomPopupViewController {
    var height: CGFloat?
    var topCornerRadius: CGFloat?
    var presentDuration: Double?
    var dismissDuration: Double?
    var shouldDismissInteractivelty: Bool?
    
    @IBOutlet weak var identifiedLbl: UILabel!
    @IBOutlet weak var similarityLbl: UILabel!
    @IBOutlet weak var livenessLbl: UILabel!
    @IBOutlet weak var yawLbl: UILabel!
    @IBOutlet weak var rollLbl: UILabel!
    @IBOutlet weak var pitchLbl: UILabel!
    
    var identifiedStr: String?
    var similarityStr: String?
    var livenessStr: String?
    var yawStr: String?
    var rollStr: String?
    var pitchStr: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.identifiedLbl.text = identifiedStr
        self.similarityLbl.text = similarityStr
        self.livenessLbl.text = livenessStr
        self.yawLbl.text = yawStr
        self.rollLbl.text = rollStr
        self.pitchLbl.text = pitchStr
        
    }
    
    
    // MARK: - BottomPopupAttributesDelegate Variables
    override var popupHeight: CGFloat { height ?? 280.0 }
    override var popupTopCornerRadius: CGFloat { topCornerRadius ?? 16.0 }
    override var popupPresentDuration: Double { presentDuration ?? 0.5 }
    override var popupDismissDuration: Double { dismissDuration ?? 0.5 }
    override var popupShouldDismissInteractivelty: Bool { shouldDismissInteractivelty ?? true }
    override var popupDimmingViewAlpha: CGFloat { BottomPopupConstants.dimmingViewDefaultAlphaValue }
}

