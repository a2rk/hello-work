import SwiftUI
import AppKit

struct StatsAppBreakdownRow: Identifiable {
    let id: String          // bundleID
    let name: String
    let icon: NSImage?
    let attempts: Int
    let percent: Int        // 0..100
    let isOwnApp: Bool
}

struct StatsAppBreakdown: View {
    let rows: [StatsAppBreakdownRow]

    var body: some View {
        VStack(spacing: 6) {
            ForEach(rows) { row in
                HStack(spacing: 10) {
                    if let icon = row.icon {
                        Image(nsImage: icon)
                            .resizable()
                            .interpolation(.high)
                            .frame(width: 18, height: 18)
                    } else {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Theme.surface)
                            .frame(width: 18, height: 18)
                    }

                    Text(row.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(width: 160, alignment: .leading)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(Theme.surface)
                                .frame(height: 6)
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(Theme.accent)
                                .frame(width: geo.size.width * CGFloat(row.percent) / 100.0, height: 6)
                        }
                        .frame(maxHeight: .infinity, alignment: .center)
                    }
                    .frame(height: 18)

                    Text("\(row.attempts)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                        .monospacedDigit()
                        .frame(width: 56, alignment: .trailing)

                    Text("\(row.percent)%")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textTertiary)
                        .monospacedDigit()
                        .frame(width: 44, alignment: .trailing)
                }
            }
        }
    }
}
