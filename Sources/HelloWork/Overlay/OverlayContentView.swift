import SwiftUI

struct OverlayContentView: View {
    @ObservedObject var state: AppState

    var body: some View {
        ZStack {
            VisualEffectView()

            if state.patternOverlay {
                FallingPatternView(elementColor: Theme.accent)
                    .blur(radius: 14)
                    .opacity(0.95)

                HalftoneOverlay(
                    baseColor: Color.black.opacity(0.55),
                    dotSpacing: 8,
                    dotRadius: 1.4
                )
            } else {
                Color.black.opacity(0.15)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
