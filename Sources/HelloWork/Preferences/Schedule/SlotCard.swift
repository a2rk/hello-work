import SwiftUI

struct SlotCard: View {
    @Environment(\.t) var t
    let slot: Slot
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Text(format(slot.startMinutes))
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundColor(.white)
                Image(systemName: "arrow.right")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textTertiary)
                Text(format(slot.endMinutes))
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                Button(action: onDelete) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9))
                        .foregroundColor(Theme.textTertiary)
                        .padding(6)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Text(lengthText)
                .font(.system(size: 11))
                .foregroundColor(Theme.textTertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Theme.surfaceStroke, lineWidth: 1)
        )
    }

    private var lengthText: String {
        let length = slot.lengthMinutes
        let h = length / 60
        let m = length % 60
        if h == 0 { return "\(m) \(t.unitMin)" }
        if m == 0 { return "\(h) \(t.unitH)" }
        return "\(h) \(t.unitH) \(m) \(t.unitMin)"
    }

    private func format(_ minute: Int) -> String {
        let m = ((minute % minutesInDay) + minutesInDay) % minutesInDay
        if m == 0 && minute != 0 { return "24:00" }
        return String(format: "%02d:%02d", m / 60, m % 60)
    }
}
