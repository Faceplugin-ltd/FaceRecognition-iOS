import UIKit
import FaceRecognitionKit

/// Android `AttributeActivity`.
final class AttributeViewController: UIViewController {
    private let faceImage: UIImage
    private let face: DetectedFace
    private let cropLandmarks: [CGPoint]

    init(faceImage: UIImage, face: DetectedFace, cropLandmarks: [CGPoint]) {
        self.faceImage = faceImage
        self.face = face
        self.cropLandmarks = cropLandmarks
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = FPColor.bg
        title = "Attribute Result"
        ScreenChrome.showInnerBar(on: self)

        let titleLabel = UILabel()
        titleLabel.text = "Face attributes"
        titleLabel.textColor = FPColor.accent
        titleLabel.font = .systemFont(ofSize: 18, weight: .bold)

        let imageCard = LandmarkImageView()
        imageCard.setContent(faceImage, landmarks: cropLandmarks)
        imageCard.heightAnchor.constraint(equalToConstant: 240).isActive = true

        let details = UIStackView()
        details.axis = .vertical
        details.spacing = 4
        ResultDetails.bind(
            container: details,
            rows: ResultDetails.rows(for: face, includeMatch: false, name: nil, similarity: nil)
        )

        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        let col = UIStackView(arrangedSubviews: [titleLabel, imageCard, details])
        col.axis = .vertical
        col.spacing = 16
        col.translatesAutoresizingMaskIntoConstraints = false
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
            col.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -24),
            col.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -32),
        ])
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        ScreenChrome.showInnerBar(on: self)
    }
}
