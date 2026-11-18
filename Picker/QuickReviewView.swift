import AppKit
import SwiftUI

struct QuickReviewView: View {
    @Bindable var model: LibraryModel
    let later: Bool
    @FocusState private var comparingHasFocus: Bool

    private var session: QuickReviewSession { model.quickReview }

    var body: some View {
        let candidates = model.quickCandidates(later: later)
        let filtered = candidates.filter(matchesFilters)
        let visible = visibleBatch(filtered)
        VStack(spacing: 0) {
            heading(candidates, filtered: filtered)
            Divider()
            if !model.cleanupReady {
                ContentUnavailableView("Waiting for Library Scan", systemImage: "photo.on.rectangle",
                                       description: Text("Quick Review will be available after the scan."))
            } else if !session.comparing.isEmpty {
                comparison(candidates)
            } else if visible.isEmpty {
                ContentUnavailableView(later ? "Nothing to Review Later" : "No Photos in This Batch",
                    systemImage: later ? "bookmark" : "checkmark.circle",
                    description: Text(later ? "Deferred photos appear here." :
                        "Choose another filter, analyze more photos, or continue to the next batch."))
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 156), spacing: 14)], spacing: 14) {
                        ForEach(visible) { item in tile(item, visible: visible, candidates: candidates) }
                    }
                    .padding(18)
                }
                selectionBar(visible)
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(later ? "Review Later" : "Quick Review").font(.headline)
            }.sharedBackgroundVisibility(.hidden)
            ToolbarItem(placement: .primaryAction) {
                Button("Undo", systemImage: "arrow.uturn.backward", action: undo)
                    .disabled(!model.canUndoQuickReview || !model.cleanupReady)
            }
        }
        .task(id: model.cleanupReady) {
            guard model.cleanupReady, !later else { return }
            if session.batch.isEmpty && session.considered.isEmpty { model.nextQuickBatch(filtered) }
            if session.inspectTotal == 0 { model.startQuickAnalysis() }
        }
        .onChange(of: session.analyzing) { _, analyzing in
            if !analyzing && !later && session.batch.isEmpty {
                model.nextQuickBatch(model.quickCandidates(later: false).filter(matchesFilters))
            }
        }
        .onChange(of: later) { resetView() }
        .disabled(model.deleting || model.preparingReview || model.showQueue)
    }

    private func visibleBatch(_ filtered: [QuickPhoto]) -> [QuickPhoto] {
        if later { return Array(filtered.prefix(QuickReviewBatch.limit)) }
        let byID = Dictionary(uniqueKeysWithValues: filtered.map { ($0.id, $0) })
        return session.batch.compactMap { byID[$0.id] }
    }

    private func matchesFilters(_ item: QuickPhoto) -> Bool {
        let year = Calendar.current.component(.year, from: item.photo.date)
        return (session.category.map(item.categories.contains) ?? true) &&
            (session.year.map { year == $0 } ?? true)
    }

    private func heading(_ all: [QuickPhoto], filtered: [QuickPhoto]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if !session.comparing.isEmpty {
                    Button("Back to Batch", systemImage: "chevron.left") { session.showComparison([]) }
                    Spacer()
                } else {
                    Picker("Category", selection: Binding(get: { session.category }, set: { value in
                        session.category = value
                        resetBatch(all)
                    })) {
                        Text("All Categories").tag(nil as QuickCategory?)
                        ForEach(QuickCategory.allCases) { category in
                            Text(category.rawValue).tag(Optional(category))
                        }
                    }
                    .labelsHidden()
                    .fixedSize()
                    Picker("Year", selection: Binding(get: { session.year }, set: { value in
                        session.year = value
                        resetBatch(all)
                    })) {
                        Text("Any Year").tag(nil as Int?)
                        ForEach(session.years, id: \.self) { year in Text(String(year)).tag(Optional(year)) }
                    }
                    .labelsHidden()
                    .fixedSize()
                    Spacer()
                    if !later {
                        Button("Next Batch") { model.nextQuickBatch(filtered) }
                            .disabled(!filtered.contains { !session.considered.contains($0.id) })
                    }
                }
            }
            HStack {
                if session.analyzing {
                    ProgressView(value: Double(session.inspectedCount),
                                 total: Double(max(session.inspectTotal, 1)))
                        .frame(width: 85)
                    Text("Analyzing \(session.inspectedCount) / \(session.inspectTotal) on this Mac")
                    Button("Stop") { model.stopQuickAnalysis() }.buttonStyle(.borderless)
                } else if !later {
                    let left = session.photosToAnalyze(limit: 1).count
                    Text("\(filtered.count.formatted()) candidates")
                    Button("Analyze More") { model.startQuickAnalysis() }
                        .buttonStyle(.borderless)
                        .disabled(left == 0 || !model.cleanupReady)
                        .help("Analyze up to 160 more photos for possible blur, documents and equipment labels")
                } else {
                    Text("\(filtered.count.formatted()) to review · up to 25 at a time")
                }
                Spacer()
                if !later && !session.comparing.isEmpty { Text("← Mark  ·  → Keep") }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func tile(_ item: QuickPhoto, visible: [QuickPhoto], candidates: [QuickPhoto]) -> some View {
        let selected = session.selection.contains(item.id)
        return VStack(alignment: .leading, spacing: 6) {
            Button {
                session.select(item.id, range: NSEvent.modifierFlags.contains(.shift), from: visible)
            } label: {
                PhotoView(photo: item.photo, onReadable: model.noteQuickPreview)
                    .frame(height: 123)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay {
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(selected ? Color.accentColor : .clear, lineWidth: 3)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(selected ? "Deselect photo" : "Select photo")
            HStack(spacing: 5) {
                Image(systemName: selected ? "checkmark.square.fill" : "square")
                    .foregroundStyle(selected ? Color.accentColor : Color.secondary)
                    .accessibilityLabel(selected ? "Selected" : "Unselected")
                Text(item.photo.date.formatted(date: .abbreviated, time: .omitted))
                    .lineLimit(1)
                Spacer()
                if item.photo.favorite {
                    Image(systemName: "heart.fill").foregroundStyle(.pink).accessibilityLabel("Favorite")
                }
                Button {
                    let members = item.groupID.map { id in candidates.filter { $0.groupID == id } } ?? []
                    openComparison(members.count == 2 ? [item] + members.filter { $0.id != item.id } : [item])
                } label: { Image(systemName: "arrow.up.left.and.arrow.down.right") }
                    .buttonStyle(.borderless)
                    .help("Open photo or pair")
                    .accessibilityLabel("Open preview")
            }
            Text(item.reasons).foregroundStyle(.secondary).lineLimit(2)
        }
        .font(.caption)
    }

    private func selectionBar(_ visible: [QuickPhoto]) -> some View {
        let selected = visible.filter { session.selection.contains($0.id) }
        let markable = selected.filter(model.canMarkQuick)
        return HStack(spacing: 9) {
            Text(markable.count == selected.count
                 ? "\(selected.count) selected"
                 : "\(selected.count) selected · \(markable.count) viewable")
                .font(.caption).foregroundStyle(.secondary)
            Spacer()
            Button("Compare Two") { openComparison(selected) }
                .disabled(selected.count != 2)
            if !later {
                Button("Review Later") { resolve(selected, as: .later) }.disabled(selected.isEmpty)
            }
            Button("Keep") { resolve(selected, as: .keep) }.disabled(selected.isEmpty)
            Button("Mark \(markable.count) for Deletion", role: .destructive) { mark(markable) }
                .disabled(markable.isEmpty)
                .help("Queue only selected photos with a readable preview")
        }
        .padding(12)
        .background(.bar)
    }

    private func comparison(_ candidates: [QuickPhoto]) -> some View {
        let photos = session.comparing.compactMap { item in
            candidates.first { $0.id == item.id && $0.photo == item.photo && $0.groupID == item.groupID }
        }
        let focused = photos.first { $0.id == session.focusedID } ?? photos.first
        let pairGroup = photos.first.flatMap { first in
            photos.count == 2 && photos.allSatisfy { $0.groupID == first.groupID } ? model.quickGroup(for: first) : nil
        }
        let entirePair = pairGroup.map { Set($0.photos.map(\.id)) == Set(photos.map(\.id)) } ?? false
        return VStack(spacing: 0) {
            if let focused {
                HStack(spacing: 12) {
                    ForEach(photos) { item in
                        VStack(spacing: 7) {
                            PhotoView(photo: item.photo, large: true, onReadable: model.noteQuickPreview)
                                .id(item.id)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 8)
                                        .strokeBorder(focused.id == item.id ? Color.accentColor : .clear, lineWidth: 3)
                                }
                            Button(focused.id == item.id ? "Active Photo" : "Make Active") {
                                session.focusedID = item.id
                                comparingHasFocus = true
                            }.buttonStyle(.borderless)
                            Text(item.reasons).font(.caption).foregroundStyle(.secondary)
                        }.frame(maxWidth: .infinity)
                    }
                }.padding(14)
                Divider()
                HStack {
                    Button("Mark for Deletion", systemImage: "arrow.left", role: .destructive) {
                        mark([focused])
                    }.disabled(!model.canMarkQuick(focused))
                    if !later {
                        Button(photos.count == 2 ? "Review Later · 2 Photos" : "Review Later") {
                            resolve(photos, as: .later)
                        }
                    }
                    Button("Keep", systemImage: "arrow.right") { resolve([focused], as: .keep) }
                }.padding(10)
                HStack {
                    if let group = model.quickGroup(for: focused) {
                        Button("Open Group") { model.reviewPendingGroup(group) }
                    }
                    if entirePair {
                        Button("Mark Entire Group · 2 Photos", role: .destructive) { mark(photos) }
                            .disabled(!photos.allSatisfy(model.canMarkQuick))
                    }
                    if !model.canMarkQuick(focused) {
                        Text("Load the preview before marking for deletion.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }.padding(.bottom, 10)
            } else {
                ContentUnavailableView("Photos Changed", systemImage: "photo",
                                       description: Text("Go back to the batch to review the updated choices."))
            }
        }
        .focusable()
        .focused($comparingHasFocus)
        .onKeyPress(.leftArrow, phases: .down) { _ in
            guard let focused, model.canMarkQuick(focused) else { return .ignored }
            mark([focused])
            return .handled
        }
        .onKeyPress(.rightArrow, phases: .down) { _ in
            guard let focused else { return .ignored }
            resolve([focused], as: .keep)
            return .handled
        }
        .onKeyPress(.escape, phases: .down) { _ in
            session.showComparison([])
            return .handled
        }
        .onAppear { comparingHasFocus = true }
    }

    private func openComparison(_ items: [QuickPhoto]) {
        session.showComparison(items)
    }

    private func resolve(_ items: [QuickPhoto], as disposition: QuickDisposition) {
        if model.resolveQuick(items, as: disposition) { continueAfterAction(items) }
    }

    private func mark(_ items: [QuickPhoto]) {
        if model.markQuick(items) { continueAfterAction(items) }
    }

    private func continueAfterAction(_ items: [QuickPhoto]) {
        session.undoComparison = session.comparing
        session.undoFocus = session.focusedID
        session.undoWasLater = later
        let ids = Set(items.map(\.id))
        session.selection.subtract(ids)
        guard !session.comparing.isEmpty else { return }
        let remaining = session.comparing.filter { !ids.contains($0.id) }
        if !remaining.isEmpty {
            session.showComparison(remaining)
            comparingHasFocus = true
            return
        }

        let next = visibleBatch(model.quickCandidates(later: later).filter(matchesFilters))
        if let first = next.first {
            let pair = first.groupID.map { id in next.filter { $0.groupID == id } } ?? []
            session.showComparison(pair.count == 2 ? pair : [first])
            comparingHasFocus = true
        } else {
            session.showComparison([])
        }
    }

    private func undo() {
        guard model.undoQuickReview(), session.undoWasLater == later else { return }
        session.showComparison(session.undoComparison)
        if let focus = session.undoFocus { session.focusedID = focus }
        if !session.comparing.isEmpty { comparingHasFocus = true }
    }

    private func resetView() {
        session.clearSelection()
        session.showComparison([])
    }

    private func resetBatch(_ all: [QuickPhoto]) {
        resetView()
        if !later {
            session.considered.removeAll()
            model.nextQuickBatch(all.filter(matchesFilters))
        }
    }
}
