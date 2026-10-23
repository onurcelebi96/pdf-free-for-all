import SwiftUI

@main
struct FreePdforallApp: App {
    @NSApplicationDelegateAdaptor(PDFAppDelegate.self) private var appDelegate
    @StateObject private var workspace = PDFWorkspace()

    var body: some Scene {
        WindowGroup("PDF FREE FOR ALL · \(AppRelease.version)") {
            WorkspaceView()
                .preferredColorScheme(.light)
                .environmentObject(workspace)
                .frame(minWidth: 820, minHeight: 580)
                .onAppear { appDelegate.workspace = workspace }
                .background(WindowCloseProtection(workspace: workspace))
        }
        .defaultSize(width: 1060, height: 700)
        .commands {
            CommandGroup(replacing: .undoRedo) {
                Button("Undo PDF change") { workspace.active?.undoPageEdit() }
                    .keyboardShortcut("z", modifiers: .command)
                    .disabled(!(workspace.active?.canUndoPageEdit ?? false))
            }
            CommandGroup(replacing: .newItem) {
                Button("Open PDF…") { workspace.openPDFs() }
                    .keyboardShortcut("o", modifiers: .command)
            }
            CommandGroup(replacing: .saveItem) {
                Button("Close Tab") { workspace.closeActiveTab() }
                    .keyboardShortcut("w", modifiers: .command)
                    .disabled(workspace.active == nil)
            }
            CommandGroup(after: .printItem) {
                Button("Save PDF As…") { workspace.active?.saveAs() }
                    .keyboardShortcut("s", modifiers: .command)
                    .disabled(workspace.active == nil)
            }
            CommandMenu("Tabs") {
                Button("Next Tab") { workspace.cycleTabs(by: 1) }
                    .keyboardShortcut(.tab, modifiers: .control)
                    .disabled(workspace.sessions.count < 2)
                Button("Previous Tab") { workspace.cycleTabs(by: -1) }
                    .keyboardShortcut(.tab, modifiers: [.control, .shift])
                    .disabled(workspace.sessions.count < 2)
            }
            CommandMenu("Page") {
                Button("Previous Page") { workspace.active?.stepPage(by: -1) }
                    .keyboardShortcut(.leftArrow, modifiers: [.command, .option])
                    .disabled(!(workspace.active?.canStep(by: -1) ?? false))
                Button("Next Page") { workspace.active?.stepPage(by: 1) }
                    .keyboardShortcut(.rightArrow, modifiers: [.command, .option])
                    .disabled(!(workspace.active?.canStep(by: 1) ?? false))
                Divider()
                Button("Move Page Up") { workspace.active?.moveSelected(-1) }
                    .keyboardShortcut(.upArrow, modifiers: [.command, .option])
                    .disabled(!(workspace.active?.canStep(by: -1) ?? false))
                Button("Move Page Down") { workspace.active?.moveSelected(1) }
                    .keyboardShortcut(.downArrow, modifiers: [.command, .option])
                    .disabled(!(workspace.active?.canStep(by: 1) ?? false))
                Divider()
                Button("Rotate Page Right") { workspace.active?.rotateSelected() }
                    .keyboardShortcut("r", modifiers: .command)
                    .disabled(workspace.active == nil)
                Button("Delete Page") { workspace.active?.deleteSelected() }
                    .keyboardShortcut(.delete, modifiers: .command)
                    .disabled((workspace.active?.pageCount ?? 0) < 2)
                Button("Add Signature…") { workspace.activeSheet = .signature }
                    .disabled(workspace.active == nil)
            }
        }
    }
}
