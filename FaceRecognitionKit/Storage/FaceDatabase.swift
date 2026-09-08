import UIKit

public struct EnrolledPerson: Codable, Equatable {
    public let id: String
    public var name: String
    public var featureBase64: String
    public var thumbnailFile: String?
    public let createdAt: Date
}

public final class FaceDatabase {
    public static let shared = FaceDatabase()

    public private(set) var people: [EnrolledPerson] = []
    private let queue = DispatchQueue(label: "far.face.database")
    private let fileURL: URL
    private let thumbDir: URL

    private init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = docs.appendingPathComponent("face_database.json")
        thumbDir = docs.appendingPathComponent("face_thumbnails", isDirectory: true)
    }

    public var count: Int { people.count }
    public var isEmpty: Bool { people.isEmpty }

    public func load() {
        queue.sync {
            guard let data = try? Data(contentsOf: fileURL),
                  let decoded = try? JSONDecoder().decode([EnrolledPerson].self, from: data) else {
                people = []
                return
            }
            people = decoded
        }
    }

    @discardableResult
    public func add(name: String, feature: Data, thumbnail: UIImage?) -> EnrolledPerson? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !feature.isEmpty else { return nil }
        let id = UUID().uuidString
        var thumbFile: String?
        if let thumbnail, let saved = saveThumbnail(thumbnail, id: id) {
            thumbFile = saved
        }
        let person = EnrolledPerson(
            id: id,
            name: trimmed,
            featureBase64: feature.base64EncodedString(),
            thumbnailFile: thumbFile,
            createdAt: Date()
        )
        queue.sync {
            people.append(person)
            persistLocked()
        }
        return person
    }

    public func remove(id: String) {
        remove(ids: Set([id]))
    }

    public func remove(ids: Set<String>) {
        guard !ids.isEmpty else { return }
        queue.sync {
            for id in ids {
                deleteThumbnailLocked(for: id)
            }
            people.removeAll { ids.contains($0.id) }
            persistLocked()
        }
    }

    @discardableResult
    public func updateName(id: String, name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        return queue.sync {
            guard let index = people.firstIndex(where: { $0.id == id }) else { return false }
            people[index].name = trimmed
            persistLocked()
            return true
        }
    }

    public func person(id: String) -> EnrolledPerson? {
        queue.sync { people.first { $0.id == id } }
    }

    public func clear() {
        queue.sync {
            people.removeAll()
            persistLocked()
            try? FileManager.default.removeItem(at: thumbDir)
        }
    }

    public func bestMatch(for feature: Data, threshold: Float) -> (person: EnrolledPerson, score: Float)? {
        let snapshot = queue.sync { people }
        var best: (EnrolledPerson, Float)?
        for person in snapshot {
            guard let stored = Data(base64Encoded: person.featureBase64) else { continue }
            let score = FaceRecognitionSDKQueue.similarity(feature1: feature, feature2: stored)
            guard score >= threshold else { continue }
            if best == nil || score > best!.1 {
                best = (person, score)
            }
        }
        return best
    }

    /// Ordered enrolled templates for VideoWorker database sync (index = person_id).
    public func featureTemplates() -> [Data] {
        queue.sync {
            people.compactMap { Data(base64Encoded: $0.featureBase64) }
        }
    }

    public func person(atVideoWorkerIndex index: Int) -> EnrolledPerson? {
        queue.sync {
            guard index >= 0, index < people.count else { return nil }
            return people[index]
        }
    }

    public func thumbnail(for person: EnrolledPerson) -> UIImage? {
        guard let file = person.thumbnailFile else { return nil }
        let url = thumbDir.appendingPathComponent(file)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    private func deleteThumbnailLocked(for id: String) {
        guard let person = people.first(where: { $0.id == id }),
              let file = person.thumbnailFile else { return }
        try? FileManager.default.removeItem(at: thumbDir.appendingPathComponent(file))
    }

    private func persistLocked() {
        try? FileManager.default.createDirectory(at: thumbDir, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(people) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    private func saveThumbnail(_ image: UIImage, id: String) -> String? {
        try? FileManager.default.createDirectory(at: thumbDir, withIntermediateDirectories: true)
        let file = "\(id).jpg"
        let url = thumbDir.appendingPathComponent(file)
        guard let data = image.jpegData(compressionQuality: 0.85) else { return nil }
        do {
            try data.write(to: url, options: .atomic)
            return file
        } catch {
            return nil
        }
    }
}
