import SwiftUI

struct OnboardingView: View {
    @Environment(\.t) var t
    let action: () -> Void

    private var steps: [(num: Int, title: String, desc: String)] {
        [
            (1, t.onboardingStep1Title, t.onboardingStep1Desc),
            (2, t.onboardingStep2Title, t.onboardingStep2Desc),
            (3, t.onboardingStep3Title, t.onboardingStep3Desc)
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 36) {
            VStack(alignment: .leading, spacing: 8) {
                Text(t.onboardingTitle)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundColor(.white)
                Text(t.onboardingSubtitle)
                    .font(.system(size: 13))
                    .foregroundColor(Theme.textSecondary)
                    .frame(maxWidth: 460, alignment: .leading)
            }

            stepsRow
                .frame(maxWidth: 620, alignment: .leading)

            Button(action: action) {
                HStack(spacing: 8) {
                    Text(t.onboardingButton)
                        .font(.system(size: 13, weight: .semibold))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundColor(.black)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(Capsule().fill(Color.white))
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)
        }
    }

    private var stepsRow: some View {
        HStack(alignment: .top, spacing: 16) {
            ForEach(0..<steps.count, id: \.self) { i in
                stepColumn(steps[i])
                    .frame(maxWidth: .infinity, alignment: .leading)
                if i < steps.count - 1 {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(Theme.textTertiary)
                        .padding(.top, 11)
                }
            }
        }
    }

    private func stepColumn(_ step: (num: Int, title: String, desc: String)) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                Circle()
                    .stroke(Theme.surfaceStroke, lineWidth: 1)
                Text("\(step.num)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.textSecondary)
            }
            .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(step.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                Text(step.desc)
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textSecondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
