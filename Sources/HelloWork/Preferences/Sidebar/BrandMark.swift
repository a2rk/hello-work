import SwiftUI

struct BrandMark: View {
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Theme.accent)
                .frame(width: 7, height: 7)
            Text("Hello work")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
        }
    }
}
