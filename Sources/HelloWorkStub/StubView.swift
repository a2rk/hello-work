import SwiftUI

struct StubView: View {
    @ObservedObject var model: EngineManager
    @State private var lang: StubLanguage = StubLanguage.system

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 18) {
                hLogo
                    .padding(.top, 12)

                Text("HWInstaller")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)

                Text(StubL10n.subtitle(lang))
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 24)

                Spacer(minLength: 0)

                statusBlock
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
            }
        }
        .frame(width: 460, height: 320)
        .preferredColorScheme(.dark)
        .onAppear {
            lang = StubLanguage.detected()
        }
    }

    // MARK: - Logo

    private var hLogo: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(red: 0.62, green: 1.0, blue: 0.58).opacity(0.18))
                .frame(width: 64, height: 64)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color(red: 0.62, green: 1.0, blue: 0.58).opacity(0.45), lineWidth: 1)
                )
            Text("H")
                .font(.system(size: 36, weight: .heavy))
                .foregroundColor(.white)
        }
    }

    // MARK: - Status

    @ViewBuilder
    private var statusBlock: some View {
        switch model.status {
        case .idle:
            statusText(StubL10n.preparing(lang))
            progressBar(value: 0)

        case .checking:
            statusText(StubL10n.checking(lang))
            progressBar(value: 0, indeterminate: true)

        case .downloading(let p):
            statusText(StubL10n.downloading(lang, percent: Int(p * 100)))
            progressBar(value: p)

        case .mounting:
            statusText(StubL10n.mounting(lang))
            progressBar(value: 0.92)

        case .copying:
            statusText(StubL10n.copying(lang))
            progressBar(value: 0.96)

        case .launching:
            statusText(StubL10n.launching(lang))
            progressBar(value: 1.0)

        case .ready:
            statusText(StubL10n.ready(lang))
            progressBar(value: 1.0)

        case .error(let message):
            VStack(spacing: 8) {
                Text(StubL10n.errorTitle(lang))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(red: 1.0, green: 0.40, blue: 0.40))
                Text(message)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func statusText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .tracking(1.2)
            .foregroundColor(.white.opacity(0.7))
    }

    private func progressBar(value: Double, indeterminate: Bool = false) -> some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(Color.white.opacity(0.08))
                .frame(height: 4)

            if indeterminate {
                Capsule()
                    .fill(Color(red: 0.62, green: 1.0, blue: 0.58).opacity(0.85))
                    .frame(width: 80, height: 4)
                    .modifier(IndeterminateAnimation())
            } else {
                GeometryReader { geo in
                    Capsule()
                        .fill(Color(red: 0.62, green: 1.0, blue: 0.58))
                        .frame(width: max(2, geo.size.width * CGFloat(min(max(value, 0), 1))), height: 4)
                }
                .frame(height: 4)
            }
        }
    }
}

private struct IndeterminateAnimation: ViewModifier {
    @State private var x: CGFloat = -80

    func body(content: Content) -> some View {
        content
            .offset(x: x)
            .onAppear {
                withAnimation(Animation.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                    x = 380
                }
            }
    }
}
