import Foundation
import UIKit

struct CountFieldRecord: Codable {
    var position: FieldPosition
    var region: CountRegion
    var markers: [CellMarker]
    var settings: DetectionSettings
    var areaConfirmed: Bool
    var reviewed: Bool
    var hasAnalyzed: Bool
}

struct CapturedField {
    var state: CountFieldRecord
    var image: UIImage
}

struct CountRecord: Codable, Identifiable {
    var id: UUID
    var date: Date
    var name: String
    var isDemo: Bool
    var region: CountRegion
    var markers: [CellMarker]
    var inputs: CountInputs
    var settings: DetectionSettings
    var areaConfirmed: Bool
    var reviewed: Bool
    var grid: NeubauerGrid? = nil // Older records decode as custom, preserving their area.
    var fields: [CountFieldRecord]? = nil
    var activeField: FieldPosition? = nil
    var imageName: String { id.uuidString + ".jpg" }
}

enum RecordStore {
    static var directory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CellScope", isDirectory: true)
    }
    static var index: URL { directory.appendingPathComponent("records.json") }
    static func load() throws -> [CountRecord] {
        guard FileManager.default.fileExists(atPath: index.path) else { return [] }
        return try JSONDecoder().decode([CountRecord].self, from: Data(contentsOf: index))
    }
    static func fieldImageName(_ position: FieldPosition, record: CountRecord) -> String {
        record.id.uuidString + "-" + position.rawValue + ".jpg"
    }
    static func save(_ record: CountRecord, image: UIImage, records: [CountRecord], fields: [CapturedField] = []) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        guard let data = image.jpegData(compressionQuality: 0.9) else { throw CocoaError(.fileWriteUnknown) }
        let imageURL = directory.appendingPathComponent(record.imageName)
        var written: [URL] = []
        do {
            try data.write(to: imageURL, options: .atomic); written.append(imageURL)
            for field in fields {
                guard let data = field.image.jpegData(compressionQuality: 0.9) else { throw CocoaError(.fileWriteUnknown) }
                let url = directory.appendingPathComponent(fieldImageName(field.state.position, record: record))
                try data.write(to: url, options: .atomic); written.append(url)
            }
            try JSONEncoder().encode([record] + records).write(to: index, options: .atomic)
        } catch {
            for url in written { try? FileManager.default.removeItem(at: url) }
            throw error
        }
    }
    static func delete(_ record: CountRecord, remaining: [CountRecord]) throws {
        try JSONEncoder().encode(remaining).write(to: index, options: .atomic)
        try? FileManager.default.removeItem(at: directory.appendingPathComponent(record.imageName))
        for field in record.fields ?? [] {
            try? FileManager.default.removeItem(at: directory.appendingPathComponent(fieldImageName(field.position, record: record)))
        }
    }
    static func image(for record: CountRecord) -> UIImage? {
        UIImage(contentsOfFile: directory.appendingPathComponent(record.imageName).path)
    }
    static func image(for field: CountFieldRecord, record: CountRecord) -> UIImage? {
        UIImage(contentsOfFile: directory.appendingPathComponent(fieldImageName(field.position, record: record)).path)
    }
}
