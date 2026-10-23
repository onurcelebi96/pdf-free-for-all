import AppKit
import SwiftUI

/// Window root: the tab strip across the top, then either the Home screen or the active document.
struct WorkspaceView: View {
    @EnvironmentObject private var workspace: PDFWorkspace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showsLaunchSignature = true

    var body: some View {
        VStack(spacing: 0) {
            TabStrip()
            if let session = workspace.active {
                SessionView(session: session)
                    .id(session.id)
            } else {
                homeHeader
                Divider().overlay(DeskColors.divider)
                HomeDashboard()
            }
        }
        .background(DeskColors.canvas)
        .frame(minWidth: 820, minHeight: 560)
        .overlay {
            if showsLaunchSignature {
                LaunchSignatureView(dismiss: dismissLaunchSignature)
                    .transition(.opacity)
                    .zIndex(10)
            }
        }
        .task {
            do {
                try await Task.sleep(for: .seconds(4))
                dismissLaunchSignature()
            } catch { /* Window closed before the launch card finished. */ }
        }
        .sheet(item: $workspace.activeSheet) { sheet in
            sheetContent(for: sheet)
        }
        .confirmationDialog("You have unsaved changes",
                            isPresented: workspace.closeConfirmationBinding,
                            titleVisibility: .visible) {
            if let id = workspace.closeConfirmationID {
                Button("Save a copy") { workspace.saveAndClose(id) }
                Button("Discard changes", role: .destructive) { workspace.remove(id) }
            }
            Button("Cancel", role: .cancel) { workspace.closeConfirmationID = nil }
        } message: {
            Text("Your source file is unchanged. Save a copy before closing this tab?")
        }
    }

    private func dismissLaunchSignature() {
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.3)) {
            showsLaunchSignature = false
        }
    }

    private var homeHeader: some View {
        HStack(spacing: 12) {
            if let iconURL = Bundle.main.url(forResource: "FreePdforall", withExtension: "icns"),
               let icon = NSImage(contentsOf: iconURL) {
                Image(nsImage: icon).resizable().interpolation(.high).frame(width: 42, height: 42)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text("PDF FREE FOR ALL")
                    .font(.custom("BrushScriptMT", size: 23, relativeTo: .title3))
                    .foregroundStyle(DeskColors.ink)
                    .accessibilityAddTraits(.isHeader)
                Canvas { context, _ in
                    var flourish = Path()
                    flourish.move(to: CGPoint(x: 5, y: 4))
                    flourish.addCurve(to: CGPoint(x: 112, y: 4), control1: CGPoint(x: 34, y: 10), control2: CGPoint(x: 80, y: -1))
                    context.stroke(flourish, with: .color(DeskColors.action), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
                }
                .frame(width: 118, height: 8)
                Text("FREE · PRIVATE · LOCAL")
                    .font(.system(size: 8, weight: .bold, design: .rounded)).tracking(0.9)
                    .foregroundStyle(DeskColors.secondary)
            }
            Text("v\(AppRelease.version)")
                .font(.system(size: 10, weight: .semibold)).foregroundStyle(DeskColors.action)
                .padding(.horizontal, 9).padding(.vertical, 5)
                .background(DeskColors.selection, in: Capsule())
            Spacer()
            Label("Files stay on this Mac", systemImage: "lock.shield")
                .font(.system(size: 11, weight: .medium)).foregroundStyle(DeskColors.secondary)
            Button("About") { workspace.notice = "PDF FREE FOR ALL \(AppRelease.version) (build \(AppRelease.build)). Free, open-source PDF tools. Documents are processed locally on this Mac." }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(DeskColors.secondary)
        }
        .padding(.horizontal, 28).padding(.vertical, 12)
        .background(DeskColors.surface)
    }

    @ViewBuilder
    private func sheetContent(for sheet: PDFWorkspace.Sheet) -> some View {
        switch sheet {
        case .signature:
            SignatureSheet(
                onSave: { strokes in
                    guard let session = workspace.active else { return }
                    session.beginSignaturePlacement(strokes)
                },
                onCancel: { workspace.activeSheet = nil }
            )
        case .signaturePlacement:
            if let session = workspace.active, let thumbnail = session.signaturePageThumbnail {
                SignaturePlacementSheet(
                    pageThumbnail: thumbnail,
                    strokes: session.pendingSignatureStrokes,
                    onApply: { rect in session.applySignature(at: rect) },
                    onCancel: { session.cancelSignaturePlacement() },
                    onRedraw: { session.redrawSignature() }
                )
            } else {
                VStack(spacing: 12) {
                    Text("The selected page is no longer available.")
                    Button("Close") { workspace.activeSheet = nil }
                }
                .padding(24)
            }
        case .split:
            if let session = workspace.active {
                SplitSheet(session: session)
            }
        case .splitReview:
            if let session = workspace.active {
                SplitReviewSheet(session: session)
            }
        case .combineReview:
            CombineReviewSheet()
        case .wordReview:
            if let session = workspace.active {
                WordReviewSheet(session: session)
            }
        }
    }
}
