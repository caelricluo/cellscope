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
    var alignment: GridQuad? = nil
    var requiresManualGrid: Bool? = nil
}

struct CapturedField {
    var state: CountFieldRecord
    var image: UIImage
}

enum RecordImageFormat: String, Codable { case jpeg, png }

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
    var alignment: GridQuad? = nil
    var requiresManualGrid: Bool? = nil
    var imageFormat: RecordImageFormat? = nil
    var imageExtension: String { imageFormat == .png ? "png" : "jpg" }
    var imageName: String { id.uuidString + "." + imageExtension }
}

enum RecordStore {
    static var directory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("cellscope", isDirectory: true)
    }
    static var index: URL { directory.appendingPathComponent("records.json") }
    static func load() throws -> [CountRecord] {
        let legacy = directory.deletingLastPathComponent().appendingPathComponent("CellScope", isDirectory: true)
        if !FileManager.default.fileExists(atPath: directory.path), FileManager.default.fileExists(atPath: legacy.path) {
            try FileManager.default.moveItem(at: legacy, to: directory)
        }
        guard FileManager.default.fileExists(atPath: index.path) else { return [] }
        return try JSONDecoder().decode([CountRecord].self, from: Data(contentsOf: index))
    }
    static func fieldImageName(_ position: FieldPosition, record: CountRecord) -> String {
        record.id.uuidString + "-" + position.rawValue + "." + record.imageExtension
    }
    static func save(_ record: CountRecord, image: UIImage, records: [CountRecord], fields: [CapturedField] = []) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        func encode(_ image: UIImage) throws -> Data {
            let data = record.imageFormat == .png ? image.pngData() : image.jpegData(compressionQuality:0.9)
            guard let data else { throw CocoaError(.fileWriteUnknown) }
            return data
        }
        let data = try encode(image)
        let imageURL = directory.appendingPathComponent(record.imageName)
        var written: [URL] = []
        do {
            try data.write(to: imageURL, options: .atomic); written.append(imageURL)
            for field in fields {
                let data = try encode(field.image)
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
