import AppKit
import Foundation
import PDFKit
import UniformTypeIdentifiers

@MainActor
enum DocumentConverter {
    struct WordPDFPreview {
        let sourceName: String
        let sourceURL: URL
        let document: PDFDocument
    }

    static func wordToPDF() throws -> WordPDFPreview? {
        let open = NSOpenPanel()
        open.allowedContentTypes = [UTType(filenameExtension: "docx") ?? .data]
        open.allowsMultipleSelection = false
        open.canChooseDirectories = false
        guard open.runModal() == .OK, let sourceURL = open.url else { return nil }

        return try wordToPDF(sourceURL: sourceURL)
    }

    static func wordToPDF(sourceURL: URL) throws -> WordPDFPreview {
        let sourceData = try Data(contentsOf: sourceURL)
        let readingOptions: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.officeOpenXML
        ]
        let content = try NSAttributedString(data: sourceData, options: readingOptions, documentAttributes: nil)
        guard content.length > 0 else { throw ConversionError.noReadableText }

        let paper = NSSize(width: 612, height: 792)
        let margin: CGFloat = 48
        let storage = NSTextStorage(attributedString: content)
        let layout = NSLayoutManager()
        storage.addLayoutManager(layout)
        let printableSize = NSSize(width: paper.width - margin * 2,
                                   height: paper.height - margin * 2)
        let container = NSTextContainer(containerSize: NSSize(width: printableSize.width, height: 10_000_000))
        container.widthTracksTextView = true
        container.heightTracksTextView = false
        layout.addTextContainer(container)
        let textView = NSTextView(frame: NSRect(origin: .zero, size: printableSize), textContainer: container)
        textView.isEditable = false
        textView.isSelectable = false
        textView.textContainerInset = .zero
        textView.isVerticallyResizable = true
        container.heightTracksTextView = false
        layout.ensureLayout(for: container)
        textView.setFrameSize(NSSize(width: printableSize.width,
                                    height: max(printableSize.height, ceil(layout.usedRect(for: container).height) + 2)))

        let printInfo = NSPrintInfo()
        printInfo.paperSize = paper
        printInfo.leftMargin = margin
        printInfo.rightMargin = margin
        printInfo.topMargin = margin
        printInfo.bottomMargin = margin
        printInfo.horizontalPagination = .fit
        printInfo.verticalPagination = .automatic
        printInfo.isVerticallyCentered = false
        printInfo.jobDisposition = .save
        let temporaryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("pdf")
        defer { try? FileManager.default.removeItem(at: temporaryURL) }
        printInfo.dictionary()[NSPrintInfo.AttributeKey.jobSavingURL] = temporaryURL

        let operation = NSPrintOperation(view: textView, printInfo: printInfo)
        operation.showsPrintPanel = false
        operation.showsProgressPanel = false
        guard operation.run() else { throw ConversionError.exportFailed }
        let pdfData = try Data(contentsOf: temporaryURL)
        guard let pdf = PDFDocument(data: pdfData) else { throw ConversionError.exportFailed }
        return WordPDFPreview(sourceName: sourceURL.deletingPathExtension().lastPathComponent,
                              sourceURL: sourceURL, document: pdf)
    }

    static func pagePNGData(_ page: PDFPage) throws -> Data {
        let image = page.thumbnail(of: CGSize(width: 2400, height: 2400), for: .cropBox)
        guard let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff),
              let data = bitmap.representation(using: .png, properties: [:]) else {
            throw ConversionError.exportFailed
        }
        return data
    }

    static func pdfToWordData(document: PDFDocument) throws -> Data {
        let text = (0..<document.pageCount)
            .compactMap { document.page(at: $0)?.string?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
        guard !text.isEmpty else { throw ConversionError.noReadableText }

        let document = NSAttributedString(string: text, attributes: [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: NSColor.textColor
        ])
        let options: [NSAttributedString.DocumentAttributeKey: Any] = [
            .documentType: NSAttributedString.DocumentType.officeOpenXML
        ]
        return try document.data(from: NSRange(location: 0, length: document.length),
                                 documentAttributes: options)
    }
}

enum ConversionError: LocalizedError {
    case noReadableText
    case exportFailed

    var errorDescription: String? {
        switch self {
        case .noReadableText:
            return "No selectable text could be read. Scanned pages need OCR, which is not included yet."
        case .exportFailed:
            return "macOS could not finish exporting this document."
        }
    }
}
