import AppKit
import SwiftUI
import PDFKit

final class PDFViewStore: ObservableObject {
    // A session retains its view while another tab is visible, preserving viewport and zoom.
    var view: PDFView?
}

@MainActor
final class PDFAppDelegate: NSObject, NSApplicationDelegate {
    weak var workspace: PDFWorkspace?
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.appearance = NSAppearance(named: .aqua)
    }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        workspace?.confirmClosingDocuments() == false ? .terminateCancel : .terminateNow
    }
}

struct WindowCloseProtection: NSViewRepresentable {
    let workspace: PDFWorkspace
    func makeNSView(context: Context) -> CloseView {
        let view = CloseView()
        view.guardDelegate.workspace = workspace
        return view
    }
    func updateNSView(_ view: CloseView, context: Context) { view.guardDelegate.workspace = workspace }
    final class CloseView: NSView {
        let guardDelegate = CloseDelegate()
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window, window.delegate !== guardDelegate else { return }
            guardDelegate.previous = window.delegate
            window.delegate = guardDelegate
        }
    }
    final class CloseDelegate: NSObject, NSWindowDelegate {
        weak var workspace: PDFWorkspace?
        weak var previous: NSWindowDelegate?
        func windowShouldClose(_ sender: NSWindow) -> Bool {
            guard workspace?.confirmClosingDocuments() != false else { return false }
            return previous?.windowShouldClose?(sender) ?? true
        }
        override func responds(to selector: Selector!) -> Bool {
            super.responds(to: selector) || (previous?.responds(to: selector) ?? false)
        }
        override func forwardingTarget(for selector: Selector!) -> Any? {
            previous?.responds(to: selector) == true ? previous : super.forwardingTarget(for: selector)
        }
    }
}
