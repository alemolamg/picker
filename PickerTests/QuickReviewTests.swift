import AppKit
import XCTest
@testable import Picker

final class QuickReviewTests: XCTestCase {
    private func photo(_ index: Int) -> Photo {
        Photo(id: "p\(index)", date: Date(timeIntervalSince1970: Double(index)), modified: nil,
              width: 1200, height: 1000, favorite: false, live: false, score: 0)
    }

    private func item(_ index: Int, groupID: String? = nil, categories: Set<QuickCategory> = [.screenshots]) -> QuickPhoto {
        QuickPhoto(photo: photo(index), groupID: groupID, categories: categories)
    }

    func testBatchLimitsAndMixesReasonsWithoutDuplicatingPhotos() {
        let screenshots = (0..<30).map { item($0) }
        let multiReason = item(30, categories: [.screenshots, .documents])
        let labels = (31..<33).map { item($0, groupID: "pair", categories: [.labels, .similar]) }
        let batch = QuickReviewBatch.choose(from: screenshots + [multiReason] + labels)
        XCTAssertEqual(batch.count, 25)
        XCTAssertEqual(Set(batch.map(\.id)).count, batch.count)
        XCTAssertTrue(batch.contains(multiReason))
        XCTAssertEqual(batch.filter { $0.groupID == "pair" }, labels)
        XCTAssertEqual(QuickReviewBatch.choose(from: labels, limit: 1), [])
    }

    func testTextSignalsDistinguishLikelyEquipmentLabelsFromDocuments() {
        func region(_ text: String, width: CGFloat = 0.5) -> QuickSignals.TextRegion {
            .init(text: text, width: width, confidence: 0.9)
        }
        XCTAssertEqual(QuickSignals.classifyText([
            region("Router", width: 0.1), region("Modelo equipo", width: 0.2), region("WLAN dispositivo", width: 0.2)
        ]), .labels)
        XCTAssertEqual(QuickSignals.classifyText((0..<8).map { region("Documento de prueba \($0)") }), .documents)
        XCTAssertEqual(QuickSignals.classifyText((0..<5).map { region("Texto \($0)", width: 0.1) }), .text)
        XCTAssertNil(QuickSignals.classifyText([region("Logo")]))
    }

    @MainActor func testVisionFindsDocumentInSyntheticPhoto() throws {
        let size = NSSize(width: 900, height: 650)
        let fixture = NSImage(size: size, flipped: true) { bounds in
            NSColor.white.setFill()
            bounds.fill()
            let style: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 27),
                .foregroundColor: NSColor.black
            ]
            let lines = [
                "Sample document for local testing only",
                "The page contains several lines of text.",
                "The words are part of an invented record.",
                "This line is intentionally easy to read.",
                "Each line uses a regular testing font.",
                "There are no names or private identifiers.",
                "This is an example of a full sized page.",
                "The last line completes the test image."
            ]
            for (index, line) in lines.enumerated() {
                line.draw(at: NSPoint(x: 65, y: CGFloat(45 + 62 * index)), withAttributes: style)
            }
            return true
        }
        let image = try XCTUnwrap(fixture.cgImage(forProposedRect: nil, context: nil, hints: nil))
        let signals = QuickSignals.inspect(image)
        XCTAssertTrue(signals.hasLocalImage)
        XCTAssertTrue(signals.categories.contains(.documents))
        let json = try JSONEncoder().encode(signals)
        XCTAssertFalse(String(decoding: json, as: UTF8.self).contains("invented record"))
    }

    func testBlurSignalRequiresContrastAndRejectsSharpEdges() {
        let width = 144
        let flat = Array(repeating: UInt8(128), count: width * width)
        let smooth = Array(repeating: (0..<width).map { UInt8(min(255, max(0, ($0 - 51) * 7))) }, count: width)
            .flatMap { $0 }
        let sharp = Array(repeating: (0..<width).map { UInt8($0 % 12 < 6 ? 0 : 255) }, count: width)
            .flatMap { $0 }
        XCTAssertFalse(QuickSignals.looksBlurry(flat, width: width))
        XCTAssertTrue(QuickSignals.looksBlurry(smooth, width: width))
        XCTAssertFalse(QuickSignals.looksBlurry(sharp, width: width))
    }

    @MainActor func testQuickKeepAndLaterDoNotMarkForDeletion() {
        let model = LibraryModel(persistenceEnabled: false)
        let photos = (0..<3).map { CleanupPhoto(photo: photo($0), screenshot: true) }
        model.updateCleanupCatalog(photos)
        let candidates = model.quickCandidates(later: false)
        XCTAssertTrue(model.resolveQuick([candidates[0]], as: .keep))
        XCTAssertTrue(model.resolveQuick([candidates[1]], as: .later))
        XCTAssertEqual(model.quickCandidates(later: false).map(\.id), ["p2"])
        XCTAssertEqual(model.quickCandidates(later: true).map(\.id), ["p1"])
        XCTAssertTrue(model.deletionPhotos.isEmpty)
        XCTAssertTrue(model.undoQuickReview())
        XCTAssertEqual(model.quickCandidates(later: false).map(\.id), ["p1", "p2"])
    }

    @MainActor func testPreviewGatesMarkingButCloudPhotoCanBeDeferred() {
        let model = LibraryModel(persistenceEnabled: false)
        model.updateCleanupCatalog([CleanupPhoto(photo: photo(0), screenshot: true)])
        let candidate = model.quickCandidates(later: false)[0]
        XCTAssertFalse(model.markQuick([candidate]))
        XCTAssertTrue(model.resolveQuick([candidate], as: .later))
        XCTAssertTrue(model.deletionPhotos.isEmpty)
        model.noteQuickPreview(candidate.photo)
        XCTAssertTrue(model.markQuick([candidate]))
        XCTAssertEqual(model.deletionPhotos.map(\.id), ["p0"])
        XCTAssertTrue(model.quickCandidates(later: true).isEmpty)
        XCTAssertTrue(model.undoQuickReview())
        XCTAssertTrue(model.deletionPhotos.isEmpty)
        XCTAssertEqual(model.quickCandidates(later: true).map(\.id), ["p0"])
    }

    @MainActor func testMixedQuickMarkUsesPendingAndUndoPreservesOtherMarks() {
        let model = LibraryModel(persistenceEnabled: false, deleteAssets: { _, _ in XCTFail("Marking must not delete") })
        let pair = SimilarGroup(photos: [photo(0), photo(1)])
        model.groups = [pair]
        model.updateCleanupCatalog((0..<4).map { CleanupPhoto(photo: photo($0), screenshot: true) })
        let candidates = model.quickCandidates(later: false)
        candidates.forEach { model.noteQuickPreview($0.photo) }
        model.markCleanup(["p3"])
        XCTAssertFalse(model.markQuick([candidates[0], candidates[0]]))
        XCTAssertTrue(model.markQuick(Array(candidates.prefix(3))))
        XCTAssertEqual(Set(model.deletionPhotos.map(\.id)), ["p0", "p1", "p2", "p3"])
        XCTAssertEqual(model.decisions[pair.id]?.keepers, [])
        XCTAssertTrue(model.undoQuickReview())
        XCTAssertEqual(model.deletionPhotos.map(\.id), ["p3"])
    }

    @MainActor func testRangeUsesVisibleItemsAndNextBatchDoesNotRepeat() {
        let model = LibraryModel(persistenceEnabled: false)
        let candidates = (0..<29).map { item($0) }
        let visible = [candidates[0], candidates[2], candidates[4]]
        model.quickReview.select("p0", range: false, from: visible)
        model.quickReview.select("p4", range: true, from: visible)
        XCTAssertEqual(model.quickReview.selection, ["p0", "p2", "p4"])
        model.nextQuickBatch(candidates)
        XCTAssertEqual(model.quickReview.batch.count, 25)
        XCTAssertTrue(model.quickReview.selection.isEmpty)
        model.nextQuickBatch(candidates)
        XCTAssertEqual(model.quickReview.batch.map(\.id), ["p25", "p26", "p27", "p28"])
    }

    @MainActor func testPhotoChangeInvalidatesQuickChoicesAndPreview() {
        let model = LibraryModel(persistenceEnabled: false)
        let original = photo(0)
        model.updateCleanupCatalog([CleanupPhoto(photo: original, screenshot: true)])
        let candidate = model.quickCandidates(later: false)[0]
        model.noteQuickPreview(original)
        XCTAssertTrue(model.resolveQuick([candidate], as: .later))
        let changed = Photo(id: original.id, date: original.date, modified: .now, width: original.width,
                            height: original.height, favorite: false, live: false, score: 0)
        model.updateCleanupCatalog([CleanupPhoto(photo: changed, screenshot: true)])
        XCTAssertTrue(model.quickCandidates(later: true).isEmpty)
        XCTAssertFalse(model.markQuick([candidate]))
        XCTAssertFalse(model.canMarkQuick(model.quickCandidates(later: false)[0]))
    }
}
