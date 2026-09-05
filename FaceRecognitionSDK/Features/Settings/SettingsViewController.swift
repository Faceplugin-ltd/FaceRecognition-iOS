import UIKit
import FaceRecognitionKit

/// Android `SettingsActivity` + labels from `strings.xml` / `root_preferences.xml`.
final class SettingsViewController: UIViewController {
    private struct ThresholdRow {
        let title: String
        let key: String
        let min: Float
        let max: Float
    }

    private struct PickerConfig {
        let title: String
        let key: String
        let options: [(String, String)]
    }

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private var valueLabels: [String: UILabel] = [:]
    private var pickerConfigs: [String: PickerConfig] = [:]
    private var thresholdRowsByKey: [String: ThresholdRow] = [:]

    private let thresholdRows: [ThresholdRow] = [
        ThresholdRow(title: "Liveness", key: "liveness_threshold", min: 0, max: 1),
        ThresholdRow(title: "Identify", key: "identify_threshold", min: 0, max: 1),
        ThresholdRow(title: "Yaw", key: "yaw_threshold", min: 0, max: 90),
        ThresholdRow(title: "Roll", key: "roll_threshold", min: 0, max: 90),
        ThresholdRow(title: "Pitch", key: "pitch_threshold", min: 0, max: 90),
        ThresholdRow(title: "Eye closed", key: "eyeclose_threshold", min: 0, max: 1),
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        for row in thresholdRows { thresholdRowsByKey[row.key] = row }

        view.backgroundColor = FPColor.bg
        title = "Settings"
        ScreenChrome.showInnerBar(on: self)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.keyboardDismissMode = .onDrag
        contentStack.axis = .vertical
        contentStack.spacing = 16
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)
        view.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 16),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 16),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -16),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24),
        ])

        contentStack.addArrangedSubview(cameraSection())
        contentStack.addArrangedSubview(thresholdsSection())
        contentStack.addArrangedSubview(resetSection())
        refreshAllValues()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        ScreenChrome.showInnerBar(on: self)
        refreshAllValues()
    }

    private func cameraSection() -> UIView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.addArrangedSubview(sectionTitle("Camera"))
        stack.addArrangedSubview(pickerRow(PickerConfig(
            title: "Camera lens",
            key: "camera_lens",
            options: [("Front", "front"), ("Back", "back")]
        )))
        return wrapCard(stack)
    }

    private func thresholdsSection() -> UIView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 10
        stack.addArrangedSubview(sectionTitle("Thresholds"))
        stack.addArrangedSubview(pickerRow(PickerConfig(
            title: "Liveness Level",
            key: "liveness_level",
            options: [("High Accuracy", "0"), ("Light Weight", "1")]
        )))
        for row in thresholdRows {
            stack.addArrangedSubview(thresholdRow(row))
        }
        return wrapCard(stack)
    }

    private func resetSection() -> UIView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.addArrangedSubview(sectionTitle("Reset"))

        let restore = makeActionButton(title: "Restore default settings", filled: true)
        restore.addTarget(self, action: #selector(restoreTapped), for: .touchUpInside)
        stack.addArrangedSubview(restore)

        let clear = makeActionButton(title: "Clear all person", filled: false)
        clear.addTarget(self, action: #selector(clearTapped), for: .touchUpInside)
        stack.addArrangedSubview(clear)

        return wrapCard(stack)
    }

    private func pickerRow(_ config: PickerConfig) -> UIView {
        pickerConfigs[config.key] = config
        let valueLabel = UILabel()
        valueLabel.textColor = FPColor.muted
        valueLabel.font = .systemFont(ofSize: 15)
        valueLabel.textAlignment = .right
        valueLabels[config.key] = valueLabel

        let button = UIButton(type: .system)
        button.accessibilityIdentifier = config.key
        button.addTarget(self, action: #selector(pickerRowTapped(_:)), for: .touchUpInside)
        return tappableRow(title: config.title, valueLabel: valueLabel, button: button)
    }

    private func thresholdRow(_ row: ThresholdRow) -> UIView {
        let valueLabel = UILabel()
        valueLabel.textColor = FPColor.muted
        valueLabel.font = .systemFont(ofSize: 15)
        valueLabel.textAlignment = .right
        valueLabels[row.key] = valueLabel

        let button = UIButton(type: .system)
        button.accessibilityIdentifier = row.key
        button.addTarget(self, action: #selector(thresholdRowTapped(_:)), for: .touchUpInside)
        return tappableRow(title: row.title, valueLabel: valueLabel, button: button)
    }

    private func tappableRow(title: String, valueLabel: UILabel, button: UIButton) -> UIView {
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.textColor = FPColor.text
        titleLabel.font = .systemFont(ofSize: 15)

        let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevron.tintColor = FPColor.muted
        chevron.setContentHuggingPriority(.required, for: .horizontal)

        let row = UIStackView(arrangedSubviews: [titleLabel, valueLabel, chevron])
        row.axis = .horizontal
        row.spacing = 8
        row.alignment = .center
        row.isUserInteractionEnabled = false

        button.translatesAutoresizingMaskIntoConstraints = false
        let container = UIView()
        container.addSubview(row)
        container.addSubview(button)
        row.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: container.topAnchor, constant: 4),
            row.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            row.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -4),
            button.topAnchor.constraint(equalTo: container.topAnchor),
            button.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            button.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            button.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        return container
    }

    private func makeActionButton(title: String, filled: Bool) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.setTitleColor(filled ? FPColor.text : FPColor.accent, for: .normal)
        button.backgroundColor = filled ? FPColor.purple : FPColor.surfaceAlt
        button.layer.cornerRadius = 10
        button.contentEdgeInsets = UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
        return button
    }

    private func wrapCard(_ stack: UIStackView) -> UIView {
        let card = UIView()
        card.backgroundColor = FPColor.surfaceAlt
        card.layer.cornerRadius = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
        ])
        return card
    }

    private func sectionTitle(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.textColor = FPColor.text
        label.font = .systemFont(ofSize: 17, weight: .semibold)
        return label
    }

    private func refreshAllValues() {
        valueLabels["camera_lens"]?.text = displayValue(for: "camera_lens")
        valueLabels["liveness_level"]?.text = displayValue(for: "liveness_level")
        for row in thresholdRows {
            valueLabels[row.key]?.text = storedString(for: row.key)
        }
    }

    private func storedString(for key: String) -> String {
        UserDefaults.standard.string(forKey: key) ?? defaultValue(for: key)
    }

    private func displayValue(for key: String) -> String {
        let raw = storedString(for: key)
        switch key {
        case "camera_lens": return raw == "back" ? "Back" : "Front"
        case "liveness_level": return raw == "1" ? "Light Weight" : "High Accuracy"
        default: return raw
        }
    }

    private func defaultValue(for key: String) -> String {
        switch key {
        case "camera_lens": return AppSettings.defaultCameraLens
        case "liveness_threshold": return AppSettings.defaultLivenessThreshold
        case "liveness_level": return AppSettings.defaultLivenessLevel
        case "identify_threshold": return AppSettings.defaultIdentifyThreshold
        case "yaw_threshold": return AppSettings.defaultYawThreshold
        case "roll_threshold": return AppSettings.defaultRollThreshold
        case "pitch_threshold": return AppSettings.defaultPitchThreshold
        case "eyeclose_threshold": return AppSettings.defaultEyecloseThreshold
        default: return ""
        }
    }

    @objc private func pickerRowTapped(_ sender: UIButton) {
        guard let key = sender.accessibilityIdentifier,
              let config = pickerConfigs[key] else { return }
        let alert = UIAlertController(title: config.title, message: nil, preferredStyle: .actionSheet)
        for (label, value) in config.options {
            alert.addAction(UIAlertAction(title: label, style: .default) { [weak self] _ in
                UserDefaults.standard.set(value, forKey: key)
                self?.refreshAllValues()
            })
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let pop = alert.popoverPresentationController {
            pop.sourceView = sender
            pop.sourceRect = sender.bounds
        }
        present(alert, animated: true)
    }

    @objc private func thresholdRowTapped(_ sender: UIButton) {
        guard let key = sender.accessibilityIdentifier,
              let row = thresholdRowsByKey[key] else { return }
        let alert = UIAlertController(title: row.title, message: nil, preferredStyle: .alert)
        alert.addTextField { field in
            field.text = self.storedString(for: row.key)
            field.keyboardType = .decimalPad
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Save", style: .default) { [weak self] _ in
            guard let self,
                  let text = alert.textFields?.first?.text,
                  let value = Float(text),
                  value >= row.min, value <= row.max else {
                self?.presentToast("Invalid value")
                return
            }
            UserDefaults.standard.set(text, forKey: row.key)
            self.refreshAllValues()
        })
        present(alert, animated: true)
    }

    @objc private func restoreTapped() {
        AppSettings.restoreDefaults()
        refreshAllValues()
        presentToast("Restored default settings")
    }

    @objc private func clearTapped() {
        FaceRecognitionClient.shared.clearEnrolled()
        presentToast("Cleared all person")
    }

    private func presentToast(_ message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        present(alert, animated: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { alert.dismiss(animated: true) }
    }
}
