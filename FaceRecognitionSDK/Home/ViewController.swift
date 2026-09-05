import UIKit
import FaceRecognitionKit

/// Android `MainActivity` — six tiles + enrolled people list + SDK status overlay.
final class ViewController: UIViewController {
    private enum GalleryRequest { case enroll, attribute }

    /// `FP1.…` from FacePlugin for bundle id `com.faceplugin.facerecognitionsdk`.
    private let licenseKey =
        "FP1.RlBMMQMAAQAPZoIUMnHWbZlL37gIAgAAiwzjjvfWBtUpvi7HaaTdfTrWZ3SyD4S949NuAmIeafdSruIt8Px7395zNLVjVa/aT8kpgeKHkUTBHXMxzDfTO3b72UxOx45PoVeJzpPUb74M4suMNcan7jDn4fpIlHA/7KSDKO4X4fPU7DC/hhvdlbWKJ3WCvRoNNP9LsR+PlkCHsMHuaTbtqGB+7LqM9UbE/BMSBArJ79dDXV/fg52WAZ3WRQ74wZeEuCoR/L2hv+blZ2ulYjl5w1DegJt4lxzTGdjdSN07AaiJ6GuilXcoald/F8eTzCRlFyLbF44dAOfLbEKAcWxIWRnV3pPP6eljlHnRCHQ95dOfZvzU1aJQF2a52buBK+L9yaDVEixjHrBHf03toU1WJ9WOqhSJW1yzbzTimNpcHQWptaB7LBVe5B5Ji1LluU7/UL4WamkcEoPIbwNg2pLgJtTOXYF1hZPA+l2U41ncSMTIsiENlMxUnpc3I2upTbw57EDWrBQO6lSXXbqh/vxHsD3LPcjgxfkXir+okr5MfkWd6iQopT4zAAJ4jV02uRWNNONX5dMGmKIXlgB6fYGNgitDfgj6Sk07tiFqLPQldLviKLZQrZJNfiBZLsNy1/8t/eXZ55L6rhJ31UY8vsQ+48KJuqb5FTcZ4p0DGlKWrpkBAi95pkOu0M3ZZMg0j65GPGU9RtKIjWqiZhjR87tzSIoAMIGHAkIA2w3qAKi99nTgIqZ0kLP1MtY2wK/w6ERXFk2KswYQVHSWIwlZd8ZVbfFt9cnV3hmY44YH6evpb8O19WpoqlKN2dQCQTbcYtr7WoqfL1DUAZlEMbGDp6qqQuVVx3jjW+9Dac/csw+GkNyy4fREMGBJSbPfqLJSnu9yTPaF8GoOqvKpwl7s"

    private let titleLabel = UILabel()
    private let warningLabel = UILabel()
    private let enrolledHeader = UILabel()
    private let tableView = UITableView(frame: .zero, style: .plain)
    private var people: [EnrolledPerson] = []
    private var sdkReady = false
    private var sdkLoading = false
    private var pendingGalleryRequest: GalleryRequest?
    private var sdkActionButtons: [UIButton] = []
    private var rowHeightConstraints: [NSLayoutConstraint] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        AppSettings.applyEngineDefaults()
        view.backgroundColor = FPColor.bg
        navigationItem.backBarButtonItem = UIBarButtonItem(title: "Back", style: .plain, target: nil, action: nil)
        navigationController?.setNavigationBarHidden(true, animated: false)
        setupUI()
        activateSDK()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        if sdkReady { refreshPeople() }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let height = Self.tileRowHeight(for: view.bounds.size)
        for constraint in rowHeightConstraints where constraint.constant != height {
            constraint.constant = height
        }
    }

    private func setupUI() {
        titleLabel.text = "Face Recognition"
        titleLabel.textColor = FPColor.text
        titleLabel.font = .systemFont(ofSize: 34, weight: .regular)
        titleLabel.textAlignment = .center

        let sdkTiles = [
            ("ENROLL", "enroll", #selector(openEnroll)),
            ("IDENTIFY", "identify", #selector(openIdentify)),
            ("CAPTURE", "capture", #selector(openCapture)),
            ("ATTRIBUTE", "attributr", #selector(openAttribute)),
        ]
        let otherTiles = [
            ("SETTINGS", "settings", #selector(openSettings)),
            ("ABOUT", "information", #selector(openAbout)),
        ]
        let sdkButtons = sdkTiles.map { makeTile(title: $0.0, assetName: $0.1, action: $0.2) }
        sdkActionButtons = sdkButtons
        let row1 = tileRow(Array(sdkButtons.prefix(3)))
        let row2 = tileRow([sdkButtons[3]] + otherTiles.map { makeTile(title: $0.0, assetName: $0.1, action: $0.2) })
        setSdkActionsEnabled(false)

        enrolledHeader.text = "Enrolled Face"
        enrolledHeader.textColor = FPColor.text
        enrolledHeader.font = .systemFont(ofSize: 20, weight: .semibold)
        enrolledHeader.isHidden = true

        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(PersonCell.self, forCellReuseIdentifier: PersonCell.reuseId)
        tableView.rowHeight = 80

        warningLabel.text = "Loading native SDK…"
        warningLabel.textColor = .white
        warningLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        warningLabel.textAlignment = .center
        warningLabel.backgroundColor = FPColor.statusError
        warningLabel.layer.cornerRadius = 8
        warningLabel.clipsToBounds = true
        warningLabel.numberOfLines = 2

        let brandButton = UIButton(type: .system)
        brandButton.setTitle("faceplugin.com", for: .normal)
        brandButton.setTitleColor(FPColor.muted, for: .normal)
        brandButton.titleLabel?.font = .systemFont(ofSize: 14)
        brandButton.addTarget(self, action: #selector(openBrand), for: .touchUpInside)
        brandButton.translatesAutoresizingMaskIntoConstraints = false

        let stack = UIStackView(arrangedSubviews: [titleLabel, row1, row2, enrolledHeader, tableView])
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        warningLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        view.addSubview(warningLabel)
        view.addSubview(brandButton)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: brandButton.topAnchor, constant: -8),
            warningLabel.centerXAnchor.constraint(equalTo: tableView.centerXAnchor),
            warningLabel.centerYAnchor.constraint(equalTo: tableView.centerYAnchor),
            warningLabel.leadingAnchor.constraint(equalTo: tableView.leadingAnchor),
            warningLabel.trailingAnchor.constraint(equalTo: tableView.trailingAnchor),
            warningLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 40),
            brandButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            brandButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8),
        ])
        let rowH = Self.tileRowHeight(for: UIScreen.main.bounds.size)
        rowHeightConstraints = [
            row1.heightAnchor.constraint(equalToConstant: rowH),
            row2.heightAnchor.constraint(equalToConstant: rowH),
        ]
        NSLayoutConstraint.activate(rowHeightConstraints)
    }

    /// Tile row tracks screen width/height so icons can scale with the buttons.
    private static func tileRowHeight(for size: CGSize) -> CGFloat {
        let width = max(size.width, 320)
        let height = max(size.height, 480)
        let tileWidth = (width - 64) / 3
        return min(tileWidth * 1.12, max(108, min(168, height * 0.15))).rounded()
    }

    private func tileRow(_ tiles: [UIView]) -> UIStackView {
        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = 16
        row.distribution = .fillEqually
        for tile in tiles {
            row.addArrangedSubview(tile)
        }
        return row
    }

    private func makeTile(title: String, assetName: String, action: Selector) -> UIButton {
        let button = HomeTileButton(title: title, assetName: assetName)
        button.addTarget(self, action: action, for: .touchUpInside)
        button.addTarget(self, action: #selector(tileTouchDown(_:)), for: .touchDown)
        button.addTarget(self, action: #selector(tileTouchUp(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        return button
    }

    @objc private func tileTouchDown(_ sender: UIButton) {
        sender.backgroundColor = FPColor.pinkTouch
    }

    @objc private func tileTouchUp(_ sender: UIButton) {
        sender.backgroundColor = FPColor.purple
    }

    @objc private func openBrand() {
        guard let url = URL(string: "https://faceplugin.com") else { return }
        UIApplication.shared.open(url)
    }

    private func activateSDK() {
        sdkLoading = true
        setSdkActionsEnabled(false)
        warningLabel.isHidden = false
        warningLabel.text = "Loading native SDK…"
        FaceRecognitionClient.shared.activate(license: licenseKey) { [weak self] code in
            guard let self else { return }
            self.sdkLoading = false
            self.sdkReady = code == 0
            if self.sdkReady {
                FaceRecognitionClient.shared.loadDatabase()
                self.warningLabel.isHidden = true
                self.setSdkActionsEnabled(true)
                self.refreshPeople()
            } else {
                self.setSdkActionsEnabled(false)
                self.warningLabel.isHidden = false
                self.warningLabel.text = switch code {
                case 1: "Invalid license!"
                case 2: "License expired!"
                case 3: "No activated!"
                default: "Init error!"
                }
            }
        }
    }

    private func setSdkActionsEnabled(_ enabled: Bool) {
        for button in sdkActionButtons {
            button.isEnabled = enabled
            button.isUserInteractionEnabled = enabled
            button.alpha = enabled ? 1 : 0.45
        }
    }

    private func refreshPeople() {
        people = FaceRecognitionClient.shared.enrolledPeople()
        enrolledHeader.isHidden = people.isEmpty
        tableView.reloadData()
    }

    private func ensureReady() -> Bool {
        if sdkReady { return true }
        presentToast(sdkLoading ? "Loading native SDK…" : "SDK not ready")
        return false
    }

    @objc private func openEnroll() {
        guard ensureReady() else { return }
        pickGallery(for: .enroll)
    }

    @objc private func openIdentify() {
        guard ensureReady() else { return }
        navigationController?.pushViewController(IdentifyCameraViewController(), animated: true)
    }

    @objc private func openCapture() {
        guard ensureReady() else { return }
        navigationController?.pushViewController(CaptureCameraViewController(), animated: true)
    }

    @objc private func openAttribute() {
        guard ensureReady() else { return }
        pickGallery(for: .attribute)
    }

    @objc private func openSettings() {
        navigationController?.pushViewController(SettingsViewController(), animated: true)
    }

    @objc private func openAbout() {
        navigationController?.pushViewController(AboutViewController(), animated: true)
    }

    private func pickGallery(for request: GalleryRequest) {
        pendingGalleryRequest = request
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = self
        present(picker, animated: true)
    }

    private func enrollFromGallery(_ image: UIImage) {
        let upright = CameraFrameUtils.normalizedUp(image)
        let prepared = CameraFrameUtils.enginePreparedImage(upright)
        FaceRecognitionClient.shared.async { [weak self] in
            let faces = FaceRecognitionClient.shared.faceDetection(
                from: prepared,
                purpose: .galleryEnroll,
                livenessLevel: AppSettings.livenessLevel
            )
            if faces.count != 1 {
                DispatchQueue.main.async {
                    self?.presentToast(faces.isEmpty ? "No face detected!" : "Multiple face detected!")
                }
                return
            }
            let face = faces[0]
            let crop = FaceUtils.cropFace(from: prepared, face: face)
            let feature = FaceRecognitionClient.shared.templateExtraction(from: prepared, face: face)
            DispatchQueue.main.async {
                guard let self else { return }
                guard let crop, let feature, !feature.isEmpty else {
                    self.presentToast("Enrollment failed")
                    return
                }
                let name = "Person\(Int.random(in: 10_000..<20_000))"
                if FaceRecognitionClient.shared.enroll(name: name, feature: feature, thumbnail: crop) != nil {
                    self.refreshPeople()
                    self.presentToast("Person enrolled!")
                } else {
                    self.presentToast("Enrollment failed")
                }
            }
        }
    }

    private func attributeFromGallery(_ image: UIImage) {
        let upright = CameraFrameUtils.normalizedUp(image)
        let prepared = CameraFrameUtils.enginePreparedImage(upright)
        FaceRecognitionClient.shared.async { [weak self] in
            let faces = FaceRecognitionClient.shared.faceDetection(
                from: prepared,
                purpose: .fullAttributes,
                livenessLevel: AppSettings.livenessLevel
            )
            DispatchQueue.main.async {
                guard let self else { return }
                if faces.count != 1 {
                    self.presentToast(faces.isEmpty ? "No face detected!" : "Multiple face detected!")
                    return
                }
                let face = faces[0]
                let crop = FaceUtils.cropFace(from: prepared, face: face) ?? upright
                let landmarks = FaceUtils.mapLandmarksToCrop(face: face, cropSize: crop.size)
                let vc = AttributeViewController(faceImage: crop, face: face, cropLandmarks: landmarks)
                self.navigationController?.pushViewController(vc, animated: true)
            }
        }
    }

    private func presentToast(_ message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        present(alert, animated: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { alert.dismiss(animated: true) }
    }
}

extension ViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        people.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: PersonCell.reuseId, for: indexPath) as! PersonCell
        let person = people[indexPath.row]
        cell.configure(
            person: person,
            thumbnail: FaceRecognitionClient.shared.thumbnail(for: person),
            onDelete: { [weak self] in
                FaceRecognitionClient.shared.removeEnrolled(ids: [person.id])
                self?.refreshPeople()
            }
        )
        return cell
    }
}

extension ViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(
        _ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
    ) {
        picker.dismiss(animated: true)
        guard let image = info[.originalImage] as? UIImage else { return }
        switch pendingGalleryRequest {
        case .enroll: enrollFromGallery(image)
        case .attribute: attributeFromGallery(image)
        case .none: break
        }
        pendingGalleryRequest = nil
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
        pendingGalleryRequest = nil
    }
}

/// Home tile whose icon and caption scale with the button (and therefore the screen).
private final class HomeTileButton: UIButton {
    private let iconView = UIImageView()
    private let caption = UILabel()

    init(title: String, assetName: String) {
        super.init(frame: .zero)
        backgroundColor = FPColor.purple
        layer.cornerRadius = 16
        clipsToBounds = true

        iconView.image = UIImage(named: assetName)
        iconView.contentMode = .scaleAspectFit
        iconView.isUserInteractionEnabled = false

        caption.text = title
        caption.textColor = FPColor.text
        caption.textAlignment = .center
        caption.adjustsFontSizeToFitWidth = true
        caption.minimumScaleFactor = 0.7
        caption.isUserInteractionEnabled = false

        addSubview(iconView)
        addSubview(caption)
    }

    required init?(coder: NSCoder) { nil }

    override func layoutSubviews() {
        super.layoutSubviews()
        let captionHeight = max(14, min(18, bounds.height * 0.16))
        let pad: CGFloat = max(4, bounds.height * 0.04)
        let available = max(24, bounds.height - captionHeight - pad * 2)
        let side = min(bounds.width * 0.68, available)
        iconView.frame = CGRect(
            x: (bounds.width - side) / 2,
            y: pad,
            width: side,
            height: side
        )
        caption.font = .systemFont(ofSize: max(11, min(15, bounds.width * 0.14)), weight: .regular)
        caption.frame = CGRect(
            x: 4,
            y: bounds.height - captionHeight - 3,
            width: bounds.width - 8,
            height: captionHeight
        )
    }
}

private final class PersonCell: UITableViewCell {
    static let reuseId = "PersonCell"
    private let thumb = UIImageView()
    private let nameLabel = UILabel()
    private let deleteButton = UIButton(type: .system)
    private var onDelete: (() -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = FPColor.surfaceAlt
        layer.cornerRadius = 8
        clipsToBounds = true

        thumb.contentMode = .scaleAspectFill
        thumb.clipsToBounds = true
        thumb.layer.cornerRadius = 30
        thumb.backgroundColor = FPColor.overlay
        thumb.translatesAutoresizingMaskIntoConstraints = false

        nameLabel.textColor = FPColor.text
        nameLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        deleteButton.setImage(UIImage(systemName: "trash"), for: .normal)
        deleteButton.tintColor = FPColor.statusError
        deleteButton.addTarget(self, action: #selector(deleteTapped), for: .touchUpInside)
        deleteButton.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(thumb)
        contentView.addSubview(nameLabel)
        contentView.addSubview(deleteButton)
        NSLayoutConstraint.activate([
            thumb.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            thumb.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            thumb.widthAnchor.constraint(equalToConstant: 60),
            thumb.heightAnchor.constraint(equalToConstant: 60),
            nameLabel.leadingAnchor.constraint(equalTo: thumb.trailingAnchor, constant: 12),
            nameLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            deleteButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            deleteButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) { nil }

    func configure(person: EnrolledPerson, thumbnail: UIImage?, onDelete: @escaping () -> Void) {
        nameLabel.text = person.name
        thumb.image = thumbnail
        self.onDelete = onDelete
    }

    @objc private func deleteTapped() { onDelete?() }
}
