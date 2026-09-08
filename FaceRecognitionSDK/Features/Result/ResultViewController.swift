import UIKit
import FaceRecognitionKit

/// Android `ResultActivity`.
final class ResultViewController: UIViewController {
    private let identifiedFace: UIImage?
    private let enrolledFace: UIImage?
    private let name: String
    private let similarity: Float
    private let face: DetectedFace
    private let cropLandmarks: [CGPoint]

    init(
        identifiedFace: UIImage?,
        enrolledFace: UIImage?,
        name: String,
        similarity: Float,
        face: DetectedFace,
        cropLandmarks: [CGPoint]
    ) {
        self.identifiedFace = identifiedFace
        self.enrolledFace = enrolledFace
        self.name = name
        self.similarity = similarity
        self.face = face
        self.cropLandmarks = cropLandmarks
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = FPColor.bg
        title = "Identify Result"
        ScreenChrome.showInnerBar(on: self)

        let identifiedView = LandmarkImageView()
        identifiedView.setContent(identifiedFace, landmarks: cropLandmarks)
        let identifiedCaption = captionLabel("Identified")

        let enrolledView = UIImageView()
        enrolledView.image = enrolledFace
        enrolledView.contentMode = .scaleAspectFill
        enrolledView.clipsToBounds = true
        enrolledView.layer.cornerRadius = 12
        enrolledView.backgroundColor = FPColor.surfaceAlt
        let enrolledCaption = captionLabel("Enrolled")

        let personLabel = UILabel()
        personLabel.text = "Id: \(name)"
        personLabel.textColor = FPColor.text
        personLabel.font = .systemFont(ofSize: 14)
        personLabel.textAlignment = .center

        let identifiedCol = UIStackView(arrangedSubviews: [identifiedView, identifiedCaption])
        identifiedCol.axis = .vertical
        identifiedCol.alignment = .center
        identifiedCol.spacing = 5

        let enrolledCol = UIStackView(arrangedSubviews: [enrolledView, enrolledCaption, personLabel])
        enrolledCol.axis = .vertical
        enrolledCol.alignment = .center
        enrolledCol.spacing = 5

        identifiedView.widthAnchor.constraint(equalToConstant: 140).isActive = true
        identifiedView.heightAnchor.constraint(equalToConstant: 140).isActive = true
        enrolledView.widthAnchor.constraint(equalToConstant: 140).isActive = true
        enrolledView.heightAnchor.constraint(equalToConstant: 140).isActive = true

        let photos = UIStackView(arrangedSubviews: [identifiedCol, enrolledCol])
        photos.axis = .horizontal
        photos.spacing = 16
        photos.distribution = .fillEqually
        photos.translatesAutoresizingMaskIntoConstraints = false

        let similarityLabel = UILabel()
        similarityLabel.text = "Similarity: \(similarity)"
        similarityLabel.textColor = FPColor.text
        similarityLabel.font = .systemFont(ofSize: 18)
        similarityLabel.textAlignment = .center

        let details = UIStackView()
        details.axis = .vertical
        details.spacing = 4
        details.translatesAutoresizingMaskIntoConstraints = false
        ResultDetails.bind(
            container: details,
            rows: ResultDetails.rows(for: face, includeMatch: false, name: nil, similarity: nil)
        )

        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        let col = UIStackView(arrangedSubviews: [photos, similarityLabel, details])
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

    private func captionLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.textColor = FPColor.text
        label.font = .systemFont(ofSize: 14)
        label.textAlignment = .center
        return label
    }
}
