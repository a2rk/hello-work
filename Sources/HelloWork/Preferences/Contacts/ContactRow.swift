import SwiftUI

struct ContactRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 0) {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(Theme.textSecondary)
                .frame(width: 84, alignment: .leading)
            Text(value)
                .font(.system(size: 13))
                .foregroundColor(.white)
                .lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }
}
