//
//  ContactUsVC.swift
//  FaceRecognitionUITest
//
//  Created by Dipankar Das on 9/3/24.
//

import Foundation
import UIKit

class ContactUsVC: BottomPopupViewController {
    var height: CGFloat?
    var topCornerRadius: CGFloat?
    var presentDuration: Double?
    var dismissDuration: Double?
    var shouldDismissInteractivelty: Bool?
    
    @IBAction func mail_clicked(_ sender: Any) {
        let appURL = URL(string: "mailto:info@faceplugin.com") // URL scheme for Mail app
        
        if let appURL = appURL, UIApplication.shared.canOpenURL(appURL) {
            // If Mail app is installed, open it with a pre-filled email
            UIApplication.shared.open(appURL, options: [:], completionHandler: nil)
        } else {
            // If Mail app is not installed, show an alert indicating that Mail app is not available
            let alert = UIAlertController(title: "Mail App Not Available", message: "The Mail app is not installed on this device.", preferredStyle: .alert)
            let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
            alert.addAction(okAction)
            UIApplication.shared.keyWindow?.rootViewController?.present(alert, animated: true, completion: nil)
        }
    }
    
    
    @IBAction func skype_clicked(_ sender: Any) {

    }
    
    @IBAction func telegram_clicked(_ sender: Any) {
        /*let appURL = URL(string: "tg://resolve?domain=faceplugin") // URL scheme for Telegram app
            
            if let appURL = appURL, UIApplication.shared.canOpenURL(appURL) {
                // If Telegram app is installed, open it to the "Add Contact" screen
                UIApplication.shared.open(appURL, options: [:], completionHandler: nil)
            } else {
                let username = "faceplugin"
                let telegramURL = URL(string: "https://t.me/\(username)")!
                UIApplication.shared.open(telegramURL, options: [:], completionHandler: nil)
            }*/
    }
    
    @IBAction func whatsapp_clicked(_ sender: Any) {
       /* let appURL = URL(string: "whatsapp://send?phone=+14422295661") // URL scheme for Telegram app
            
            if let appURL = appURL, UIApplication.shared.canOpenURL(appURL) {
                // If Telegram app is installed, open it to the "Add Contact" screen
                UIApplication.shared.open(appURL, options: [:], completionHandler: nil)
            } else {
                let username = "+14422295661"
                let telegramURL = URL(string: "https://wa.me/\(username)")!
                UIApplication.shared.open(telegramURL, options: [:], completionHandler: nil)
            }*/
    }
    
    @IBAction func github_clicked(_ sender: Any) {
        let telegramURL = URL(string: "https://github.com/Faceplugin-ltd")!
        UIApplication.shared.open(telegramURL, options: [:], completionHandler: nil)
    }
    
    // MARK: - BottomPopupAttributesDelegate Variables
    override var popupHeight: CGFloat { height ?? 280.0 }
    override var popupTopCornerRadius: CGFloat { topCornerRadius ?? 16.0 }
    override var popupPresentDuration: Double { presentDuration ?? 0.5 }
    override var popupDismissDuration: Double { dismissDuration ?? 0.5 }
    override var popupShouldDismissInteractivelty: Bool { shouldDismissInteractivelty ?? true }
    override var popupDimmingViewAlpha: CGFloat { BottomPopupConstants.dimmingViewDefaultAlphaValue }
}
