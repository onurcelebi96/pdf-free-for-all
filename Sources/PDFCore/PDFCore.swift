import Foundation
import PDFKit

public enum PageRangeParser {
    /// Parses one-based page numbers and ranges, returning unique zero-based indexes.
    public static func parse(_ value: String, pageCount: Int) -> [Int]? {
        guard pageCount > 0 else { return nil }
        let normalized = value
            .replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: "—", with: "-")
            .replacingOccurrences(of: "−", with: "-")
        let pieces = normalized.split(separator: ",", omittingEmptySubsequences: false)
        guard !pieces.isEmpty else { return nil }

        var result: [Int] = []
        for piece in pieces {
            let cleaned = piece.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleaned.isEmpty else { return nil }

            let parts = cleaned.split(separator: "-", omittingEmptySubsequences: false)
            guard parts.count <= 2,
                  let first = parts.first.flatMap({ Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }) else {
                return nil
            }
            let last: Int
            if parts.count == 2 {
                guard let parsed = Int(parts[1].trimmingCharacters(in: .whitespacesAndNewlines)) else { return nil }
                last = parsed
            } else {
                last = first
            }

            guard first >= 1, first <= pageCount, last >= 1, last <= pageCount else { return nil }
            for page in min(first, last)...max(first, last) {
                let index = page - 1
                if !result.contains(index) { result.append(index) }
            }
        }
        return result.isEmpty ? nil : result
    }
}

public enum PDFPageRotation {
    /// Normalizes the current page rotation after applying a signed degree change.
    public static func normalized(_ current: Int, adding degrees: Int) -> Int {
        let normalizedCurrent = (current % 360 + 360) % 360
        let normalizedChange = (degrees % 360 + 360) % 360
        return (normalizedCurrent + normalizedChange) % 360
    }
}

public enum PDFFileSafety {
    public static func canonicalURL(_ url: URL) -> URL {
        url.resolvingSymlinksInPath().standardizedFileURL
    }

    /// Returns true when the destination points to an original input, including by hard link.
    public static func wouldOverwriteSource(_ destination: URL, originals: Set<URL>) -> Bool {
        let target = canonicalURL(destination).path
        let targetIdentity = fileIdentity(destination)
        return originals.contains { source in
            let canonicalSource = canonicalURL(source)
            if canonicalSource.path.compare(target, options: .caseInsensitive) == .orderedSame { return true }
            guard let targetIdentity, let sourceIdentity = fileIdentity(source) else { return false }
            return targetIdentity == sourceIdentity
        }
    }

    private static func fileIdentity(_ url: URL) -> String? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let device = attributes[.systemNumber] as? NSNumber,
              let inode = attributes[.systemFileNumber] as? NSNumber else { return nil }
        return "\(device.stringValue):\(inode.stringValue)"
    }
}

public enum PDFDocumentOperations {
    public static func combine(_ documents: [PDFDocument]) -> PDFDocument? {
        let output = PDFDocument()
        guard !documents.isEmpty, documents.allSatisfy({ !$0.isLocked && $0.pageCount > 0 }) else { return nil }
        let expectedCount = documents.reduce(0) { $0 + $1.pageCount }
        guard expectedCount > 0 else { return nil }

        for document in documents {
            for index in 0..<document.pageCount {
                guard let page = document.page(at: index)?.copy() as? PDFPage else { return nil }
                output.insert(page, at: output.pageCount)
            }
        }
        return output.pageCount == expectedCount ? output : nil
    }

    public static func extract(_ pageIndexes: [Int], from document: PDFDocument) -> PDFDocument? {
        guard !pageIndexes.isEmpty, pageIndexes.allSatisfy({ (0..<document.pageCount).contains($0) }) else {
            return nil
        }
        let output = PDFDocument()
        for index in pageIndexes {
            guard let page = document.page(at: index)?.copy() as? PDFPage else { return nil }
            output.insert(page, at: output.pageCount)
        }
        return output.pageCount == pageIndexes.count ? output : nil
    }

    /// Rotates each valid page once and returns the zero-based indexes that changed.
    public static func rotatePages(in document: PDFDocument, at pageIndexes: [Int], by degrees: Int) -> [Int] {
        let validIndexes = Array(Set(pageIndexes.filter { (0..<document.pageCount).contains($0) })).sorted()
        for index in validIndexes {
            guard let page = document.page(at: index) else { continue }
            page.rotation = PDFPageRotation.normalized(page.rotation, adding: degrees)
        }
        return validIndexes
    }

    @discardableResult
    public static func movePage(in document: PDFDocument, from sourceIndex: Int, to destinationIndex: Int) -> Bool {
        guard (0..<document.pageCount).contains(sourceIndex),
              (0..<document.pageCount).contains(destinationIndex),
              sourceIndex != destinationIndex,
              let page = document.page(at: sourceIndex) else { return false }
        // Retain the page itself: earlier undo entries refer to its annotation identities.
        document.removePage(at: sourceIndex)
        document.insert(page, at: destinationIndex)
        return true
    }
}
