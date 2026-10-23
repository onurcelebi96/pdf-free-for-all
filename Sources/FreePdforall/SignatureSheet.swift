import SwiftUI

struct SignatureSheet: View {
    let onSave: ([[CGPoint]]) -> Void
    let onCancel: () -> Void
    @State private var strokes: [[CGPoint]] = []
    @State private var current: [CGPoint] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Draw your signature").font(.system(size: 18, weight: .semibold, design: .rounded))
                    Text("Draw with your trackpad or mouse, then choose where it belongs.").font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Clear") { strokes = []; current = [] }.disabled(strokes.isEmpty && current.isEmpty)
            }
            SignaturePad(strokes: strokes, current: current) { point, ended in
                if ended {
                    if !current.isEmpty { strokes.append(current) }
                    current = []
                } else { current.append(point) }
            }
            .frame(height: 190)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.black.opacity(0.09), lineWidth: 1))
            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                Button("Review placement") { onSave(strokes) }
                    .keyboardShortcut(.defaultAction).disabled(!strokes.contains(where: { $0.count > 1 }))
            }
        }
        .padding(22).frame(width: 500)
    }
}

private struct SignaturePad: View {
    let strokes: [[CGPoint]]
    let current: [CGPoint]
    let onPoint: (CGPoint, Bool) -> Void
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Canvas { context, size in
                    context.stroke(Path { path in
                        path.move(to: CGPoint(x: 22, y: size.height * 0.78))
                        path.addLine(to: CGPoint(x: size.width - 22, y: size.height * 0.78))
                    }, with: .color(Color.gray.opacity(0.18)), lineWidth: 1)
                    for stroke in strokes + (current.isEmpty ? [] : [current]) where stroke.count > 1 {
                        var path = Path()
                        path.move(to: CGPoint(x: stroke[0].x * size.width, y: stroke[0].y * size.height))
                        for point in stroke.dropFirst() { path.addLine(to: CGPoint(x: point.x * size.width, y: point.y * size.height)) }
                        context.stroke(path, with: .color(DeskColors.signatureInk), style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
                    }
                }
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        onPoint(CGPoint(x: value.location.x / max(geometry.size.width, 1), y: value.location.y / max(geometry.size.height, 1)), false)
                    }
                    .onEnded { _ in onPoint(.zero, true) })
            }
        }
    }
}
