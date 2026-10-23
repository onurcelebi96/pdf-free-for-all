import AppKit
import PDFKit
import SwiftUI

@MainActor
final class PDFThumbnailCache: ObservableObject {
    private final class Thumbnail {
        // Keep identity alive until eviction, so a removed page's address cannot be reused for a different cached page.
        let page: PDFPage
        let image: NSImage
        init(page: PDFPage, image: NSImage) { self.page = page; self.image = image }
    }
    private let images = NSCache<NSString, Thumbnail>()
    private weak var document: PDFDocument?
    private(set) var renderCount = 0
    init() {
        images.countLimit = 96
        images.totalCostLimit = 32 * 1024 * 1024
    }
    func image(document: PDFDocument, index: Int, size: CGSize) -> NSImage? {
        if self.document !== document {
            images.removeAllObjects()
            self.document = document
        }
        guard let page = document.page(at: index) else { return nil }
        let key = "\(ObjectIdentifier(page))-\(page.rotation)-\(page.annotations.count)-\(size.width)x\(size.height)" as NSString
        if let cached = images.object(forKey: key) { return cached.image }
        let image = page.thumbnail(of: size, for: .mediaBox)
        images.setObject(Thumbnail(page: page, image: image), forKey: key, cost: Int(size.width * size.height * 4))
        renderCount += 1
        return image
    }
}

@MainActor
final class PDFSearchController: ObservableObject {
    @Published private(set) var matches: [PDFSelection] = []
    @Published private(set) var isSearching = false
    private weak var document: PDFDocument?
    private var observers: [NSObjectProtocol] = []
    private var generation = 0

    func cancel() {
        generation += 1
        observers.forEach(NotificationCenter.default.removeObserver)
        observers.removeAll()
        document?.cancelFindString()
        document = nil
        matches = []
        isSearching = false
    }

    func start(_ query: String, in document: PDFDocument) {
        cancel()
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        self.document = document
        isSearching = true
        let token = generation
        observers.append(NotificationCenter.default.addObserver(forName: .PDFDocumentDidFindMatch, object: document, queue: .main) { [weak self] note in
            MainActor.assumeIsolated {
                guard let self, self.generation == token,
                      let match = note.userInfo?["PDFDocumentFoundSelection"] as? PDFSelection else { return }
                self.matches.append(match)
            }
        })
        observers.append(NotificationCenter.default.addObserver(forName: .PDFDocumentDidEndFind, object: document, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.generation == token else { return }
                self.isSearching = false
            }
        })
        document.beginFindString(query, withOptions: [.caseInsensitive])
    }

    deinit { observers.forEach(NotificationCenter.default.removeObserver) }
}
