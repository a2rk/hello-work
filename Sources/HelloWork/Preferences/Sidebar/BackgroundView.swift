import SwiftUI
import AppKit

struct BackgroundView: View {
    var body: some View {
        ZStack {
            MaterialBackdrop()
            Color.black.opacity(0.22)
        }
        .ignoresSafeArea()
    }
}

struct MaterialBackdrop: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = .hudWindow
        v.blendingMode = .behindWindow
        v.state = .active
        v.appearance = NSAppearance(named: .vibrantDark)
        return v
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
