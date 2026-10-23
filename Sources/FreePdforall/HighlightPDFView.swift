import AppKit
import PDFKit

/// Finishes a highlight only after PDFKit has finished handling the selection gesture.
/// A local event monitor also catches mouse-up delivered to PDFKit's internal document view.
final class HighlightPDFView: PDFView {
    var highlightEnabled = false
    var onHighlightSelection: ((PDFSelection) -> Void)?
    var onEndHighlight: (() -> Void)?
    private var mouseMonitor: Any?
    private var selectionStartedHere = false

    override init(frame: NSRect) {
        super.init(frame: frame)
        mouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .leftMouseUp]) { [weak self] event in
            guard let self else { return event }
            if event.type == .leftMouseDown {
                let point = self.convert(event.locationInWindow, from: nil)
                self.selectionStartedHere = self.highlightEnabled && event.window === self.window &&
                    self.window != nil && self.bounds.contains(point) && !self.isHiddenOrHasHiddenAncestor
            } else if self.selectionStartedHere {
                self.selectionStartedHere = false
                // The monitor runs before PDFKit receives mouseUp. Wait one main-loop turn.
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.highlightEnabled, self.window != nil,
                          let selection = self.currentSelection?.copy() as? PDFSelection else { return }
                    self.onHighlightSelection?(selection)
                }
            }
            return event
        }
    }

    required init?(coder: NSCoder) { fatalError("Use init(frame:)") }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 && highlightEnabled {
            onEndHighlight?()
        } else {
            super.keyDown(with: event)
        }
    }

    deinit { if let mouseMonitor { NSEvent.removeMonitor(mouseMonitor) } }
}
