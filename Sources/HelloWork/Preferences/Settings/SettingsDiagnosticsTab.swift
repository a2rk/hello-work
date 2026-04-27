import SwiftUI
import AppKit

struct SettingsDiagnosticsTab: View {
    @Environment(\.t) var t
    @ObservedObject var state: AppState

    @State private var contents: String = ""
    @State private var refreshTimer: Timer?
    /// Last seen mtime файла лога — если не изменился, skip read+state-update.
    @State private var lastModificationDate: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(t.diagnosticsTitle)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                Text(t.diagnosticsSubtitle)
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textSecondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(DevLogger.shared.logURL.path)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(Theme.textTertiary)
                    .textSelection(.enabled)
                    .padding(.top, 2)
            }

            controlsBar

            logScroll
        }
        .onAppear {
            reload()
            refreshTimer?.invalidate()
            // Авто-обновление каждые 0.8с пока вкладка открыта.
            let timer = Timer(timeInterval: 0.8, repeats: true) { _ in
                Task { @MainActor in
                    self.reload()
                }
            }
            RunLoop.main.add(timer, forMode: .common)
            refreshTimer = timer
        }
        .onDisappear {
            refreshTimer?.invalidate()
            refreshTimer = nil
        }
    }

    private var controlsBar: some View {
        HStack(spacing: 8) {
            actionButton(t.diagnosticsRefresh, system: "arrow.clockwise") {
                lastModificationDate = nil
                reload()
            }
            actionButton(t.diagnosticsClear, system: "trash") {
                DevLogger.shared.clear()
                contents = ""
                lastModificationDate = nil
            }
            actionButton(t.diagnosticsReveal, system: "folder") {
                NSWorkspace.shared.activateFileViewerSelecting([DevLogger.shared.logURL])
            }
            Spacer()
            actionButton(t.diagnosticsDisable, system: "xmark.circle", danger: true) {
                state.developerMode = false
                state.settingsTab = .data
            }
        }
    }

    private func actionButton(
        _ title: String,
        system: String,
        danger: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: system)
                    .font(.system(size: 10, weight: .medium))
                Text(title)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundColor(danger ? Theme.danger : .white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill((danger ? Theme.danger : Color.white).opacity(0.08)))
            .overlay(
                Capsule().stroke((danger ? Theme.danger : Theme.surfaceStroke), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var logScroll: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if contents.isEmpty {
                    Text(t.diagnosticsEmpty)
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .id("bottom")
                } else {
                    Text(contents)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.white.opacity(0.92))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .id("bottom")
                }
            }
            .frame(maxHeight: 420)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.black.opacity(0.35))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Theme.surfaceStroke, lineWidth: 1)
            )
            .onChange(of: contents) { _ in
                // Прокручиваем к последней строке.
                withAnimation(.linear(duration: 0.1)) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
        }
    }

    private func reload() {
        // Двухступенчатый: дешёвый stat() для mtime, full read только если изменилось.
        // .onDisappear уже останавливает timer при смене таба, так что здесь
        // дополнительная пауза не нужна — но gate через mtime спасает от
        // ненужных file-read'ов когда логгер выключен / dev mode off.
        let url = DevLogger.shared.logURL
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        let mtime = attrs?[.modificationDate] as? Date
        if mtime != lastModificationDate {
            lastModificationDate = mtime
            contents = DevLogger.shared.readContents()
        }
    }
}
