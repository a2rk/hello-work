import SwiftUI

struct OverlayContentView: View {
    var body: some View {
        ZStack {
            VisualEffectView()
            Color.black.opacity(0.15)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
