import PDFKit
import SwiftUI

/// Split pages: choose the page numbers for the active document.
struct SplitSheet: View {
    @ObservedObject var session: DocumentSession
    @EnvironmentObject private var workspace: PDFWorkspace

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Split pages").font(.system(size: 18, weight: .semibold, design: .rounded)).foregroundStyle(DeskColors.ink)
            Text("Choose page numbers or ranges. The selected pages will be saved as a separate PDF.")
                .font(.system(size: 12)).foregroundStyle(DeskColors.secondary).fixedSize(horizontal: false, vertical: true)
            TextField("Example: 1–3, 5", text: $session.splitRange)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("Page numbers or ranges to extract")
                .accessibilityHint("Enter page numbers separated by commas, or ranges such as 1 to 3")
                .onSubmit { session.createSplitPreview() }
            if let notice = workspace.notice, notice.hasPrefix("Check the page range") {
                Text(notice).font(.system(size: 11)).foregroundStyle(DeskColors.destructive)
            }
            HStack {
                Spacer()
                Button("Cancel") { workspace.activeSheet = nil }
                Button("Preview extracted pages") { session.createSplitPreview() }
                    .keyboardShortcut(.defaultAction)
                    .tint(DeskColors.action)
            }
        }
        .padding(22).frame(width: 390).background(DeskColors.surface)
    }
}

/// Review the pages produced by a split before saving them.
struct SplitReviewSheet: View {
    @ObservedObject var session: DocumentSession
    @StateObject private var previewStore = PDFViewStore()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Review extracted pages").font(.system(size: 19, weight: .semibold, design: .rounded)).foregroundStyle(DeskColors.ink)
            Text(summary)
                .font(.system(size: 12)).foregroundStyle(DeskColors.secondary)
            if let preview = session.splitPreview {
                PDFCanvas(document: preview, selectedPage: 0, store: previewStore)
                    .frame(width: 560, height: 400).background(DeskColors.documentStage)
            }
            HStack {
                Button("Cancel") { session.cancelSplitPreview() }
                Spacer()
                Button("Save a copy…") { session.saveSplitPreview() }
                    .keyboardShortcut(.defaultAction).buttonStyle(.borderedProminent).tint(DeskColors.action)
            }
        }
        .padding(20).background(DeskColors.canvas)
    }

    private var summary: String {
        let count = session.splitPreview?.pageCount ?? 0
        return "\(count) \(count == 1 ? "page" : "pages") · The original document remains unchanged"
    }
}

/// Review the plain-text Word export before saving it.
struct WordReviewSheet: View {
    @ObservedObject var session: DocumentSession

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            Text("Review Word export").font(.system(size: 19, weight: .semibold, design: .rounded)).foregroundStyle(DeskColors.ink)
            Text("Text-first export · Page layout, images, and tables may not be preserved. Scanned pages need OCR.")
                .font(.system(size: 12)).foregroundStyle(DeskColors.warning).fixedSize(horizontal: false, vertical: true)
            ScrollView {
                Text(session.wordPreviewText.isEmpty ? "No selectable text was found." : session.wordPreviewText)
                    .font(.system(size: 12)).foregroundStyle(DeskColors.ink).frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled).padding(12)
            }
            .frame(minHeight: 180, maxHeight: 360)
            .background(DeskColors.surface, in: RoundedRectangle(cornerRadius: 8))
            HStack {
                Button("Cancel") { session.cancelWordPreview() }
                Spacer()
                Button("Save Word copy…") { session.saveWordConversionCopy() }
                    .keyboardShortcut(.defaultAction).buttonStyle(.borderedProminent).tint(DeskColors.action)
                    .disabled(session.wordPreviewData == nil)
            }
        }
        .padding(20).frame(width: 580).background(DeskColors.canvas)
    }
}

/// Merge: order the chosen PDFs. Shown from Home or from an open document; the result opens in a new tab.
struct CombineReviewSheet: View {
    @EnvironmentObject private var workspace: PDFWorkspace

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Combine PDFs").font(.system(size: 20, weight: .semibold, design: .rounded)).foregroundStyle(DeskColors.ink)
                Text("Set the order for the combined document. Your source files stay unchanged.")
                    .font(.system(size: 12)).foregroundStyle(DeskColors.secondary)
            }
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(workspace.combineSources.indices, id: \.self) { index in
                        let source = workspace.combineSources[index]
                        HStack(spacing: 12) {
                            Text("\(index + 1)").font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(DeskColors.action).frame(width: 26, height: 26)
                                .background(DeskColors.selection, in: Circle())
                            VStack(alignment: .leading, spacing: 3) {
                                Text(source.name).font(.system(size: 12, weight: .medium)).foregroundStyle(DeskColors.ink).lineLimit(1)
                                Text(source.pageCount == 1 ? "1 page" : "\(source.pageCount) pages")
                                    .font(.system(size: 10)).foregroundStyle(DeskColors.secondary)
                            }
                            Spacer(minLength: 4)
                            Button { workspace.moveCombineSource(index, by: -1) } label: { Image(systemName: "arrow.up") }
                                .disabled(index == 0).accessibilityLabel("Move \(source.name) earlier")
                            Button { workspace.moveCombineSource(index, by: 1) } label: { Image(systemName: "arrow.down") }
                                .disabled(index == workspace.combineSources.count - 1).accessibilityLabel("Move \(source.name) later")
                            Button { workspace.removeCombineSource(index) } label: { Image(systemName: "xmark") }
                                .tint(DeskColors.destructive).accessibilityLabel("Remove \(source.name)")
                        }
                        .buttonStyle(.bordered).controlSize(.small)
                        .padding(10).background(DeskColors.surface, in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
            .frame(minHeight: 90, maxHeight: 310)
            Button { workspace.addMoreCombineSources() } label: { Label("Add PDFs", systemImage: "plus") }
                .buttonStyle(.plain).foregroundStyle(DeskColors.action)
            if workspace.combineSources.count < 2 {
                Text("Add at least one more readable PDF to continue.")
                    .font(.system(size: 11)).foregroundStyle(DeskColors.warning)
            }
            HStack {
                Spacer()
                Button("Cancel") { workspace.activeSheet = nil; workspace.combineSources = [] }
                Button("Create combined PDF") { workspace.confirmCombine() }
                    .keyboardShortcut(.defaultAction).tint(DeskColors.action)
                    .disabled(workspace.combineSources.count < 2)
            }
        }
        .padding(22).frame(width: 500).background(DeskColors.canvas)
    }
}
