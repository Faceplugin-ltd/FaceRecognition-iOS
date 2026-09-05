import UIKit

/// Android `AboutActivity` — logo, company, two body cards, site, copyright.
final class AboutViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = FPColor.bg
        title = "About"
        ScreenChrome.showInnerBar(on: self)

        let logo = UIImageView(image: UIImage(named: "FacePluginLogo")?.withRenderingMode(.alwaysOriginal))
        logo.contentMode = .scaleAspectFit
        logo.isUserInteractionEnabled = true
        logo.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(openSite)))
        logo.translatesAutoresizingMaskIntoConstraints = false
        logo.heightAnchor.constraint(equalToConstant: 120).isActive = true
        logo.widthAnchor.constraint(equalToConstant: 120).isActive = true

        let company = UILabel()
        company.text = "FacePlugin"
        company.textColor = FPColor.text
        company.font = .systemFont(ofSize: 22, weight: .bold)
        company.textAlignment = .center

        let product = UILabel()
        product.text = "Face Recognition SDK"
        product.textColor = FPColor.accent
        product.font = .systemFont(ofSize: 15)
        product.textAlignment = .center

        let companyBody = cardLabel(
            "FacePlugin builds on-device identity technology — face recognition, liveness, and document reading — so biometric data never has to leave the phone."
        )
        let productBody = cardLabel(
            "This app demos the Face Recognition SDK for iOS: enroll, identify, capture, and attribute analysis. Everything runs fully on-premise."
        )

        let website = UIButton(type: .system)
        website.setTitle("faceplugin.com", for: .normal)
        website.setTitleColor(FPColor.accent, for: .normal)
        website.titleLabel?.font = .systemFont(ofSize: 14)
        website.addTarget(self, action: #selector(openSite), for: .touchUpInside)

        let copyright = UILabel()
        copyright.text = "© 2026 FacePlugin. All rights reserved."
        copyright.textColor = FPColor.muted
        copyright.font = .systemFont(ofSize: 12)
        copyright.textAlignment = .center

        let logoWrap = UIView()
        logo.translatesAutoresizingMaskIntoConstraints = false
        logoWrap.addSubview(logo)
        NSLayoutConstraint.activate([
            logo.topAnchor.constraint(equalTo: logoWrap.topAnchor, constant: 24),
            logo.centerXAnchor.constraint(equalTo: logoWrap.centerXAnchor),
            logo.bottomAnchor.constraint(equalTo: logoWrap.bottomAnchor),
        ])

        let col = UIStackView(arrangedSubviews: [
            logoWrap, company, product, companyBody, productBody, website, copyright,
        ])
        col.axis = .vertical
        col.spacing = 16
        col.setCustomSpacing(4, after: company)
        col.setCustomSpacing(24, after: product)
        col.setCustomSpacing(20, after: productBody)
        col.setCustomSpacing(24, after: website)
        col.translatesAutoresizingMaskIntoConstraints = false

        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(col)
        view.addSubview(scroll)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            col.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 16),
            col.leadingAnchor.constraint(equalTo: scroll.frameLayoutGuide.leadingAnchor, constant: 16),
            col.trailingAnchor.constraint(equalTo: scroll.frameLayoutGuide.trailingAnchor, constant: -16),
            col.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -16),
            col.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -32),
        ])
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        ScreenChrome.showInnerBar(on: self)
    }

    private func cardLabel(_ text: String) -> UIView {
        let label = UILabel()
        label.text = text
        label.textColor = FPColor.text
        label.font = .systemFont(ofSize: 14)
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false

        let pad = UIView()
        pad.backgroundColor = FPColor.surfaceAlt
        pad.layer.cornerRadius = 12
        pad.clipsToBounds = true
        pad.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: pad.topAnchor, constant: 16),
            label.leadingAnchor.constraint(equalTo: pad.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: pad.trailingAnchor, constant: -16),
            label.bottomAnchor.constraint(equalTo: pad.bottomAnchor, constant: -16),
        ])
        return pad
    }

    @objc private func openSite() {
        guard let url = URL(string: "https://faceplugin.com") else { return }
        UIApplication.shared.open(url)
    }
}
