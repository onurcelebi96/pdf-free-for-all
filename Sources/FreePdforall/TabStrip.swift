import SwiftUI

/// Document tabs across the top of the window, in the style of Acrobat:
/// a fixed Home tab, one tab per open PDF with a close button, and an Open button.
struct TabStrip: View {
    @EnvironmentObject private var workspace: PDFWorkspace

    var body: some View {
        HStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        HomeTab()
                        ForEach(workspace.sessions) { session in
                            DocumentTab(session: session)
                                .id(session.id)
                        }
                    }
                    .padding(.horizontal, 10)
                }
                .onChange(of: workspace.activeSessionID) { _, id in
                    guard let id else { return }
                    withAnimation(.easeInOut(duration: 0.18)) { proxy.scrollTo(id, anchor: .center) }
                }
            }
            Button { workspace.openPDFs() } label: {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .foregroundStyle(DeskColors.action)
            .padding(.horizontal, 8)
            .help("Open PDF in a new tab (⌘O)")
            .accessibilityLabel("Open PDF in a new tab")
        }
        .frame(height: 32)
        .background(DeskColors.navigator)
        .overlay(alignment: .bottom) { Rectangle().fill(DeskColors.divider).frame(height: 1) }
    }
}

private struct HomeTab: View {
    @EnvironmentObject private var workspace: PDFWorkspace

    var body: some View {
        Button { workspace.showHome() } label: {
            Label("Home", systemImage: "house")
                .font(.system(size: 11, weight: workspace.isHome ? .semibold : .medium))
                .padding(.horizontal, 11)
                .frame(height: 28)
        }
        .buttonStyle(.plain)
        .foregroundStyle(workspace.isHome ? DeskColors.ink : DeskColors.secondary)
        .modifier(TabSurface(selected: workspace.isHome))
        .accessibilityAddTraits(workspace.isHome ? .isSelected : [])
    }
}

private struct DocumentTab: View {
    @ObservedObject var session: DocumentSession
    @EnvironmentObject private var workspace: PDFWorkspace
    @State private var hovering = false

    private var isActive: Bool { workspace.activeSessionID == session.id }
    private var title: String { session.sourceName.isEmpty ? "Untitled" : session.sourceName }

    var body: some View {
        HStack(spacing: 7) {
            Button { workspace.activate(session.id) } label: {
                HStack(spacing: 7) {
                    Image(systemName: "doc.richtext")
                        .font(.system(size: 11))
                    Text(title)
                        .font(.system(size: 11, weight: isActive ? .semibold : .medium))
                        .lineLimit(1)
                        .frame(maxWidth: 170, alignment: .leading)
                    if session.hasUnsavedChanges {
                        Circle()
                            .fill(DeskColors.warning)
                            .frame(width: 6, height: 6)
                            .accessibilityLabel("Unsaved changes")
                    }
                }
            }
            .buttonStyle(.plain)

            Button { workspace.close(session.id) } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .frame(width: 16, height: 16)
                    .background(hovering ? DeskColors.divider : Color.clear, in: Circle())
            }
            .buttonStyle(.plain)
            .opacity(isActive || hovering ? 1 : 0)
            .help("Close tab (⌘W)")
            .accessibilityLabel("Close \(title)")
        }
        .foregroundStyle(isActive ? DeskColors.ink : DeskColors.secondary)
        .padding(.horizontal, 11)
        .frame(height: 28)
        .modifier(TabSurface(selected: isActive))
        .onHover { hovering = $0 }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}

private struct TabSurface: ViewModifier {
    let selected: Bool

    func body(content: Content) -> some View {
        content
            .background(selected ? DeskColors.surface : Color.clear, in: RoundedRectangle(cornerRadius: 7))
            .overlay(alignment: .bottom) {
                if selected {
                    Rectangle()
                        .fill(DeskColors.action)
                        .frame(height: 2)
                        .padding(.horizontal, 6)
                }
            }
    }
}
