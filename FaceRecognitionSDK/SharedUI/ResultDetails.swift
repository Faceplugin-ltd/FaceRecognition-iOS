import UIKit
import FaceRecognitionKit

/// Mirrors Android `FaceBoxExtras` + `ResultDetails`.
enum FaceBoxPayload {
    static let identifiedFace = "identified_face"
    static let enrolledFace = "enrolled_face"
    static let faceImage = "face_image"
    static let identifiedName = "identified_name"
    static let similarity = "similarity"
}

enum ResultDetails {
    static let section = "__section__"

    private static let headerColor = UIColor(red: 0xD0 / 255, green: 0xBC / 255, blue: 0xFF / 255, alpha: 1)
    private static let labelColor = UIColor(red: 0x93 / 255, green: 0x8F / 255, blue: 0x99 / 255, alpha: 1)
    private static let valueColor = UIColor(red: 0xE6 / 255, green: 0xE1 / 255, blue: 0xE5 / 255, alpha: 1)

    static func qualityText(_ score: Float) -> String {
        let pct = Int(score * 100)
        switch score {
        case ..<0.5: return "Low · \(pct)%"
        case ..<0.75: return "Medium · \(pct)%"
        default: return "High · \(pct)%"
        }
    }

    static func livenessText(score: Float, threshold: Float, label: String?) -> String {
        let already = label ?? ""
        if already.contains(" · ") { return already }
        let lower = already.lowercased()
        let live: String
        if lower.contains("spoof") || lower.contains("fake") {
            live = "Spoof"
        } else if lower.contains("real") {
            live = "Real"
        } else if score >= threshold {
            live = "Real"
        } else {
            live = "Spoof"
        }
        return "\(live) · \(Int(score * 100))%"
    }

    static func genderText(gender: Int, label: String?) -> String {
        if let label, !label.isEmpty { return label }
        switch gender {
        case 0: return "Male"
        case 1: return "Female"
        default: return "Unknown"
        }
    }

    static func rows(for face: DetectedFace, includeMatch: Bool, name: String?, similarity: Float?) -> [(String, String)] {
        let extra = extraMap(face)
        var used = Set<String>()
        var rows: [(String, String)] = []

        func engineAttr(_ keys: [String]) -> String {
            for key in keys {
                if let value = extra[key], !value.isEmpty { return value }
            }
            return ""
        }

        func take(_ title: String, _ keys: String..., fallback: String? = nil) {
            let fromEngine = engineAttr(keys)
            let resolved = fromEngine.isEmpty ? (fallback ?? "") : fromEngine
            if !resolved.isEmpty {
                rows.append((title, resolved))
                keys.forEach { used.insert($0) }
            }
        }

        if includeMatch, let name, let similarity {
            rows.append((section, "Match"))
            rows.append(("Person", name))
            rows.append(("Similarity", "\(Int(similarity * 100))%"))
        }

        rows.append((section, "Authenticity"))
        take(
            "Liveness",
            "Liveness2D",
            fallback: livenessText(
                score: face.livenessScore,
                threshold: AppSettings.livenessThreshold,
                label: face.livenessLabel
            )
        )

        rows.append((section, "Person"))
        take("Age", "Age", fallback: face.ageValue > 0 ? String(face.ageValue) : nil)
        take(
            "Gender",
            "Gender",
            fallback: genderText(gender: face.genderValue, label: face.genderLabel)
        )
        take("Emotion", "Emotion", fallback: face.emotionLabel)
        take("All emotions", "Emotions")

        rows.append((section, "Face"))
        take("Mask", "MedicalMask", "Mask", fallback: face.maskLabel)
        take("Glasses", "Glasses")
        take("Sunglasses", "Sunglasses")
        let leftText = {
            let fromEngine = extra["EyesLeft"] ?? ""
            return fromEngine.isEmpty ? (face.eyesLeftLabel ?? "") : fromEngine
        }()
        let rightText = {
            let fromEngine = extra["EyesRight"] ?? ""
            return fromEngine.isEmpty ? (face.eyesRightLabel ?? "") : fromEngine
        }()
        if !leftText.isEmpty || !rightText.isEmpty {
            let left = leftText.isEmpty ? "—" : leftText
            let right = rightText.isEmpty ? "—" : rightText
            rows.append(("Eyes", "Left  \(left)\nRight  \(right)"))
            used.insert("EyesLeft")
            used.insert("EyesRight")
        }

        rows.append((section, "Quality"))
        let qualityLabel = extra["FaceQuality"] ?? face.qualityLabel
        let overall: String?
        if let qualityLabel, !qualityLabel.isEmpty {
            overall = qualityLabel
        } else if face.faceQualityScore > 0 {
            overall = qualityText(face.faceQualityScore)
        } else {
            overall = nil
        }
        if let overall, !overall.isEmpty {
            rows.append(("Overall", overall))
        }
        used.insert("FaceQuality")
        for key in ["Lighting", "Sharpness", "Noise", "Flare", "BlurLevel", "NoiseLevel"] {
            take(key, key)
        }

        rows.append((section, "Geometry"))
        rows.append((
            "Pose",
            "yaw \(face.yaw)°   roll \(face.roll)°   pitch \(face.pitch)°"
        ))
        let box = face.boxRect
        rows.append((
            "Box",
            "\(Int(box.minX)), \(Int(box.minY)) → \(Int(box.maxX)), \(Int(box.maxY))"
        ))
        if face.faceLuminance > 0 {
            rows.append(("Luminance", "\(Int(face.faceLuminance * 100))%"))
        }

        let leftovers = extra.filter { key, value in
            !used.contains(key)
                && !value.isEmpty
                && !["MouthOpened", "Deepfake", "Template"].contains(key)
        }
        if !leftovers.isEmpty {
            rows.append((section, "More from engine"))
            for (key, value) in leftovers.sorted(by: { $0.key < $1.key }) {
                if !rows.contains(where: { $0.0.compare(key, options: .caseInsensitive) == .orderedSame }) {
                    rows.append((key, value))
                }
            }
        }

        let marks = landmarkPositions(face)
        if !marks.isEmpty {
            rows.append((section, "Landmarks"))
            let count = face.landmarkCount > 0 ? face.landmarkCount : face.landmarks.count
            rows.append(("Count", count > 0 ? "\(count) points" : ""))
            rows.append(("Positions", marks))
        }

        return rows.enumerated().compactMap { index, row in
            if row.0 != section {
                return row.1.isEmpty ? nil : row
            }
            let next = index + 1 < rows.count ? rows[index + 1] : nil
            if let next, next.0 != section, !next.1.isEmpty {
                return row
            }
            return nil
        }
    }

    static func landmarkPositions(_ face: DetectedFace) -> String {
        if face.landmarks.isEmpty { return "" }
        return face.landmarks.enumerated().map { idx, pt in
            "\(idx + 1): \(pt.x), \(pt.y)"
        }.joined(separator: "\n")
    }

    static func bind(container: UIStackView, rows: [(String, String)]) {
        container.arrangedSubviews.forEach { view in
            container.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        container.spacing = 0
        for (title, value) in rows {
            if title == section {
                let header = UILabel()
                header.numberOfLines = 1
                header.attributedText = NSAttributedString(
                    string: value.uppercased(),
                    attributes: [
                        .font: UIFont.systemFont(ofSize: 13, weight: .regular),
                        .foregroundColor: headerColor,
                        .kern: 0.8,
                    ]
                )
                wrap(header, insets: UIEdgeInsets(top: 20, left: 16, bottom: 5, right: 16), in: container)
                continue
            }
            let label = UILabel()
            label.text = title
            label.font = .systemFont(ofSize: 13)
            label.textColor = labelColor
            wrap(label, insets: UIEdgeInsets(top: 10, left: 16, bottom: 0, right: 16), in: container)

            let body = UILabel()
            body.text = value
            body.font = .systemFont(ofSize: 16)
            body.textColor = valueColor
            body.numberOfLines = 0
            wrap(body, insets: UIEdgeInsets(top: 0, left: 16, bottom: 10, right: 16), in: container)
        }
    }

    private static func extraMap(_ face: DetectedFace) -> [String: String] {
        var map: [String: String] = [:]
        for (key, attr) in face.attributes {
            if attr.value.count > 2000 { continue }
            if attr.value.isEmpty { continue }
            let pretty = attr.value.contains(" · ") || attr.value.contains("%") || attr.value.contains("\n")
            if pretty || attr.confidence == nil || attr.confidence?.isEmpty == true {
                map[key] = attr.value
            } else if let conf = attr.confidence {
                map[key] = "\(attr.value) (\(conf))"
            }
        }
        return map
    }

    private static func wrap(_ view: UIView, insets: UIEdgeInsets, in container: UIStackView) {
        let box = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        box.addSubview(view)
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: box.topAnchor, constant: insets.top),
            view.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: insets.left),
            view.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -insets.right),
            view.bottomAnchor.constraint(equalTo: box.bottomAnchor, constant: -insets.bottom),
        ])
        container.addArrangedSubview(box)
    }
}
