import SwiftUI

struct ContactsView: View {
    @Environment(\.t) var t

    private var rows: [(label: String, value: String)] {
        [
            (t.contactEmail,    "..."),
            (t.contactTelegram, "..."),
            (t.contactWebsite,  "..."),
            (t.contactIssues,   "...")
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 6) {
                Text(t.contactsTitle)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
                Text(t.contactsSubtitle)
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textSecondary)
            }

            VStack(spacing: 0) {
                ForEach(0..<rows.count, id: \.self) { i in
                    ContactRow(label: rows[i].label, value: rows[i].value)
                    if i < rows.count - 1 {
                        Rectangle()
                            .fill(Theme.surfaceStroke)
                            .frame(height: 1)
                    }
                }
            }
            .frame(maxWidth: 460, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Theme.surfaceStroke, lineWidth: 1)
            )

            Spacer(minLength: 0)
        }
    }
}
