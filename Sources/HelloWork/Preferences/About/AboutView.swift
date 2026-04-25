import SwiftUI

struct AboutView: View {
    @Environment(\.t) var t

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .center, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color.white.opacity(0.95))
                    Text("H")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.black)
                }
                .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Hello work")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.white)
                    Text(AppVersion.displayString)
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textSecondary)
                }
            }

            Text(t.aboutDescription)
                .font(.system(size: 13))
                .foregroundColor(Color.white.opacity(0.78))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 460, alignment: .leading)

            VStack(alignment: .leading, spacing: 10) {
                Text(t.aboutHowToUseTitle)
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textTertiary)

                Text(t.aboutHowToUseDesc)
                    .font(.system(size: 13))
                    .foregroundColor(Color.white.opacity(0.78))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 460, alignment: .leading)
            }

            Spacer(minLength: 0)
        }
    }
}
