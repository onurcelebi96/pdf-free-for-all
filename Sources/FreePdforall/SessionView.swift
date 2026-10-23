import AppKit
import PDFKit
import SwiftUI
import UniformTypeIdentifiers

/// The screen for one open document. WorkspaceView creates it per tab with `.id(session.id)`,
/// so search, page selection and thumbnail state start fresh whenever the user switches tabs.
struct SessionView: View {
    @ObservedObject var session: DocumentSession
    @EnvironmentObject private var workspace: PDFWorkspace
    @State private var pageSelection: Set<Int> = []
    @State private var draggedPageIndex: Int?
    @State private var pageNavigatorVisible = false
    @State private var quickToolsVisible = false
    @State private var highlightOptionsVisible = false
    @State private var findVisible = false
    @State private var findQuery = ""
    @State private var lastFindQuery = ""
    @StateObject private var search = PDFSearchController()
    @StateObject private var thumbnails = PDFThumbnailCache()
    @State private var matchIndex = -1
    @FocusState private var findFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            documentHeader
            Divider().overlay(DeskColors.divider)
            if session.mode == .read {
                readView
            } else {
                arrangeView
            }
        }
        .background(DeskColors.canvas)
        .popover(isPresented: $highlightOptionsVisible) { highlightOptions }
        .onAppear { pageSelection = [session.selectedPage] }
        .onChange(of: findQuery) { _, _ in
            search.cancel(); lastFindQuery = ""; matchIndex = -1
        }
        .onChange(of: search.matches.count) { _, count in
            if count > 0 && matchIndex < 0 { showMatch(at: 0) }
        }
        .onChange(of: search.isSearching) { _, running in
            if !running && !lastFindQuery.isEmpty && search.matches.isEmpty {
                workspace.notice = "No matches. Scanned pages need OCR to search text."
            }
        }
        .onChange(of: session.pageCount) { _, _ in
            pageSelection = [session.selectedPage]
            search.cancel(); matchIndex = -1; lastFindQuery = ""
        }
        .onDisappear { search.cancel() }
    }

    private var documentHeader: some View {
        HStack(spacing: 18) {
            Button {
                session.mode = .read
                quickToolsVisible.toggle()
            } label: {
                Label("All tools", systemImage: "square.grid.2x2")
                    .foregroundStyle(quickToolsVisible ? DeskColors.action : DeskColors.ink)
            }
            .help("Show or hide all tools")
            .accessibilityValue(quickToolsVisible ? "Expanded" : "Collapsed")

            Menu("Edit") {
                Button("Organize pages") {
                    pageSelection = [session.selectedPage]
                    session.mode = .arrange
                }
                Button("Read document") { session.mode = .read }
                Divider()
                Button("Highlight…") { highlightOptionsVisible = true }
                Button("Rotate current page") { session.rotateSelected() }
                Button("Undo PDF change") { session.undoPageEdit() }
                    .disabled(!session.canUndoPageEdit)
                Divider()
                Button("Merge PDFs…") { workspace.addPDFs() }
                Button("Split & extract…") { workspace.activeSheet = .split }
            }
            .fixedSize()
            Menu("Convert") {
                Button("Word to PDF…") { workspace.convertWordToPDF() }
                Button("PDF to Word…") { session.convertPDFToWord() }
                Button("Export page image…") { session.exportPageImage() }
            }
            .fixedSize()
            Menu("Sign") {
                Button("Draw a signature…") { workspace.activeSheet = .signature }
            }
            .fixedSize()
            if session.mode == .arrange {
                Button("Back to reading") { session.mode = .read }
                    .foregroundStyle(DeskColors.action)
            }
            Spacer(minLength: 4)
            Button {
                findVisible.toggle()
            } label: {
                Label("Find in page", systemImage: "magnifyingglass")
                    .labelStyle(.titleAndIcon)
            }
            .keyboardShortcut("f", modifiers: .command)
            .help("Find in page (⌘F)")
            .popover(isPresented: $findVisible, arrowEdge: .bottom) {
                findPopover
            }
            Rectangle().fill(DeskColors.divider).frame(width: 1, height: 16)
            Button { session.saveAs() } label: { Image(systemName: "square.and.arrow.down") }
                .help("Save a copy (⌘S)").accessibilityLabel("Save a copy")
            Button { session.printPDF() } label: { Image(systemName: "printer") }
                .help("Print").accessibilityLabel("Print")
        }
        .buttonStyle(.plain)
        .menuStyle(.borderlessButton)
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(DeskColors.ink)
        .controlSize(.small)
        .padding(.horizontal, 18)
        .frame(height: 40)
        .background(DeskColors.surface)
    }

    private var findPopover: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(DeskColors.secondary)
                TextField("Find in page", text: $findQuery)
                    .textFieldStyle(.plain)
                    .focused($findFocused)
                    .onSubmit { findText() }
                    .accessibilityLabel("Find in page")
                Button { findVisible = false } label: { Image(systemName: "xmark") }
                    .buttonStyle(.plain).accessibilityLabel("Close search")
            }
            .padding(9)
            .background(DeskColors.canvas, in: RoundedRectangle(cornerRadius: 6))
            HStack(spacing: 12) {
                if search.isSearching {
                    ProgressView().controlSize(.mini).accessibilityLabel("Searching PDF")
                }
                Text(findQuery.isEmpty ? "Search text in this PDF" :
                     lastFindQuery == findQuery ? "\(search.matches.isEmpty ? 0 : matchIndex + 1) of \(search.matches.count)" : "Press Return to search")
                    .foregroundStyle(DeskColors.secondary).monospacedDigit()
                Spacer()
                Button { findText(backward: true) } label: { Image(systemName: "chevron.up") }
                    .accessibilityLabel("Previous match")
                Button { findText() } label: { Image(systemName: "chevron.down") }
                    .accessibilityLabel("Next match")
            }
            .buttonStyle(.plain)
        }
        .font(.system(size: 12))
        .padding(14)
        .frame(width: 300)
        .background(DeskColors.surface)
        .onAppear { findFocused = true }
        .onExitCommand { findVisible = false }
    }

    private func findText(backward: Bool = false) {
        guard !findQuery.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        if lastFindQuery != findQuery {
            matchIndex = -1
            lastFindQuery = findQuery
            workspace.notice = nil
            search.start(findQuery, in: session.document)
            return
        }
        guard !search.matches.isEmpty else { return }
        let index = (matchIndex + (backward ? -1 : 1) + search.matches.count) % search.matches.count
        showMatch(at: index)
    }

    private func showMatch(at index: Int) {
        guard search.matches.indices.contains(index) else { return }
        matchIndex = index
        let match = search.matches[index]
        if let page = match.pages.first { session.selectPage(session.document.index(for: page)) }
        session.pdfViewStore.view?.setCurrentSelection(match, animate: true)
        session.pdfViewStore.view?.go(to: match)
    }

    private var readView: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                if quickToolsVisible {
                    quickToolsPanel.frame(width: min(218, max(190, geometry.size.width * 0.21)))
                }
                readerCanvas.frame(maxWidth: .infinity, maxHeight: .infinity)
                if pageNavigatorVisible {
                    pageNavigator.frame(width: min(190, max(154, geometry.size.width * 0.17)))
                }
            }
            .background(DeskColors.documentStage)
            .animation(.easeInOut(duration: 0.18), value: pageNavigatorVisible)
            .animation(.easeInOut(duration: 0.18), value: quickToolsVisible)
        }
    }

    private var pageNavigator: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Pages").font(.system(size: 12, weight: .semibold))
                Text("\(session.pageCount)").font(.system(size: 11)).foregroundStyle(DeskColors.secondary)
                Spacer()
                Button { pageNavigatorVisible = false } label: { Image(systemName: "xmark") }
                    .buttonStyle(.plain).accessibilityLabel("Close page thumbnails")
            }
            .padding(13)

            Rectangle().fill(DeskColors.divider).frame(height: 1)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(0..<session.pageCount, id: \.self) { index in
                            PageNavigatorRow(document: session.document, cache: thumbnails, index: index,
                                             selected: session.selectedPage == index) {
                                session.selectPage(index)
                            }
                            .id(index)
                        }
                    }
                    .padding(9)
                }
                .onChange(of: session.selectedPage) { _, page in
                    withAnimation(.easeInOut(duration: 0.18)) { proxy.scrollTo(page, anchor: .center) }
                }
            }
        }
        .background(DeskColors.navigator)
        .overlay(alignment: .leading) { Rectangle().fill(DeskColors.divider).frame(width: 1) }
    }

    private var readerCanvas: some View {
        VStack(spacing: 0) {
            PDFCanvas(document: session.document, selectedPage: session.selectedPage,
                      store: session.pdfViewStore, highlightEnabled: session.highlightActive,
                      onHighlight: { [weak session] selection in session?.highlightSelection(selection) },
                      onEndHighlight: { [weak session] in session?.highlightActive = false },
                      onPageChange: { session.selectPage($0) })
                .background(DeskColors.documentStage)
            HStack(spacing: 12) {
                Button { pageNavigatorVisible.toggle() } label: { Image(systemName: "sidebar.right") }
                    .accessibilityLabel("Page thumbnails").help("Show or hide page thumbnails")
                    .foregroundStyle(pageNavigatorVisible ? DeskColors.action : DeskColors.secondary)
                if session.highlightActive {
                    Label(session.highlightInk.title, systemImage: "highlighter")
                        .font(.system(size: 11, weight: .medium))
                    Circle().fill(Color(nsColor: session.highlightInk.color.withAlphaComponent(1)))
                        .frame(width: 10, height: 10).accessibilityHidden(true)
                    Button("Done") { session.highlightActive = false }
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(DeskColors.action)
                        .help("Stop highlighting (Escape)")
                }
                Spacer(minLength: 6)
                Button { session.stepPage(by: -1) } label: { Image(systemName: "chevron.left") }
                    .accessibilityLabel("Previous page").help("Previous page")
                    .disabled(!session.canStep(by: -1))
                Text("Page \(session.selectedPage + 1) of \(session.pageCount)")
                    .font(.system(size: 11, weight: .medium, design: .rounded)).monospacedDigit()
                    .foregroundStyle(DeskColors.ink).frame(minWidth: 112)
                    .accessibilityLabel("Page navigation")
                    .accessibilityValue("Page \(session.selectedPage + 1) of \(session.pageCount)")
                Button { session.stepPage(by: 1) } label: { Image(systemName: "chevron.right") }
                    .accessibilityLabel("Next page").help("Next page")
                    .disabled(!session.canStep(by: 1))
                Spacer(minLength: 6)
                Button {
                    guard let view = session.pdfViewStore.view else { return }
                    view.autoScales = false
                    view.zoomOut(nil)
                } label: {
                    Image(systemName: "minus.magnifyingglass")
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Zoom out").help("Zoom out")
                Button {
                    guard let view = session.pdfViewStore.view else { return }
                    view.autoScales = false
                    view.zoomIn(nil)
                } label: {
                    Image(systemName: "plus.magnifyingglass")
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Zoom in").help("Zoom in")
                Button {
                    guard let view = session.pdfViewStore.view else { return }
                    view.autoScales = true
                    view.scaleFactor = view.scaleFactorForSizeToFit
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Fit page").help("Fit page")
            }
            .padding(.horizontal, 16)
            .buttonStyle(.plain).foregroundStyle(DeskColors.ink)
            .frame(maxWidth: .infinity).frame(height: 32)
            .background(DeskColors.surface)
            .overlay(alignment: .top) { Rectangle().fill(DeskColors.divider).frame(height: 1) }
            if let notice = workspace.notice {
                HStack(spacing: 9) {
                    Image(systemName: "info.circle")
                    Text(notice).lineLimit(2)
                    Spacer(minLength: 6)
                    Button { workspace.notice = nil } label: { Image(systemName: "xmark") }
                        .buttonStyle(.plain).accessibilityLabel("Dismiss message")
                }
                .font(.system(size: 10)).foregroundStyle(DeskColors.secondary)
                .accessibilityElement(children: .combine)
                .padding(.horizontal, 14).padding(.vertical, 8).background(DeskColors.surface)
            }
        }
    }

    private var quickToolsPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("All tools").font(.system(size: 12, weight: .semibold))
                Spacer()
                Button { quickToolsVisible = false } label: { Image(systemName: "xmark") }
                    .buttonStyle(.plain).accessibilityLabel("Close all tools")
            }
            .padding(14)
            Rectangle().fill(DeskColors.divider).frame(height: 1)
            ScrollView {
                VStack(spacing: 6) {
                    QuickToolRow(title: "Organize pages", symbol: "square.grid.2x2") {
                        pageSelection = [session.selectedPage]
                        session.mode = .arrange
                    }
                    QuickToolRow(title: "Merge PDFs", symbol: "square.stack.3d.up") { workspace.addPDFs() }
                    QuickToolRow(title: "Split pages", symbol: "scissors") { workspace.activeSheet = .split }
                    QuickToolRow(title: "Word to PDF", symbol: "doc.text") { workspace.convertWordToPDF() }
                    QuickToolRow(title: "PDF to Word", symbol: "doc.richtext") { session.convertPDFToWord() }
                    QuickToolRow(title: "Add signature", symbol: "signature") { workspace.activeSheet = .signature }
                    QuickToolRow(title: "Highlight text", symbol: "highlighter") { highlightOptionsVisible = true }
                    QuickToolRow(title: "Export page image", symbol: "photo") { session.exportPageImage() }
                    QuickToolRow(title: "Print", symbol: "printer") { session.printPDF() }
                }
                .padding(9)
            }
            Spacer(minLength: 0)
            HStack(alignment: .top, spacing: 7) {
                Image(systemName: "lock.shield.fill").foregroundStyle(DeskColors.success)
                Text("Files are handled locally on this Mac.")
                    .font(.system(size: 9)).foregroundStyle(DeskColors.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
        }
        .background(DeskColors.navigator)
        .overlay(alignment: .trailing) { Rectangle().fill(DeskColors.divider).frame(width: 1) }
    }

    private var highlightOptions: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Highlight text").font(.system(size: 15, weight: .semibold))
            Text("Choose once, then drag across text to keep highlighting.")
                .font(.system(size: 12)).foregroundStyle(DeskColors.secondary)
            HStack(spacing: 12) {
                ForEach(DocumentSession.HighlightInk.allCases, id: \.self) { ink in
                    Button {
                        session.activateHighlight(ink)
                        quickToolsVisible = false
                        highlightOptionsVisible = false
                    } label: {
                        HStack(spacing: 8) {
                            Circle().fill(Color(nsColor: ink.color.withAlphaComponent(1)))
                                .frame(width: 18, height: 18)
                            Text(ink.title)
                            if session.highlightInk == ink { Image(systemName: "checkmark") }
                        }
                        .padding(10)
                        .background(DeskColors.canvas, in: RoundedRectangle(cornerRadius: 7))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Use \(ink.title.lowercased()) highlighter")
                }
            }
            if session.highlightActive {
                Button("Stop highlighting") {
                    session.highlightActive = false
                    highlightOptionsVisible = false
                }
            }
            Text("Done or Escape returns to normal selection. Scanned image text requires OCR.")
                .font(.system(size: 11)).foregroundStyle(DeskColors.secondary)
        }
        .padding(20).frame(width: 330)
        .background(DeskColors.surface)
    }

    private var arrangeView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text("\(pageSelection.count) selected").font(.system(size: 12, weight: .semibold))
                Spacer(minLength: 8)
                Button { movePageSelection(-1) } label: { Image(systemName: "arrow.left") }
                    .disabled(pageSelection.count != 1 || pageSelection.first == 0).help("Move earlier").accessibilityLabel("Move earlier")
                Button { movePageSelection(1) } label: { Image(systemName: "arrow.right") }
                    .disabled(pageSelection.count != 1 || pageSelection.first == session.pageCount - 1).help("Move later").accessibilityLabel("Move later")
                Button { session.rotatePages(Array(pageSelection), degrees: -90) } label: { Image(systemName: "rotate.left") }
                    .disabled(pageSelection.isEmpty).help("Rotate left").accessibilityLabel("Rotate left")
                Button { session.rotatePages(Array(pageSelection), degrees: 90) } label: { Image(systemName: "rotate.right") }
                    .disabled(pageSelection.isEmpty).help("Rotate right").accessibilityLabel("Rotate right")
                Divider().frame(height: 20)
                Button {
                    session.splitRange = pageSelection.sorted().map { String($0 + 1) }.joined(separator: ", ")
                    workspace.activeSheet = .split
                } label: { Label("Extract", systemImage: "scissors") }.disabled(pageSelection.isEmpty)
                Button { session.deletePages(Array(pageSelection)) } label: { Label("Delete", systemImage: "trash") }
                    .tint(DeskColors.destructive).disabled(pageSelection.isEmpty || pageSelection.count == session.pageCount)
                Button("Undo") { session.undoPageEdit() }.disabled(!session.canUndoPageEdit)
                Button("Select all") { pageSelection = Set(0..<session.pageCount) }
            }
            .foregroundStyle(DeskColors.ink).buttonStyle(.bordered).controlSize(.small)
            .padding(.horizontal, 24).padding(.vertical, 12).background(DeskColors.surface)
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 185, maximum: 260), spacing: 22)], spacing: 22) {
                    ForEach(0..<session.pageCount, id: \.self) { index in
                        ArrangePageCard(document: session.document, cache: thumbnails, index: index,
                                        selected: pageSelection.contains(index),
                                        session: session, draggedPageIndex: $draggedPageIndex,
                                        pageSelection: $pageSelection) {
                            if NSEvent.modifierFlags.contains(.command) {
                                if pageSelection.contains(index) { pageSelection.remove(index) } else { pageSelection.insert(index) }
                            } else {
                                pageSelection = [index]
                                session.selectPage(index)
                            }
                        }
                    }
                }
                .padding(26)
                .frame(maxWidth: 1180)
                .frame(maxWidth: .infinity)
            }
            .background(DeskColors.documentStage)
        }
    }

    private func movePageSelection(_ direction: Int) {
        guard pageSelection.count == 1, let index = pageSelection.first else { return }
        session.selectPage(index)
        session.moveSelected(direction)
        pageSelection = [session.selectedPage]
    }
}

/// Draws one document in a PDFView. Each tab gets its own instance.
struct PDFCanvas: NSViewRepresentable {
    let document: PDFDocument
    let selectedPage: Int
    let store: PDFViewStore
    var highlightEnabled = false
    var onHighlight: ((PDFSelection) -> Void)? = nil
    var onEndHighlight: (() -> Void)? = nil
    var onPageChange: ((Int) -> Void)? = nil

    final class Coordinator {
        var parent: PDFCanvas
        var observer: NSObjectProtocol?
        init(_ parent: PDFCanvas) { self.parent = parent }
        deinit { if let observer { NotificationCenter.default.removeObserver(observer) } }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> PDFView {
        let view = store.view ?? HighlightPDFView(frame: .zero)
        if store.view == nil { view.autoScales = true }
        view.displayMode = document.pageCount == 1 ? .singlePage : .singlePageContinuous
        view.displayDirection = .vertical
        view.backgroundColor = NSColor.clear
        store.view = view
        context.coordinator.observer = NotificationCenter.default.addObserver(forName: .PDFViewPageChanged, object: view, queue: .main) { [weak coordinator = context.coordinator, weak view] _ in
            DispatchQueue.main.async {
                guard let coordinator, let view, let page = view.currentPage,
                      view.document === coordinator.parent.document else { return }
                let index = coordinator.parent.document.index(for: page)
                if index != NSNotFound { coordinator.parent.onPageChange?(index) }
            }
        }
        return view
    }

    func updateNSView(_ view: PDFView, context: Context) {
        context.coordinator.parent = self
        if let markerView = view as? HighlightPDFView {
            markerView.highlightEnabled = highlightEnabled
            markerView.onHighlightSelection = onHighlight
            markerView.onEndHighlight = onEndHighlight
        }
        let documentChanged = view.document !== document
        if documentChanged {
            view.displayMode = document.pageCount == 1 ? .singlePage : .singlePageContinuous
            view.document = document
        }
        if let page = document.page(at: selectedPage), documentChanged || view.currentPage !== page {
            view.go(to: page)
        }
        store.view = view
    }
}

private struct PageNavigatorRow: View {
    let document: PDFDocument
    let cache: PDFThumbnailCache
    let index: Int
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                if let image = cache.image(document: document, index: index, size: CGSize(width: 98, height: 128)) {
                    Image(nsImage: image)
                        .resizable().aspectRatio(contentMode: .fit)
                        .frame(width: 49, height: 64)
                        .background(DeskColors.documentSheet)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                        .overlay(RoundedRectangle(cornerRadius: 3).stroke(DeskColors.divider.opacity(0.6), lineWidth: 0.6))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Page \(index + 1)")
                        .font(.system(size: 10, weight: selected ? .semibold : .medium))
                        .foregroundStyle(DeskColors.ink)
                    if selected {
                        Text("CURRENT")
                            .font(.system(size: 8, weight: .bold, design: .rounded)).tracking(0.7)
                            .foregroundStyle(DeskColors.action)
                    }
                }
                Spacer(minLength: 0)
                if selected {
                    Circle().fill(DeskColors.action).frame(width: 6, height: 6)
                }
            }
            .padding(6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selected ? DeskColors.selection : .clear, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8)
                .stroke(selected ? DeskColors.action.opacity(0.45) : .clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Page \(index + 1)")
        .accessibilityValue(selected ? "Current page" : "")
        .accessibilityHint("Show this page in the reader")
    }
}

private struct QuickToolRow: View {
    let title: String
    let symbol: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(DeskColors.action)
                    .frame(width: 27, height: 27)
                    .background(DeskColors.selection, in: RoundedRectangle(cornerRadius: 7))
                Text(title).font(.system(size: 10, weight: .medium)).foregroundStyle(DeskColors.ink).lineLimit(1)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .semibold)).foregroundStyle(DeskColors.secondary.opacity(0.8))
            }
            .padding(.horizontal, 8).padding(.vertical, 7)
            .background(DeskColors.surface, in: RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9)
                .stroke(hovering ? DeskColors.action.opacity(0.55) : DeskColors.divider.opacity(0.7), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

private struct ArrangePageCard: View {
    let document: PDFDocument
    let cache: PDFThumbnailCache
    let index: Int
    let selected: Bool
    let session: DocumentSession
    @Binding var draggedPageIndex: Int?
    @Binding var pageSelection: Set<Int>
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 11) {
                ZStack(alignment: .topTrailing) {
                    if let image = cache.image(document: document, index: index, size: CGSize(width: 380, height: 480)) {
                        Image(nsImage: image)
                            .resizable().aspectRatio(contentMode: .fit).frame(maxWidth: .infinity).frame(height: 232)
                            .background(.white).clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                    if selected {
                        Image(systemName: "checkmark.circle.fill").font(.system(size: 18)).foregroundStyle(DeskColors.action)
                            .padding(8)
                    }
                }
                HStack {
                    Text("Page \(index + 1)").font(.system(size: 12, weight: .medium)).foregroundStyle(DeskColors.ink)
                    Spacer()
                }
            }
            .padding(12)
            .background(DeskColors.surface, in: RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(selected ? DeskColors.action : DeskColors.divider, lineWidth: selected ? 2 : 1))
            .shadow(color: .black.opacity(selected ? 0.09 : 0.035), radius: selected ? 7 : 3, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Page \(index + 1)")
        .accessibilityValue(selected ? "Selected" : "Not selected")
        .accessibilityHint("Activate to select this page. Use the selection action to add or remove it from the selection.")
        .accessibilityAction(named: Text("Toggle page selection")) {
            if selected { pageSelection.remove(index) } else { pageSelection.insert(index) }
            session.selectPage(index)
        }
        .onDrag {
            draggedPageIndex = index
            return NSItemProvider(object: String(index) as NSString)
        }
        .onDrop(of: [UTType.plainText], delegate: PageReorderDropDelegate(
            targetIndex: index,
            session: session,
            draggedPageIndex: $draggedPageIndex,
            pageSelection: $pageSelection
        ))
    }
}

private struct PageReorderDropDelegate: DropDelegate {
    let targetIndex: Int
    let session: DocumentSession
    @Binding var draggedPageIndex: Int?
    @Binding var pageSelection: Set<Int>

    func dropEntered(info: DropInfo) {
        guard let sourceIndex = draggedPageIndex, sourceIndex != targetIndex else { return }
        pageSelection = Set(pageSelection.map { index in
            if index == sourceIndex { return targetIndex }
            if sourceIndex < targetIndex && index > sourceIndex && index <= targetIndex { return index - 1 }
            if sourceIndex > targetIndex && index >= targetIndex && index < sourceIndex { return index + 1 }
            return index
        })
        session.movePage(from: sourceIndex, to: targetIndex)
        draggedPageIndex = targetIndex
    }

    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .move) }

    func performDrop(info: DropInfo) -> Bool {
        draggedPageIndex = nil
        return true
    }
}
