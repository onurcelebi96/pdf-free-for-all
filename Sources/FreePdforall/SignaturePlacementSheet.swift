import AppKit
import SwiftUI

struct SignaturePlacementSheet: View {
    let pageThumbnail: NSImage
    let strokes: [[CGPoint]]
    let onApply: (CGRect) -> Void
    let onCancel: () -> Void
    let onRedraw: () -> Void

    @State private var placement = CGRect(x: 0.30, y: 0.44, width: 0.40, height: 0.12)
    @State private var moveOrigin: CGRect?
    @State private var resizeOrigin: CGRect?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Place your signature")
                    .font(.system(size: 19, weight: .semibold, design: .rounded))
                    .foregroundStyle(DeskColors.ink)
                Text("Drag the mark to move it. Drag the corner to resize, or use the buttons below.")
                    .font(.system(size: 12)).foregroundStyle(DeskColors.secondary)
            }

            GeometryReader { geometry in
                let pageSize = fittedPageSize(in: geometry.size)
                let pageOrigin = CGPoint(x: (geometry.size.width - pageSize.width) / 2,
                                         y: (geometry.size.height - pageSize.height) / 2)
                let markFrame = CGRect(x: pageOrigin.x + placement.minX * pageSize.width,
                                       y: pageOrigin.y + placement.minY * pageSize.height,
                                       width: placement.width * pageSize.width,
                                       height: placement.height * pageSize.height)

                ZStack {
                    Image(nsImage: pageThumbnail)
                        .resizable()
                        .frame(width: pageSize.width, height: pageSize.height)
                        .position(x: pageOrigin.x + pageSize.width / 2,
                                  y: pageOrigin.y + pageSize.height / 2)
                        .shadow(color: .black.opacity(0.12), radius: 10, y: 3)
                        .accessibilityHidden(true)

                    SignatureInkPreview(strokes: strokes)
                        .frame(width: markFrame.width, height: markFrame.height)
                        .background(DeskColors.action.opacity(0.08), in: RoundedRectangle(cornerRadius: 4))
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(DeskColors.action, lineWidth: 1.5))
                        .overlay(alignment: .bottomTrailing) {
                            Circle()
                                .fill(DeskColors.action)
                                .frame(width: 18, height: 18)
                                .overlay(Circle().stroke(.white, lineWidth: 2))
                                .offset(x: 8, y: 8)
                                .highPriorityGesture(resizeGesture(in: pageSize))
                                .accessibilityHidden(true)
                        }
                        .contentShape(Rectangle())
                        .gesture(moveGesture(in: pageSize))
                        .accessibilityElement()
                        .accessibilityLabel("Signature placement preview")
                        .accessibilityHint("Drag to move the signature. Use the arrow buttons to position it and the size buttons to resize it.")
                        .position(x: markFrame.midX, y: markFrame.midY)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(height: 430)
            .padding(10)
            .background(DeskColors.documentStage, in: RoundedRectangle(cornerRadius: 10))

            HStack(spacing: 8) {
                Button { moveBy(x: -0.025, y: 0) } label: { Label("Move left", systemImage: "arrow.left") }
                Button { moveBy(x: 0, y: -0.025) } label: { Label("Move up", systemImage: "arrow.up") }
                Button { moveBy(x: 0, y: 0.025) } label: { Label("Move down", systemImage: "arrow.down") }
                Button { moveBy(x: 0.025, y: 0) } label: { Label("Move right", systemImage: "arrow.right") }
                Divider().frame(height: 22)
                Button("Smaller") { resizeBy(factor: 0.9) }
                Button("Larger") { resizeBy(factor: 1.1) }
            }
            .buttonStyle(.bordered).controlSize(.small)

            Text("This adds a visual ink mark. It is not a certificate-backed digital signature.")
                .font(.system(size: 11)).foregroundStyle(DeskColors.secondary)

            HStack {
                Button("Cancel", action: onCancel)
                Button("Redraw", action: onRedraw)
                Spacer()
                Button("Apply signature") { onApply(placement) }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .tint(DeskColors.action)
            }
        }
        .padding(20)
        .frame(width: 690)
        .background(DeskColors.canvas)
    }

    private func fittedPageSize(in available: CGSize) -> CGSize {
        let imageSize = pageThumbnail.size
        guard imageSize.width > 0, imageSize.height > 0 else { return available }
        let scale = min(available.width / imageSize.width, available.height / imageSize.height)
        return CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
    }

    private func moveGesture(in pageSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                let origin = moveOrigin ?? placement
                if moveOrigin == nil { moveOrigin = placement }
                placement = constrained(CGRect(x: origin.minX + value.translation.width / max(pageSize.width, 1),
                                                y: origin.minY + value.translation.height / max(pageSize.height, 1),
                                                width: origin.width, height: origin.height))
            }
            .onEnded { _ in moveOrigin = nil }
    }

    private func resizeGesture(in pageSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                let origin = resizeOrigin ?? placement
                if resizeOrigin == nil { resizeOrigin = placement }
                placement = constrained(CGRect(x: origin.minX, y: origin.minY,
                                                width: origin.width + value.translation.width / max(pageSize.width, 1),
                                                height: origin.height + value.translation.height / max(pageSize.height, 1)))
            }
            .onEnded { _ in resizeOrigin = nil }
    }

    private func moveBy(x: CGFloat, y: CGFloat) {
        placement = constrained(CGRect(x: placement.minX + x, y: placement.minY + y,
                                        width: placement.width, height: placement.height))
    }

    private func resizeBy(factor: CGFloat) {
        let width = min(0.82, max(0.10, placement.width * factor))
        let height = min(0.30, max(0.04, placement.height * factor))
        placement = constrained(CGRect(x: placement.midX - width / 2, y: placement.midY - height / 2,
                                        width: width, height: height))
    }

    private func constrained(_ rect: CGRect) -> CGRect {
        let width = min(0.82, max(0.10, rect.width))
        let height = min(0.30, max(0.04, rect.height))
        let x = min(max(rect.minX, 0), 1 - width)
        let y = min(max(rect.minY, 0), 1 - height)
        return CGRect(x: x, y: y, width: width, height: height)
    }
}

private struct SignatureInkPreview: View {
    let strokes: [[CGPoint]]

    var body: some View {
        Canvas { context, size in
            for stroke in strokes where stroke.count > 1 {
                var path = Path()
                path.move(to: CGPoint(x: stroke[0].x * size.width, y: stroke[0].y * size.height))
                for point in stroke.dropFirst() {
                    path.addLine(to: CGPoint(x: point.x * size.width, y: point.y * size.height))
                }
                context.stroke(path, with: .color(DeskColors.signatureInk),
                               style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
            }
        }
        .accessibilityHidden(true)
    }
}
