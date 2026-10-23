import AppKit
import Combine
import PDFCore
import PDFKit
import SwiftUI
import UniformTypeIdentifiers

/// Window-level controller. Owns the open document tabs, decides which one is active,
/// and holds the sheets and status message that are shared across the window.
/// Document-specific state lives in `DocumentSession`.
@MainActor
final class PDFWorkspace: ObservableObject {
    enum Sheet: String, Identifiable {
        case signature, signaturePlacement, split, splitReview, combineReview, wordReview
        var id: String { rawValue }
    }

    enum HomeTask { case organize, split, sign, exportImage, wordExport, printDocument }

    struct CombineSource: Identifiable {
        let id = UUID()
        let name: String
        let document: PDFDocument
        let sourceURLs: Set<URL>
        var pageCount: Int { document.pageCount }
    }

    @Published private(set) var sessions: [DocumentSession] = []
    /// nil means the Home screen is showing.
    @Published private(set) var activeSessionID: UUID?
    @Published var activeSheet: Sheet?
    @Published var notice: String?
    @Published var combineSources: [CombineSource] = []
    /// Tab waiting for a save-or-discard decision before it closes.
    @Published var closeConfirmationID: UUID?

    private var sessionObservers: [UUID: AnyCancellable] = [:]

    var active: DocumentSession? {
        sessions.first { $0.id == activeSessionID }
    }

    var isHome: Bool { active == nil }

    var closeConfirmationBinding: Binding<Bool> {
        Binding(get: { self.closeConfirmationID != nil },
                set: { if !$0 { self.closeConfirmationID = nil } })
    }

    var unsavedSessions: [DocumentSession] { sessions.filter(\.hasUnsavedChanges) }

    /// Used by both the native close button and Command-Q. Canceling a save also cancels closing.
    func confirmClosingDocuments() -> Bool {
        for session in unsavedSessions {
            let alert = NSAlert()
            alert.messageText = "Save changes to \(session.sourceName)?"
            alert.informativeText = "This document has unsaved changes. Your original file is unchanged."
            alert.addButton(withTitle: "Save a copy")
            alert.addButton(withTitle: "Cancel")
            alert.addButton(withTitle: "Discard changes")
            switch alert.runModal() {
            case .alertFirstButtonReturn:
                guard session.saveAs() else { return false }
            case .alertThirdButtonReturn: continue
            default: return false
            }
        }
        return true
    }

    // MARK: Tabs

    func activate(_ id: UUID) {
        guard sessions.contains(where: { $0.id == id }), activeSessionID != id else { return }
        activeSessionID = id
        notice = nil
    }

    func showHome() {
        activeSessionID = nil
        notice = nil
    }

    func resumeLastDocument() {
        guard let last = sessions.last else { return }
        activate(last.id)
    }

    /// Moves to the next or previous tab, wrapping around. From Home, forward starts at the first tab.
    func cycleTabs(by offset: Int) {
        guard !sessions.isEmpty else { return }
        let count = sessions.count
        let current = sessions.firstIndex(where: { $0.id == activeSessionID }) ?? (offset > 0 ? -1 : count)
        let next = ((current + offset) % count + count) % count
        activate(sessions[next].id)
    }

    func closeActiveTab() {
        guard let id = activeSessionID else { return }
        close(id)
    }

    /// Closes a tab, asking first when it has changes that would be lost.
    func close(_ id: UUID) {
        guard let session = sessions.first(where: { $0.id == id }) else { return }
        if session.hasUnsavedChanges {
            activate(id)
            closeConfirmationID = id
        } else {
            remove(id)
        }
    }

    func saveAndClose(_ id: UUID) {
        closeConfirmationID = nil
        guard let session = sessions.first(where: { $0.id == id }) else { return }
        activate(id)
        if session.saveAs() {
            remove(id)
        }
    }

    /// Removes a tab without asking. When the active tab closes, its right-hand neighbour takes over,
    /// or the left-hand one if it was last; with no tabs left, Home is shown.
    func remove(_ id: UUID) {
        guard let index = sessions.firstIndex(where: { $0.id == id }) else { return }
        let wasActive = activeSessionID == id
        sessions.remove(at: index)
        sessionObservers[id] = nil
        if closeConfirmationID == id { closeConfirmationID = nil }
        if wasActive {
            activeSessionID = sessions.isEmpty ? nil : sessions[min(index, sessions.count - 1)].id
            notice = nil
        }
    }

    private func add(_ session: DocumentSession) {
        session.workspace = self
        // Forward each document's changes so the window (tab strip, commands, toolbars) refreshes.
        sessionObservers[session.id] = session.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
        sessions.append(session)
        activate(session.id)
    }

    // MARK: Opening files

    func openPDFs() {
        openSelectedPDFs(allowingMultiple: true)
    }

    /// Shows the open panel and opens the chosen files, each in its own tab.
    @discardableResult
    func openSelectedPDFs(allowingMultiple: Bool) -> DocumentSession? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf]
        panel.allowsMultipleSelection = allowingMultiple
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, !panel.urls.isEmpty else { return nil }
        return openFiles(panel.urls)
    }

    /// Opens files as tabs. A file that is already open just brings its tab forward.
    /// Returns the last tab that was opened or focused.
    @discardableResult
    func openFiles(_ urls: [URL]) -> DocumentSession? {
        var lastOpened: DocumentSession?
        var failedNames: [String] = []
        for url in urls {
            let canonical = PDFFileSafety.canonicalURL(url)
            if let existing = sessions.first(where: { $0.openedURL == canonical }) {
                lastOpened = existing
                continue
            }
            guard let opened = PDFDocument(url: url), !opened.isLocked, opened.pageCount > 0 else {
                failedNames.append(url.lastPathComponent)
                continue
            }
            let session = DocumentSession(document: opened,
                                          sourceName: url.deletingPathExtension().lastPathComponent,
                                          openedURL: canonical,
                                          protectedSourceURLs: [canonical],
                                          needsSave: false)
            add(session)
            lastOpened = session
        }
        if let lastOpened { activate(lastOpened.id) }
        notice = failedNames.isEmpty
            ? nil
            : "Could not open \(failedNames.joined(separator: ", ")). It may be damaged, encrypted, or have no readable pages."
        return lastOpened
    }

    /// Home-screen shortcuts open a file first, then start the chosen task on its tab.
    func startHomeTask(_ task: HomeTask) {
        guard let session = openSelectedPDFs(allowingMultiple: false) else { return }
        switch task {
        case .organize: session.mode = .arrange
        case .split: activeSheet = .split
        case .sign: activeSheet = .signature
        case .exportImage: session.exportPageImage()
        case .wordExport: session.convertPDFToWord()
        case .printDocument: session.printPDF()
        }
    }

    func convertWordToPDF() {
        do {
            guard let preview = try DocumentConverter.wordToPDF() else { return }
            add(DocumentSession(document: preview.document,
                                sourceName: preview.sourceName,
                                openedURL: nil,
                                protectedSourceURLs: [PDFFileSafety.canonicalURL(preview.sourceURL)],
                                needsSave: true))
            notice = "Review the converted PDF, then choose Save a copy. Formatting may differ from Word."
        } catch {
            notice = "Word conversion failed: \(error.localizedDescription)"
        }
    }

    // MARK: Combine

    func addPDFs() {
        prepareCombine(includeCurrentDocument: active != nil)
    }

    func startCombineFromHome() {
        prepareCombine(includeCurrentDocument: false)
    }

    func prepareCombine(includeCurrentDocument: Bool) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, !panel.urls.isEmpty else { return }
        var sources: [CombineSource] = []
        if includeCurrentDocument, let current = active {
            sources.append(CombineSource(name: current.sourceName.isEmpty ? "Current PDF" : current.sourceName,
                                         document: current.document,
                                         sourceURLs: current.protectedSourceURLs))
        }
        var skipped = 0
        for url in panel.urls {
            guard let incoming = PDFDocument(url: url), !incoming.isLocked, incoming.pageCount > 0 else { skipped += 1; continue }
            sources.append(CombineSource(name: url.lastPathComponent, document: incoming,
                                         sourceURLs: [PDFFileSafety.canonicalURL(url)]))
        }
        guard !sources.isEmpty else { notice = "No readable PDF pages were selected."; return }
        combineSources = sources
        activeSheet = .combineReview
        notice = skipped == 0 ? nil : "Could not read \(skipped) selected file(s); they were left out."
    }

    func addMoreCombineSources() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK else { return }
        var skipped = 0
        for url in panel.urls {
            guard let incoming = PDFDocument(url: url), !incoming.isLocked, incoming.pageCount > 0 else { skipped += 1; continue }
            combineSources.append(CombineSource(name: url.lastPathComponent, document: incoming,
                                                sourceURLs: [PDFFileSafety.canonicalURL(url)]))
        }
        if skipped > 0 { notice = "Could not read \(skipped) selected file(s); they were left out." }
    }

    func moveCombineSource(_ index: Int, by offset: Int) {
        let destination = index + offset
        guard combineSources.indices.contains(index), combineSources.indices.contains(destination) else { return }
        let source = combineSources.remove(at: index)
        combineSources.insert(source, at: destination)
    }

    func removeCombineSource(_ index: Int) {
        guard combineSources.indices.contains(index) else { return }
        combineSources.remove(at: index)
    }

    /// The combined result opens as a new tab, so the source tabs stay as they were.
    func confirmCombine() {
        guard combineSources.count >= 2 else {
            notice = "Choose at least two readable PDFs to combine."
            return
        }
        guard let combined = PDFDocumentOperations.combine(combineSources.map(\.document)) else {
            notice = "The selected PDF pages could not be copied safely."
            return
        }
        let protectedURLs = combineSources.reduce(into: Set<URL>()) { $0.formUnion($1.sourceURLs) }
        add(DocumentSession(document: combined,
                            sourceName: "Combined PDF",
                            openedURL: nil,
                            protectedSourceURLs: protectedURLs,
                            needsSave: true))
        activeSheet = nil
        notice = "Combined \(combineSources.count) PDFs. Review the result, then save a copy."
        combineSources = []
    }
}
