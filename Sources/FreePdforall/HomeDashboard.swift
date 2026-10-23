import SwiftUI

struct HomeDashboard: View {
    @EnvironmentObject private var workspace: PDFWorkspace

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 20) {
                Text("WORKSPACE").font(.system(size: 10, weight: .semibold)).tracking(1.2).foregroundStyle(DeskColors.secondary)
                Label("All tools", systemImage: "square.grid.2x2.fill")
                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(DeskColors.action)
                    .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                    .background(DeskColors.selection, in: RoundedRectangle(cornerRadius: 8))
                Button { workspace.openPDFs() } label: {
                    Label("Open PDFs", systemImage: "plus").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent).tint(DeskColors.action).controlSize(.large)
                Divider()
                if !workspace.sessions.isEmpty {
                    Text("OPEN DOCUMENTS").font(.system(size: 10, weight: .semibold)).tracking(1).foregroundStyle(DeskColors.secondary)
                    ForEach(workspace.sessions) { session in
                        sidebarButton(session.sourceName.isEmpty ? "Untitled" : session.sourceName, "doc.richtext") {
                            workspace.activate(session.id)
                        }
                    }
                    Divider()
                }
                Text("QUICK ACCESS").font(.system(size: 10, weight: .semibold)).tracking(1).foregroundStyle(DeskColors.secondary)
                sidebarButton("Sign a document", "signature") { workspace.startHomeTask(.sign) }
                sidebarButton("Print a document", "printer") { workspace.startHomeTask(.printDocument) }
                Spacer()
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: "lock.shield").font(.system(size: 20)).foregroundStyle(DeskColors.success)
                    Text("Your files. Your Mac.").font(.system(size: 12, weight: .semibold))
                    Text("No upload, account, or subscription.").font(.system(size: 11)).foregroundStyle(DeskColors.secondary)
                }
            }
            .padding(20).frame(width: 180).frame(maxHeight: .infinity)
            .background(DeskColors.surface)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 25) {
                    HStack {
                        Label("EVERY TOOL IS FREE", systemImage: "checkmark.seal.fill")
                            .font(.system(size: 10, weight: .semibold)).tracking(0.8).foregroundStyle(DeskColors.success)
                        Spacer()
                        Text("Made for Mac").font(.system(size: 11)).foregroundStyle(DeskColors.secondary)
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Make PDFs work for you.")
                            .font(.system(size: 30, weight: .semibold)).tracking(-0.8).foregroundStyle(DeskColors.ink)
                        Text("Read, organize, convert, and sign. Everything you need, in one calm workspace.")
                            .font(.system(size: 13)).foregroundStyle(DeskColors.secondary)
                    }
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 205), spacing: 14)], spacing: 14) {
                        tool("Open & read", detail: "View, search, zoom, and highlight text. Open several at once.", icon: "doc.text", color: .blue) { workspace.openPDFs() }
                        tool("Organize pages", detail: "Reorder, rotate, or remove pages.", icon: "square.grid.2x2", color: .purple) { workspace.startHomeTask(.organize) }
                        tool("Merge PDFs", detail: "Bring several documents together.", icon: "square.stack.3d.up", color: .orange) { workspace.startCombineFromHome() }
                        tool("Split & extract", detail: "Save selected pages as a new PDF.", icon: "scissors", color: .pink) { workspace.startHomeTask(.split) }
                        tool("Word to PDF", detail: "Create a PDF from a Word document.", icon: "doc.badge.arrow.up", color: .blue) { workspace.convertWordToPDF() }
                        tool("PDF to Word", detail: "Export selectable text to Word.", icon: "doc.richtext", color: .indigo) { workspace.startHomeTask(.wordExport) }
                        tool("Draw & sign", detail: "Add your handwritten signature.", icon: "signature", color: .teal) { workspace.startHomeTask(.sign) }
                        tool("Export page image", detail: "Save the current page as a PNG.", icon: "photo", color: .green) { workspace.startHomeTask(.exportImage) }
                    }
                    HStack(spacing: 10) {
                        Image(systemName: "info.circle").foregroundStyle(DeskColors.secondary)
                        Text("Word conversion works locally. Complex layouts may change; PDF to Word exports text.")
                            .font(.system(size: 11)).foregroundStyle(DeskColors.secondary)
                    }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
                        .background(DeskColors.surface, in: RoundedRectangle(cornerRadius: 8))
                    if let notice = workspace.notice {
                        Label(notice, systemImage: "info.circle").font(.system(size: 12)).foregroundStyle(DeskColors.ink)
                            .textSelection(.enabled)
                    }
                }
                .padding(28).frame(maxWidth: 1160, alignment: .leading).frame(maxWidth: .infinity)
            }
            .background(DeskColors.canvas)
        }
    }

    private func sidebarButton(_ title: String, _ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol).font(.system(size: 12)).foregroundStyle(DeskColors.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
        }.buttonStyle(.plain)
    }

    private func tool(_ title: String, detail: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        DashboardToolCard(title: title, detail: detail, icon: icon, color: color, action: action)
    }
}

private struct DashboardToolCard: View {
    let title: String
    let detail: String
    let icon: String
    let color: Color
    let action: () -> Void
    @State private var hovered = false
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: icon).font(.system(size: 21, weight: .medium)).foregroundStyle(color)
                        .frame(width: 42, height: 42).background(color.opacity(0.09), in: RoundedRectangle(cornerRadius: 10))
                    Spacer()
                    Image(systemName: "arrow.up.right").font(.system(size: 10, weight: .semibold)).foregroundStyle(DeskColors.secondary)
                }
                Text(title).font(.system(size: 14, weight: .semibold)).foregroundStyle(DeskColors.ink)
                Text(detail).font(.system(size: 11)).foregroundStyle(DeskColors.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(18).frame(maxWidth: .infinity, minHeight: 158, maxHeight: .infinity, alignment: .topLeading)
            .background(DeskColors.surface, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(hovered ? DeskColors.action : DeskColors.divider, lineWidth: 1))
            .shadow(color: .black.opacity(hovered ? 0.06 : 0), radius: 10, y: 3)
        }
        .buttonStyle(.plain).onHover { hovered = $0 }
        .accessibilityLabel("\(title). \(detail)")
    }
}
