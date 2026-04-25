import SwiftUI

struct AboutView: View {
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

            Text("Софт для тех, кто пишет код. Для людей с двумя+ мониторами, которые умеют сфокусироваться, но иногда забывают — и Telegram во второй экран сам себя не закроет.")
                .font(.system(size: 13))
                .foregroundColor(Color.white.opacity(0.78))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 460, alignment: .leading)

            VStack(alignment: .leading, spacing: 10) {
                Text("Как пользоваться")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textTertiary)

                Text("Добавь приложение через «+ Добавить» в боковой панели. Открой его расписание и нарисуй на круге зелёные слоты — это окна доступа. Всё остальное время приложение заблокировано: блюр поверх окна и блок ввода.")
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
