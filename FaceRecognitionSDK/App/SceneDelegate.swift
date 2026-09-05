import UIKit
import FaceRecognitionKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        window.backgroundColor = FPColor.bg
        let nav = UINavigationController(rootViewController: ViewController())
        nav.view.backgroundColor = FPColor.bg
        window.rootViewController = nav
        window.tintColor = FPColor.accent
        window.makeKeyAndVisible()
        self.window = window
    }
}

/// Android Material3 dark + FaceRecognition demo palette (`colors.xml`).
enum FPColor {
    static let bg = UIColor(red: 0.188, green: 0.188, blue: 0.200, alpha: 1)           // #303033 black_bg
    static let text = UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1)                 // onPrimary tiles
    static let muted = UIColor(red: 0.576, green: 0.561, blue: 0.600, alpha: 1)          // md_theme_dark_outline
    static let accent = UIColor(red: 0.816, green: 0.737, blue: 1.0, alpha: 1)           // md_theme_dark_onPrimaryContainer
    static let purple = UIColor(red: 0.388, green: 0.192, blue: 0.482, alpha: 1)         // #63317B pink_700
    static let pinkTouch = UIColor(red: 0.749, green: 0.255, blue: 0.890, alpha: 1)     // #BF41E3
    static let surfaceAlt = UIColor(red: 0.145, green: 0.145, blue: 0.145, alpha: 1)     // #252525 background1
    static let statusOk = UIColor(red: 0.220, green: 0.557, blue: 0.235, alpha: 1)
    static let statusError = UIColor(red: 0.827, green: 0.184, blue: 0.184, alpha: 1)  // md_theme_light_error #B3261E
    static let overlay = UIColor(red: 0.110, green: 0.106, blue: 0.122, alpha: 0.80)
    static let captureScrimStart = UIColor(red: 0.110, green: 0.106, blue: 0.122, alpha: 1)
    static let captureScrimEnd = UIColor.black
    static let captureTertiary = UIColor(red: 0.937, green: 0.722, blue: 0.784, alpha: 1) // md_theme_dark_onTertiary
    static let livenessReal = UIColor.systemGreen
    static let livenessSpoof = UIColor.systemRed
    static let livenessNeutral = UIColor.white
}

/// Shared nav bar so every pushed screen shows a labeled Back control.
enum ScreenChrome {
    static func showInnerBar(on viewController: UIViewController) {
        guard let navigationController = viewController.navigationController else { return }
        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.backgroundColor = FPColor.bg
        appearance.shadowColor = .clear
        appearance.titleTextAttributes = [.foregroundColor: FPColor.text]
        let button = UIBarButtonItemAppearance()
        button.normal.titleTextAttributes = [.foregroundColor: FPColor.accent]
        appearance.buttonAppearance = button
        appearance.backButtonAppearance = button
        navigationController.navigationBar.standardAppearance = appearance
        navigationController.navigationBar.scrollEdgeAppearance = appearance
        navigationController.navigationBar.compactAppearance = appearance
        navigationController.navigationBar.tintColor = FPColor.accent
        navigationController.navigationBar.barStyle = .black
        viewController.navigationItem.largeTitleDisplayMode = .never
        navigationController.setNavigationBarHidden(false, animated: false)
    }
}
