import AppKit
import Photos
import SwiftUI
import Vision

enum QuickCategory: String, CaseIterable, Codable, Identifiable {
    case screenshots = "Screenshots"
    case blur = "Possible Blur"
    case documents = "Documents"
    case labels = "Equipment Labels"
    case text = "Photos with Text"
    case similar = "Similar Photos"

    var id: String { rawValue }
}

struct QuickSignals: Codable, Equatable {
    var categories: Set<QuickCategory> = []
    var hasLocalImage = false

    static func classifyText(_ regions: [TextRegion]) -> QuickCategory? {
        let lines = regions.filter { $0.text.count >= 3 && $0.confidence >= 0.5 }
        guard lines.count >= 3 else { return nil }
        // Use only a category from these transient strings. Never persist recognized text.
        let words = Set(lines.flatMap {
            $0.text.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
        })
        let deviceWords: Set<String> = ["router", "ssid", "wlan", "wps", "ethernet", "huawei", "tp", "tplink",
                                        "serial", "hdmi", "voltage", "manufactured", "sony", "samsung", "dell"]
        let labelWords: Set<String> = ["model", "modelo", "serial", "input", "voltage", "mac", "ssid", "wlan"]
        if words.intersection(deviceWords).count >= 2 && !words.isDisjoint(with: labelWords) {
            return .labels
        }
        let wideLines = lines.filter { $0.width >= 0.28 }.count
        if lines.count >= 7 && wideLines >= 4 { return .documents }
        return lines.count >= 5 ? .text : nil
    }

    struct TextRegion {
        let text: String
        let width: CGFloat
        let confidence: Float
    }

    // Low edge strength alone can mean a flat scene. Require visible contrast and few sharp edges.
    static func looksBlurry(_ samples: [UInt8], width: Int) -> Bool {
        guard width >= 3, samples.count >= width * 3, samples.count.isMultiple(of: width),
              let minimum = samples.min(), let maximum = samples.max(),
              Int(maximum) - Int(minimum) >= 45 else { return false }
        var edges = 0
        var strong = 0
        for y in 1..<(samples.count / width - 1) {
            for x in 1..<(width - 1) {
                let i = y * width + x
                let gradient = abs(Int(samples[i + 1]) - Int(samples[i - 1]))
                    + abs(Int(samples[i + width]) - Int(samples[i - width]))
                if gradient >= 10 { edges += 1 }
                if gradient >= 25 { strong += 1 }
            }
        }
        return edges >= samples.count / 25 && strong * 8 < edges
    }

    static func inspect(_ image: CGImage) -> QuickSignals {
        var result = QuickSignals(hasLocalImage: true)
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .fast
        request.recognitionLanguages = ["en-US", "es-ES"]
        request.usesLanguageCorrection = false
        if (try? VNImageRequestHandler(cgImage: image).perform([request])) != nil {
            let regions = (request.results ?? []).compactMap { observation -> TextRegion? in
                guard let candidate = observation.topCandidates(1).first else { return nil }
                return TextRegion(text: candidate.string, width: observation.boundingBox.width,
                                  confidence: candidate.confidence)
            }
            if let category = classifyText(regions) { result.categories.insert(category) }
        }
        let scale = 144.0 / Double(max(image.width, image.height))
        let width = max(3, Int(Double(image.width) * scale))
        let height = max(3, Int(Double(image.height) * scale))
        if let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                   bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(),
                                   bitmapInfo: CGImageAlphaInfo.none.rawValue) {
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            if let data = context.data,
               looksBlurry(Array(UnsafeBufferPointer(start: data.assumingMemoryBound(to: UInt8.self),
                                                     count: width * height)), width: width) {
                result.categories.insert(.blur)
            }
        }
        return result
    }
}

actor QuickPhotoAnalyzer {
    func inspect(_ photos: [Photo], onResult: @escaping @MainActor (Photo, QuickSignals) -> Void) async {
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: photos.map(\.id), options: nil)
        var byID: [String: PHAsset] = [:]
        assets.enumerateObjects { asset, _, _ in byID[asset.localIdentifier] = asset }
        let manager = PHImageManager()
        let options = PHImageRequestOptions()
        options.isSynchronous = true
        options.isNetworkAccessAllowed = false
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .exact
        for photo in photos {
            guard !Task.isCancelled else { return }
            guard let asset = byID[photo.id], asset.modificationDate == photo.modified,
                  asset.pixelWidth == photo.width, asset.pixelHeight == photo.height else { continue }
            let signals = autoreleasepool {
                var image: CGImage?
                manager.requestImage(for: asset, targetSize: CGSize(width: 768, height: 768),
                                     contentMode: .aspectFit, options: options) { photo, info in
                    guard (info?[PHImageResultIsDegradedKey] as? Bool) != true else { return }
                    image = photo?.cgImage(forProposedRect: nil, context: nil, hints: nil)
                }
                return image.map(QuickSignals.inspect) ?? QuickSignals()
            }
            await onResult(photo, signals)
        }
    }
}

struct QuickPhoto: Identifiable, Equatable {
    let photo: Photo
    let groupID: String?
    let categories: Set<QuickCategory>
    var id: String { photo.id }

    var reasons: String {
        QuickCategory.allCases.filter(categories.contains).map(\.rawValue).joined(separator: " · ")
    }
}

enum QuickDisposition: String, Codable { case keep, later }

struct QuickReviewStore: Codable {
    struct Note: Codable, Equatable {
        let photo: Photo
        let disposition: QuickDisposition
    }
    struct Analysis: Codable {
        let photo: Photo
        let signals: QuickSignals
    }
    var notes: [String: Note] = [:]
    var analysis: [String: Analysis] = [:]
}

enum QuickReviewBatch {
    static let limit = 25

    static func choose(from candidates: [QuickPhoto], limit: Int = limit) -> [QuickPhoto] {
        let buckets = QuickCategory.allCases.map { category in
            candidates.filter { $0.categories.contains(category) }
        }
        var cursors = Array(repeating: 0, count: buckets.count)
        var selected: [QuickPhoto] = []
        var included: Set<String> = []
        let byGroup = Dictionary(grouping: candidates.compactMap { item in
            item.groupID.map { ($0, item) }
        }, by: { $0.0 })
        while selected.count < limit {
            let before = selected.count
            for index in buckets.indices where selected.count < limit {
                let bucket = buckets[index]
                while cursors[index] < bucket.count {
                    let item = bucket[cursors[index]]
                    cursors[index] += 1
                    guard !included.contains(item.id) else { continue }
                    let members = item.groupID.flatMap { byGroup[$0]?.map(\.1) } ?? [item]
                    let pair = members.count == 2 ? members : [item]
                    let available = pair.filter { !included.contains($0.id) }
                    guard available.count <= limit - selected.count else { continue }
                    for member in available {
                        included.insert(member.id)
                        selected.append(member)
                    }
                    break
                }
            }
            if selected.count == before { break }
        }
        return selected
    }
}

@MainActor @Observable
final class QuickReviewSession {
    private(set) var catalog: [CleanupPhoto] = []
    private(set) var years: [Int] = []
    private var catalogByID: [String: CleanupPhoto] = [:]
    var store = QuickReviewStore()
    var batch: [QuickPhoto] = []
    var considered = Set<String>()
    var selection = Set<String>()
    var anchor: String?
    var category: QuickCategory?
    var year: Int?
    var comparing: [QuickPhoto] = []
    var focusedID: String?
    var undoComparison: [QuickPhoto] = []
    var undoFocus: String?
    var undoWasLater = false
    var analyzing = false
    var inspectedCount = 0
    var inspectTotal = 0
    private(set) var unavailableIDs = Set<String>()
    private var readable: [String: Photo] = [:]

    func updateCatalog(_ photos: [CleanupPhoto]) {
        catalog = photos
        let calendar = Calendar.current
        years = Set(photos.lazy.filter { $0.photo.date != .distantPast }
            .map { calendar.component(.year, from: $0.photo.date) }).sorted(by: >)
        catalogByID = Dictionary(uniqueKeysWithValues: photos.map { ($0.id, $0) })
        store.analysis = store.analysis.filter { catalogByID[$0.key]?.photo == $0.value.photo }
        store.notes = store.notes.filter { id, note in
            catalogByID[id]?.photo.matchesAsset(note.photo) == true
        }
        unavailableIDs.formIntersection(catalogByID.keys)
        readable = readable.filter { id, photo in
            guard let current = catalogByID[id]?.photo else { return false }
            return photo.matchesAsset(current)
        }
    }

    func candidates(groups: [SimilarGroup]) -> [QuickPhoto] {
        var membership: [String: (String, Photo)] = [:]
        for group in groups {
            for photo in group.photos {
                membership[photo.id] = (group.id, photo)
            }
        }
        return catalog.compactMap { item in
            let group = membership[item.id]
            var reasons = store.analysis[item.id]?.signals.categories ?? []
            if item.screenshot { reasons.insert(.screenshots) }
            if group != nil { reasons.insert(.similar) }
            // Keep a resolved item recognizable even if the filter that found it has changed.
            guard !reasons.isEmpty || store.notes[item.id] != nil else { return nil }
            return QuickPhoto(photo: group?.1 ?? item.photo, groupID: group?.0, categories: reasons)
        }
    }

    func photosToAnalyze(limit: Int = 160) -> [Photo] {
        // Process a bounded window within the selected year.
        let calendar = Calendar.current
        return Array(catalog.lazy.filter { item in
            (self.year.map { calendar.component(.year, from: item.photo.date) == $0 } ?? true)
                && self.store.analysis[item.id] == nil && !self.unavailableIDs.contains(item.id)
        }.prefix(limit).map(\.photo))
    }

    func record(_ signals: QuickSignals, for photo: Photo) {
        guard catalogByID[photo.id]?.photo == photo else { return }
        if signals.hasLocalImage {
            store.analysis[photo.id] = .init(photo: photo, signals: signals)
        } else {
            unavailableIDs.insert(photo.id)
        }
        inspectedCount += 1
    }

    func note(for item: QuickPhoto) -> QuickReviewStore.Note? {
        guard let note = store.notes[item.id], note.photo.matchesAsset(item.photo) else { return nil }
        return note
    }

    func set(_ disposition: QuickDisposition, for items: [QuickPhoto]) {
        for item in items {
            store.notes[item.id] = .init(photo: item.photo, disposition: disposition)
        }
    }

    func contains(_ photo: Photo) -> Bool { catalogByID[photo.id]?.photo.matchesAsset(photo) == true }

    func notePreview(_ photo: Photo) {
        guard catalogByID[photo.id]?.photo.matchesAsset(photo) == true else { return }
        readable[photo.id] = photo
        unavailableIDs.remove(photo.id)
    }

    func hasPreview(_ photo: Photo) -> Bool { readable[photo.id] == photo }

    func select(_ id: String, range: Bool, from visible: [QuickPhoto]) {
        let ids = visible.map(\.id)
        guard let end = ids.firstIndex(of: id) else { return }
        if range, let anchor, let start = ids.firstIndex(of: anchor) {
            selection.formUnion(ids[min(start, end)...max(start, end)])
        } else {
            if selection.remove(id) == nil { selection.insert(id) }
            anchor = id
        }
    }

    func clearSelection() {
        selection.removeAll()
        anchor = nil
    }

    func showComparison(_ items: [QuickPhoto]) {
        comparing = items
        focusedID = items.first?.id
    }
}

private extension Photo {
    func matchesAsset(_ other: Photo) -> Bool {
        id == other.id && date == other.date && modified == other.modified
            && width == other.width && height == other.height && favorite == other.favorite && live == other.live
    }
}
