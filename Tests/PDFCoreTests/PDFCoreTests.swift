import Foundation
import PDFKit
import Testing
@testable import PDFCore

@Suite("Page range parsing")
struct PageRangeParserTests {
    @Test("Parses pages, ranges, and duplicates in input order")
    func parsesPagesAndRanges() {
        #expect(PageRangeParser.parse("1-3, 5, 3", pageCount: 6) == [0, 1, 2, 4])
    }

    @Test("Accepts dash characters shown or typed by users")
    func acceptsDashCharacters() {
        #expect(PageRangeParser.parse("1–3, 5", pageCount: 5) == [0, 1, 2, 4])
        #expect(PageRangeParser.parse("2—4", pageCount: 5) == [1, 2, 3])
        #expect(PageRangeParser.parse("3−4", pageCount: 5) == [2, 3])
    }

    @Test("Trims whitespace and handles descending ranges")
    func handlesWhitespaceAndDescendingRanges() {
        #expect(PageRangeParser.parse(" 4 - 2 , 5 ", pageCount: 5) == [1, 2, 3, 4])
    }

    @Test("Rejects malformed and out-of-bounds ranges")
    func rejectsInvalidRanges() {
        #expect(PageRangeParser.parse("", pageCount: 5) == nil)
        #expect(PageRangeParser.parse("1,,3", pageCount: 5) == nil)
        #expect(PageRangeParser.parse("1--3", pageCount: 5) == nil)
        #expect(PageRangeParser.parse("0, 2", pageCount: 5) == nil)
        #expect(PageRangeParser.parse("1-6", pageCount: 5) == nil)
        #expect(PageRangeParser.parse("1, x", pageCount: 5) == nil)
        #expect(PageRangeParser.parse("1", pageCount: 0) == nil)
    }
}

@Suite("Page rotation")
struct PDFPageRotationTests {
    @Test("Normalizes positive and negative rotations")
    func normalizesRotation() {
        #expect(PDFPageRotation.normalized(270, adding: 90) == 0)
        #expect(PDFPageRotation.normalized(0, adding: -90) == 270)
        #expect(PDFPageRotation.normalized(90, adding: -180) == 270)
        #expect(PDFPageRotation.normalized(-90, adding: 0) == 270)
        #expect(PDFPageRotation.normalized(0, adding: 810) == 90)
    }
}

@Suite("Source file protection")
struct PDFFileSafetyTests {
    @Test("Protects the original path")
    func protectsOriginalPath() throws {
        let fixture = try makeTemporarySource()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        #expect(PDFFileSafety.wouldOverwriteSource(fixture.source, originals: [fixture.source]))
    }

    @Test("Protects an alias through a symbolic link")
    func protectsSymbolicLink() throws {
        let fixture = try makeTemporarySource()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let alias = fixture.directory.appendingPathComponent("source-alias.pdf")
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: fixture.source)
        #expect(PDFFileSafety.wouldOverwriteSource(alias, originals: [fixture.source]))
    }

    @Test("Protects an alias through a hard link")
    func protectsHardLink() throws {
        let fixture = try makeTemporarySource()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let alias = fixture.directory.appendingPathComponent("source-hardlink.pdf")
        try FileManager.default.linkItem(at: fixture.source, to: alias)
        #expect(PDFFileSafety.wouldOverwriteSource(alias, originals: [fixture.source]))
    }

    @Test("Allows a new destination")
    func allowsNewDestination() throws {
        let fixture = try makeTemporarySource()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let destination = fixture.directory.appendingPathComponent("edited.pdf")
        #expect(!PDFFileSafety.wouldOverwriteSource(destination, originals: [fixture.source]))
    }

    private func makeTemporarySource() throws -> (directory: URL, source: URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FreePdforallTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let source = directory.appendingPathComponent("source.pdf")
        try Data("fixture".utf8).write(to: source)
        return (directory, source)
    }
}

@Suite("PDF page operations")
struct PDFDocumentOperationsTests {
    @Test("Combines, extracts, and moves pages without changing page sizes")
    func combinesExtractsAndMovesPages() throws {
        let first = try makeDocument(pageWidths: [100, 120])
        let second = try makeDocument(pageWidths: [140])

        let combined = try #require(PDFDocumentOperations.combine([first, second]))
        #expect(combined.pageCount == 3)
        #expect(pageWidths(in: combined) == [100, 120, 140])

        let extracted = try #require(PDFDocumentOperations.extract([2, 0], from: combined))
        #expect(pageWidths(in: extracted) == [140, 100])
        #expect(pageWidths(in: combined) == [100, 120, 140], "Extraction must not mutate its input.")

        #expect(PDFDocumentOperations.movePage(in: combined, from: 0, to: 2))
        #expect(pageWidths(in: combined) == [120, 140, 100])
    }

    @Test("Rejects invalid extraction and move indexes")
    func rejectsInvalidIndexes() throws {
        let document = try makeDocument(pageWidths: [100, 120])
        #expect(PDFDocumentOperations.extract([], from: document) == nil)
        #expect(PDFDocumentOperations.extract([0, 2], from: document) == nil)
        #expect(!PDFDocumentOperations.movePage(in: document, from: 0, to: 2))
        #expect(!PDFDocumentOperations.movePage(in: document, from: 1, to: 1))
        #expect(pageWidths(in: document) == [100, 120])
    }

    @Test("Rotates valid pages and applies inverse rotation cleanly")
    func rotatesPagesAndUndoesRotation() throws {
        let document = try makeDocument(pageWidths: [100, 120])
        document.page(at: 0)?.rotation = 270

        #expect(PDFDocumentOperations.rotatePages(in: document, at: [0, 9], by: 90) == [0])
        #expect(document.page(at: 0)?.rotation == 0)
        #expect(PDFDocumentOperations.rotatePages(in: document, at: [0], by: -90) == [0])
        #expect(document.page(at: 0)?.rotation == 270)
        #expect(PDFDocumentOperations.rotatePages(in: document, at: [9], by: 90).isEmpty)
    }

    @Test("Does not create an empty combined document")
    func rejectsEmptyCombine() {
        #expect(PDFDocumentOperations.combine([]) == nil)
        #expect(PDFDocumentOperations.combine([PDFDocument()]) == nil)
    }

    @Test("Combined output serializes and opens again")
    func serializesCombinedOutput() throws {
        let document = try makeDocument(pageWidths: [100, 120])
        let combined = try #require(PDFDocumentOperations.combine([document]))
        let data = try #require(combined.dataRepresentation())
        let reopened = try #require(PDFDocument(data: data))
        #expect(reopened.pageCount == 2)
        #expect(pageWidths(in: reopened) == [100, 120])
    }

    private func makeDocument(pageWidths: [CGFloat]) throws -> PDFDocument {
        let document = PDFDocument()
        for width in pageWidths {
            let page = PDFPage()
            page.setBounds(CGRect(x: 0, y: 0, width: width, height: 200), for: .mediaBox)
            document.insert(page, at: document.pageCount)
        }
        #expect(document.pageCount == pageWidths.count)
        return document
    }

    private func pageWidths(in document: PDFDocument) -> [CGFloat] {
        (0..<document.pageCount).compactMap { document.page(at: $0)?.bounds(for: .mediaBox).width }
    }
}
