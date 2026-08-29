import AppKit
import SwiftUI

@main
struct ResourceMonitorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var sampler = MetricsSamplerService.shared
    @AppStorage("showCPUMemoryInMenuBar") private var showCPUMemoryInMenuBar = false

    var body: some Scene {
        MenuBarExtra {
            MenuBarMonitorView(
                sampler: sampler,
                showCPUMemoryInMenuBar: $showCPUMemoryInMenuBar
            )
        } label: {
            MenuBarStatusLabel(
                sampler: sampler,
                showValues: showCPUMemoryInMenuBar
            )
        }
        .menuBarExtraStyle(.window)

        Window("Desktop Panel", id: "desktop-panel") {
            DesktopPanelView(sampler: sampler)
                .background(DesktopPanelChrome())
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 280, height: 200)
        .keyboardShortcut("p", modifiers: [.command])

        WindowGroup("Resource Monitor") {
            ContentView(sampler: sampler)
        }
        .defaultSize(width: 460, height: 380)
        .commands {
            CommandGroup(after: .windowList) {
                Button("Show Desktop Panel") {
                    NotificationCenter.default.post(name: .showDesktopPanel, object: nil)
                }
                .keyboardShortcut("p", modifiers: [.command])
            }
        }
    }
}

private struct MenuBarStatusLabel: View {
    @ObservedObject var sampler: MetricsSamplerService
    let showValues: Bool

    var body: some View {
        if showValues {
            Image(nsImage: MenuBarMetricsImage.make(
                cpuUsage: sampler.snapshot.cpuUsage,
                memoryUsage: sampler.snapshot.memoryUsage
            ))
        } else {
            Image(systemName: "gauge.with.dots.needle.33percent")
        }
    }
}

private struct MenuBarMonitorView: View {
    @ObservedObject var sampler: MetricsSamplerService
    @Binding var showCPUMemoryInMenuBar: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Resource Monitor")
                .font(.headline)

            labeled("CPU", ByteFormat.percent(sampler.snapshot.cpuUsage))
            labeled(
                "Memory",
                "\(ByteFormat.percent(sampler.snapshot.memoryUsage)) · \(ByteFormat.memory(sampler.snapshot.memoryUsedBytes))"
            )
            labeled("Down", ByteFormat.rate(sampler.snapshot.networkInBytesPerSec))
            labeled("Up", ByteFormat.rate(sampler.snapshot.networkOutBytesPerSec))

            Divider()

            Toggle("Show CPU & Memory in menu bar", isOn: $showCPUMemoryInMenuBar)
                .toggleStyle(.checkbox)

            Text(sampler.statusMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                NotificationCenter.default.post(name: .showDesktopPanel, object: nil)
            } label: {
                Text("Show Desktop Panel")
                    .frame(maxWidth: .infinity)
            }
            .keyboardShortcut("p", modifiers: [.command])

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(12)
        .frame(width: 260)
        .modifier(DesktopPanelOpener())
    }

    private func labeled(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .monospacedDigit()
        }
        .font(.callout)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var openPanelObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        MetricsSamplerService.shared.start()

        openPanelObserver = NotificationCenter.default.addObserver(
            forName: .showDesktopPanel,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.showDesktopPanel()
        }

        // Show the live panel automatically so it’s obvious where it is.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.showDesktopPanel()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let openPanelObserver {
            NotificationCenter.default.removeObserver(openPanelObserver)
        }
    }

    func showDesktopPanel() {
        NSApp.activate(ignoringOtherApps: true)

        // Prefer an existing panel window.
        if let existing = NSApp.windows.first(where: { isDesktopPanel($0) }) {
            configurePanel(existing)
            positionBottomRight(existing)
            existing.orderFront(nil)
            return
        }

        // Ask SwiftUI to open the Window scene, then configure it.
        NotificationCenter.default.post(name: .requestOpenDesktopPanelWindow, object: nil)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            guard let self else { return }
            if let window = NSApp.windows.first(where: { self.isDesktopPanel($0) }) {
                self.configurePanel(window)
                self.positionBottomRight(window)
                window.orderFront(nil)
            } else {
                // Fallback: create a plain hosting window if the scene didn’t open.
                self.openFallbackPanel()
            }
        }
    }

    private func isDesktopPanel(_ window: NSWindow) -> Bool {
        let title = window.title
        return title == "Desktop Panel" || window.identifier?.rawValue == "desktop-panel"
    }

    private func openFallbackPanel() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 200),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.title = "Desktop Panel"
        panel.identifier = NSUserInterfaceItemIdentifier("desktop-panel")
        panel.contentViewController = NSHostingController(
            rootView: DesktopPanelView(sampler: MetricsSamplerService.shared)
        )
        configurePanel(panel)
        positionBottomRight(panel)
        panel.orderFront(nil)
    }

    func configurePanel(_ window: NSWindow) {
        window.title = "Desktop Panel"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isOpaque = false
        window.backgroundColor = .clear
        window.isMovableByWindowBackground = true
        // Normal level so other app windows can cover the panel.
        window.level = .normal
        window.hasShadow = false
        window.collectionBehavior.insert([.canJoinAllSpaces, .fullScreenAuxiliary])

        // Remove traffic lights entirely for a clean widget-like look.
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true

        // Drop closable chrome if present.
        window.styleMask.remove(.closable)
        window.styleMask.remove(.miniaturizable)
        window.styleMask.remove(.resizable)
        if !window.styleMask.contains(.fullSizeContentView) {
            window.styleMask.insert(.fullSizeContentView)
        }
    }

    /// Places the panel in the bottom-right of the current screen's visible frame.
    func positionBottomRight(_ window: NSWindow) {
        window.layoutIfNeeded()
        let screen = window.screen ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return }

        let size = window.frame.size
        let margin: CGFloat = 16
        let origin = NSPoint(
            x: visible.maxX - size.width - margin,
            y: visible.minY + margin
        )
        window.setFrameOrigin(origin)
    }
}

extension Notification.Name {
    static let showDesktopPanel = Notification.Name("showDesktopPanel")
    static let requestOpenDesktopPanelWindow = Notification.Name("requestOpenDesktopPanelWindow")
}

/// Bridges NotificationCenter → SwiftUI openWindow for the Desktop Panel scene.
struct DesktopPanelOpener: ViewModifier {
    @Environment(\.openWindow) private var openWindow

    func body(content: Content) -> some View {
        content.onReceive(NotificationCenter.default.publisher(for: .requestOpenDesktopPanelWindow)) { _ in
            openWindow(id: "desktop-panel")
        }
    }
}

private struct DesktopPanelChrome: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { configure(view.window) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { configure(nsView.window) }
    }

    private func configure(_ window: NSWindow?) {
        guard let window else { return }
        (NSApp.delegate as? AppDelegate)?.configurePanel(window)
    }
}
