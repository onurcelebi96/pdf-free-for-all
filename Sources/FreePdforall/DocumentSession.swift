import AppKit
import PDFCore
import PDFKit
import SwiftUI
import UniformTypeIdentifiers

/// One open PDF, shown as one tab in the window.
///
/// A session owns everything that belongs to a single document: its pages, undo history,
/// unsaved-change state, page selection, split and Word previews, and the PDF view it is drawn in.
/// Keeping this state per session is what lets several PDFs stay open without mixing their edits.
@MainActor
final class DocumentSession: ObservableObject, Identifiable {
    enum Mode { case read, arrange }
    enum HighlightInk: String, CaseIterable {
        case yellow, green
        var title: String { self == .yellow ? "Yellow" : "Green" }
        var color: NSColor {
            self == .yellow
                ? NSColor(srgbRed: 1, green: 0.91, blue: 0.05, alpha: 0.55)
                : NSColor(srgbRed: 0.35, green: 0.95, blue: 0.25, alpha: 0.5)
        }
    }
    @Published var highlightActive = false
    @Published private(set) var highlightInk = HighlightInk(rawValue: UserDefaults.standard.string(forKey: "HighlightInk") ?? "yellow") ?? .yellow

    func activateHighlight(_ ink: HighlightInk) {
        highlightInk = ink
        UserDefaults.standard.set(ink.rawValue, forKey: "HighlightInk")
        mode = .read
        pdfViewStore.view?.clearSelection()
        highlightActive = true
    }


    private struct SavedPage {
        let index: Int
        let page: PDFPage
    }

    private enum UndoAction {
        case rotate(indices: [Int], degrees: Int)
        case restorePages([SavedPage])
        case move(from: Int, to: Int)
        case removeAnnotation(pageIndex: Int, annotation: PDFAnnotation)
        case removeHighlights([(Int, PDFAnnotation)])
    }

    private struct UndoEntry {
        let action: UndoAction
        let previousRevision: UUID
    }

    private static let protectedDestinationMessage = "Choose a different destination. Original source files are protected."

    let id = UUID()
    let document: PDFDocument
    let sourceName: String
    /// Canonical location of the file this tab was opened from. Opening the same file again focuses this tab.
    let openedURL: URL?
    /// Original input files. Save and export destinations that resolve to one of these are refused.
    let protectedSourceURLs: Set<URL>
    let pdfViewStore = PDFViewStore()
    /// Set by PDFWorkspace when the session joins the window; used for status messages and sheets.
    weak var workspace: PDFWorkspace?

    @Published var selectedPage = 0
    @Published var mode: Mode = .read
    @Published private(set) var hasUnsavedChanges = false
    @Published var splitRange = "1"
    @Published private(set) var splitPreview: PDFDocument?
    @Published private(set) var wordPreviewData: Data?
    @Published private(set) var wordPreviewText = ""
    @Published private(set) var wordPreviewName = "PDF document"
    @Published private(set) var pendingSignatureStrokes: [[CGPoint]] = []
    @Published private var pageEditUndo: [UndoEntry] = []
    private var generatedDocumentNeedsSave: Bool
    private var currentRevision = UUID()
    private var savedRevision: UUID

    init(document: PDFDocument, sourceName: String, openedURL: URL?, protectedSourceURLs: Set<URL>, needsSave: Bool) {
        self.document = document
        self.sourceName = sourceName
        self.openedURL = openedURL
        self.protectedSourceURLs = protectedSourceURLs
        self.generatedDocumentNeedsSave = needsSave
        self.savedRevision = self.currentRevision
        updateUnsavedChanges()
    }

    var pageCount: Int { document.pageCount }
    var canUndoPageEdit: Bool { !pageEditUndo.isEmpty }
    var signaturePageThumbnail: NSImage? {
        guard let page = document.page(at: selectedPage) else { return nil }
        return page.thumbnail(of: CGSize(width: 700, height: 900), for: .mediaBox)
    }

    // MARK: Navigation

    func selectPage(_ index: Int) {
        guard index >= 0, index < pageCount else { return }
        selectedPage = index
    }

    func stepPage(by offset: Int) {
        selectPage(selectedPage + offset)
    }

    func canStep(by offset: Int) -> Bool {
        let target = selectedPage + offset
        return target >= 0 && target < pageCount
    }

    // MARK: Reading and export

    func highlightSelectedText() {
        guard let selection = pdfViewStore.view?.currentSelection else { return }
        highlightSelection(selection)
    }

    func highlightSelection(_ selection: PDFSelection) {
        guard !(selection.string ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        var added: [(Int, PDFAnnotation)] = []
        for line in selection.selectionsByLine() {
            for page in line.pages {
                let bounds = line.bounds(for: page)
                guard !bounds.isEmpty, !bounds.isInfinite, !bounds.isNull, document.index(for: page) != NSNotFound else { continue }
                let annotation = PDFAnnotation(bounds: bounds, forType: .highlight, withProperties: nil)
                annotation.color = highlightInk.color
                page.addAnnotation(annotation)
                added.append((document.index(for: page), annotation))
            }
        }
        guard !added.isEmpty else { return }
        appendUndo(.removeHighlights(added))
        pdfViewStore.view?.clearSelection()
        objectWillChange.send()
        // Keep the persistent marker unobstructed; the tab dirty indicator confirms edits.
    }

    func exportPageImage() {
        guard let page = document.page(at: selectedPage) else { return }
        guard let png = try? DocumentConverter.pagePNGData(page) else {
            notify("Could not render this page as an image.")
            return
        }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "\(sourceName)-page-\(selectedPage + 1).png"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard !PDFFileSafety.wouldOverwriteSource(url, originals: protectedSourceURLs) else {
            notify(Self.protectedDestinationMessage)
            return
        }
        do {
            try png.write(to: url, options: .atomic)
            notify("Saved page \(selectedPage + 1) as PNG (up to 2400 pixels).")
        } catch {
            notify("Image export failed: \(error.localizedDescription)")
        }
    }

    @discardableResult
    func saveAs() -> Bool {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = "\(sourceName.isEmpty ? "PDF document" : sourceName)-edited.pdf"
        guard panel.runModal() == .OK, let url = panel.url else { return false }
        do {
            try saveCopy(to: url)
        } catch {
            notify(error.localizedDescription)
            return false
        }
        notify("Saved PDF copy.")
        return true
    }

    /// The same validated, atomic save used by the native panel, exposed for regression checks.
    func saveCopy(to url: URL) throws {
        guard !PDFFileSafety.wouldOverwriteSource(url, originals: protectedSourceURLs) else {
            throw NSError(domain: "PDFSave", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: Self.protectedDestinationMessage])
        }
        guard let data = document.dataRepresentation(),
              let verified = PDFDocument(data: data), verified.pageCount == document.pageCount else {
            throw NSError(domain: "PDFSave", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "Could not validate the PDF data for saving."])
        }
        do { try data.write(to: url, options: .atomic) }
        catch {
            throw NSError(domain: "PDFSave", code: 3,
                          userInfo: [NSLocalizedDescriptionKey: "Could not save this PDF: \(error.localizedDescription)"])
        }
        markSaved()
    }

    func printPDF() {
        guard let operation = document.printOperation(for: NSPrintInfo.shared,
                                                     scalingMode: .pageScaleDownToFit,
                                                     autoRotate: true) else {
            notify("macOS could not prepare this PDF for printing.")
            return
        }
        operation.run()
    }

    // MARK: Word conversion (PDF to Word)

    func convertPDFToWord() {
        do {
            let data = try DocumentConverter.pdfToWordData(document: document)
            wordPreviewData = data
            wordPreviewText = (0..<document.pageCount)
                .compactMap { document.page(at: $0)?.string?.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: "\n\n")
            wordPreviewName = sourceName.isEmpty ? "PDF document" : sourceName
            presentSheet(.wordReview)
        } catch {
            notify("Word export failed: \(error.localizedDescription)")
        }
    }

    @discardableResult
    func saveWordConversionCopy() -> Bool {
        guard let wordPreviewData else {
            notify("Create a Word preview first.")
            return false
        }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "docx") ?? .data]
        panel.nameFieldStringValue = wordPreviewName + ".docx"
        guard panel.runModal() == .OK, let url = panel.url else { return false }
        guard !PDFFileSafety.wouldOverwriteSource(url, originals: protectedSourceURLs) else {
            notify(Self.protectedDestinationMessage)
            return false
        }
        let readingOptions: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.officeOpenXML
        ]
        guard let verified = try? NSAttributedString(data: wordPreviewData, options: readingOptions,
                                                     documentAttributes: nil), verified.length > 0 else {
            notify("Could not validate the Word document for saving.")
            return false
        }
        do {
            try wordPreviewData.write(to: url, options: .atomic)
            presentSheet(nil)
            self.wordPreviewData = nil
            notify("Saved a text-first Word copy. Page layout and images are not preserved.")
            return true
        } catch {
            notify("Word export failed: \(error.localizedDescription)")
            return false
        }
    }

    func cancelWordPreview() {
        presentSheet(nil)
        wordPreviewData = nil
        wordPreviewText = ""
    }

    // MARK: Page editing

    func rotateSelected() {
        rotatePages([selectedPage], degrees: 90)
    }

    func deleteSelected() {
        deletePages([selectedPage])
    }

    func rotatePages(_ indices: [Int], degrees: Int) {
        let valid = PDFDocumentOperations.rotatePages(in: document, at: indices, by: degrees)
        guard !valid.isEmpty else { return }
        appendUndo(.rotate(indices: valid, degrees: -degrees))
        objectWillChange.send()
    }

    func deletePages(_ indices: [Int]) {
        let valid = Array(Set(indices.filter { $0 >= 0 && $0 < document.pageCount })).sorted(by: >)
        guard !valid.isEmpty else { return }
        guard valid.count < document.pageCount else {
            notify("Keep at least one page in the document.")
            return
        }
        let saved = valid.compactMap { index -> SavedPage? in
            guard let page = document.page(at: index) else { return nil }
            return SavedPage(index: index, page: page)
        }
        guard saved.count == valid.count else {
            notify("Could not safely prepare the selected page(s) for removal.")
            return
        }
        appendUndo(.restorePages(saved))
        for index in valid { document.removePage(at: index) }
        selectedPage = min(valid.min() ?? selectedPage, document.pageCount - 1)
        objectWillChange.send()
        notify("Removed \(valid.count) page(s). Choose Undo to restore them.")
    }

    func undoPageEdit() {
        guard let entry = pageEditUndo.popLast() else { return }
        switch entry.action {
        case .rotate(let indices, let degrees):
            _ = PDFDocumentOperations.rotatePages(in: document, at: indices, by: degrees)
        case .restorePages(let pages):
            for savedPage in pages.sorted(by: { $0.index < $1.index }) {
                document.insert(savedPage.page, at: min(savedPage.index, document.pageCount))
            }
            selectedPage = min(pages.first?.index ?? selectedPage, document.pageCount - 1)
        case .move(let from, let to):
            guard PDFDocumentOperations.movePage(in: document, from: from, to: to) else { return }
            selectedPage = to
        case .removeHighlights(let annotations):
            for (index, annotation) in annotations {
                document.page(at: index)?.removeAnnotation(annotation)
            }
        case .removeAnnotation(let pageIndex, let annotation):
            document.page(at: pageIndex)?.removeAnnotation(annotation)
        }
        currentRevision = entry.previousRevision
        objectWillChange.send()
        updateUnsavedChanges()
        notify("Last page change undone.")
    }

    func moveSelected(_ offset: Int) {
        movePage(from: selectedPage, to: selectedPage + offset)
    }

    func movePage(from sourceIndex: Int, to destinationIndex: Int) {
        guard sourceIndex >= 0, sourceIndex < document.pageCount,
              destinationIndex >= 0, destinationIndex < document.pageCount,
              sourceIndex != destinationIndex else { return }
        guard PDFDocumentOperations.movePage(in: document, from: sourceIndex, to: destinationIndex) else { return }
        appendUndo(.move(from: destinationIndex, to: sourceIndex))
        selectedPage = destinationIndex
        objectWillChange.send()
    }

    // MARK: Split and extract

    @discardableResult
    func createSplitPreview() -> Bool {
        guard let indices = PageRangeParser.parse(splitRange, pageCount: document.pageCount), !indices.isEmpty else {
            notify("Check the page range. Use values from 1 to \(document.pageCount), like 1-3, 5.")
            return false
        }
        guard let output = PDFDocumentOperations.extract(indices, from: document) else {
            notify("The selected pages could not be copied safely.")
            return false
        }
        splitPreview = output
        presentSheet(.splitReview)
        notify("Previewing \(indices.count) extracted page(s). Save a copy to finish.")
        return true
    }

    @discardableResult
    func saveSplitPreview() -> Bool {
        guard let splitPreview else {
            notify("Create a split preview first.")
            return false
        }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = "\(sourceName.isEmpty ? "PDF" : sourceName)-pages.pdf"
        guard panel.runModal() == .OK, let url = panel.url else { return false }
        guard !PDFFileSafety.wouldOverwriteSource(url, originals: protectedSourceURLs) else {
            notify(Self.protectedDestinationMessage)
            return false
        }
        guard let data = splitPreview.dataRepresentation(),
              let verified = PDFDocument(data: data), verified.pageCount == splitPreview.pageCount else {
            notify("Could not validate the extracted PDF pages for saving.")
            return false
        }
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            notify("Could not save the selected-page PDF: \(error.localizedDescription)")
            return false
        }
        self.splitPreview = nil
        presentSheet(nil)
        notify("Saved extracted pages as a separate PDF.")
        return true
    }

    func cancelSplitPreview() {
        splitPreview = nil
        presentSheet(nil)
    }

    // MARK: Signature

    func beginSignaturePlacement(_ strokes: [[CGPoint]]) {
        guard document.page(at: selectedPage) != nil, strokes.contains(where: { $0.count > 1 }) else {
            notify("Draw a signature with at least two points first.")
            return
        }
        pendingSignatureStrokes = strokes
        presentSheet(.signaturePlacement)
    }

    func cancelSignaturePlacement() {
        pendingSignatureStrokes = []
        presentSheet(nil)
    }

    func redrawSignature() {
        pendingSignatureStrokes = []
        presentSheet(.signature)
    }

    func applySignature(at normalizedRect: CGRect) {
        guard let page = document.page(at: selectedPage),
              pendingSignatureStrokes.contains(where: { $0.count > 1 }) else { return }
        let bounds = page.bounds(for: .mediaBox)
        let rect = normalizedRect.standardized
        let minX = min(max(rect.minX, 0), 0.94)
        let minY = min(max(rect.minY, 0), 0.94)
        let width = min(max(rect.width, 0.06), 1 - minX)
        let height = min(max(rect.height, 0.04), 1 - minY)
        let box = CGRect(x: bounds.minX + minX * bounds.width,
                         y: bounds.minY + (1 - minY - height) * bounds.height,
                         width: width * bounds.width,
                         height: height * bounds.height)
        let annotation = PDFAnnotation(bounds: box, forType: .ink, withProperties: nil)
        annotation.color = .black
        annotation.contents = "Handwritten signature"
        let border = PDFBorder()
        border.lineWidth = 2.2
        annotation.border = border
        for stroke in pendingSignatureStrokes where stroke.count > 1 {
            let path = NSBezierPath()
            for (i, point) in stroke.enumerated() {
                let mapped = CGPoint(x: point.x * box.width,
                                     y: (1 - point.y) * box.height)
                if i == 0 { path.move(to: mapped) } else { path.line(to: mapped) }
            }
            annotation.add(path)
        }
        page.addAnnotation(annotation)
        appendUndo(.removeAnnotation(pageIndex: selectedPage, annotation: annotation))
        pendingSignatureStrokes = []
        presentSheet(nil)
        objectWillChange.send()
        notify("Signature added to page \(selectedPage + 1). Save a copy to export it.")
    }

    // MARK: Undo and unsaved-change tracking

    private func appendUndo(_ action: UndoAction) {
        pageEditUndo.append(UndoEntry(action: action, previousRevision: currentRevision))
        currentRevision = UUID()
        if pageEditUndo.count > 50 { pageEditUndo.removeFirst() }
        updateUnsavedChanges()
    }

    private func markSaved() {
        generatedDocumentNeedsSave = false
        savedRevision = currentRevision
        updateUnsavedChanges()
    }

    private func updateUnsavedChanges() {
        hasUnsavedChanges = generatedDocumentNeedsSave || savedRevision != currentRevision
    }

    // MARK: Helpers

    /// Status messages are shown by the window, so they stay visible whichever screen is open.
    private func notify(_ message: String?) {
        workspace?.notice = message
    }

    /// Sheets are window-level, so the session asks the workspace to show or dismiss them.
    private func presentSheet(_ sheet: PDFWorkspace.Sheet?) {
        workspace?.activeSheet = sheet
    }
}
