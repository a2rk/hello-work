import Foundation

enum DevLogConfig {
    /// Путь до dev_log.json. После создания репозитория замени `<user>` и `<repo>`.
    static let url = URL(string: "https://raw.githubusercontent.com/a2rk/hello-work/main/dev_log.json")!
}
